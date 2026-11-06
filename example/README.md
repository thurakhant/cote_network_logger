# Explicit-session example

Run from this directory with `flutter run`. Tap **Start session**, then **Send
test GET**. Requests go to JSONPlaceholder only when you tap the request button.
Bodies remain metadata-only and dashboard access stays on loopback.

Tap **Reveal private pairing link** to display the credential-bearing link in
this app. Open it in your own browser. Do not share, log or screenshot it. On
Android, first run `adb forward tcp:3000 tcp:3000` on your laptop.

**Stop session** stops capture and closes the server. The widget disposes its
session and Dio client when removed. Profile/release also requires
`--dart-define=NETWORK_LOGGER_ENABLED=true`; runtime configuration remains an
independent gate. `STAGING_ENV` does not enable the logger.

See the [package guide](../README.md) for explicit LAN access, optional JSON field
capture and 1.x migration. This example belongs to the unpublished 2.0.0 local
release candidate. Browser and device acceptance gates remain open.
