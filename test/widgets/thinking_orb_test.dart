import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/thinking_orb.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false, ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(ThinkingOrb),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter;
}

double _clock(WidgetTester tester) =>
    (_painter(tester).clock as ValueListenable<double>).value;

double _fade(WidgetTester tester) =>
    (_painter(tester).fade as Animation<double>).value;

void main() {
  group('ThinkingOrb', () {
    testWidgets('renders with defaults', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(find.byType(ThinkingOrb)), const Size(64, 64));
      expect(_painter(tester).state, ThinkingOrbState.working);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    for (final ThinkingOrbState state in ThinkingOrbState.values) {
      testWidgets('${state.name} renders at 20, 64 and 120', (
        WidgetTester tester,
      ) async {
        for (final double size in <double>[20, 64, 120]) {
          await tester.pumpWidget(_wrap(ThinkingOrb(state: state, size: size)));
          for (int i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(tester.getSize(find.byType(ThinkingOrb)), Size(size, size));
          expect(
            tester.renderObject(
              find
                  .descendant(
                    of: find.byType(ThinkingOrb),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            ),
            paints..circle(),
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('time progresses while animating', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      final double t0 = _clock(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      final double t1 = _clock(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double t2 = _clock(tester);

      expect(tester.hasRunningAnimations, isTrue);
      expect(t1, greaterThan(t0));
      expect(t2, greaterThan(t1));
      expect(t2 - t1, closeTo(0.25, 0.001));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('speed scales time and 0 freezes it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb(speed: 2)));
      await tester.pump(const Duration(milliseconds: 100));
      final double a = _clock(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_clock(tester) - a, closeTo(0.4, 0.001));

      await tester.pumpWidget(_wrap(const ThinkingOrb(speed: 0.5)));
      await tester.pump(const Duration(milliseconds: 100));
      final double b = _clock(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_clock(tester) - b, closeTo(0.1, 0.001));

      await tester.pumpWidget(_wrap(const ThinkingOrb(speed: 0)));
      final double c = _clock(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_clock(tester), c);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_clock(tester), greaterThan(c));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('state change crossfades between scenes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(
        _wrap(const ThinkingOrb(state: ThinkingOrbState.searching)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester).state, ThinkingOrbState.searching);
      expect(_painter(tester).previous, ThinkingOrbState.working);
      expect(_fade(tester), greaterThan(0.0));
      expect(_fade(tester), lessThan(1.0));

      // A second change mid-crossfade is safe.
      await tester.pumpWidget(
        _wrap(const ThinkingOrb(state: ThinkingOrbState.shaping)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painter(tester).previous, ThinkingOrbState.searching);

      await tester.pump(const Duration(milliseconds: 300));
      expect(_fade(tester), 1.0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion renders a static frame and schedules nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb(), reducedMotion: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      final double t = _clock(tester);
      expect(t, 0.6);

      // State changes switch instantly.
      await tester.pumpWidget(
        _wrap(
          const ThinkingOrb(state: ThinkingOrbState.weaving),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_painter(tester).state, ThinkingOrbState.weaving);
      expect(_painter(tester).previous, isNull);
      expect(_clock(tester), t);
    });

    testWidgets('enabled false is static', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb(enabled: false)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_clock(tester), 0.6);

      // Enabling starts the animation; disabling returns to the static frame.
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      expect(_clock(tester), greaterThan(0.6));

      await tester.pumpWidget(_wrap(const ThinkingOrb(enabled: false)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_clock(tester), 0.6);
    });

    testWidgets('semantics label follows state and override', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final ThinkingOrbState state in ThinkingOrbState.values) {
        await tester.pumpWidget(
          _wrap(ThinkingOrb(state: state), reducedMotion: true),
        );
        expect(find.bySemanticsLabel(state.label), findsOneWidget);
      }
      expect(ThinkingOrbState.thinking.label, 'Thinking...');

      await tester.pumpWidget(
        _wrap(
          const ThinkingOrb(semanticLabel: 'Assistant is busy'),
          reducedMotion: true,
        ),
      );
      expect(find.bySemanticsLabel('Assistant is busy'), findsOneWidget);
      expect(find.bySemanticsLabel('Working...'), findsNothing);
      handle.dispose();
    });

    testWidgets('color defaults to onSurface and can be overridden', (
      WidgetTester tester,
    ) async {
      final ThemeData theme = ThemeData(brightness: Brightness.dark);
      await tester.pumpWidget(
        _wrap(const ThinkingOrb(), reducedMotion: true, theme: theme),
      );
      expect(_painter(tester).color, theme.colorScheme.onSurface);

      await tester.pumpWidget(
        _wrap(const ThinkingOrb(color: Colors.teal), reducedMotion: true),
      );
      expect(_painter(tester).color, Colors.teal);
    });

    testWidgets('configuration changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          const ThinkingOrb(
            state: ThinkingOrbState.connecting,
            size: 24,
            speed: 3,
            color: Colors.red,
            transitionDuration: Duration(milliseconds: 600),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          const ThinkingOrb(
            state: ThinkingOrbState.thinking,
            transitionDuration: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      expect(_painter(tester).previous, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingOrb()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(const ThinkingOrb(state: ThinkingOrbState.solving)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
