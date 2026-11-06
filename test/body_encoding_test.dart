import 'dart:convert';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
  test('FormData, bytes and unsupported bodies remain JSON-safe', () async {
    final store = NetworkLogStore.instance..clear();
    final dio = Dio()..interceptors.add(const CoteNetworkLogger());
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
    final cycle = <String, dynamic>{};
    cycle['self'] = cycle;
    store.upsertLog('cyclic', {'requestBody': cycle, 'responseBody': Object()});
    final payload = jsonDecode(
      jsonEncode({'logs': store.getLogs(), 'count': store.logCount}),
    );
    expect(payload['count'], 3);
    final upload = (payload['logs'] as List)
        .singleWhere((log) => log['url'] == 'https://example.test/upload');
    expect(upload['requestBody'], isA<String>());
    expect(upload['requestBody'], contains('FormData'));
    expect(upload['responseBody'], contains('3 bytes'));
  });

  test('JSON body is snapshotted before caller can mutate it', () {
    final store = NetworkLogStore.instance..clear();
    final body = {
      'items': <dynamic>[1, true, null],
    };
    store.upsertLog('json', {'requestBody': body});
    body['items']!.add(Object());
    expect(store.getLogs().single['requestBody'], {
      'items': [1, true, null],
    });
    expect(() => jsonEncode(store.getLogs()), returnsNormally);
  });
}
