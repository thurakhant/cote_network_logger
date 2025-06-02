# 🚀 CoteNetworkLogger

A powerful Flutter package for real-time HTTP network monitoring during development and staging environments.

---

## 📦 What's New in 1.1.0 (2025-06-03)
- **Single transaction per HTTP call:** No more duplicate rows for request/response. Each HTTP call is now represented by a single transaction in the dashboard.
- **Improved log grouping:** Status updates in real-time, with clear distinction between pending, completed, and failed requests.
- **Dart conventions:** Codebase refactored for best practices and pub.dev compliance.
- **Better error and response body handling.**
- **Documentation and README improvements.**

---

## ✨ Features

- 🔍 **Real-time network monitoring** - See HTTP requests as they happen
- 📱 **Cross-platform support** - Android, iOS, macOS, Windows, Linux
- 🌐 **Web dashboard** - Beautiful browser-based interface
- 🎨 **Material Design 3** - Modern, responsive UI
- 🔄 **Auto-refresh** - Smart refresh that pauses during user interaction
- 💾 **Memory efficient** - In-memory storage with auto-cleanup
- 🌍 **Environment support** - Debug, Staging, and Release modes

## 🛠️ Quick Start

1. **Add to your pubspec.yaml:**
   ```yaml
   dependencies:
     cote_network_logger: ^1.1.0
   ```

2. **Start the server in your main.dart:**
   ```dart
   import 'package:cote_network_logger/cote_network_logger.dart';

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await startNetworkLogServer();
     runApp(MyApp());
   }
   ```

3. **Add the interceptor to your Dio instance:**
   ```dart
   import 'package:dio/dio.dart';
   import 'package:cote_network_logger/cote_network_logger.dart';

   final dio = Dio();
   dio.interceptors.add(const CoteNetworkLogger());
   ```

4. **Open the dashboard URL in your browser!**

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for full release notes.

---

## 🌍 Environment Support

The network logger is available in the following environments:

- ✅ **Debug Mode**: Always enabled during development
- ✅ **Staging Environment**: Enabled when `STAGING_ENV=true`
- ✅ **Release Mode**: Can be enabled with `NETWORK_LOGGER_ENABLED=true`
- ❌ **Production Environment**: Disabled by default for security

### Running in Different Environments

#### Debug Mode (Default)
```bash
flutter run
```

#### Staging Environment
```bash
flutter run --dart-define=STAGING_ENV=true
```

#### Release Mode with Logger
```bash
flutter run --release --dart-define=NETWORK_LOGGER_ENABLED=true
```

### Building for Different Flavors

For Android:
```bash
# Debug flavor
flutter build apk --flavor debug

# Staging flavor
flutter build apk --flavor staging --dart-define=STAGING_ENV=true

# Production flavor
flutter build apk --flavor production
```

For iOS:
```bash
# Debug configuration
flutter build ios --flavor Debug

# Staging configuration
flutter build ios --flavor Staging --dart-define=STAGING_ENV=true

# Release configuration
flutter build ios --flavor Release
```

## 📱 Platform Support

### iOS Simulator (Best for Mac)
1. Run your Flutter app on iOS simulator
2. Open browser on your Mac
3. Navigate to: **http://localhost:3000**

### Android Emulator
1. Run your Flutter app on Android emulator
2. Open browser on the emulator itself
3. Navigate to: **http://localhost:3000**

### Physical Devices
1. Find your device's IP address
2. Open browser on any device on the same network
3. Navigate to: **http://YOUR_DEVICE_IP:3000**

## 🔧 Troubleshooting

### Dashboard Not Loading
- Check if server is running (look for console message)
- Verify platform support
- Check environment settings
- Ensure port 3000 is not blocked

### iOS Local Network Setup
1. Go to iOS Settings → Privacy & Security → Local Network
2. Find your app and toggle it ON
3. Run your app and try accessing the dashboard

## 📚 API Reference

### Main Functions

```dart
// Start the network logger server
Future<bool> startNetworkLogServer()

// Stop the network logger server
Future<void> stopNetworkLogServer()

// Check if server is running
bool isNetworkLogServerRunning()

// Get dashboard URL
String? getNetworkLogDashboardUrl()

// Check platform support
bool isNetworkLoggerSupported()
```

### Configuration

```dart
class NetworkLoggerConfig {
  // Check if logger is enabled
  static bool get isEnabled

  // Get current flavor/environment
  static String get currentFlavor

  // Check if logger is enabled in specific flavor
  static bool isEnabledInFlavor(String flavor)
}
```

### Configuration Examples

#### Basic Setup
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the logger (automatically handles environment)
  await NetworkLogger.start();
  
  runApp(MyApp());
}
```

#### Environment Configuration
```dart
void setupNetworkLogger() {
  // Configure with predefined environments
  NetworkLogger.configure(
    environments: [
      NetworkLoggerEnvironment.debug,
      NetworkLoggerEnvironment.staging,
      NetworkLoggerEnvironment.qa,
    ],
  );
}

// Or use custom environments
NetworkLogger.configure(
  environments: [
    NetworkLoggerEnvironment.custom(
      name: 'uat',
      enableByDefault: true,
      description: 'User Acceptance Testing',
    ),
    NetworkLoggerEnvironment.custom(
      name: 'preprod',
      enableByDefault: true,
      description: 'Pre-Production Environment',
    ),
  ],
);
```

#### Enable in Release Mode
```dart
// Enable logger in release mode for specific environments
NetworkLogger.configure(
  environments: [NetworkLoggerEnvironment.staging],
  enableInRelease: true,
);
```

#### Check Logger Status
```dart
// Check if logger is running
if (NetworkLogger.isRunning) {
  // Get dashboard URL
  final url = NetworkLogger.dashboardUrl;
  print('Dashboard available at: $url');
}
```

#### Environment-Specific Behavior
```dart
// The logger automatically handles different environments:
// - Debug: Always enabled
// - Staging: Enabled by default
// - QA: Enabled by default
// - Beta: Enabled by default
// - Production: Always disabled
// - Custom: Configurable via enableByDefault
```

## 🎯 Use Cases

### Quick Start
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NetworkLogger.start();
  runApp(MyApp());
}
```

### QA Testing Setup
```dart
void setupForQATesting() {
  NetworkLogger.configure(
    environments: [NetworkLoggerEnvironment.qa],
    enableInRelease: true,
  );
}
```

### Multiple Environment Support
```dart
void setupAllEnvironments() {
  NetworkLogger.configure(
    environments: [
      NetworkLoggerEnvironment.debug,
      NetworkLoggerEnvironment.staging,
      NetworkLoggerEnvironment.qa,
      NetworkLoggerEnvironment.beta,
    ],
  );
}
```

### Custom Environment
```dart
void setupCustomEnvironment() {
  NetworkLogger.configure(
    environments: [
      NetworkLoggerEnvironment.custom(
        name: 'demo',
        enableByDefault: true,
        description: 'Demo Environment',
      ),
    ],
  );
}
```

### Custom Environment Support
The network logger supports custom environment types for flexible configuration:

1. **Add Custom Environments**
   ```dart
   // Add your custom environments
   NetworkLoggerConfig.addCustomEnvironment('qa');
   NetworkLoggerConfig.addCustomEnvironment('beta');
   NetworkLoggerConfig.addCustomEnvironment('uat');
   ```

2. **Run with Custom Environment**
   ```bash
   # Run with QA environment
   flutter run --dart-define=CUSTOM_ENV=qa --dart-define=NETWORK_LOGGER_ENABLED=true
   
   # Run with Beta environment
   flutter run --dart-define=CUSTOM_ENV=beta --dart-define=NETWORK_LOGGER_ENABLED=true
   ```

3. **Environment-Specific Behavior**
   - Debug: Always enabled
   - Staging: Enabled by default
   - Custom: Enabled when NETWORK_LOGGER_ENABLED=true
   - Production: Always disabled

### QA Testing in Release Mode
The network logger is particularly useful for QA teams testing release builds in staging environment:

1. **Release Mode Testing**
   ```bash
   # Build release version with staging environment
   flutter build apk --release --dart-define=STAGING_ENV=true
   ```

2. **Enable Logger in Release**
   ```bash
   # Enable logger in release mode for staging environment
   flutter run --release --dart-define=STAGING_ENV=true --dart-define=NETWORK_LOGGER_ENABLED=true
   ```

3. **Benefits for QA Teams**
   - Monitor network requests in release builds
   - Debug issues in staging environment
   - Test with production-like performance
   - Maintain security in production

### Development Workflow
1. **Local Development**
   - Debug mode with full logging
   - Real-time request monitoring
   - Immediate feedback

2. **Staging Testing**
   - Release mode with controlled logging
   - QA team access to network logs
   - Production-like environment

3. **Production Deployment**
   - Logger automatically disabled
   - No performance impact
   - Secure by default

## 🎯 Example

Check out the [example](example) directory for a complete working example.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
