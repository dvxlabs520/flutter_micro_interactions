import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/wake_slider.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 320;

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: _width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// A host that owns the value, like a real form would.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = 0.2,
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

  @override
  Widget build(BuildContext context) {
    return WakeSlider(
      value: value,
      divisions: widget.divisions,
      focusNode: widget.focusNode,
      onChangeStart: widget.onChangeStart,
      onChangeEnd: widget.onChangeEnd,
      onChanged: (double v) => setState(() => value = v),
    );
  }
}

double _value(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host)).value;

dynamic _field(WidgetTester tester) {
  final dynamic painter = tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(WakeSlider),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter;
  return painter.field;
}

double _position(WidgetTester tester) => _field(tester).position as double;

double _peak(WidgetTester tester) => _field(tester).peak as double;

/// Fraction of the track under a local x position (default 32 bars and a
/// gap of 3 on a 320 pixel track).
double _fractionAtX(double x) {
  const double barWidth = (_width - 31 * 3) / 32;
  return (x - barWidth / 2) / (_width - barWidth);
}

Offset _local(WidgetTester tester, double x) =>
    tester.getTopLeft(find.byType(WakeSlider)) + Offset(x, 20);

/// Drags across the track with timestamps, [dx] pixels per 16 ms frame.
Future<double> _dragAndMeasurePeak(
  WidgetTester tester, {
  required double dx,
  int frames = 6,
}) async {
  final TestGesture gesture = await tester.startGesture(_local(tester, 20));
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump(const Duration(milliseconds: 16));
  double peak = 0;
  for (int i = 0; i < frames; i++) {
    await gesture.moveBy(Offset(dx, 0));
    await tester.pump(const Duration(milliseconds: 16));
    peak = _peak(tester) > peak ? _peak(tester) : peak;
  }
  await gesture.up();
  return peak;
}

void main() {
  group('WakeSlider', () {
    testWidgets('renders bars with the handle at the value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 0.25)));
      await tester.pump();
      expect(tester.getSize(find.byType(WakeSlider)), const Size(320, 40));
      expect(_position(tester), 0.25);
      expect((_field(tester).wake as List<double>).length, 32);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('barWidth sets an exact intrinsic width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: WakeSlider(
              value: 0.5,
              bars: 10,
              barWidth: 4,
              gap: 2,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(WakeSlider)), const Size(58, 40));
    });

    testWidgets('tap jumps to the tapped point and glides there', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tapAt(_local(tester, 240));
      await tester.pump();
      expect(_value(tester), closeTo(_fractionAtX(240), 1e-6));
      // The handle glides rather than jumping.
      await tester.pump(const Duration(milliseconds: 40));
      expect(_position(tester), greaterThan(0.2));
      expect(_position(tester), lessThan(_value(tester)));
      await tester.pumpAndSettle();
      expect(_position(tester), closeTo(_value(tester), 1e-4));
    });

    testWidgets('drag maps the finger position to the value', (
      WidgetTester tester,
    ) async {
      final List<double> starts = <double>[];
      final List<double> ends = <double>[];
      await tester.pumpWidget(
        _wrap(_Host(onChangeStart: starts.add, onChangeEnd: ends.add)),
      );
      final TestGesture gesture = await tester.startGesture(_local(tester, 40));
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_value(tester), closeTo(_fractionAtX(280), 1e-6));
      // During a continuous drag the handle stays right under the finger.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_position(tester), closeTo(_value(tester), 1e-3));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(starts, <double>[0.2]);
      expect(ends, hasLength(1));
      expect(ends.single, _value(tester));
    });

    testWidgets('dragging past the ends clamps to min and max', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 0.5)));
      await tester.drag(find.byType(WakeSlider), const Offset(900, 0));
      await tester.pumpAndSettle();
      expect(_value(tester), 1.0);
      await tester.drag(find.byType(WakeSlider), const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(_value(tester), 0.0);
    });

    testWidgets('divisions snap values', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const _Host(divisions: 4)));
      await tester.tapAt(_local(tester, 0.32 * _width));
      await tester.pump();
      expect(_value(tester), 0.25);
      await tester.tapAt(_local(tester, 0.9 * _width));
      await tester.pump();
      expect(_value(tester), 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('right to left: the track starts on the right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _Host(), textDirection: TextDirection.rtl),
      );
      await tester.tapAt(_local(tester, 40));
      await tester.pump();
      expect(_value(tester), closeTo(1 - _fractionAtX(40), 1e-6));
      await tester.pumpAndSettle();
    });

    testWidgets('a fast drag raises a higher wake than a slow one', (
      WidgetTester tester,
    ) async {
      // Start where the drag will begin, so no jump adds its own wake.
      await tester.pumpWidget(_wrap(_Host(initial: _fractionAtX(40))));
      final double slow = await _dragAndMeasurePeak(tester, dx: 2);
      await tester.pumpAndSettle();

      // A fresh slider for the second run.
      await tester.pumpWidget(
        _wrap(
          _Host(key: const ValueKey<String>('fast'), initial: _fractionAtX(40)),
        ),
      );
      final double fast = await _dragAndMeasurePeak(tester, dx: 30);

      expect(fast, greaterThan(0.2));
      expect(fast, greaterThan(slow * 2));
    });

    testWidgets('the wake settles back and stops scheduling frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 0)));
      final double peak = await _dragAndMeasurePeak(tester, dx: 30);
      expect(peak, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_peak(tester), lessThan(peak));
      await tester.pumpAndSettle();
      expect(_peak(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a tap jump also leaves a wake', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 0)));
      await tester.tapAt(_local(tester, 300));
      await tester.pump();
      double peak = 0;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        peak = _peak(tester) > peak ? _peak(tester) : peak;
      }
      expect(peak, greaterThan(0.2));
      await tester.pumpAndSettle();
    });

    testWidgets('semantics: slider with values and adjust actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Host(initial: 0.2)));
      final SemanticsNode node = tester.getSemantics(find.byType(WakeSlider));
      expect(
        node,
        isSemantics(
          isSlider: true,
          isEnabled: true,
          value: '20%',
          increasedValue: '25%',
          decreasedValue: '15%',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(_value(tester), closeTo(0.25, 1e-9));
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pump();
      expect(_value(tester), closeTo(0.2, 1e-9));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('semanticFormatterCallback formats the value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          WakeSlider(
            value: 3,
            min: 0,
            max: 10,
            divisions: 10,
            semanticLabel: 'Volume',
            semanticFormatterCallback: (double v) => 'level ${v.round()}',
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(WakeSlider)),
        isSemantics(
          label: 'Volume',
          value: 'level 3',
          increasedValue: 'level 4',
        ),
      );
      handle.dispose();
    });

    testWidgets('keyboard: arrows, page keys, Home and End', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(_Host(initial: 0.5, divisions: 10, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      await press(LogicalKeyboardKey.arrowRight);
      expect(_value(tester), closeTo(0.6, 1e-9));
      await press(LogicalKeyboardKey.arrowDown);
      expect(_value(tester), closeTo(0.5, 1e-9));
      await press(LogicalKeyboardKey.pageUp);
      expect(_value(tester), closeTo(0.7, 1e-9));
      await press(LogicalKeyboardKey.end);
      expect(_value(tester), 1.0);
      await press(LogicalKeyboardKey.home);
      expect(_value(tester), 0.0);
      await tester.pumpAndSettle();
    });

    testWidgets('disabled: dimmed, ignores input, semantics disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      double value = 0.3;
      await tester.pumpWidget(
        _wrap(
          WakeSlider(
            value: value,
            enabled: false,
            onChanged: (double v) => value = v,
          ),
        ),
      );
      await tester.tapAt(_local(tester, 300));
      await tester.drag(find.byType(WakeSlider), const Offset(100, 0));
      await tester.pump();
      expect(value, 0.3);
      expect(find.byType(Opacity), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(WakeSlider)),
        isSemantics(isSlider: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('reduced motion: direct value changes, no wake, no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _Host(initial: 0), reducedMotion: true),
      );
      await tester.tapAt(_local(tester, 300));
      await tester.pump();
      expect(_position(tester), _value(tester));
      expect(_peak(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      final TestGesture gesture = await tester.startGesture(_local(tester, 20));
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(_peak(tester), 0.0);
        expect(_position(tester), _value(tester));
      }
      await gesture.up();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('config changes and disposal mid animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(initial: 0)));
      await tester.tapAt(_local(tester, 300));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(
        _wrap(WakeSlider(value: 0.4, bars: 12, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect((_field(tester).wake as List<double>).length, 12);
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
