import 'dart:async';
import 'package:flutter/foundation.dart';
import 'adapter/session_interceptor.dart';
import 'core/config.dart';
import 'core/models.dart';
import 'server/server.dart';

/// An explicitly owned capture and dashboard session.
class NetworkLoggerSession {
  NetworkLoggerSession({required this.config}) {
    _capture = CaptureController(
      policy: config.capture,
      limits: config.limits,
      onDiagnostic: _diagnostic,
      onChanged: _notify,
    );
  }
  final LoggerConfig config;
  final SessionServer _server = createServer();
  final StreamController<LoggerChange> _changes = StreamController.broadcast();
  late final CaptureController _capture;
  LoggerLifecycle _state = LoggerLifecycle.idle;
  int _generation = 0;
  Future<LoggerStartResult>? _starting;
  Future<void>? _stopping;
  Future<void>? _disposing;
  LoggerStartResult? _runningResult;
  bool _disposed = false;

  LoggerLifecycle get state => _state;
  LoggerPlatformSupport get platformSupport => _server.platformSupport;
  bool get isEnabled =>
      _configurationEnabled &&
      platformSupport == LoggerPlatformSupport.supported;
  bool get isRunning => _state == LoggerLifecycle.running;
  Uri? get dashboardUri => isRunning ? _runningResult?.dashboardUri : null;
  Stream<LoggerChange> get changes => _changes.stream;
  bool get _configurationEnabled => effectiveLoggerEnabled(
        runtimeEnabled: config.enabled,
        debugMode: kDebugMode,
        releaseOptIn: const bool.fromEnvironment('NETWORK_LOGGER_ENABLED'),
      );

  Future<LoggerStartResult> start() {
    if (_disposed) return Future.value(_result(LoggerStartStatus.disposed));
    if (!_configurationEnabled) {
      return Future.value(_result(LoggerStartStatus.disabled));
    }
    if (platformSupport != LoggerPlatformSupport.supported) {
      return Future.value(_result(LoggerStartStatus.unsupportedPlatform));
    }
    if (_state == LoggerLifecycle.stopping) {
      return _stopping!.then((_) => start());
    }
    if (_starting != null) return _starting!;
    if (isRunning) return Future.value(_runningResult!);
    _state = LoggerLifecycle.starting;
    final completer = Completer<LoggerStartResult>();
    _starting = completer.future;
    _beginStart(_generation).then(
      completer.complete,
      onError: (Object error, StackTrace stack) {
        _diagnostic('startFailed');
        if (!_disposed && _state == LoggerLifecycle.starting) {
          _state = LoggerLifecycle.idle;
        }
        completer.complete(_result(LoggerStartStatus.bindFailed));
      },
    ).whenComplete(() {
      _starting = null;
    });
    return completer.future;
  }

  Future<LoggerStartResult> _beginStart(int generation) async {
    final result = await _server.start(
      config,
      snapshot: getSnapshot,
      clear: clear,
      changes: changes,
    );
    if (_disposed || generation != _generation) {
      await _server.stop();
      return _result(
        _disposed ? LoggerStartStatus.disposed : LoggerStartStatus.cancelled,
      );
    }
    if (result.status != LoggerStartStatus.running) {
      _state = LoggerLifecycle.idle;
      return _result(result.status);
    }
    _capture.activate(result.sessionId);
    _runningResult = CoreConfigRecords.start(
      status: result.status,
      dashboardUri: result.dashboardUri,
      lanCandidates: result.lanCandidates,
      warningCodes: result.warningCodes,
    );
    _state = LoggerLifecycle.running;
    return _runningResult!;
  }

  Future<void> stop() {
    _capture.deactivate();
    if (_disposed) return _disposing ?? Future.value();
    if (_stopping != null) return _stopping!;
    if (_state == LoggerLifecycle.idle) return Future.value();
    _generation++;
    _state = LoggerLifecycle.stopping;
    _runningResult = null;
    final completer = Completer<void>();
    _stopping = completer.future;
    _finishStop().then(completer.complete).whenComplete(() {
      _stopping = null;
    });
    return completer.future;
  }

  Future<void> _finishStop() async {
    try {
      await _starting;
      await _server.stop();
    } catch (_) {
      _diagnostic('stopFailed');
    }
    if (!_disposed) _state = LoggerLifecycle.idle;
  }

  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _disposed = true;
    _state = LoggerLifecycle.disposed;
    _generation++;
    _runningResult = null;
    _capture.deactivate();
    final completer = Completer<void>();
    _disposing = completer.future;
    _finishDispose().then(completer.complete);
    return completer.future;
  }

  Future<void> _finishDispose() async {
    try {
      await _starting;
      await _stopping;
      await _server.stop();
    } catch (_) {
      _diagnostic('stopFailed');
    }
    if (getSnapshot().sessionId.isNotEmpty) _capture.clear();
    unawaited(_changes.close());
  }

  void clear() {
    if (_disposed || getSnapshot().sessionId.isEmpty) return;
    _capture.clear();
  }

  List<NetworkCall> getCalls() => _capture.store.calls;
  LoggerSnapshot getSnapshot() => _capture.store.snapshot;
  Uri? pairingUri({Uri? dashboardUri}) =>
      isRunning ? _server.pairingUri(dashboardUri: dashboardUri) : null;

  LoggerStartResult _result(LoggerStartStatus status) =>
      CoreConfigRecords.start(status: status);
  void _notify() {
    if (_disposed) return;
    final snapshot = getSnapshot();
    _changes.add(CoreRecords.change(snapshot.sessionId, snapshot.version));
  }

  void _diagnostic(String code) {
    if (code == 'versionExhausted' && !_disposed) unawaited(stop());
    try {
      config.onDiagnostic?.call(CoreConfigRecords.diagnostic(code));
    } catch (_) {/* Diagnostics cannot break app network requests. */}
  }
}

/// Dio capture adapter for one explicit session.
class CoteNetworkLogger extends SessionDioInterceptor {
  CoteNetworkLogger({required NetworkLoggerSession session})
      : super(session._capture);
}
