import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() {
  return const MaterialApp(home: Scaffold(body: Text('Home')));
}

void main() {
  group('ToastNotification', () {
    testWidgets('show displays the toast and it auto-dismisses', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Saved!',
        duration: const Duration(seconds: 1),
        onDismiss: () => dismissed = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Saved!'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('close button removes the toast early', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Closable',
        onDismiss: () => dismissed = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Closable'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Closable'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('action button runs onAction and dismisses', (
      WidgetTester tester,
    ) async {
      bool acted = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Deleted',
        actionLabel: 'Undo',
        onAction: () => acted = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(acted, isTrue);
      expect(find.text('Deleted'), findsNothing);
    });

    testWidgets('dismissOnTap closes the toast when its body is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Tap me away',
        dismissOnTap: true,
        showCloseButton: false,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Tap me away'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Tap me away'), findsNothing);
    });

    testWidgets('announces the message to assistive technology', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Announced',
        duration: const Duration(milliseconds: 100),
      );
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Announced'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });
  });

  group('context.showToast', () {
    testWidgets('extension shows a toast', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      tester
          .element(find.text('Home'))
          .showToast(message: 'Via extension', type: ToastType.success);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Via extension'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Let it dismiss itself so no timers leak into the next test.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Via extension'), findsNothing);
    });
  });

  group('stacking and reduced motion', () {
    testWidgets('two toasts stack at different offsets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      final BuildContext context = tester.element(find.text('Home'));
      context.showToast(
        message: 'First',
        duration: const Duration(milliseconds: 500),
      );
      context.showToast(
        message: 'Second',
        duration: const Duration(milliseconds: 500),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      final double firstTop = tester.getTopLeft(find.text('First')).dy;
      final double secondTop = tester.getTopLeft(find.text('Second')).dy;
      expect(secondTop, greaterThan(firstTop));

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('reduced motion shows and hides instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      tester
          .element(find.text('Home'))
          .showToast(
            message: 'Instant',
            duration: const Duration(milliseconds: 200),
          );

      await tester.pump();
      expect(find.text('Instant'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('Instant'), findsNothing);
    });
  });
  group('swipe to dismiss', () {
    Future<void> showAndSettle(
      WidgetTester tester, {
      ToastPosition position = ToastPosition.top,
      bool swipeToDismiss = true,
      VoidCallback? onDismiss,
    }) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Swipe me',
        position: position,
        duration: Duration.zero,
        swipeToDismiss: swipeToDismiss,
        onDismiss: onDismiss,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('horizontal swipe past the threshold dismisses', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;
      await showAndSettle(tester, onDismiss: () => dismissed = true);
      await tester.drag(find.text('Swipe me'), const Offset(400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Swipe me'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('short slow swipe springs back', (WidgetTester tester) async {
      await showAndSettle(tester);
      final double before = tester.getTopLeft(find.text('Swipe me')).dx;
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe me')),
      );
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(find.text('Swipe me')).dx, greaterThan(before));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Swipe me')).dx, before);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('a fast short fling dismisses', (WidgetTester tester) async {
      await showAndSettle(tester);
      await tester.fling(find.text('Swipe me'), const Offset(-60, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
    });

    testWidgets('vertical swipe only dismisses towards the edge', (
      WidgetTester tester,
    ) async {
      await showAndSettle(tester, position: ToastPosition.bottom);
      // Up, away from the bottom edge: clamped, nothing happens.
      await tester.fling(find.text('Swipe me'), const Offset(0, -80), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsOneWidget);
      // Down, towards the bottom edge: dismissed.
      await tester.fling(find.text('Swipe me'), const Offset(0, 80), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
    });

    testWidgets('swipeToDismiss false ignores swipes', (
      WidgetTester tester,
    ) async {
      await showAndSettle(tester, swipeToDismiss: false);
      await tester.fling(find.text('Swipe me'), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('semantic dismiss action closes the toast', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await showAndSettle(tester);
      final SemanticsNode node = tester.getSemantics(
        find.ancestor(
          of: find.text('Swipe me'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.dismiss),
        isTrue,
      );
      node.owner!.performAction(node.id, SemanticsAction.dismiss);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
      handle.dispose();
    });

    testWidgets('reduced motion removes a swiped toast instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      tester
          .element(find.text('Home'))
          .showToast(message: 'Swipe me', duration: Duration.zero);
      await tester.pump();
      await tester.drag(find.text('Swipe me'), const Offset(400, 0));
      await tester.pump();
      expect(find.text('Swipe me'), findsNothing);
    });
  });

  group('progress fuse and pause', () {
    CustomPaint? fusePaint(WidgetTester tester) {
      final Finder finder = find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_FusePainter',
      );
      if (finder.evaluate().isEmpty) {
        return null;
      }
      return tester.widget<CustomPaint>(finder);
    }

    testWidgets('showProgress draws a shrinking fuse and dismisses', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Fuse',
        duration: const Duration(seconds: 2),
        showProgress: true,
      );
      await tester.pump();
      final CustomPaint? paint = fusePaint(tester);
      expect(paint, isNotNull);
      final Animation<double> progress =
          (paint!.painter! as dynamic).progress as Animation<double>;
      await tester.pump(const Duration(seconds: 1));
      expect(progress.value, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('Fuse'), findsNothing);
    });

    testWidgets('no fuse by default', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Plain',
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(fusePaint(tester), isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('pressing pauses the fuse and the countdown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Hold',
        duration: const Duration(seconds: 1),
        showProgress: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final Animation<double> progress =
          (fusePaint(tester)!.painter! as dynamic).progress
              as Animation<double>;
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Hold')),
      );
      final double paused = progress.value;
      await tester.pump(const Duration(seconds: 3));
      expect(progress.value, paused);
      expect(find.text('Hold'), findsOneWidget);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hold'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Hold'), findsNothing);
    });

    testWidgets('mouse hover pauses the timer-based countdown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Hover',
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump();
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Hover'), findsOneWidget);

      await mouse.moveTo(const Offset(1, 500));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Hover'), findsNothing);
    });

    testWidgets('pauseOnHover false keeps counting while pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'No pause',
        duration: const Duration(milliseconds: 500),
        pauseOnHover: false,
        swipeToDismiss: false,
      );
      await tester.pump();
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('No pause')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('No pause'), findsNothing);
      await gesture.up();
    });

    testWidgets('reduced motion hides the fuse but still auto-dismisses', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      tester
          .element(find.text('Home'))
          .showToast(
            message: 'Reduced fuse',
            duration: const Duration(milliseconds: 300),
            showProgress: true,
          );
      await tester.pump();
      expect(find.text('Reduced fuse'), findsOneWidget);
      expect(fusePaint(tester), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Reduced fuse'), findsNothing);
    });
  });
}
