import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

/// The render object that paints the waves of the only [WaterRipple].
RenderObject _wavePainter(WidgetTester tester) {
  return tester.renderObject(
    find.descendant(
      of: find.byType(WaterRipple),
      matching: find.byType(CustomPaint),
    ),
  );
}

/// The colored surface of the only [RippleButton].
Finder _buttonSurface() {
  return find.descendant(
    of: find.byType(RippleButton),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          (widget.decoration as BoxDecoration).color == Colors.green,
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('RippleEffect', () {
    testWidgets('renders its child and fires onTap', (
      WidgetTester tester,
    ) async {
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

    testWidgets('paints a ripple on tap and removes it when finished', (
      WidgetTester tester,
    ) async {
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

    testWidgets('enabled false renders child and does not fire onTap', (
      WidgetTester tester,
    ) async {
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

    testWidgets('reduced motion: no ripples but onTap still fires', (
      WidgetTester tester,
    ) async {
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

    testWidgets('lays the child out as if it were not wrapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 80,
            child: RippleEffect(
              child: Container(key: const Key('fill'), color: Colors.green),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('fill'))),
        const Size(300, 80),
      );
    });

    testWidgets('disposal mid-ripple does not throw', (
      WidgetTester tester,
    ) async {
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

    testWidgets('fills the width it is given', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            child: RippleButton(
              onTap: () {},
              backgroundColor: Colors.green,
              child: const Text('Wide'),
            ),
          ),
        ),
      );
      expect(tester.getSize(_buttonSurface()).width, 300);
      expect(tester.getSize(find.byType(RippleButton)).width, 300);
      // The label is centered on the stretched surface.
      expect(
        tester.getCenter(find.text('Wide')).dx,
        closeTo(tester.getCenter(_buttonSurface()).dx, 0.5),
      );
    });

    testWidgets('stretches inside a stretch Column', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  RippleButton(
                    onTap: () {},
                    backgroundColor: Colors.green,
                    child: const Text('Stretch'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(_buttonSurface()).width, 320);
    });

    testWidgets('keeps its intrinsic width under loose constraints', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RippleButton(
            onTap: () {},
            backgroundColor: Colors.green,
            child: const SizedBox(width: 50, height: 10),
          ),
        ),
      );
      // 50 plus the default 16 pixel padding on both sides.
      expect(tester.getSize(_buttonSurface()), const Size(82, 42));
    });
  });

  group('WaterRipple', () {
    testWidgets('renders child and loops without settling', (
      WidgetTester tester,
    ) async {
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

    testWidgets('controller starts and stops the waves', (
      WidgetTester tester,
    ) async {
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

    testWidgets('paints no waves while not playing', (
      WidgetTester tester,
    ) async {
      final WaterRippleController controller = WaterRippleController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          WaterRipple(
            autoPlay: false,
            controller: controller,
            child: const SizedBox.square(dimension: 100),
          ),
        ),
      );
      // Never started: only the child.
      expect(_wavePainter(tester), paintsNothing);

      controller.start();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_wavePainter(tester), paints..circle());

      // Stopped mid-wave: the rings disappear instead of freezing.
      controller.stop();
      await tester.pump();
      expect(_wavePainter(tester), paintsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('autoPlay false without a controller paints no waves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const WaterRipple(
            autoPlay: false,
            child: SizedBox.square(dimension: 100),
          ),
        ),
      );
      expect(_wavePainter(tester), paintsNothing);
    });

    testWidgets('reduced motion while playing shows static rings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: WaterRipple(
                  child: const SizedBox.square(dimension: 100),
                ),
              ),
            ),
          ),
        ),
      );
      expect(_wavePainter(tester), paints..circle());
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  // Issue #2: ripples must show on every press, not only when the tap wins.
  group('RippleEffect reliability', () {
    bool hasRipple(WidgetTester tester) => find
        .descendant(
          of: find.byType(RippleEffect),
          matching: find.byType(IgnorePointer),
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('ripple starts at once over an interactive child', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RippleEffect(
                child: ElevatedButton(
                  onPressed: () => pressed++,
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Go')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(hasRipple(tester), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('scrolling a list removes the press ripple', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                RippleEffect(
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
      await tester.pump(const Duration(milliseconds: 20));
      expect(hasRipple(tester), isTrue);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(hasRipple(tester), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });
}
