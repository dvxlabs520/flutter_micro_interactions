import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/hold_to_confirm.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  Widget body = Center(child: child);
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(home: Scaffold(body: body));
}

Future<TestGesture> _press(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.byType(HoldToConfirm)),
  );
  await tester.pump();
  return gesture;
}

void main() {
  group('HoldToConfirm', () {
    testWidgets('renders the label twice but announces it once', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(HoldToConfirm(onConfirmed: () {}, child: const Text('Hold'))),
      );
      // Normal copy plus the inverse copy clipped by the fill.
      expect(find.text('Hold'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Hold'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(HoldToConfirm)),
        isSemantics(label: 'Hold', isButton: true, hasTapAction: true),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      handle.dispose();
    });

    testWidgets('holding the full duration confirms exactly once', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            resetAfterConfirm: false,
            onConfirmed: () => confirmed++,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(confirmed, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(confirmed, 1);
      // Holding longer and releasing does not fire again.
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(confirmed, 1);

      // A confirmed button ignores further holds.
      final TestGesture again = await _press(tester);
      await tester.pump(const Duration(seconds: 2));
      await again.up();
      await tester.pumpAndSettle();
      expect(confirmed, 1);
    });

    testWidgets('releasing early drains back and does not confirm', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      double progress = 0.0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            onConfirmed: () => confirmed++,
            onProgress: (double value) => progress = value,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 750));
      expect(progress, closeTo(0.5, 0.02));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Draining, quickly.
      expect(progress, lessThan(0.5));
      expect(progress, greaterThan(0.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(progress, 0.0);
      expect(confirmed, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('onProgress grows monotonically to 1 while held', (
      WidgetTester tester,
    ) async {
      final List<double> values = <double>[];
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            resetAfterConfirm: false,
            onConfirmed: () {},
            onProgress: values.add,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      for (int i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      expect(values, isNotEmpty);
      for (int i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
      expect(values.last, 1.0);
    });

    testWidgets('keyboard activation confirms directly', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            resetAfterConfirm: false,
            onConfirmed: () => confirmed++,
            child: const Text('Hold'),
          ),
        ),
      );
      final Element element = tester.element(find.byType(HoldToConfirm));
      FocusScope.of(element).nextFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(confirmed, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(confirmed, 1);
    });

    testWidgets('semantic tap confirms directly', (WidgetTester tester) async {
      int confirmed = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            resetAfterConfirm: false,
            semanticLabel: 'Delete account',
            onConfirmed: () => confirmed++,
            child: const Text('Hold to delete'),
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(HoldToConfirm),
      );
      expect(node.label, contains('Delete account'));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      // Once confirmed, the tap action is gone.
      expect(
        tester.getSemantics(find.byType(HoldToConfirm)),
        isSemantics(hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('resets after confirm and can confirm again', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      double progress = 0.0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            onConfirmed: () => confirmed++,
            onProgress: (double value) => progress = value,
            confirmedChild: const Text('Done'),
            child: const Text('Hold'),
          ),
        ),
      );
      TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      expect(confirmed, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Done'), findsNWidgets(2));
      expect(progress, 1.0);

      // Past the reset delay, then the drain.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(progress, 0.0);
      expect(find.text('Hold'), findsNWidgets(2));

      gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      expect(confirmed, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('controller.reset reuses a button that does not auto reset', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      final HoldToConfirmController controller = HoldToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            controller: controller,
            resetAfterConfirm: false,
            onConfirmed: () => confirmed++,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      expect(controller.isConfirmed, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(controller.isConfirmed, isTrue);

      controller.reset();
      await tester.pumpAndSettle();
      expect(controller.isConfirmed, isFalse);
      final TestGesture again = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await again.up();
      expect(confirmed, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('disabled ignores holds, keys and semantic taps', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      double progress = 0.0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            enabled: false,
            onConfirmed: () => confirmed++,
            onProgress: (double value) => progress = value,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      expect(confirmed, 0);
      expect(progress, 0.0);
      expect(
        tester.getSemantics(find.byType(HoldToConfirm)),
        isSemantics(hasTapAction: false, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('disabling mid-hold cancels the fill', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      double progress = 0.0;
      Widget build(bool enabled) => _wrap(
        HoldToConfirm(
          enabled: enabled,
          onConfirmed: () => confirmed++,
          onProgress: (double value) => progress = value,
          child: const Text('Hold'),
        ),
      );
      await tester.pumpWidget(build(true));
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      expect(confirmed, 0);
      expect(progress, 0.0);
    });

    testWidgets('disposing mid-hold throws nothing', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            fillStyle: HoldFillStyle.liquid,
            onConfirmed: () => confirmed++,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pump();
      expect(confirmed, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing during the reset delay throws nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(HoldToConfirm(onConfirmed: () {}, child: const Text('Hold'))),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('liquid fill animates its wave while held', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            fillStyle: HoldFillStyle.liquid,
            resetAfterConfirm: false,
            onConfirmed: () => confirmed++,
            child: const Text('Hold'),
          ),
        ),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final Finder clip = find.byWidgetPredicate(
        (Widget widget) =>
            widget is ClipPath && widget.clipper is! ShapeBorderClipper,
      );
      final RenderClipPath render = tester.renderObject(clip);
      final Size size = render.size;
      final Path first = tester.widget<ClipPath>(clip).clipper!.getClip(size);
      await tester.pump(const Duration(milliseconds: 300));
      final Path second = tester.widget<ClipPath>(clip).clipper!.getClip(size);
      expect(first.getBounds(), isNot(second.getBounds()));
      await tester.pump(const Duration(milliseconds: 900));
      expect(confirmed, 1);
      await gesture.up();
      // Full: the wave stops.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('horizontal fill grows from the start edge', (
      WidgetTester tester,
    ) async {
      Future<Rect> boundsAfterHalf(TextDirection direction) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: HoldToConfirm(
                    onConfirmed: () {},
                    child: const Text('Hold'),
                  ),
                ),
              ),
            ),
          ),
        );
        final TestGesture gesture = await _press(tester);
        await tester.pump(const Duration(milliseconds: 750));
        final Finder clip = find.byWidgetPredicate(
          (Widget widget) =>
              widget is ClipPath && widget.clipper is! ShapeBorderClipper,
        );
        final Size size = tester.renderObject<RenderBox>(clip).size;
        final Rect bounds = tester
            .widget<ClipPath>(clip)
            .clipper!
            .getClip(size)
            .getBounds();
        await gesture.up();
        await tester.pumpAndSettle();
        return bounds;
      }

      final Rect ltr = await boundsAfterHalf(TextDirection.ltr);
      expect(ltr.left, 0.0);
      expect(ltr.width, closeTo(100.0, 3.0));
      final Rect rtl = await boundsAfterHalf(TextDirection.rtl);
      expect(rtl.right, closeTo(200.0, 0.01));
      expect(rtl.width, closeTo(100.0, 3.0));
    });

    testWidgets('reduced motion: hold still takes the full duration', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      double progress = 0.0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirm(
            fillStyle: HoldFillStyle.liquid,
            onConfirmed: () => confirmed++,
            onProgress: (double value) => progress = value,
            child: const Text('Hold'),
          ),
          reducedMotion: true,
        ),
      );
      TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(confirmed, 0);
      expect(progress, closeTo(2 / 3, 0.02));
      // Early release jumps back instantly.
      await gesture.up();
      await tester.pump();
      expect(progress, 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(confirmed, 1);
      await gesture.up();
      // The reset jumps instantly too.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      expect(progress, 0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('config changes mid-hold do not throw', (
      WidgetTester tester,
    ) async {
      int confirmed = 0;
      Widget build(Duration hold, HoldFillStyle style) => _wrap(
        HoldToConfirm(
          holdDuration: hold,
          fillStyle: style,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          onConfirmed: () => confirmed++,
          child: const Text('Hold'),
        ),
      );
      await tester.pumpWidget(
        build(const Duration(milliseconds: 1500), HoldFillStyle.horizontal),
      );
      final TestGesture gesture = await _press(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(
        build(const Duration(milliseconds: 600), HoldFillStyle.liquid),
      );
      // Remaining two thirds at the new pace: 400 milliseconds.
      await tester.pump(const Duration(milliseconds: 450));
      expect(confirmed, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
