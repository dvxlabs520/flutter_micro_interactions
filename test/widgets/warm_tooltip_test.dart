import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/warm_tooltip.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _box(String label) => SizedBox(
  width: 60,
  height: 40,
  child: ColoredBox(
    color: Colors.blue,
    child: Center(child: Text(label)),
  ),
);

Widget _group({bool reducedMotion = false, bool preferBelow = false}) {
  return _wrap(
    WarmTooltipGroup(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          WarmTooltip(
            message: 'Alpha tip',
            preferBelow: preferBelow,
            child: _box('A'),
          ),
          const SizedBox(width: 200),
          WarmTooltip(message: 'Beta tip', child: _box('B')),
          const SizedBox(width: 20),
          WarmTooltip(message: 'Gamma tip', child: _box('C')),
        ],
      ),
    ),
    reducedMotion: reducedMotion,
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: const Offset(1, 1));
  return mouse;
}

void main() {
  group('WarmTooltip', () {
    testWidgets('first tooltip waits for warmDelay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group());
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Alpha tip'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Alpha tip'), findsOneWidget);
      // Above the anchor by default.
      expect(
        tester.getRect(find.text('Alpha tip')).bottom,
        lessThan(tester.getRect(find.text('A')).top),
      );
      await mouse.removePointer();
      await tester.pumpAndSettle();
    });

    testWidgets('sibling shows instantly and the bubble glides', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group());
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final double fromX = tester.getCenter(find.text('A')).dx;
      final double toX = tester.getCenter(find.text('B')).dx;

      await mouse.moveTo(tester.getCenter(find.text('B')));
      await tester.pump();
      expect(find.text('Beta tip'), findsOneWidget, reason: 'no warm delay');
      await tester.pump(const Duration(milliseconds: 60));
      final double midX = tester.getCenter(find.text('Beta tip')).dx;
      expect(midX, greaterThan(fromX + 5));
      expect(midX, lessThan(toX - 5));
      // The old text is still cross-fading out.
      expect(find.text('Alpha tip'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Beta tip')).dx, closeTo(toX, 0.5));
      expect(find.text('Alpha tip'), findsNothing);
      await mouse.removePointer();
      await tester.pumpAndSettle();
    });

    testWidgets('still warm within cooldown, cold again after it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group());
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Leave to empty space, come back to a sibling within the cooldown.
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 200));
      await mouse.moveTo(tester.getCenter(find.text('C')));
      await tester.pump();
      expect(find.text('Gamma tip'), findsOneWidget);
      await tester.pumpAndSettle();

      // Leave for longer than the cooldown: the group is cold.
      await mouse.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await mouse.moveTo(tester.getCenter(find.text('B')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Beta tip'), findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Beta tip'), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpAndSettle();
    });

    testWidgets('long press shows on touch and hides after showDuration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(WarmTooltip(message: 'Touch tip', child: _box('T'))),
      );
      await tester.longPress(find.text('T'));
      await tester.pump();
      expect(find.text('Touch tip'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Touch tip'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Touch tip'), findsNothing);
    });

    testWidgets('standalone tooltip uses waitDuration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WarmTooltip(
            message: 'Solo',
            waitDuration: const Duration(milliseconds: 200),
            child: _box('S'),
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('S')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Solo'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Solo'), findsOneWidget);
      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(find.text('Solo'), findsNothing);
      await mouse.removePointer();
    });

    testWidgets('flips below when there is no room above', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: WarmTooltip(message: 'Flip', child: _box('F')),
            ),
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('F')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Flip')).top,
        greaterThan(tester.getRect(find.text('F')).bottom),
      );
      await mouse.removePointer();
    });

    testWidgets('preferBelow places the bubble below', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group(preferBelow: true));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Alpha tip')).top,
        greaterThan(tester.getRect(find.text('A')).bottom),
      );
      await mouse.removePointer();
    });

    testWidgets('Escape hides a visible tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(_group());
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Alpha tip'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Alpha tip'), findsNothing);
      await mouse.removePointer();
    });

    testWidgets('child carries the message as semantics tooltip', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_group());
      expect(
        tester.getSemantics(find.text('A')),
        isSemantics(tooltip: 'Alpha tip'),
      );
      handle.dispose();
    });

    testWidgets('enabled false shows nothing', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(WarmTooltip(message: 'Off', enabled: false, child: _box('O'))),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('O')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Off'), findsNothing);
      await mouse.removePointer();
    });

    testWidgets('reduced motion: no glide, no fade frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group(reducedMotion: true));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Alpha tip'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await mouse.moveTo(tester.getCenter(find.text('B')));
      await tester.pump();
      expect(
        tester.getCenter(find.text('Beta tip')).dx,
        closeTo(tester.getCenter(find.text('B')).dx, 0.5),
      );
      expect(find.text('Alpha tip'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('disposing while visible or pending leaves no timers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_group());
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.moveTo(tester.getCenter(find.text('B')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Pending first-show timer is cancelled on dispose too.
      await tester.pumpWidget(_group());
      await mouse.moveTo(tester.getCenter(find.text('C')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();
      await mouse.removePointer();
    });

    testWidgets('removing the active anchor hides the bubble', (
      WidgetTester tester,
    ) async {
      bool showB = true;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          WarmTooltipGroup(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                setOuter = setState;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    WarmTooltip(message: 'Keep', child: _box('K')),
                    if (showB) WarmTooltip(message: 'Gone', child: _box('G')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('G')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Gone'), findsOneWidget);
      setOuter(() => showB = false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Gone'), findsNothing);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
