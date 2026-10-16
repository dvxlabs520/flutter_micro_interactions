import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/voice_glow.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _glow({
  double level = 0.0,
  ValueListenable<double>? levelListenable,
  VoiceGlowState state = VoiceGlowState.listening,
  VoiceGlowPalette palette = VoiceGlowPalette.colorful,
  List<Color>? colors,
  Brightness? brightness,
  bool enabled = true,
  bool clip = true,
  bool showBand = true,
  double reach = 1.2,
}) {
  return VoiceGlow(
    level: level,
    levelListenable: levelListenable,
    state: state,
    palette: palette,
    colors: colors,
    brightness: brightness,
    enabled: enabled,
    clip: clip,
    showBand: showBand,
    reach: reach,
    child: const SizedBox(width: 350, height: 56, child: Text('Ask')),
  );
}

/// The per-frame values the glow painter draws.
dynamic _frame(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(VoiceGlow),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_VoiceGlowPainter',
      ),
    ),
  );
  return (paint.painter as dynamic).frame;
}

double _effective(WidgetTester tester) =>
    (_frame(tester).effective as num).toDouble();

Future<void> _pumpFor(WidgetTester tester, int milliseconds) async {
  for (int t = 0; t < milliseconds; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('VoiceGlow', () {
    testWidgets('renders its child and a decorative glow', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_glow()));
      expect(find.text('Ask'), findsOneWidget);
      expect(find.bySemanticsLabel('Ask'), findsOneWidget);
      expect(_frame(tester), isNotNull);
      await _pumpFor(tester, 200);
      expect(tester.takeException(), isNull);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rises with the level and falls more slowly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow()));
      await _pumpFor(tester, 600);
      final double quiet = _effective(tester);
      expect(quiet, lessThan(0.05));

      await tester.pumpWidget(_wrap(_glow(level: 1)));
      // One attack time constant: about 63 percent of the way up.
      await _pumpFor(tester, 325);
      final double rising = _effective(tester);
      expect(rising, greaterThan(0.5));
      expect(rising, lessThan(0.8));
      await _pumpFor(tester, 2000);
      expect(_effective(tester), greaterThan(0.95));

      await tester.pumpWidget(_wrap(_glow(level: 0)));
      await _pumpFor(tester, 325);
      // Release is slower than attack: still well above the rising value
      // drop after the same time.
      expect(_effective(tester), greaterThan(0.6));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lobes flow sideways and the hue drifts while listening', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow(level: 0.8)));
      await _pumpFor(tester, 500);
      final double phase0 = (_frame(tester).phase as num).toDouble();
      final double hue0 = (_frame(tester).hueDegrees as num).toDouble();
      await _pumpFor(tester, 500);
      expect((_frame(tester).phase as num).toDouble(), isNot(phase0));
      expect((_frame(tester).hueDegrees as num).toDouble(), isNot(hue0));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
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
              return _glow(levelListenable: level);
            },
          ),
        ),
      );
      await _pumpFor(tester, 300);
      final double before = _effective(tester);
      level.value = 0.9;
      await _pumpFor(tester, 1500);
      expect(_effective(tester), greaterThan(before + 0.5));
      expect(builds, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('idle breathes on its own', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_glow(state: VoiceGlowState.idle)));
      final List<double> samples = <double>[];
      for (int i = 0; i < 6; i++) {
        await _pumpFor(tester, 900);
        samples.add(_effective(tester));
      }
      final double maxValue = samples.reduce((double a, double b) {
        return a > b ? a : b;
      });
      final double minValue = samples.reduce((double a, double b) {
        return a < b ? a : b;
      });
      expect(maxValue, greaterThan(0.1));
      expect(maxValue, lessThanOrEqualTo(0.24));
      expect(maxValue - minValue, greaterThan(0.05));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('processing gathers a beam that sweeps side to side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow()));
      await _pumpFor(tester, 200);
      await tester.pumpWidget(_wrap(_glow(state: VoiceGlowState.processing)));
      await _pumpFor(tester, 1500);
      expect((_frame(tester).processing as num).toDouble(), greaterThan(0.95));
      final List<double> positions = <double>[];
      for (int i = 0; i < 10; i++) {
        await _pumpFor(tester, 500);
        positions.add((_frame(tester).beamU as num).toDouble());
      }
      expect(positions.any((double u) => u > 0.8), isTrue);
      expect(positions.any((double u) => u < -0.8), isTrue);

      await tester.pumpWidget(_wrap(_glow()));
      await _pumpFor(tester, 2000);
      expect((_frame(tester).processing as num).toDouble(), lessThan(0.05));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('off fades out, stops ticking and fades back in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow(level: 0.5)));
      await _pumpFor(tester, 700);
      expect((_frame(tester).fade as num).toDouble(), 1.0);

      await tester.pumpWidget(
        _wrap(_glow(level: 0.5, state: VoiceGlowState.off)),
      );
      await _pumpFor(tester, 250);
      final double midFade = (_frame(tester).fade as num).toDouble();
      expect(midFade, greaterThan(0.0));
      expect(midFade, lessThan(1.0));
      await _pumpFor(tester, 400);
      expect((_frame(tester).fade as num).toDouble(), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_wrap(_glow(level: 0.5)));
      expect(tester.hasRunningAnimations, isTrue);
      await _pumpFor(tester, 300);
      final double fadingIn = (_frame(tester).fade as num).toDouble();
      expect(fadingIn, greaterThan(0.0));
      expect(fadingIn, lessThan(1.0));
      await _pumpFor(tester, 400);
      expect((_frame(tester).fade as num).toDouble(), 1.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion schedules no frames but follows the level', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow(level: 0.2), reducedMotion: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_effective(tester), closeTo(0.2, 1e-9));

      await tester.pumpWidget(_wrap(_glow(level: 0.9), reducedMotion: true));
      expect(_effective(tester), closeTo(0.9, 1e-9));
      expect((_frame(tester).phase as num).toDouble(), 0.0);
      expect((_frame(tester).hueDegrees as num).toDouble(), 0.0);
      expect(tester.hasRunningAnimations, isFalse);

      // levelListenable also works without a ticker.
      final ValueNotifier<double> level = ValueNotifier<double>(0.1);
      addTearDown(level.dispose);
      await tester.pumpWidget(
        _wrap(_glow(levelListenable: level), reducedMotion: true),
      );
      expect(_effective(tester), closeTo(0.1, 1e-9));
      level.value = 0.7;
      await tester.pump();
      expect(_effective(tester), closeTo(0.7, 1e-9));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Processing shows a still beam in the center; off hides the glow.
      await tester.pumpWidget(
        _wrap(_glow(state: VoiceGlowState.processing), reducedMotion: true),
      );
      expect((_frame(tester).processing as num).toDouble(), 1.0);
      expect((_frame(tester).beamU as num).toDouble(), 0.0);
      await tester.pumpWidget(
        _wrap(_glow(state: VoiceGlowState.off), reducedMotion: true),
      );
      expect((_frame(tester).fade as num).toDouble(), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false shows a static idle frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow(level: 0.9, enabled: false)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Idle breathing frozen at its midpoint: 0.23 * 0.5.
      expect(_effective(tester), closeTo(0.115, 1e-9));
      expect((_frame(tester).idleMix as num).toDouble(), 1.0);
      expect(find.text('Ask'), findsOneWidget);

      // Re-enabling starts the ticker again.
      await tester.pumpWidget(_wrap(_glow(level: 0.9)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> a = ValueNotifier<double>(0.3);
      final ValueNotifier<double> b = ValueNotifier<double>(0.8);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await tester.pumpWidget(_wrap(_glow(levelListenable: a)));
      await _pumpFor(tester, 200);
      await tester.pumpWidget(_wrap(_glow(levelListenable: b)));
      await _pumpFor(tester, 1500);
      expect(_effective(tester), greaterThan(0.7));
      // The old listenable is no longer listened to.
      a.value = 0.0;
      await _pumpFor(tester, 100);
      expect(_effective(tester), greaterThan(0.7));

      for (final VoiceGlowPalette palette in VoiceGlowPalette.values) {
        for (final Brightness brightness in Brightness.values) {
          await tester.pumpWidget(
            _wrap(
              _glow(
                level: 0.6,
                palette: palette,
                brightness: brightness,
                clip: brightness == Brightness.dark,
                reach: 2,
              ),
            ),
          );
          await _pumpFor(tester, 50);
        }
      }
      await tester.pumpWidget(
        _wrap(
          _glow(
            level: 0.6,
            colors: const <Color>[Colors.red, Colors.blue],
            showBand: false,
            state: VoiceGlowState.processing,
          ),
        ),
      );
      await _pumpFor(tester, 100);
      await tester.pumpWidget(
        _wrap(_glow(level: 0.6, state: VoiceGlowState.idle)),
      );
      await _pumpFor(tester, 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switching reduced motion on and off mid-animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_glow(level: 0.5)));
      await _pumpFor(tester, 200);
      await tester.pumpWidget(_wrap(_glow(level: 0.5), reducedMotion: true));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_effective(tester), closeTo(0.5, 1e-9));
      await tester.pumpWidget(_wrap(_glow(level: 0.5)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> level = ValueNotifier<double>(0.5);
      addTearDown(level.dispose);
      await tester.pumpWidget(
        _wrap(_glow(levelListenable: level, state: VoiceGlowState.processing)),
      );
      await _pumpFor(tester, 150);
      await tester.pumpWidget(const SizedBox());
      // Changes after dispose are ignored.
      level.value = 0.9;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
