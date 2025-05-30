library cote_network_logger;

import 'package:flutter/foundation.dart';
import 'web_server.dart';

// Export all public components
export 'interceptor.dart'; // Contains CoteNetworkLogger class
export 'log_store.dart';
export 'web_server.dart';

/// Starts the Network Logger web server.
///
/// This function initializes the local web server that serves the dashboard
/// and API endpoints for viewing network logs. The server will only start
/// in debug mode and on supported platforms.
///
/// **Platform Support:**
/// - ✅ Android, iOS, macOS, Windows, Linux
/// - ❌ Web (browsers don't support ServerSocket.bind)
///
/// Returns a [Future<bool>] indicating whether the server started successfully.
/// Returns false if platform is not supported or if not in debug mode.
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Start the network logger server
///   final serverStarted = await startNetworkLogServer();
///   if (serverStarted) {
///     debugPrint('Network Logger Dashboard: http://localhost:3000');
///   } else {
///     debugPrint('Network Logger not available on this platform');
///   }
///
///   runApp(MyApp());
/// }
/// ```
Future<bool> startNetworkLogServer() async {
  if (!kDebugMode) {
    return false;
  }

  if (!NetworkLogWebServer.isPlatformSupported) {
    if (kIsWeb) {
      debugPrint('💡 Cote Network Logger: Web platform detected');
      debugPrint('💡 Dashboard not available - use browser DevTools instead');
      debugPrint('💡 Network requests will still be logged to console');
    }
    return false;
  }

  try {
    final success = await NetworkLogWebServer.instance.start();
    return success;
  } catch (e) {
    debugPrint('❌ Failed to start Network Logger: $e');
    return false;
  }
}

/// Stops the Network Logger web server.
///
/// This function stops the running web server. Useful for cleanup
/// or when you want to manually control the server lifecycle.
Future<void> stopNetworkLogServer() async {
  await NetworkLogWebServer.instance.stop();
}

/// Returns whether the Network Logger web server is currently running.
///
/// Always returns false on unsupported platforms.
bool isNetworkLogServerRunning() {
  if (!NetworkLogWebServer.isPlatformSupported) {
    return false;
  }
  return NetworkLogWebServer.instance.isRunning;
}

/// Returns the URL where the Network Logger dashboard is accessible.
///
/// Returns null if the server is not running or platform is not supported.
String? getNetworkLogDashboardUrl() {
  if (!NetworkLogWebServer.isPlatformSupported || !NetworkLogWebServer.instance.isRunning) {
    return null;
  }
  return NetworkLogWebServer.instance.dashboardUrl;
}

/// Checks if the current platform supports the Network Logger dashboard.
///
/// Returns true for Android, iOS, macOS, Windows, Linux.
/// Returns false for Web and other unsupported platforms.
bool isNetworkLoggerSupported() {
  return NetworkLogWebServer.isPlatformSupported;
}

/// Starts the web dashboard server for real-time monitoring.
///
/// Returns true if the server started successfully, false otherwise.
/// The dashboard will be available at http://localhost:3000 (for emulators)
/// or http://YOUR_DEVICE_IP:3000 (for physical devices).
Future<bool> startDashboard() async {
  return await NetworkLogWebServer.instance.start();
}

/// Returns the URL where the dashboard is accessible.
String get dashboardUrl => NetworkLogWebServer.instance.dashboardUrl;

/// Returns whether the dashboard server is currently running.
bool get isDashboardRunning => NetworkLogWebServer.instance.isRunning;
