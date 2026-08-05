import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/animated_check.dart';
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

void main() {
  group('AnimatedCheck', () {
    testWidgets('renders a CustomPaint of the requested size',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCheck(size: 64)));
      final Finder paint = find.descendant(
        of: find.byType(AnimatedCheck),
        matching: find.byType(CustomPaint),
      );
      expect(paint, findsOneWidget);
      expect(tester.getSize(paint), const Size(64, 64));
    });

    testWidgets('autoPlay completes and fires onCompleted exactly once',
        (WidgetTester tester) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(AnimatedCheck(onCompleted: () => completed++)),
      );
      // First frame after the ticker starts has elapsed zero.
      await tester.pump();
      // Mid-animation: not yet complete.
      await tester.pump(const Duration(milliseconds: 350));
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, 1);
      // Extra frames must not re-fire.
      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, 1);
    });

    testWidgets('autoPlay false stays blank until controller.play',
        (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController controller = AnimatedCheckController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            autoPlay: false,
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 0);
      expect(controller.isComplete, isFalse);

      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 1);
      expect(controller.isComplete, isTrue);
    });

    testWidgets('controller.reset clears and play replays',
        (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController controller = AnimatedCheckController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 1);
      expect(controller.isComplete, isTrue);

      controller.reset();
      await tester.pump();
      expect(controller.isComplete, isFalse);

      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 2);
      expect(controller.isComplete, isTrue);
    });

    testWidgets('type switch resets and replays', (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController controller = AnimatedCheckController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 1);

      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            type: AnimatedCheckType.cross,
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      // Immediately after the switch the mark is reset.
      expect(controller.isComplete, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 2);
      expect(controller.isComplete, isTrue);
    });

    testWidgets('type switch mid-animation restarts cleanly',
        (WidgetTester tester) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(AnimatedCheck(onCompleted: () => completed++)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            type: AnimatedCheckType.cross,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion completes instantly and fires onCompleted',
        (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController controller = AnimatedCheckController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            controller: controller,
            onCompleted: () => completed++,
          ),
          reducedMotion: true,
        ),
      );
      // The play is deferred one frame; no animation time is needed.
      await tester.pump();
      expect(completed, 1);
      expect(controller.isComplete, isTrue);

      // Replaying under reduced motion fires again, still without frames.
      controller.play();
      await tester.pump();
      expect(completed, 2);
    });

    testWidgets('disposal mid-animation throws nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCheck()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false renders statically and ignores commands',
        (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController controller = AnimatedCheckController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            enabled: false,
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 0);
      controller.play();
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 0);
      expect(controller.isComplete, isFalse);
    });

    testWidgets('exposes the semantic label once complete',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const AnimatedCheck()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Success'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.bySemanticsLabel('Success'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('cross defaults to the Error label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const AnimatedCheck(type: AnimatedCheckType.cross)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.bySemanticsLabel('Error'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('didUpdateWidget applies duration, curve and controller swap',
        (WidgetTester tester) async {
      int completed = 0;
      final AnimatedCheckController first = AnimatedCheckController();
      final AnimatedCheckController second = AnimatedCheckController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            autoPlay: false,
            controller: first,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          AnimatedCheck(
            autoPlay: false,
            controller: second,
            duration: const Duration(milliseconds: 300),
            curve: Curves.linear,
            onCompleted: () => completed++,
          ),
        ),
      );
      // The detached controller is ignored.
      first.play();
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 0);

      second.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(completed, 1);
      expect(second.isComplete, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
