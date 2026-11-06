import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public session is explicit, disabled and disposable', () async {
    final session = NetworkLoggerSession(config: LoggerConfig(enabled: false));
    final dio = Dio()..interceptors.add(CoteNetworkLogger(session: session));
    expect((await session.start()).status, LoggerStartStatus.disabled);
    expect(session.getSnapshot().calls, isEmpty);
    expect(session.dashboardUri, isNull);
    await session.dispose();
    dio.close();
    expect(session.state, LoggerLifecycle.disposed);
  });
}
