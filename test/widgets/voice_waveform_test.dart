import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/voice_waveform.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Current bar heights drawn by the painter.
List<double> _heights(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(VoiceWaveform),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_WaveformPainter',
      ),
    ),
  );
  final List<double> heights =
      ((paint.painter as dynamic).bars.heights as List<double>);
  return List<double>.of(heights);
}

double _sum(List<double> values) =>
    values.fold(0.0, (double a, double b) => a + b);

Future<void> _pumpFor(WidgetTester tester, int milliseconds) async {
  for (int t = 0; t < milliseconds; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('VoiceWaveform', () {
    testWidgets('renders bars with the default size and label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const VoiceWaveform()));
      // 5 bars of 3 plus 4 gaps of 3.
      expect(tester.getSize(find.byType(VoiceWaveform)), const Size(27, 24));
      expect(_heights(tester), hasLength(5));
      expect(find.bySemanticsLabel('Recording'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bars follow the level with taller center bars', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const VoiceWaveform(idleAnimation: false)));
      await _pumpFor(tester, 300);
      final List<double> quiet = _heights(tester);
      for (final double h in quiet) {
        expect(h, closeTo(4, 0.1));
      }

      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 1, idleAnimation: false)),
      );
      double centerTotal = 0;
      double edgeTotal = 0;
      for (int i = 0; i < 20; i++) {
        await _pumpFor(tester, 50);
        final List<double> loud = _heights(tester);
        centerTotal += loud[2];
        edgeTotal += loud[0];
        expect(_sum(loud), greaterThan(_sum(quiet) + 10));
        for (final double h in loud) {
          expect(h, lessThanOrEqualTo(24.0));
        }
      }
      expect(centerTotal, greaterThan(edgeTotal));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bars keep moving with a steady level', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const VoiceWaveform(level: 0.6)));
      await _pumpFor(tester, 300);
      final List<double> a = _heights(tester);
      await _pumpFor(tester, 120);
      final List<double> b = _heights(tester);
      expect(a, isNot(equals(b)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('silent bars ripple gently when idleAnimation is on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const VoiceWaveform()));
      final List<double> maxima = List<double>.filled(5, 0);
      for (int i = 0; i < 20; i++) {
        await _pumpFor(tester, 80);
        final List<double> heights = _heights(tester);
        for (int j = 0; j < 5; j++) {
          if (heights[j] > maxima[j]) maxima[j] = heights[j];
          // The ripple stays small: below 20 percent of the range.
          expect(heights[j], lessThan(4 + 20 * 0.2 + 0.01));
        }
      }
      expect(maxima.every((double h) => h > 5), isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('silent bars settle and stop ticking without idleAnimation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const VoiceWaveform(idleAnimation: false)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // A level change wakes the ticker up again.
      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 0.5, idleAnimation: false)),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('inactive bars collapse with animation and drop the label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const VoiceWaveform(level: 1)));
      await _pumpFor(tester, 400);
      final double loud = _sum(_heights(tester));

      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 1, active: false)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final double collapsing = _sum(_heights(tester));
      expect(collapsing, lessThan(loud));
      expect(collapsing, greaterThan(5 * 4 + 1));
      expect(find.bySemanticsLabel('Recording'), findsNothing);

      await _pumpFor(tester, 1500);
      for (final double h in _heights(tester)) {
        expect(h, 4.0);
      }
      expect(tester.hasRunningAnimations, isFalse);
      handle.dispose();
    });

    testWidgets('levelListenable updates without rebuilding the parent', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> level = ValueNotifier<double>(0);
      addTearDown(level.dispose);
      int builds = 0;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              builds++;
              return VoiceWaveform(
                levelListenable: level,
                idleAnimation: false,
              );
            },
          ),
        ),
      );
      await tester.pump();
      final double quiet = _sum(_heights(tester));
      expect(tester.hasRunningAnimations, isFalse);

      level.value = 0.9;
      await _pumpFor(tester, 300);
      expect(_sum(_heights(tester)), greaterThan(quiet + 10));
      expect(builds, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion shows the level directly with no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 0.5), reducedMotion: true),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Center bar: min + range * level.
      expect(_heights(tester)[2], closeTo(4 + 20 * 0.5, 1e-9));

      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 1), reducedMotion: true),
      );
      expect(_heights(tester)[2], closeTo(24, 1e-9));
      expect(_heights(tester)[0], lessThan(24));

      await tester.pumpWidget(
        _wrap(const VoiceWaveform(), reducedMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      for (final double h in _heights(tester)) {
        expect(h, 4.0);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false is static', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 0.5, enabled: false)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      final List<double> a = _heights(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_heights(tester), a);
      expect(a[2], closeTo(14, 1e-9));
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const VoiceWaveform(level: 0.4)));
      await _pumpFor(tester, 100);
      await tester.pumpWidget(
        _wrap(
          const VoiceWaveform(
            level: 0.4,
            barCount: 9,
            barWidth: 4,
            spacing: 2,
            minHeight: 2,
            maxHeight: 40,
            color: Colors.red,
          ),
        ),
      );
      await _pumpFor(tester, 100);
      expect(_heights(tester), hasLength(9));
      expect(tester.getSize(find.byType(VoiceWaveform)), const Size(52, 40));
      await tester.pumpWidget(
        _wrap(const VoiceWaveform(level: 0.4, barCount: 1)),
      );
      await _pumpFor(tester, 100);
      expect(_heights(tester), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> level = ValueNotifier<double>(0.5);
      addTearDown(level.dispose);
      await tester.pumpWidget(_wrap(VoiceWaveform(levelListenable: level)));
      await _pumpFor(tester, 100);
      await tester.pumpWidget(const SizedBox());
      level.value = 0.9;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
