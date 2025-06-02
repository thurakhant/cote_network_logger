import 'package:flutter_test/flutter_test.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

void main() {
  group('NetworkLogStore', () {
    setUp(() {
      // Clear logs before each test to ensure clean state
      NetworkLogStore.instance.clearLogs();
    });

    test('should be a singleton', () {
      final store1 = NetworkLogStore.instance;
      final store2 = NetworkLogStore.instance;
      expect(store1, equals(store2));
    });

    test('should add and retrieve logs', () {
      final store = NetworkLogStore.instance;

      final testLog = {
        'id': '123',
        'type': 'request',
        'timestamp': DateTime.now().toIso8601String(),
        'method': 'GET',
        'url': 'https://example.com',
      };

      store.upsertLog(testLog['id'] as String, testLog);
      final logs = store.getLogs();

      expect(logs.length, equals(1));
      expect(logs.first['id'], equals('123'));
      expect(logs.first['type'], equals('request'));
    });

    test('should respect max log entries limit', () {
      final store = NetworkLogStore.instance;

      // Add more than the limit
      for (int i = 0; i < 250; i++) {
        store.upsertLog(
          i.toString(),
          {
            'id': i.toString(),
            'type': 'request',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      final logs = store.getLogs();
      expect(logs.length, equals(200)); // Should be limited to 200
    });

    test('should clear all logs', () {
      final store = NetworkLogStore.instance;

      // Add some logs
      store.upsertLog(
        '1',
        {'id': '1', 'type': 'request'},
      );
      store.upsertLog(
        '2',
        {'id': '2', 'type': 'response'},
      );

      expect(store.logCount, equals(2));

      // Clear logs
      store.clearLogs();
      expect(store.logCount, equals(0));
      expect(store.getLogs(), isEmpty);
    });
  });

  group('CoteNetworkLogger', () {
    test('should create interceptor instance', () {
      const interceptor = CoteNetworkLogger();
      expect(interceptor, isNotNull);
      expect(interceptor, isA<CoteNetworkLogger>());
    });
  });

  group('NetworkLogWebServer', () {
    test('should be a singleton', () {
      final server1 = NetworkLogWebServer.instance;
      final server2 = NetworkLogWebServer.instance;
      expect(server1, equals(server2));
    });

    test('should initially not be running', () {
      final server = NetworkLogWebServer.instance;
      expect(server.isRunning, isFalse);
    });

    test('should provide dashboard URL', () {
      final server = NetworkLogWebServer.instance;
      expect(server.dashboardUrl, equals('http://localhost:3000'));
    });
  });

  group('Public API', () {
    test('should provide start server function', () {
      expect(startNetworkLogServer, isA<Function>());
    });

    test('should provide stop server function', () {
      expect(stopNetworkLogServer, isA<Function>());
    });

    test('should provide server running check function', () {
      expect(isNetworkLogServerRunning, isA<Function>());
    });

    test('should provide dashboard URL function', () {
      expect(getNetworkLogDashboardUrl, isA<Function>());
    });
  });
}
