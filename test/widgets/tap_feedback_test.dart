import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Issue #2: "irregular behaviour when using gesture detector. The action
  // happens sometimes, but sometimes it doesn't".
  group('TapFeedback reliability', () {
    double scaleOf(WidgetTester tester) {
      final ScaleTransition t = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(TapFeedback),
          matching: find.byType(ScaleTransition),
        ),
      );
      return t.scale.value;
    }

    testWidgets('press feedback starts at once over an interactive child', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            child: ElevatedButton(
              onPressed: () => pressed++,
              child: const Text('Go'),
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Go')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(scaleOf(tester), lessThan(1.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(scaleOf(tester), 1.0);
    });

    testWidgets('quick presses inside a list show feedback and fire onTap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                TapFeedback(
                  onTap: () => taps++,
                  child: const SizedBox(height: 60, child: Text('Row')),
                ),
              ],
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Row')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // The list competes for the pointer, yet the feedback is immediate.
      expect(scaleOf(tester), lessThan(1.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);

      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('Row'));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(taps, 9);
    });

    testWidgets('scrolling cancels the press without onTap or haptics', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int haptics = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                TapFeedback(
                  onTap: () => taps++,
                  child: const SizedBox(height: 60, child: Text('Row')),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Row')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(scaleOf(tester), lessThan(1.0));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(haptics, 0);
      expect(scaleOf(tester), 1.0);

      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(haptics, 1);
    });

    testWidgets('warns once when a child takes the tap from onTap', (
      WidgetTester tester,
    ) async {
      final List<String> logs = <String>[];
      final DebugPrintCallback previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      int outer = 0;
      int inner = 0;
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            onTap: () => outer++,
            child: GestureDetector(
              onTap: () => inner++,
              child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
            ),
          ),
        ),
      );
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Tap'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      debugPrint = previous;
      expect(inner, 3);
      expect(outer, 0);
      expect(
        logs.where((String m) => m.startsWith('TapFeedback.onTap was not')),
        hasLength(1),
      );
    });

    testWidgets('does not warn when onTap fires', (WidgetTester tester) async {
      final List<String> logs = <String>[];
      final DebugPrintCallback previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      await tester.pumpWidget(
        _wrap(
          TapFeedback(
            onTap: () {},
            child: const SizedBox(width: 100, height: 40, child: Text('Tap')),
          ),
        ),
      );
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      debugPrint = previous;
      expect(logs, isEmpty);
    });
  });
}
