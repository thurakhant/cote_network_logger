import 'dart:async';

import 'package:cote_network_logger/cote_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetworkLoggerExampleApp());
}

class NetworkLoggerExampleApp extends StatelessWidget {
  const NetworkLoggerExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: LoggerDemo(),
      );
}

class LoggerDemo extends StatefulWidget {
  const LoggerDemo({super.key});

  @override
  State<LoggerDemo> createState() => _LoggerDemoState();
}

class _LoggerDemoState extends State<LoggerDemo> {
  // Profile/release also requires NETWORK_LOGGER_ENABLED at compile time.
  // Default access is loopback; bodies stay metadata-only.
  final _session = NetworkLoggerSession(config: LoggerConfig(enabled: true));
  late final Dio _dio = Dio()
    ..interceptors.add(CoteNetworkLogger(session: _session));
  String _status = 'idle';
  Uri? _pairingUri;
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    final result = await _session.start();
    if (!mounted) return;
    setState(() {
      _status = result.status.name;
      _busy = false;
    });
  }

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _pairingUri = null;
    });
    await _session.stop();
    if (!mounted) return;
    setState(() {
      _status = 'stopped';
      _busy = false;
    });
  }

  Future<void> _sendRequest() async {
    setState(() => _busy = true);
    String status;
    try {
      final response = await _dio.get<Object?>(
        'https://jsonplaceholder.typicode.com/posts/1',
      );
      status = 'HTTP ${response.statusCode}';
    } on DioException {
      // Never print raw errors, headers, URLs or pairing credentials.
      status = 'Request failed; inspect the sanitized dashboard.';
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _busy = false;
    });
  }

  @override
  void dispose() {
    _dio.close(force: true);
    unawaited(_session.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Network logger 2.0')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Loopback access • Metadata-only bodies'),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const Text('Android USB: adb forward tcp:3000 tcp:3000'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy || _session.isRunning ? null : _start,
              child: const Text('Start session'),
            ),
            ElevatedButton(
              onPressed: _busy || !_session.isRunning ? null : _sendRequest,
              child: const Text('Send test GET'),
            ),
            OutlinedButton(
              onPressed: _busy || !_session.isRunning
                  ? null
                  : () => setState(() => _pairingUri = _session.pairingUri()),
              child: const Text('Reveal private pairing link'),
            ),
            if (_pairingUri != null) ...[
              const Text(
                  'This link grants access. Open it in your own browser. '
                  'Do not share it or include it in logs or screenshots.'),
              SelectableText(_pairingUri.toString()),
            ],
            OutlinedButton(
              onPressed: _busy || !_session.isRunning ? null : _stop,
              child: const Text('Stop session'),
            ),
          ],
        ),
      );
}
