import 'dart:io';
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard URL is one reachable local URL after startup', () async {
    final server = NetworkLogWebServer.instance;
    expect(server.dashboardUrl, 'http://localhost:3000');
    expect(await server.start(), isTrue);
    addTearDown(server.stop);
    final uri = Uri.parse(server.dashboardUrl);
    expect(uri.scheme, 'http');
    expect(uri.port, 3000);
    expect(uri.path, isEmpty);
    expect(uri.hasQuery, isFalse);
    expect(uri.host, isNot(contains('YOUR_')));
    final addresses =
        (await NetworkInterface.list(type: InternetAddressType.IPv4))
            .expand((interface) => interface.addresses)
            .map((address) => address.address);
    expect(uri.host == 'localhost' || addresses.contains(uri.host), isTrue);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final response = await (await client.getUrl(uri)).close();
    expect(response.statusCode, 200);
    await response.drain<void>();
  });
}
