import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/pixel_transition.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// 12 by 12 grid, so 144 cells.
const int _cells = 144;

Widget _pixels({
  PixelTransitionTrigger trigger = PixelTransitionTrigger.hover,
  bool? showSecond,
  ValueChanged<bool>? onChanged,
  PixelTransitionController? controller,
  bool enabled = true,
  int gridSize = 12,
  Duration duration = const Duration(milliseconds: 600),
  Color? pixelColor,
  int? seed = 7,
  VoidCallback? onSecondPressed,
}) {
  return PixelTransition(
    trigger: trigger,
    showSecond: showSecond,
    onChanged: onChanged,
    controller: controller,
    enabled: enabled,
    gridSize: gridSize,
    duration: duration,
    pixelColor: pixelColor,
    seed: seed,
    firstChild: const SizedBox(
      width: 200,
      height: 120,
      child: Center(child: Text('First')),
    ),
    secondChild: SizedBox(
      width: 160,
      height: 160,
      child: Center(
        child: GestureDetector(
          onTap: onSecondPressed,
          child: const Text('Second'),
        ),
      ),
    ),
  );
}

Finder get _painterFinder => find.descendant(
  of: find.byType(PixelTransition),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_PixelPainter',
  ),
);

dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painterFinder).painter;

double _progress(WidgetTester tester) =>
    (_painter(tester).progress as Animation<double>).value;

/// Number of rectangles the cell painter draws in the current frame.
Matcher _drawsRects(int count) =>
    count == 0 ? paintsNothing : paintsExactlyCountTimes(#drawRect, count);

RenderObject _painterBox(WidgetTester tester) =>
    tester.renderObject(_painterFinder);

/// Opacity of the wrapper around [text]; 1 means it is on screen.
double _opacityOf(WidgetTester tester, String text) {
  return tester
      .widget<Opacity>(
        find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
      )
      .opacity;
}

bool _showing(WidgetTester tester, String text) =>
    _opacityOf(tester, text) == 1.0;

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('PixelTransition', () {
    testWidgets('renders the first child at rest, sized to the larger child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels()));
      expect(_showing(tester, 'First'), isTrue);
      expect(_showing(tester, 'Second'), isFalse);
      expect(
        tester.getSize(find.byType(PixelTransition)),
        const Size(200, 160),
      );
      expect(_painterBox(tester), _drawsRects(0));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('covers, swaps under full coverage, then reveals', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_pixels(onChanged: changes.add)));
      // A touch tap toggles in hover mode.
      await tester.tap(find.byType(PixelTransition));
      expect(changes, <bool>[true]);
      await tester.pump();

      // Quarter way: half of the cells cover the first child.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_progress(tester), closeTo(0.25, 1e-9));
      expect(_painterBox(tester), _drawsRects(_cells ~/ 2));
      expect(_showing(tester, 'First'), isTrue);

      // Halfway: fully covered (one rectangle) and the content swapped.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_painterBox(tester), _drawsRects(1));
      expect(_showing(tester, 'Second'), isTrue);
      expect(_showing(tester, 'First'), isFalse);

      // Three quarters: half of the cells are gone again.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_painterBox(tester), _drawsRects(_cells ~/ 2));
      expect(_showing(tester, 'Second'), isTrue);

      await tester.pumpAndSettle();
      expect(_painterBox(tester), _drawsRects(0));
      expect(_showing(tester, 'Second'), isTrue);
      expect(changes, <bool>[true]);

      // Tapping again goes back to the first child.
      await tester.tap(find.byType(PixelTransition));
      await tester.pumpAndSettle();
      expect(_showing(tester, 'First'), isTrue);
      expect(changes, <bool>[true, false]);
    });

    testWidgets('cells appear in a fresh random order every transition', (
      WidgetTester tester,
    ) async {
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_pixels(controller: controller)));
      controller.toggle();
      await tester.pump();
      final dynamic plan = _painter(tester).plan;
      final Uint16List cover = plan.coverOrder as Uint16List;
      final Uint16List reveal = plan.revealOrder as Uint16List;
      expect(cover.toSet(), hasLength(_cells));
      expect(reveal.toSet(), hasLength(_cells));
      expect(cover, isNot(orderedEquals(reveal)));
      await tester.pumpAndSettle();

      controller.toggle();
      await tester.pump();
      final dynamic next = _painter(tester).plan;
      expect(next.coverOrder as Uint16List, isNot(orderedEquals(cover)));
      await tester.pumpAndSettle();
    });

    testWidgets('the same seed gives the same cell order', (
      WidgetTester tester,
    ) async {
      Future<List<int>> coverOrder() async {
        final PixelTransitionController controller =
            PixelTransitionController();
        await tester.pumpWidget(
          _wrap(_pixels(controller: controller, seed: 42)),
        );
        controller.showSecond();
        await tester.pump();
        final List<int> order = List<int>.of(
          _painter(tester).plan.coverOrder as Uint16List,
        );
        await tester.pumpWidget(_wrap(const SizedBox()));
        controller.dispose();
        return order;
      }

      expect(await coverOrder(), orderedEquals(await coverOrder()));
    });

    testWidgets('mouse hover shows the second child and exit the first', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_pixels(onChanged: changes.add)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(PixelTransition)));
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);

      // A mouse click does not toggle in hover mode.
      await tester.tap(
        find.byType(PixelTransition),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(_showing(tester, 'First'), isTrue);
      expect(changes, <bool>[true, false]);
    });

    testWidgets('tap trigger toggles on mouse clicks and ignores hover', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_pixels(trigger: PixelTransitionTrigger.tap)),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(PixelTransition)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(
        find.byType(PixelTransition),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);
    });

    testWidgets('manual trigger ignores gestures', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(_pixels(trigger: PixelTransitionTrigger.manual)),
      );
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_showing(tester, 'First'), isTrue);
    });

    testWidgets('taps on the visible child reach it without toggling', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _pixels(
            controller: controller,
            trigger: PixelTransitionTrigger.tap,
            onSecondPressed: () => taps++,
          ),
        ),
      );
      controller.showSecond();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(_showing(tester, 'Second'), isTrue);
    });

    testWidgets('controller commands and isShowingSecond', (
      WidgetTester tester,
    ) async {
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_pixels(controller: controller, onChanged: changes.add)),
      );
      expect(controller.isShowingSecond, isFalse);

      controller.showSecond();
      await tester.pump();
      expect(controller.isShowingSecond, isTrue);
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);

      // Already there: no-op.
      controller.showSecond();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(_showing(tester, 'First'), isTrue);
      expect(controller.isShowingSecond, isFalse);

      controller.showFirst();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(changes, <bool>[true, false]);
    });

    testWidgets('controlled mode only requests through onChanged', (
      WidgetTester tester,
    ) async {
      final List<bool> requests = <bool>[];
      await tester.pumpWidget(
        _wrap(_pixels(showSecond: false, onChanged: requests.add)),
      );
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      expect(requests, <bool>[true]);
      expect(tester.hasRunningAnimations, isFalse);

      // The parent applies the request.
      await tester.pumpWidget(
        _wrap(_pixels(showSecond: true, onChanged: requests.add)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_painterBox(tester), _drawsRects(_cells ~/ 2));
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);
      expect(requests, <bool>[true]);
    });

    testWidgets('starts on the second child when showSecond is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels(showSecond: true)));
      expect(_showing(tester, 'Second'), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('toggling back while covering retraces without swapping', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_pixels(onChanged: changes.add)));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final double mid = _progress(tester);

      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_progress(tester), lessThan(mid));
      expect(_showing(tester, 'First'), isTrue);
      await tester.pumpAndSettle();
      expect(_showing(tester, 'First'), isTrue);
      expect(_painterBox(tester), _drawsRects(0));
      expect(changes, <bool>[true, false]);
    });

    testWidgets('toggling back while revealing re-covers and swaps back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels()));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(_showing(tester, 'Second'), isTrue);

      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      // Back under full coverage the first child returns.
      await tester.pump(const Duration(milliseconds: 160));
      expect(_showing(tester, 'First'), isTrue);

      // Many rapid toggles never throw and settle on a consistent side.
      for (int i = 0; i < 7; i++) {
        await tester.tap(find.byType(PixelTransition));
        await tester.pump(const Duration(milliseconds: 37));
      }
      await tester.pumpAndSettle();
      expect(_painterBox(tester), _drawsRects(0));
      // Seven more toggles after "first" end on the second child.
      expect(_showing(tester, 'Second'), isTrue);
    });

    testWidgets('only the visible child is in the semantics tree', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_pixels(controller: controller)));
      expect(find.bySemanticsLabel('First'), findsOneWidget);
      expect(find.bySemanticsLabel('Second'), findsNothing);

      controller.showSecond();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('First'), findsOneWidget);
      expect(find.bySemanticsLabel('Second'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('First'), findsNothing);
      expect(find.bySemanticsLabel('Second'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion swaps instantly without cells', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_pixels(onChanged: changes.add), reduceMotion: true),
      );
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_showing(tester, 'Second'), isTrue);
      expect(_painterBox(tester), _drawsRects(0));
      expect(changes, <bool>[true]);
    });

    testWidgets('turning on reduced motion mid-transition settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels()));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_wrap(_pixels(), reduceMotion: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_showing(tester, 'Second'), isTrue);
      expect(_painterBox(tester), _drawsRects(0));
    });

    testWidgets('enabled false ignores gestures and the controller', (
      WidgetTester tester,
    ) async {
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          _pixels(
            enabled: false,
            controller: controller,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(PixelTransition));
      controller.toggle();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_showing(tester, 'First'), isTrue);
      expect(changes, isEmpty);

      // A new declarative value still applies, instantly.
      await tester.pumpWidget(_wrap(_pixels(enabled: false, showSecond: true)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_showing(tester, 'Second'), isTrue);
    });

    testWidgets('disabling mid-transition jumps to the target side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels()));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(_pixels(enabled: false)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_showing(tester, 'Second'), isTrue);
      expect(_painterBox(tester), _drawsRects(0));
    });

    testWidgets('config changes mid-transition do not throw', (
      WidgetTester tester,
    ) async {
      final PixelTransitionController controller = PixelTransitionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_pixels()));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(
        _wrap(
          _pixels(
            gridSize: 5,
            duration: const Duration(milliseconds: 1000),
            pixelColor: Colors.red,
            seed: 99,
            controller: controller,
            trigger: PixelTransitionTrigger.tap,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_progress(tester), greaterThan(0.25));
      expect(_progress(tester), lessThan(0.5));
      // The new 5 by 5 grid is used right away.
      expect(_painterBox(tester), paints..rect(color: Colors.red));
      await tester.pumpAndSettle();
      expect(_showing(tester, 'Second'), isTrue);
      expect(controller.isShowingSecond, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-transition does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_pixels()));
      await tester.tap(find.byType(PixelTransition));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });

    test('rejects an invalid grid size', () {
      expect(
        () => PixelTransition(
          gridSize: 0,
          firstChild: const SizedBox(),
          secondChild: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });
}
