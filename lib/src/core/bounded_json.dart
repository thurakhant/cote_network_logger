import 'dart:collection';
import 'limits.dart';

/// Internal, bounded JSON copy. Never invokes application conversion methods.
class BoundedJson {
  static BoundedJsonResult copy(
    Object? input, {
    LoggerLimits limits = const LoggerLimits(),
    int? maxBytes,
  }) {
    limits.validate();
    final walker = _Walker(limits, maxBytes ?? limits.maxBodyBytes);
    try {
      final value = walker.copy(input, 0);
      return BoundedJsonResult._(value, null, walker.bytes);
    } on _Omitted catch (failure) {
      return BoundedJsonResult._(null, failure.reason, 0);
    }
  }
}

class BoundedJsonResult {
  const BoundedJsonResult._(this.value, this.omissionReason, this.sizeBytes);
  final Object? value;
  final String? omissionReason;
  final int sizeBytes;
  bool get isSuccess => omissionReason == null;
}

class _Omitted implements Exception {
  const _Omitted(this.reason);
  final String reason;
}

class _Walker {
  _Walker(this.limits, this.maxBytes);
  final LoggerLimits limits;
  final int maxBytes;
  final Set<Object> ancestors = HashSet.identity();
  int nodes = 0, bytes = 0;
  void add(int count) {
    bytes += count;
    if (bytes > maxBytes) throw const _Omitted('byteLimit');
  }

  void string(String value) {
    // Every UTF-16 unit needs at least one encoded JSON byte. Reject huge
    // existing strings without encoding or scanning their entire content.
    if (value.length > limits.maxScalarBytes ||
        value.length > maxBytes - bytes) {
      throw const _Omitted('byteLimit');
    }
    final start = bytes;
    add(2);
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit == 34 ||
          unit == 92 ||
          unit == 8 ||
          unit == 9 ||
          unit == 10 ||
          unit == 12 ||
          unit == 13) {
        add(2);
      } else if (unit < 32) {
        add(6);
      } else if (unit < 128) {
        add(1);
      } else if (unit < 2048) {
        add(2);
      } else if (unit >= 0xd800 &&
          unit <= 0xdbff &&
          i + 1 < value.length &&
          value.codeUnitAt(i + 1) >= 0xdc00 &&
          value.codeUnitAt(i + 1) <= 0xdfff) {
        add(4);
        i++;
      } else if (unit >= 0xd800 && unit <= 0xdfff) {
        add(6); // Dart JSON escapes unpaired surrogates.
      } else {
        add(3);
      }
      if (bytes - start > limits.maxScalarBytes) {
        throw const _Omitted('byteLimit');
      }
    }
    if (bytes - start > limits.maxScalarBytes) {
      throw const _Omitted('byteLimit');
    }
  }

  Object? copy(Object? value, int depth) {
    if (++nodes > limits.maxVisitedNodes) throw const _Omitted('nodeLimit');
    if (depth > limits.maxDepth) throw const _Omitted('depthLimit');
    if (value == null) {
      if (limits.maxScalarBytes < 4) throw const _Omitted('byteLimit');
      add(4);
      return null;
    }
    if (value is bool) {
      if (limits.maxScalarBytes < (value ? 4 : 5)) {
        throw const _Omitted('byteLimit');
      }
      add(value ? 4 : 5);
      return value;
    }
    if (value is String) {
      string(value);
      return value;
    }
    if (value is num) {
      if (!value.isFinite) throw const _Omitted('unsupportedType');
      final size = value.toString().length;
      if (size > limits.maxScalarBytes) throw const _Omitted('byteLimit');
      add(size);
      return value;
    }
    if (value is! Map && value is! List) {
      throw const _Omitted('unsupportedType');
    }
    if (!ancestors.add(value)) throw const _Omitted('cycle');
    try {
      add(2);
      if (value is List) {
        final output = <Object?>[];
        for (final item in value) {
          if (output.isNotEmpty) add(1);
          output.add(copy(item, depth + 1));
        }
        return List<Object?>.unmodifiable(output);
      }
      final output = <String, Object?>{};
      for (final entry in (value as Map).entries) {
        if (entry.key is! String) throw const _Omitted('unsupportedType');
        if (++nodes > limits.maxVisitedNodes) throw const _Omitted('nodeLimit');
        if (output.isNotEmpty) add(1);
        string(entry.key as String);
        add(1);
        output[entry.key as String] = copy(entry.value, depth + 1);
      }
      return Map<String, Object?>.unmodifiable(output);
    } finally {
      ancestors.remove(value);
    }
  }
}

/// Only for already bounded, trusted JSON held by the output models.
Object? detachedJsonCopy(Object? value) {
  if (value is Map<String, Object?>) {
    return value.map((key, item) => MapEntry(key, detachedJsonCopy(item)));
  }
  if (value is List) return value.map(detachedJsonCopy).toList();
  return value;
}
