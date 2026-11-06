import 'package:flutter_test/flutter_test.dart';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'interceptor_flow_test.dart' show FakeAdapter;

void main() {
  test('sessions isolate records, bound count and clear snapshots', () async {
    final session = NetworkLoggerSession(
      config: LoggerConfig(port: 0, limits: const LoggerLimits(maxCalls: 2)),
    );
    final other = NetworkLoggerSession(config: LoggerConfig(port: 0));
    addTearDown(session.dispose);
    addTearDown(other.dispose);
    expect(session.isRunning, isFalse);
    expect(session.dashboardUri, isNull);
    await session.start();
    await other.start();
    final dio = Dio()
      ..interceptors.add(CoteNetworkLogger(session: session))
      ..httpClientAdapter =
          FakeAdapter((_) => ResponseBody.fromString('{}', 200));
    addTearDown(dio.close);
    for (var i = 0; i < 3; i++) {
      await dio.get('https://example.test/$i');
    }
    expect(session.getCalls().length, 2);
    expect(other.getCalls(), isEmpty);
    final before = session.getSnapshot();
    session.clear();
    expect(session.getCalls(), isEmpty);
    expect(before.calls.length, 2);
    expect(session.getSnapshot().clearGeneration, before.clearGeneration + 1);
    await session.stop();
    expect(session.isRunning, isFalse);
    expect(session.dashboardUri, isNull);
  });
}
