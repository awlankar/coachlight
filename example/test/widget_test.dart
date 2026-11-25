// Author: Nitin Awlankar
// Smoke tests for the example app.

import 'package:coachlight_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tour starts, skips the missing step and can be skipped',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    // showOnce starts the tour automatically on the first frame.
    expect(find.text('Find things'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget); // 5 steps, 1 has no widget

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('skipped'), findsOneWidget);
  });
}
