import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/liquid_progress.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _wrapReduced(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('LiquidProgress', () {
    testWidgets('renders at value 0, 0.5 and 1 without exceptions', (
      WidgetTester tester,
    ) async {
      for (final double value in <double>[0.0, 0.5, 1.0]) {
        await tester.pumpWidget(_wrap(LiquidProgress(value: value)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the rectangle shape without exceptions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LiquidProgress(
            value: 0.4,
            shape: LiquidProgressShape.rectangle,
            width: 200,
            height: 60,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final Size size = tester.getSize(find.byType(LiquidProgress));
      expect(size, const Size(200, 60));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a value change animates to the target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.0, animateWave: false)),
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.8, animateWave: false)),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid value changes retarget without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.0, animateWave: false)),
      );
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.9, animateWave: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.2, animateWave: false)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics reports the target percent, even mid-animation', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.0, animateWave: false)),
      );
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.8, animateWave: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getSemantics(find.byType(LiquidProgress)),
        matchesSemantics(label: 'Progress', value: '80 percent'),
      );
      await tester.pump(const Duration(milliseconds: 600));
      handle.dispose();
    });

    testWidgets('semanticLabel overrides the default label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const LiquidProgress(
            value: 0.5,
            animateWave: false,
            semanticLabel: 'Upload progress',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(LiquidProgress)),
        matchesSemantics(label: 'Upload progress', value: '50 percent'),
      );
      handle.dispose();
    });

    testWidgets('animateWave false runs no repeating animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.5, animateWave: false)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animateWave true keeps the wave running until disposed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LiquidProgress(value: 0.5)));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders static and jumps on value change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapReduced(const LiquidProgress(value: 0.3)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_wrapReduced(const LiquidProgress(value: 0.9)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false applies value changes instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.1, enabled: false)),
      );
      await tester.pumpWidget(
        _wrap(const LiquidProgress(value: 0.7, enabled: false)),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showPercentage renders the two-layer contrast label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LiquidProgress(
            value: 0.5,
            showPercentage: true,
            animateWave: false,
          ),
        ),
      );
      // One copy over the background plus one clipped to the liquid.
      expect(find.text('50%'), findsNWidgets(2));
    });

    testWidgets('center overrides the percentage label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LiquidProgress(
            value: 0.5,
            showPercentage: true,
            animateWave: false,
            center: Text('custom'),
          ),
        ),
      );
      expect(find.text('custom'), findsOneWidget);
      expect(find.text('50%'), findsNothing);
    });

    testWidgets('disposal mid-animation is safe', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const LiquidProgress(value: 0.0)));
      await tester.pumpWidget(_wrap(const LiquidProgress(value: 1.0)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
