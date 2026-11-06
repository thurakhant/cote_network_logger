import '../core/config.dart';
import '../core/models.dart';

abstract class SessionServer {
  LoggerPlatformSupport get platformSupport;
  Future<ServerStart> start(
    LoggerConfig config, {
    required LoggerSnapshot Function() snapshot,
    required void Function() clear,
    required Stream<LoggerChange> changes,
  });
  Future<void> stop();
  Uri? pairingUri({Uri? dashboardUri});
}

class ServerStart {
  ServerStart({
    required this.status,
    this.sessionId = '',
    this.dashboardUri,
    List<Uri> lanCandidates = const [],
    List<String> warningCodes = const [],
  })  : lanCandidates = List.unmodifiable(lanCandidates),
        warningCodes = List.unmodifiable(warningCodes);
  final LoggerStartStatus status;
  final String sessionId;
  final Uri? dashboardUri;
  final List<Uri> lanCandidates;
  final List<String> warningCodes;
}
