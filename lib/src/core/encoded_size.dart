part of 'models.dart';

int _jsonStringBytes(String value) {
  var bytes = 2;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit == 34 ||
        unit == 92 ||
        unit == 8 ||
        unit == 9 ||
        unit == 10 ||
        unit == 12 ||
        unit == 13) {
      bytes += 2;
    } else if (unit < 32) {
      bytes += 6;
    } else if (unit < 128) {
      bytes++;
    } else if (unit < 2048) {
      bytes += 2;
    } else if (unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < value.length &&
        value.codeUnitAt(i + 1) >= 0xdc00 &&
        value.codeUnitAt(i + 1) <= 0xdfff) {
      bytes += 4;
      i++;
    } else if (unit >= 0xd800 && unit <= 0xdfff) {
      bytes += 6;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

// Used only on trusted, bounded metadata. Body traversal has an exact cached
// size from the bounded copier; knownSizeBytes is never used for budgeting.
int _jsonMetadataBytes(Object? value) {
  if (value == null) return 4;
  if (value is String) return _jsonStringBytes(value);
  if (value is bool) return value ? 4 : 5;
  if (value is num) return value.toString().length;
  if (value is List) {
    var bytes = 2;
    for (var i = 0; i < value.length; i++) {
      bytes += _jsonMetadataBytes(value[i]) + (i == 0 ? 0 : 1);
    }
    return bytes;
  }
  if (value is Map<String, Object?>) return _jsonObjectBytes(value, const {});
  throw StateError('Unsupported internal metadata');
}

int _jsonObjectBytes(Map<String, Object?> value, Map<String, int> childSizes) {
  var bytes = 2;
  var first = true;
  for (final entry in value.entries) {
    bytes += (first ? 0 : 1) +
        _jsonStringBytes(entry.key) +
        1 +
        (childSizes[entry.key] ?? _jsonMetadataBytes(entry.value));
    first = false;
  }
  return bytes;
}
