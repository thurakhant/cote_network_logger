import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Simple test server to serve Flutter web files without Flutter dependencies
void main() async {
  print('🚀 Testing Static File Server...');

  try {
    // Try multiple possible paths for the dashboard build
    final possiblePaths = [
      'dashboard/build/web',
      '../dashboard/build/web',
      '${Directory.current.path}/dashboard/build/web',
      '${Directory.current.path}/../dashboard/build/web',
    ];

    String? dashboardPath;
    Directory? dashboardDir;

    print('🔍 Current working directory: ${Directory.current.path}');

    // Try each possible path until we find one that exists
    for (final path in possiblePaths) {
      final dir = Directory(path);
      print('🔍 Checking path: ${dir.path}');
      if (dir.existsSync()) {
        dashboardPath = path;
        dashboardDir = dir;
        print('✅ Found dashboard at: ${dir.path}');
        break;
      }
    }

    if (dashboardDir == null) {
      print('❌ Flutter Web dashboard not found in any of these paths:');
      for (final path in possiblePaths) {
        print('   - $path');
      }
      print('   Run: cd dashboard && flutter build web --release');
      return;
    }

    // List files in the dashboard directory for debugging
    final files = dashboardDir.listSync();
    print('📁 Dashboard files: ${files.map((f) => f.path.split('/').last).join(', ')}');

    // Create MIME type middleware
    final mimeTypeMiddleware = (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        final path = request.url.path.toLowerCase();
        Map<String, String> headers = Map.from(response.headers);

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
        }

        headers['Access-Control-Allow-Origin'] = '*';
        headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
        headers['Access-Control-Allow-Headers'] = 'Content-Type';

        print('🌐 Serving ${request.url.path} with content-type: ${headers['content-type'] ?? 'default'}');

        return response.change(headers: headers);
      };
    };

    // Create static file handler
    final staticHandler = Pipeline().addMiddleware(mimeTypeMiddleware).addHandler(createStaticHandler(
          dashboardDir.path,
          defaultDocument: 'index.html',
          serveFilesOutsidePath: true,
        ));

    // Start server
    final server = await HttpServer.bind('0.0.0.0', 3000);
    print('✅ Server started successfully!');
    print('🌐 Server URL: http://localhost:3000');

    server.listen((HttpRequest request) async {
      try {
        print('📨 Request: ${request.method} ${request.uri.path}');

        final headers = <String, String>{};
        request.headers.forEach((name, values) {
          if (values.isNotEmpty) headers[name] = values.join(',');
        });

        final shelfRequest = Request(
          request.method,
          request.requestedUri,
          headers: headers,
          body: request,
        );

        final shelfResponse = await staticHandler(shelfRequest);
        request.response.statusCode = shelfResponse.statusCode;
        shelfResponse.headers.forEach((name, value) {
          request.response.headers.set(name, value);
        });
        await shelfResponse.read().forEach(request.response.add);
        await request.response.close();

        print('✅ Response: ${shelfResponse.statusCode} for ${request.uri.path}');
      } catch (e) {
        print('❌ Error handling request: $e');
        request.response.statusCode = 500;
        request.response.write('Internal Server Error');
        await request.response.close();
      }
    });

    print('');
    print('📋 What to do next:');
    print('1. Open http://localhost:3000 in your browser');
    print('2. Check the console for request logs');
    print('3. Press Ctrl+C to stop the server');
    print('');

    // Keep the server running
    await Future.delayed(Duration(minutes: 10));
  } catch (e) {
    print('❌ Failed to start server: $e');
  }
}
