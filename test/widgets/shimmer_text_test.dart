import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/shimmer_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Finder get _mask => find.descendant(
  of: find.byType(ShimmerText),
  matching: find.byType(ShaderMask),
);

void main() {
  group('ShimmerText', () {
    testWidgets('renders its text', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ShimmerText('Thinking...')));
      expect(find.text('Thinking...'), findsOneWidget);
      expect(_mask, findsOneWidget);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('keeps looping while mounted', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const ShimmerText(
            'Thinking...',
            duration: Duration(milliseconds: 300),
          ),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.binding.hasScheduledFrame, isTrue);
      }
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('waits for interval between sweeps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ShimmerText(
            'Thinking...',
            duration: Duration(milliseconds: 200),
            interval: Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // The sweep finished and the pause timer is pending: no frames.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('reduced motion renders static text without frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ShimmerText('Thinking...'), reduceMotion: true),
      );
      await tester.pump();
      expect(find.text('Thinking...'), findsOneWidget);
      expect(_mask, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false stops the sweep', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ShimmerText('Thinking...')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(const ShimmerText('Thinking...', enabled: false)),
      );
      await tester.pump();
      expect(_mask, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_wrap(const ShimmerText('Thinking...')));
      await tester.pump();
      expect(_mask, findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('child constructor shimmers any widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ShimmerText.child(child: Icon(Icons.auto_awesome))),
      );
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(_mask, findsOneWidget);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('child keeps a solid tint under reduced motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ShimmerText.child(child: Icon(Icons.auto_awesome)),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(_mask, findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('config changes mid-sweep do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ShimmerText('A')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          const ShimmerText(
            'B',
            duration: Duration(milliseconds: 500),
            curve: Curves.linear,
            bandWidth: 0.6,
            interval: Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('disposing during the pause cancels the timer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ShimmerText(
            'A',
            duration: Duration(milliseconds: 100),
            interval: Duration(seconds: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_wrap(const SizedBox()));
      // A pending timer would fail the test at teardown.
    });

    testWidgets('text stays readable by screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const ShimmerText('Thinking...')));
      expect(find.bySemanticsLabel('Thinking...'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(_wrap(const SizedBox()));
    });
  });
}
