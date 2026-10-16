import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/glare_hover.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _glare({
  VoidCallback? onPressed,
  bool reverseOnExit = true,
  bool playOnce = false,
  bool enabled = true,
  Duration duration = const Duration(milliseconds: 400),
  Curve curve = Curves.easeOutCubic,
  double glareAngle = -45,
  GlareHoverController? controller,
  bool plainChild = false,
}) {
  return GlareHover(
    reverseOnExit: reverseOnExit,
    playOnce: playOnce,
    enabled: enabled,
    duration: duration,
    curve: curve,
    glareAngle: glareAngle,
    controller: controller,
    child: SizedBox(
      width: 200,
      height: 120,
      // A plain child has no hover or ink animations of its own.
      child: plainChild
          ? GestureDetector(onTap: onPressed, child: const Text('Card'))
          : TextButton(onPressed: onPressed, child: const Text('Card')),
    ),
  );
}

Finder get _painter => find.descendant(
  of: find.byType(GlareHover),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_GlareSweepPainter',
  ),
);

/// Curved sweep progress: 0 before the band enters, 1 after it left.
double _progress(WidgetTester tester) {
  final dynamic painter = tester.widget<CustomPaint>(_painter).painter;
  return (painter.progress as Animation<double>).value;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('GlareHover', () {
    testWidgets('renders its child with no glare at rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      expect(find.text('Card'), findsOneWidget);
      expect(_painter, findsOneWidget);
      expect(_progress(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('hover plays one sweep that finishes off the child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double early = _progress(tester);
      expect(early, greaterThan(0.0));
      expect(early, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(early));

      await tester.pumpAndSettle();
      expect(_progress(tester), 1.0);
      // Resting on the child does not loop.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('exit sweeps back the other way', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pumpAndSettle();

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double back = _progress(tester);
      expect(back, lessThan(1.0));
      expect(back, greaterThan(0.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), lessThan(back));
      await tester.pumpAndSettle();
      expect(_progress(tester), 0.0);
    });

    testWidgets('exit mid-sweep turns the band around', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = _progress(tester);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_progress(tester), lessThan(mid));
      await tester.pumpAndSettle();
      expect(_progress(tester), 0.0);
    });

    testWidgets('reverseOnExit false hides the glare without a sweep back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare(reverseOnExit: false)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_progress(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);

      // Leaving mid-sweep lets the sweep finish, then rests off the child.
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = _progress(tester);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_progress(tester), greaterThan(mid));
      await tester.pumpAndSettle();
      expect(_progress(tester), 0.0);
    });

    testWidgets('every hover plays by default', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      for (int i = 0; i < 2; i++) {
        await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_progress(tester), greaterThan(0.0));
        await tester.pumpAndSettle();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('playOnce plays only on the first hover', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare(playOnce: true)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pumpAndSettle();
      expect(_progress(tester), 1.0);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(_progress(tester), 0.0);

      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_progress(tester), 0.0);
    });

    testWidgets('a touch press plays one sweep and child taps pass through', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_glare(onPressed: () => taps++)));
      await tester.tap(find.text('Card'));
      expect(taps, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(0.0));
      expect(_progress(tester), lessThan(1.0));
      await tester.pumpAndSettle();
      // The band left the child and the glare rests at its start again.
      expect(_progress(tester), 0.0);
    });

    testWidgets('mouse clicks reach the child', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_glare(onPressed: () => taps++)));
      await tester.tap(find.text('Card'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('keyboard focus inside the child plays the sweep', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare(onPressed: () {})));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_progress(tester), 1.0);

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(_progress(tester), 0.0);
    });

    testWidgets('controller play runs one sweep', (WidgetTester tester) async {
      final GlareHoverController controller = GlareHoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_glare(controller: controller)));
      expect(controller.isSweeping, isFalse);

      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isSweeping, isTrue);
      expect(_progress(tester), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(controller.isSweeping, isFalse);
      expect(_progress(tester), 0.0);

      // Programmatic sweeps ignore playOnce and can repeat.
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(0.0));
      await tester.pumpAndSettle();
    });

    testWidgets('swapping controllers listens to the new one only', (
      WidgetTester tester,
    ) async {
      final GlareHoverController first = GlareHoverController();
      final GlareHoverController second = GlareHoverController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(_wrap(_glare(controller: first)));
      await tester.pumpWidget(_wrap(_glare(controller: second)));
      first.play();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      second.play();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion paints no glare and schedules no frames', (
      WidgetTester tester,
    ) async {
      final GlareHoverController controller = GlareHoverController();
      addTearDown(controller.dispose);
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          _glare(
            controller: controller,
            onPressed: () => taps++,
            plainChild: true,
          ),
          reduceMotion: true,
        ),
      );
      expect(_painter, findsNothing);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      controller.play();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(controller.isSweeping, isFalse);

      await tester.tap(find.text('Card'));
      expect(taps, 1);
    });

    testWidgets('enabled false paints no glare but keeps the child working', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          _glare(enabled: false, onPressed: () => taps++, plainChild: true),
        ),
      );
      expect(_painter, findsNothing);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text('Card'));
      expect(taps, 1);
    });

    testWidgets('disabling mid-sweep stops the glare', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(_glare(enabled: false)));
      expect(_painter, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      // Re-enabling starts from rest.
      await tester.pumpWidget(_wrap(_glare()));
      expect(_progress(tester), 0.0);
    });

    testWidgets('config changes mid-sweep do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final GlareHoverController controller = GlareHoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _glare(
            duration: const Duration(milliseconds: 900),
            curve: Curves.linear,
            glareAngle: 90,
            controller: controller,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_progress(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-sweep does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glare()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the child semantics and adds none', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_glare(onPressed: () {})));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlareHover)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getSemantics(find.text('Card')),
        matchesSemantics(
          label: 'Card',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.pumpAndSettle();
      handle.dispose();
    });

    test('rejects invalid parameters', () {
      expect(
        () => GlareHover(glareOpacity: 1.5, child: const SizedBox()),
        throwsAssertionError,
      );
      expect(
        () => GlareHover(glareSize: 0, child: const SizedBox()),
        throwsAssertionError,
      );
    });
  });
}
