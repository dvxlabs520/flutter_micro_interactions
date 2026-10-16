import 'dart:async';

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
  Widget body = Center(child: SizedBox(width: 300, child: child));
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

/// Pumps enough frames for the settle animations to finish without waiting
/// for an indefinite progress indicator to stop.
Future<void> _settleFrames(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The target opacity of the confirmed child (the default check icon).
double _confirmedOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.check),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;
}

void main() {
  group('SlideToConfirm', () {
    testWidgets('renders track, label and thumb', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(SlideToConfirm(onConfirmed: () {})));
      expect(find.text('Slide to confirm'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('drag below threshold springs back and does not confirm', (
      WidgetTester tester,
    ) async {
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

    testWidgets('drag past threshold confirms exactly once', (
      WidgetTester tester,
    ) async {
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

    testWidgets('controller.reset restores and allows confirming again', (
      WidgetTester tester,
    ) async {
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

    testWidgets('resetAfterConfirm springs back after resetDelay', (
      WidgetTester tester,
    ) async {
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
      final SemanticsNode node = tester.getSemantics(
        find.byType(SlideToConfirm),
      );
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

    testWidgets('keyboard focus plus activation key confirms', (
      WidgetTester tester,
    ) async {
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

    testWidgets('enabled false ignores drags and disables semantics', (
      WidgetTester tester,
    ) async {
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

      final SemanticsNode node = tester.getSemantics(
        find.byType(SlideToConfirm),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('RTL confirms dragging towards the start edge', (
      WidgetTester tester,
    ) async {
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

    testWidgets('RTL does not confirm dragging the LTR direction', (
      WidgetTester tester,
    ) async {
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

    testWidgets('disposal mid-drag throws nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SlideToConfirm(onConfirmed: () {})));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SlideToConfirm)),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-spring throws nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(SlideToConfirm(onConfirmed: () {})));
      await tester.drag(find.byType(SlideToConfirm), const Offset(80, 0));
      // Part-way through the spring back.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion still confirms and settles instantly', (
      WidgetTester tester,
    ) async {
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

    testWidgets('didUpdateWidget swaps controllers and disables mid-state', (
      WidgetTester tester,
    ) async {
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

  group('SlideToConfirm onConfirmAsync', () {
    testWidgets('a Future-returning onConfirmed does not enter loading', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      int calls = 0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            // Like `() => Navigator.pushNamed(...)`: the Future is ignored.
            onConfirmed: () {
              calls++;
              completer.future;
            },
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(controller.isLoading, isFalse);
      expect(controller.isConfirmed, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_confirmedOpacity(tester), 1.0);
    });

    testWidgets('a tear-off returning a Future does not enter loading', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      Future<void> pending() => completer.future;
      await tester.pumpWidget(
        _wrap(SlideToConfirm(controller: controller, onConfirmed: pending)),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(controller.isLoading, isFalse);
      expect(controller.isConfirmed, isTrue);
    });

    testWidgets('both callbacks: onConfirmed fires first, then loading', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final List<String> log = <String>[];
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmed: () => log.add('sync'),
            onConfirmAsync: () {
              log.add('async');
              return completer.future;
            },
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      expect(log, <String>['sync', 'async']);
      expect(controller.isLoading, isTrue);
      completer.complete();
      await _settleFrames(tester);
      expect(controller.isConfirmed, isTrue);
      expect(log, <String>['sync', 'async']);
    });

    testWidgets('a synchronous throw in onConfirmAsync goes to onError', (
      WidgetTester tester,
    ) async {
      Object? reported;
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmAsync: () => throw StateError('sync'),
            onError: (Object error, StackTrace stackTrace) => reported = error,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      expect(reported, isA<StateError>());
      expect(controller.isLoading, isFalse);
      expect(controller.isConfirmed, isFalse);
    });

    test('asserts that a confirm callback is provided', () {
      expect(() => SlideToConfirm(), throwsAssertionError);
    });
    testWidgets('shows loading while pending, then confirmed', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      int loadingNotifications = 0;
      controller.addListener(() => loadingNotifications++);
      int calls = 0;
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmAsync: () {
              calls++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(controller.isLoading, isTrue);
      expect(controller.isConfirmed, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.takeAnnouncements().map((dynamic a) => a.message),
        contains('Loading'),
      );

      // Locked: further drags do not re-fire.
      await tester.drag(find.byType(SlideToConfirm), const Offset(-280, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(controller.isLoading, isTrue);

      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isLoading, isFalse);
      expect(controller.isConfirmed, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_confirmedOpacity(tester), 1.0);
      expect(loadingNotifications, greaterThanOrEqualTo(2));
    });

    testWidgets('custom loadingChild and loadingSemanticLabel', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            loadingChild: const Text('wait'),
            loadingSemanticLabel: 'Procesando',
            onConfirmAsync: () => completer.future,
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SlideToConfirm),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('wait'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final SemanticsData data = tester
          .getSemantics(find.byType(SlideToConfirm))
          .getSemanticsData();
      // Announced once; no changing semantics value.
      final List<String> announcements = tester
          .takeAnnouncements()
          .map((dynamic a) => a.message as String)
          .toList();
      expect(
        announcements.where((String m) => m == 'Procesando'),
        hasLength(1),
      );
      expect(data.value, isEmpty);
      expect(data.hasAction(SemanticsAction.tap), isFalse);

      completer.complete();
      await _settleFrames(tester);
      expect(find.text('wait'), findsNothing);
      handle.dispose();
    });

    testWidgets('error springs back, calls onError and allows retry', (
      WidgetTester tester,
    ) async {
      Completer<void> completer = Completer<void>();
      Object? reported;
      double lastProgress = 0.0;
      int calls = 0;
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmAsync: () {
              calls++;
              return completer.future;
            },
            onError: (Object error, StackTrace stackTrace) => reported = error,
            onProgress: (double value) => lastProgress = value,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      expect(controller.isLoading, isTrue);

      completer.completeError(StateError('declined'));
      await _settleFrames(tester);
      expect(reported, isA<StateError>());
      expect(controller.isLoading, isFalse);
      expect(controller.isConfirmed, isFalse);
      expect(lastProgress, 0.0);
      expect(tester.takeException(), isNull);

      completer = Completer<void>();
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      expect(calls, 2);
      completer.complete();
      await _settleFrames(tester);
      expect(controller.isConfirmed, isTrue);
    });

    testWidgets('error without onError is reported, not swallowed', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmAsync: () => completer.future)),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      completer.completeError(StateError('boom'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      await _settleFrames(tester);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('resetAfterConfirm waits for the future', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            resetAfterConfirm: true,
            resetDelay: const Duration(milliseconds: 500),
            onConfirmAsync: () => completer.future,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.isLoading, isTrue);
      completer.complete();
      await tester.pump();
      expect(controller.isConfirmed, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await _settleFrames(tester);
      expect(controller.isConfirmed, isFalse);
    });

    testWidgets('controller.reset while loading returns to idle', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      final SlideToConfirmController controller = SlideToConfirmController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(
            controller: controller,
            onConfirmAsync: () => completer.future,
          ),
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await _settleFrames(tester);
      expect(controller.isLoading, isTrue);
      controller.reset();
      await _settleFrames(tester);
      expect(controller.isLoading, isFalse);
      // A late completion is ignored.
      completer.complete();
      await _settleFrames(tester);
      expect(controller.isConfirmed, isFalse);
      expect(_confirmedOpacity(tester), 0.0);
    });

    testWidgets('reduced motion shows a static loading indicator', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          SlideToConfirm(onConfirmAsync: () => completer.future),
          reducedMotion: true,
        ),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_top), findsNothing);
    });

    testWidgets('disposing while loading throws nothing', (
      WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();
      await tester.pumpWidget(
        _wrap(SlideToConfirm(onConfirmAsync: () => completer.future)),
      );
      await tester.drag(find.byType(SlideToConfirm), const Offset(280, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      completer.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
