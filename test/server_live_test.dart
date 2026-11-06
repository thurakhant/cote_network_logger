import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
  test('advertised URL and logs endpoint survive odd bodies', () async {
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
    final server = NetworkLogWebServer.instance;
    expect(await server.start(), isTrue);
    addTearDown(server.stop);
    final uri = Uri.parse(server.dashboardUrl);
    expect(uri.scheme, 'http');
    expect(uri.port, 3000);
    expect(uri.path, isEmpty);
    final addresses =
        (await NetworkInterface.list(type: InternetAddressType.IPv4))
            .expand((interface) => interface.addresses)
            .map((address) => address.address);
    expect(uri.host == 'localhost' || addresses.contains(uri.host), isTrue);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final page = await (await client.getUrl(uri)).close();
    expect(page.statusCode, 200);
    await page.drain<void>();
    final response = await (await client.getUrl(uri.resolve('/logs'))).close();
    expect(response.statusCode, 200);
    final payload = jsonDecode(await utf8.decoder.bind(response).join());
    expect(payload['count'], 3);
    final upload = (payload['logs'] as List)
        .singleWhere((log) => log['url'] == 'https://example.test/upload');
    expect(upload['requestBody'], contains('FormData'));
    expect(upload['responseBody'], contains('3 bytes'));
  });

  test('stopping closes multiple clients safely', () async {
    final server = NetworkLogWebServer.instance;
    expect(await server.start(), isTrue);
    addTearDown(server.stop);
    final clients = await Future.wait([
      WebSocket.connect('ws://localhost:3000/ws'),
      WebSocket.connect('ws://localhost:3000/ws'),
    ]);
    final closed = clients.map((client) => client.drain<void>()).toList();
    await server.stop();
    await Future.wait(closed).timeout(const Duration(seconds: 3));
    expect(server.isRunning, isFalse);
  });
  test('connected clients receive a completed Dio call without refreshing',
      () async {
    NetworkLogStore.instance.clear();
    final server = NetworkLogWebServer.instance;
    expect(await server.start(), isTrue);
    addTearDown(server.stop);
    final socket = await WebSocket.connect('ws://localhost:3000/ws');
    final messages = StreamIterator<dynamic>(socket);
    addTearDown(() async {
      await messages.cancel();
      await socket.close();
    });
    expect(await messages.moveNext(), isTrue);
    expect(jsonDecode(messages.current as String)['type'], 'init');
    final dio = Dio()..interceptors.add(const CoteNetworkLogger());
    addTearDown(dio.close);
    dio.httpClientAdapter =
        FakeAdapter((_) => ResponseBody.fromString('ok', 200));
    await dio.get('https://example.test/live');
    final received = <Map<String, dynamic>>[];
    for (var i = 0; i < 2; i++) {
      expect(
        await messages.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      received
          .add(jsonDecode(messages.current as String) as Map<String, dynamic>);
    }
    expect(received.map((e) => e['type']), everyElement('log'));
    expect(received.last['log']['status'], 'completed');
    expect(received.last['log']['url'], 'https://example.test/live');
  });
}
