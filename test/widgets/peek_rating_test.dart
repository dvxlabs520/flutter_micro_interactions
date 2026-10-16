import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/peek_rating.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Controlled harness that stores the committed value.
class _Harness extends StatefulWidget {
  const _Harness({
    this.initial = 2,
    this.allowHalf = false,
    this.onChanged,
    this.readOnly = false,
  });

  final double initial;
  final bool allowHalf;
  final bool readOnly;
  final ValueChanged<double>? onChanged;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return PeekRating(
      value: _value,
      allowHalf: widget.allowHalf,
      readOnly: widget.readOnly,
      onChanged: (double value) {
        setState(() => _value = value);
        widget.onChanged?.call(value);
      },
    );
  }
}

Finder get _rating => find.byType(PeekRating);

/// Lift (in pixels, positive is up) of each star.
List<double> _lifts(WidgetTester tester) {
  final List<Transform> transforms = tester
      .widgetList<Transform>(
        find.descendant(of: _rating, matching: find.byType(Transform)),
      )
      .toList();
  final List<double> lifts = <double>[];
  // Each star is a translate wrapping a scale.
  for (int i = 0; i < transforms.length; i += 2) {
    lifts.add(-transforms[i].transform.storage[13]);
  }
  return lifts;
}

/// Center of star [index] (0-based) with the default size 28, spacing 6
/// and padding 4.
Offset _starCenter(WidgetTester tester, int index, {double dx = 0}) {
  final Rect rect = tester.getRect(_rating);
  return Offset(rect.left + 4 + index * 34 + 14 + dx, rect.center.dy);
}

/// Fill fraction of star [index] read from its painter's semantics-free
/// description.
double _fill(WidgetTester tester, int index) {
  final List<CustomPaint> paints = tester
      .widgetList<CustomPaint>(
        find.descendant(of: _rating, matching: find.byType(CustomPaint)),
      )
      .where((CustomPaint p) => p.painter != null)
      .toList();
  // ignore: avoid_dynamic_calls
  return (paints[index].painter! as dynamic).fill as double;
}

void main() {
  group('PeekRating', () {
    testWidgets('renders count stars with the committed value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(initial: 3)));
      expect(_lifts(tester), hasLength(5));
      expect(
        <double>[for (int i = 0; i < 5; i++) _fill(tester, i)],
        <double>[1, 1, 1, 0, 0],
      );
    });

    testWidgets('hover previews and lifts in a staggered wave', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(initial: 1)));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_starCenter(tester, 3));
      await tester.pump();
      // Preview fills up to the pointer.
      expect(_fill(tester, 3), 1.0);
      expect(_fill(tester, 4), 0.0);

      await tester.pump(const Duration(milliseconds: 60));
      final List<double> early = _lifts(tester);
      // The star under the pointer starts first; star 0 is 3 steps away.
      expect(early[3], greaterThan(0.0));
      expect(early[3], greaterThan(early[0]));
      expect(early[4], 0.0);

      await tester.pump(const Duration(seconds: 1));
      final List<double> settled = _lifts(tester);
      for (int i = 0; i < 4; i++) {
        expect(settled[i], closeTo(28 * 0.2, 0.05));
      }
      expect(settled[4], 0.0);

      // Leaving restores the committed value and drops the stars.
      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(_fill(tester, 1), 0.0);
      expect(_fill(tester, 0), 1.0);
      await tester.pump(const Duration(seconds: 1));
      expect(_lifts(tester).every((double l) => l.abs() < 0.05), isTrue);
      await mouse.removePointer();
    });

    testWidgets('click commits with a pop', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      await tester.tapAt(_starCenter(tester, 3));
      expect(changes, <double>[4.0]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // The committed star swells during the pop.
      final List<Transform> transforms = tester
          .widgetList<Transform>(
            find.descendant(of: _rating, matching: find.byType(Transform)),
          )
          .toList();
      expect(transforms[7].transform.storage[0], greaterThan(1.05));
      await tester.pumpAndSettle();
      final List<Transform> after = tester
          .widgetList<Transform>(
            find.descendant(of: _rating, matching: find.byType(Transform)),
          )
          .toList();
      expect(after[7].transform.storage[0], closeTo(1.0, 0.001));
    });

    testWidgets('half stars: left half picks x.5', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(
        _wrap(_Harness(allowHalf: true, onChanged: changes.add)),
      );
      await tester.tapAt(_starCenter(tester, 2, dx: -7));
      await tester.pumpAndSettle();
      expect(changes, <double>[2.5]);
      expect(_fill(tester, 2), 0.5);
      await tester.tapAt(_starCenter(tester, 2, dx: 7));
      await tester.pumpAndSettle();
      expect(changes.last, 3.0);
    });

    testWidgets('touch drag previews and commits on release', (
      WidgetTester tester,
    ) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      final TestGesture touch = await tester.startGesture(
        _starCenter(tester, 0),
      );
      await touch.moveTo(_starCenter(tester, 2));
      await tester.pump();
      await touch.moveTo(_starCenter(tester, 4));
      await tester.pump();
      expect(_fill(tester, 4), 1.0);
      await touch.up();
      await tester.pumpAndSettle();
      expect(changes, <double>[5.0]);
    });

    testWidgets('keyboard arrows change the value by a step', (
      WidgetTester tester,
    ) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(
        _wrap(_Harness(allowHalf: true, onChanged: changes.add)),
      );
      Focus.of(
        tester.element(
          find.descendant(of: _rating, matching: find.byType(Row)),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changes, <double>[2.5, 2.0, 1.5, 5.0, 0.0]);
    });

    testWidgets('semantics: slider with "x of 5" and actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<double> changes = <double>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      final Finder node = find.bySemanticsLabel('Rating');
      expect(
        tester.getSemantics(node),
        isSemantics(
          isSlider: true,
          label: 'Rating',
          value: '2 of 5',
          increasedValue: '3 of 5',
          decreasedValue: '1 of 5',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Rating'));
      await tester.pumpAndSettle();
      expect(changes, <double>[3.0]);
      expect(tester.getSemantics(node), isSemantics(value: '3 of 5'));
      handle.dispose();
    });

    testWidgets('readOnly and disabled ignore input', (
      WidgetTester tester,
    ) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(
        _wrap(_Harness(readOnly: true, onChanged: changes.add)),
      );
      await tester.tapAt(_starCenter(tester, 4));
      await tester.pump();
      expect(changes, isEmpty);

      await tester.pumpWidget(
        _wrap(const PeekRating(value: 3, onChanged: null)),
      );
      await tester.tapAt(_starCenter(tester, 4));
      await tester.pump();
      expect(
        find.descendant(of: _rating, matching: find.byType(Opacity)),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion: preview recolors without wave or pop', (
      WidgetTester tester,
    ) async {
      final List<double> changes = <double>[];
      await tester.pumpWidget(
        _wrap(_Harness(onChanged: changes.add), reducedMotion: true),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_starCenter(tester, 4));
      await tester.pump();
      expect(_fill(tester, 4), 1.0);
      expect(_lifts(tester).every((double l) => l == 0.0), isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tapAt(_starCenter(tester, 4));
      await tester.pump();
      expect(changes, <double>[5.0]);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await mouse.removePointer();
    });

    testWidgets('disposing mid-wave and mid-pop does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_starCenter(tester, 4));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tapAt(_starCenter(tester, 4));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    });

    testWidgets('changing count mid-wave does not throw', (
      WidgetTester tester,
    ) async {
      double count = 5;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setOuter = setState;
              return PeekRating(
                value: 2,
                count: count.toInt(),
                onChanged: (_) {},
              );
            },
          ),
        ),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(_starCenter(tester, 4));
      await tester.pump(const Duration(milliseconds: 20));
      setOuter(() => count = 3);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_lifts(tester), hasLength(3));
      await mouse.removePointer();
    });
  });
}
