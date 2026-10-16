import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1x1 transparent PNG, so image widgets can be built without assets.
final Uint8List _kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ParallaxScroll', () {
    testWidgets('renders foreground children over the background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParallaxScroll(
            background: Container(color: Colors.blue),
            children: List<Widget>.generate(
              20,
              (int i) => SizedBox(height: 100, child: Text('Item $i')),
            ),
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('foreground scrolls while the background pans', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ParallaxScroll(
            controller: controller,
            background: Container(color: Colors.blue),
            children: List<Widget>.generate(
              20,
              (int i) => SizedBox(height: 100, child: Text('Item $i')),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('supports extra layers', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ParallaxScroll(
            layers: <ParallaxLayer>[
              ParallaxLayer(
                parallaxFactor: 0.2,
                child: Container(color: Colors.green),
              ),
            ],
            children: const <Widget>[SizedBox(height: 100, child: Text('Top'))],
          ),
        ),
      );
      expect(find.text('Top'), findsOneWidget);
    });

    testWidgets('paints the background behind the layers', (
      WidgetTester tester,
    ) async {
      const Key backgroundKey = Key('background');
      const Key deepKey = Key('deep');
      const Key nearKey = Key('near');
      await tester.pumpWidget(
        _wrap(
          ParallaxScroll(
            background: Container(key: backgroundKey, color: Colors.blue),
            layers: <ParallaxLayer>[
              ParallaxLayer(
                parallaxFactor: 0.2,
                child: Container(key: deepKey, color: Colors.green),
              ),
              ParallaxLayer(
                parallaxFactor: 0.4,
                child: Container(key: nearKey, color: Colors.red),
              ),
            ],
            children: const <Widget>[SizedBox(height: 100, child: Text('Top'))],
          ),
        ),
      );

      // Stack children paint in order, so the paint order of the three
      // decorative layers is the order of their Positioned ancestors.
      final Stack stack = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(backgroundKey),
              matching: find.byType(Stack),
            )
            .first,
      );
      int indexOf(Key key) {
        final Element element = tester.element(find.byKey(key));
        for (int i = 0; i < stack.children.length; i++) {
          bool found = false;
          element.visitAncestorElements((Element ancestor) {
            if (identical(ancestor.widget, stack.children[i])) {
              found = true;
              return false;
            }
            return true;
          });
          if (found) {
            return i;
          }
        }
        return -1;
      }

      final int background = indexOf(backgroundKey);
      final int deep = indexOf(deepKey);
      final int near = indexOf(nearKey);
      expect(background, isNot(-1));
      expect(background, lessThan(deep));
      expect(deep, lessThan(near));
      // The foreground list is painted last, above every layer.
      expect(stack.children.last, isA<ListView>());
    });

    testWidgets('reduced motion keeps the background static', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ParallaxScroll(
                background: Container(color: Colors.blue),
                children: List<Widget>.generate(
                  20,
                  (int i) => SizedBox(height: 100, child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ParallaxImage', () {
    testWidgets('builds inside a scrollable at the requested height', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: <Widget>[
              ParallaxImage(
                imageProvider: MemoryImage(_kTransparentImage),
                height: 220,
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );
      expect(find.byType(ParallaxImage), findsOneWidget);
      expect(tester.getSize(find.byType(ParallaxImage)).height, 220);

      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the image always covers its area at narrow widths', (
      WidgetTester tester,
    ) async {
      // A square image laid out 100 wide would be only 100 tall, leaving
      // a 120 pixel strip of the 220 pixel area uncovered.
      final MemoryImage provider = MemoryImage(_kTransparentImage);
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 100,
                  child: ParallaxImage(imageProvider: provider, height: 220),
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          provider,
          tester.element(find.byType(ParallaxImage)),
        );
      });
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);

      void expectCovered() {
        final Rect area = tester.getRect(find.byType(ParallaxImage));
        final Rect image = tester.getRect(find.byType(RawImage));
        expect(image.width, area.width);
        expect(image.height, greaterThanOrEqualTo(area.height));
        // The painted (translated) image spans the whole clip area.
        final RenderBox box = tester.renderObject<RenderBox>(
          find.byType(RawImage),
        );
        final Offset topLeft = box.localToGlobal(Offset.zero);
        final Offset bottomLeft = box.localToGlobal(Offset(0, box.size.height));
        expect(topLeft.dy, lessThanOrEqualTo(area.top + 0.001));
        expect(bottomLeft.dy, greaterThanOrEqualTo(area.bottom - 0.001));
      }

      expectCovered();
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pump();
      expectCovered();
    });

    testWidgets('renders statically outside a scrollable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: ParallaxImage(
              imageProvider: MemoryImage(_kTransparentImage),
              semanticLabel: 'A picture',
            ),
          ),
        ),
      );
      expect(find.byType(Flow), findsNothing);
      expect(tester.getSize(find.byType(ParallaxImage)).height, 200);
    });
  });
}
