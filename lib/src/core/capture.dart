import 'dart:collection';
import 'dart:convert';
import 'capture_policy.dart';
import 'limits.dart';
import 'models.dart';

const _absentBody = Object();

class CaptureEngine {
  CaptureEngine({CapturePolicy? policy, this.limits = const LoggerLimits()})
      : policy = policy ?? CapturePolicy() {
    limits.validate();
  }
  final CapturePolicy policy;
  final LoggerLimits limits;
  String _bound(String s, int cap) {
    var bytes = 0, end = 0;
    for (final rune in s.runes) {
      final n = rune < 128
          ? 1
          : rune < 2048
              ? 2
              : rune < 65536
                  ? 3
                  : 4;
      if (bytes + n > cap) break;
      bytes += n;
      end += rune > 65535 ? 2 : 1;
    }
    return s.substring(0, end);
  }

  Map<String, List<String>> _headers(
    Map<String, dynamic> input,
    int budget,
    Set<String> warnings,
  ) {
    try {
      return _readHeaders(input, budget, warnings);
    } catch (_) {
      warnings.add('policyFailed');
      return {};
    }
  }

  Map<String, List<String>> _readHeaders(
    Map<String, dynamic> input,
    int budget,
    Set<String> warnings,
  ) {
    final out = <String, List<String>>{};
    var used = 2, visited = 0;
    for (final entry in input.entries) {
      if (++visited > limits.maxVisitedNodes) {
        warnings.add('nodeLimit');
        break;
      }
      if (entry.key.length > limits.maxScalarBytes) {
        warnings.add('byteLimit');
        continue;
      }
      final key = entry.key.toLowerCase();
      if (policy.deniedKeys.contains(key) ||
          !policy.allowedHeaders.contains(key)) {
        warnings.add(
          policy.deniedKeys.contains(key) ? 'keyDenied' : 'headerOmitted',
        );
        continue;
      }
      final raw = entry.value;
      final values = raw is List ? raw : [raw];
      final safe = <String>[];
      for (final v in values) {
        if (++visited > limits.maxVisitedNodes) {
          warnings.add('nodeLimit');
          break;
        }
        if (v is! String) continue;
        if (v.length > budget || v.length > limits.maxScalarBytes) {
          warnings.add('byteLimit');
          break;
        }
        final size = utf8.encode(jsonEncode(v)).length + 1;
        if (size - 1 > limits.maxScalarBytes ||
            used + size + utf8.encode(jsonEncode(key)).length + 3 > budget) {
          warnings.add('byteLimit');
          break;
        }
        safe.add(v);
        used += size;
      }
      if (safe.isNotEmpty) {
        used += utf8.encode(jsonEncode(key)).length + 3;
        out[key] = safe;
      }
    }
    return out;
  }

  void _extraQuery(
    Map<String, dynamic> input,
    _QueryCapture query,
    Set<String> warnings,
  ) {
    var nodes = 0;
    for (final entry in input.entries) {
      if (query.full) break;
      if (++nodes > limits.maxVisitedNodes) {
        warnings.add('nodeLimit');
        break;
      }
      final key = entry.key;
      if (key.length > limits.maxUrlBytes ||
          key.length > limits.maxScalarBytes) {
        warnings.add('byteLimit');
        continue;
      }
      final lower = key.toLowerCase();
      if (!policy.allowedQueryKeys.contains(lower) ||
          policy.deniedKeys.contains(lower)) {
        query.add(key, '[REDACTED]');
        warnings.add('queryRedacted');
        continue;
      }
      if (entry.value is List) warnings.add('queryEncodingApproximate');
      final values = entry.value is List ? entry.value as List : [entry.value];
      for (final value in values) {
        if (++nodes > limits.maxVisitedNodes) {
          warnings.add('nodeLimit');
          break;
        }
        String? safe;
        if (value is String) {
          if (value.length <= limits.maxUrlBytes &&
              value.length <= limits.maxScalarBytes) {
            safe = value;
          }
        } else if (value == null) {
          safe = '';
        } else if (value is bool || value is num && value.isFinite) {
          safe = value.toString();
        }
        if (safe == null) {
          safe = '[REDACTED]';
          warnings.add('queryRedacted');
        }
        if (!query.add(key, safe)) break;
      }
      if (nodes > limits.maxVisitedNodes) break;
    }
  }

  NetworkRequest request({
    required String method,
    required String url,
    Map<String, dynamic> queryParameters = const {},
    Map<String, dynamic> headers = const {},
    Object? body = _absentBody,
    DateTime? startedAt,
    BodySnapshot? bodyOverride,
  }) {
    final warnings = <String>{};
    Uri? uri;
    String safeUrl = '';
    try {
      // Bound work before URI parsing and policy callbacks.
      if (url.length > limits.maxUrlBytes) {
        warnings.add('byteLimit');
      } else {
        uri = Uri.parse(url).normalizePath();
        if (uri.userInfo.isNotEmpty) warnings.add('userInfoRedacted');
        var path = uri.path;
        try {
          path = policy.pathSanitizer?.call(path) ?? path;
          if (path != uri.path) warnings.add('pathRedacted');
        } catch (_) {
          path = '';
          warnings.add('pathPolicyFailed');
        }
        path = _bound(path, limits.maxUrlBytes);
        final query = _QueryCapture(limits.maxUrlBytes, warnings);
        for (final e in uri.queryParametersAll.entries) {
          final key = e.key.toLowerCase();
          final allowed = policy.allowedQueryKeys.contains(key) &&
              !policy.deniedKeys.contains(key);
          for (final value in e.value) {
            if (!query.add(e.key, allowed ? value : '[REDACTED]')) break;
          }
          if (!allowed) warnings.add('queryRedacted');
        }
        _extraQuery(queryParameters, query, warnings);
        final cleaned = Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: path,
          queryParameters: query.values.isEmpty ? null : query.values,
        );
        safeUrl = _bound(cleaned.toString(), limits.maxUrlBytes);
        if (safeUrl.length < cleaned.toString().length) {
          warnings.add('byteLimit');
        }
      }
    } catch (_) {
      uri = null;
      warnings.add('policyFailed');
    }
    final safeHeaders = _headers(headers, limits.maxHeadersBytes, warnings);
    final captured = bodyOverride ??
        _body(
          body,
          uri?.host ?? '',
          uri?.path ?? '',
          method,
          BodyDirection.request,
          safeHeaders,
          warnings,
        );
    return CoreRecords.request(
      method: _bound(
        method,
        limits.maxScalarBytes < 64 ? limits.maxScalarBytes : 64,
      ),
      url: safeUrl,
      headers: safeHeaders,
      startedAt: startedAt,
      captureWarnings: List.of(warnings),
      body: captured,
    );
  }

  NetworkResponse response({
    required String host,
    required String path,
    required String method,
    Map<String, dynamic> headers = const {},
    Object? body = _absentBody,
    int? statusCode,
    required DateTime endedAt,
    BodySnapshot? bodyOverride,
    int? headerBudgetBytes,
  }) {
    final warnings = <String>{};
    final safeHeaders = _headers(
      headers,
      headerBudgetBytes ?? limits.maxHeadersBytes,
      warnings,
    );
    final captured = bodyOverride ??
        _body(
          body,
          host,
          path,
          method,
          BodyDirection.response,
          safeHeaders,
          warnings,
        );
    return CoreRecords.response(
      statusCode: statusCode,
      headers: safeHeaders,
      body: captured,
      endedAt: endedAt,
      captureWarnings: List.of(warnings),
    );
  }

  BodySnapshot _body(
    Object? body,
    String host,
    String path,
    String method,
    BodyDirection direction,
    Map<String, List<String>> headers,
    Set<String> warnings,
  ) {
    final contentType = headers['content-type']?.first;
    BodySnapshot omit(String reason) {
      warnings.add(reason);
      return CoreRecords.body(
        kind: BodyKind.omitted,
        contentType: contentType,
        omissionReason: reason,
        truncated: reason == 'byteLimit',
      );
    }

    if (identical(body, _absentBody)) {
      return CoreRecords.body(kind: BodyKind.absent);
    }
    try {
      if (host.length > limits.maxUrlBytes ||
          path.length > limits.maxUrlBytes ||
          method.length > limits.maxScalarBytes) {
        return omit('byteLimit');
      }
      final matches = policy.bodyRules
          .where(
            (r) =>
                r.host == host.toLowerCase() &&
                r.path == path &&
                r.methods.contains(method.toUpperCase()) &&
                (r.direction == direction || r.direction == BodyDirection.both),
          )
          .toList();
      if (matches.isEmpty) return omit('policyOmitted');
      if (matches.map((r) => r.mode).toSet().length > 1) {
        return omit('policyConflict');
      }
      if (matches.first.mode == BodyCaptureMode.text) {
        if (body is! String) return omit('unsupportedType');
        return CoreRecords.body(
          kind: BodyKind.text,
          contentType: contentType,
          content: body,
          limits: limits,
        );
      }
      final allows = matches.expand((r) => r.allows).toList(),
          denies = matches.expand((r) => r.denies).toList();
      if (allows.isEmpty) return omit('policyOmitted');
      final walker = _Filter(policy, limits, allows, denies, warnings);
      final filtered = walker.walk(body, [], 0);
      if (identical(filtered, _missing)) return omit('policyOmitted');
      final result = CoreRecords.body(
        kind: BodyKind.json,
        contentType: contentType,
        content: filtered,
        limits: limits,
      );
      if (result.omissionReason != null) warnings.add(result.omissionReason!);
      return result;
    } on _Failure catch (e) {
      return omit(e.reason);
    } catch (_) {
      return omit('policyFailed');
    }
  }
}

final _missing = Object();

class _Failure implements Exception {
  const _Failure(this.reason);
  final String reason;
}

class _Filter {
  _Filter(this.policy, this.limits, this.allows, this.denies, this.warnings);
  final CapturePolicy policy;
  final LoggerLimits limits;
  final List<List<Object?>> allows, denies;
  final Set<String> warnings;
  final Set<Object> active = HashSet.identity();
  int nodes = 0, bytes = 0;
  bool prefix(List<Object?> a, List<Object?> b) {
    if (a.length > b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] == null ? b[i] is! int : a[i] != b[i]) return false;
    }
    return true;
  }

  void count() {
    if (++nodes > limits.maxVisitedNodes) throw const _Failure('nodeLimit');
  }

  void charge(int n) {
    bytes += n;
    if (bytes > limits.maxBodyBytes) throw const _Failure('byteLimit');
  }

  Object? walk(Object? value, List<Object?> path, int depth) {
    count();
    if (depth > limits.maxDepth) throw const _Failure('depthLimit');
    if (denies.any((p) => prefix(p, path))) {
      warnings.add('bodyFieldsOmitted');
      return _missing;
    }
    final selected = allows.any((p) => prefix(p, path));
    final needed = selected ||
        allows.any(
          (p) =>
              path.length <= p.length &&
              prefix(p.sublist(0, path.length), path),
        );
    if (!needed) {
      warnings.add('bodyFieldsOmitted');
      return _missing;
    }
    if (value is Map || value is List) {
      if (!active.add(value!)) throw const _Failure('cycle');
      charge(2);
      try {
        if (value is List) {
          final out = <Object?>[];
          for (var i = 0; i < value.length; i++) {
            charge(1);
            final v = walk(value[i], [...path, i], depth + 1);
            out.add(identical(v, _missing) ? null : v);
          }
          return out;
        }
        final out = <String, Object?>{};
        for (final e in (value as Map).entries) {
          count();
          if (e.key is! String) throw const _Failure('unsupportedType');
          final key = e.key as String;
          if (key.length > limits.maxScalarBytes) {
            throw const _Failure('byteLimit');
          }
          if (policy.deniedKeys.contains(key.toLowerCase())) {
            warnings.add('keyDenied');
            warnings.add('bodyFieldsOmitted');
            continue;
          }
          final v = walk(e.value, [...path, key.toLowerCase()], depth + 1);
          if (!identical(v, _missing)) {
            charge(utf8.encode(jsonEncode(key)).length + 2);
            out[key] = v;
          }
        }
        return out;
      } finally {
        active.remove(value);
      }
    }
    if (!selected) {
      warnings.add('bodyFieldsOmitted');
      return _missing;
    }
    if (value is String) {
      if (value.length > limits.maxScalarBytes ||
          value.length > limits.maxBodyBytes - bytes) {
        throw const _Failure('byteLimit');
      }
      charge(utf8.encode(jsonEncode(value)).length);
      return value;
    }
    if (value == null || value is bool || value is num && value.isFinite) {
      charge(
        value == null
            ? 4
            : value is bool
                ? (value ? 4 : 5)
                : (value as num).toString().length,
      );
      return value;
    }
    throw const _Failure('unsupportedType');
  }
}

// Counts escaped query pairs before retaining or encoding them. Repeated keys
// and delimiters are charged for every value, including empty values.
class _QueryCapture {
  _QueryCapture(this.cap, this.warnings);
  final int cap;
  final Set<String> warnings;
  final values = <String, List<String>>{};
  int bytes = 0;
  bool full = false;
  int componentBytes(String value) {
    var size = 0;
    for (final rune in value.runes) {
      final unreserved = rune >= 65 && rune <= 90 ||
          rune >= 97 && rune <= 122 ||
          rune >= 48 && rune <= 57 ||
          rune == 45 ||
          rune == 46 ||
          rune == 95 ||
          rune == 126;
      size += unreserved
          ? 1
          : rune < 128
              ? 3
              : rune < 2048
                  ? 6
                  : rune < 65536
                      ? 9
                      : 12;
      if (size > cap) return cap + 1;
    }
    return size;
  }

  bool add(String key, String value) {
    if (full) return false;
    final size = componentBytes(key) + componentBytes(value) + 2;
    if (bytes + size > cap) {
      full = true;
      warnings.add('byteLimit');
      return false;
    }
    bytes += size;
    (values[key] ??= []).add(value);
    return true;
  }
}
