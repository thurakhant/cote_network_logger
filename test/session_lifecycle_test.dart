import 'dart:io';
import 'package:cote_network_logger/src/session.dart';
import 'package:cote_network_logger/src/core/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled never binds, captures or returns pairing URI', () async {
    final logger =
        NetworkLoggerSession(config: LoggerConfig(enabled: false, port: 0));
    expect(logger.isEnabled, isFalse);
    expect((await logger.start()).status, LoggerStartStatus.disabled);
    expect(logger.state, LoggerLifecycle.idle);
    expect(logger.pairingUri(), isNull);
    expect(logger.getCalls(), isEmpty);
    await logger.dispose();
  });
  test('concurrent starts share future and restart rotates credentials',
      () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    final first = logger.start();
    expect(identical(first, logger.start()), isTrue);
    final result = await first;
    expect(result.status, LoggerStartStatus.running);
    expect(result.dashboardUri!.host, '127.0.0.1');
    expect(result.dashboardUri!.port, greaterThan(0));
    expect(logger.dashboardUri!.fragment, isEmpty);
    final pairing = logger.pairingUri()!;
    expect(pairing.fragment, startsWith('token='));
    expect(
      logger.pairingUri(dashboardUri: Uri.parse('http://evil.test/')),
      isNull,
    );
    expect(logger.pairingUri(), pairing);
    await logger.stop();
    expect(logger.state, LoggerLifecycle.idle);
    expect(logger.dashboardUri, isNull);
    await logger.start();
    expect(logger.pairingUri()!.fragment, isNot(pairing.fragment));
    final client = HttpClient();
    final oldToken = Uri.splitQueryString(pairing.fragment)['token']!;
    final request =
        await client.getUrl(logger.dashboardUri!.resolve('/api/v2/session'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $oldToken');
    expect((await request.close()).statusCode, 401);
    client.close(force: true);
    await logger.dispose();
  });
  test('stop during startup cancels, dispose is terminal and idempotent',
      () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    final start = logger.start();
    final stop = logger.stop();
    expect((await start).status, LoggerStartStatus.cancelled);
    await stop;
    expect(logger.isRunning, isFalse);
    final next = logger.start();
    final dispose = logger.dispose();
    expect(
      (await next).status,
      anyOf(LoggerStartStatus.cancelled, LoggerStartStatus.disposed),
    );
    await dispose;
    await logger.dispose();
    expect(logger.state, LoggerLifecycle.disposed);
    expect((await logger.start()).status, LoggerStartStatus.disposed);
    expect(logger.getCalls(), isEmpty);
  });
  test('bind failure admits no capture, diagnostics cannot break app callback',
      () async {
    final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final logger = NetworkLoggerSession(
      config: LoggerConfig(
        port: occupied.port,
        onDiagnostic: (_) => throw StateError('ignored'),
      ),
    );
    expect((await logger.start()).status, LoggerStartStatus.addressInUse);
    final interceptor = CoteNetworkLogger(session: logger);
    interceptor.onRequest(
      RequestOptions(path: 'https://example.test/'),
      RequestInterceptorHandler(),
    );
    expect(logger.getCalls(), isEmpty);
    await logger.dispose();
    await occupied.close(force: true);
  });
  test('clear emits sanitized version event, dispose closes stream', () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    final events = <String>[];
    var closed = false;
    logger.changes.listen(
      (e) => events.add('${e.sessionId}:${e.version}'),
      onDone: () => closed = true,
    );
    await logger.start();
    final interceptor = CoteNetworkLogger(session: logger);
    interceptor.onRequest(
      RequestOptions(path: 'https://example.test/?token=SECRET'),
      RequestInterceptorHandler(),
    );
    expect(logger.getCalls(), hasLength(1));
    final generation = logger.getSnapshot().clearGeneration;
    logger.clear();
    expect(logger.getSnapshot().clearGeneration, generation + 1);
    expect(logger.getCalls(), isEmpty);
    await logger.dispose();
    expect(closed, isTrue);
    expect(events.join(), isNot(contains('SECRET')));
  });
  test('release gate requires compile opt-in and runtime false always wins',
      () {
    for (final debug in [false, true]) {
      for (final define in [false, true]) {
        expect(
          effectiveLoggerEnabled(
            runtimeEnabled: false,
            debugMode: debug,
            releaseOptIn: define,
          ),
          isFalse,
        );
        expect(
          effectiveLoggerEnabled(
            runtimeEnabled: true,
            debugMode: debug,
            releaseOptIn: define,
          ),
          debug || define,
        );
      }
    }
  });
  test('config rejects invalid ports and non-IPv4 advertised addresses', () {
    expect(() => LoggerConfig(port: -1), throwsArgumentError);
    expect(() => LoggerConfig(port: 65536), throwsArgumentError);
    for (final address in [
      'localhost',
      'http://1.2.3.4',
      '1.2.3.999',
      '::1',
      '1.2.3.4:80',
    ]) {
      expect(
        () => LoggerConfig(
          access: DashboardAccess.lan,
          advertisedAddress: address,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => LoggerConfig(advertisedAddress: '1.2.3.4'),
      throwsArgumentError,
    );
  });
  test('start during stop waits then opens fresh session', () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    await logger.start();
    final identity = logger.getSnapshot().sessionId;
    final stop = logger.stop();
    final restart = logger.start();
    await stop;
    expect((await restart).status, LoggerStartStatus.running);
    expect(logger.getSnapshot().sessionId, isNot(identity));
    await logger.dispose();
  });
  test('pre-start clear stays empty and paused listener cannot block disposal',
      () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    logger.clear();
    expect(logger.getSnapshot().version, 0);
    final subscription = logger.changes.listen((_) {})..pause();
    await logger.dispose().timeout(const Duration(seconds: 1));
    expect(logger.getSnapshot().sessionId, isEmpty);
    expect(logger.getSnapshot().version, 0);
    await subscription.cancel();
  });
  test('LAN advertised address must be a bound local interface', () async {
    final logger = NetworkLoggerSession(
      config: LoggerConfig(
        port: 0,
        access: DashboardAccess.lan,
        advertisedAddress: '203.0.113.2',
      ),
    );
    expect((await logger.start()).status, LoggerStartStatus.bindFailed);
    expect(logger.isRunning, isFalse);
    expect(logger.pairingUri(), isNull);
    await logger.dispose();
  });
  test('change listener can clear without reentrant stream errors', () async {
    final logger = NetworkLoggerSession(config: LoggerConfig(port: 0));
    await logger.start();
    final versions = <int>[];
    logger.changes.listen((change) {
      versions.add(change.version);
      if (change.version == 1) logger.clear();
    });
    CoteNetworkLogger(session: logger).onRequest(
      RequestOptions(path: 'https://example.test/'),
      RequestInterceptorHandler(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(logger.getCalls(), isEmpty);
    expect(versions, [1, 2]);
    await logger.dispose();
  });
}
