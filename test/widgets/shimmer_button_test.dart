import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/shimmer_button.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

/// The shimmer band overlay is the only SlideTransition in the button.
Finder get _shimmerBand => find.descendant(
      of: find.byType(ShimmerButton),
      matching: find.byType(SlideTransition),
    );

void main() {
  group('ShimmerButton', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ShimmerButton(onPressed: () {}, child: const Text('Buy'))),
      );
      expect(find.text('Buy'), findsOneWidget);
      // Dispose to stop the shimmer loop before the test ends.
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('fires onPressed immediately on tap-up',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () => pressed = true,
            child: const Text('Buy'),
          ),
        ),
      );
      await tester.tap(find.text('Buy'));
      // Fires on tap-up without waiting for any animation pump.
      expect(pressed, isTrue);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('shimmer sweeps, pauses, then sweeps again',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () {},
            shimmerDuration: const Duration(milliseconds: 400),
            shimmerInterval: const Duration(milliseconds: 300),
            child: const Text('Buy'),
          ),
        ),
      );
      expect(_shimmerBand, findsOneWidget);

      Offset bandOffset() =>
          tester.widget<SlideTransition>(_shimmerBand).position.value;

      // The band starts outside the start edge and moves during a sweep.
      final Offset start = bandOffset();
      await tester.pump(const Duration(milliseconds: 200));
      expect(bandOffset(), isNot(equals(start)));

      // Finish the sweep; the band rests back at the start position during
      // the pause between sweeps.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bandOffset(), equals(start));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bandOffset(), equals(start));

      // After the interval the next sweep is running again.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(bandOffset(), isNot(equals(start)));

      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('onPressed null renders disabled: dimmed, no shimmer, no tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const ShimmerButton(onPressed: null, child: Text('Buy'))),
      );
      expect(_shimmerBand, findsNothing);
      final Opacity opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Buy'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, lessThan(1.0));
      // Tapping a disabled button must not throw and plays no press.
      await tester.tap(find.text('Buy'), warnIfMissed: false);
      await tester.pump();
      // No shimmer loop means no timers pending at the end of this test.
    });

    testWidgets('enabled false never fires onPressed and shows no shimmer',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            enabled: false,
            onPressed: () => pressed = true,
            child: const Text('Buy'),
          ),
        ),
      );
      expect(_shimmerBand, findsNothing);
      await tester.tap(find.text('Buy'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, isFalse);
    });

    testWidgets('reduced motion: no shimmer, still fully functional',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            ShimmerButton(
              onPressed: () => pressed = true,
              child: const Text('Buy'),
            ),
          ),
        ),
      );
      expect(_shimmerBand, findsNothing);
      await tester.tap(find.text('Buy'));
      expect(pressed, isTrue);
      await tester.pump();
      // No shimmer loop: no timers pending at the end of this test.
    });

    testWidgets('press scales the button down and back',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ShimmerButton(onPressed: () {}, child: const Text('Buy'))),
      );

      double scale() => tester
          .widget<ScaleTransition>(
            find
                .ancestor(
                  of: find.text('Buy'),
                  matching: find.byType(ScaleTransition),
                )
                .first,
          )
          .scale
          .value;

      expect(scale(), 1.0);
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('Buy')));
      // One pump to let the tap recognizer report the press and start the
      // controller, then one to advance the animation.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(), lessThan(1.0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(), 1.0);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('keyboard focus shows a highlight and Enter activates',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () => pressed = true,
            child: const Text('Buy'),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Focus highlight border overlay appears.
      expect(
        find.descendant(
          of: find.byType(ShimmerButton),
          matching: find.byType(DecoratedBox),
        ),
        findsWidgets,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(pressed, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('exposes button semantics with a label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () {},
            semanticLabel: 'Buy now',
            child: const SizedBox(width: 80, height: 20),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Buy now')),
        matchesSemantics(
          label: 'Buy now',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('disposing mid-sweep cancels the loop cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () {},
            shimmerDuration: const Duration(milliseconds: 400),
            shimmerInterval: const Duration(milliseconds: 300),
            child: const Text('Buy'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      // Removing the button mid-sweep must cancel its interval timer; the
      // test framework fails if any timer were left pending here.
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(find.text('Buy'), findsNothing);

      // Dispose during the pause between sweeps as well.
      await tester.pumpWidget(
        _wrap(
          ShimmerButton(
            onPressed: () {},
            shimmerDuration: const Duration(milliseconds: 100),
            shimmerInterval: const Duration(seconds: 5),
            child: const Text('Buy'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_wrap(const SizedBox()));
    });
  });
}
