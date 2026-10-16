import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/tilt_card.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 200 x 120 card centered on the 800 x 600 test screen, spanning
/// x 300..500 and y 240..360.
Widget _card({
  bool enabled = true,
  bool glare = true,
  double maxTilt = 12,
  double scaleOnHover = 1.03,
  Duration resetDuration = const Duration(milliseconds: 400),
  Curve resetCurve = Curves.easeOutBack,
  VoidCallback? onPressed,
}) {
  return TiltCard(
    enabled: enabled,
    glare: glare,
    maxTilt: maxTilt,
    scaleOnHover: scaleOnHover,
    resetDuration: resetDuration,
    resetCurve: resetCurve,
    child: SizedBox(
      width: 200,
      height: 120,
      child: Center(
        child: ElevatedButton(
          onPressed: onPressed ?? () {},
          child: const Text('Tilt'),
        ),
      ),
    ),
  );
}

Matrix4 _matrix(WidgetTester tester) {
  return tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(TiltCard),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
}

Finder get _glare => find.descendant(
  of: find.byType(TiltCard),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_GlarePainter',
  ),
);

double _glareIntensity(WidgetTester tester) {
  final dynamic painter = tester.widget<CustomPaint>(_glare).painter;
  return (painter.intensity as Animation<double>).value;
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
  group('TiltCard', () {
    testWidgets('renders its child flat at rest', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_card()));
      expect(find.text('Tilt'), findsOneWidget);
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('child taps still fire', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_card(onPressed: () => taps++)));
      await tester.tap(find.text('Tilt'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('hover tilts the side under the pointer away', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      // Pointer near the right edge, vertically centered.
      await mouse.moveTo(const Offset(490, 300));
      await tester.pumpAndSettle();

      final Matrix4 m = _matrix(tester);
      expect(m, isNot(Matrix4.identity()));
      final Offset right = MatrixUtils.transformPoint(m, const Offset(100, 0));
      final Offset left = MatrixUtils.transformPoint(m, const Offset(-100, 0));
      // The right side is pushed back, so it projects smaller.
      expect(right.dx.abs(), lessThan(left.dx.abs()));
      expect(_glareIntensity(tester), 1.0);
    });

    testWidgets('moving the pointer updates the tilt', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(310, 300));
      await tester.pumpAndSettle();
      final Matrix4 first = _matrix(tester);

      await mouse.moveTo(const Offset(400, 250));
      await tester.pump();
      final Matrix4 second = _matrix(tester);
      expect(second, isNot(first));
      final Offset top = MatrixUtils.transformPoint(
        second,
        const Offset(0, -60),
      );
      final Offset bottom = MatrixUtils.transformPoint(
        second,
        const Offset(0, 60),
      );
      expect(top.dy.abs(), lessThan(bottom.dy.abs()));
    });

    testWidgets('leaving springs back to flat with an animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pumpAndSettle();

      await mouse.moveTo(const Offset(700, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_matrix(tester), isNot(Matrix4.identity()));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(_matrix(tester), Matrix4.identity());
      expect(_glareIntensity(tester), 0.0);
    });

    testWidgets('touch drag tilts and releases on lift', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture finger = await tester.startGesture(
        const Offset(320, 300),
      );
      await tester.pumpAndSettle();
      final Matrix4 pressed = _matrix(tester);
      expect(pressed, isNot(Matrix4.identity()));

      await finger.moveTo(const Offset(480, 300));
      await tester.pump();
      expect(_matrix(tester), isNot(pressed));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_matrix(tester), Matrix4.identity());
    });

    testWidgets('reduced motion stays flat without glare or frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(), reducedMotion: true));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pump();
      expect(_matrix(tester), Matrix4.identity());
      expect(_glare, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false stays flat', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_card(enabled: false)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_matrix(tester), Matrix4.identity());
      expect(_glare, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('glare false paints no glare', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_card(glare: false)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pumpAndSettle();
      expect(_matrix(tester), isNot(Matrix4.identity()));
      expect(_glare, findsNothing);
    });

    testWidgets('disabling keeps the child state', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      Widget build(bool enabled) => _wrap(
        TiltCard(
          enabled: enabled,
          child: SizedBox(key: key, width: 100, height: 100),
        ),
      );
      await tester.pumpWidget(build(true));
      final Element before = key.currentContext! as Element;
      await tester.pumpWidget(build(false));
      expect(key.currentContext, same(before));
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        _wrap(
          _card(
            maxTilt: 30,
            scaleOnHover: 1.1,
            glare: false,
            resetDuration: const Duration(milliseconds: 100),
            resetCurve: Curves.easeIn,
          ),
        ),
      );
      await mouse.moveTo(const Offset(700, 50));
      await tester.pumpAndSettle();
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(480, 260));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
