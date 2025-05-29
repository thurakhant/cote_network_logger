# Cote Network Logger 🌐

[![pub package](https://img.shields.io/pub/v/cote_network_logger.svg)](https://pub.dev/packages/cote_network_logger)
[![popularity](https://img.shields.io/pub/popularity/cote_network_logger?logo=dart)](https://pub.dev/packages/cote_network_logger/score)
[![likes](https://img.shields.io/pub/likes/cote_network_logger?logo=dart)](https://pub.dev/packages/cote_network_logger/score)
[![pub points](https://img.shields.io/pub/points/cote_network_logger?logo=dart)](https://pub.dev/packages/cote_network_logger/score)

A Flutter developer tool for monitoring HTTP network activity with a beautiful web dashboard. Perfect for debugging API calls during development.

## Features

- 🚀 **Easy Setup** - Add one line and you're ready
- 🎨 **Web Dashboard** - View all network activity in your browser
- ⚡ **Real-time** - See requests as they happen
- 📱 **Cross-platform** - Works on mobile and desktop
- 🔒 **Debug Only** - Completely disabled in release builds
- 💾 **Memory Safe** - Automatically cleans up old logs

## Screenshots

![Cote Network Logger Demo](https://raw.githubusercontent.com/thurakhant/cote_network_logger/main/screenshots/side_by_side.png)

| Mobile App | Dashboard |
|------------|-----------|
| ![Mobile Demo](https://raw.githubusercontent.com/thurakhant/cote_network_logger/main/screenshots/mobile_demo.png) | ![Dashboard](https://raw.githubusercontent.com/thurakhant/cote_network_logger/main/screenshots/dashboard.png) |

## Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cote_network_logger: ^1.0.0
```

Start the server in your `main.dart`:

```dart
import 'package:cote_network_logger/cote_network_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the dashboard server
  await startNetworkLogServer();
  
  runApp(MyApp());
}
```

Add the interceptor to your Dio instance:

```dart
import 'package:dio/dio.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

final dio = Dio();
dio.interceptors.add(const CoteNetworkLogger());
```

Open `http://localhost:3000` in your browser to see the dashboard!

## Platform Support

| Platform | Dashboard | Logging |
|----------|-----------|---------|
| iOS | ✅ | ✅ |
| Android | ✅ | ✅ |
| macOS | ✅ | ✅ |
| Windows | ✅ | ✅ |
| Linux | ✅ | ✅ |
| Web | ❌ | ✅ Console |

*Web browsers can't run the dashboard server due to security restrictions. Network requests are still logged to the console.*

## Example Usage

```dart
class ApiService {
  final Dio _dio = Dio();
  
  ApiService() {
    // Add the network logger
    _dio.interceptors.add(const CoteNetworkLogger());
  }
  
  Future<Response> getPosts() {
    return _dio.get('https://jsonplaceholder.typicode.com/posts');
  }
  
  Future<Response> createPost(Map<String, dynamic> data) {
    return _dio.post('https://jsonplaceholder.typicode.com/posts', data: data);
  }
}
```

## API Reference

### Functions

- `startNetworkLogServer()` - Start the dashboard server
- `stopNetworkLogServer()` - Stop the dashboard server  
- `isNetworkLogServerRunning()` - Check if server is running
- `getNetworkLogDashboardUrl()` - Get the dashboard URL

### Classes

- `CoteNetworkLogger` - Dio interceptor for capturing requests
- `NetworkLogStore` - Storage for network logs
- `NetworkLogWebServer` - Web server for the dashboard

## Dashboard Features

- View all HTTP requests and responses
- Filter by method, status code, or URL
- Search through request/response data
- Color-coded status codes
- Real-time updates
- Clear logs with one click

## Security & Performance

- **Debug Mode Only**: All functionality is disabled in release builds
- **Local Only**: Server only binds to localhost (127.0.0.1)
- **Memory Limited**: Keeps only the last 200 requests
- **No Persistence**: Logs are stored in memory only
- **Lightweight**: Minimal impact on app performance

## Troubleshooting

**Dashboard not loading?**
- Make sure you're in debug mode
- Check that port 3000 isn't being used by another app
- Visit `http://localhost:3000` (not `127.0.0.1:3000`)

**No requests showing?**
- Verify the interceptor is added to your Dio instance
- Make sure your app is actually making HTTP requests
- Check the browser console for any errors

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## Migration Guide

### From v0.x.x to v1.0.0

**Class Name Change:**
The interceptor class has been renamed for consistency:
- **Old:** `NetworkLoggerInterceptor`
- **New:** `CoteNetworkLogger`

Simply update your import usage:
```dart
// Before
dio.interceptors.add(const NetworkLoggerInterceptor());

// After  
dio.interceptors.add(const CoteNetworkLogger());
```

All other functionality remains the same.

## License

MIT License - see [LICENSE](LICENSE) file for details.