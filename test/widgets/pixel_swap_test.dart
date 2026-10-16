import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/pixel_swap.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 200 x 120 swap centered on the 800 x 600 test screen, spanning
/// x 300..500 and y 240..360. With gridSize 6 the cells are 20 px, in a
/// 10 x 6 grid.
Widget _swap({
  PixelSwapTrigger trigger = PixelSwapTrigger.hover,
  PixelSwapController? controller,
  bool showSecond = false,
  bool enabled = true,
  int gridSize = 6,
  double gap = 0,
  Duration duration = const Duration(milliseconds: 700),
  Curve? curve,
  ValueChanged<bool>? onChanged,
}) {
  final Widget first = Container(
    width: 200,
    height: 120,
    color: Colors.indigo,
    alignment: Alignment.center,
    child: const Text('First'),
  );
  const Widget second = ColoredBox(
    color: Colors.pink,
    child: Center(child: Text('Second')),
  );
  if (curve != null) {
    return PixelSwap(
      first: first,
      second: second,
      trigger: trigger,
      controller: controller,
      showSecond: showSecond,
      enabled: enabled,
      gridSize: gridSize,
      gap: gap,
      duration: duration,
      curve: curve,
      onChanged: onChanged,
    );
  }
  return PixelSwap(
    first: first,
    second: second,
    trigger: trigger,
    controller: controller,
    showSecond: showSecond,
    enabled: enabled,
    gridSize: gridSize,
    gap: gap,
    duration: duration,
    onChanged: onChanged,
  );
}

dynamic _wave(WidgetTester tester) {
  final RenderObject clip = tester.renderObject(
    find.byWidgetPredicate(
      (Widget w) => w.runtimeType.toString() == '_PixelClip',
    ),
  );
  return (clip as dynamic).wave;
}

double _cell(WidgetTester tester, int i, int j) =>
    _wave(tester).valueAt(i, j) as double;

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

const Offset _topLeft = Offset(301, 241);
const Offset _bottomRight = Offset(499, 359);
const Duration _total = Duration(milliseconds: 1020);

void main() {
  group('PixelSwap', () {
    testWidgets('sizes from first and shows only first at rest', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_swap()));
      expect(tester.getSize(find.byType(PixelSwap)), const Size(200, 120));
      expect(find.semantics.byLabel('First'), findsOneWidget);
      expect(find.semantics.byLabel('Second'), findsNothing);
      expect(_cell(tester, 0, 0), 0.0);
      expect(_wave(tester).cols, 10);
      expect(_wave(tester).rows, 6);
      expect(tester.hasRunningAnimations, isFalse);
      handle.dispose();
    });

    testWidgets('hover builds the second child in from the entry point', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_swap(onChanged: changes.add)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      expect(changes, <bool>[true]);

      final dynamic wave = _wave(tester);
      expect(
        wave.delayAt(0, 0) as double,
        lessThan(wave.delayAt(9, 5) as double),
      );
      expect(
        wave.delayAt(1, 1) as double,
        lessThan(wave.delayAt(8, 4) as double),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(_cell(tester, 0, 0), greaterThan(0.5));
      expect(_cell(tester, 9, 5), 0.0);

      // The spring overshoots before settling at 1.
      double peak = 0;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final double v = _cell(tester, 5, 3);
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(1.05));

      await tester.pump(_total);
      expect(_cell(tester, 9, 5), 1.0);
      expect(_wave(tester).isSettled, isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('leaving plays the reverse wave from the exit point', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_swap(onChanged: changes.add)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      await tester.pump(_total);

      await mouse.moveTo(_bottomRight);
      await mouse.moveTo(const Offset(520, 380));
      await tester.pump();
      expect(changes, <bool>[true, false]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cell(tester, 9, 5), lessThan(0.5));
      expect(_cell(tester, 0, 0), 1.0);

      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('rapid toggles reverse cells without jumps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_swap()));
      final TestGesture mouse = await _mouse(tester);
      for (int round = 0; round < 4; round++) {
        await mouse.moveTo(_topLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final double before = _cell(tester, 1, 1);
        await mouse.moveTo(const Offset(290, 230));
        await tester.pump();
        expect(_cell(tester, 1, 1), closeTo(before, 1e-6));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(_total);
      expect(_cell(tester, 1, 1), 0.0);
      expect(_cell(tester, 9, 5), 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics, focus and hit testing swap halfway', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final PixelSwapController controller = PixelSwapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_swap(trigger: PixelSwapTrigger.manual, controller: controller)),
      );
      controller.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.semantics.byLabel('First'), findsOneWidget);
      expect(find.semantics.byLabel('Second'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.semantics.byLabel('First'), findsNothing);
      expect(find.semantics.byLabel('Second'), findsOneWidget);
      expect(find.text('Second').hitTestable(), findsOneWidget);
      expect(find.text('First').hitTestable(), findsNothing);
      await tester.pump(_total);
      handle.dispose();
    });

    testWidgets('tap trigger toggles from the tap point', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_swap(trigger: PixelSwapTrigger.tap, onChanged: changes.add)),
      );
      await tester.tapAt(_bottomRight);
      await tester.pump();
      expect(changes, <bool>[true]);
      expect(_wave(tester).origin, const Offset(199, 119));
      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 1.0);

      await tester.tapAt(_topLeft);
      await tester.pump();
      await tester.pump(_total);
      expect(changes, <bool>[true, false]);
      expect(_cell(tester, 0, 0), 0.0);
    });

    testWidgets('hover trigger toggles on touch taps only', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(_wrap(_swap(onChanged: changes.add)));
      await tester.tapAt(_topLeft);
      await tester.pump();
      expect(changes, <bool>[true]);
      await tester.pump(_total);
      await tester.tapAt(_topLeft);
      await tester.pump();
      expect(changes, <bool>[true, false]);
      await tester.pump(_total);
    });

    testWidgets('manual trigger ignores hover and taps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_swap(trigger: PixelSwapTrigger.manual)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      await tester.tapAt(_topLeft);
      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('controller shows, hides and toggles with an origin', (
      WidgetTester tester,
    ) async {
      final PixelSwapController controller = PixelSwapController();
      addTearDown(controller.dispose);
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_swap(controller: controller, onChanged: changes.add)),
      );

      controller.show(origin: const Offset(200, 120));
      expect(controller.isShowingSecond, isTrue);
      await tester.pump();
      expect(_wave(tester).origin, const Offset(200, 120));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_cell(tester, 9, 5), greaterThan(_cell(tester, 0, 0)));
      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 1.0);

      controller.toggle();
      expect(controller.isShowingSecond, isFalse);
      await tester.pump();
      expect(_wave(tester).origin, isNull);
      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 0.0);

      controller.toggle(origin: Offset.zero);
      await tester.pump();
      await tester.pump(_total);
      controller.hide();
      await tester.pump();
      await tester.pump(_total);
      expect(changes, <bool>[true, false, true, false]);

      // Hover changes are mirrored into the controller.
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      expect(controller.isShowingSecond, isTrue);
      await tester.pump(_total);
    });

    testWidgets('showSecond is declarative and does not call onChanged', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_swap(showSecond: true, onChanged: changes.add)),
      );
      expect(_cell(tester, 0, 0), 1.0);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(_wrap(_swap(onChanged: changes.add)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(_total);
      expect(_cell(tester, 0, 0), 0.0);
      expect(changes, isEmpty);
    });

    testWidgets('reduced motion swaps instantly', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_swap(onChanged: changes.add), reducedMotion: true),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      // One extra frame lets focus bookkeeping for the swapped child settle.
      await tester.pump();
      expect(changes, <bool>[true]);
      expect(_cell(tester, 9, 5), 1.0);
      expect(find.semantics.byLabel('Second'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump();
      expect(_cell(tester, 0, 0), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      handle.dispose();
    });

    testWidgets('enabled false ignores hover and swaps instantly', (
      WidgetTester tester,
    ) async {
      final PixelSwapController controller = PixelSwapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_swap(enabled: false, controller: controller)),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_topLeft);
      await tester.pump();
      expect(_cell(tester, 0, 0), 0.0);

      controller.show();
      await tester.pump();
      expect(_cell(tester, 0, 0), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('config changes mid-wave do not throw', (
      WidgetTester tester,
    ) async {
      final PixelSwapController controller = PixelSwapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_swap(controller: controller)));
      controller.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(
        _wrap(
          _swap(
            controller: controller,
            gridSize: 10,
            gap: 2,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_wave(tester).cols, 17);
      await tester.pump(const Duration(seconds: 1));
      expect(_wave(tester).isSettled, isTrue);
      expect(_cell(tester, 0, 0), 1.0);

      // Swapping the controller keeps working.
      final PixelSwapController other = PixelSwapController();
      addTearDown(other.dispose);
      await tester.pumpWidget(_wrap(_swap(controller: other)));
      expect(other.isShowingSecond, isTrue);
      other.hide();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_cell(tester, 0, 0), 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-wave does not throw', (
      WidgetTester tester,
    ) async {
      final PixelSwapController controller = PixelSwapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_swap(controller: controller, gap: 1)));
      controller.show(origin: const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.hide();
      await tester.pump(_total);
      expect(tester.takeException(), isNull);
    });
  });
}
