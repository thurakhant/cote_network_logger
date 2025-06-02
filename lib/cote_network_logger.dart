import 'package:flutter/foundation.dart';
import 'web_server.dart';

// Export all public components
export 'interceptor.dart'; // Contains CoteNetworkLogger class
export 'log_store.dart';
export 'web_server.dart';

/// Environment configuration for Network Logger
class NetworkLoggerConfig {
  // Private constructor to prevent instantiation
  NetworkLoggerConfig._();

  // Default environment types
  static const String kDebug = 'debug';
  static const String kStaging = 'staging';
  static const String kProduction = 'production';

  // Custom environment types
  static final Set<String> _customEnvironments = {};

  /// Get current environment/flavor
  static String get currentFlavor {
    if (kDebugMode) return kDebug;
    if (const bool.fromEnvironment('STAGING_ENV')) return kStaging;
    return kProduction;
  }

  /// Check if logger is enabled
  static bool get isEnabled {
    // Allow explicit enable flag
    if (const bool.fromEnvironment('NETWORK_LOGGER_ENABLED')) return true;

    // Enable in debug mode
    if (kDebugMode) return true;

    // Enable in staging environment
    if (currentFlavor == kStaging) return true;

    return false;
  }

  /// Check if logger is enabled in specific environment
  static bool isEnabledInFlavor(String flavor) {
    final normalizedFlavor = flavor.toLowerCase();

    // Enable in debug mode
    if (normalizedFlavor == kDebug) return true;

    // Enable in staging
    if (normalizedFlavor == kStaging) return true;

    // Enable in custom environments if explicitly enabled
    if (_customEnvironments.contains(normalizedFlavor)) {
      return const bool.fromEnvironment('NETWORK_LOGGER_ENABLED');
    }

    return false;
  }

  /// Maximum number of logs to keep in memory
  static const int maxLogEntries = 200;

  /// Port number for the dashboard server
  static const int serverPort = 3000;

  /// Host address for the dashboard server
  static const String serverHost = '0.0.0.0';

  /// Add a custom environment type
  static void addCustomEnvironment(String environment) {
    _customEnvironments.add(environment.toLowerCase());
  }

  /// Get all available environment types
  static Set<String> get availableEnvironments => {
        kDebug,
        kStaging,
        kProduction,
        ..._customEnvironments,
      };

  /// Check if the given environment is valid
  static bool isValidEnvironment(String environment) {
    return availableEnvironments.contains(environment.toLowerCase());
  }
}

/// Builder class for configuring Network Logger environments
class NetworkLoggerEnvironment {
  final String name;
  final bool enableByDefault;
  final String? description;

  const NetworkLoggerEnvironment({
    required this.name,
    this.enableByDefault = false,
    this.description,
  });

  /// Create a debug environment
  static const debug = NetworkLoggerEnvironment(
    name: 'debug',
    enableByDefault: true,
    description: 'Development environment with full logging',
  );

  /// Create a staging environment
  static const staging = NetworkLoggerEnvironment(
    name: 'staging',
    enableByDefault: true,
    description: 'Staging environment for testing',
  );

  /// Create a production environment
  static const production = NetworkLoggerEnvironment(
    name: 'production',
    enableByDefault: false,
    description: 'Production environment with logging disabled',
  );

  /// Create a QA environment
  static const qa = NetworkLoggerEnvironment(
    name: 'qa',
    enableByDefault: true,
    description: 'QA testing environment',
  );

  /// Create a beta environment
  static const beta = NetworkLoggerEnvironment(
    name: 'beta',
    enableByDefault: true,
    description: 'Beta testing environment',
  );

  /// Create a custom environment
  static NetworkLoggerEnvironment custom({
    required String name,
    bool enableByDefault = false,
    String? description,
  }) {
    return NetworkLoggerEnvironment(
      name: name,
      enableByDefault: enableByDefault,
      description: description,
    );
  }
}

/// Helper class to configure Network Logger
class NetworkLogger {
  /// Configure the logger with specific environments
  static void configure({
    List<NetworkLoggerEnvironment>? environments,
    bool enableInRelease = false,
  }) {
    if (environments != null) {
      for (final env in environments) {
        NetworkLoggerConfig.addCustomEnvironment(env.name);
      }
    }

    if (enableInRelease) {
      // Enable logger in release mode
      const bool.fromEnvironment('NETWORK_LOGGER_ENABLED');
    }
  }

  /// Start the logger if enabled in current environment
  static Future<bool> start() async {
    if (NetworkLoggerConfig.isEnabled) {
      return await startNetworkLogServer();
    }
    return false;
  }

  /// Get the dashboard URL if logger is running
  static String? get dashboardUrl => getNetworkLogDashboardUrl();

  /// Check if logger is running
  static bool get isRunning => isNetworkLogServerRunning();
}

/// Starts the Network Logger web server.
///
/// This function initializes the local web server that serves the dashboard
/// and API endpoints for viewing network logs. The server will start if:
/// - In debug mode
/// - In staging environment
/// - Explicitly enabled via NETWORK_LOGGER_ENABLED flag
///
/// **Platform Support:**
/// - ✅ Android, iOS, macOS, Windows, Linux
/// - ❌ Web (browsers don't support ServerSocket.bind)
///
/// **Environment Support:**
/// - ✅ Debug mode (always enabled)
/// - ✅ Staging environment (when STAGING_ENV=true)
/// - ✅ Release mode with explicit enable (when NETWORK_LOGGER_ENABLED=true)
/// - ❌ Production environment (disabled by default)
///
/// Returns a [Future<bool>] indicating whether the server started successfully.
/// Returns false if platform is not supported or if not enabled.
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
  if (!NetworkLoggerConfig.isEnabled) {
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
