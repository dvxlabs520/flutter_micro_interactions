import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/squish_switch.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduced = false, TextDirection? direction}) {
  Widget app = MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
  if (direction != null) {
    app = MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }
  if (reduced) {
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }
  return app;
}

/// Pumps a switch whose parent stores the value when [accept] is true.
/// Every requested value is appended to [calls].
Future<void> _pumpHost(
  WidgetTester tester, {
  required List<bool> calls,
  bool initial = false,
  bool accept = true,
  bool reduced = false,
  TextDirection? direction,
}) async {
  bool value = initial;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return _wrap(
          SquishSwitch(
            value: value,
            semanticLabel: 'Wi-Fi',
            onChanged: (bool v) {
              calls.add(v);
              if (accept) setState(() => value = v);
            },
          ),
          reduced: reduced,
          direction: direction,
        );
      },
    ),
  );
}

Finder get _paint => find
    .descendant(
      of: find.byType(SquishSwitch),
      matching: find.byType(CustomPaint),
    )
    .first;

/// Filled rounded rectangles in paint order: the track, then the thumb.
List<RRect> _fills(WidgetTester tester) {
  final List<RRect> fills = <RRect>[];
  expect(
    tester.renderObject(_paint),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #drawRRect &&
          (args[1] as Paint).style == PaintingStyle.fill) {
        fills.add(args[0] as RRect);
      }
      return true;
    }),
  );
  return fills;
}

/// Stroked rounded rectangles: the off outline and the focus ring.
int _strokeCount(WidgetTester tester, Color color) {
  int count = 0;
  expect(
    tester.renderObject(_paint),
    paints..everything((Symbol method, List<dynamic> args) {
      final Paint paint = args.isNotEmpty && args.last is Paint
          ? args.last as Paint
          : Paint();
      if (method == #drawRRect &&
          paint.style == PaintingStyle.stroke &&
          paint.color.toARGB32() == color.toARGB32()) {
        count++;
      }
      return true;
    }),
  );
  return count;
}

/// Drags slowly through each horizontal [legs] distance (5 px every 50 ms),
/// then optionally flicks by [flick] pixels within 30 ms, then releases.
Future<void> _slowDrag(
  WidgetTester tester,
  Offset start,
  List<double> legs, {
  double flick = 0,
}) async {
  int ms = 0;
  final TestGesture gesture = await tester.startGesture(start);
  for (final double leg in legs) {
    final int steps = (leg.abs() / 5).ceil();
    for (int i = 0; i < steps; i++) {
      ms += 50;
      await gesture.moveBy(
        Offset(leg / steps, 0),
        timeStamp: Duration(milliseconds: ms),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  if (flick != 0) {
    for (int i = 0; i < 4; i++) {
      ms += 8;
      await gesture.moveBy(
        Offset(flick / 4, 0),
        timeStamp: Duration(milliseconds: ms),
      );
    }
  }
  await gesture.up(timeStamp: Duration(milliseconds: ms));
}

Rect _thumb(WidgetTester tester) => _fills(tester)[1].outerRect;

Rect _track(WidgetTester tester) => _fills(tester)[0].outerRect;

void main() {
  group('SquishSwitch', () {
    testWidgets('renders off and on at rest with a 24 px round thumb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SquishSwitch(value: false, onChanged: (_) {})),
      );
      final Rect track = _track(tester);
      expect(track.size, const Size(52, 32));
      Rect thumb = _thumb(tester);
      expect(thumb.width, closeTo(24, 0.01));
      expect(thumb.height, closeTo(24, 0.01));
      expect(thumb.center.dx, closeTo(track.left + 16, 0.01));

      await tester.pumpWidget(
        _wrap(SquishSwitch(value: true, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      thumb = _thumb(tester);
      expect(thumb.center.dx, closeTo(track.right - 16, 0.01));
    });

    testWidgets('tap requests the opposite value; only moves on rebuild', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls, accept: false);
      final Rect before = _thumb(tester);
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump();
      expect(calls, <bool>[true]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_thumb(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // When the parent accepts, the thumb travels to the on side.
      final List<bool> accepted = <bool>[];
      await _pumpHost(tester, calls: accepted);
      await tester.tap(find.byType(SquishSwitch));
      await tester.pumpAndSettle();
      expect(accepted, <bool>[true]);
      expect(
        _thumb(tester).center.dx,
        closeTo(_track(tester).right - 16, 0.01),
      );
    });

    testWidgets('thumb stretches while moving and squashes on arrival', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump();

      double maxWidth = 0;
      double minHeightWhileStretched = double.infinity;
      double minWidth = double.infinity;
      double maxHeight = 0;
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final Rect thumb = _thumb(tester);
        if (thumb.width > maxWidth) {
          maxWidth = thumb.width;
          minHeightWhileStretched = thumb.height;
        }
        if (thumb.width < minWidth) minWidth = thumb.width;
        if (thumb.height > maxHeight) maxHeight = thumb.height;
      }
      // Stretch: wider and flatter than at rest while travelling.
      expect(maxWidth, greaterThan(24 * 1.1));
      expect(minHeightWhileStretched, lessThan(24));
      // Squash: narrower and taller than at rest against the end wall.
      expect(minWidth, lessThan(24 * 0.95));
      expect(maxHeight, greaterThan(24));
      // Never leaves the track.
      final Rect track = _track(tester);
      expect(maxHeight, lessThanOrEqualTo(track.height));

      await tester.pumpAndSettle();
      expect(_thumb(tester).width, closeTo(24, 0.01));
    });

    testWidgets('slow drag decides by position', (WidgetTester tester) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      final Offset center = tester.getCenter(find.byType(SquishSwitch));

      // Out and nearly all the way back, slowly: stays off.
      await _slowDrag(tester, center, <double>[30, -25]);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(_thumb(tester).center.dx, closeTo(_track(tester).left + 16, 0.01));

      // A slow drag past the middle turns it on.
      await _slowDrag(tester, center, <double>[25]);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);
      expect(
        _thumb(tester).center.dx,
        closeTo(_track(tester).right - 16, 0.01),
      );
    });

    testWidgets('drag follows the finger with stretch', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      final double restX = _thumb(tester).center.dx;
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SquishSwitch)),
      );
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final Rect moving = _thumb(tester);
      expect(moving.center.dx, greaterThan(restX));
      expect(moving.width, greaterThan(24));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a quick flick decides by velocity, not position', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      await tester.fling(find.byType(SquishSwitch), const Offset(30, 0), 800);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);

      // Drag far to the off side slowly, then flick back towards on: the
      // finger ends on the off half, but the flick wins.
      final Offset center = tester.getCenter(find.byType(SquishSwitch));
      await _slowDrag(tester, center, <double>[-40], flick: 24);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);
      expect(
        _thumb(tester).center.dx,
        closeTo(_track(tester).right - 16, 0.01),
      );

      // And the other way: ends on the on half, flicked towards off.
      await _slowDrag(tester, center, <double>[10], flick: -24);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false]);
      expect(_thumb(tester).center.dx, closeTo(_track(tester).left + 16, 0.01));
    });

    testWidgets('springs back when the parent rejects a dragged value', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls, accept: false);
      await _slowDrag(
        tester,
        tester.getCenter(find.byType(SquishSwitch)),
        <double>[30],
      );
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);
      expect(_thumb(tester).center.dx, closeTo(_track(tester).left + 16, 0.01));
    });

    testWidgets('RTL: on is on the left and drags are mirrored', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls, direction: TextDirection.rtl);
      expect(
        _thumb(tester).center.dx,
        closeTo(_track(tester).right - 16, 0.01),
      );
      await tester.fling(find.byType(SquishSwitch), const Offset(-30, 0), 800);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);
      expect(_thumb(tester).center.dx, closeTo(_track(tester).left + 16, 0.01));
    });

    testWidgets('keyboard: focus ring, Space/Enter toggle, arrows set side', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      final Color primary = Theme.of(
        tester.element(find.byType(SquishSwitch)),
      ).colorScheme.primary;
      expect(_strokeCount(tester, primary), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_strokeCount(tester, primary), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false]);

      // Left while off does nothing; right turns it on.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false, true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false, true, false]);
    });

    testWidgets('semantics expose toggled state, label and tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls, initial: true);
      expect(
        tester.getSemantics(find.byType(SquishSwitch)),
        isSemantics(
          label: 'Wi-Fi',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Wi-Fi'));
      await tester.pumpAndSettle();
      expect(calls, <bool>[false]);
      handle.dispose();
    });

    testWidgets('tap target is at least 48 by 48', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(SquishSwitch(value: false, onChanged: (_) {})),
      );
      final Size size = tester.getSize(find.byType(SquishSwitch));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('disabled: dimmed, ignores input, semantics disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const SquishSwitch(value: false, onChanged: null)),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SquishSwitch),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));
      expect(
        tester.getSemantics(find.byType(SquishSwitch)),
        isSemantics(
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();

      bool called = false;
      await tester.pumpWidget(
        _wrap(
          SquishSwitch(
            value: false,
            enabled: false,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(SquishSwitch), warnIfMissed: false);
      await tester.fling(find.byType(SquishSwitch), const Offset(30, 0), 800);
      await tester.pump();
      expect(called, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: instant change, no stretch, no frames', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls, reduced: true);
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump();
      expect(calls, <bool>[true]);
      final Rect thumb = _thumb(tester);
      expect(thumb.width, closeTo(24, 0.01));
      expect(thumb.center.dx, closeTo(_track(tester).right - 16, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rapid toggles mid-animation reverse smoothly', (
      WidgetTester tester,
    ) async {
      final List<bool> calls = <bool>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final double mid = _thumb(tester).center.dx;
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // Continues from where it was rather than jumping.
      expect((_thumb(tester).center.dx - mid).abs(), lessThan(6));
      await tester.tap(find.byType(SquishSwitch));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      expect(calls, <bool>[true, false, true]);
      expect(
        _thumb(tester).center.dx,
        closeTo(_track(tester).right - 16, 0.01),
      );
    });

    testWidgets('config changes and dispose mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SquishSwitch(value: false, onChanged: (_) {})),
      );
      await tester.pumpWidget(
        _wrap(SquishSwitch(value: true, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(
        _wrap(
          SquishSwitch(
            value: true,
            size: const Size(60, 36),
            stretch: 2,
            activeColor: Colors.green,
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
