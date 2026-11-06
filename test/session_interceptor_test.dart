import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cote_network_logger/src/adapter/session_interceptor.dart';
import 'package:cote_network_logger/src/core/models.dart';
import 'package:cote_network_logger/src/core/limits.dart';
import 'package:cote_network_logger/src/core/capture_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.fetcher);
  final Future<ResponseBody> Function(RequestOptions) fetcher;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      fetcher(options);
  @override
  void close({bool force = false}) {}
}

class RecordingErrorHandler extends ErrorInterceptorHandler {
  int calls = 0;
  @override
  void next(DioException err) {
    calls++;
  }
}

class HostileQuery {
  int conversions = 0;
  @override
  String toString() {
    conversions++;
    return 'SECRET';
  }
}

class CountingQueryList extends ListBase<Object?> {
  int reads = 0;
  @override
  int get length => 9999;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  Object? operator [](int index) {
    reads++;
    return '';
  }

  @override
  void operator []=(int index, Object? value) =>
      throw UnsupportedError('read only');
}

void main() {
  test('disabled logger leaves request data and store untouched', () async {
    final capture = CaptureController();
    final data = {'token': 'SECRET', 'ok': false};
    final dio = Dio()
      ..httpClientAdapter = StubAdapter((options) async {
        expect(identical(options.data, data), isTrue);
        return ResponseBody.fromString('{}', 200);
      });
    dio.interceptors.add(SessionDioInterceptor(capture));
    await dio.post('https://example.test/a?token=SECRET', data: data);
    expect(capture.store.calls, isEmpty);
    expect(capture.isCapturing, isFalse);
    dio.close();
  });
  test('request preserved, error sanitized, terminal duration monotonic',
      () async {
    final capture = CaptureController()..activate('s');
    var calls = 0;
    final dio = Dio()
      ..httpClientAdapter = StubAdapter((options) async {
        calls++;
        return ResponseBody.fromString(
          '{"token":"SECRET"}',
          503,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
    dio.interceptors.add(SessionDioInterceptor(capture));
    await expectLater(
      dio.get(
        'https://example.test/request?token=SECRET',
        options: Options(headers: {'Authorization': 'SECRET'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(calls, 1);
    final call = capture.store.calls.single;
    expect(call.state, NetworkCallState.failed);
    expect(call.error!.kind, NetworkErrorKind.badResponse);
    expect(call.request.url, contains('/request'));
    expect(call.response!.statusCode, 503);
    expect(call.durationMicros, greaterThanOrEqualTo(0));
    expect(
      jsonEncode(capture.store.snapshot.toJson()),
      isNot(contains('SECRET')),
    );
    dio.close();
  });
  test('late request after clear or restart never reappears', () async {
    for (final restart in [false, true]) {
      final response = Completer<ResponseBody>();
      final entered = Completer<void>();
      final capture = CaptureController()..activate('s');
      final dio = Dio()
        ..httpClientAdapter = StubAdapter((options) {
          entered.complete();
          return response.future;
        });
      dio.interceptors.add(SessionDioInterceptor(capture));
      final pending = dio.get('https://example.test/late');
      await entered.future;
      if (restart) {
        capture.deactivate();
        capture.activate('next');
      } else {
        capture.clear();
      }
      response.complete(ResponseBody.fromString('{}', 200));
      await pending;
      expect(capture.store.calls, isEmpty);
      dio.close();
    }
  });
  test('streams and multipart are summarized without consumption', () async {
    var listened = 0;
    final stream = Stream<List<int>>.multi((sink) {
      listened++;
      sink.close();
    });
    final form = FormData.fromMap({
      'secret': 'SECRET',
      'file': MultipartFile.fromStream(() => stream, 0, filename: 'SECRET'),
    });
    final capture = CaptureController()..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    final options = RequestOptions(
      path: 'https://example.test/upload',
      method: 'POST',
      data: form,
    );
    interceptor.onRequest(options, RequestInterceptorHandler());
    expect(listened, 0);
    expect(form.isFinalized, isFalse);
    final body = capture.store.calls.single.request.body;
    expect(body.kind, BodyKind.multipartSummary);
    expect(body.summary!.fileCount, 1);
    expect(
      jsonEncode(capture.store.snapshot.toJson()),
      isNot(contains('SECRET')),
    );
  });
  test('unmatched response and cancellation have honest terminal records', () {
    final capture = CaptureController()..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    final options = RequestOptions(path: 'https://example.test/no-request');
    interceptor.onResponse(
      Response(requestOptions: options, statusCode: 200),
      ResponseInterceptorHandler(),
    );
    expect(capture.store.calls.single.incompleteRequest, isTrue);
    expect(capture.store.calls.single.durationMicros, isNull);
    final cancelled = RequestOptions(path: 'https://example.test/cancel');
    interceptor.onRequest(cancelled, RequestInterceptorHandler());
    interceptor.onError(
      DioException(
        requestOptions: cancelled,
        type: DioExceptionType.cancel,
        message: 'SECRET',
      ),
      RecordingErrorHandler(),
    );
    expect(capture.store.calls.first.state, NetworkCallState.cancelled);
    expect(
      jsonEncode(capture.store.snapshot.toJson()),
      isNot(contains('SECRET')),
    );
  });
  test('retries get new IDs and duplicate terminals do not update twice', () {
    final capture = CaptureController()..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    final options = RequestOptions(path: 'https://example.test/retry');
    interceptor.onRequest(options, RequestInterceptorHandler());
    final first = capture.store.calls.single.id;
    final handler = RecordingErrorHandler();
    interceptor.onError(DioException(requestOptions: options), handler);
    expect(handler.calls, 1);
    interceptor.onRequest(options, RequestInterceptorHandler());
    expect(capture.store.calls.first.id, isNot(first));
    final response = Response(requestOptions: options, statusCode: 200);
    interceptor.onResponse(response, ResponseInterceptorHandler());
    final version = capture.store.snapshot.version;
    interceptor.onResponse(response, ResponseInterceptorHandler());
    expect(capture.store.snapshot.version, version);
    expect(
      capture.store.calls.map((c) => c.state),
      [NetworkCallState.completed, NetworkCallState.failed],
    );
  });
  test('primitive captures preserved; Dio null data is honestly absent', () {
    final capture = CaptureController(
      policy: CapturePolicy(
        bodyRules: [
          BodyCaptureRule(
            host: 'example.test',
            path: '/primitive',
            allowedJsonPaths: {r'$'},
          ),
        ],
      ),
    )..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    for (final value in [false, 0, '', null]) {
      final options =
          RequestOptions(path: 'https://example.test/primitive', data: value);
      interceptor.onRequest(options, RequestInterceptorHandler());
      interceptor.onResponse(
        Response(requestOptions: options, data: value, statusCode: 200),
        ResponseInterceptorHandler(),
      );
      final call = capture.store.calls.first;
      for (final body in [call.request.body, call.response!.body]) {
        expect(body.kind, value == null ? BodyKind.absent : BodyKind.json);
        expect(body.content, value);
      }
    }
  });
  test('all resolved Dio timeout variants map to safe timeout category', () {
    for (final type
        in DioExceptionType.values.where((t) => t.name.endsWith('Timeout'))) {
      final capture = CaptureController()..activate('s');
      final interceptor = SessionDioInterceptor(capture);
      final options = RequestOptions(path: 'https://example.test/timeout');
      interceptor.onRequest(options, RequestInterceptorHandler());
      interceptor.onError(
        DioException(requestOptions: options, type: type, message: 'SECRET'),
        RecordingErrorHandler(),
      );
      expect(capture.store.calls.single.error!.kind, NetworkErrorKind.timeout);
    }
  });
  test('fixed error description respects configured error byte cap', () {
    final capture =
        CaptureController(limits: const LoggerLimits(maxErrorBytes: 1))
          ..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    final options = RequestOptions(path: 'https://example.test/error');
    interceptor.onRequest(options, RequestInterceptorHandler());
    interceptor.onError(
      DioException(requestOptions: options),
      RecordingErrorHandler(),
    );
    expect(
      utf8.encode(capture.store.calls.single.error!.description),
      hasLength(1),
    );
  });
  test('query capture bounds huge and cyclic inputs without object conversion',
      () {
    final capture = CaptureController(
      policy: CapturePolicy(allowedQueryKeys: {'object', 'cycle'}),
    )..activate('s');
    final interceptor = SessionDioInterceptor(capture);
    final hostile = HostileQuery();
    final cycle = <Object?>[];
    cycle.add(cycle);
    final options = RequestOptions(
      path: 'https://example.test/query',
      queryParameters: {
        'token': 'SECRET' * 1000000,
        'object': hostile,
        'cycle': cycle,
      },
    );
    interceptor.onRequest(options, RequestInterceptorHandler());
    expect(hostile.conversions, 0);
    expect(capture.store.calls, hasLength(1));
    expect(
      jsonEncode(capture.store.snapshot.toJson()),
      isNot(contains('SECRET')),
    );
    expect(
      capture.store.calls.single.request.url.length,
      lessThanOrEqualTo(4096),
    );
    interceptor.onResponse(
      Response(requestOptions: options, statusCode: 200),
      ResponseInterceptorHandler(),
    );
    expect(hostile.conversions, 0);
  });
  test('repeated query keys charge percent-encoded pair cost before copying',
      () {
    for (final key in ['x' * 4000, 'é' * 1000]) {
      final capture =
          CaptureController(policy: CapturePolicy(allowedQueryKeys: {key}))
            ..activate('s');
      final values = CountingQueryList();
      SessionDioInterceptor(capture).onRequest(
        RequestOptions(
          path: 'https://example.test/',
          queryParameters: {key: values},
        ),
        RequestInterceptorHandler(),
      );
      expect(values.reads, lessThanOrEqualTo(2));
      expect(
        capture.store.calls.single.request.captureWarnings,
        contains('byteLimit'),
      );
    }
  });
}
