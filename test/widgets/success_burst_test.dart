import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/success_burst.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

Finder _particleLayer() {
  return find.descendant(
    of: find.byType(SuccessBurst),
    matching: find.byType(CustomPaint),
  );
}

void main() {
  group('SuccessBurst', () {
    testWidgets('renders its child with no particle layer at rest',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const SuccessBurst(child: Text('Done'))),
      );
      expect(find.text('Done'), findsOneWidget);
      expect(_particleLayer(), findsNothing);
    });

    testWidgets('controller.burst paints particles and completes',
        (WidgetTester tester) async {
      final SuccessBurstController controller = SuccessBurstController();
      addTearDown(controller.dispose);
      int completed = 0;

      await tester.pumpWidget(
        _wrap(
          SuccessBurst(
            controller: controller,
            duration: const Duration(milliseconds: 300),
            seed: 42,
            onCompleted: () => completed++,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );

      controller.burst();
      await tester.pump();
      expect(_particleLayer(), findsOneWidget);
      expect(completed, 0);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(_particleLayer(), findsNothing);
      expect(completed, 1);
    });

    testWidgets('concurrent bursts each complete and fire onCompleted',
        (WidgetTester tester) async {
      final SuccessBurstController controller = SuccessBurstController();
      addTearDown(controller.dispose);
      int completed = 0;

      await tester.pumpWidget(
        _wrap(
          SuccessBurst(
            controller: controller,
            duration: const Duration(milliseconds: 300),
            seed: 1,
            onCompleted: () => completed++,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );

      controller.burst();
      await tester.pump(const Duration(milliseconds: 100));
      controller.burst();
      await tester.pump();
      expect(_particleLayer(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(_particleLayer(), findsNothing);
      expect(completed, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('burstOnTap triggers a burst on tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const SuccessBurst(
            burstOnTap: true,
            duration: Duration(milliseconds: 300),
            seed: 7,
            child: SizedBox(width: 48, height: 48),
          ),
        ),
      );

      await tester.tap(find.byType(SuccessBurst));
      await tester.pump();
      expect(_particleLayer(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(_particleLayer(), findsNothing);
    });

    testWidgets('enabled false ignores controller and taps',
        (WidgetTester tester) async {
      final SuccessBurstController controller = SuccessBurstController();
      addTearDown(controller.dispose);
      int completed = 0;

      await tester.pumpWidget(
        _wrap(
          SuccessBurst(
            controller: controller,
            enabled: false,
            burstOnTap: true,
            onCompleted: () => completed++,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );

      controller.burst();
      await tester.tap(find.byType(SuccessBurst), warnIfMissed: false);
      await tester.pump();
      expect(_particleLayer(), findsNothing);
      expect(completed, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: no particles but onCompleted still fires',
        (WidgetTester tester) async {
      final SuccessBurstController controller = SuccessBurstController();
      addTearDown(controller.dispose);
      int completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SuccessBurst(
                  controller: controller,
                  onCompleted: () => completed++,
                  child: const SizedBox(width: 48, height: 48),
                ),
              ),
            ),
          ),
        ),
      );

      controller.burst();
      await tester.pump();
      expect(_particleLayer(), findsNothing);
      await tester.pump(Duration.zero);
      expect(completed, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal mid-burst does not throw',
        (WidgetTester tester) async {
      final SuccessBurstController controller = SuccessBurstController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SuccessBurst(
            controller: controller,
            seed: 3,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      controller.burst();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping controllers rewires burst triggering',
        (WidgetTester tester) async {
      final SuccessBurstController first = SuccessBurstController();
      final SuccessBurstController second = SuccessBurstController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget build(SuccessBurstController controller) {
        return _wrap(
          SuccessBurst(
            controller: controller,
            duration: const Duration(milliseconds: 200),
            seed: 5,
            child: const SizedBox(width: 48, height: 48),
          ),
        );
      }

      await tester.pumpWidget(build(first));
      await tester.pumpWidget(build(second));

      first.burst();
      await tester.pump();
      expect(_particleLayer(), findsNothing);

      second.burst();
      await tester.pump();
      expect(_particleLayer(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(_particleLayer(), findsNothing);
    });
  });
}
