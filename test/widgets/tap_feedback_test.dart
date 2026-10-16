import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TapFeedback', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TapFeedback(child: Text('Tap me'))));
      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('fires onTap immediately on tap-up', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            onTap: () => tapped = true,
            child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
          ),
        ),
      );

      await tester.tap(find.text('Tap'));
      // The callback fires on tap-up without waiting for any animation pump.
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });

    for (final TapAnimationType effect in TapAnimationType.values) {
      testWidgets('effect $effect animates a press and release', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            TapFeedback(
              effect: effect,
              onTap: () {},
              child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
            ),
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.text('Tap')),
        );
        await tester.pump(const Duration(milliseconds: 80));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('Tap'), findsOneWidget);
      });
    }

    testWidgets('static constructors build', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: <Widget>[
              TapFeedback.scale(child: const Text('scale')),
              TapFeedback.bounce(child: const Text('bounce')),
              TapFeedback.fade(child: const Text('fade')),
              TapFeedback.scaleAndOpacity(child: const Text('both')),
            ],
          ),
        ),
      );
      expect(find.text('scale'), findsOneWidget);
      expect(find.text('bounce'), findsOneWidget);
      expect(find.text('fade'), findsOneWidget);
      expect(find.text('both'), findsOneWidget);
    });

    testWidgets('enabled false renders child and never fires onTap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            enabled: false,
            onTap: () => tapped = true,
            child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
          ),
        ),
      );
      await tester.tap(find.text('Tap'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('exposes button semantics with label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            semanticLabel: 'Do it',
            onTap: () {},
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Do it'), findsOneWidget);
    });

    testWidgets('reduced motion: tap fires callback with no animations', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: TapFeedback(
                  onTap: () => tapped = true,
                  child: const SizedBox(
                    width: 100,
                    height: 40,
                    child: Text('Tap'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap'));
      await tester.pump();
      expect(tapped, isTrue);
      // No press animation is scheduled under reduced motion.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            onTap: () {},
            child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
          ),
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // Replace the tree while the press animation is running.
      await tester.pumpWidget(Container());
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
