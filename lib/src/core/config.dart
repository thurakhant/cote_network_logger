import 'capture_policy.dart';
import 'limits.dart';

enum DashboardAccess { loopback, lan }

enum LoggerLifecycle { idle, starting, running, stopping, disposed }

enum LoggerPlatformSupport { supported, unsupportedWeb, unsupportedPlatform }

enum LoggerStartStatus {
  running,
  disabled,
  unsupportedPlatform,
  addressInUse,
  bindFailed,
  authInitializationFailed,
  cancelled,
  disposed,
}

class LoggerConfig {
  LoggerConfig({
    this.enabled = true,
    this.access = DashboardAccess.loopback,
    this.port = 3000,
    this.advertisedAddress,
    this.limits = const LoggerLimits(),
    CapturePolicy? capture,
    this.onDiagnostic,
  }) : capture = capture ?? CapturePolicy() {
    if (port < 0 || port > 65535) throw ArgumentError.value(port, 'port');
    limits.validate();
    final address = advertisedAddress;
    if (address != null) {
      if (access != DashboardAccess.lan || !_isIpv4(address)) {
        throw ArgumentError.value(
          address,
          'advertisedAddress',
          'LAN IPv4 literal required',
        );
      }
    }
  }
  final bool enabled;
  final DashboardAccess access;
  final int port;
  final String? advertisedAddress;
  final LoggerLimits limits;
  final CapturePolicy capture;
  final void Function(LoggerDiagnostic)? onDiagnostic;
  static bool _isIpv4(String value) {
    if (value.length > 15) return false;
    final parts = value.split('.');
    return parts.length == 4 &&
        parts.every(
          (part) =>
              RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) &&
              int.parse(part) <= 255,
        );
  }
}

class LoggerDiagnostic {
  const LoggerDiagnostic._(this.code);
  final String code;
}

class LoggerStartResult {
  LoggerStartResult._({
    required this.status,
    this.dashboardUri,
    List<Uri> lanCandidates = const [],
    List<String> warningCodes = const [],
  })  : lanCandidates = List.unmodifiable(lanCandidates),
        warningCodes = List.unmodifiable(warningCodes);
  final LoggerStartStatus status;
  final Uri? dashboardUri;
  final List<Uri> lanCandidates;
  final List<String> warningCodes;
}

/// Internal factories; output constructors stay private to the library.
class CoreConfigRecords {
  static LoggerDiagnostic diagnostic(String code) => LoggerDiagnostic._(code);
  static LoggerStartResult start({
    required LoggerStartStatus status,
    Uri? dashboardUri,
    List<Uri> lanCandidates = const [],
    List<String> warningCodes = const [],
  }) =>
      LoggerStartResult._(
        status: status,
        dashboardUri: dashboardUri,
        lanCandidates: lanCandidates,
        warningCodes: warningCodes,
      );
}

/// Internal build gate, shared by facade and the release-mode matrix test.
bool effectiveLoggerEnabled({
  required bool runtimeEnabled,
  required bool debugMode,
  required bool releaseOptIn,
}) =>
    runtimeEnabled && (debugMode || releaseOptIn);
