import 'dart:convert';
import 'package:cote_network_logger/src/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cote_network_logger/src/core/bounded_json.dart';
import 'package:cote_network_logger/src/core/limits.dart';

class Hostile {
  @override
  String toString() => throw StateError('must not call');
  Object toJson() => throw StateError('must not call');
}

void main() {
  test('null and bool obey scalar byte budget', () {
    for (final value in [null, true, false]) {
      final length = jsonEncode(value).length;
      expect(
        BoundedJson.copy(value, limits: LoggerLimits(maxScalarBytes: length))
            .isSuccess,
        isTrue,
      );
      expect(
        BoundedJson.copy(
          value,
          limits: LoggerLimits(maxScalarBytes: length - 1),
        ).omissionReason,
        'byteLimit',
      );
    }
  });

  test('snapshot serialization is detached and includes explicit null fields',
      () {
    final store = CallStore(limits: const LoggerLimits())..reset('session');
    final started = DateTime.utc(2026, 1, 1);
    store.admit(
      id: 'id',
      observedAt: started,
      request: CoreRecords.request(
        method: 'POST',
        url: '/',
        startedAt: started,
        body: CoreRecords.body(
          kind: BodyKind.json,
          content: {
            'items': [false, 0],
          },
        ),
      ),
    );
    final snapshot = store.snapshot;
    final serialized = snapshot.toJson();
    final call = (serialized['calls'] as List).single as Map;
    expect(call.containsKey('endedAt'), isTrue);
    expect(call['endedAt'], isNull);
    final request = call['request'] as Map;
    expect(request['startedAt'], '2026-01-01T00:00:00.000Z');
    final body = request['body'] as Map;
    expect(body.containsKey('summary'), isTrue);
    ((body['content'] as Map)['items'] as List).clear();
    expect(
      ((snapshot.calls.single.request.body.content as Map)['items']),
      [false, 0],
    );
    (serialized['calls'] as List).clear();
    expect(snapshot.calls, hasLength(1));
    expect(() => snapshot.calls.clear(), throwsUnsupportedError);
  });
  test('model metadata copies are defensive and nested headers immutable', () {
    final values = ['application/json'];
    final headers = {'content-type': values};
    final warnings = ['missingRequest'];
    final request = CoreRecords.request(
      method: 'GET',
      url: '/',
      headers: headers,
      captureWarnings: warnings,
    );
    values.clear();
    headers.clear();
    warnings.clear();
    expect(request.headers['content-type'], ['application/json']);
    expect(request.captureWarnings, ['missingRequest']);
    expect(
      () => request.headers['content-type']!.clear(),
      throwsUnsupportedError,
    );
    expect(() => request.captureWarnings.clear(), throwsUnsupportedError);
    expect(request.body.kind, BodyKind.absent);
  });
  test('body factory copies nested JSON and preserves primitive null', () {
    final source = {
      'x': [1],
    };
    final body = CoreRecords.body(kind: BodyKind.json, content: source);
    source['x']!.clear();
    expect((body.content as Map)['x'], [1]);
    expect(CoreRecords.body(kind: BodyKind.json).kind, BodyKind.json);
    expect(CoreRecords.body(kind: BodyKind.json).content, isNull);
    expect(
      CoreRecords.body(kind: BodyKind.json, content: Hostile()).truncated,
      isFalse,
    );
  });
  test('text capture uses raw UTF8 budget and does not split surrogate pairs',
      () {
    final body = CoreRecords.body(
      kind: BodyKind.text,
      content: 'é😀x',
      limits: const LoggerLimits(maxBodyBytes: 6),
    );
    expect(body.content, 'é😀');
    expect(body.knownSizeBytes, 6);
    expect(body.truncated, isTrue);
    final exact = CoreRecords.body(
      kind: BodyKind.text,
      content: 'é😀',
      limits: const LoggerLimits(maxBodyBytes: 6),
    );
    expect(exact.truncated, isFalse);
  });
  test('copies JSON deeply without retaining mutable source', () {
    final input = <String, Object?>{
      'items': [false, 0, '', null],
    };
    final result = BoundedJson.copy(input);
    expect(result.isSuccess, isTrue);
    expect(result.sizeBytes, utf8.encode(jsonEncode(input)).length);
    (input['items'] as List).clear();
    final items = (result.value as Map)['items'] as List;
    expect(items, [false, 0, '', null]);
    expect(() => items.clear(), throwsUnsupportedError);
    expect(() => (result.value as Map).clear(), throwsUnsupportedError);
  });
  test('cycles rejected but shared subtrees accepted', () {
    final cycle = [];
    cycle.add(cycle);
    expect(BoundedJson.copy(cycle).omissionReason, 'cycle');
    final shared = [1];
    expect(BoundedJson.copy([shared, shared]).isSuccess, isTrue);
  });
  test('limits terminate before copying oversized values', () {
    expect(
      BoundedJson.copy('x' * 1000000, maxBytes: 12).omissionReason,
      'byteLimit',
    );
    expect(
      BoundedJson.copy(
        [
          [
            [1],
          ]
        ],
        limits: const LoggerLimits(maxDepth: 1),
      ).omissionReason,
      'depthLimit',
    );
    expect(
      BoundedJson.copy([1, 2], limits: const LoggerLimits(maxVisitedNodes: 2))
          .omissionReason,
      'nodeLimit',
    );
    expect(
      BoundedJson.copy('abcd', limits: const LoggerLimits(maxScalarBytes: 3))
          .omissionReason,
      'byteLimit',
    );
  });
  test('unknown objects, keys and nonfinite numbers are never converted', () {
    for (final value in [
      Hostile(),
      {1: 'x'},
      double.nan,
      double.infinity,
    ]) {
      expect(BoundedJson.copy(value).omissionReason, 'unsupportedType');
    }
  });
  test('UTF8 and escaped JSON bytes exactly match encoding', () {
    for (final value in [
      'é😀\n\t"\\',
      '\ud800',
      '\udc00',
      {'é': '\u0000'},
      null,
      1.5,
    ]) {
      final bytes = utf8.encode(jsonEncode(value)).length;
      expect(BoundedJson.copy(value, maxBytes: bytes).sizeBytes, bytes);
      expect(BoundedJson.copy(value, maxBytes: bytes - 1).isSuccess, isFalse);
    }
  });
  test('limits reject nonpositive values', () {
    expect(
      () => const LoggerLimits(maxCalls: 0).validate(),
      throwsArgumentError,
    );
  });
}
