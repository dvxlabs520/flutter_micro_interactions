import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/jelly_radio.dart';
import 'package:flutter_test/flutter_test.dart';

const List<JellyRadioItem<String>> _items = <JellyRadioItem<String>>[
  JellyRadioItem<String>(value: 'xs', label: Text('XS')),
  JellyRadioItem<String>(value: 's', label: Text('Small')),
  JellyRadioItem<String>(value: 'm', label: Text('Medium')),
  JellyRadioItem<String>(value: 'l', label: Text('Large')),
];

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
  required List<String> calls,
  String? initial = 'xs',
  bool accept = true,
  bool reduced = false,
  Axis direction = Axis.horizontal,
  bool wrap = false,
}) async {
  String? value = initial;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return _wrap(
          JellyRadioGroup<String>(
            items: _items,
            value: value,
            direction: direction,
            wrap: wrap,
            onChanged: (String v) {
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

Finder _chip(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(CustomPaint))
    .first;

Rect _rect(WidgetTester tester, String text) => tester.getRect(_chip(text));

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(JellyRadioGroup<String>))).colorScheme;

/// Bounds of the selected fill painted inside the chip labelled [text].
Rect? _fillBounds(WidgetTester tester, String text) {
  Rect? bounds;
  final int fill = _scheme(tester).primary.toARGB32();
  expect(
    tester.renderObject(_chip(text)),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #drawPath) {
        final Paint paint = args[1] as Paint;
        if (paint.style == PaintingStyle.fill &&
            paint.color.toARGB32() == fill) {
          bounds = (args[0] as Path).getBounds();
        }
      }
      return true;
    }),
  );
  return bounds;
}

int _focusRings(WidgetTester tester, String text) {
  int count = 0;
  final int primary = _scheme(tester).primary.toARGB32();
  expect(
    tester.renderObject(_chip(text)),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #drawPath) {
        final Paint paint = args[1] as Paint;
        if (paint.style == PaintingStyle.stroke &&
            paint.strokeWidth == 2.0 &&
            paint.color.toARGB32() == primary) {
          count++;
        }
      }
      return true;
    }),
  );
  return count;
}

void main() {
  group('JellyRadioGroup', () {
    testWidgets('renders with the selected chip swollen and filled', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <String>[], initial: 'm');
      final Size medium = tester.getSize(_chip('Medium'));
      final Rect painted = _rect(tester, 'Medium');
      expect(painted.width / medium.width, closeTo(1.08, 0.001));
      expect(
        _rect(tester, 'Small').width,
        closeTo(tester.getSize(_chip('Small')).width, 0.001),
      );
      expect(_fillBounds(tester, 'Medium'), isNotNull);
      expect(_fillBounds(tester, 'Small'), isNull);
      // Tap targets are at least 48 by 48.
      for (final JellyRadioItem<String> item in _items) {
        final Finder target = find
            .ancestor(
              of: find.text((item.label as Text).data!),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('null value selects nothing', (WidgetTester tester) async {
      await _pumpHost(tester, calls: <String>[], initial: null);
      for (final String label in <String>['XS', 'Small', 'Medium', 'Large']) {
        expect(_fillBounds(tester, label), isNull);
      }
    });

    testWidgets('tap requests a value; nothing moves until rebuild', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls, accept: false);
      final Rect before = _rect(tester, 'Medium');
      await tester.tap(find.text('Medium'));
      await tester.tap(find.text('XS'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, <String>['m']);
      expect(_rect(tester, 'Medium'), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('selected chip swells with jelly overshoot and wobble', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls);
      final Size base = tester.getSize(_chip('Medium'));
      await tester.tap(find.text('Medium'));
      await tester.pump();
      double maxScale = 0;
      double maxWobble = 0;
      double? minFillWidth;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final Rect r = _rect(tester, 'Medium');
        final double sx = r.width / base.width;
        final double sy = r.height / base.height;
        if (sx > maxScale) maxScale = sx;
        if ((sx - sy).abs() > maxWobble) maxWobble = (sx - sy).abs();
        if (i == 0) {
          minFillWidth = _fillBounds(tester, 'Medium')?.width;
        }
      }
      expect(maxScale, greaterThan(1.08));
      expect(maxWobble, greaterThan(0.005));
      // The fill starts small and centered.
      expect(minFillWidth, isNotNull);
      expect(minFillWidth, lessThan(base.width * 0.9));

      await tester.pumpAndSettle();
      expect(_rect(tester, 'Medium').width / base.width, closeTo(1.08, 0.001));
      // The previous chip shrank back and lost its fill.
      expect(
        _rect(tester, 'XS').width,
        closeTo(tester.getSize(_chip('XS')).width, 0.001),
      );
      expect(_fillBounds(tester, 'XS'), isNull);
    });

    testWidgets('fill grows from the center of the chip', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <String>[]);
      await tester.tap(find.text('Large'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final Rect fill = _fillBounds(tester, 'Large')!;
      final Size chip = tester.getSize(_chip('Large'));
      expect(fill.width, lessThan(chip.width));
      expect(fill.center.dx, closeTo(chip.width / 2, 0.5));
      expect(fill.center.dy, closeTo(chip.height / 2, 0.5));
      await tester.pumpAndSettle();
    });

    testWidgets('neighbours are pushed outward, then spring back', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls);
      final double xs = _rect(tester, 'XS').center.dx;
      final double small = _rect(tester, 'Small').center.dx;
      final double large = _rect(tester, 'Large').center.dx;
      await tester.tap(find.text('Medium'));
      await tester.pump();
      double minSmall = small;
      double maxLarge = large;
      double minXs = xs;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        final double s = _rect(tester, 'Small').center.dx;
        final double l = _rect(tester, 'Large').center.dx;
        final double x = _rect(tester, 'XS').center.dx;
        if (s < minSmall) minSmall = s;
        if (l > maxLarge) maxLarge = l;
        if (x < minXs) minXs = x;
      }
      // Direct neighbours move about pushDistance (6) away.
      expect(small - minSmall, closeTo(6, 1.0));
      expect(maxLarge - large, closeTo(6, 1.0));
      // The chip two places away moves less.
      expect(xs - minXs, greaterThan(0.5));
      expect(xs - minXs, lessThan(small - minSmall));

      await tester.pumpAndSettle();
      expect(_rect(tester, 'Small').center.dx, closeTo(small, 0.01));
      expect(_rect(tester, 'Large').center.dx, closeTo(large, 0.01));
      expect(_rect(tester, 'XS').center.dx, closeTo(xs, 0.01));
    });

    testWidgets('vertical direction pushes along the vertical axis', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <String>[], direction: Axis.vertical);
      final Rect small = _rect(tester, 'Small');
      await tester.tap(find.text('Medium'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final Rect moved = _rect(tester, 'Small');
      expect(moved.center.dy, lessThan(small.center.dy));
      expect(moved.center.dx, closeTo(small.center.dx, 0.01));
      await tester.pumpAndSettle();
    });

    testWidgets('wrap lays chips out in a Wrap', (WidgetTester tester) async {
      await _pumpHost(tester, calls: <String>[], wrap: true);
      expect(
        find.descendant(
          of: find.byType(JellyRadioGroup<String>),
          matching: find.byType(Wrap),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keyboard: focus ring, arrows wrap, Space picks first', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls, initial: null);
      expect(_focusRings(tester, 'XS'), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusRings(tester, 'XS'), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, <String>['xs']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(calls, <String>['xs', 'l']);
      expect(_focusRings(tester, 'Large'), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(calls, <String>['xs', 'l', 'xs', 's']);
    });

    testWidgets('semantics: checked members of an exclusive group', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls);
      expect(
        tester.getSemantics(find.text('XS')),
        isSemantics(
          label: 'XS',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Large')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      tester.semantics.tap(find.semantics.byLabel('Large'));
      await tester.pumpAndSettle();
      expect(calls, <String>['l']);
      handle.dispose();
    });

    testWidgets('disabled: dimmed and inert', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JellyRadioGroup<String>(
            items: _items,
            value: 's',
            onChanged: null,
          ),
        ),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(JellyRadioGroup<String>),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(1.0));
      expect(
        tester.getSemantics(find.text('Small')),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      handle.dispose();

      final List<String> calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          JellyRadioGroup<String>(
            items: _items,
            value: 's',
            enabled: false,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.tap(find.text('Large'), warnIfMissed: false);
      await tester.pump();
      expect(calls, isEmpty);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: instant, no push, no frames', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls, reduced: true);
      final double small = _rect(tester, 'Small').center.dx;
      await tester.tap(find.text('Medium'));
      await tester.pump();
      expect(calls, <String>['m']);
      expect(
        _rect(tester, 'Medium').width / tester.getSize(_chip('Medium')).width,
        closeTo(1.08, 0.001),
      );
      expect(_rect(tester, 'Small').center.dx, closeTo(small, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rapid changes, item changes and dispose do not throw', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(find.text('Medium'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Small'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(calls, <String>['m', 's', 'l']);
      expect(_fillBounds(tester, 'Medium'), isNull);
      expect(_fillBounds(tester, 'Small'), isNull);
      expect(_fillBounds(tester, 'Large'), isNotNull);

      await tester.pumpWidget(
        _wrap(
          JellyRadioGroup<String>(
            items: _items,
            value: 'xs',
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(
        _wrap(
          JellyRadioGroup<String>(
            items: _items.sublist(0, 2),
            value: 's',
            spacing: 12,
            selectedScale: 1.2,
            spring: const SpringDescription(
              mass: 1,
              stiffness: 200,
              damping: 10,
            ),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(
        _wrap(
          JellyRadioGroup<String>(items: _items, value: 'l', onChanged: (_) {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
