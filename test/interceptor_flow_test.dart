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
  setUp(() => NetworkLogStore.instance.clear());
  for (final status in [200, 500]) {
    test('request fields survive response $status and old keys remain',
        () async {
      Map<String, dynamic>? pending;
      final dio = Dio()..interceptors.add(const CoteNetworkLogger());
      addTearDown(dio.close);
      dio.httpClientAdapter = FakeAdapter((options) {
        pending = Map.of(NetworkLogStore.instance.getLogs().single);
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
      final log = NetworkLogStore.instance.getLogs().single;
      expect(log['requestHeaders'], containsPair('x-request', 'yes'));
      expect(log['requestTimestamp'], pending!['timestamp']);
      expect(log['headers'], containsPair('x-response', ['yes']));
      expect(
        log.keys,
        containsAll([
          'transactionId',
          'method',
          'url',
          'headers',
          'statusCode',
          'requestBody',
          'responseBody',
          'status',
          'timestamp',
        ]),
      );
    });
  }
}
