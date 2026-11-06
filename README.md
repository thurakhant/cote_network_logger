# Cote Network Logger

Real-time Dio HTTP monitoring for Flutter, with a browser dashboard.

## What's new in 1.2.1

- Request headers and time survive completed and failed calls.
- Live updates work in explicitly enabled release builds.
- FormData, byte buffers, and other unsupported bodies cannot break the log list.
- The startup message prints one local dashboard URL.
- Body and cURL copy work on plain HTTP through a clipboard fallback.

## Network access warning

**Anyone on the same reachable Wi-Fi or local network can read all logged calls, including headers, bodies, and tokens.** The server listens on all interfaces on port 3000. It has no authentication or encryption. The cURL helper masks Authorization and Cookie headers, but the dashboard and API still expose the original values.

Use it only on a trusted test network with test data. Stop the server when finished. Token-based access is planned for 2.0; it is not available in 1.2.1.

## Quick start

```yaml
dependencies:
  cote_network_logger: ^1.2.1
```

Start the server and add the interceptor to the Dio instance making your calls:

```dart
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

final dio = Dio()..interceptors.add(const CoteNetworkLogger());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startNetworkLogServer();
  runApp(MyApp());
}
```

Make a request through `dio`. Open the URL printed as `Network Logger Dashboard` in your laptop browser. The dashboard shows live requests, response status, headers, and bodies. Expand a row to copy its body or cURL command.

JSON bodies remain JSON. FormData is summarized by field/file count, byte buffers by byte count, and unsupported objects by type. These summaries are not replayable upload contents. Copied cURL commands redact Authorization and Cookie; replace those placeholders yourself when needed. Large displayed bodies may be truncated, and copied truncated content includes a notice.

## Open the dashboard

### Android emulator or USB-connected Android phone

Run your app, then forward the dashboard port from your laptop:

```bash
adb forward tcp:3000 tcp:3000
```

Open **http://localhost:3000** in the laptop browser. With multiple devices, use `adb -s DEVICE_SERIAL forward tcp:3000 tcp:3000`.

### Physical Android or iOS device over Wi-Fi

1. Connect the phone and laptop to the same trusted Wi-Fi network.
2. Start the app and open its printed URL, such as `http://192.168.1.20:3000`, on the laptop.
3. If no suitable LAN address is found, the server prints `http://localhost:3000` with a fallback message. On Android, use USB forwarding above.

The address is discovered at server startup. Restart the server after changing networks. Hotspots, VPNs, firewalls, and Wi-Fi client isolation can prevent access. A printed address does not guarantee that the network allows connections.

### iOS simulator and desktop

Open **http://localhost:3000** on the same computer. A discovered LAN URL also lets another computer on the trusted network connect.

The server supports Android, iOS, macOS, Windows, and Linux. Flutter Web cannot host this socket server.

## Enable logging

| Build configuration | Logger |
| --- | --- |
| Debug | Enabled |
| `--dart-define=STAGING_ENV=true` | Enabled |
| `--dart-define=NETWORK_LOGGER_ENABLED=true` | Enabled, including release |
| Release without either flag | Disabled |

For a release test build:

```bash
flutter run --release --dart-define=NETWORK_LOGGER_ENABLED=true
```

`NetworkLogger.configure(enableInRelease: true)` **has no effect**. Use `--dart-define=NETWORK_LOGGER_ENABLED=true` when running or building instead. Registering a custom environment, setting `enableByDefault`, or passing `CUSTOM_ENV` also does not enable logging by itself. Debug mode remains enabled even when `NETWORK_LOGGER_ENABLED=false`.

Do not distribute a production build with either enabling flag.

## API

```dart
await startNetworkLogServer();
final url = getNetworkLogDashboardUrl(); // null until running
final running = isNetworkLogServerRunning();
final supported = isNetworkLoggerSupported();
await stopNetworkLogServer();
```

The `NetworkLogger.start()`, `NetworkLogger.dashboardUrl`, and `NetworkLogger.isRunning` helpers are also available. Stopping the server closes dashboard connections; the interceptor still records calls while the logger configuration is enabled. Call `NetworkLogStore.instance.clearLogs()` to clear stored entries.

The store keeps the most recent 200 transactions in memory. In 1.2.1, completed log maps retain all previous keys and add `requestHeaders` and `requestTimestamp`. The legacy `headers` and `timestamp` fields continue to represent the most recent update. Existing `addRequest` and `addResponse` APIs are unchanged.

## Troubleshooting

- Check that the server started and port 3000 is free.
- Check that the Dio instance making requests has `CoteNetworkLogger` attached.
- For release builds, use one of the enabling build flags above.
- If Wi-Fi blocks access, use Android USB forwarding.
- On iOS, allow local network access for the app if prompted or available in Settings.
- Plain HTTP uses a selection-based copy fallback. If the browser denies copying, the button shows `Failed`; try another browser or select the text manually.

See the [example](example) and [CHANGELOG.md](CHANGELOG.md). Licensed under [MIT](LICENSE).
