import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard URL has a usable localhost fallback before discovery', () {
    final uri = Uri.parse(NetworkLogWebServer.instance.dashboardUrl);
    expect(uri.scheme, 'http');
    expect(uri.host, 'localhost');
    expect(uri.port, NetworkLoggerConfig.serverPort);
    expect(uri.path, isEmpty);
    expect(uri.hasQuery, isFalse);
  });
}
