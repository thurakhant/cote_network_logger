import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cote_network_logger/src/core/config.dart';
import 'package:cote_network_logger/src/core/limits.dart';
import 'package:cote_network_logger/src/core/models.dart';
import 'package:cote_network_logger/src/server/server_io.dart';

void main() {
  securityTests();
  test('HTTP notifications authenticate before opening NDJSON', () async {
    final h = await _harness();
    final denied = await h.request('GET', '/api/v2/events', auth: false);
    expect(denied.statusCode, 401);
    await denied.drain<void>();
    final response = await h.request('GET', '/api/v2/events');
    expect(response.statusCode, 200);
    expect(response.headers.contentType!.mimeType, 'application/x-ndjson');
    final lines = StreamIterator(
      utf8.decoder.bind(response).transform(const LineSplitter()),
    );
    expect(await lines.moveNext(), true);
    final initial = jsonDecode(lines.current);
    expect(initial['type'], 'authenticated');
    expect(initial['clientId'], isA<String>());
    await lines.cancel();
  });
  test('live server requires bearer before data, ETag and clear', () async {
    final store = CallStore(limits: const LoggerLimits());
    final changes = StreamController<LoggerChange>.broadcast();
    final server = IoSessionServer();
    final started = await server.start(
      LoggerConfig(port: 0),
      snapshot: () => store.snapshot,
      clear: store.clear,
      changes: changes.stream,
    );
    store.reset(started.sessionId);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.stop();
      await changes.close();
    });
    final uri = started.dashboardUri!.resolve('/api/v2/calls');
    final denied = await (await client.getUrl(uri)).close();
    expect(denied.statusCode, 401);
    expect(
      await utf8.decoder.bind(denied).join(),
      '{"schemaVersion":2,"error":{"code":"unauthorized"}}',
    );
    final token = Uri.splitQueryString(server.pairingUri()!.fragment)['token']!;
    final request = await client.getUrl(uri);
    request.headers.set('authorization', 'Bearer $token');
    final response = await request.close();
    expect(response.statusCode, 200);
    expect(response.headers.value('etag'), '"${started.sessionId}:0"');
    expect(
      jsonDecode(await utf8.decoder.bind(response).join())['calls'],
      isEmpty,
    );
  });
}

Future<_Harness> _harness({IoSessionServer? server}) async {
  final h = _Harness(server ?? IoSessionServer());
  final result = await h.server.start(
    LoggerConfig(port: 0),
    snapshot: () => h.store.snapshot,
    clear: h.store.clear,
    changes: h.changes.stream,
  );
  h.store.reset(result.sessionId);
  h.uri = result.dashboardUri!;
  h.token = Uri.splitQueryString(h.server.pairingUri()!.fragment)['token']!;
  addTearDown(h.close);
  return h;
}

class _Harness {
  _Harness(this.server);
  final IoSessionServer server;
  final store = CallStore(limits: const LoggerLimits());
  final changes = StreamController<LoggerChange>.broadcast();
  final client = HttpClient();
  late Uri uri;
  late String token;
  Future<HttpClientResponse> request(
    String method,
    String path, {
    bool auth = true,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final r = await client.openUrl(method, uri.resolve(path));
    if (auth) r.headers.set('authorization', 'Bearer $token');
    headers.forEach(r.headers.set);
    if (body != null) {
      r.contentLength = utf8.encode(body).length;
      r.write(body);
    }
    return r.close();
  }

  Future<StreamIterator<String>> events() async {
    final r = await request('GET', '/api/v2/events');
    expect(r.statusCode, 200);
    final lines =
        StreamIterator(utf8.decoder.bind(r).transform(const LineSplitter()));
    return lines;
  }

  Future<int> ack(Map initial, int version, {String? session}) async {
    final r = await request(
      'POST',
      '/api/v2/events/ack',
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'sessionId': session ?? initial['sessionId'],
        'clientId': initial['clientId'],
        'version': version,
      }),
    );
    await r.drain<void>();
    return r.statusCode;
  }

  Future<void> close() async {
    client.close(force: true);
    await server.stop();
    await changes.close();
  }
}

void securityTests() {
  test('origin host methods bodies legacy and unauthorized clear are rejected',
      () async {
    final h = await _harness();
    final cases = [
      ('GET', '/api/v2/calls', {'origin': 'null'}, 403),
      ('GET', '/api/v2/calls', {'origin': 'https://evil.test'}, 403),
      (
        'GET',
        '/api/v2/calls',
        {'host': 'localhost.evil.test:${h.uri.port}'},
        403
      ),
      ('POST', '/api/v2/calls', <String, String>{}, 405),
      ('GET', '/logs', <String, String>{}, 410),
      ('GET', '/missing', <String, String>{}, 404),
    ];
    for (final c in cases) {
      final r = await h.request(c.$1, c.$2, headers: c.$3);
      expect(r.statusCode, c.$4);
      final text = await utf8.decoder.bind(r).join();
      expect(text, isNot(contains(h.token)));
      expect(text, isNot(contains(h.store.snapshot.sessionId)));
    }
    final denied = await h.request('DELETE', '/api/v2/calls', auth: false);
    expect(denied.statusCode, 401);
    await denied.drain<void>();
    expect(h.store.snapshot.clearGeneration, 0);
    final body = await h.request('DELETE', '/api/v2/calls', body: 'x');
    expect(body.statusCode, 413);
    await body.drain<void>();
    final clear = await h.request('DELETE', '/api/v2/calls');
    expect(clear.statusCode, 200);
    expect(
      jsonDecode(await utf8.decoder.bind(clear).join())['clearGeneration'],
      1,
    );
    final etag = '"${h.store.snapshot.sessionId}:${h.store.snapshot.version}"';
    final unchanged = await h
        .request('GET', '/api/v2/calls', headers: {'if-none-match': etag});
    expect(unchanged.statusCode, 304);
    await unchanged.drain<void>();
    final noAuth = await h.request(
      'GET',
      '/api/v2/calls',
      auth: false,
      headers: {'if-none-match': etag},
    );
    expect(noAuth.statusCode, 401);
    await noAuth.drain<void>();
  });
  test('ten invalid attempts bound the shared rate limit', () async {
    final h = await _harness();
    for (var i = 0; i < 10; i++) {
      final r = await h.request('GET', '/api/v2/calls', auth: false);
      expect(r.statusCode, 401);
      await r.drain<void>();
    }
    final r = await h.request('GET', '/api/v2/calls');
    expect(r.statusCode, 429);
    await r.drain<void>();
  });
  test(
      'notifications coalesce, duplicate ACK is harmless and future ACK closes',
      () async {
    final h = await _harness();
    final lines = await h.events();
    expect(await lines.moveNext(), true);
    final initial = jsonDecode(lines.current) as Map;
    for (var i = 1; i <= 100; i++) {
      h.changes.add(CoreRecords.change(h.store.snapshot.sessionId, i));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await h.ack(initial, 0), 204);
    expect(await h.ack(initial, 0), 204);
    expect(await lines.moveNext(), true);
    expect(jsonDecode(lines.current)['version'], 100);
    expect(await h.ack(initial, 101), 400);
    expect(h.server.activeStreams, 0);
    await lines.cancel();
  });
  test('four streams maximum, initial ACK deadline releases slots', () async {
    final h = await _harness(
      server: IoSessionServer(ackTimeout: const Duration(milliseconds: 300)),
    );
    final lines = <StreamIterator<String>>[];
    for (var i = 0; i < 4; i++) {
      final stream = await h.events();
      await stream.moveNext();
      lines.add(stream);
    }
    final busy = await h.request('GET', '/api/v2/events');
    expect(busy.statusCode, 429);
    await busy.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(h.server.activeStreams, 0);
    for (final stream in lines) {
      await stream.cancel();
    }
  });
  test('only one snapshot runs and a timed out transfer releases its slot',
      () async {
    late _Harness h;
    Future<HttpClientResponse>? competing;
    h = await _harness(
      server: IoSessionServer(
        snapshotTimeout: const Duration(milliseconds: 20),
        onRecordEncoded: (_) {
          competing ??= h.request('GET', '/api/v2/calls');
        },
      ),
    );
    for (var i = 0; i < 100; i++) {
      h.store.admit(
        id: '$i',
        request: CoreRecords.request(
          method: 'GET',
          url: 'https://example.test/',
          body: CoreRecords.body(kind: BodyKind.text, content: 'a' * 60000),
        ),
        observedAt: DateTime.utc(2026),
      );
    }
    final response = await h.request('GET', '/api/v2/calls');
    // A short deadline may expire before or during body consumption.
    var interrupted = false;
    try {
      await response.drain<void>();
    } on HttpException {
      interrupted = true;
    }
    expect(
      interrupted,
      isTrue,
      reason: 'The short transfer deadline must abort the body.',
    );
    final busy = await competing!;
    expect(busy.statusCode, 429);
    await busy.drain<void>();
    h.store.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = await h.request('GET', '/api/v2/calls');
    expect(after.statusCode, 200);
    expect(jsonDecode(await utf8.decoder.bind(after).join())['calls'], isEmpty);
  });
  test('disconnect releases snapshot slot by configured deadline', () async {
    const deadline = Duration(milliseconds: 500);
    const cleanupBudget = Duration(seconds: 2);
    final h =
        await _harness(server: IoSessionServer(snapshotTimeout: deadline));
    for (var i = 0; i < 100; i++) {
      h.store.admit(
        id: '$i',
        request: CoreRecords.request(
          method: 'GET',
          url: 'https://example.test/',
          body: CoreRecords.body(kind: BodyKind.text, content: 'a' * 60000),
        ),
        observedAt: DateTime.utc(2026),
      );
    }
    final disconnected = HttpClient();
    final req = await disconnected.getUrl(h.uri.resolve('/api/v2/calls'));
    req.headers.set('authorization', 'Bearer ${h.token}');
    final first = await req.close();
    final sub = first.listen((_) {});
    await sub.cancel();
    disconnected.close(force: true);
    // Older supported SDKs may not surface idle EOF promptly. Cleanup must
    // still finish by the configured response deadline plus scheduling margin.
    final elapsed = Stopwatch()..start();
    HttpClientResponse? next;
    while (elapsed.elapsed < cleanupBudget) {
      next = await h.request('GET', '/api/v2/calls');
      if (next.statusCode == 200) break;
      expect(next.statusCode, 429);
      await next.drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(next!.statusCode, 200);
    expect(elapsed.elapsed, lessThan(cleanupBudget));
    expect(
      jsonDecode(await utf8.decoder.bind(next).join())['calls'],
      hasLength(100),
    );
  });
  test('ACK rejects invalid bodies, foreign origin and wrong session',
      () async {
    final h = await _harness();
    final lines = await h.events();
    await lines.moveNext();
    final initial = jsonDecode(lines.current) as Map;
    for (final entry in [
      ('x' * 513, 'application/json', 413),
      ('{}', 'text/plain', 415),
      ('{}', 'application/json', 400),
      (
        '{"clientId":"x","sessionId":"x","version":0,"extra":1}',
        'application/json',
        400
      ),
    ]) {
      final r = await h.request(
        'POST',
        '/api/v2/events/ack',
        headers: {'content-type': entry.$2},
        body: entry.$1,
      );
      expect(r.statusCode, entry.$3);
      await r.drain<void>();
    }
    final foreign = await h.request(
      'POST',
      '/api/v2/events/ack',
      headers: {
        'origin': 'https://evil.test',
        'content-type': 'application/json',
      },
      body: '{}',
    );
    expect(foreign.statusCode, 403);
    await foreign.drain<void>();
    expect(await h.ack(initial, 0, session: 'wrong'), 400);
    expect(h.server.activeStreams, 0);
    await lines.cancel();
  });
  test('upgrade requests rejected before any websocket frame parser', () async {
    final h = await _harness();
    final r = await h.request(
      'GET',
      '/api/v2/events',
      headers: {
        'connection': 'Upgrade',
        'upgrade': 'websocket',
        'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==',
        'sec-websocket-version': '13',
      },
    );
    expect(r.statusCode, 400);
    await r.drain<void>();
    expect(h.server.activeStreams, 0);
  });
  test('huge and fragmented upgrade payloads never open a notification stream',
      () async {
    final h = await _harness();
    for (final fragmented in [false, true]) {
      final socket = await Socket.connect(h.uri.host, h.uri.port);
      socket.write(
        'GET /api/v2/events HTTP/1.1\r\nHost: ${h.uri.authority}\r\nAuthorization: Bearer ${h.token}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n',
      );
      socket.add([
        fragmented ? 0x01 : 0x81,
        0xff,
        0x7f,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
      ]);
      socket.add(List.filled(128 * 1024, 0));
      final response = await utf8.decoder
          .bind(socket)
          .join()
          .timeout(const Duration(seconds: 2));
      expect(response, contains('400'));
      expect(response, isNot(contains('authenticated')));
      expect(h.server.activeStreams, 0);
    }
  });
  test('pre-header connections capped at twelve and slow headers expire',
      () async {
    final h = await _harness(
      server: IoSessionServer(authTimeout: const Duration(milliseconds: 400)),
    );
    final sockets = <Socket>[];
    for (var i = 0; i < 12; i++) {
      final s = await Socket.connect(h.uri.host, h.uri.port);
      s.write('GET / HTTP/1.1\r\nHost:');
      sockets.add(s);
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(h.server.activeConnections, 12);
    final extra = await Socket.connect(h.uri.host, h.uri.port);
    expect(await extra.toList(), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(h.server.activeConnections, 0);
    for (final s in sockets) {
      s.destroy();
    }
    final recovered = await h.request('GET', '/api/v2/session');
    expect(recovered.statusCode, 200);
    await recovered.drain<void>();
  });
  test('stalled fixed ACK body expires and stop releases streams and TCP slots',
      () async {
    final h = await _harness(
      server: IoSessionServer(authTimeout: const Duration(milliseconds: 150)),
    );
    final socket = await Socket.connect(h.uri.host, h.uri.port);
    socket.write(
      'POST /api/v2/events/ack HTTP/1.1\r\nHost: ${h.uri.authority}\r\nAuthorization: Bearer ${h.token}\r\nContent-Type: application/json\r\nContent-Length: 512\r\n\r\n{',
    );
    await socket.toList().timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.server.activeConnections, 0);
    final lines = await h.events();
    await lines.moveNext();
    await h.server.stop();
    expect(h.server.activeConnections, 0);
    expect(h.server.activeStreams, 0);
    await lines.cancel();
  });
  test(
      'finite lifetime bounds idle disconnect and reconnect has fresh client ID',
      () async {
    final h = await _harness(
      server:
          IoSessionServer(streamLifetime: const Duration(milliseconds: 180)),
    );
    final lines = await h.events();
    await lines.moveNext();
    final initial = jsonDecode(lines.current) as Map;
    expect(await h.ack(initial, 0), 204);
    expect(
      await lines.moveNext(),
      false,
      reason: 'Healthy idle lifetime ends with normal HTTP EOF',
    );
    expect(h.server.activeStreams, 0);
    final next = await h.events();
    await next.moveNext();
    final second = jsonDecode(next.current) as Map;
    expect(second['clientId'], isNot(initial['clientId']));
    expect(second['sessionId'], initial['sessionId']);
    expect(second['version'], 0);
    expect(await h.ack(second, 0), 204);
    await next.cancel();
    h.client.close(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(h.server.activeStreams, 0);
    expect(h.server.activeConnections, 0);
  });
  test('pipelined requests have only one response and chunked ACK is rejected',
      () async {
    final h = await _harness();
    final socket = await Socket.connect(h.uri.host, h.uri.port);
    final one =
        'GET /api/v2/session HTTP/1.1\r\nHost: ${h.uri.authority}\r\nAuthorization: Bearer ${h.token}\r\n\r\n';
    socket.write(one * 50);
    final text = await utf8.decoder.bind(socket).join();
    expect('HTTP/1.1 200'.allMatches(text).length, 1);
    final chunked = await Socket.connect(h.uri.host, h.uri.port);
    chunked.write(
      'POST /api/v2/events/ack HTTP/1.1\r\nHost: ${h.uri.authority}\r\nAuthorization: Bearer ${h.token}\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n',
    );
    final reply = await utf8.decoder.bind(chunked).join();
    expect(reply, contains('413'));
  });
  test(
      'snapshot keeps immutable records and headers across clear; Unicode is valid',
      () async {
    late _Harness h;
    var converted = 0;
    h = await _harness(
      server: IoSessionServer(
        onRecordEncoded: (_) {
          converted++;
          if (converted == 1) h.store.clear();
        },
      ),
    );
    for (var i = 0; i < 3; i++) {
      h.store.admit(
        id: '$i',
        request: CoreRecords.request(
          method: 'GET',
          url: 'https://example.test/',
          body: CoreRecords.body(
            kind: BodyKind.text,
            content: 'မြန်မာ 😀 " \\ \n',
          ),
        ),
        observedAt: DateTime.utc(2026),
      );
    }
    final version = h.store.snapshot.version;
    final r = await h.request('GET', '/api/v2/calls');
    expect(r.headers.value('etag'), '"${h.store.snapshot.sessionId}:$version"');
    final data = jsonDecode(await utf8.decoder.bind(r).join());
    expect(data['version'], version);
    expect(data['clearGeneration'], 0);
    expect(data['calls'], hasLength(3));
    expect(data['calls'][0]['request']['body']['content'], 'မြန်မာ 😀 " \\ \n');
    expect(converted, 3);
    expect(h.store.snapshot.calls, isEmpty);
    final next = await h.request('GET', '/api/v2/calls');
    expect(
      jsonDecode(await utf8.decoder.bind(next).join())['clearGeneration'],
      1,
    );
  });
}
