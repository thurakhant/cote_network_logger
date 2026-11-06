import 'dart:convert';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
  test('FormData, bytes and unsupported bodies remain JSON-safe', () async {
    final session = NetworkLoggerSession(config: LoggerConfig(port: 0));
    await session.start();
    addTearDown(session.dispose);
    final dio = Dio()..interceptors.add(CoteNetworkLogger(session: session));
    addTearDown(dio.close);
    dio.httpClientAdapter =
        FakeAdapter((_) => ResponseBody.fromBytes([1, 2, 3], 200));
    await dio.post(
      'https://example.test/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes([4, 5], filename: 'a.bin'),
      }),
      options: Options(responseType: ResponseType.bytes),
    );
    await dio.get(
      'https://example.test/normal',
      options: Options(responseType: ResponseType.bytes),
    );
    final payload = jsonDecode(jsonEncode(session.getSnapshot().toJson()));
    expect(payload['calls'].length, 2);
    final upload = (payload['calls'] as List).singleWhere(
      (call) => call['request']['url'] == 'https://example.test/upload',
    );
    expect(upload['request']['body']['kind'], 'multipartSummary');
    expect(upload['response']['body']['kind'], 'binarySummary');
    expect(upload['response']['body']['content'], isNull);
  });

  test('JSON body is snapshotted before caller can mutate it', () async {
    final session = NetworkLoggerSession(
      config: LoggerConfig(
        port: 0,
        capture: CapturePolicy(
          bodyRules: [
            BodyCaptureRule(
              host: 'example.test',
              path: '/json',
              methods: {'POST'},
              allowedJsonPaths: {r'$.items[*]'},
            ),
          ],
        ),
      ),
    );
    await session.start();
    addTearDown(session.dispose);
    final body = {
      'items': <dynamic>[1, true, null],
    };
    final dio = Dio()
      ..interceptors.add(CoteNetworkLogger(session: session))
      ..httpClientAdapter =
          FakeAdapter((_) => ResponseBody.fromString('{}', 200));
    addTearDown(dio.close);
    await dio.post('https://example.test/json', data: body);
    body['items']!.add(Object());
    expect(session.getCalls().single.request.body.content, {
      'items': [1, true, null],
    });
    expect(() => jsonEncode(session.getSnapshot().toJson()), returnsNormally);
  });
}
