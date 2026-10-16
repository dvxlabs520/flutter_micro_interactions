import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/voice_pill.dart';
import 'package:flutter_micro_interactions/src/voice_waveform.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduced = false}) {
  final Widget app = MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
  if (!reduced) {
    return app;
  }
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: app,
  );
}

double _width(WidgetTester tester) =>
    tester.getSize(find.byType(VoicePill)).width;

/// Horizontal scale of the squash transform: the only transform that
/// scales x and y differently. 1 when the pill is not squashed.
double _squashScaleX(WidgetTester tester) {
  for (final Transform transform in tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(VoicePill),
      matching: find.byType(Transform),
    ),
  )) {
    final List<double> m = transform.transform.storage;
    if ((m[0] - m[5]).abs() > 1e-9) {
      return m[0];
    }
  }
  return 1.0;
}

List<double> _barHeights(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_WaveformPainter',
    ),
  );
  return List<double>.of(
    (paint.painter as dynamic).bars.heights as List<double>,
  );
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('VoicePill', () {
    test('formatElapsed', () {
      expect(VoicePill.formatElapsed(Duration.zero), '0:00');
      expect(VoicePill.formatElapsed(const Duration(seconds: 12)), '0:12');
      expect(
        VoicePill.formatElapsed(const Duration(minutes: 12, seconds: 3)),
        '12:03',
      );
      expect(VoicePill.formatElapsed(const Duration(seconds: 3723)), '1:02:03');
    });

    testWidgets('idle: a round mic button that asks to start', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: calls.add)),
      );
      expect(tester.getSize(find.byType(VoicePill)), const Size(48.0, 48.0));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byType(VoiceWaveform), findsNothing);

      await tester.tap(find.byType(VoicePill));
      expect(calls, <bool>[true]);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('starting grows the capsule with a spring', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: (_) {})),
      );
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {})),
      );
      final List<double> widths = <double>[];
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        widths.add(_width(tester));
      }
      expect(widths.first, greaterThan(48.0));
      expect(widths.first, lessThan(208.0));
      // The spring overshoots slightly, then settles on the open width.
      expect(
        widths.reduce((double a, double b) => a > b ? a : b),
        greaterThan(208.0),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_width(tester), closeTo(208.0, 0.5));
      expect(find.byType(VoiceWaveform), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stopping folds back with a squash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {})),
      );
      expect(_width(tester), 208.0);
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: (_) {})),
      );
      double maxSquash = 1.0;
      double previous = _width(tester);
      bool shrinking = true;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final double w = _width(tester);
        if (w > previous + 0.01) {
          shrinking = false;
        }
        previous = w;
        final double sx = _squashScaleX(tester);
        if (sx > maxSquash) {
          maxSquash = sx;
        }
      }
      expect(shrinking, isTrue);
      expect(maxSquash, greaterThan(1.02));
      await tester.pump(const Duration(seconds: 1));
      expect(_width(tester), 48.0);
      expect(_squashScaleX(tester), 1.0);
      expect(find.byType(VoiceWaveform), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the timer counts while recording and restarts', (
      WidgetTester tester,
    ) async {
      Widget build(bool recording) =>
          _wrap(VoicePill(recording: recording, onChanged: (_) {}));
      await tester.pumpWidget(build(true));
      expect(find.text('0:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('0:12'), findsOneWidget);
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(build(true));
      expect(find.text('0:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:01'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('elapsed overrides the measured time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          VoicePill(
            recording: true,
            onChanged: (_) {},
            elapsed: const Duration(seconds: 75),
          ),
        ),
      );
      expect(find.text('1:15'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1:15'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the level drives the equalizer bars', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> level = ValueNotifier<double>(0.0);
      addTearDown(level.dispose);
      await tester.pumpWidget(
        _wrap(
          VoicePill(recording: true, onChanged: (_) {}, levelListenable: level),
        ),
      );
      await _frames(tester, 20);
      final double quiet = _barHeights(
        tester,
      ).reduce((double a, double b) => a > b ? a : b);
      level.value = 1.0;
      await _frames(tester, 20);
      final double loud = _barHeights(
        tester,
      ).reduce((double a, double b) => a > b ? a : b);
      expect(loud, greaterThan(quiet + 5.0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the stop button asks to stop', (WidgetTester tester) async {
      final List<bool> calls = <bool>[];
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: calls.add)),
      );
      await tester.tap(find.byIcon(Icons.stop_rounded));
      expect(calls, <bool>[false]);
      // Tapping the waveform area does nothing.
      await tester.tap(find.byType(VoiceWaveform), warnIfMissed: false);
      expect(calls, <bool>[false]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cancel shows only while recording and calls onCancel', (
      WidgetTester tester,
    ) async {
      int cancels = 0;
      Widget build(bool recording) => _wrap(
        VoicePill(
          recording: recording,
          onChanged: (_) {},
          onCancel: () => cancels++,
        ),
      );
      await tester.pumpWidget(build(false));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cancels, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('semantics: start, stop, cancel and timer', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: (_) {}, onCancel: () {})),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Start recording')),
        matchesSemantics(
          label: 'Start recording',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {}, onCancel: () {})),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
      expect(find.bySemanticsLabel('Cancel recording'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Recording')),
        matchesSemantics(label: 'Recording', value: '0:03'),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('onChanged null renders disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const VoicePill(recording: false, onChanged: null)),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byIcon(Icons.mic_rounded),
              matching: find.byType(Opacity),
            )
            .last,
      );
      expect(opacity.opacity, 0.5);
      await tester.tap(find.byType(VoicePill), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard activation toggles', (WidgetTester tester) async {
      final List<bool> calls = <bool>[];
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: calls.add)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, <bool>[true]);
    });

    testWidgets('reduced motion: instant open and close, timer counts', (
      WidgetTester tester,
    ) async {
      Widget build(bool recording) => _wrap(
        VoicePill(recording: recording, onChanged: (_) {}),
        reduced: true,
      );
      await tester.pumpWidget(build(false));
      await tester.pumpWidget(build(true));
      expect(_width(tester), 208.0);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(build(false));
      expect(_width(tester), 48.0);
      expect(_squashScaleX(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false: instant transitions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: (_) {}, enabled: false)),
      );
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {}, enabled: false)),
      );
      expect(_width(tester), 208.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('config changes and disposal mid-spring do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VoicePill(recording: false, onChanged: (_) {})),
      );
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {})),
      );
      await _frames(tester, 3);
      await tester.pumpWidget(
        _wrap(
          Directionality(
            textDirection: TextDirection.rtl,
            child: VoicePill(
              recording: false,
              onChanged: (_) {},
              size: 56,
              expandedWidth: 240,
              recordingColor: Colors.red,
              stopIcon: Icons.check_rounded,
              barCount: 5,
            ),
          ),
        ),
      );
      await _frames(tester, 3);
      await tester.pumpWidget(
        _wrap(VoicePill(recording: true, onChanged: (_) {})),
      );
      await _frames(tester, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
