import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/scrub_field.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A host that owns the value, like a real form would.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1,
    this.fractionDigits = 0,
    this.sensitivity = 4,
    this.focusNode,
    this.onChangeEnd,
  });

  final double initial;
  final double min;
  final double max;
  final double step;
  final int fractionDigits;
  final double sensitivity;
  final FocusNode? focusNode;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  final List<double> changes = <double>[];

  @override
  Widget build(BuildContext context) {
    return ScrubField(
      label: 'W',
      suffix: 'px',
      value: value,
      min: widget.min,
      max: widget.max,
      step: widget.step,
      fractionDigits: widget.fractionDigits,
      sensitivity: widget.sensitivity,
      focusNode: widget.focusNode,
      onChangeEnd: widget.onChangeEnd,
      onChanged: (double v) {
        changes.add(v);
        setState(() => value = v);
      },
    );
  }
}

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

/// Horizontal rubber-band offset currently applied to the chip.
double _overshoot(WidgetTester tester) {
  double result = 0;
  for (final Transform t in tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(ScrubField),
      matching: find.byType(Transform),
    ),
  )) {
    final double x = t.transform.getTranslation().x;
    if (x.abs() > result.abs()) result = x;
  }
  return result;
}

/// Starts a drag and moves past the touch slop so scrubbing begins.
Future<TestGesture> _startScrub(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.byType(ScrubField)),
  );
  await gesture.moveBy(const Offset(kTouchSlop + 2, 0));
  await tester.pump();
  return gesture;
}

void main() {
  group('ScrubField', () {
    testWidgets('renders the label, value and suffix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 42)));
      expect(find.text('W'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('px'), findsOneWidget);
    });

    testWidgets('formats with fractionDigits', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const _Host(initial: 0.5, step: 0.1, fractionDigits: 2)),
      );
      expect(find.text('0.50'), findsOneWidget);
    });

    testWidgets('dragging changes the value by step per sensitivity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 10, sensitivity: 4)));
      final TestGesture gesture = await _startScrub(tester);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(_host(tester).value, 20);
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(_host(tester).value, 5);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_host(tester).changes, <double>[20, 5]);
    });

    testWidgets('fractional steps stay clean', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            initial: 0.1,
            step: 0.1,
            fractionDigits: 1,
            sensitivity: 10,
          ),
        ),
      );
      final TestGesture gesture = await _startScrub(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(_host(tester).value, 0.3);
      expect(find.text('0.3'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('rubber band past max: clamped value, stretch, spring back', (
      WidgetTester tester,
    ) async {
      final List<double> ends = <double>[];
      await tester.pumpWidget(
        _wrap(_Host(initial: 10, max: 12, onChangeEnd: ends.add)),
      );
      final TestGesture gesture = await _startScrub(tester);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(_host(tester).value, 12);
      final double small = _overshoot(tester);
      expect(small, greaterThan(0));

      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      expect(_host(tester).value, 12);
      final double big = _overshoot(tester);
      expect(big, greaterThan(small));
      // Resistance: never further than maxOvershoot (18 by default).
      expect(big, lessThanOrEqualTo(18));

      await gesture.up();
      await tester.pump();
      expect(ends, <double>[12]);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_overshoot(tester).abs(), lessThan(big));
      await tester.pumpAndSettle();
      expect(_overshoot(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rubber band past min stretches the other way', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 1, min: 0)));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScrubField)),
      );
      await gesture.moveBy(const Offset(-(kTouchSlop + 2), 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(_host(tester).value, 0);
      expect(_overshoot(tester), lessThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_overshoot(tester), 0);
    });

    testWidgets('tap opens an inline field; Enter commits the clamped value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 10, max: 100)));
      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '10');
      expect(field.controller!.selection.extentOffset, 2);

      await tester.enterText(find.byType(TextField), '64');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(_host(tester).value, 64);

      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_host(tester).value, 100);
    });

    testWidgets('Escape cancels typing', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 10)));
      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '55');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(_host(tester).value, 10);
      expect(_host(tester).changes, isEmpty);
    });

    testWidgets('moving focus away commits; invalid input is ignored', (
      WidgetTester tester,
    ) async {
      final FocusNode other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Host(initial: 10, fractionDigits: 1, step: 0.5),
              Focus(focusNode: other, child: const SizedBox(width: 10)),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '3,14');
      other.requestFocus();
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      // Commas are read as decimal points and rounded to fractionDigits.
      expect(_host(tester).value, 3.1);

      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '--');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_host(tester).value, 3.1);
    });

    testWidgets('keyboard arrows step; Shift steps by ten', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(_Host(initial: 10, max: 30, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_host(tester).value, 11);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_host(tester).value, 10);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(_host(tester).value, 30);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('semantics: adjustable with values and actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Host(initial: 10)));
      final SemanticsNode node = tester.getSemantics(find.byType(ScrubField));
      expect(
        node,
        isSemantics(
          label: 'W',
          value: '10 px',
          increasedValue: '11 px',
          decreasedValue: '9 px',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          hasTapAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(_host(tester).value, 11);
      handle.dispose();
    });

    testWidgets('disabled: dimmed, ignores drags and taps', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const ScrubField(value: 5, onChanged: null, label: 'X')),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScrubField)),
      );
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byType(ScrubField));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('5'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ScrubField)),
        isSemantics(isSlider: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('enabled false behaves like a null onChanged', (
      WidgetTester tester,
    ) async {
      double value = 5;
      await tester.pumpWidget(
        _wrap(
          ScrubField(
            value: value,
            enabled: false,
            onChanged: (double v) => value = v,
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScrubField)),
      );
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await tester.pump();
      expect(value, 5);
    });

    testWidgets('reduced motion: no stretch past the limit, no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _Host(initial: 10, max: 12), reducedMotion: true),
      );
      final TestGesture gesture = await _startScrub(tester);
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(_host(tester).value, 12);
      expect(_overshoot(tester), 0);
      await gesture.up();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('disposing during the spring back does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 10, max: 12)));
      final TestGesture gesture = await _startScrub(tester);
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
