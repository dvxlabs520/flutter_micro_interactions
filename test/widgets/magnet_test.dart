import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/magnet.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 100 x 50 magnet centered on the 800 x 600 test screen, so its
/// resting center is (400, 300) and its attraction area spans
/// x 290..510 and y 185..415 with the default 60 pixel padding.
Widget _magnet({
  double strength = 0.3,
  double padding = 60,
  bool enabled = true,
  Duration activeDuration = const Duration(milliseconds: 300),
  Duration inactiveDuration = const Duration(milliseconds: 600),
  Curve inactiveCurve = Curves.elasticOut,
  VoidCallback? onPressed,
}) {
  return Magnet(
    strength: strength,
    padding: padding,
    enabled: enabled,
    activeDuration: activeDuration,
    inactiveDuration: inactiveDuration,
    inactiveCurve: inactiveCurve,
    child: SizedBox(
      width: 100,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        child: const Text('Magnet'),
      ),
    ),
  );
}

Offset _offset(WidgetTester tester) {
  final Transform transform = tester.widget<Transform>(
    find
        .descendant(of: find.byType(Magnet), matching: find.byType(Transform))
        .first,
  );
  return Offset(
    transform.transform.storage[12],
    transform.transform.storage[13],
  );
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
  group('Magnet', () {
    testWidgets('renders its child at rest', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_magnet()));
      expect(find.text('Magnet'), findsOneWidget);
      expect(_offset(tester), Offset.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('child taps still fire', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_magnet(onPressed: () => taps++)));
      await tester.tap(find.text('Magnet'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('mouse within padding pulls the child toward it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture mouse = await _mouse(tester);

      // Outside the attraction area: nothing happens.
      await mouse.moveTo(const Offset(600, 300));
      await tester.pump();
      expect(_offset(tester), Offset.zero);

      // 70 pixels right of center, inside the padding area.
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final Offset mid = _offset(tester);
      expect(mid.dx, greaterThan(0));
      expect(mid.dx, lessThan(21));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_offset(tester).dx, closeTo(21, 0.01));
      expect(_offset(tester).dy, closeTo(0, 0.01));
    });

    testWidgets('leaving springs back to rest with an animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 250));
      await tester.pumpAndSettle();
      expect(_offset(tester).dy, closeTo(-15, 0.01));

      await mouse.moveTo(const Offset(700, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_offset(tester), isNot(Offset.zero));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(_offset(tester).dx, closeTo(0, 0.001));
      expect(_offset(tester).dy, closeTo(0, 0.001));
    });

    testWidgets('touch drag follows the finger and releases on lift', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet(strength: 0.5)));
      final TestGesture finger = await tester.startGesture(
        const Offset(420, 300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester).dx, closeTo(10, 0.01));

      await finger.moveTo(const Offset(440, 320));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester).dx, closeTo(20, 0.01));
      expect(_offset(tester).dy, closeTo(10, 0.01));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_offset(tester).dx, closeTo(0, 0.001));
    });

    testWidgets('touch drag leaving the area releases the child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture finger = await tester.startGesture(
        const Offset(450, 300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester).dx, greaterThan(0));

      await finger.moveTo(const Offset(750, 300));
      await tester.pumpAndSettle();
      expect(_offset(tester).dx, closeTo(0, 0.001));
      await finger.up();
    });

    testWidgets('reduced motion never moves and schedules no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet(), reducedMotion: true));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump();
      expect(_offset(tester), Offset.zero);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false never moves', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_magnet(enabled: false)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester), Offset.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disabling while pulled snaps back to rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_offset(tester), isNot(Offset.zero));

      await tester.pumpWidget(_wrap(_magnet(enabled: false)));
      expect(_offset(tester), Offset.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        _wrap(
          _magnet(
            strength: 0.8,
            padding: 20,
            activeDuration: const Duration(milliseconds: 100),
            inactiveDuration: const Duration(milliseconds: 200),
            inactiveCurve: Curves.easeOut,
          ),
        ),
      );
      // Now outside the smaller padding area: returns to rest.
      await mouse.moveTo(const Offset(475, 300));
      await tester.pumpAndSettle();
      expect(_offset(tester).dx, closeTo(0, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose mid-animation does not throw and stops listening', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_magnet()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(470, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await mouse.moveTo(const Offset(430, 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
