import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/capture.dart';
import '../core/capture_policy.dart';
import '../core/limits.dart';
import '../core/models.dart';

/// Internal capture lifecycle bridge. The public session controls activation.
class CaptureController {
  CaptureController({
    CapturePolicy? policy,
    LoggerLimits limits = const LoggerLimits(),
    void Function(String)? onDiagnostic,
    this.onChanged,
  })  : engine = CaptureEngine(policy: policy, limits: limits),
        store = CallStore(limits: limits, onDiagnostic: onDiagnostic),
        _onDiagnostic = onDiagnostic;
  final CaptureEngine engine;
  final CallStore store;
  final void Function(String)? _onDiagnostic;
  final void Function()? onChanged;
  bool isCapturing = false;
  int _sequence = 0;
  void activate(String sessionId) {
    store.reset(sessionId);
    isCapturing = true;
  }

  void deactivate() {
    isCapturing = false;
    store.deactivate();
  }

  void clear() {
    store.clear();
    onChanged?.call();
  }

  String nextId() => '${++_sequence}';
  void diagnostic(String code) {
    try {
      _onDiagnostic?.call(code);
    } catch (_) {/* Never break application IO. */}
  }
}

/// Internal interceptor until the session facade replaces the v1 entrypoint.
class SessionDioInterceptor extends Interceptor {
  SessionDioInterceptor(this._capture);
  final CaptureController _capture;
  final Expando<_Observation> _observations = Expando<_Observation>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_capture.isCapturing) {
      handler.next(options);
      return;
    }
    try {
      final now = DateTime.now().toUtc();
      final stopwatch = Stopwatch()..start();
      final request = _capture.engine.request(
        method: options.method,
        url: _rawUrl(options),
        queryParameters: options.queryParameters,
        headers: options.headers,
        body: options.data,
        startedAt: now,
        bodyOverride: _summary(options.data),
      );
      final admission = _capture.store
          .admit(id: _capture.nextId(), request: request, observedAt: now);
      // A rejected admission is still observed: a later callback must not
      // reconstruct it as an unmatched call.
      if (admission != null) _capture.onChanged?.call();
      _observations[options] = _Observation(
        admission,
        stopwatch,
        utf8.encode(jsonEncode(request.headers)).length,
      );
    } catch (_) {
      _observations[options] = _Observation(null, null, 0);
      _capture.diagnostic('captureFailed');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_capture.isCapturing) {
      handler.next(response);
      return;
    }
    _terminal(response.requestOptions, response, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_capture.isCapturing) {
      handler.next(err);
      return;
    }
    _terminal(err.requestOptions, err.response, err);
    handler.next(err);
  }

  void _terminal(
    RequestOptions options,
    Response? response,
    DioException? error,
  ) {
    try {
      final marker = _observations[options];
      if (marker != null &&
          (marker.terminal ||
              marker.admission == null ||
              !_capture.store.accepts(marker.admission!))) {
        return;
      }
      if (marker != null) {
        marker.terminal = true;
        marker.watch?.stop();
      }
      final now = DateTime.now().toUtc();
      final kind = error == null ? null : _errorKind(error.type);
      final state = kind == NetworkErrorKind.cancelled
          ? NetworkCallState.cancelled
          : error == null
              ? NetworkCallState.completed
              : NetworkCallState.failed;
      final request = marker == null
          ? _capture.engine.request(
              method: options.method,
              url: _rawUrl(options),
              queryParameters: options.queryParameters,
              headers: options.headers,
              bodyOverride: CoreRecords.body(
                kind: BodyKind.omitted,
                omissionReason: 'missingRequest',
              ),
            )
          : null;
      final usedHeaders = marker?.headerBytes ??
          utf8.encode(jsonEncode(request!.headers)).length;
      final rawTarget = _rawUrl(options);
      final target = rawTarget.length <= _capture.engine.limits.maxUrlBytes
          ? Uri.tryParse(rawTarget)?.normalizePath()
          : null;
      final capturedResponse = response == null
          ? null
          : _capture.engine.response(
              host: target?.host ?? '',
              path: target?.path ?? '',
              method: options.method,
              headers: response.headers.map,
              body: response.data,
              bodyOverride: _summary(response.data),
              statusCode: response.statusCode,
              endedAt: now,
              headerBudgetBytes:
                  (_capture.engine.limits.maxHeadersBytes - usedHeaders)
                      .clamp(0, _capture.engine.limits.maxHeadersBytes),
            );
      final capturedError = kind == null
          ? null
          : CoreRecords.error(
              kind,
              maxBytes: _capture.engine.limits.maxErrorBytes,
            );
      if (marker != null) {
        _capture.store.finish(
          marker.admission!,
          response: capturedResponse,
          error: capturedError,
          state: state,
          durationMicros: marker.watch!.elapsedMicroseconds,
          endedAt: now,
        );
      } else {
        // Keep a weak terminal marker so duplicate unmatched callbacks are ignored.
        _observations[options] = _Observation(null, null, usedHeaders)
          ..terminal = true;
        _capture.store.admitUnmatched(
          id: _capture.nextId(),
          request: request!,
          observedAt: now,
          endedAt: now,
          state: state,
          response: capturedResponse,
          error: capturedError,
        );
      }
      _capture.onChanged?.call();
    } catch (_) {
      _capture.diagnostic('captureFailed');
    }
  }

  // Never use RequestOptions.uri: it recursively converts raw query values.
  String _rawUrl(RequestOptions options) {
    final path = options.path;
    final cap = _capture.engine.limits.maxUrlBytes;
    if (path.length > cap) return path;
    if (path.startsWith('http:') || path.startsWith('https:')) return path;
    final base = options.baseUrl;
    if (base.length > cap) return base;
    // Mirror Dio's bounded base/path joining, without encoding query objects.
    final joined = '$base$path';
    final pieces = joined.split(':/');
    return pieces.length == 2
        ? '${pieces[0]}:/${pieces[1].replaceAll('//', '/')}'
        : joined;
  }

  BodySnapshot? _summary(Object? data) {
    if (data == null) return CoreRecords.body(kind: BodyKind.absent);
    if (data is FormData) {
      final types = <String>[];
      var bytes = 0;
      for (final entry in data.files.take(16)) {
        final mime = entry.value.contentType;
        if (mime == null || mime.type.length > 64 || mime.subtype.length > 64) {
          continue;
        }
        final type = '${mime.type}/${mime.subtype}';
        if (type.length > 128 || bytes + type.length > 1024) continue;
        bytes += type.length;
        if (!types.contains(type)) types.add(type);
      }
      return CoreRecords.body(
        kind: BodyKind.multipartSummary,
        summary: CoreRecords.summary(
          fieldCount: data.fields.length,
          fileCount: data.files.length,
          contentTypes: types,
        ),
      );
    }
    if (data is Uint8List || data is List<int>) {
      return CoreRecords.body(
        kind: BodyKind.binarySummary,
        knownSizeBytes: (data as List).length,
      );
    }
    if (data is MultipartFile) {
      return CoreRecords.body(
        kind: BodyKind.binarySummary,
        knownSizeBytes: data.length,
      );
    }
    if (data is Stream || data is ResponseBody) {
      return CoreRecords.body(
        kind: BodyKind.unsupported,
        omissionReason: 'unsupportedType',
      );
    }
    return null;
  }

  NetworkErrorKind _errorKind(DioExceptionType type) => switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          NetworkErrorKind.timeout,
        DioExceptionType.badCertificate => NetworkErrorKind.certificate,
        DioExceptionType.badResponse => NetworkErrorKind.badResponse,
        DioExceptionType.cancel => NetworkErrorKind.cancelled,
        DioExceptionType.connectionError => NetworkErrorKind.connection,
        DioExceptionType.unknown => NetworkErrorKind.unknown,
        _ => type.name.endsWith('Timeout')
            ? NetworkErrorKind.timeout
            : NetworkErrorKind.unknown,
      };
}

class _Observation {
  _Observation(this.admission, this.watch, this.headerBytes);
  final Admission? admission;
  final Stopwatch? watch;
  final int headerBytes;
  bool terminal = false;
}
