import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/pulse_highlight.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

Finder _ringLayer() {
  return find.descendant(
    of: find.byType(PulseHighlight),
    matching: find.byType(CustomPaint),
  );
}

void main() {
  group('PulseHighlight', () {
    testWidgets('renders its child and autoplays without settling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const PulseHighlight(child: Text('New'))),
      );
      expect(find.text('New'), findsOneWidget);
      expect(_ringLayer(), findsOneWidget);

      // The pulse repeats: pump explicit durations, never pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller starts and stops the pulses',
        (WidgetTester tester) async {
      final PulseHighlightController controller = PulseHighlightController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          PulseHighlight(
            autoPlay: false,
            stopOnTap: false,
            controller: controller,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(controller.isPulsing, isFalse);
      expect(_ringLayer(), findsNothing);

      controller.start();
      await tester.pump();
      expect(controller.isPulsing, isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      expect(_ringLayer(), findsOneWidget);

      controller.stop();
      await tester.pump();
      expect(controller.isPulsing, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      expect(_ringLayer(), findsNothing);
    });

    testWidgets('stops after maxPulseCount and reports each cycle',
        (WidgetTester tester) async {
      int cycles = 0;
      await tester.pumpWidget(
        _wrap(
          PulseHighlight(
            duration: const Duration(milliseconds: 200),
            maxPulseCount: 2,
            onPulseComplete: () => cycles++,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(cycles, 1);
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      expect(cycles, 2);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_ringLayer(), findsNothing);
    });

    testWidgets('stopOnTap stops the pulses and syncs the controller',
        (WidgetTester tester) async {
      final PulseHighlightController controller = PulseHighlightController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          PulseHighlight(
            controller: controller,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      expect(controller.isPulsing, isTrue);

      await tester.tap(find.byType(PulseHighlight));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(controller.isPulsing, isFalse);
      expect(_ringLayer(), findsNothing);
    });

    testWidgets('tap still reaches the child', (WidgetTester tester) async {
      bool childTapped = false;
      await tester.pumpWidget(
        _wrap(
          PulseHighlight(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => childTapped = true,
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PulseHighlight));
      await tester.pump();
      expect(childTapped, isTrue);
    });

    testWidgets('enabled false renders the child only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const PulseHighlight(
            enabled: false,
            child: SizedBox(width: 48, height: 48),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_ringLayer(), findsNothing);
    });

    testWidgets('reduced motion never pulses', (WidgetTester tester) async {
      final PulseHighlightController controller = PulseHighlightController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: PulseHighlight(
                  controller: controller,
                  child: const SizedBox(width: 48, height: 48),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_ringLayer(), findsNothing);

      controller.start();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_ringLayer(), findsNothing);
    });

    testWidgets('disposal mid-pulse does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const PulseHighlight(child: SizedBox(width: 48, height: 48))),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
