import '../core/config.dart';
import '../core/models.dart';
import 'server_contract.dart';

SessionServer createServer() => _UnsupportedServer();

class _UnsupportedServer implements SessionServer {
  @override
  LoggerPlatformSupport get platformSupport =>
      const bool.fromEnvironment('dart.library.js_interop')
          ? LoggerPlatformSupport.unsupportedWeb
          : LoggerPlatformSupport.unsupportedPlatform;
  @override
  Future<ServerStart> start(
    LoggerConfig config, {
    required LoggerSnapshot Function() snapshot,
    required void Function() clear,
    required Stream<LoggerChange> changes,
  }) async =>
      ServerStart(
        status: config.enabled
            ? LoggerStartStatus.unsupportedPlatform
            : LoggerStartStatus.disabled,
      );
  @override
  Future<void> stop() async {}
  @override
  Uri? pairingUri({Uri? dashboardUri}) => null;
}
