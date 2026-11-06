import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
  test(
      'public authenticated server preserves binary summaries and live updates',
      () async {
    final session = NetworkLoggerSession(config: LoggerConfig(port: 0));
    await session.start();
    addTearDown(session.dispose);
    final uri = session.dashboardUri!;
    final token =
        Uri.splitQueryString(session.pairingUri()!.fragment)['token']!;
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<HttpClientResponse> get(String path, {bool auth = true}) async {
      final req = await client.getUrl(uri.resolve(path));
      if (auth) req.headers.set('authorization', 'Bearer $token');
      return req.close();
    }

    final unauthorized = await get('/api/v2/calls', auth: false);
    expect(unauthorized.statusCode, 401);
    await unauthorized.drain<void>();
    final stream = await get('/api/v2/events');
    final messages = StreamIterator<String>(
      stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
    addTearDown(messages.cancel);
    expect(await messages.moveNext(), isTrue);
    final init = jsonDecode(messages.current);
    expect(init['type'], 'authenticated');
    final ack = await client.postUrl(uri.resolve('/api/v2/events/ack'));
    ack.headers.set('authorization', 'Bearer $token');
    ack.headers.contentType = ContentType.json;
    final data = utf8.encode(
      jsonEncode({
        'sessionId': init['sessionId'],
        'clientId': init['clientId'],
        'version': init['version'],
      }),
    );
    ack.contentLength = data.length;
    ack.add(data);
    final ackResult = await ack.close();
    expect(ackResult.statusCode, 204);
    await ackResult.drain<void>();
    final dio = Dio()
      ..interceptors.add(CoteNetworkLogger(session: session))
      ..httpClientAdapter =
          FakeAdapter((_) => ResponseBody.fromBytes([1, 2, 3], 200));
    addTearDown(dio.close);
    await dio.post(
      'https://example.test/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes([4, 5], filename: 'a.bin'),
      }),
      options: Options(responseType: ResponseType.bytes),
    );
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(jsonDecode(messages.current)['type'], 'changed');
    final response = await get('/api/v2/calls');
    expect(response.statusCode, 200);
    final payload = jsonDecode(await utf8.decoder.bind(response).join());
    expect(payload['calls'].length, 1);
    expect(payload['calls'][0]['request']['body']['kind'], 'multipartSummary');
    expect(payload['calls'][0]['response']['body']['kind'], 'binarySummary');
    expect(payload['calls'][0]['state'], 'completed');
    await session.stop();
    expect(session.isRunning, isFalse);
    try {
      expect(
        await messages.moveNext().timeout(const Duration(seconds: 3)),
        isFalse,
      );
    } on HttpException {
      // Stop may abort an HTTP stream before its terminating chunk.
      expect(session.isRunning, isFalse);
    }
  });
}
