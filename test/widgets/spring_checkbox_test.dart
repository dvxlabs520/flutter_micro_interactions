import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/spring_checkbox.dart';
import 'package:flutter_test/flutter_test.dart';

const String _labelText = 'Water the plants';

Widget _wrap(Widget child, {bool reduced = false}) {
  final Widget app = MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
  if (reduced) {
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }
  return app;
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<bool?> calls,
  bool? initial = false,
  bool accept = true,
  bool reduced = false,
  bool tristate = false,
  bool strikeThrough = true,
}) async {
  bool? value = initial;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return _wrap(
          SpringCheckbox(
            value: value,
            tristate: tristate,
            strikeThrough: strikeThrough,
            label: const Text(_labelText),
            onChanged: (bool? v) {
              calls.add(v);
              if (accept) setState(() => value = v);
            },
          ),
          reduced: reduced,
        );
      },
    ),
  );
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SpringCheckbox))).colorScheme;

Finder get _box => find
    .descendant(
      of: find.byType(SpringCheckbox),
      matching: find.byType(CustomPaint),
    )
    .first;

Finder get _labelPaint => find
    .ancestor(of: find.text(_labelText), matching: find.byType(CustomPaint))
    .first;

/// What the box painter currently draws.
class _BoxFrame {
  bool filled = false;
  double fillScale = 1.0;
  Rect? mark;
  int focusRings = 0;
}

_BoxFrame _boxFrame(WidgetTester tester) {
  final _BoxFrame frame = _BoxFrame();
  final ColorScheme scheme = _scheme(tester);
  expect(
    tester.renderObject(_box),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #scale) {
        frame.fillScale = args[0] as double;
      }
      if (method == #drawRRect) {
        final Paint paint = args[1] as Paint;
        if (paint.style == PaintingStyle.fill &&
            paint.color.toARGB32() == scheme.primary.toARGB32()) {
          frame.filled = true;
        }
        if (paint.style == PaintingStyle.stroke &&
            paint.color.toARGB32() == scheme.primary.toARGB32() &&
            (args[0] as RRect).width > 22) {
          frame.focusRings++;
        }
      }
      if (method == #drawPath) {
        final Paint paint = args[1] as Paint;
        if (paint.color.toARGB32() == scheme.onPrimary.toARGB32()) {
          frame.mark = (args[0] as Path).getBounds();
        }
      }
      return true;
    }),
  );
  return frame;
}

/// Length of the strike-through line, or 0 when none is drawn.
double _strike(WidgetTester tester) {
  double length = 0;
  expect(
    tester.renderObject(_labelPaint),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #drawLine) {
        length = ((args[1] as Offset) - (args[0] as Offset)).distance;
      }
      return true;
    }),
  );
  return length;
}

double _labelOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(SpringCheckbox),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  group('SpringCheckbox', () {
    testWidgets('renders unchecked and checked at rest', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <bool?>[]);
      _BoxFrame frame = _boxFrame(tester);
      expect(frame.filled, isFalse);
      expect(frame.mark, isNull);
      expect(_strike(tester), 0);
      expect(_labelOpacity(tester), 1.0);
      final Size box = tester.getSize(
        find
            .descendant(
              of: find.byType(SpringCheckbox),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));

      await _pumpHost(tester, calls: <bool?>[], initial: true);
      await tester.pumpAndSettle();
      frame = _boxFrame(tester);
      expect(frame.filled, isTrue);
      expect(frame.mark, isNotNull);
      expect(_strike(tester), closeTo(tester.getSize(_labelPaint).width, 0.01));
      expect(_labelOpacity(tester), closeTo(0.55, 0.001));
    });

    testWidgets('tapping box or label requests a toggle; controlled', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls, accept: false);
      await tester.tap(_box);
      await tester.tap(find.text(_labelText));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, <bool?>[true, true]);
      expect(_boxFrame(tester).filled, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('one spring sequences fill, then tick, then strike', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(find.text(_labelText));
      await tester.pump();

      int? fillFrame;
      int? tickFrame;
      int? strikeFrame;
      double maxFillScale = 0;
      Rect? tickAtStrikeStart;
      bool strikeBeforeTick = false;
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        final _BoxFrame frame = _boxFrame(tester);
        final double strike = _strike(tester);
        if (frame.filled) {
          fillFrame ??= i;
          if (frame.fillScale > maxFillScale) maxFillScale = frame.fillScale;
        }
        if (frame.mark != null) tickFrame ??= i;
        if (strike > 0) {
          if (strikeFrame == null) tickAtStrikeStart = frame.mark;
          strikeFrame ??= i;
          if (frame.mark == null) strikeBeforeTick = true;
        }
      }
      expect(calls, <bool?>[true]);
      expect(fillFrame, isNotNull);
      expect(tickFrame, greaterThan(fillFrame!));
      expect(strikeFrame, greaterThan(tickFrame!));
      expect(strikeBeforeTick, isFalse);
      // The fill scales in with a small overshoot.
      expect(maxFillScale, greaterThan(1.0));

      await tester.pumpAndSettle();
      final Rect fullTick = _boxFrame(tester).mark!;
      // The tick is complete by the time the strike starts.
      expect(tickAtStrikeStart!.width, closeTo(fullTick.width, 0.01));
      expect(_labelOpacity(tester), closeTo(0.55, 0.001));
    });

    testWidgets('unchecking plays the sequence backwards', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls, initial: true);
      await tester.pumpAndSettle();
      await tester.tap(_box);
      await tester.pump();
      int? strikeGone;
      int? tickGone;
      int? fillGone;
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        final _BoxFrame frame = _boxFrame(tester);
        if (_strike(tester) == 0) strikeGone ??= i;
        if (frame.mark == null) tickGone ??= i;
        if (!frame.filled) fillGone ??= i;
      }
      expect(calls, <bool?>[false]);
      expect(strikeGone, isNotNull);
      expect(tickGone, greaterThan(strikeGone!));
      expect(fillGone, greaterThan(tickGone!));
      await tester.pumpAndSettle();
      expect(_labelOpacity(tester), 1.0);
    });

    testWidgets('tristate cycles false, true, null and shows a dash', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls, tristate: true);
      await tester.tap(_box);
      await tester.pumpAndSettle();
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(calls, <bool?>[true, null]);
      final Rect dash = _boxFrame(tester).mark!;
      expect(dash.height, lessThan(0.5));
      expect(dash.width, greaterThan(10));
      expect(_strike(tester), 0);
      expect(_labelOpacity(tester), 1.0);

      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(calls, <bool?>[true, null, false]);
      expect(_boxFrame(tester).filled, isFalse);

      // Checking again draws a tick, not a dash.
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(_boxFrame(tester).mark!.height, greaterThan(4));
    });

    testWidgets('keyboard: focus ring, Space and Enter toggle', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls);
      expect(_boxFrame(tester).focusRings, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_boxFrame(tester).focusRings, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, <bool?>[true, false]);
    });

    testWidgets('semantics: one checkbox node with the label text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls, tristate: true, initial: null);
      expect(
        tester.getSemantics(find.byType(SpringCheckbox)),
        isSemantics(
          label: _labelText,
          hasCheckedState: true,
          isChecked: false,
          isCheckStateMixed: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel(_labelText));
      await tester.pumpAndSettle();
      expect(calls, <bool?>[false]);
      expect(
        tester.getSemantics(find.byType(SpringCheckbox)),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      handle.dispose();

      final SemanticsHandle handle2 = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SpringCheckbox(
            value: true,
            semanticLabel: 'Done',
            label: const Text(_labelText),
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SpringCheckbox)),
        isSemantics(label: 'Done', isChecked: true),
      );
      handle2.dispose();
    });

    testWidgets('disabled: dimmed and inert', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const SpringCheckbox(
            value: false,
            onChanged: null,
            label: Text(_labelText),
          ),
        ),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SpringCheckbox),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));
      expect(
        tester.getSemantics(find.byType(SpringCheckbox)),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      handle.dispose();

      final List<bool?> calls = <bool?>[];
      await tester.pumpWidget(
        _wrap(
          SpringCheckbox(
            value: false,
            enabled: false,
            onChanged: calls.add,
            label: const Text(_labelText),
          ),
        ),
      );
      await tester.tap(find.text(_labelText), warnIfMissed: false);
      await tester.pump();
      expect(calls, isEmpty);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: instant, no frames', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls, reduced: true);
      await tester.tap(_box);
      await tester.pump();
      final _BoxFrame frame = _boxFrame(tester);
      expect(frame.filled, isTrue);
      expect(frame.fillScale, 1.0);
      expect(frame.mark, isNotNull);
      expect(_strike(tester), closeTo(tester.getSize(_labelPaint).width, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('strikeThrough false never strikes or dims', (
      WidgetTester tester,
    ) async {
      await _pumpHost(
        tester,
        calls: <bool?>[],
        initial: true,
        strikeThrough: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SpringCheckbox),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(_boxFrame(tester).mark, isNotNull);
    });

    testWidgets('rapid toggles, config changes and dispose', (
      WidgetTester tester,
    ) async {
      final List<bool?> calls = <bool?>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(_box);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(_box);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(_box);
      await tester.pumpAndSettle();
      expect(calls, <bool?>[true, false, true]);
      expect(_boxFrame(tester).mark, isNotNull);
      expect(_strike(tester), greaterThan(0));

      await tester.pumpWidget(
        _wrap(SpringCheckbox(value: false, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(
        _wrap(
          SpringCheckbox(
            value: true,
            size: 30,
            borderRadius: 2,
            activeColor: Colors.green,
            dimmedLabelOpacity: 0.3,
            onChanged: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
