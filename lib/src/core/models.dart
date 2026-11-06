import 'dart:convert';
import 'bounded_json.dart';
import 'limits.dart';
part 'store.dart';

enum NetworkCallState { pending, completed, failed, cancelled }

enum NetworkErrorKind {
  connection,
  timeout,
  badResponse,
  cancelled,
  certificate,
  unknown
}

enum BodyKind {
  absent,
  omitted,
  json,
  text,
  binarySummary,
  multipartSummary,
  unsupported
}

class NetworkCall {
  NetworkCall._({
    required this.id,
    required this.request,
    this.response,
    this.error,
    required this.state,
    this.durationMicros,
    required this.revision,
    required this.incompleteRequest,
    required this.observedAt,
    this.endedAt,
  });
  final String id;
  final NetworkRequest request;
  final NetworkResponse? response;
  final NetworkError? error;
  final NetworkCallState state;
  final int? durationMicros;
  final int revision;
  final bool incompleteRequest;
  final DateTime observedAt;
  final DateTime? endedAt;
  Map<String, Object?> _toJson() => {
        'id': id,
        'request': request._toJson(),
        'response': response?._toJson(),
        'error': error?._toJson(),
        'state': state.name,
        'durationMicros': durationMicros,
        'revision': revision,
        'incompleteRequest': incompleteRequest,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
      };
}

class NetworkRequest {
  NetworkRequest._({
    required this.method,
    required this.url,
    required Map<String, List<String>> headers,
    required this.body,
    this.startedAt,
    List<String> captureWarnings = const [],
  })  : headers = Map.unmodifiable(
          headers.map(
            (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
          ),
        ),
        captureWarnings = List.unmodifiable(captureWarnings);
  final String method;
  final String url;
  final Map<String, List<String>> headers;
  final BodySnapshot body;
  final DateTime? startedAt;
  final List<String> captureWarnings;
  Map<String, Object?> _toJson() => {
        'method': method,
        'url': url,
        'headers': detachedJsonCopy(headers),
        'body': body._toJson(),
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'captureWarnings': detachedJsonCopy(captureWarnings),
      };
}

class NetworkResponse {
  NetworkResponse._({
    this.statusCode,
    required Map<String, List<String>> headers,
    required this.body,
    required this.endedAt,
    List<String> captureWarnings = const [],
  })  : headers = Map.unmodifiable(
          headers.map(
            (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
          ),
        ),
        captureWarnings = List.unmodifiable(captureWarnings);
  final int? statusCode;
  final Map<String, List<String>> headers;
  final BodySnapshot body;
  final DateTime endedAt;
  final List<String> captureWarnings;
  Map<String, Object?> _toJson() => {
        'statusCode': statusCode,
        'headers': detachedJsonCopy(headers),
        'body': body._toJson(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'captureWarnings': detachedJsonCopy(captureWarnings),
      };
}

class BodySnapshot {
  BodySnapshot._({
    required this.kind,
    this.contentType,
    this.knownSizeBytes,
    required this.truncated,
    this.omissionReason,
    this.content,
    this.summary,
  });
  final BodyKind kind;
  final String? contentType;
  final int? knownSizeBytes;
  final bool truncated;
  final String? omissionReason;
  final Object? content;
  final BodySummary? summary;
  Map<String, Object?> _toJson() => {
        'kind': kind.name,
        'contentType': contentType,
        'knownSizeBytes': knownSizeBytes,
        'truncated': truncated,
        'omissionReason': omissionReason,
        'content': detachedJsonCopy(content),
        'summary': summary?._toJson(),
      };
}

class BodySummary {
  BodySummary._({
    this.fieldCount,
    this.fileCount,
    List<String> contentTypes = const [],
  }) : contentTypes = List.unmodifiable(contentTypes);
  final int? fieldCount;
  final int? fileCount;
  final List<String> contentTypes;
  Map<String, Object?> _toJson() => {
        'fieldCount': fieldCount,
        'fileCount': fileCount,
        'contentTypes': detachedJsonCopy(contentTypes),
      };
}

class LoggerChange {
  LoggerChange._({
    required this.sessionId,
    required this.version,
  });
  final String sessionId;
  final int version;
}

class LoggerSnapshot {
  LoggerSnapshot._({
    required this.sessionId,
    required this.version,
    required this.clearGeneration,
    List<NetworkCall> calls = const [],
  }) : calls = List.unmodifiable(calls);
  final String sessionId;
  final int version;
  final int clearGeneration;
  final List<NetworkCall> calls;
  int get schemaVersion => 2;
  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'sessionId': sessionId,
        'version': version,
        'clearGeneration': clearGeneration,
        'calls': calls.map((call) => call._toJson()).toList(),
      };
}

class NetworkError {
  NetworkError._(this.kind, this._maxBytes);
  final NetworkErrorKind kind;
  final int _maxBytes;
  String get description {
    final safe = switch (kind) {
      NetworkErrorKind.connection => 'Connection failed',
      NetworkErrorKind.timeout => 'Request timed out',
      NetworkErrorKind.badResponse => 'Response rejected',
      NetworkErrorKind.cancelled => 'Request cancelled',
      NetworkErrorKind.certificate => 'Certificate rejected',
      NetworkErrorKind.unknown => 'Request failed',
    };
    return safe.substring(0, safe.length < _maxBytes ? safe.length : _maxBytes);
  }

  Map<String, Object?> _toJson() =>
      {'kind': kind.name, 'description': description};
}

/// Internal bridge for sanitized adapters; not exported by the package.
class CoreRecords {
  static NetworkRequest request({
    required String method,
    required String url,
    Map<String, List<String>> headers = const {},
    BodySnapshot? body,
    DateTime? startedAt,
    List<String> captureWarnings = const [],
  }) =>
      NetworkRequest._(
        method: method,
        url: url,
        headers: headers,
        body: body ?? BodySnapshot._(kind: BodyKind.absent, truncated: false),
        startedAt: startedAt?.toUtc(),
        captureWarnings: captureWarnings,
      );
  static NetworkResponse response({
    int? statusCode,
    Map<String, List<String>> headers = const {},
    BodySnapshot? body,
    required DateTime endedAt,
    List<String> captureWarnings = const [],
  }) =>
      NetworkResponse._(
        statusCode: statusCode,
        headers: headers,
        body: body ?? BodySnapshot._(kind: BodyKind.absent, truncated: false),
        endedAt: endedAt.toUtc(),
        captureWarnings: captureWarnings,
      );
  static NetworkError error(NetworkErrorKind kind, {int maxBytes = 1024}) {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    return NetworkError._(kind, maxBytes);
  }

  static BodySummary summary({
    int? fieldCount,
    int? fileCount,
    List<String> contentTypes = const [],
  }) =>
      BodySummary._(
        fieldCount: fieldCount,
        fileCount: fileCount,
        contentTypes: contentTypes,
      );
  static BodySnapshot body({
    required BodyKind kind,
    String? contentType,
    int? knownSizeBytes,
    bool truncated = false,
    String? omissionReason,
    Object? content,
    BodySummary? summary,
    LoggerLimits limits = const LoggerLimits(),
  }) {
    if (kind == BodyKind.json || kind == BodyKind.text) {
      if (kind == BodyKind.text && content is! String) {
        return BodySnapshot._(
          kind: BodyKind.unsupported,
          truncated: false,
          contentType: contentType,
          omissionReason: 'unsupportedType',
        );
      }
      if (kind == BodyKind.text) {
        limits.validate();
        final value = content as String;
        final cap = limits.maxBodyBytes < limits.maxScalarBytes
            ? limits.maxBodyBytes
            : limits.maxScalarBytes;
        var end = 0;
        var bytes = 0;
        while (end < value.length) {
          final unit = value.codeUnitAt(end);
          var width = 1;
          var size = unit < 128 ? 1 : (unit < 2048 ? 2 : 3);
          if (unit >= 0xd800 && unit <= 0xdbff && end + 1 < value.length) {
            final next = value.codeUnitAt(end + 1);
            if (next >= 0xdc00 && next <= 0xdfff) {
              width = 2;
              size = 4;
            }
          }
          if (bytes + size > cap) break;
          bytes += size;
          end += width;
        }
        final cut = end < value.length;
        return BodySnapshot._(
          kind: kind,
          contentType: contentType,
          knownSizeBytes: bytes,
          truncated: truncated || cut,
          omissionReason: cut ? 'byteLimit' : omissionReason,
          content: value.substring(0, end),
        );
      }
      final copied = BoundedJson.copy(content, limits: limits);
      if (!copied.isSuccess) {
        return BodySnapshot._(
          kind: BodyKind.omitted,
          contentType: contentType,
          truncated: copied.omissionReason == 'byteLimit',
          omissionReason: copied.omissionReason,
        );
      }
      return BodySnapshot._(
        kind: kind,
        contentType: contentType,
        knownSizeBytes: copied.sizeBytes,
        truncated: truncated,
        omissionReason: omissionReason,
        content: copied.value,
      );
    }
    return BodySnapshot._(
      kind: kind,
      contentType: contentType,
      knownSizeBytes: knownSizeBytes,
      truncated: truncated,
      omissionReason: omissionReason,
      summary: summary,
    );
  }
}
