import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/orbit_items.dart';
import 'package:flutter_test/flutter_test.dart';

List<Key> _keys(int count) =>
    List<Key>.generate(count, (int i) => ValueKey<String>('item$i'));

List<Widget> _items(int count, {Size size = const Size(40, 40)}) {
  return <Widget>[
    for (final Key key in _keys(count))
      SizedBox(
        key: key,
        width: size.width,
        height: size.height,
        child: const ColoredBox(color: Color(0xFF2196F3)),
      ),
  ];
}

/// A 300 x 300 orbit at the top-left corner of the screen.
Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, height: 300, child: child),
      ),
    ),
  );
}

Offset _center(WidgetTester tester, int i) =>
    tester.getCenter(find.byKey(ValueKey<String>('item$i')));

Matcher _near(Offset expected) => isA<Offset>()
    .having(
      (Offset o) => o.dx,
      'dx',
      moreOrLessEquals(expected.dx, epsilon: 0.01),
    )
    .having(
      (Offset o) => o.dy,
      'dy',
      moreOrLessEquals(expected.dy, epsilon: 0.01),
    );

Future<void> _dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  group('OrbitItems', () {
    testWidgets('places items evenly on a circle, first at the top', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrbitItems(children: _items(4))));
      // Default radius keeps 40 px items inside 300 px: (300 - 40) / 2.
      expect(_center(tester, 0), _near(const Offset(150, 20)));
      expect(_center(tester, 1), _near(const Offset(280, 150)));
      expect(_center(tester, 2), _near(const Offset(150, 280)));
      expect(_center(tester, 3), _near(const Offset(20, 150)));
      await _dispose(tester);
    });

    testWidgets('advances over time, clockwise by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrbitItems(duration: const Duration(seconds: 4), children: _items(4)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final Offset halfway = _center(tester, 0);
      // An eighth of a turn clockwise from the top: upper right.
      expect(halfway.dx, greaterThan(150));
      expect(halfway.dy, lessThan(150));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_center(tester, 0), _near(const Offset(280, 150)));
      expect(_center(tester, 3), _near(const Offset(150, 20)));
      await _dispose(tester);
    });

    testWidgets('counter-clockwise moves the other way', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            clockwise: false,
            duration: const Duration(seconds: 4),
            children: _items(4),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_center(tester, 0), _near(const Offset(20, 150)));
      await _dispose(tester);
    });

    testWidgets('ellipse spaces items by equal arc length', (
      WidgetTester tester,
    ) async {
      const double rx = 130;
      const double ry = 50;
      const int count = 7;
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            shape: OrbitShape.ellipse,
            radiusX: rx,
            radiusY: ry,
            children: _items(count),
          ),
        ),
      );
      double paramOf(Offset p) =>
          math.atan2((p.dy - 150) / ry, (p.dx - 150) / rx);
      double arc(double from, double to) {
        if (to < from) to += 2 * math.pi;
        double length = 0;
        const int steps = 2000;
        for (int s = 0; s < steps; s++) {
          final double t = from + (to - from) * (s + 0.5) / steps;
          length +=
              math.sqrt(
                math.pow(rx * math.sin(t), 2) + math.pow(ry * math.cos(t), 2),
              ) *
              (to - from) /
              steps;
        }
        return length;
      }

      final List<double> arcs = <double>[];
      for (int i = 0; i < count; i++) {
        arcs.add(
          arc(
            paramOf(_center(tester, i)),
            paramOf(_center(tester, (i + 1) % count)),
          ),
        );
      }
      final double mean = arcs.reduce((double a, double b) => a + b) / count;
      for (final double a in arcs) {
        expect(a, moreOrLessEquals(mean, epsilon: mean * 0.005));
      }
      await _dispose(tester);
    });

    testWidgets('custom path: items follow the path by arc length', (
      WidgetTester tester,
    ) async {
      // Perimeter 600, three items 200 apart.
      final Path path = Path()..addRect(const Rect.fromLTWH(20, 20, 200, 100));
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            path: path,
            duration: const Duration(seconds: 6),
            children: _items(3),
          ),
        ),
      );
      expect(_center(tester, 0), _near(const Offset(20, 20)));
      expect(_center(tester, 1), _near(const Offset(220, 20)));
      expect(_center(tester, 2), _near(const Offset(120, 120)));
      await tester.pump(const Duration(milliseconds: 500));
      // 50 px along the top edge.
      expect(_center(tester, 0), _near(const Offset(70, 20)));
      await _dispose(tester);
    });

    testWidgets('depth: back items shrink and sit behind the center', (
      WidgetTester tester,
    ) async {
      int centerTaps = 0;
      final List<int> itemTaps = <int>[0, 0];
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            shape: OrbitShape.ellipse,
            depth: true,
            enabled: false,
            center: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => centerTaps++,
              child: const SizedBox(width: 300, height: 300),
            ),
            children: <Widget>[
              for (int i = 0; i < 2; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => itemTaps[i]++,
                  child: SizedBox(
                    key: ValueKey<String>('item$i'),
                    width: 40,
                    height: 40,
                  ),
                ),
            ],
          ),
        ),
      );
      final Rect back = tester.getRect(
        find.byKey(const ValueKey<String>('item0')),
      );
      final Rect front = tester.getRect(
        find.byKey(const ValueKey<String>('item1')),
      );
      expect(back.width, moreOrLessEquals(32.0));
      expect(front.width, moreOrLessEquals(40.0));
      expect(back.center.dy, lessThan(front.center.dy));

      // The back item is covered by the center, the front item is on top.
      await tester.tapAt(back.center);
      expect(centerTaps, 1);
      expect(itemTaps[0], 0);
      await tester.tapAt(front.center);
      expect(itemTaps[1], 1);
      expect(centerTaps, 1);
    });

    testWidgets('without depth items paint above the center', (
      WidgetTester tester,
    ) async {
      int itemTaps = 0;
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            enabled: false,
            center: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const SizedBox(width: 300, height: 300),
            ),
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => itemTaps++,
                child: const SizedBox(
                  key: ValueKey<String>('item0'),
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('item0')));
      expect(itemTaps, 1);
    });

    testWidgets('rotateItems follows the tangent', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            rotateItems: true,
            enabled: false,
            children: _items(4, size: const Size(40, 20)),
          ),
        ),
      );
      Rect rectOf(int i) =>
          tester.getRect(find.byKey(ValueKey<String>('item$i')));
      // Top: moving right, upright. Right side: moving down, turned 90 deg.
      expect(rectOf(0).size, _sizeNear(const Size(40, 20)));
      expect(rectOf(1).size, _sizeNear(const Size(20, 40)));
    });

    testWidgets('pauses on hover and resumes when the mouse leaves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrbitItems(children: _items(4))));
      await tester.pump(const Duration(milliseconds: 100));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(600, 500));
      await mouse.moveTo(const Offset(150, 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final Offset paused = _center(tester, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(_center(tester, 0), paused);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await mouse.moveTo(const Offset(600, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_center(tester, 0), isNot(paused));
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('pause eases instead of stopping instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrbitItems(duration: const Duration(seconds: 4), children: _items(4)),
        ),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(600, 500));
      await mouse.moveTo(const Offset(150, 150));
      await tester.pump();
      final Offset before = _center(tester, 0);
      await tester.pump(const Duration(milliseconds: 100));
      // Still moving during the ease-out.
      expect(_center(tester, 0), isNot(before));
      await mouse.removePointer();
      await _dispose(tester);
    });

    testWidgets('children stay tappable while orbiting', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            pauseOnHover: false,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(
                  key: ValueKey<String>('item0'),
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const ValueKey<String>('item0')));
      expect(taps, 1);
      await _dispose(tester);
    });

    testWidgets('reduced motion: static evenly placed, no frames scheduled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(reduceMotion: true, OrbitItems(children: _items(4))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_center(tester, 0), _near(const Offset(150, 20)));
      expect(_center(tester, 1), _near(const Offset(280, 150)));
    });

    testWidgets('enabled false is static and re-enabling resumes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(OrbitItems(enabled: false, children: _items(4))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_center(tester, 0), _near(const Offset(150, 20)));
      await tester.pumpWidget(_wrap(OrbitItems(children: _items(4))));
      await tester.pump(const Duration(seconds: 1));
      expect(_center(tester, 0), isNot(_near(const Offset(150, 20))));
      await _dispose(tester);
    });

    testWidgets('showPath draws the orbit line', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(OrbitItems(showPath: true, enabled: false, children: _items(3))),
      );
      expect(
        tester.renderObject(find.byType(OrbitItems)),
        paints..circle(x: 150, y: 150, radius: 130),
      );
      await tester.pumpWidget(
        _wrap(OrbitItems(enabled: false, children: _items(3))),
      );
      expect(
        tester.renderObject(find.byType(OrbitItems)),
        isNot(paints..circle()),
      );
    });

    testWidgets('itemSize forces the item size and center stays centered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            itemSize: const Size(24, 24),
            center: const SizedBox(
              key: ValueKey<String>('center'),
              width: 60,
              height: 60,
            ),
            enabled: false,
            children: _items(3),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('item0'))),
        const Size(24, 24),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey<String>('center'))),
        const Offset(150, 150),
      );
      // Radius grows to (300 - 24) / 2.
      expect(_center(tester, 0), _near(const Offset(150, 12)));
    });

    testWidgets('unbounded constraints fall back to the radius', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: UnconstrainedBox(
              child: OrbitItems(enabled: false, children: _items(3)),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(OrbitItems)), const Size(280, 280));
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrbitItems(children: _items(4))));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            shape: OrbitShape.ellipse,
            depth: true,
            rotateItems: true,
            showPath: true,
            clockwise: false,
            duration: const Duration(seconds: 2),
            center: const FlutterLogo(),
            children: _items(6),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          OrbitItems(
            path: Path()..addOval(const Rect.fromLTWH(10, 10, 200, 120)),
            children: _items(2),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_wrap(const OrbitItems(children: <Widget>[])));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OrbitItems(children: _items(4))));
      await tester.pump(const Duration(milliseconds: 250));
      await _dispose(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });
  });
}

Matcher _sizeNear(Size expected) => isA<Size>()
    .having(
      (Size s) => s.width,
      'width',
      moreOrLessEquals(expected.width, epsilon: 0.01),
    )
    .having(
      (Size s) => s.height,
      'height',
      moreOrLessEquals(expected.height, epsilon: 0.01),
    );
