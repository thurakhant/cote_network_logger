# Cote Network Logger

Dio request inspection for Flutter with an authenticated browser dashboard.
This branch is the **2.0.0 local release candidate**, not a published release.

## Start an explicit session

Use the local package while evaluating this candidate:

```yaml
dependencies:
  cote_network_logger:
    path: ../cote_network_logger
  dio: ^5.4.0
```

```dart
import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';

final session = NetworkLoggerSession(
  config: LoggerConfig(enabled: true),
);
final dio = Dio()..interceptors.add(CoteNetworkLogger(session: session));

Future<LoggerStartResult> startInspection() => session.start();

Future<void> stopInspection() => session.stop();
Future<void> disposeInspection() => session.dispose();
```

Check `result.status == LoggerStartStatus.running` before offering dashboard
access. Capture begins only after successful startup. `stop()` stops capture and
closes connections, retaining sanitized calls for local inspection. `dispose()`
is terminal and clears calls. A successful restart clears data and rotates the
session identity and pairing token. `clear()` clears calls without cancelling
application requests.

Bodies are metadata-only by default. Only `content-type` and `accept` headers
are allowed by default; query values are redacted unless allowed. Mandatory
credential keys cannot be allowed back. URLs may still contain sensitive path
segments: use `CapturePolicy.pathSanitizer` when your routes contain private data.

## Pair a browser

`session.dashboardUri` is a plain address without credentials. The shell alone
cannot read captured calls. Retrieve `session.pairingUri()` only after an explicit
user action, then open that private link in your browser. Do not print it, send
it to analytics, or put it in screenshots. The browser removes the fragment and
keeps the token in memory; reload may require pairing again.

Loopback (`127.0.0.1:3000`) is the default. On Android, forward the port from
your laptop and open the pairing link there:

```bash
adb forward tcp:3000 tcp:3000
```

Use `adb -s DEVICE_SERIAL forward tcp:3000 tcp:3000` with multiple devices.
For a simulator or desktop on the same computer, use the loopback pairing link.

LAN access must be selected explicitly:

```dart
final lanSession = NetworkLoggerSession(
  config: LoggerConfig(access: DashboardAccess.lan),
);
final result = await lanSession.start();
// Offer result.lanCandidates in your own UI after successful startup.
// For a selected candidate:
// lanSession.pairingUri(dashboardUri: selectedCandidate);
```

LAN uses unencrypted HTTP. Use a trusted test network and test data. The server
admits local IPv4 addresses only; IPv6 is deferred. If no LAN address is found,
startup reports `noLanCandidate` and offers loopback/USB access. Network isolation,
firewalls and VPNs may still prevent connections. Restart after changing networks.
Flutter Web compiles with an unsupported-server result; it does not capture or
fall back to console logging.

## Enable profile or release inspection

| Build | Required permission |
| --- | --- |
| Debug | `LoggerConfig(enabled: true)` |
| Profile or release | Runtime `enabled: true` **and** compile-time `NETWORK_LOGGER_ENABLED=true` |
| Any build with runtime `enabled: false` | Disabled |

```bash
flutter run --release --dart-define=NETWORK_LOGGER_ENABLED=true
```

`STAGING_ENV`, custom environment names and the removed `enableInRelease` option
do not grant permission. Keep inspection opt-in in your application configuration.

## Optional body capture

Allow only the fields needed for a particular endpoint:

```dart
final capture = CapturePolicy(bodyRules: [
  BodyCaptureRule(
    host: 'api.example.test',
    path: '/items',
    methods: {'POST'},
    direction: BodyDirection.response,
    allowedJsonPaths: {r'$.items[*].name', r'$.ok'},
  ),
]);
final session = NetworkLoggerSession(config: LoggerConfig(capture: capture));
```

Rules match exact host, path, method and direction. Denies win. Allowing an object
path allows its descendants except denied fields. Text capture requires explicit
`BodyCaptureMode.text`; arbitrary secrets in text cannot be reliably redacted.
Uploads, binary bodies and streams remain summaries and are never consumed by the
logger. Limits bound retained calls, encoded bytes and capture traversal; defaults
include 200 calls, 8 MiB store and 64 KiB per body. Output models and snapshots are
immutable. `session.getSnapshot().toJson()` returns detached serialized data.

## Migrate from 1.x

Before:

```dart
final dio = Dio()..interceptors.add(const CoteNetworkLogger());
await startNetworkLogServer();
```

After:

```dart
final session = NetworkLoggerSession(config: LoggerConfig());
final dio = Dio()..interceptors.add(CoteNetworkLogger(session: session));
final result = await session.start();
// Handle result.status; deliberately reveal session.pairingUri() in your UI.
// On owner shutdown: await session.dispose();
```

| Removed 1.x API | 2.0 replacement |
| --- | --- |
| `NetworkLogger.configure`, `NetworkLoggerConfig`, environment helpers | App-owned `LoggerConfig` and build gate above |
| `NetworkLogger.start`, `startNetworkLogServer`, `startDashboard` | `session.start()` returning `LoggerStartResult` |
| URL/running/support globals and singleton server | `session.dashboardUri`, `isRunning`, `platformSupport` |
| `stopNetworkLogServer` | `session.stop()` |
| `NetworkLogStore.instance`, `getLogs`, `logCount` | `session.getCalls()` and its length |
| `clearLogs`, `clear` on the store | `session.clear()` |
| Request/response constructors and raw store injection | Read-only `NetworkCall.request`, `.response`, `.error` |
| `getRequest`, `getResponse` | Find the call ID in `session.getCalls()` |
| `broadcastLog`, public dashboard asset imports | Removed; internal authenticated transport |
| `/logs`, `/logs/clear`, `/ws` | Removed with HTTP 410; authenticated `/api/v2` protocol |

There are no insecure compatibility wrappers. Import only the package entrypoint.
The package and embedded dashboard must be upgraded together.

## Interpret captured data

- Capture observes Dio callbacks, not wire traffic. Dio `data == null` cannot
  reliably distinguish an absent body from explicit JSON null; the adapter records
  it as absent. False, zero and empty strings remain values when allowed.
- List-valued query encoding is approximate and marked `queryEncodingApproximate`.
  cURL is a sanitized, potentially incomplete aid, not byte-exact replay. It omits
  unsafe or incomplete bodies and reports missing information.
- Body sizes describe captured encoding, not transferred wire bytes. Unknown
  sizes and durations stay unknown. JSON and HAR exports carry capture metadata.
- HAR uses a synthetic `wait` allocation for the observed Dio total duration. It
  is **not measured TTFB**; DNS, connect and transfer phases are unavailable.
  Calls without a known start time or usable HTTP URL are skipped with a reason.
- Dashboard pause freezes the visible view only; capture continues. Clear and new
  sessions invalidate frozen details too. Offline views remain stale until the
  next authenticated snapshot; no durable offline storage is provided.

## Validation status

The compatibility matrix exercised Flutter 3.24.5 / Dart 3.5.4 and Flutter 3.47.9 /
Dart 3.13.7, each with Dio 5.4.0 and 5.11.1. Separate public consumers pass on these combinations. Chromium and WebKit
authentication, synchronization, pause and export checks pass; an exported HAR
imports in Chrome DevTools. A web release consumer returns unsupportedPlatform
without retaining calls. These checks do not establish device performance or
production readiness. Android release functional and APK-size checks pass, including authenticated
USB dashboard access. The strict frame acceptance gate is unmet: ten runs
reported 17 over-budget FrameTiming events with logging versus 10 without it;
these are timing proxies, not measured physical missed frames. Full-store heap,
remaining device timing/LAN checks and final release gates remain open.
iOS/Safari application parity is not validated. No 2.0 publication is claimed.

See the [example](example/lib/main.dart) and [changelog](CHANGELOG.md).
Licensed under [MIT](LICENSE).
