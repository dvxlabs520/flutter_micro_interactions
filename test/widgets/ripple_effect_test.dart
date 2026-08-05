import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('RippleEffect', () {
    testWidgets('renders its child and fires onTap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          RippleEffect(
            onTap: () => tapped = true,
            child: const SizedBox(width: 200, height: 80, child: Text('Tap')),
          ),
        ),
      );
      expect(find.text('Tap'), findsOneWidget);

      await tester.tap(find.text('Tap'));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('paints a ripple on tap and removes it when finished',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          RippleEffect(
            duration: Duration(milliseconds: 200),
            child: SizedBox(width: 200, height: 80),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(RippleEffect),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      await tester.tap(find.byType(RippleEffect));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(RippleEffect),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(RippleEffect),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('enabled false renders child and does not fire onTap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          RippleEffect(
            enabled: false,
            onTap: () => tapped = true,
            child: const SizedBox(width: 200, height: 80),
          ),
        ),
      );
      await tester.tap(find.byType(RippleEffect), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('reduced motion: no ripples but onTap still fires',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: RippleEffect(
                  onTap: () => tapped = true,
                  child: const SizedBox(width: 200, height: 80),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(RippleEffect));
      await tester.pump();
      expect(tapped, isTrue);
      expect(
        find.descendant(
          of: find.byType(RippleEffect),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('disposal mid-ripple does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(RippleEffect(child: SizedBox(width: 200, height: 80))),
      );
      await tester.tap(find.byType(RippleEffect));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('RippleButton', () {
    testWidgets('renders child and fires onTap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          RippleButton(
            onTap: () => tapped = true,
            semanticLabel: 'Submit',
            child: const Text('Submit'),
          ),
        ),
      );
      expect(find.text('Submit'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });
  });

  group('WaterRipple', () {
    testWidgets('renders child and loops without settling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(WaterRipple(child: Icon(Icons.mic, size: 48))),
      );
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // The wave animation repeats: pump explicit durations, never
      // pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller starts and stops the waves',
        (WidgetTester tester) async {
      final WaterRippleController controller = WaterRippleController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          WaterRipple(
            autoPlay: false,
            controller: controller,
            child: const Icon(Icons.mic),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(controller.isPlaying, isFalse);

      controller.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isPlaying, isTrue);
      expect(tester.hasRunningAnimations, isTrue);

      controller.stop();
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion renders static', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: WaterRipple(child: const Icon(Icons.mic))),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
