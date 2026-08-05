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
    testWidgets('renders foreground children over the background',
        (WidgetTester tester) async {
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

    testWidgets('foreground scrolls while the background pans',
        (WidgetTester tester) async {
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

    testWidgets('reduced motion keeps the background static',
        (WidgetTester tester) async {
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
    testWidgets('builds inside a scrollable at the requested height',
        (WidgetTester tester) async {
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

    testWidgets('renders statically outside a scrollable',
        (WidgetTester tester) async {
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
