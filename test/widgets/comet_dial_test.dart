import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/comet_dial.dart';
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
    this.initial = 50,
    this.divisions,
    this.focusNode,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final double initial;
  final int? divisions;
  final FocusNode? focusNode;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  final List<double> changes = <double>[];

  @override
  Widget build(BuildContext context) {
    return CometDial(
      value: value,
      divisions: widget.divisions,
      focusNode: widget.focusNode,
      onChangeStart: widget.onChangeStart,
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

dynamic _field(WidgetTester tester) {
  final dynamic painter = tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(CometDial),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter;
  return painter.field;
}

/// A point on a circle of [radius] around the dial center, at [degrees]
/// measured clockwise from 3 o'clock.
Offset _polar(WidgetTester tester, double degrees, {double radius = 80}) {
  final double a = degrees * math.pi / 180;
  return tester.getCenter(find.byType(CometDial)) +
      Offset(math.cos(a), math.sin(a)) * radius;
}

/// Drags around the dial from [from] to [to] degrees in [steps] moves, one
/// frame apart, with timestamps so release velocity is meaningful.
Future<TestGesture> _arcDrag(
  WidgetTester tester, {
  required double from,
  required double to,
  int steps = 12,
  int frameMs = 16,
}) async {
  final TestGesture gesture = await tester.startGesture(_polar(tester, from));
  for (int i = 1; i <= steps; i++) {
    final double degrees = from + (to - from) * i / steps;
    await gesture.moveTo(
      _polar(tester, degrees),
      timeStamp: Duration(milliseconds: frameMs * i),
    );
    await tester.pump(Duration(milliseconds: frameMs));
  }
  return gesture;
}

void main() {
  group('CometDial', () {
    testWidgets('renders the value in the center', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 35)));
      expect(find.text('35'), findsOneWidget);
      expect(tester.getSize(find.byType(CometDial)), const Size(200, 200));
      expect(_field(tester).position, 0.35);
      expect(_field(tester).trail, 0.0);
    });

    testWidgets('centerBuilder replaces the center content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometDial(
            value: 21,
            onChanged: (_) {},
            centerBuilder: (BuildContext context, double value) =>
                Text('${value.round()} C'),
          ),
        ),
      );
      expect(find.text('21 C'), findsOneWidget);
    });

    testWidgets('dragging maps the swept angle to the value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 50)));
      // 60 degrees clockwise is 60 / 300 of the range.
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -90,
        to: -30,
        frameMs: 200,
      );
      await gesture.up(timeStamp: const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_host(tester).value, closeTo(70, 0.5));

      // Counter-clockwise lowers the value.
      final TestGesture back = await _arcDrag(
        tester,
        from: 0,
        to: -90,
        frameMs: 200,
      );
      await back.up(timeStamp: const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_host(tester).value, closeTo(40, 0.5));
    });

    testWidgets('moving straight out from the center changes nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 50)));
      final TestGesture gesture = await tester.startGesture(
        _polar(tester, -45, radius: 30),
      );
      for (int i = 1; i <= 6; i++) {
        await gesture.moveTo(_polar(tester, -45, radius: 30 + i * 10.0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_host(tester).value, 50);
    });

    testWidgets('crossing the gap clamps instead of wrapping', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 90)));
      // Value 90 sits at 120 + 270 = 390 (30) degrees. Keep turning
      // clockwise through the bottom gap and on to the left side.
      final TestGesture gesture = await _arcDrag(
        tester,
        from: 30,
        to: 200,
        steps: 34,
        frameMs: 100,
      );
      expect(_host(tester).value, 100);
      expect(_host(tester).changes.every((double v) => v >= 90), isTrue);
      // Turning back immediately lowers the value from the max.
      for (int i = 1; i <= 6; i++) {
        await gesture.moveTo(
          _polar(tester, 200 - i * 5.0),
          timeStamp: Duration(milliseconds: 3400 + 100 * i),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_host(tester).value, closeTo(100 - 30 / 3, 0.5));
      await gesture.up(timeStamp: const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a flick keeps turning with friction, then settles', (
      WidgetTester tester,
    ) async {
      final List<double> starts = <double>[];
      final List<double> ends = <double>[];
      await tester.pumpWidget(
        _wrap(
          _Host(initial: 20, onChangeStart: starts.add, onChangeEnd: ends.add),
        ),
      );
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -150,
        to: -100,
        steps: 5,
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 90));
      await tester.pump();
      final double atRelease = _host(tester).value;
      expect(ends, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      final double coast1 = _host(tester).value;
      await tester.pump(const Duration(milliseconds: 100));
      final double coast2 = _host(tester).value;
      expect(coast1, greaterThan(atRelease));
      expect(coast2, greaterThan(coast1));
      // Friction: the second interval covers less ground than the first.
      expect(coast2 - coast1, lessThan(coast1 - atRelease));
      // The comet streak grows with the motion.
      expect(_field(tester).trail as double, greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(starts, <double>[20]);
      expect(ends, hasLength(1));
      expect(ends.single, _host(tester).value);
      expect(_field(tester).trail, 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a flick stops at the end of the range', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 90)));
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -60,
        to: 0,
        steps: 4,
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 70));
      await tester.pumpAndSettle();
      expect(_host(tester).value, 100);
    });

    testWidgets('divisions snap every reported value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 50, divisions: 10)));
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -90,
        to: -10,
        frameMs: 200,
      );
      await gesture.up(timeStamp: const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_host(tester).changes, isNotEmpty);
      for (final double v in _host(tester).changes) {
        expect(v % 10, closeTo(0, 1e-9));
      }
      expect(_host(tester).value, closeTo(80, 1e-9));
      expect(_field(tester).position, closeTo(0.8, 1e-4));
    });

    testWidgets('semantics: slider with values and adjust actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Host(initial: 50)));
      final SemanticsNode node = tester.getSemantics(find.byType(CometDial));
      expect(
        node,
        isSemantics(
          isSlider: true,
          isEnabled: true,
          value: '50',
          increasedValue: '51',
          decreasedValue: '49',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(_host(tester).value, 51);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('keyboard: arrows, page keys, Home and End', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(_wrap(_Host(initial: 50, focusNode: focusNode)));
      focusNode.requestFocus();
      await tester.pump();
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      await press(LogicalKeyboardKey.arrowUp);
      expect(_host(tester).value, 51);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(_host(tester).value, 50);
      await press(LogicalKeyboardKey.pageDown);
      expect(_host(tester).value, 40);
      await press(LogicalKeyboardKey.end);
      expect(_host(tester).value, 100);
      await press(LogicalKeyboardKey.home);
      expect(_host(tester).value, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('a keyboard jump glides the head with a comet streak', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(_wrap(_Host(initial: 0, focusNode: focusNode)));
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final double position = _field(tester).position as double;
      expect(position, greaterThan(0));
      expect(position, lessThan(1));
      expect(_field(tester).trail as double, greaterThan(0.05));
      expect(_field(tester).direction, 1.0);
      await tester.pumpAndSettle();
      expect(_field(tester).position, closeTo(1.0, 1e-4));
    });

    testWidgets('disabled: dimmed, ignores input, semantics disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      double value = 30;
      await tester.pumpWidget(
        _wrap(
          CometDial(
            value: value,
            enabled: false,
            onChanged: (double v) => value = v,
          ),
        ),
      );
      final TestGesture gesture = await _arcDrag(tester, from: -90, to: 0);
      await gesture.up();
      await tester.pump();
      expect(value, 30);
      expect(find.byType(Opacity), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(CometDial)),
        isSemantics(isSlider: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('reduced motion: no comet, no coasting, no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _Host(initial: 20), reducedMotion: true),
      );
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -150,
        to: -100,
        steps: 5,
      );
      expect(_field(tester).trail, 0.0);
      expect(_field(tester).position, closeTo(_host(tester).value / 100, 1e-9));
      await gesture.up(timeStamp: const Duration(milliseconds: 90));
      await tester.pump();
      final double atRelease = _host(tester).value;
      await tester.pump(const Duration(milliseconds: 200));
      expect(_host(tester).value, atRelease);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('disposing during a flick does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 20)));
      final TestGesture gesture = await _arcDrag(
        tester,
        from: -150,
        to: -100,
        steps: 5,
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 90));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('range changes mid animation do not throw', (
      WidgetTester tester,
    ) async {
      double value = 10;
      Widget build() => _wrap(
        CometDial(
          value: value,
          max: value > 50 ? 200 : 100,
          onChanged: (double v) => value = v,
        ),
      );
      await tester.pumpWidget(build());
      value = 80;
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 30));
      expect(_field(tester).position, lessThan(0.4));
      await tester.pumpAndSettle();
      expect(_field(tester).position, closeTo(0.4, 1e-4));
    });
  });
}
