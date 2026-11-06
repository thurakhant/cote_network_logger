import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public URL is actual loopback binding and pairing is explicit',
      () async {
    final session = NetworkLoggerSession(config: LoggerConfig(port: 0));
    addTearDown(session.dispose);
    expect(session.dashboardUri, isNull);
    expect(session.pairingUri(), isNull);
    final result = await session.start();
    final uri = result.dashboardUri!;
    expect(uri.scheme, 'http');
    expect(uri.host, '127.0.0.1');
    expect(uri.port, greaterThan(0));
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
    expect(session.pairingUri()!.fragment, startsWith('token='));
  });
}
