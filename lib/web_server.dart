import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'log_store.dart';
import 'dart:async';

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
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux;
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
        if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _wsClients.add(socket);
          socket.add(jsonEncode({
            'type': 'init',
            'logs': NetworkLogStore.instance.getLogs(),
          }));
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

      _printAccessInstructions();
      return true;
    } catch (e) {
      debugPrint('❌ NetworkLogWebServer: Failed to start server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Prints platform-specific instructions for accessing the dashboard.
  void _printAccessInstructions() {
    debugPrint('✅ NetworkLogWebServer: Server started successfully!');
    debugPrint('');
    debugPrint('🌐 ACCESS DASHBOARD:');

    if (Platform.isAndroid) {
      debugPrint('📱 Android Emulator: Open http://10.0.2.2:3000 in the emulator browser.');
      debugPrint('📱 Physical Android Device: Open http://YOUR_MAC_IP:3000 in Chrome (find your Mac IP in System Preferences > Network).');
    } else if (Platform.isIOS) {
      debugPrint('📱 iOS Simulator: Open http://localhost:3000 in your Mac browser.');
      debugPrint('📱 Physical iOS Device: Open http://YOUR_MAC_IP:3000 in Safari/Chrome (find your Mac IP in System Preferences > Network).');
    } else {
      debugPrint('💻 Desktop: Open http://localhost:3000 in your browser.');
    }

    debugPrint('');
    debugPrint('🎨 Features: Real-time monitoring, beautiful UI, filtering, search');
    debugPrint('🔥 Make HTTP requests in your app to see them appear!');
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
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000 (emulator) or http://YOUR_MAC_IP:3000 (physical device)';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000 (simulator) or http://YOUR_MAC_IP:3000 (physical device)';
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
    // In a real package, you would serve from the package's web_assets directory
    // For now, we'll serve a simple HTML response directly
    return (Request request) {
      if (request.url.path == '' || request.url.path == '/') {
        return Response.ok(
          _getIndexHtml(),
          headers: {'content-type': 'text/html'},
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

  /// Returns the HTML content for the dashboard.
  String _getIndexHtml() {
    // ignore: unnecessary_string_escapes
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Logger Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Inter', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #2d3748;
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .dashboard-container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: #2d3748;
            padding: 24px;
            text-align: center;
            border-radius: 16px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            margin-bottom: 24px;
        }
        
        .header h1 {
            font-size: 32px;
            font-weight: 700;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
        }
        
        .header p {
            color: #718096;
            font-size: 16px;
        }
        
        .controls {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 16px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            margin-bottom: 24px;
        }
        
        .controls-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            margin-bottom: 16px;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .stat {
            background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%);
            padding: 12px 20px;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 600;
            border: 1px solid #e2e8f0;
        }
        
        .stat strong {
            color: #667eea;
            font-size: 18px;
        }
        
        .button-group {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 12px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
            box-shadow: 0 4px 16px rgba(102, 126, 234, 0.3);
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
        }
        
        .btn.danger {
            background: linear-gradient(135deg, #e53e3e 0%, #c53030 100%);
            box-shadow: 0 4px 16px rgba(229, 62, 62, 0.3);
        }
        
        .btn.danger:hover {
            box-shadow: 0 8px 24px rgba(229, 62, 62, 0.4);
        }
        
        .search-filter {
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .search-input {
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            width: 250px;
            transition: all 0.3s ease;
            background: white;
        }
        
        .search-input:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .filter-select {
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 14px;
            background: white;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .filter-select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 16px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        
        .table-container {
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        
        th, td {
            padding: 16px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        
        th {
            background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%);
            font-weight: 700;
            color: #2d3748;
            position: sticky;
            top: 0;
            z-index: 10;
            border-bottom: 2px solid #e2e8f0;
        }
        
        tr {
            transition: all 0.2s ease;
            cursor: pointer;
        }
        
        tr:hover {
            background: rgba(102, 126, 234, 0.05);
        }
        
        tr.expanded {
            background: rgba(102, 126, 234, 0.08);
        }
        
        .type-badge {
            padding: 6px 12px;
            border-radius: 8px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .type-request {
            background: linear-gradient(135deg, #3182ce 0%, #2c5282 100%);
            color: white;
        }
        
        .type-response {
            background: linear-gradient(135deg, #38a169 0%, #2f855a 100%);
            color: white;
        }
        
        .type-error {
            background: linear-gradient(135deg, #e53e3e 0%, #c53030 100%);
            color: white;
        }
        
        .method {
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }
        
        .method.GET { background: #c6f6d5; color: #22543d; }
        .method.POST { background: #fed7aa; color: #9c4221; }
        .method.PUT { background: #bee3f8; color: #2a4365; }
        .method.DELETE { background: #fed7d7; color: #742a2a; }
        .method.PATCH { background: #e9d8fd; color: #553c9a; }
        
        .url {
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            font-size: 13px;
            max-width: 400px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            color: #4a5568;
        }
        
        .status-code {
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }
        
        .status-2xx { background: #c6f6d5; color: #22543d; }
        .status-3xx { background: #feebc8; color: #744210; }
        .status-4xx { background: #fed7d7; color: #742a2a; }
        .status-5xx { background: #e9d8fd; color: #553c9a; }
        
        .timestamp {
            font-size: 12px;
            color: #718096;
            white-space: nowrap;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
        }
        
        .details-row {
            background: #f7fafc;
            border-top: 1px solid #e2e8f0;
        }
        
        .details-content {
            padding: 24px;
            background: #f7fafc;
        }
        
        .empty-state {
            text-align: center;
            padding: 80px 20px;
            color: #718096;
        }
        
        .empty-state h3 {
            margin-bottom: 12px;
            font-size: 24px;
            font-weight: 600;
        }
        
        .empty-state p {
            font-size: 16px;
            max-width: 400px;
            margin: 0 auto;
        }
        
        .loading {
            text-align: center;
            padding: 60px;
            color: #718096;
            font-size: 18px;
        }
        
        .expand-icon {
            transition: transform 0.3s ease;
            margin-right: 8px;
            font-size: 12px;
        }
        
        .expanded .expand-icon {
            transform: rotate(90deg);
        }
        
        pre {
            white-space: pre-wrap;
            word-break: break-word;
            background: #1a202c;
            color: #e2e8f0;
            padding: 16px;
            border-radius: 8px;
            font-size: 13px;
            max-height: 400px;
            overflow-y: auto;
            font-family: 'SF Mono', 'Monaco', 'Menlo', 'Consolas', monospace;
            line-height: 1.5;
            border: 1px solid #2d3748;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .details-content {
            padding: 24px;
            background: #f7fafc;
        }
        
        .details-content h4 {
            color: #2d3748;
            font-size: 16px;
            font-weight: 700;
            margin-bottom: 12px;
            padding-bottom: 8px;
            border-bottom: 2px solid #e2e8f0;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .details-content h5 {
            color: #4a5568;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 8px;
            margin-top: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .content-section {
            margin-bottom: 20px;
        }
        
        .json-content {
            background: linear-gradient(135deg, #1a202c 0%, #2d3748 100%);
            color: #e2e8f0;
            padding: 16px;
            border-radius: 12px;
            font-size: 12px;
            line-height: 1.6;
            border: 1px solid #4a5568;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            position: relative;
            overflow-x: auto;
        }
        
        .expandable-content {
            transition: max-height 0.3s ease;
        }
        
        .expand-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 11px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s ease;
        }
        
        .expand-btn:hover {
            background: #5a67d8;
            transform: translateY(-1px);
        }
        
        /* JSON Syntax Highlighting */
        .json-content .json-key {
            color: #81e6d9;
            font-weight: 600;
        }
        
        .json-content .json-string {
            color: #68d391;
        }
        
        .json-content .json-number {
            color: #63b3ed;
        }
        
        .json-content .json-boolean {
            color: #f6ad55;
            font-weight: 600;
        }
        
        .json-content .json-null {
            color: #a0aec0;
            font-style: italic;
        }
        
        .json-content .json-punctuation {
            color: #cbd5e0;
        }
        
        /* Status indicators */
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-success { background: #48bb78; }
        .status-error { background: #f56565; }
        .status-pending { background: #ed8936; }
        
        /* Improved scrollbar for JSON content */
        .json-content::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        
        .json-content::-webkit-scrollbar-track {
            background: #2d3748;
            border-radius: 4px;
        }
        
        .json-content::-webkit-scrollbar-thumb {
            background: #4a5568;
            border-radius: 4px;
        }
        
        .json-content::-webkit-scrollbar-thumb:hover {
            background: #5a67d8;
        }
        
        /* Copy button for JSON content */
        .copy-btn {
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(255, 255, 255, 0.1);
            color: #e2e8f0;
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 10px;
            cursor: pointer;
            opacity: 0;
            transition: all 0.2s ease;
        }
        
        .json-content:hover .copy-btn {
            opacity: 1;
        }
        
        .copy-btn:hover {
            background: rgba(255, 255, 255, 0.2);
        }
        
        /* Responsive design for details */
        @media (max-width: 768px) {
            .details-content {
                padding: 16px;
            }
            
            .json-content {
                font-size: 11px;
                padding: 12px;
            }
        }
        
        /* Transaction Overview Styles */
        .transaction-overview {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 24px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
            border-left: 4px solid #667eea;
        }
        
        .overview-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 16px;
            margin-top: 12px;
        }
        
        .overview-item {
            background: #f7fafc;
            padding: 12px 16px;
            border-radius: 8px;
            border: 1px solid #e2e8f0;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .overview-item strong {
            color: #4a5568;
            font-weight: 600;
            min-width: 60px;
        }
        
        .url-text {
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            color: #667eea;
            word-break: break-all;
        }
        
        .method-badge {
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 700;
            font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
        }
        
        /* Section Styles */
        .request-section,
        .response-section,
        .error-section {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
        }
        
        .request-section {
            border-left: 4px solid #38a169;
        }
        
        .response-section {
            border-left: 4px solid #3182ce;
        }
        
        .error-section {
            border-left: 4px solid #e53e3e;
        }
        
        /* Enhanced mobile responsiveness */
        @media (max-width: 768px) {
            .overview-grid {
                grid-template-columns: 1fr;
                gap: 12px;
            }
            
            .overview-item {
                flex-direction: column;
                align-items: flex-start;
                gap: 4px;
            }
            
            .transaction-overview,
            .request-section,
            .response-section,
            .error-section {
                padding: 16px;
                margin-bottom: 16px;
            }
        }
    </style>
</head>
<body>
    <div class="dashboard-container">
        <div class="header">
            <h1>🚀 coTe Network Dashboard <span id="wsStatus" style="font-size:16px;vertical-align:middle;margin-left:12px;"><span id="wsDot" style="display:inline-block;width:12px;height:12px;border-radius:50%;background:#e53e3e;margin-right:6px;"></span><span id="wsText">Offline</span></span></h1>
            <p>Real-time HTTP activity monitoring</p>
        </div>
        
        <div class="controls">
            <div class="controls-row">
                <div class="stats">
                    <div class="stat">
                        <strong id="logCount">0</strong> Total Logs
                    </div>
                    <div class="stat">
                        <strong id="requestCount">0</strong> Requests
                    </div>
                    <div class="stat">
                        <strong id="errorCount">0</strong> Errors
                    </div>
                    <div class="stat">
                        Last updated: <span id="lastUpdated">Never</span>
                    </div>
                </div>
                <div class="button-group">
                    <button class="btn" onclick="refreshLogs()">
                        🔄 Refresh
                    </button>
                    <button class="btn danger" onclick="clearLogs()">
                        🗑️ Clear All
                    </button>
                </div>
            </div>
            <div class="search-filter">
                <input type="text" class="search-input" id="searchInput" placeholder="🔍 Search URLs, methods, status codes...">
                <select class="filter-select" id="methodFilter">
                    <option value="">All Methods</option>
                    <option value="GET">GET</option>
                    <option value="POST">POST</option>
                    <option value="PUT">PUT</option>
                    <option value="DELETE">DELETE</option>
                    <option value="PATCH">PATCH</option>
                </select>
                <select class="filter-select" id="statusFilter">
                    <option value="">All Status</option>
                    <option value="2xx">2xx Success</option>
                    <option value="4xx">4xx Client Error</option>
                    <option value="5xx">5xx Server Error</option>
                </select>
            </div>
        </div>
        
        <div class="container">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th></th>
                            <th>Type</th>
                            <th>Method</th>
                            <th>URL</th>
                            <th>Status</th>
                            <th>Time</th>
                        </tr>
                    </thead>
                    <tbody id="logsTableBody">
                        <tr>
                            <td colspan="6" class="loading">🔄 Loading network logs...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        $_dashboardScript
    </script>
</body>
</html>
''';
  }

  static const String _dashboardScript = r'''
    console.log('🚀 Network Logger Dashboard Starting...');
    
    let logs = [];
    let allTransactions = [];
    let filteredTransactions = [];
    let expandedRows = new Set();
    let userInteracting = false;
    let interactionTimeout;
    let lastDataHash = '';
    let consecutiveNoChanges = 0;
    let forceNextUpdate = false;
    let ws = null;
    let wsConnected = false;
    let wsReconnectTimeout = null;

    function updateWsStatus() {
        const wsDot = document.getElementById('wsDot');
        const wsText = document.getElementById('wsText');
        if (wsConnected) {
            if (wsDot) wsDot.style.background = '#38a169';
            if (wsText) wsText.textContent = 'Live';
        } else {
            if (wsDot) wsDot.style.background = '#e53e3e';
            if (wsText) wsText.textContent = 'Offline';
        }
    }

    // --- WebSocket Real-Time Updates ---
    function connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
        const wsUrl = `${protocol}://${window.location.host}/ws`;
        console.log('🌐 Connecting to WebSocket:', wsUrl);
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
            wsConnected = true;
            updateWsStatus();
            console.log('✅ WebSocket connected! Real-time updates enabled.');
            if (wsReconnectTimeout) clearTimeout(wsReconnectTimeout);
        };

        ws.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                if (msg.type === 'init') {
                    logs = msg.logs || [];
                    console.log('🟢 [WS] Received init with', logs.length, 'logs');
                    processLogs();
                    updateDisplay();
                } else if (msg.type === 'log') {
                    // Insert new log at the top
                    logs.unshift(msg.log);
                    console.log('🟢 [WS] Received new log:', msg.log);
                    processLogs();
                    updateDisplay();
                }
            } catch (e) {
                console.error('❌ Error parsing WebSocket message:', e);
            }
        };

        ws.onclose = () => {
            wsConnected = false;
            updateWsStatus();
            console.warn('⚠️ WebSocket closed. Attempting to reconnect in 3s...');
            wsReconnectTimeout = setTimeout(connectWebSocket, 3000);
        };

        ws.onerror = (err) => {
            wsConnected = false;
            updateWsStatus();
            console.error('❌ WebSocket error:', err);
            ws.close();
        };
    }

    // --- End WebSocket ---

    // Track user interaction to pause auto-refresh (much less aggressive)
    function setUserInteracting() {
        userInteracting = true;
        clearTimeout(interactionTimeout);
        interactionTimeout = setTimeout(() => {
            userInteracting = false;
            console.log('🔄 User interaction ended, resuming auto-refresh');
            // Immediately refresh after user stops interacting
            forceNextUpdate = true;
            if (!wsConnected) loadLogs();
        }, 1000);
    }

    // Load logs immediately when page loads (fallback for polling)
    async function loadLogs() {
        if (wsConnected) return; // Don't poll if WebSocket is active
        if (userInteracting && consecutiveNoChanges < 2 && !forceNextUpdate) {
            console.log('⏸️ Skipping refresh - user is actively interacting');
            return;
        }
        console.log('📡 Loading logs from API...');
        try {
            const cacheBuster = `?t=${Date.now()}&r=${Math.random()}`;
            const response = await fetch(`/logs${cacheBuster}`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            const data = await response.json();
            const currentDataHash = JSON.stringify(data.logs);
            if (forceNextUpdate || currentDataHash !== lastDataHash) {
                if (forceNextUpdate) forceNextUpdate = false;
                consecutiveNoChanges = 0;
                lastDataHash = currentDataHash;
                logs = data.logs || [];
                processLogs();
                updateDisplay();
                return;
            }
            consecutiveNoChanges++;
            if (consecutiveNoChanges >= 3) {
                lastDataHash = '';
                consecutiveNoChanges = 0;
                forceNextUpdate = true;
                logs = data.logs || [];
                processLogs();
                updateDisplay();
            }
        } catch (error) {
            console.error('❌ Error loading logs:', error);
            showError('Failed to load logs: ' + error.message);
            consecutiveNoChanges++;
        }
    }

    function processLogs() {
        console.log('🔄 Processing logs...');
        console.log('📊 Raw logs received:', logs.length);
        
        // Step 1: Create a transaction for every request
        const requestTransactions = new Map();
        const responseOrErrorLogs = [];
        
        // Debug: Log all unique IDs
        const allIds = logs.map(log => log.id);
        const uniqueIds = [...new Set(allIds)];
        console.log('🆔 Unique log IDs:', uniqueIds.length, 'out of', allIds.length, 'total logs');
        
        logs.forEach(log => {
            if (log.type === 'request') {
                // Every request gets its own unique transaction using the log ID
                const transactionId = `req_${log.id}`;
                if (requestTransactions.has(transactionId)) {
                    console.warn('⚠️ Duplicate request transaction ID:', transactionId);
                }
                requestTransactions.set(transactionId, {
                    id: transactionId,
                    url: log.url,
                    method: log.method || 'UNKNOWN',
                    request: log,
                    response: null,
                    error: null,
                    timestamp: log.timestamp,
                    requestTimestamp: log.timestamp,
                    logId: log.id
                });
                console.log('➕ Created transaction for request:', transactionId, log.method, log.url);
            } else {
                // Collect responses and errors for pairing
                responseOrErrorLogs.push(log);
            }
        });
        
        console.log('📤 Request transactions created:', requestTransactions.size);
        console.log('📥 Response/Error logs to pair:', responseOrErrorLogs.length);
        
        // Step 2: Pair responses and errors with their matching requests
        responseOrErrorLogs.forEach(log => {
            // Find the best matching request transaction
            let bestMatch = null;
            let smallestTimeDiff = Infinity;
            
            for (const [transactionId, transaction] of requestTransactions) {
                // Must match method and URL
                if (transaction.method === log.method && transaction.url === log.url) {
                    // Calculate time difference
                    const timeDiff = Math.abs(new Date(log.timestamp) - new Date(transaction.requestTimestamp));
                    
                    // Only consider if this transaction doesn't already have this type of log
                    const canMatch = (log.type === 'response' && !transaction.response) || 
                                   (log.type === 'error' && !transaction.error);
                    
                    if (canMatch && timeDiff < smallestTimeDiff && timeDiff < 30000) { // within 30 seconds
                        bestMatch = transaction;
                        smallestTimeDiff = timeDiff;
                    }
                }
            }
            
            if (bestMatch) {
                // Pair with the best matching request
                if (log.type === 'response') {
                    bestMatch.response = log;
                    console.log('🔗 Paired response to:', bestMatch.id);
                } else if (log.type === 'error') {
                    bestMatch.error = log;
                    console.log('🔗 Paired error to:', bestMatch.id);
                }
                
                // Update transaction timestamp to latest
                if (new Date(log.timestamp) > new Date(bestMatch.timestamp)) {
                    bestMatch.timestamp = log.timestamp;
                }
            } else {
                // No matching request found, create standalone transaction
                const standaloneId = `standalone_${log.type}_${log.id}`;
                requestTransactions.set(standaloneId, {
                    id: standaloneId,
                    url: log.url,
                    method: log.method || 'UNKNOWN',
                    request: null,
                    response: log.type === 'response' ? log : null,
                    error: log.type === 'error' ? log : null,
                    timestamp: log.timestamp,
                    requestTimestamp: null,
                    logId: log.id
                });
                
                console.log('📋 Created standalone transaction:', standaloneId);
            }
        });
        
        allTransactions = Array.from(requestTransactions.values())
            .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        
        // --- Preserve expandedRows ---
        const currentIds = new Set(allTransactions.map(t => t.id));
        expandedRows = new Set([...expandedRows].filter(id => currentIds.has(id)));
        
        // Apply current filters
        applyFilters();
        
        console.log('✅ Final result:', allTransactions.length, 'transactions from', logs.length, 'logs');
        console.log('📋 Transaction summary:', allTransactions.map(t => `${t.method} ${t.url} (${t.id})`));
    }

    function applyFilters() {
        const searchTerm = document.getElementById('searchInput') && document.getElementById('searchInput').value.toLowerCase() || '';
        const methodFilter = document.getElementById('methodFilter') && document.getElementById('methodFilter').value || '';
        const statusFilter = document.getElementById('statusFilter') && document.getElementById('statusFilter').value || '';
        
        filteredTransactions = allTransactions.filter(transaction => {
            const matchesSearch = !searchTerm || 
                transaction.url.toLowerCase().includes(searchTerm) ||
                transaction.method.toLowerCase().includes(searchTerm);
            
            const matchesMethod = !methodFilter || transaction.method === methodFilter;
            
            const statusCode = getStatusCode(transaction);
            const matchesStatus = !statusFilter || 
                (statusFilter === '2xx' && statusCode >= 200 && statusCode < 300) ||
                (statusFilter === '4xx' && statusCode >= 400 && statusCode < 500) ||
                (statusFilter === '5xx' && statusCode >= 500);
            
            return matchesSearch && matchesMethod && matchesStatus;
        });
    }

    function updateDisplay() {
        console.log('🎨 Updating display...');
        console.log('📊 Data summary:', {
            totalLogs: logs.length,
            allTransactions: allTransactions.length,
            filteredTransactions: filteredTransactions.length,
            expandedRows: expandedRows.size
        });
        updateStats();
        updateTable();
    }

    function updateStats() {
        const totalLogs = document.getElementById('logCount');
        const requestCount = document.getElementById('requestCount');
        const errorCount = document.getElementById('errorCount');
        const lastUpdated = document.getElementById('lastUpdated');
        
        const requests = allTransactions.filter(t => t.request).length;
        const errors = allTransactions.filter(t => t.error || (t.response && t.response.statusCode >= 400)).length;
        
        if (totalLogs) {
            totalLogs.textContent = allTransactions.length;
            // Add visual feedback for new data
            totalLogs.style.color = '#667eea';
            setTimeout(() => {
                totalLogs.style.color = '';
            }, 300);
        }
        if (requestCount) {
            requestCount.textContent = requests;
            requestCount.style.color = '#667eea';
            setTimeout(() => {
                requestCount.style.color = '';
            }, 300);
        }
        if (errorCount) {
            errorCount.textContent = errors;
            errorCount.style.color = errors > 0 ? '#e53e3e' : '#667eea';
            setTimeout(() => {
                errorCount.style.color = '';
            }, 300);
        }
        if (lastUpdated) {
            lastUpdated.textContent = new Date().toLocaleTimeString();
            lastUpdated.style.color = '#38a169';
            setTimeout(() => {
                lastUpdated.style.color = '';
            }, 500);
        }
        
        console.log('📊 Stats updated - Total:', allTransactions.length, 'Requests:', requests, 'Errors:', errors);
    }

    function updateTable() {
        const tableBody = document.getElementById('logsTableBody');
        if (!tableBody) return;
        
        if (filteredTransactions.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6" class="empty-state">
                        <h3>📡 No network activity</h3>
                        <p>Make HTTP requests in your Flutter app to see them here</p>
                    </td>
                </tr>
            `;
            return;
        }
        
        let html = '';
        filteredTransactions.forEach(transaction => {
            const statusCode = getStatusCode(transaction);
            const statusClass = getStatusClass(statusCode);
            const time = new Date(transaction.timestamp).toLocaleTimeString();
            const isExpanded = expandedRows.has(transaction.id);
            
            html += `
                <tr onclick="toggleDetails('${transaction.id}')" style="cursor: pointer;" class="${isExpanded ? 'expanded' : ''}">
                    <td><span class="expand-icon">${isExpanded ? '▼' : '▶'}</span></td>
                    <td><span class="type-badge ${getTypeClass(transaction)}">${getTypeText(transaction)}</span></td>
                    <td><span class="method ${transaction.method}">${transaction.method}</span></td>
                    <td><span class="url" title="${transaction.url}">${transaction.url}</span></td>
                    <td><span class="status-code ${statusClass}">${statusCode}</span></td>
                    <td><span class="timestamp">${time}</span></td>
                </tr>
            `;
            
            if (isExpanded) {
                html += `
                    <tr class="details-row" style="display: table-row;">
                        <td colspan="6">
                            <div class="details-content">
                                ${createDetailedView(transaction)}
                            </div>
                        </td>
                    </tr>
                `;
            }
        });
        
        tableBody.innerHTML = html;
        console.log('🎨 Table updated with', filteredTransactions.length, 'transactions');
    }

    function getStatusCode(transaction) {
        if (transaction.error) return 'ERROR';
        if (transaction.response && transaction.response.statusCode) return transaction.response.statusCode;
        return 'PENDING';
    }

    function getStatusClass(statusCode) {
        if (statusCode === 'ERROR') return 'status-4xx';
        if (statusCode === 'PENDING') return '';
        
        const code = parseInt(statusCode);
        if (code >= 200 && code < 300) return 'status-2xx';
        if (code >= 300 && code < 400) return 'status-3xx';
        if (code >= 400 && code < 500) return 'status-4xx';
        if (code >= 500) return 'status-5xx';
        return '';
    }

    function getTypeClass(transaction) {
        if (transaction.error) return 'type-error';
        if (transaction.response) return 'type-response';
        return 'type-request';
    }

    function getTypeText(transaction) {
        if (transaction.error) return 'ERROR';
        if (transaction.response) return 'COMPLETE';
        return 'PENDING';
    }

    function formatRequestDetails(transaction) {
        if (!transaction.request) return 'No request data';
        
        const req = transaction.request;
        let details = `URL: ${req.url}\n`;
        details += `Method: ${req.method}\n`;
        details += `Timestamp: ${req.timestamp}\n\n`;
        
        if (req.headers) {
            details += 'Headers:\n' + formatJSON(req.headers) + '\n\n';
        }
        
        if (req.requestBody) {
            details += 'Request Body:\n' + formatJSON(req.requestBody);
        }
        
        return details;
    }

    function formatResponseDetails(transaction) {
        if (transaction.error) {
            return `Error: ${formatJSON(transaction.error)}`;
        }
        
        if (!transaction.response) return 'No response data';
        
        const res = transaction.response;
        let details = `Status: ${res.statusCode} ${res.statusMessage || ''}\n`;
        details += `Timestamp: ${res.timestamp}\n\n`;
        
        if (res.headers) {
            details += 'Response Headers:\n' + formatJSON(res.headers) + '\n\n';
        }
        
        if (res.responseBody) {
            details += 'Response Body:\n' + formatJSON(res.responseBody);
        }
        
        return details;
    }

    function formatJSON(data) {
        try {
            // If it's already a string, try to parse it first
            if (typeof data === 'string') {
                try {
                    data = JSON.parse(data);
                } catch (e) {
                    // If parsing fails, return the original string
                    return data;
                }
            }
            
            // Pretty print the JSON with 2-space indentation
            return JSON.stringify(data, null, 2);
        } catch (error) {
            // If JSON formatting fails, return the original data
            return typeof data === 'string' ? data : String(data);
        }
    }

    function createExpandableContent(title, content, maxHeight = '200px') {
        const contentId = `content_${Math.random().toString(36).substr(2, 9)}`;
        const isLongContent = content.length > 500;
        
        if (!isLongContent) {
            return `<div class="content-section">
                <h5>${title}</h5>
                <pre class="json-content">${content}</pre>
            </div>`;
        }
        
        return `<div class="content-section">
            <h5>${title} <button class="expand-btn" onclick="toggleContent('${contentId}')">[Expand]</button></h5>
            <pre class="json-content expandable-content" id="${contentId}" style="max-height: ${maxHeight}; overflow: hidden;">${content}</pre>
        </div>`;
    }

    function toggleContent(contentId) {
        const element = document.getElementById(contentId);
        const button = element.previousElementSibling.querySelector('.expand-btn');
        
        if (element.style.maxHeight === 'none') {
            element.style.maxHeight = '200px';
            element.style.overflow = 'hidden';
            button.textContent = '[Expand]';
        } else {
            element.style.maxHeight = 'none';
            element.style.overflow = 'visible';
            button.textContent = '[Collapse]';
        }
    }

    function toggleDetails(transactionId) {
        console.log('🔄 Toggling details for:', transactionId);
        setUserInteracting(); // Mark as user interaction
        
        if (expandedRows.has(transactionId)) {
            expandedRows.delete(transactionId);
            console.log('➖ Collapsed row:', transactionId);
        } else {
            expandedRows.add(transactionId);
            console.log('➕ Expanded row:', transactionId);
        }
        updateTable();
    }

    function showError(message) {
        const tableBody = document.getElementById('logsTableBody');
        if (tableBody) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6" class="empty-state" style="color: #e53e3e;">
                        <h3>⚠️ Error</h3>
                        <p>${message}</p>
                    </td>
                </tr>
            `;
        }
        console.error('❌', message);
    }

    // Button handlers
    function refreshLogs() {
        console.log('🔄 Manual refresh triggered');
        lastDataHash = ''; // Force refresh
        consecutiveNoChanges = 0;
        forceNextUpdate = true;
        userInteracting = false; // Stop any interaction pausing
        clearTimeout(interactionTimeout);
        loadLogs();
    }

    async function clearLogs() {
        if (!confirm('Clear all logs?')) return;
        
        userInteracting = false; // Stop any interaction pausing
        clearTimeout(interactionTimeout);
        
        try {
            const response = await fetch('/logs/clear', { method: 'POST' });
            if (response.ok) {
                logs = [];
                allTransactions = [];
                filteredTransactions = [];
                expandedRows.clear();
                lastDataHash = '';
                consecutiveNoChanges = 0;
                forceNextUpdate = true;
                updateDisplay();
                console.log('🗑️ Logs cleared');
                // Force immediate refresh after clear
                setTimeout(() => loadLogs(), 100);
            }
        } catch (error) {
            console.error('❌ Error clearing logs:', error);
        }
    }

    // Filter function
    function filterTransactions() {
        setUserInteracting(); // Mark as user interaction
        applyFilters();
        updateTable();
    }

    // Initialize everything when page loads
    document.addEventListener('DOMContentLoaded', function() {
        console.log('📄 DOM loaded, initializing...');
        // Set up event listeners
        const searchInput = document.getElementById('searchInput');
        const methodFilter = document.getElementById('methodFilter');
        const statusFilter = document.getElementById('statusFilter');
        if (searchInput) {
            searchInput.addEventListener('input', filterTransactions);
            searchInput.addEventListener('input', setUserInteracting);
        }
        if (methodFilter) methodFilter.addEventListener('change', filterTransactions);
        if (statusFilter) statusFilter.addEventListener('change', filterTransactions);
        // Try to connect WebSocket
        connectWebSocket();
        // Fallback polling if WebSocket is not available
        setInterval(() => {
            if (!wsConnected) {
                console.log('⏰ Polling fallback (WebSocket not connected)...');
                loadLogs();
            }
        }, 2000);
    });

    console.log('✅ Network Logger Dashboard JavaScript Loaded!');

    function createDetailedView(transaction) {
        let html = '';
        
        // Transaction Overview
        html += `
            <div class="transaction-overview">
                <h4><span class="status-indicator ${getStatusIndicatorClass(transaction)}"></span>Transaction Overview</h4>
                <div class="overview-grid">
                    <div class="overview-item">
                        <strong>URL:</strong> <span class="url-text">${transaction.url}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Method:</strong> <span class="method-badge ${transaction.method}">${transaction.method}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Status:</strong> <span class="status-code ${getStatusClass(getStatusCode(transaction))}">${getStatusCode(transaction)}</span>
                    </div>
                    <div class="overview-item">
                        <strong>Time:</strong> <span class="timestamp">${new Date(transaction.timestamp).toLocaleString()}</span>
                    </div>
                </div>
            </div>
        `;
        
        // Request Details
        if (transaction.request) {
            const req = transaction.request;
            html += `<div class="request-section">
                <h4>📤 Request Details</h4>`;
                
            if (req.headers) {
                html += createExpandableContent('Request Headers', formatJSON(req.headers), '150px');
            }
            
            if (req.requestBody) {
                html += createExpandableContent('Request Body', formatJSON(req.requestBody), '200px');
            }
            
            html += `</div>`;
        }
        
        // Response Details
        if (transaction.response) {
            const res = transaction.response;
            html += `<div class="response-section">
                <h4>📥 Response Details</h4>`;
                
            if (res.headers) {
                html += createExpandableContent('Response Headers', formatJSON(res.headers), '150px');
            }
            
            if (res.responseBody) {
                html += createExpandableContent('Response Body', formatJSON(res.responseBody), '300px');
            }
            
            html += `</div>`;
        }
        
        // Error Details
        if (transaction.error) {
            html += `<div class="error-section">
                <h4>❌ Error Details</h4>
                ${createExpandableContent('Error Information', formatJSON(transaction.error), '200px')}
            </div>`;
        }
        
        return html;
    }
    
    function getStatusIndicatorClass(transaction) {
        if (transaction.error) return 'status-error';
        if (transaction.response) {
            const statusCode = parseInt(getStatusCode(transaction));
            if (statusCode >= 200 && statusCode < 400) return 'status-success';
            return 'status-error';
        }
        return 'status-pending';
    }
  ''';
}
