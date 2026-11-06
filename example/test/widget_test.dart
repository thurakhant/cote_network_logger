import 'package:cote_network_logger_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('session starts idle and pairing requires explicit action',
      (tester) async {
    await tester.pumpWidget(const NetworkLoggerExampleApp());
    expect(find.text('Status: idle'), findsOneWidget);
    expect(find.text('Loopback access • Metadata-only bodies'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    final reveal = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Reveal private pairing link'),
    );
    expect(reveal.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
