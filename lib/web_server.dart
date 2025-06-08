import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'dart:async';
import 'web_server/dashboard_template.dart';
import 'web_server/dashboard_script.dart';
import 'cote_network_logger.dart';

/// A local web server that provides a dashboard for viewing network logs.
///
/// This server serves a static HTML dashboard and provides API endpoints
/// for accessing network activity logs. Only runs in debug mode or staging
/// environment and on platforms that support server sockets (mobile, desktop).
///
/// **Platform Support:**
/// - ✅ Android, iOS, macOS, Windows, Linux
/// - ❌ Web (browsers don't support ServerSocket.bind)
///
/// **Environment Support:**
/// - ✅ Debug mode (always enabled)
/// - ✅ Staging environment (when STAGING_ENV=true)
/// - ❌ Production environment (always disabled)
class NetworkLogWebServer {
  NetworkLogWebServer._internal();
  static final NetworkLogWebServer _instance = NetworkLogWebServer._internal();

  /// Returns the singleton instance of NetworkLogWebServer.
  static NetworkLogWebServer get instance => _instance;

  HttpServer? _server;
  bool _isRunning = false;
  Timer? _monitorTimer;

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
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Starts the web server if not already running.
  ///
  /// Only starts in debug mode or staging environment and on supported platforms. The server will be available at:
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
    if (!NetworkLoggerConfig.isEnabled) {
      return false;
    }
    if (!isPlatformSupported) {
      return false;
    }
    if (_isRunning) {
      return false;
    }

    try {
      if (kDebugMode) {
        debugPrint('🚀 NetworkLogWebServer: Starting server on ${NetworkLoggerConfig.serverHost}:${NetworkLoggerConfig.serverPort}...');
      }
      final handler = _createHandler();
      _server = await HttpServer.bind(NetworkLoggerConfig.serverHost, NetworkLoggerConfig.serverPort);
      _isRunning = true;

      _server!.listen((HttpRequest request) async {
        try {
          if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            _handleWebSocketConnection(socket);
            return;
          }

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
          request.response.statusCode = shelfResponse.statusCode;
          shelfResponse.headers.forEach((name, value) {
            request.response.headers.set(name, value);
          });
          await shelfResponse.read().forEach(request.response.add);
          await request.response.close();
        } catch (e) {
          if (kDebugMode) debugPrint('❌ NetworkLogWebServer: Error handling request: $e');
          request.response.statusCode = 500;
          request.response.write('Internal Server Error');
          await request.response.close();
        }
      });

      _startMonitoring();
      if (kDebugMode) {
        debugPrint('✅ NetworkLogWebServer: Server started successfully!');
        debugPrint('🌐 Network Logger Dashboard: $dashboardUrl');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NetworkLogWebServer: Failed to start server: $e');
      _isRunning = false;
      return false;
    }
  }

  void _handleWebSocketConnection(WebSocket socket) {
    _wsClients.add(socket);

    // Send initial logs with more detailed information
    final logs = NetworkLogStore.instance.getLogs();
    final enhancedLogs = logs.map((log) {
      return {
        ...log,
        'displayStatus': _getDisplayStatus(log),
        'displayType': _getDisplayType(log),
        'displayMethod': _getDisplayMethod(log),
      };
    }).toList();

    socket.add(
      jsonEncode(
        <String, dynamic>{
          'type': 'init',
          'logs': enhancedLogs,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );

    socket.listen(
      (data) {
        // WebSocket message received - no action needed
      },
      onError: (error) {
        _wsClients.remove(socket);
      },
      onDone: () {
        _wsClients.remove(socket);
      },
    );
  }

  String _getDisplayStatus(Map<String, dynamic> log) {
    final status = log['status'] as String?;
    final statusCode = log['statusCode'] as int?;

    if (status == 'error') return 'error';
    if (status == 'pending') return 'pending';
    if (statusCode != null) {
      if (statusCode >= 200 && statusCode < 300) return 'success';
      if (statusCode >= 400) return 'error';
    }
    return 'unknown';
  }

  String _getDisplayType(Map<String, dynamic> log) {
    final type = log['type'] as String?;
    if (type == 'request') return 'Request';
    if (type == 'response') return 'Response';
    if (type == 'error') return 'Error';
    return 'Unknown';
  }

  String _getDisplayMethod(Map<String, dynamic> log) {
    final method = log['method'] as String?;
    if (method == null) return 'UNKNOWN';
    return method.toUpperCase();
  }

  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Background monitoring - no logging needed in production
    });
  }

  /// Stops the web server if running.
  Future<void> stop() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;

    for (final client in _wsClients) {
      try {
        await client.close();
      } catch (e) {
        // Silent close - errors not critical during shutdown
      }
    }
    _wsClients.clear();

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
    return 'http://localhost:${NetworkLoggerConfig.serverPort}';
  }

  /// Broadcasts a new log entry to all connected WebSocket clients.
  void broadcastLog(Map<String, dynamic> logEntry) {
    if (!kDebugMode) return;
    if (_wsClients.isEmpty) return;

    try {
      // Enhance the log entry with display information
      final enhancedLog = {
        ...logEntry,
        'displayStatus': _getDisplayStatus(logEntry),
        'displayType': _getDisplayType(logEntry),
        'displayMethod': _getDisplayMethod(logEntry),
      };

      final message = jsonEncode({
        'type': 'log',
        'log': enhancedLog,
        'timestamp': DateTime.now().toIso8601String(),
      });

      for (final client in _wsClients) {
        try {
          client.add(message);
        } catch (e) {
          _wsClients.remove(client);
        }
      }
    } catch (e) {
      // Silent fail - broadcast is not critical
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
    // Try multiple possible paths for the dashboard build
    final possiblePaths = [
      // If running from project root
      'dashboard/build/web',
      // If running from example directory
      '../dashboard/build/web',
      // Absolute path construction attempts
      '${Directory.current.path}/dashboard/build/web',
      '${Directory.current.path}/../dashboard/build/web',
    ];

    Directory? dashboardDir;

    // Try each possible path until we find one that exists
    for (final path in possiblePaths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dashboardDir = dir;
        break;
      }
    }

    if (dashboardDir != null) {
      // Serve the Flutter Web dashboard build with proper MIME types
      return Pipeline().addMiddleware(_mimeTypeMiddleware()).addHandler(
            createStaticHandler(
              dashboardDir.path,
              defaultDocument: 'index.html',
              serveFilesOutsidePath: true,
            ),
          );
    } else {
      // Fallback to the original HTML template if Flutter build doesn't exist
      return (Request request) {
        if (request.url.path == '' || request.url.path == '/') {
          // Get the HTML template and inject the JavaScript
          final html = DashboardTemplate.getHtml();
          final script = DashboardScript.getScript();
          final finalHtml = html.replaceAll('{{DASHBOARD_SCRIPT}}', script).replaceAll('{{TIMESTAMP}}', '');

          return Response.ok(
            finalHtml,
            headers: const {
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
  }

  /// Middleware to set correct MIME types for Flutter Web assets
  Middleware _mimeTypeMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);

        // Set correct MIME types for Flutter Web files
        final path = request.url.path.toLowerCase();
        final Map<String, String> headers = Map.from(response.headers);

        if (path.endsWith('.js')) {
          headers['content-type'] = 'application/javascript; charset=utf-8';
          headers['cache-control'] = 'no-cache, no-store, must-revalidate';
        } else if (path.endsWith('.html')) {
          headers['content-type'] = 'text/html; charset=utf-8';
          headers['cache-control'] = 'no-cache, no-store, must-revalidate';
        } else if (path.endsWith('.css')) {
          headers['content-type'] = 'text/css; charset=utf-8';
        } else if (path.endsWith('.json')) {
          headers['content-type'] = 'application/json; charset=utf-8';
        } else if (path.endsWith('.png')) {
          headers['content-type'] = 'image/png';
        } else if (path.endsWith('.ico')) {
          headers['content-type'] = 'image/x-icon';
        } else if (path.endsWith('.wasm')) {
          headers['content-type'] = 'application/wasm';
        } else if (path.endsWith('.map')) {
          headers['content-type'] = 'application/json; charset=utf-8';
        }

        // Add CORS headers for all responses
        headers['Access-Control-Allow-Origin'] = '*';
        headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
        headers['Access-Control-Allow-Headers'] = 'Content-Type';

        return response.change(headers: headers);
      };
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
}
