import 'dart:typed_data';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final status in [200, 500]) {
    test('request fields survive response $status through public session',
        () async {
      final session = NetworkLoggerSession(
        config: LoggerConfig(
          port: 0,
          capture: CapturePolicy(
            allowedHeaders: {
              'x-request',
              'x-response',
              'content-type',
            },
          ),
        ),
      );
      expect((await session.start()).status, LoggerStartStatus.running);
      addTearDown(session.dispose);
      NetworkCall? pending;
      final dio = Dio()..interceptors.add(CoteNetworkLogger(session: session));
      addTearDown(dio.close);
      dio.httpClientAdapter = FakeAdapter((options) {
        pending = session.getCalls().single;
        return ResponseBody.fromString(
          '{"ok":true}',
          status,
          headers: {
            'content-type': ['application/json'],
            'x-response': ['yes'],
          },
        );
      });
      try {
        await dio.post(
          'https://example.test/items',
          data: {'name': 'test'},
          options: Options(headers: {'x-request': 'yes'}),
        );
      } on DioException {
        if (status == 200) rethrow;
      }
      final log = session.getCalls().single;
      expect(log.request.headers, containsPair('x-request', ['yes']));
      expect(log.request.startedAt, pending!.request.startedAt);
      expect(log.response!.headers, containsPair('x-response', ['yes']));
      expect(log.response!.statusCode, status);
      expect(
        log.state,
        status == 200 ? NetworkCallState.completed : NetworkCallState.failed,
      );
      expect(log.durationMicros, greaterThanOrEqualTo(0));
      expect(pending!.state, NetworkCallState.pending);
    });
  }
}
