import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/animated_gradient_border.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

double _painterProgress(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(AnimatedGradientBorder),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  final Animation<double> progress =
      (paint.painter as dynamic).progress as Animation<double>;
  return progress.value;
}

void main() {
  group('AnimatedGradientBorder', () {
    testWidgets('renders its child inside the border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedGradientBorder(child: Text('Featured'))),
      );
      expect(find.text('Featured'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnimatedGradientBorder),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('autoPlay animates the painter progress', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedGradientBorder(
            duration: Duration(milliseconds: 1000),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      final double p0 = _painterProgress(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double p1 = _painterProgress(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double p2 = _painterProgress(tester);

      expect(tester.hasRunningAnimations, isTrue);
      expect(p1, isNot(equals(p0)));
      expect(p2, isNot(equals(p1)));

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller start and stop control the sweep', (
      WidgetTester tester,
    ) async {
      final AnimatedGradientBorderController controller =
          AnimatedGradientBorderController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBorder(
            autoPlay: false,
            controller: controller,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(controller.isPlaying, isFalse);

      controller.start();
      await tester.pump();
      expect(controller.isPlaying, isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 400));

      controller.stop();
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('controller stop pauses the sweep in place and start resumes', (
      WidgetTester tester,
    ) async {
      final AnimatedGradientBorderController controller =
          AnimatedGradientBorderController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBorder(
            autoPlay: false,
            controller: controller,
            duration: const Duration(milliseconds: 1000),
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final double paused = _painterProgress(tester);
      expect(paused, closeTo(0.4, 0.001));

      controller.stop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // No snap back to angle 0: the sweep holds its current angle.
      expect(_painterProgress(tester), paused);
      expect(tester.hasRunningAnimations, isFalse);

      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painterProgress(tester), closeTo(0.5, 0.001));

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false shows the rest frame even after a pause', (
      WidgetTester tester,
    ) async {
      Widget build({required bool enabled}) {
        return _wrap(
          AnimatedGradientBorder(
            enabled: enabled,
            duration: const Duration(milliseconds: 1000),
            child: const SizedBox(width: 80, height: 40),
          ),
        );
      }

      await tester.pumpWidget(build(enabled: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painterProgress(tester), greaterThan(0.0));

      await tester.pumpWidget(build(enabled: false));
      expect(_painterProgress(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false never animates', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedGradientBorder(
            enabled: false,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(AnimatedGradientBorder), findsOneWidget);
    });

    testWidgets('reduced motion renders a static border without tickers', (
      WidgetTester tester,
    ) async {
      final AnimatedGradientBorderController controller =
          AnimatedGradientBorderController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBorder(
            controller: controller,
            child: const Text('Still'),
          ),
          reducedMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painterProgress(tester), 0.0);
      expect(find.text('Still'), findsOneWidget);

      // Even an explicit start request stays static.
      controller.start();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_painterProgress(tester), 0.0);
    });

    testWidgets('parameter changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedGradientBorder(
            duration: Duration(milliseconds: 800),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(
        _wrap(
          const AnimatedGradientBorder(
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            colors: <Color>[Colors.red, Colors.orange],
            borderWidth: 4,
            glowRadius: 6,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping controllers detaches the old one cleanly', (
      WidgetTester tester,
    ) async {
      final AnimatedGradientBorderController a =
          AnimatedGradientBorderController();
      final AnimatedGradientBorderController b =
          AnimatedGradientBorderController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBorder(
            autoPlay: false,
            controller: a,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      a.start();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBorder(
            autoPlay: false,
            controller: b,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      // The old controller no longer drives the widget.
      a.stop();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      b.stop();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedGradientBorder(child: SizedBox(width: 80, height: 40)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
