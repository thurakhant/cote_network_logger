import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'log_store.dart';
import 'dart:async';
import 'web_server/dashboard_template.dart';
import 'web_server/dashboard_script.dart';

/// A local web server that provides a dashboard for viewing network logs.
///
/// This server serves a static HTML dashboard and provides API endpoints
/// for accessing network activity logs. Only runs in debug mode and on
/// platforms that support server sockets (mobile, desktop).
///
/// **Platform Support:**
/// - ✅ Android, iOS, macOS, Windows, Linux
/// - ❌ Web (browsers don't support ServerSocket.bind)
class NetworkLogWebServer {
  NetworkLogWebServer._internal();
  static final NetworkLogWebServer _instance = NetworkLogWebServer._internal();

  /// Returns the singleton instance of NetworkLogWebServer.
  static NetworkLogWebServer get instance => _instance;

  static const String _host = '0.0.0.0';
  static const int _port = 3000;

  HttpServer? _server;
  bool _isRunning = false;

  // WebSocket clients
  final Set<WebSocket> _wsClients = <WebSocket>{};

  /// Checks if the current platform supports the web server.
  static bool get isPlatformSupported {
    if (kIsWeb) {
      return false; // Web platforms don't support ServerSocket.bind
    }

    // Check if we're on a supported platform
    try {
      // This will throw on unsupported platforms
      return Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Starts the web server if not already running.
  ///
  /// Only starts in debug mode and on supported platforms. The server will be available at:
  /// - **Android Emulator**: http://localhost:3000 (from host Mac browser)
  /// - **Physical Android**: http://YOUR_DEVICE_IP:3000 (find IP in device settings)
  /// - **iOS Simulator**: http://localhost:3000 (from host Mac browser)
  /// - **Physical iOS**: http://YOUR_DEVICE_IP:3000 (find IP in device settings)
  /// - **Desktop**: http://localhost:3000
  ///
  /// **Dashboard Features:**
  /// - 🚀 Real-time network monitoring
  /// - 📊 Beautiful Material Design interface
  /// - 🔍 Advanced filtering and search
  /// - 📱 Mobile-responsive design
  /// - ⚡ Fast performance with minimal load time
  ///
  /// Returns true if the server started successfully, false otherwise.
  Future<bool> start() async {
    if (!kDebugMode) return false;
    if (!isPlatformSupported) return false;
    if (_isRunning) return false;

    try {
      debugPrint('🚀 NetworkLogWebServer: Starting server on $_host:$_port...');
      final handler = _createHandler();
      _server = await HttpServer.bind(_host, _port);
      _isRunning = true;

      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/ws' &&
            WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _wsClients.add(socket);
          socket.add(
            jsonEncode(<String, dynamic>{
              'type': 'init',
              'logs': NetworkLogStore.instance.getLogs(),
            }),
          );
          socket.done.then((_) => _wsClients.remove(socket));
          return;
        }
        // Convert HttpHeaders to Map<String, String>
        final headers = <String, String>{};
        request.headers.forEach((name, values) {
          if (values.isNotEmpty) headers[name] = values.join(',');
        });
        final shelfRequest = Request(
          request.method,
          request.requestedUri,
          headers: headers,
          body: request,
          context: {'shelf.io.request': request},
        );
        final shelfResponse = await handler(shelfRequest);
        // Write shelf response to HttpResponse
        request.response.statusCode = shelfResponse.statusCode;
        shelfResponse.headers.forEach((name, value) {
          request.response.headers.set(name, value);
        });
        await shelfResponse.read().forEach(request.response.add);
        await request.response.close();
      });

      debugPrint('✅ NetworkLogWebServer: Server started successfully!');
      debugPrint('🌐 Network Logger Dashboard: $dashboardUrl');
      await _printAccessInstructions();
      return true;
    } catch (e) {
      debugPrint('❌ NetworkLogWebServer: Failed to start server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Prints platform-specific instructions for accessing the dashboard.
  Future<void> _printAccessInstructions() async {
    final deviceIp = await _getLocalIpAddress();

    debugPrint('');
    debugPrint('📱 ACCESS DASHBOARD:');

    if (Platform.isIOS) {
      debugPrint('');
      debugPrint('🔧 IMPORTANT: Enable Local Network Access');
      debugPrint('   Go to: Settings > Privacy & Security > Local Network');
      debugPrint('   Enable access for your app');
      debugPrint('');
      debugPrint(
        '📱 iOS Simulator: Open http://localhost:3000 in your Mac browser',
      );
      if (deviceIp != null) {
        debugPrint(
          '📱 Physical iPhone: Open http://$deviceIp:3000 in Safari',
        );
        debugPrint(
          '   ✅ Your device IP: $deviceIp',
        );
      } else {
        debugPrint(
          '📱 Physical iPhone: Open http://YOUR_MAC_IP:3000 in Safari',
        );
        debugPrint(
          '   💡 Find your Mac IP: System Settings > Wi-Fi > Details > TCP/IP',
        );
      }
      debugPrint(
        '   💡 Both devices must be on the same Wi-Fi network',
      );
      debugPrint(
        '   💡 Alternative: Use your Mac\'s computer name: http://YOUR-MAC-NAME.local:3000',
      );
    } else if (Platform.isAndroid) {
      debugPrint(
        '📱 Android Emulator: Open http://10.0.2.2:3000 in the emulator browser',
      );
      if (deviceIp != null) {
        debugPrint('📱 Physical Android: Open http://$deviceIp:3000 in Chrome');
        debugPrint('   ✅ Your device IP: $deviceIp');
      } else {
        debugPrint(
          '📱 Physical Android: Open http://YOUR_MAC_IP:3000 in Chrome',
        );
        debugPrint('   💡 Find your Mac IP: System Preferences > Network');
      }
      debugPrint('   💡 Both devices must be on the same Wi-Fi network');
    } else {
      debugPrint('💻 Desktop: Open http://localhost:3000 in your browser');
      if (deviceIp != null) {
        debugPrint('   ✅ Network access: http://$deviceIp:3000');
      }
    }

    debugPrint('');
    debugPrint(
      '🎨 Features: Real-time monitoring, beautiful UI, filtering, search',
    );
    debugPrint('🔥 Make HTTP requests in your app to see them appear!');
    debugPrint('');
  }

  /// Stops the web server if running.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
    }
  }

  /// Returns whether the server is currently running.
  bool get isRunning => _isRunning;

  /// Returns the URL where the dashboard is accessible.
  String get dashboardUrl {
    if (Platform.isIOS) {
      return 'http://localhost:3000 (simulator) or http://YOUR_MAC_IP:3000 (physical device)';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000 (emulator) or http://YOUR_MAC_IP:3000 (physical device)';
    }
    return 'http://localhost:$_port';
  }

  /// Broadcasts a new log entry to all connected WebSocket clients.
  void broadcastLog(Map<String, dynamic> logEntry) {
    if (!kDebugMode || _wsClients.isEmpty) return;

    final message = jsonEncode({
      'type': 'log',
      'log': logEntry,
    });

    for (final client in _wsClients) {
      try {
        client.add(message);
      } catch (e) {
        debugPrint('❌ NetworkLogWebServer: Failed to broadcast to client: $e');
        _wsClients.remove(client);
      }
    }
  }

  /// Creates the main request handler for the server.
  Handler _createHandler() {
    final staticHandler = _createStaticHandler();
    final apiHandler = _createApiHandler();
    return Cascade().add(apiHandler).add(staticHandler).handler;
  }

  /// Creates handler for serving static web assets.
  Handler _createStaticHandler() {
    return (Request request) {
      if (request.url.path == '' || request.url.path == '/') {
        // Get the HTML template and inject the JavaScript
        final html = DashboardTemplate.getHtml();
        final script = DashboardScript.getScript();
        final finalHtml = html
            .replaceAll('{{DASHBOARD_SCRIPT}}', script)
            .replaceAll('{{TIMESTAMP}}', '');

        return Response.ok(
          finalHtml,
          headers: {
            'content-type': 'text/html',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        );
      }
      return Response.notFound('Not found');
    };
  }

  /// Creates handler for API endpoints.
  Handler _createApiHandler() {
    return (Request request) async {
      // Handle CORS
      final response = await _handleCors(request);
      if (response != null) return response;

      switch (request.url.path) {
        case 'logs':
          return _handleLogsEndpoint(request);
        case 'logs/clear':
          return _handleClearLogsEndpoint(request);
        default:
          return Response.notFound('API endpoint not found');
      }
    };
  }

  /// Handles CORS preflight requests.
  Future<Response?> _handleCors(Request request) async {
    final headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: headers);
    }

    return null;
  }

  /// Handles the /logs endpoint - returns all network logs as JSON.
  Response _handleLogsEndpoint(Request request) {
    try {
      final logs = NetworkLogStore.instance.getLogs();
      final jsonResponse = jsonEncode({
        'logs': logs,
        'count': logs.length,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return Response.ok(
        jsonResponse,
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to retrieve logs'}),
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }
  }

  /// Handles the /logs/clear endpoint - clears all stored logs.
  Response _handleClearLogsEndpoint(Request request) {
    if (request.method != 'POST') {
      return Response(405, body: 'Method not allowed');
    }

    try {
      NetworkLogStore.instance.clearLogs();

      return Response.ok(
        jsonEncode({'message': 'Logs cleared successfully'}),
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to clear logs'}),
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }
  }

  /// Gets the device's local IP address for network access
  Future<String?> _getLocalIpAddress() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Prefer Wi-Fi interfaces on mobile
            if (Platform.isIOS || Platform.isAndroid) {
              if (interface.name.toLowerCase().contains('en0') ||
                  interface.name.toLowerCase().contains('wlan') ||
                  interface.name.toLowerCase().contains('wifi')) {
                return addr.address;
              }
            } else {
              return addr.address;
            }
          }
        }
      }
      // Fallback: return any non-loopback IPv4 address
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to get local IP address: $e');
    }
    return null;
  }
}
