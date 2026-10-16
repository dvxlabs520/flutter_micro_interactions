import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/sling_button.dart';
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

/// The round button surface.
Finder get _disk => find.descendant(
  of: find.byType(SlingButton),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is DecoratedBox &&
        w.decoration is ShapeDecoration &&
        (w.decoration as ShapeDecoration).shape is CircleBorder,
  ),
);

Offset _restCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(SlingButton));

Offset _diskOffset(WidgetTester tester) =>
    tester.getCenter(_disk) - _restCenter(tester);

Offset _iconOffset(WidgetTester tester) =>
    tester.getCenter(find.byIcon(Icons.send)) - _restCenter(tester);

List<Object?> _mockHaptics(WidgetTester tester) {
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
  return calls;
}

/// Drags from the button center by [total] in [steps] moves.
Future<TestGesture> _pull(
  WidgetTester tester,
  Offset total, {
  int steps = 10,
}) async {
  final TestGesture gesture = await tester.startGesture(_restCenter(tester));
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(total / steps.toDouble());
    await tester.pump();
  }
  return gesture;
}

void main() {
  group('SlingButton', () {
    testWidgets('renders a round button with a 48 pixel target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SlingButton(size: 40, onFired: () {}, child: const Icon(Icons.send)),
        ),
      );
      final Size size = tester.getSize(find.byType(SlingButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(_disk), const Size(40, 40));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a tap fires once and plays a launch that settles', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(onFired: () => fired++, child: const Icon(Icons.send)),
        ),
      );
      await tester.tap(find.byType(SlingButton));
      await tester.pump();
      expect(fired, 1);
      await tester.pump(const Duration(milliseconds: 150));
      // The icon flies toward the end side (right in LTR) and upward.
      expect(_iconOffset(tester).dx, greaterThan(10.0));
      expect(_iconOffset(tester).dy, lessThan(0.0));
      await tester.pumpAndSettle();
      expect(_iconOffset(tester), Offset.zero);
      expect(_diskOffset(tester), Offset.zero);
      expect(fired, 1);
    });

    testWidgets('fireOnTap false: a tap does not fire', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(
            fireOnTap: false,
            onFired: () => fired++,
            child: const Icon(Icons.send),
          ),
        ),
      );
      await tester.tap(find.byType(SlingButton));
      await tester.pumpAndSettle();
      expect(fired, 0);
    });

    testWidgets('pulling stretches, release past threshold fires opposite', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(onFired: () => fired++, child: const Icon(Icons.send)),
        ),
      );
      final TestGesture gesture = await _pull(tester, const Offset(-150, 0));
      final Offset pulled = _diskOffset(tester);
      expect(pulled.dx, lessThan(-40.0));
      expect(pulled.distance, lessThanOrEqualTo(80.0));
      // The bands are painted while pulling.
      final CustomPaint bands = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(SlingButton),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(bands.painter, isNotNull);
      expect(fired, 0);

      await gesture.up();
      await tester.pump();
      expect(fired, 1);
      await tester.pump(const Duration(milliseconds: 150));
      // The icon flies to the right, away from the pull.
      expect(_iconOffset(tester).dx, greaterThan(30.0));
      await tester.pumpAndSettle();
      expect(_diskOffset(tester), Offset.zero);
      expect(_iconOffset(tester), Offset.zero);
      expect(fired, 1);
    });

    testWidgets('release below threshold springs back without firing', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(onFired: () => fired++, child: const Icon(Icons.send)),
        ),
      );
      final TestGesture gesture = await _pull(tester, const Offset(0, 30));
      expect(_diskOffset(tester).dy, greaterThan(15.0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // Still on its way back, icon never leaves the button.
      expect(_diskOffset(tester).dy, greaterThan(0.0));
      expect(
        (_iconOffset(tester) - _diskOffset(tester)).distance,
        lessThan(0.01),
      );
      await tester.pumpAndSettle();
      expect(_diskOffset(tester), Offset.zero);
      expect(fired, 0);
    });

    testWidgets('the pull never exceeds maxPull and respects axis', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SlingButton(
            maxPull: 60,
            axis: Axis.horizontal,
            onFired: () {},
            child: const Icon(Icons.send),
          ),
        ),
      );
      final TestGesture gesture = await _pull(tester, const Offset(-500, 300));
      final Offset pulled = _diskOffset(tester);
      expect(pulled.dy, 0.0);
      expect(pulled.dx, lessThan(-50.0));
      expect(pulled.dx, greaterThanOrEqualTo(-60.0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('haptics: rising ticks while pulling, heavy on fire', (
      WidgetTester tester,
    ) async {
      final List<Object?> calls = _mockHaptics(tester);
      await tester.pumpWidget(
        _wrap(SlingButton(onFired: () {}, child: const Icon(Icons.send))),
      );
      final TestGesture gesture = await _pull(
        tester,
        const Offset(-300, 0),
        steps: 30,
      );
      expect(calls, <Object?>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      await gesture.up();
      await tester.pump();
      expect(calls.last, 'HapticFeedbackType.heavyImpact');
      await tester.pumpAndSettle();

      calls.clear();
      await tester.pumpWidget(
        _wrap(
          SlingButton(
            enableHaptics: false,
            onFired: () {},
            child: const Icon(Icons.send),
          ),
        ),
      );
      final TestGesture quiet = await _pull(tester, const Offset(-300, 0));
      await quiet.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('semantics and keyboard activation fire', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(onFired: () => fired++, child: const Icon(Icons.send)),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SlingButton)),
        matchesSemantics(
          label: 'Send',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Send'));
      await tester.pumpAndSettle();
      expect(fired, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(fired, 3);
      handle.dispose();
    });

    testWidgets('disabled: dimmed, ignores taps and drags', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(
            enabled: false,
            onFired: () => fired++,
            child: const Icon(Icons.send),
          ),
        ),
      );
      await tester.tap(find.byType(SlingButton), warnIfMissed: false);
      final TestGesture gesture = await _pull(tester, const Offset(-200, 0));
      expect(_diskOffset(tester), Offset.zero);
      await gesture.up();
      await tester.pump();
      expect(fired, 0);
      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(SlingButton),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.5);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: follows the finger, returns instantly', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await tester.pumpWidget(
        _wrap(
          SlingButton(onFired: () => fired++, child: const Icon(Icons.send)),
          reducedMotion: true,
        ),
      );
      final TestGesture gesture = await _pull(tester, const Offset(-200, 0));
      expect(_diskOffset(tester).dx, lessThan(-40.0));
      await gesture.up();
      await tester.pump();
      expect(fired, 1);
      expect(_diskOffset(tester), Offset.zero);
      expect(_iconOffset(tester), Offset.zero);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.tap(find.byType(SlingButton));
      await tester.pump();
      expect(fired, 2);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('config changes and disposing mid-flight do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SlingButton(onFired: () {}, child: const Icon(Icons.send))),
      );
      final TestGesture gesture = await _pull(tester, const Offset(-150, 0));
      await tester.pumpWidget(
        _wrap(
          SlingButton(
            maxPull: 40,
            axis: Axis.vertical,
            duration: const Duration(milliseconds: 300),
            onFired: () {},
            child: const Icon(Icons.send),
          ),
        ),
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(SlingButton));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
