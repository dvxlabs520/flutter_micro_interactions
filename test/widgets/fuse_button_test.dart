import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/fuse_button.dart';
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

/// Records every callback of a [FuseButton].
class _Log {
  int pressed = 0;
  int committed = 0;
  int undone = 0;
}

FuseButton _button(
  _Log log, {
  Duration undoWindow = const Duration(seconds: 5),
  bool resetAfterCommit = false,
  bool pauseOnHover = true,
  bool enabled = true,
  bool enableHaptics = true,
  FuseTrack track = FuseTrack.border,
}) {
  return FuseButton(
    onPressed: () => log.pressed++,
    onCommit: () => log.committed++,
    onUndo: () => log.undone++,
    undoWindow: undoWindow,
    resetAfterCommit: resetAfterCommit,
    pauseOnHover: pauseOnHover,
    enabled: enabled,
    enableHaptics: enableHaptics,
    track: track,
    doneChild: const Text('Deleted'),
    child: const Text('Delete'),
  );
}

/// The fuse painter, read dynamically since its type is private.
dynamic _fusePainter(WidgetTester tester) {
  final Iterable<CustomPaint> paints = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(FuseButton),
          matching: find.byType(CustomPaint),
        ),
      )
      .where(
        (CustomPaint p) => p.painter.runtimeType.toString() == '_FusePainter',
      );
  return paints.isEmpty ? null : paints.first.painter;
}

/// Pumps [total] in steps so animations advance like real frames.
Future<void> _advance(WidgetTester tester, Duration total) async {
  const Duration step = Duration(milliseconds: 100);
  Duration elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  group('FuseButton', () {
    testWidgets('renders its child with a 48 pixel tall target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_button(_Log())));
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(
        tester.getSize(find.byType(FuseButton)).height,
        greaterThanOrEqualTo(48.0),
      );
      expect(_fusePainter(tester), isNull);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('press opens the undo window, burn out commits once', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await tester.pump();
      expect(log.pressed, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);

      // The fuse burns down.
      final double start = _fusePainter(tester).remaining.value as double;
      await _advance(tester, const Duration(seconds: 2));
      final double later = _fusePainter(tester).remaining.value as double;
      expect(later, lessThan(start));
      expect(log.committed, 0);

      await _advance(tester, const Duration(milliseconds: 2800));
      expect(log.committed, 1);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Deleted'), findsOneWidget);
      expect(_fusePainter(tester), isNull);

      // The final done state ignores further taps.
      await tester.tap(find.byType(FuseButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(log.pressed, 1);
      expect(log.committed, 1);
      expect(log.undone, 0);
    });

    testWidgets('undo within the window restores and never commits', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(seconds: 3));
      await tester.tap(find.byType(FuseButton));
      await tester.pump();
      expect(log.undone, 1);
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);

      await _advance(tester, const Duration(seconds: 6));
      expect(log.committed, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // A second press starts a fresh, full window.
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(milliseconds: 4800));
      expect(log.committed, 0);
      await _advance(tester, const Duration(milliseconds: 400));
      expect(log.committed, 1);
      expect(log.pressed, 2);
    });

    testWidgets('resetAfterCommit returns to the original state', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(
        _wrap(
          _button(
            log,
            resetAfterCommit: true,
            undoWindow: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(milliseconds: 1200));
      expect(log.committed, 1);
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Deleted'), findsNothing);
      // It can be used again.
      await tester.tap(find.byType(FuseButton));
      await tester.pump();
      expect(log.pressed, 2);
      await _advance(tester, const Duration(milliseconds: 1200));
      expect(log.committed, 2);
    });

    testWidgets('the fuse pauses while hovered', (WidgetTester tester) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(seconds: 1));

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(FuseButton)));
      await tester.pump();
      final double paused = _fusePainter(tester).remaining.value as double;
      await _advance(tester, const Duration(seconds: 10));
      expect(log.committed, 0);
      expect(_fusePainter(tester).remaining.value, paused);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Leaving resumes from where it stopped: about 4 seconds remain.
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 3500));
      expect(log.committed, 0);
      await _advance(tester, const Duration(milliseconds: 800));
      expect(log.committed, 1);
    });

    testWidgets('pauseOnHover false keeps burning while hovered', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log, pauseOnHover: false)));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(FuseButton)));
      await tester.pump();
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(milliseconds: 5200));
      expect(log.committed, 1);
    });

    testWidgets('keyboard: Enter presses, Escape and Space undo', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(log.pressed, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(log.undone, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(log.pressed, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(log.undone, 2);
      await tester.pumpAndSettle();
      expect(log.committed, 0);
    });

    testWidgets('semantics: button, then a live region with Undo', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      expect(
        tester.getSemantics(find.byType(FuseButton)),
        matchesSemantics(
          label: 'Delete',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Delete'));
      // Not pumpAndSettle: that would burn the whole fuse.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(log.pressed, 1);
      final SemanticsNode node = tester.getSemantics(find.byType(FuseButton));
      expect(node.label, contains('Deleted'));
      expect(node.label, contains('Undo'));
      expect(
        node,
        matchesSemantics(
          label: node.label,
          isButton: true,
          isLiveRegion: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await _advance(tester, const Duration(seconds: 6));
      handle.dispose();
    });

    testWidgets('semanticLabel replaces the idle label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          FuseButton(
            onPressed: () {},
            onCommit: () {},
            semanticLabel: 'Delete message',
            child: const Icon(Icons.delete),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Delete message'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('disabled: dimmed and ignores taps', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log, enabled: false)));
      await tester.tap(find.byType(FuseButton), warnIfMissed: false);
      await tester.pump();
      expect(log.pressed, 0);
      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(FuseButton),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.5);

      await tester.pumpWidget(
        _wrap(
          FuseButton(
            onPressed: null,
            onCommit: () => log.committed++,
            child: const Text('Delete'),
          ),
        ),
      );
      await tester.tap(find.byType(FuseButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(log.committed, 0);
    });

    testWidgets('reduced motion: instant swap, static bar, still commits', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(
        _wrap(
          _button(log, undoWindow: const Duration(seconds: 2)),
          reducedMotion: true,
        ),
      );
      await tester.tap(find.byType(FuseButton));
      await tester.pump();
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      expect(_fusePainter(tester).spark, isFalse);
      await _advance(tester, const Duration(milliseconds: 2200));
      expect(log.committed, 1);
      await tester.pump();
      expect(find.text('Undo'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('haptics on press and undo', (WidgetTester tester) async {
      final List<Object?> calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(FuseButton));
      await tester.pumpAndSettle();
      expect(calls, <Object?>[
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.selectionClick',
      ]);

      calls.clear();
      await tester.pumpWidget(_wrap(_button(log, enableHaptics: false)));
      await tester.tap(find.byType(FuseButton));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(FuseButton));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('bottom track and RTL paint without errors', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(
        _wrap(
          Directionality(
            textDirection: TextDirection.rtl,
            child: _button(log, track: FuseTrack.bottom),
          ),
        ),
      );
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(seconds: 1));
      expect(_fusePainter(tester).track, FuseTrack.bottom);
      expect(tester.takeException(), isNull);
      await _advance(tester, const Duration(seconds: 5));
      expect(log.committed, 1);
    });

    testWidgets('changing undoWindow mid-window applies the new length', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(seconds: 1));
      // 80 percent remains; with a 1 second window that is 0.8 seconds.
      await tester.pumpWidget(
        _wrap(_button(log, undoWindow: const Duration(seconds: 1))),
      );
      await _advance(tester, const Duration(milliseconds: 1000));
      expect(log.committed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing during the window calls nothing and leaks nothing', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      await tester.pumpWidget(_wrap(_button(log)));
      await tester.tap(find.byType(FuseButton));
      await _advance(tester, const Duration(seconds: 1));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await _advance(tester, const Duration(seconds: 6));
      expect(log.committed, 0);
      expect(log.undone, 0);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
