import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/spotlight_card.dart';
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
  Duration duration = const Duration(milliseconds: 250),
  double radius = 200,
  Color? spotlightColor,
  double borderWidth = 1,
  VoidCallback? onPressed,
}) {
  return SizedBox(
    width: 200,
    height: 120,
    child: SpotlightCard(
      enabled: enabled,
      duration: duration,
      radius: radius,
      spotlightColor: spotlightColor,
      borderWidth: borderWidth,
      padding: const EdgeInsets.all(8),
      child: Center(
        // A plain GestureDetector keeps the child free of its own
        // animations, so frame and ticker checks only see the effect.
        child: GestureDetector(onTap: onPressed, child: const Text('Inside')),
      ),
    ),
  );
}

dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SpotlightCard),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SpotlightPainter',
      ),
    ),
  );
  return paint.painter;
}

double _fade(WidgetTester tester) =>
    (_painter(tester).fade as Animation<double>).value;

Offset? _position(WidgetTester tester) =>
    (_painter(tester).position as ValueNotifier<Offset?>).value;

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('SpotlightCard', () {
    testWidgets('renders its child without a spotlight at rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      expect(find.text('Inside'), findsOneWidget);
      expect(_fade(tester), 0.0);
      expect(_position(tester), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('child taps still fire', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_card(onPressed: () => taps++)));
      await tester.tap(find.text('Inside'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('an ElevatedButton inside still receives taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          SpotlightCard(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Button'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Button'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('hover fades the spotlight in and follows the pointer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);

      await mouse.moveTo(const Offset(320, 260));
      await tester.pump();
      expect(_position(tester), const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = _fade(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await mouse.moveTo(const Offset(480, 340));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_position(tester), const Offset(180, 100));
      expect(_fade(tester), 1.0);
    });

    testWidgets('leaving fades the spotlight out with an animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(_fade(tester), 1.0);

      await mouse.moveTo(const Offset(700, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fade(tester), greaterThan(0));
      expect(_fade(tester), lessThan(1));
      // The spotlight fades out in place.
      expect(_position(tester), const Offset(100, 60));

      await tester.pumpAndSettle();
      expect(_fade(tester), 0.0);
    });

    testWidgets('touch shows the spotlight while pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture finger = await tester.startGesture(
        const Offset(310, 250),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fade(tester), 1.0);
      expect(_position(tester), const Offset(10, 10));

      await finger.moveTo(const Offset(350, 300));
      await tester.pump();
      expect(_position(tester), const Offset(50, 60));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_fade(tester), 0.0);
    });

    testWidgets('reduced motion follows instantly without fading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(), reducedMotion: true));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump();
      expect(_fade(tester), 1.0);
      expect(_position(tester), const Offset(100, 60));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await mouse.moveTo(const Offset(700, 50));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false shows no spotlight', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(enabled: false)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fade(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Inside'), findsOneWidget);
    });

    testWidgets('disabling while lit hides the spotlight', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(_fade(tester), 1.0);

      await tester.pumpWidget(_wrap(_card(enabled: false)));
      expect(_fade(tester), 0.0);
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        _wrap(
          _card(
            duration: const Duration(milliseconds: 50),
            radius: 80,
            spotlightColor: Colors.red,
            borderWidth: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_fade(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
