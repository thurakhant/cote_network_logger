import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cote_network_logger/src/core/capture.dart';
import 'package:cote_network_logger/src/core/capture_policy.dart';
import 'package:cote_network_logger/src/core/limits.dart';
import 'package:cote_network_logger/src/core/models.dart';

class Poison {
  @override
  String toString() => throw StateError('called');
}

void main() {
  test('explicit null, primitives, direction, conflicts, traversal budgets',
      () {
    CaptureEngine engine(
            {LoggerLimits limits = const LoggerLimits(),
            List<BodyCaptureRule>? rules,}) =>
        CaptureEngine(
            limits: limits,
            policy: CapturePolicy(
                bodyRules: rules ??
                    [
                      BodyCaptureRule(
                          host: 'a', path: '/', allowedJsonPaths: {r'$'},),
                    ],),);
    final e = engine();
    expect(
        e.request(method: 'GET', url: 'https://a/').body.kind, BodyKind.absent,);
    for (final value in [null, false, 0, '']) {
      final result =
          e.request(method: 'GET', url: 'https://a/', body: value).body;
      expect(result.kind, BodyKind.json);
      expect(result.content, value);
    }
    final depth = engine(limits: const LoggerLimits(maxDepth: 1))
        .request(method: 'GET', url: 'https://a/', body: [
      [1],
    ],);
    expect(depth.body.omissionReason, 'depthLimit');
    final nodes = engine(limits: const LoggerLimits(maxVisitedNodes: 2))
        .request(method: 'GET', url: 'https://a/', body: [1, 2]);
    expect(nodes.body.omissionReason, 'nodeLimit');
    final conflict = engine(rules: [
      BodyCaptureRule(host: 'a', path: '/', allowedJsonPaths: {r'$'}),
      BodyCaptureRule(host: 'a', path: '/', mode: BodyCaptureMode.text),
    ],).request(method: 'GET', url: 'https://a/', body: 'SECRET');
    expect(conflict.body.omissionReason, 'policyConflict');
    final responseOnly = engine(rules: [
      BodyCaptureRule(
          host: 'a',
          path: '/',
          direction: BodyDirection.response,
          allowedJsonPaths: {r'$'},),
    ],);
    expect(
        responseOnly
            .request(method: 'GET', url: 'https://a/', body: 'SECRET')
            .body
            .content,
        isNull,);
    final headers = e.response(
        host: 'a',
        path: '/',
        method: 'GET',
        endedAt: DateTime.utc(2026),
        headers: {'accept': 'x' * 200},
        headerBudgetBytes: 10,);
    expect(headers.headers, isEmpty);
  });
  test('safe defaults and mandatory deny', () {
    final r = CaptureEngine(
      policy: CapturePolicy(
        allowedHeaders: {'authorization', 'content-type'},
        allowedQueryKeys: {'token', 'ok'},
      ),
    ).request(
      method: 'GET',
      url:
          'https://user:SECRET@api.test/p?token=SECRET&other=SECRET&ok=yes#SECRET',
      headers: {
        'Authorization': 'SECRET',
        'Content-Type': 'application/json',
      },
      body: {
        'secret': 'SECRET',
      },
    );
    expect(r.url, isNot(contains('SECRET')));
    expect(r.headers, {
      'content-type': ['application/json'],
    });
    expect(r.body.kind, BodyKind.omitted);
  });
  test('allows descendants with recursive denies and array positions', () {
    final r = CaptureEngine(
      policy: CapturePolicy(
        bodyRules: [
          BodyCaptureRule(
            host: 'api.test',
            path: '/p',
            allowedJsonPaths: {r'$.items[*].name', r'$.obj'},
            deniedJsonPaths: {r'$.obj.hidden'},
          ),
        ],
      ),
    ).request(
      method: 'GET',
      url: 'https://api.test/p',
      body: {
        'items': [
          {'name': 'ok', 'password': 'SECRET'},
          {'secret': 'SECRET'},
        ],
        'obj': {'ok': false, 'hidden': 'SECRET', 'TOKEN': 'SECRET'},
      },
    );
    expect(jsonEncode(r.body.content), isNot(contains('SECRET')));
    expect(r.body.content, {
      'items': [
        {'name': 'ok'},
        {},
      ],
      'obj': {'ok': false},
    });
    expect(r.captureWarnings, contains('bodyFieldsOmitted'));
  });
  test('immutable policy and grammar validation', () {
    final keys = {'ok'};
    final p = CapturePolicy(allowedQueryKeys: keys);
    keys.add('secret');
    expect(p.allowedQueryKeys, {'ok'});
    expect(() => p.allowedQueryKeys.add('bad'), throwsUnsupportedError);
    expect(
      () => BodyCaptureRule(
        host: 'a',
        path: '/',
        allowedJsonPaths: {r'$..bad'},
      ),
      throwsArgumentError,
    );
  });
  test('bounded traversal and unknown objects fail closed', () {
    final e = CaptureEngine(
      policy: CapturePolicy(
        bodyRules: [
          BodyCaptureRule(host: 'a', path: '/', allowedJsonPaths: {r'$'}),
        ],
      ),
    );
    final cycle = <Object?>[];
    cycle.add(cycle);
    for (final body in [
      Poison(),
      cycle,
      {'ok': 'x' * 70000},
    ]) {
      final r = e.request(method: 'GET', url: 'https://a/', body: body);
      expect(r.body.content, isNull);
    }
  });
  test('path callback failure and text utf8 cap', () {
    final e = CaptureEngine(
      limits: const LoggerLimits(maxBodyBytes: 5),
      policy: CapturePolicy(
        pathSanitizer: (_) => throw StateError('SECRET'),
        bodyRules: [
          BodyCaptureRule(
            host: 'a',
            path: '/SECRET',
            mode: BodyCaptureMode.text,
          ),
        ],
      ),
    );
    final r = e.request(method: 'GET', url: 'https://a/SECRET', body: '😀😀');
    expect(r.url, isNot(contains('SECRET')));
    expect(r.body.content, '😀');
    expect(r.body.truncated, true);
  });
}
