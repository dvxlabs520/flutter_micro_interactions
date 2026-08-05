// Smoke test for the flutter_micro_interactions example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_micro_interactions_example/main.dart';

void main() {
  testWidgets('home screen renders demo categories',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MicroInteractionsExampleApp());

    expect(find.text('Flutter Micro Interactions'), findsOneWidget);
    expect(find.text('Gestures & Taps'), findsOneWidget);
    expect(find.text('Buttons & Inputs'), findsOneWidget);

    // Categories further down the list are reachable by scrolling.
    await tester.scrollUntilVisible(find.text('Loading'), 200);
    expect(find.text('Loading'), findsOneWidget);
  });
}
