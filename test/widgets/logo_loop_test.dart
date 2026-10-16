import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/logo_loop.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _k0 = ValueKey<String>('item0');
const Key _k1 = ValueKey<String>('item1');
const Key _k2 = ValueKey<String>('item2');

/// Three 50 x 20 boxes with a 10 pixel gap: one run is 180 pixels long.
const double _run = 180.0;

List<Widget> _items({bool vertical = false}) {
  final Size size = vertical ? const Size(20, 50) : const Size(50, 20);
  return <Widget>[
    for (final Key key in <Key>[_k0, _k1, _k2])
      SizedBox(
        key: key,
        width: size.width,
        height: size.height,
        child: const ColoredBox(color: Color(0xFF2196F3)),
      ),
  ];
}

Widget _wrap(
  Widget child, {
  double width = 400,
  double height = 400,
  TextDirection textDirection = TextDirection.ltr,
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: textDirection,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
          child: child,
        ),
      ),
    ),
  );
}

/// Position of the first copy of item 0 along [axis], relative to the loop.
double _pos(WidgetTester tester, {Axis axis = Axis.horizontal}) {
  final Offset origin = tester.getTopLeft(find.byType(LogoLoop));
  final Offset item = tester.getTopLeft(find.byKey(_k0).first);
  return axis == Axis.horizontal ? item.dx - origin.dx : item.dy - origin.dy;
}

/// [value] folded into [0, _run): the phase of the repeating pattern.
double _phase(double value) => value % _run;

Future<void> _dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  group('LogoLoop', () {
    testWidgets('renders enough copies to cover the viewport plus one run', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LogoLoop(gap: 10, children: _items())));
      // ceil(400 / 180) + 1 = 4 copies, already on the first frame.
      expect(find.byKey(_k0), findsNWidgets(4));
      expect(tester.getSize(find.byType(LogoLoop)), const Size(400, 20));
      await _dispose(tester);
    });

    testWidgets('copy count adapts to a resize within the same frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LogoLoop(gap: 10, children: _items())));
      expect(find.byKey(_k0), findsNWidgets(4));
      await tester.pumpWidget(
        _wrap(width: 750, LogoLoop(gap: 10, children: _items())),
      );
      // ceil(750 / 180) + 1 = 6.
      expect(find.byKey(_k0), findsNWidgets(6));
      await _dispose(tester);
    });

    testWidgets('scrolls left at speed and the offset wraps within one run', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, speed: 60, children: _items())),
      );
      expect(_pos(tester), 0.0);
      for (int second = 1; second <= 8; second++) {
        await tester.pump(const Duration(seconds: 1));
        final double shift = -_pos(tester);
        // The first copy never drifts more than one run out of view.
        expect(shift, greaterThanOrEqualTo(0.0));
        expect(shift, lessThan(_run));
        expect(shift, moreOrLessEquals((60.0 * second) % _run, epsilon: 1e-6));
      }
      await _dispose(tester);
    });

    testWidgets('movement is frame-rate independent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, speed: 60, children: _items())),
      );
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      final double highRate = _pos(tester);
      await _dispose(tester);

      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, speed: 60, children: _items())),
      );
      await tester.pump(const Duration(microseconds: 8333 * 60));
      expect(_pos(tester), moreOrLessEquals(highRate, epsilon: 1e-6));
      expect(highRate, moreOrLessEquals(-30.0, epsilon: 0.01));
      await _dispose(tester);
    });

    testWidgets('direction right and negative speed move to the right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LogoLoop(
            gap: 10,
            direction: LogoLoopDirection.right,
            children: _items(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_phase(_pos(tester)), moreOrLessEquals(30.0, epsilon: 1e-6));
      await _dispose(tester);

      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, speed: -60, children: _items())),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_phase(_pos(tester)), moreOrLessEquals(30.0, epsilon: 1e-6));
      await _dispose(tester);
    });

    testWidgets('vertical directions move up and down', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LogoLoop(
            gap: 10,
            direction: LogoLoopDirection.up,
            children: _items(vertical: true),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LogoLoop)), const Size(20, 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _phase(_pos(tester, axis: Axis.vertical)),
        moreOrLessEquals(_run - 30.0, epsilon: 1e-6),
      );
      await _dispose(tester);

      await tester.pumpWidget(
        _wrap(
          LogoLoop(
            gap: 10,
            direction: LogoLoopDirection.down,
            children: _items(vertical: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _phase(_pos(tester, axis: Axis.vertical)),
        moreOrLessEquals(30.0, epsilon: 1e-6),
      );
      await _dispose(tester);
    });

    testWidgets('right-to-left: starts at the right edge, left stays visual', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          textDirection: TextDirection.rtl,
          LogoLoop(gap: 10, children: _items()),
        ),
      );
      // First item sits at the right edge of the first run.
      expect(_pos(tester), 400.0 - 50.0);
      await tester.pump(const Duration(milliseconds: 500));
      // Moved 30 pixels toward the visual left.
      expect(
        _phase(_pos(tester)),
        moreOrLessEquals(_phase(350.0 - 30.0), epsilon: 1e-6),
      );
      await _dispose(tester);
    });

    testWidgets(
      'speed changes ease instead of snapping, then the ticker stops',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(LogoLoop(gap: 10, speed: 60, children: _items())),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(
          _wrap(LogoLoop(gap: 10, speed: 0, children: _items())),
        );
        final double before = _phase(_pos(tester));
        await tester.pump(const Duration(milliseconds: 100));
        final double moved = before - _phase(_pos(tester));
        // Still moving, but already slower than full speed (6 px / 100 ms).
        expect(moved, greaterThan(3.0));
        expect(moved, lessThan(6.0));
        await tester.pump(const Duration(milliseconds: 400));
        final double settled = _pos(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(_pos(tester), settled);
        expect(tester.binding.hasScheduledFrame, isFalse);

        // Speeding up again also eases in.
        await tester.pumpWidget(
          _wrap(LogoLoop(gap: 10, speed: 60, children: _items())),
        );
        final double start = _phase(_pos(tester));
        await tester.pump(const Duration(milliseconds: 100));
        final double accelerated = _phase(start - _phase(_pos(tester)));
        expect(accelerated, greaterThan(0.0));
        expect(accelerated, lessThan(3.0));
        await _dispose(tester);
      },
    );

    testWidgets('pauses on hover and resumes when the mouse leaves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LogoLoop(gap: 10, children: _items())));
      await tester.pump(const Duration(milliseconds: 100));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 300));
      await mouse.moveTo(const Offset(200, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final double paused = _pos(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_pos(tester), paused);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await mouse.moveTo(const Offset(200, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_pos(tester), isNot(paused));
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('hoverSpeed slows down instead of pausing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, hoverSpeed: 20, children: _items())),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 300));
      await mouse.moveTo(const Offset(200, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final double before = _phase(_pos(tester));
      await tester.pump(const Duration(seconds: 1));
      final double moved = _phase(before - _phase(_pos(tester)));
      expect(moved, moreOrLessEquals(20.0, epsilon: 1e-6));
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('pauseOnHover false keeps full speed under the mouse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, pauseOnHover: false, children: _items())),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 10));
      await tester.pump();
      final double before = _phase(_pos(tester));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _phase(before - _phase(_pos(tester))),
        moreOrLessEquals(30.0, epsilon: 1e-6),
      );
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('scaleOnHover grows only the hovered item', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, scaleOnHover: true, children: _items())),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 300));
      await mouse.moveTo(tester.getCenter(find.byKey(_k1).first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      double scaleOf(Key key) => tester
          .widget<AnimatedScale>(
            find
                .ancestor(
                  of: find.byKey(key).first,
                  matching: find.byType(AnimatedScale),
                )
                .first,
          )
          .scale;
      expect(scaleOf(_k1), 1.1);
      expect(scaleOf(_k0), 1.0);
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('fade mask present by default and absent when off', (
      WidgetTester tester,
    ) async {
      final Finder mask = find.descendant(
        of: find.byType(LogoLoop),
        matching: find.byType(ShaderMask),
      );
      await tester.pumpWidget(_wrap(LogoLoop(children: _items())));
      expect(mask, findsOneWidget);
      await tester.pumpWidget(
        _wrap(LogoLoop(fadeOut: false, children: _items())),
      );
      expect(mask, findsNothing);
      await _dispose(tester);
    });

    testWidgets('duplicates are excluded from semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const LogoLoop(
            gap: 10,
            children: <Widget>[Text('Alpha'), Text('Beta'), Text('Gamma')],
          ),
        ),
      );
      expect(find.text('Alpha'), findsAtLeastNWidgets(2));

      int count = 0;
      bool visit(SemanticsNode node) {
        count += 'Alpha'.allMatches(node.label).length;
        node.visitChildren(visit);
        return true;
      }

      visit(
        tester
            .renderObject(find.byType(LogoLoop))
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(count, 1);
      handle.dispose();
      await _dispose(tester);
    });

    testWidgets('children stay tappable while moving', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          LogoLoop(
            gap: 10,
            pauseOnHover: false,
            children: <Widget>[
              GestureDetector(
                onTap: () => taps++,
                child: const SizedBox(
                  key: _k0,
                  width: 50,
                  height: 20,
                  child: ColoredBox(color: Color(0xFF000000)),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Run is 60 pixels, so after 0.3 s the second copy sits at x = 42,
      // fully inside the viewport.
      final Finder visible = find.byKey(_k0).at(1);
      expect(tester.getTopLeft(visible).dx, moreOrLessEquals(42.0));
      await tester.tap(visible);
      expect(taps, 1);
      await _dispose(tester);
    });

    testWidgets('reduced motion: static single run, no frames scheduled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(reduceMotion: true, LogoLoop(gap: 10, children: _items())),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byKey(_k0), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(_pos(tester), 0.0);
    });

    testWidgets('enabled false renders statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LogoLoop(gap: 10, enabled: false, children: _items())),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byKey(_k0), findsOneWidget);
      expect(_pos(tester), 0.0);

      // Enabling starts the loop again.
      await tester.pumpWidget(_wrap(LogoLoop(gap: 10, children: _items())));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_pos(tester), moreOrLessEquals(-30.0, epsilon: 1e-6));
      await _dispose(tester);
    });

    testWidgets('unbounded main axis sizes to one run', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[LogoLoop(gap: 10, children: _items())],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LogoLoop)).width, _run);
      await tester.pump(const Duration(milliseconds: 100));
      await _dispose(tester);
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LogoLoop(children: _items())));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          LogoLoop(
            direction: LogoLoopDirection.down,
            gap: 4,
            speed: 120,
            fadeOut: false,
            scaleOnHover: true,
            speedChangeDuration: Duration.zero,
            children: _items(vertical: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_wrap(const LogoLoop(children: <Widget>[])));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LogoLoop(children: _items())));
      await tester.pump(const Duration(milliseconds: 250));
      await _dispose(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });
  });
}
