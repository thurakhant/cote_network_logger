import 'dart:convert';
import 'package:cote_network_logger/src/core/models.dart';
import 'package:cote_network_logger/src/core/limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counter exhaustion is atomic and requires fresh session', () {
    final store = CallStore(limits: const LoggerLimits(), counterLimit: 1);
    store.reset('s');
    store.clear();
    expect(store.snapshot.version, 1);
    expect(store.snapshot.clearGeneration, 1);
    store.clear();
    expect(store.snapshot.version, 1);
    expect(store.snapshot.clearGeneration, 1);
    store.reset('next');
    expect(store.snapshot.version, 0);
    expect(store.snapshot.clearGeneration, 0);
  });

  final now = DateTime.utc(2026);
  NetworkRequest request([String url = 'https://example.test']) =>
      CoreRecords.request(method: 'GET', url: url, startedAt: now);
  test('completion preserves request and admission order, terminal only once',
      () {
    final store = CallStore(limits: const LoggerLimits());
    store.reset('session');
    final first =
        store.admit(id: 'first', request: request(), observedAt: now)!;
    store.admit(id: 'second', request: request(), observedAt: now);
    expect(
      store.finish(
        first,
        state: NetworkCallState.completed,
        durationMicros: 50,
        endedAt: now.add(const Duration(microseconds: 50)),
      ),
      isTrue,
    );
    expect(store.calls.map((c) => c.id), ['second', 'first']);
    expect(store.calls.last.request.url, 'https://example.test');
    expect(store.calls.last.revision, 2);
    expect(
      store.finish(
        first,
        state: NetworkCallState.failed,
        durationMicros: 60,
        endedAt: now,
      ),
      isFalse,
    );
    expect(store.calls.last.durationMicros, 50);
  });
  test('clear, eviction and restart ignore late completions', () {
    final store = CallStore(limits: const LoggerLimits(maxCalls: 1));
    store.reset('s');
    final old = store.admit(id: 'old', request: request(), observedAt: now)!;
    store.admit(id: 'new', request: request(), observedAt: now);
    expect(
      store.finish(
        old,
        state: NetworkCallState.completed,
        durationMicros: 1,
        endedAt: now,
      ),
      isFalse,
    );
    final token = store.admit(id: 'same', request: request(), observedAt: now)!;
    store.clear();
    store.admit(id: 'same', request: request(), observedAt: now);
    expect(
      store.finish(
        token,
        state: NetworkCallState.completed,
        durationMicros: 1,
        endedAt: now,
      ),
      isFalse,
    );
    expect(store.snapshot.clearGeneration, 1);
    store.reset('new-session');
    expect(store.calls, isEmpty);
    expect(store.snapshot.version, 0);
  });
  test('snapshot is stable and detached, byte limits include metadata', () {
    final store = CallStore(limits: const LoggerLimits(maxStoreBytes: 1600));
    store.reset('s');
    store.admit(id: 'a', request: request(), observedAt: now);
    final snapshot = store.snapshot;
    store.admit(id: 'b', request: request(), observedAt: now);
    expect(snapshot.calls.map((c) => c.id), ['a']);
    expect(() => snapshot.calls.clear(), throwsUnsupportedError);
    final json = snapshot.toJson();
    (json['calls'] as List).clear();
    expect(snapshot.calls, hasLength(1));
    expect(store.encodedBytes, lessThanOrEqualTo(1600));
    expect(
      store.admit(id: 'large', request: request('x' * 4096), observedAt: now),
      isNull,
    );
    expect(store.encodedBytes, lessThanOrEqualTo(1600));
  });
  test('unmatched terminal is explicit and disabled store retains nothing', () {
    final store = CallStore(limits: const LoggerLimits());
    expect(store.admit(id: 'off', request: request(), observedAt: now), isNull);
    store.reset('s');
    store.admitUnmatched(
      id: 'unknown',
      request: request(),
      observedAt: now,
      endedAt: now,
      state: NetworkCallState.failed,
      error: CoreRecords.error(NetworkErrorKind.unknown),
    );
    final call = store.calls.single;
    expect(call.incompleteRequest, isTrue);
    expect(call.request.startedAt, isNull);
    expect(call.durationMicros, isNull);
    expect(call.endedAt, now);
    store.deactivate();
    expect(store.admit(id: 'off', request: request(), observedAt: now), isNull);
    expect(store.calls, hasLength(1));
  });
  test('oversized terminal drops record and diagnostics cannot escape', () {
    final store = CallStore(
      limits: const LoggerLimits(maxStoreBytes: 1500),
      onDiagnostic: (_) => throw StateError('callback'),
    );
    store.reset('s');
    final token = store.admit(id: 'a', request: request(), observedAt: now)!;
    final response = CoreRecords.response(
      endedAt: now,
      body: CoreRecords.body(kind: BodyKind.text, content: 'x' * 2000),
    );
    expect(
      store.finish(
        token,
        response: response,
        state: NetworkCallState.completed,
        durationMicros: 5,
        endedAt: now,
      ),
      isFalse,
    );
    expect(store.calls, isEmpty);
    expect(store.encodedBytes, 0);
  });
  test('cached record budgets exactly match JSON bytes across body variants',
      () {
    final bodies = [
      CoreRecords.body(
        kind: BodyKind.json,
        content: {
          'é😀': [false, 0, '', null, '\n\u0000'],
        },
      ),
      CoreRecords.body(kind: BodyKind.text, content: '\ud800é😀\t"\\'),
      CoreRecords.body(kind: BodyKind.binarySummary, knownSizeBytes: 999999999),
      CoreRecords.body(kind: BodyKind.omitted, omissionReason: 'policyOmitted'),
    ];
    for (final body in bodies) {
      final store = CallStore(limits: const LoggerLimits())..reset('s');
      final admission = store.admit(
        id: 'é',
        observedAt: now,
        request: CoreRecords.request(
          method: 'POST',
          url: 'https://x/é',
          body: body,
          headers: {
            'content-type': ['application/json', 'é\n'],
          },
          startedAt: now,
        ),
      )!;
      for (var phase = 0; phase < 2; phase++) {
        final call = store.calls.single;
        final actual =
            utf8.encode(jsonEncode(CoreRecords.callJson(call))).length;
        expect(CoreRecords.callEncodedBytes(call), actual);
        expect(store.encodedBytes, actual + 2);
        expect(
          jsonEncode(CoreRecords.callEncodingView(call)),
          jsonEncode(CoreRecords.callJson(call)),
        );
        if (phase == 0) {
          store.finish(
            admission,
            state: NetworkCallState.failed,
            response: CoreRecords.response(
              endedAt: now,
              body: body,
              statusCode: 500,
            ),
            error: CoreRecords.error(NetworkErrorKind.unknown),
            durationMicros: 23,
            endedAt: now,
          );
        }
      }
    }
  });
}
