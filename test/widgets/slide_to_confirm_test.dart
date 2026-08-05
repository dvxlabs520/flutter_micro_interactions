import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/slide_to_confirm.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
}) {
  Widget body = Center(
    child: SizedBox(width: 300, child: child),
  );
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: body),
    ),
  );
}

void main() {
  group('SlideToConfirm', () {
    testWidgets('renders track, label and thumb', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmed: () {})),
      );
      expect(find.text('Slide to confirm'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('drag below threshold springs back and does not confirm',
        (WidgetTester tester) async {
      int confirmed = 0;
      double lastProgress = 0.0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            onConfirmed: () => confirmed++,
            onProgress: (double value) => lastProgress = value,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(80, 0));
      expect(lastProgress, greaterThan(0.0));
      // Let the spring-back finish.
      await tester.pumpAndSettle();
      expect(confirmed, 0);
      expect(lastProgress, 0.0);
    });

    testWidgets('drag past threshold confirms exactly once',
        (WidgetTester tester) async {
      int confirmed = 0;
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmed: () => confirmed++,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(controller.isConfirmed, isTrue);

      // Extra drags after confirmation must not re-fire.
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SlideToConfirm), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
    });

    testWidgets('controller.reset restores and allows confirming again',
        (WidgetTester tester) async {
      int confirmed = 0;
      double lastProgress = 1.0;
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmed: () => confirmed++,
            onProgress: (double value) => lastProgress = value,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 1);

      controller.reset();
      await tester.pumpAndSettle();
      expect(controller.isConfirmed, isFalse);
      expect(lastProgress, 0.0);

      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 2);
    });

    testWidgets('resetAfterConfirm springs back after resetDelay',
        (WidgetTester tester) async {
      int confirmed = 0;
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            resetAfterConfirm: true,
            resetDelay: const Duration(seconds: 2),
            onConfirmed: () => confirmed++,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      // Let the settle and cross-fade animations finish, before the delay.
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.isConfirmed, isTrue);
      // Pass the reset delay, then let the spring-back finish.
      await tester.pump(const Duration(seconds: 2));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.isConfirmed, isFalse);
      expect(confirmed, 1);
    });

    testWidgets('semantic tap confirms directly', (WidgetTester tester) async {
      int confirmed = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmed: () => confirmed++)),
      );
      final SemanticsNode node =
          tester.getSemantics(find.byType(SlideToConfirm));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(confirmed, 1);

      // A second semantic tap must not re-fire.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      handle.dispose();
    });

    testWidgets('keyboard focus plus activation key confirms',
        (WidgetTester tester) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmed: () => confirmed++)),
      );
      final Element element = tester.element(find.byType(SlideToConfirm));
      FocusScope.of(element).nextFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(confirmed, 1);

      // Pressing again after confirmation must not re-fire.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(confirmed, 1);
    });

    testWidgets('enabled false ignores drags and disables semantics',
        (WidgetTester tester) async {
      int confirmed = 0;
      double lastProgress = 0.0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            enabled: false,
            onConfirmed: () => confirmed++,
            onProgress: (double value) => lastProgress = value,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump();
      expect(confirmed, 0);
      expect(lastProgress, 0.0);

      final SemanticsNode node =
          tester.getSemantics(find.byType(SlideToConfirm));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('RTL confirms dragging towards the start edge',
        (WidgetTester tester) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(onConfirmed: () => confirmed++),
          direction: TextDirection.rtl,
        ),
      );
      // In RTL the thumb travels right-to-left on screen.
      await tester.drag(find.byType(SlideToConfirm), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
    });

    testWidgets('RTL does not confirm dragging the LTR direction',
        (WidgetTester tester) async {
      int confirmed = 0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(onConfirmed: () => confirmed++),
          direction: TextDirection.rtl,
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(confirmed, 0);
    });

    testWidgets('disposal mid-drag throws nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmed: () {})),
      );
      final TestGesture gesture = await tester
          .startGesture(tester.getCenter(find.byType(SlideToConfirm)));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-spring throws nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmed: () {})),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(80, 0));
      // Part-way through the spring back.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion still confirms and settles instantly',
        (WidgetTester tester) async {
      int confirmed = 0;
      double lastProgress = 0.0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            onConfirmed: () => confirmed++,
            onProgress: (double value) => lastProgress = value,
          ),
          reducedMotion: true,
        ),
      );
      // Below threshold: snaps back instantly, no animation frames needed.
      await tester.drag(find.byType(SlideToConfirm), const Offset(80, 0));
      await tester.pump();
      expect(lastProgress, 0.0);
      expect(confirmed, 0);

      // Past threshold: confirms, thumb jumps to the end instantly.
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump();
      expect(confirmed, 1);
      expect(lastProgress, 1.0);
    });

    testWidgets('didUpdateWidget swaps controllers and disables mid-state',
        (WidgetTester tester) async {
      int confirmed = 0;
      final SlideToConfirmController first = SlideToConfirmController();
      final SlideToConfirmController second = SlideToConfirmController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(controller: first, onConfirmed: () => confirmed++),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(controller: second, onConfirmed: () => confirmed++),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(second.isConfirmed, isTrue);
      // The detached controller can no longer reset the widget.
      first.reset();
      await tester.pumpAndSettle();
      expect(second.isConfirmed, isTrue);
      expect(confirmed, 1);

      // Disabling after confirmation keeps the confirmed state.
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: second,
            enabled: false,
            onConfirmed: () => confirmed++,
          ),
        ),
      );
      await tester.pump();
      expect(second.isConfirmed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
