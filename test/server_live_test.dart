import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
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
      expect(await messages.moveNext().timeout(const Duration(seconds: 3)),
          isTrue);
      received
          .add(jsonDecode(messages.current as String) as Map<String, dynamic>);
    }
    expect(received.map((e) => e['type']), everyElement('log'));
    expect(received.last['log']['status'], 'completed');
    expect(received.last['log']['url'], 'https://example.test/live');
  });
}
