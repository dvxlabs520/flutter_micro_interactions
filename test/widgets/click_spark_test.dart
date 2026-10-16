import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/click_spark.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 200 x 120 area centered on the 800 x 600 test screen, spanning
/// x 300..500 and y 240..360.
Widget _spark({
  bool enabled = true,
  Duration duration = const Duration(milliseconds: 400),
  ClickSparkShape shape = ClickSparkShape.lines,
  Color? sparkColor,
  int sparkCount = 8,
  double extraScale = 1.0,
  VoidCallback? onPressed,
}) {
  return ClickSpark(
    enabled: enabled,
    duration: duration,
    shape: shape,
    sparkColor: sparkColor,
    sparkCount: sparkCount,
    extraScale: extraScale,
    child: SizedBox(
      width: 200,
      height: 120,
      child: Center(
        // A plain GestureDetector keeps the child free of its own
        // animations, so frame and ticker checks only see the effect.
        child: GestureDetector(onTap: onPressed, child: const Text('Spark')),
      ),
    ),
  );
}

dynamic _painter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(ClickSpark),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_SparkPainter',
          ),
        ),
      )
      .painter;
}

int _burstCount(WidgetTester tester) =>
    (_painter(tester).field.bursts as List<dynamic>).length;

Offset _firstOrigin(WidgetTester tester) =>
    (_painter(tester).field.bursts as List<dynamic>).first.origin as Offset;

void main() {
  group('ClickSpark', () {
    testWidgets('renders its child with no sparks at rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      expect(find.text('Spark'), findsOneWidget);
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tap sparks at the tap point and the child still fires', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_spark(onPressed: () => taps++)));
      await tester.tapAt(const Offset(400, 300));
      expect(taps, 1);
      expect(_burstCount(tester), 1);
      expect(_firstOrigin(tester), const Offset(100, 60));

      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_burstCount(tester), 1);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('an ElevatedButton inside still receives taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          ClickSpark(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Button'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Button'));
      expect(taps, 1);
      expect(_burstCount(tester), 1);
      await tester.pumpAndSettle();
      expect(_burstCount(tester), 0);
    });

    testWidgets('taps on empty areas of the child also spark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      await tester.tapAt(const Offset(310, 250));
      expect(_burstCount(tester), 1);
      expect(_firstOrigin(tester), const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_burstCount(tester), 0);
    });

    testWidgets('overlapping bursts are tracked and cleaned up', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      await tester.tapAt(const Offset(320, 260));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(480, 340));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(400, 300));
      expect(_burstCount(tester), 3);

      // The first burst ends 400ms after it started.
      await tester.pump(const Duration(milliseconds: 210));
      expect(_burstCount(tester), 2);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_burstCount(tester), 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('drags do not spark', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_spark()));
      final TestGesture finger = await tester.startGesture(
        const Offset(320, 260),
      );
      await finger.moveBy(const Offset(60, 0));
      await finger.up();
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('dots shape paints and finishes', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(_spark(shape: ClickSparkShape.dots, extraScale: 2)),
      );
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_burstCount(tester), 0);
    });

    testWidgets('reduced motion shows no sparks and schedules no frames', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(_spark(onPressed: () => taps++), reducedMotion: true),
      );
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(taps, 1);
      expect(_burstCount(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false shows no sparks', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(_spark(enabled: false, onPressed: () => taps++)),
      );
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(taps, 1);
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disabling mid-burst clears the sparks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_burstCount(tester), 1);

      await tester.pumpWidget(_wrap(_spark(enabled: false)));
      expect(_burstCount(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('config changes mid-burst are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        _wrap(
          _spark(
            duration: const Duration(milliseconds: 150),
            shape: ClickSparkShape.dots,
            sparkColor: Colors.red,
            sparkCount: 3,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(_burstCount(tester), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('dispose mid-burst does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_spark()));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
