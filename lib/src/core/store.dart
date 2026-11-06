part of 'models.dart';

/// A bounded, session-owned store. Internal: never exported by the package.
class CallStore {
  CallStore({
    required this.limits,
    this.onDiagnostic,
    this.counterLimit = 9007199254740991,
  }) {
    limits.validate();
    if (counterLimit <= 0 || counterLimit > 9007199254740991) {
      throw ArgumentError.value(counterLimit, 'counterLimit');
    }
  }
  final LoggerLimits limits;
  // Internal lower ceiling permits exhaustion tests without billions of writes.
  final int counterLimit;
  final void Function(String)? onDiagnostic;
  final _records = <String, NetworkCall>{};
  final _sizes = <String, int>{};
  final _admissions = <String, Admission>{};
  String _sessionId = '';
  int _version = 0;
  int _clearGeneration = 0;
  int _epoch = 0;
  int _bytes = 0;
  bool _active = false;

  int get encodedBytes => _bytes;
  List<NetworkCall> get calls =>
      List.unmodifiable(_records.values.toList().reversed);
  LoggerSnapshot get snapshot => LoggerSnapshot._(
        sessionId: _sessionId,
        version: _version,
        clearGeneration: _clearGeneration,
        calls: calls,
      );

  void reset(String sessionId) {
    _empty();
    _epoch++;
    _sessionId = sessionId;
    _version = 0;
    _clearGeneration = 0;
    _active = true;
  }

  void deactivate() {
    _active = false;
  }

  void clear() {
    _empty();
    _epoch++;
    if (_advance()) _clearGeneration++;
  }

  void _empty() {
    _records.clear();
    _sizes.clear();
    _admissions.clear();
    _bytes = 0;
  }

  Admission? admit({
    required String id,
    required NetworkRequest request,
    required DateTime observedAt,
  }) {
    if (!_active || _records.containsKey(id)) return null;
    final call = NetworkCall._(
      id: id,
      request: request,
      state: NetworkCallState.pending,
      revision: 1,
      incompleteRequest: false,
      observedAt: observedAt.toUtc(),
    );
    if (!_put(call)) return null;
    final admission = Admission._(id, _epoch);
    _admissions[id] = admission;
    return admission;
  }

  bool accepts(Admission admission) =>
      _active &&
      admission._epoch == _epoch &&
      identical(_admissions[admission._id], admission) &&
      _records[admission._id]?.state == NetworkCallState.pending;

  bool finish(
    Admission admission, {
    NetworkResponse? response,
    NetworkError? error,
    required NetworkCallState state,
    required int durationMicros,
    required DateTime endedAt,
  }) {
    if (!_active ||
        admission._epoch != _epoch ||
        !identical(_admissions[admission._id], admission)) {
      return false;
    }
    final previous = _records[admission._id];
    if (previous == null || previous.state != NetworkCallState.pending) {
      return false;
    }
    if (state == NetworkCallState.pending || durationMicros < 0) {
      throw ArgumentError('Invalid terminal transition');
    }
    final call = NetworkCall._(
      id: previous.id,
      request: previous.request,
      response: response,
      error: error,
      state: state,
      durationMicros: durationMicros,
      revision: 2,
      incompleteRequest: false,
      observedAt: previous.observedAt,
      endedAt: endedAt.toUtc(),
    );
    _admissions.remove(admission._id);
    return _put(call);
  }

  bool admitUnmatched({
    required String id,
    required NetworkRequest request,
    required DateTime observedAt,
    required DateTime endedAt,
    required NetworkCallState state,
    NetworkResponse? response,
    NetworkError? error,
  }) {
    if (!_active || _records.containsKey(id)) return false;
    if (state == NetworkCallState.pending) {
      throw ArgumentError('Terminal state required');
    }
    return _put(
      NetworkCall._(
        id: id,
        request: NetworkRequest._(
          method: request.method,
          url: request.url,
          headers: request.headers,
          body: BodySnapshot._(
            kind: BodyKind.omitted,
            omissionReason: 'missingRequest',
            truncated: false,
          ),
          captureWarnings: [...request.captureWarnings, 'missingRequest'],
        ),
        response: response,
        error: error,
        state: state,
        revision: 2,
        incompleteRequest: true,
        observedAt: observedAt.toUtc(),
        endedAt: endedAt.toUtc(),
      ),
    );
  }

  bool _put(NetworkCall call) {
    // Child byte counts are computed once from captured immutable values.
    // Two bytes preserve the prior conservative single-record array budget.
    final bytes = call._encodedBytes + 2;
    if (bytes > limits.maxStoreBytes) {
      if (_records.remove(call.id) != null) {
        _bytes -= _sizes.remove(call.id)!;
        _admissions.remove(call.id);
        _advance();
      }
      _diagnostic('recordTooLarge');
      return false;
    }
    _bytes -= _sizes[call.id] ?? 0;
    _records[call.id] = call;
    _sizes[call.id] = bytes;
    _bytes += bytes;
    while (_records.length > limits.maxCalls || _bytes > limits.maxStoreBytes) {
      final oldest = _records.keys.first;
      _records.remove(oldest);
      _admissions.remove(oldest);
      _bytes -= _sizes.remove(oldest)!;
    }
    _advance();
    return _records.containsKey(call.id);
  }

  bool _advance() {
    if (_version >= counterLimit || _clearGeneration >= counterLimit) {
      _active = false;
      _empty();
      _diagnostic('versionExhausted');
      return false;
    }
    _version++;
    return true;
  }

  void _diagnostic(String code) {
    try {
      onDiagnostic?.call(code);
    } catch (_) {/* diagnostics never affect requests */}
  }
}

/// Adapter retains this token in a weak association, not in an unbounded tombstone list.
class Admission {
  Admission._(this._id, this._epoch);
  final String _id;
  final int _epoch;
}
