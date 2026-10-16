import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/depth_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Cards are 260 x 340 on the 800 x 600 test screen; the front card spans
/// x 270..530, and the first right neighbor shows between x 530 and ~630.
Widget _carousel({
  int count = 5,
  int initialIndex = 0,
  DepthCarouselController? controller,
  ValueChanged<int>? onIndexChanged,
  bool loop = false,
  bool autoPlay = false,
  Duration interval = const Duration(seconds: 1),
  bool enabled = true,
  Axis axis = Axis.horizontal,
  double depthBlur = 0,
  VoidCallback? onFrontPressed,
}) {
  return DepthCarousel.builder(
    itemCount: count,
    initialIndex: initialIndex,
    controller: controller,
    onIndexChanged: onIndexChanged,
    loop: loop,
    autoPlay: autoPlay,
    interval: interval,
    enabled: enabled,
    axis: axis,
    depthBlur: depthBlur,
    itemBuilder: (BuildContext context, int index) {
      return ColoredBox(
        color: Colors.primaries[index % Colors.primaries.length],
        child: Center(
          child: TextButton(
            onPressed: onFrontPressed,
            child: Text('Card $index'),
          ),
        ),
      );
    },
  );
}

const Offset _center = Offset(400, 300);

void main() {
  group('DepthCarousel', () {
    testWidgets('builds only the cards within reach of the front', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_carousel(count: 10, initialIndex: 4)));
      for (int i = 2; i <= 6; i++) {
        expect(find.text('Card $i'), findsOneWidget);
      }
      expect(find.text('Card 1'), findsNothing);
      expect(find.text('Card 7'), findsNothing);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('front card paints last and side cards recede', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_carousel(initialIndex: 2)));
      final List<Transform> transforms = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(DepthCarousel),
              matching: find.byWidgetPredicate(
                (Widget w) => w is Transform && w.key is ValueKey<int>,
              ),
            ),
          )
          .toList();
      expect(transforms, hasLength(5));
      expect((transforms.last.key! as ValueKey<int>).value, 2);
      expect(transforms.last.transform, isNot(Matrix4.identity()));
      // The front card is the largest on screen.
      final Size front = tester.getSize(find.text('Card 2'));
      expect(front, isNot(Size.zero));
      final Rect frontRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Card 2'),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final Rect sideRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Card 3'),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(frontRect.center.dx, closeTo(400, 0.5));
      expect(sideRect.center.dx, greaterThan(frontRect.center.dx));
    });

    testWidgets('a slow drag left advances one card and snaps', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      await tester.timedDragFrom(
        _center,
        const Offset(-90, 0),
        const Duration(seconds: 1),
      );
      expect(controller.page, greaterThan(0.5));
      expect(controller.page, lessThan(1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(controller.page, 1.0);
      expect(controller.index, 1);
    });

    testWidgets('a short slow drag springs back', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, initialIndex: 2)),
      );
      await tester.timedDragFrom(
        _center,
        const Offset(-30, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.page, 2.0);
    });

    testWidgets('a fling keeps momentum across several cards', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, count: 10)),
      );
      await tester.flingFrom(_center, const Offset(-120, 0), 2500);
      await tester.pumpAndSettle();
      expect(controller.index, greaterThanOrEqualTo(2));
      expect(controller.page, controller.index.toDouble());
    });

    testWidgets('dragging past the first card resists and returns', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      final TestGesture gesture = await tester.startGesture(_center);
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      // Without resistance this would be about -1.3 pages.
      expect(controller.page, lessThan(0));
      expect(controller.page, greaterThan(-0.6));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.page, 0.0);
    });

    testWidgets('tapping a side card brings it to the front', (
      WidgetTester tester,
    ) async {
      int frontTaps = 0;
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _carousel(controller: controller, onFrontPressed: () => frontTaps++),
        ),
      );
      await tester.tapAt(const Offset(600, 300));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(frontTaps, 0, reason: 'side card content must not get taps');

      // The front card content stays interactive.
      await tester.tap(find.text('Card 1'));
      await tester.pumpAndSettle();
      expect(frontTaps, 1);
      expect(controller.index, 1);
    });

    testWidgets('controller animateTo, next, previous and jumpTo', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      expect(controller.hasClients, isFalse);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      expect(controller.hasClients, isTrue);

      bool done = false;
      controller.animateTo(3).then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.page, greaterThan(0));
      expect(controller.page, lessThan(3));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(controller.index, 3);

      controller.next();
      controller.next(); // Queued: clamps at the last card.
      await tester.pumpAndSettle();
      expect(controller.index, 4);

      controller.previous();
      await tester.pumpAndSettle();
      expect(controller.index, 3);

      controller.jumpTo(0);
      expect(controller.page, 0.0);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('onIndexChanged fires once per card change', (
      WidgetTester tester,
    ) async {
      final List<int> changes = <int>[];
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, onIndexChanged: changes.add)),
      );
      controller.animateTo(2);
      await tester.pumpAndSettle();
      expect(changes, <int>[1, 2]);
    });

    testWidgets('loop wraps around both ends', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, loop: true)),
      );
      // The last card already waits on the left.
      expect(find.text('Card 4'), findsOneWidget);
      controller.previous();
      await tester.pumpAndSettle();
      expect(controller.index, 4);
      expect(controller.page, 4.0);
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      // Shortest path: from 0 to 4 goes one step back.
      controller.animateTo(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.page, greaterThan(3.9));
      await tester.pumpAndSettle();
      expect(controller.index, 4);
    });

    testWidgets('loop works with fewer cards than visible slots', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_carousel(count: 2, loop: true)));
      expect(tester.takeException(), isNull);
      expect(find.text('Card 0'), findsWidgets);
    });

    testWidgets('autoplay advances and pauses while dragging', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, autoPlay: true)),
      );
      await tester.pump(const Duration(milliseconds: 1001));
      await tester.pumpAndSettle();
      expect(controller.index, 1);

      final TestGesture gesture = await tester.startGesture(_center);
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
      final double held = controller.page;
      await tester.pump(const Duration(seconds: 3));
      expect(controller.page, held);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.index, 1);

      // Resumes after release.
      await tester.pump(const Duration(milliseconds: 1001));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('autoplay rewinds at the end without loop', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _carousel(
            controller: controller,
            count: 2,
            initialIndex: 1,
            autoPlay: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1001));
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('autoplay pauses on hover', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, autoPlay: true)),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: _center);
      addTearDown(mouse.removePointer);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 1001));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('arrow keys move the rail when focused', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      final Focus focus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(DepthCarousel),
              matching: find.byType(Focus),
            )
            .first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.index, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('vertical axis uses up and down', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 600,
            child: _carousel(controller: controller, axis: Axis.vertical),
          ),
        ),
      );
      await tester.timedDragFrom(
        _center,
        const Offset(0, -100),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      final Focus focus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(DepthCarousel),
              matching: find.byType(Focus),
            )
            .first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('mouse wheel steps through cards', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(_center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(60, 0)));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      // Vertical wheel over a horizontal rail is left alone.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    });

    testWidgets('semantics expose value and actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));

      SemanticsNode node = tester.getSemantics(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.value != null,
        ),
      );
      expect(node.value, 'Item 1 of 5');
      expect(node.increasedValue, 'Item 2 of 5');
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), true);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        false,
      );

      // Neighbors are reachable; far cards are hidden from assistive tech.
      expect(find.bySemanticsLabel('Card 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Card 2'), findsNothing);

      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      node = tester.getSemantics(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.value != null,
        ),
      );
      expect(node.value, 'Item 2 of 5');
      expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), true);
      handle.dispose();
    });

    testWidgets('reduced motion snaps without spring frames', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _carousel(controller: controller, autoPlay: true),
          reducedMotion: true,
        ),
      );
      controller.next();
      expect(controller.page, 1.0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);

      // Drag still follows the finger, then lands immediately.
      final TestGesture gesture = await tester.startGesture(_center);
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(controller.page, greaterThan(1));
      await gesture.up();
      expect(controller.page, controller.page.roundToDouble());
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);

      // Autoplay is off under reduced motion.
      final int index = controller.index;
      await tester.pump(const Duration(seconds: 5));
      expect(controller.index, index);
    });

    testWidgets('enabled false ignores input', (WidgetTester tester) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, enabled: false)),
      );
      await tester.timedDragFrom(
        _center,
        const Offset(-150, 0),
        const Duration(milliseconds: 500),
      );
      await tester.tapAt(const Offset(600, 300));
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.page, 0.0);
    });

    testWidgets('optional depth blur renders', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_carousel(depthBlur: 1.5)));
      expect(find.byType(ImageFiltered), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      final DepthCarouselController other = DepthCarouselController();
      addTearDown(controller.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(_wrap(_carousel(controller: controller)));
      controller.animateTo(4);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(
        _wrap(_carousel(controller: other, count: 3, loop: true)),
      );
      expect(controller.hasClients, isFalse);
      expect(other.hasClients, isTrue);
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrap(_carousel(controller: other, count: 2)));
      await tester.pumpAndSettle();
      expect(other.index, lessThan(2));
      await tester.pumpWidget(_wrap(_carousel(controller: other, count: 0)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      final DepthCarouselController controller = DepthCarouselController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(_carousel(controller: controller, autoPlay: true)),
      );
      controller.animateTo(3);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(controller.hasClients, isFalse);
      // Commands without a carousel are ignored.
      await controller.next();
      expect(tester.takeException(), isNull);
    });

    testWidgets('children constructor works', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          DepthCarousel(
            children: <Widget>[for (int i = 0; i < 3; i++) Text('Plain $i')],
          ),
        ),
      );
      expect(find.text('Plain 0'), findsOneWidget);
      expect(find.text('Plain 2'), findsOneWidget);
    });
  });
}
