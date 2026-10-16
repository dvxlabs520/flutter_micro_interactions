import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/gradual_blur.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

const Size _childSize = Size(400, 300);

Widget _content() => const SizedBox(
  width: 400,
  height: 300,
  child: ColoredBox(color: Colors.orange),
);

Finder _filters() => find.descendant(
  of: find.byType(GradualBlur),
  matching: find.byType(BackdropFilter),
);

List<BackdropFilter> _filterWidgets(WidgetTester tester) =>
    tester.widgetList<BackdropFilter>(_filters()).toList();

/// Union of every blur layer's on-screen rect.
Rect _bandRect(WidgetTester tester) {
  Rect? band;
  for (final Element element in _filters().evaluate()) {
    final Rect rect = tester.getRect(
      find.byElementPredicate((Element e) {
        return identical(e, element);
      }),
    );
    band = band == null ? rect : band.expandToInclude(rect);
  }
  return band!;
}

ui.ImageFilter _blur(double sigma) => ui.ImageFilter.blur(
  sigmaX: sigma,
  sigmaY: sigma,
  tileMode: TileMode.mirror,
);

void main() {
  group('GradualBlur', () {
    testWidgets('builds one backdrop layer per layer sharing one backdrop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(GradualBlur(child: _content())));
      final List<BackdropFilter> filters = _filterWidgets(tester);
      expect(filters, hasLength(6));
      final BackdropKey? key = filters.first.backdropGroupKey;
      expect(key, isNotNull);
      for (final BackdropFilter filter in filters) {
        expect(filter.backdropGroupKey, same(key));
      }
      expect(tester.getSize(find.byType(GradualBlur)), _childSize);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('layers count and sigma ramp follow the parameters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GradualBlur(
            layers: 4,
            strength: 0.5,
            curve: Curves.linear,
            child: _content(),
          ),
        ),
      );
      final List<BackdropFilter> filters = _filterWidgets(tester);
      expect(filters, hasLength(4));
      const double max = GradualBlur.maxSigma * 0.5;
      for (int i = 0; i < 4; i++) {
        expect(filters[i].filter, _blur(max * (i + 1) / 4));
      }
    });

    testWidgets('the default curve is exponential and reaches the max', (
      WidgetTester tester,
    ) async {
      expect(GradualBlur.exponential.transform(0.0), 0.0);
      expect(GradualBlur.exponential.transform(1.0), 1.0);
      expect(GradualBlur.exponential.transform(0.5), closeTo(0.2, 1e-9));

      await tester.pumpWidget(_wrap(GradualBlur(child: _content())));
      final List<BackdropFilter> filters = _filterWidgets(tester);
      expect(filters.last.filter, _blur(GradualBlur.maxSigma));
    });

    testWidgets('strength 0 or enabled false paints no blur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(GradualBlur(strength: 0, child: _content())),
      );
      expect(_filters(), findsNothing);
      expect(tester.getSize(find.byType(GradualBlur)), _childSize);

      await tester.pumpWidget(
        _wrap(GradualBlur(enabled: false, child: _content())),
      );
      expect(_filters(), findsNothing);
      expect(tester.getSize(find.byType(GradualBlur)), _childSize);
    });

    testWidgets('the band sits on the requested edge', (
      WidgetTester tester,
    ) async {
      final Map<GradualBlurEdge, Rect Function(Rect)> expected =
          <GradualBlurEdge, Rect Function(Rect)>{
            GradualBlurEdge.bottom: (Rect c) =>
                Rect.fromLTRB(c.left, c.bottom - 80, c.right, c.bottom),
            GradualBlurEdge.top: (Rect c) =>
                Rect.fromLTRB(c.left, c.top, c.right, c.top + 80),
            GradualBlurEdge.left: (Rect c) =>
                Rect.fromLTRB(c.left, c.top, c.left + 80, c.bottom),
            GradualBlurEdge.right: (Rect c) =>
                Rect.fromLTRB(c.right - 80, c.top, c.right, c.bottom),
          };
      for (final GradualBlurEdge edge in GradualBlurEdge.values) {
        // Physical edges ignore the text direction.
        await tester.pumpWidget(
          _wrap(
            GradualBlur(edge: edge, extent: 80, layers: 4, child: _content()),
            direction: TextDirection.rtl,
          ),
        );
        final Rect child = tester.getRect(find.byType(GradualBlur));
        expect(_bandRect(tester), expected[edge]!(child), reason: '$edge');

        // The strongest layer touches the edge.
        final Element strongest = _filters().evaluate().last;
        final Rect last = tester.getRect(
          find.byElementPredicate((Element e) => identical(e, strongest)),
        );
        final Rect band = expected[edge]!(child);
        switch (edge) {
          case GradualBlurEdge.bottom:
            expect(last.bottom, band.bottom);
            expect(last.height, 20);
          case GradualBlurEdge.top:
            expect(last.top, band.top);
            expect(last.height, 20);
          case GradualBlurEdge.left:
            expect(last.left, band.left);
            expect(last.width, 20);
          case GradualBlurEdge.right:
            expect(last.right, band.right);
            expect(last.width, 20);
        }
      }
    });

    testWidgets('fadeColor paints a gradient that is solid at the edge', (
      WidgetTester tester,
    ) async {
      const Color color = Color(0xFF123456);
      await tester.pumpWidget(
        _wrap(
          GradualBlur(
            edge: GradualBlurEdge.top,
            fadeColor: color,
            child: _content(),
          ),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GradualBlur),
          matching: find.byType(DecoratedBox),
        ),
      );
      final LinearGradient gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.end, Alignment.topCenter);
      expect(gradient.colors.first.a, 0.0);
      expect(gradient.colors.last, color);

      // Fade color alone still paints when the blur is off.
      await tester.pumpWidget(
        _wrap(GradualBlur(strength: 0, fadeColor: color, child: _content())),
      );
      expect(_filters(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GradualBlur),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('taps under the band reach the child', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          GradualBlur(
            fadeColor: Colors.white,
            child: GestureDetector(onTap: () => taps++, child: _content()),
          ),
        ),
      );
      final Rect child = tester.getRect(find.byType(GradualBlur));
      await tester.tapAt(child.bottomCenter - const Offset(0, 10));
      expect(taps, 1);
    });

    testWidgets('overlay builds only the band for a custom Stack', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 500,
            child: Stack(
              key: const Key('stack'),
              children: <Widget>[
                const Positioned.fill(child: ColoredBox(color: Colors.teal)),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GradualBlur.overlay(extent: 120, layers: 3),
                ),
              ],
            ),
          ),
        ),
      );
      expect(_filters(), findsNWidgets(3));
      expect(tester.getSize(find.byType(GradualBlur)), const Size(300, 120));
      final Rect stack = tester.getRect(find.byKey(const Key('stack')));
      expect(tester.getRect(find.byType(GradualBlur)).bottom, stack.bottom);
    });

    testWidgets('parameter changes rebuild safely', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(GradualBlur(child: _content())));
      await tester.pumpWidget(
        _wrap(
          GradualBlur(
            edge: GradualBlurEdge.right,
            extent: 50,
            layers: 2,
            strength: 2,
            fadeColor: Colors.black,
            child: _content(),
          ),
        ),
      );
      expect(_filters(), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
