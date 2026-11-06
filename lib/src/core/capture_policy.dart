import 'dart:convert';

enum BodyDirection { request, response, both }

enum BodyCaptureMode { json, text }

const mandatoryDeniedKeys = {
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'password',
  'token',
  'secret',
};

class CapturePolicy {
  CapturePolicy({
    Set<String> allowedHeaders = const {'content-type', 'accept'},
    Set<String> allowedQueryKeys = const {},
    Set<String> deniedKeys = mandatoryDeniedKeys,
    List<BodyCaptureRule> bodyRules = const [],
    this.pathSanitizer,
  })  : allowedHeaders =
            Set.unmodifiable(allowedHeaders.map((s) => s.toLowerCase())),
        allowedQueryKeys =
            Set.unmodifiable(allowedQueryKeys.map((s) => s.toLowerCase())),
        deniedKeys = Set.unmodifiable({
          ...mandatoryDeniedKeys,
          ...deniedKeys.map((s) => s.toLowerCase()),
        }),
        bodyRules = List.unmodifiable(bodyRules);
  final Set<String> allowedHeaders, allowedQueryKeys, deniedKeys;
  final List<BodyCaptureRule> bodyRules;
  final String Function(String path)? pathSanitizer;
}

class BodyCaptureRule {
  BodyCaptureRule({
    required String host,
    required this.path,
    Set<String> methods = const {'GET'},
    this.direction = BodyDirection.both,
    this.mode = BodyCaptureMode.json,
    Set<String> allowedJsonPaths = const {},
    Set<String> deniedJsonPaths = const {},
  })  : host = host.toLowerCase(),
        methods = Set.unmodifiable(methods.map((s) => s.toUpperCase())),
        allowedJsonPaths = Set.unmodifiable(allowedJsonPaths),
        deniedJsonPaths = Set.unmodifiable(deniedJsonPaths),
        allows = List.unmodifiable(allowedJsonPaths.map(parseJsonPath)),
        denies = List.unmodifiable(deniedJsonPaths.map(parseJsonPath));
  final String host, path;
  final Set<String> methods, allowedJsonPaths, deniedJsonPaths;
  final BodyDirection direction;
  final BodyCaptureMode mode;
  // Internal compiled tokens. An integer is an index; null is any index.
  final List<List<Object?>> allows, denies;
}

List<Object?> parseJsonPath(String source) {
  if (!source.startsWith(r'$')) throw ArgumentError('Invalid JSON path');
  final tokens = <Object?>[];
  var i = 1;
  while (i < source.length) {
    if (source[i] == '.') {
      final match =
          RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').firstMatch(source.substring(++i));
      if (match == null) throw ArgumentError('Invalid JSON path');
      tokens.add(match[0]!.toLowerCase());
      i += match[0]!.length;
    } else if (source[i] == '[') {
      i++;
      if (i < source.length && source[i] == '"') {
        final start = i++;
        var escaped = false;
        while (i < source.length) {
          final c = source[i++];
          if (escaped) {
            escaped = false;
            continue;
          }
          if (c == '\\') {
            escaped = true;
            continue;
          }
          if (c == '"') break;
        }
        try {
          final value = jsonDecode(source.substring(start, i));
          if (value is! String) throw const FormatException();
          tokens.add(value.toLowerCase());
        } catch (_) {
          throw ArgumentError('Invalid JSON path');
        }
      } else {
        final end = source.indexOf(']', i);
        if (end < 0) throw ArgumentError('Invalid JSON path');
        final value = source.substring(i, end);
        if (value == '*') {
          tokens.add(null);
        } else if (RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value) &&
            int.tryParse(value) != null) {
          tokens.add(int.parse(value));
        } else {
          throw ArgumentError('Invalid JSON path');
        }
        i = end;
      }
      if (i >= source.length || source[i] != ']') {
        throw ArgumentError('Invalid JSON path');
      }
      i++;
    } else {
      throw ArgumentError('Invalid JSON path');
    }
  }
  return List.unmodifiable(tokens);
}
