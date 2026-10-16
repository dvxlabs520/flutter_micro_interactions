import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// The morph progress the [ShapeMorph] painter currently draws.
double _shapeMorphProgress(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(ShapeMorph),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return (paint.painter as dynamic).progress as double;
}

void main() {
  group('MorphingShapes', () {
    testWidgets('builds and paints the first shape', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MorphingShapes(
            shapes: <MicroShapeType>[MicroShapeType.circle],
            semanticLabel: 'Decoration',
          ),
        ),
      );
      expect(find.byType(MorphingShapes), findsOneWidget);
      expect(find.bySemanticsLabel('Decoration'), findsOneWidget);
    });

    testWidgets('controller.morphToNext advances to the next shape', (
      WidgetTester tester,
    ) async {
      final MorphingShapesController controller = MorphingShapesController();
      addTearDown(controller.dispose);
      final List<MicroShapeType> seen = <MicroShapeType>[];

      await tester.pumpWidget(
        _wrap(
          MorphingShapes(
            shapes: const <MicroShapeType>[
              MicroShapeType.circle,
              MicroShapeType.square,
              MicroShapeType.star,
            ],
            duration: const Duration(milliseconds: 200),
            controller: controller,
            onShapeChanged: seen.add,
          ),
        ),
      );

      controller.morphToNext();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(seen, <MicroShapeType>[MicroShapeType.square]);

      controller.morphTo(MicroShapeType.circle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(seen.last, MicroShapeType.circle);

      // Morphing to a shape not in the list does nothing.
      controller.morphTo(MicroShapeType.heart);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(seen.length, 2);
    });

    testWidgets('morphOnTap advances on tap', (WidgetTester tester) async {
      final List<MicroShapeType> seen = <MicroShapeType>[];
      await tester.pumpWidget(
        _wrap(
          MorphingShapes(
            shapes: const <MicroShapeType>[
              MicroShapeType.circle,
              MicroShapeType.diamond,
            ],
            duration: const Duration(milliseconds: 200),
            morphOnTap: true,
            onShapeChanged: seen.add,
          ),
        ),
      );
      await tester.tap(find.byType(MorphingShapes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(seen, <MicroShapeType>[MicroShapeType.diamond]);
    });

    testWidgets('autoPlay cycles shapes on its own', (
      WidgetTester tester,
    ) async {
      final List<MicroShapeType> seen = <MicroShapeType>[];
      await tester.pumpWidget(
        _wrap(
          MorphingShapes(
            shapes: const <MicroShapeType>[
              MicroShapeType.circle,
              MicroShapeType.triangle,
            ],
            autoPlay: true,
            autoPlayDuration: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 100),
            onShapeChanged: seen.add,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(seen, isNotEmpty);
      expect(seen.first, MicroShapeType.triangle);

      // Tear the widget down to cancel the pending auto-play timer.
      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion swaps shapes instantly', (
      WidgetTester tester,
    ) async {
      final MorphingShapesController controller = MorphingShapesController();
      addTearDown(controller.dispose);
      final List<MicroShapeType> seen = <MicroShapeType>[];

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: MorphingShapes(
                shapes: const <MicroShapeType>[
                  MicroShapeType.circle,
                  MicroShapeType.square,
                ],
                controller: controller,
                onShapeChanged: seen.add,
              ),
            ),
          ),
        ),
      );

      controller.morphToNext();
      await tester.pump();
      expect(seen, <MicroShapeType>[MicroShapeType.square]);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal mid-morph does not throw', (
      WidgetTester tester,
    ) async {
      final MorphingShapesController controller = MorphingShapesController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphingShapes(
            shapes: const <MicroShapeType>[
              MicroShapeType.circle,
              MicroShapeType.star,
            ],
            controller: controller,
          ),
        ),
      );
      controller.morphToNext();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('ShapeMorph', () {
    testWidgets('tap toggles between the two shapes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ShapeMorph(
            fromShape: MicroShapeType.circle,
            toShape: MicroShapeType.heart,
            duration: Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.tap(find.byType(ShapeMorph));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      // Toggle back.
      await tester.tap(find.byType(ShapeMorph));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('autoReverse loops without settling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ShapeMorph(
            fromShape: MicroShapeType.circle,
            toShape: MicroShapeType.square,
            autoReverse: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a duration change applies to a running loop', (
      WidgetTester tester,
    ) async {
      Widget build(Duration duration) {
        return _wrap(
          ShapeMorph(
            fromShape: MicroShapeType.circle,
            toShape: MicroShapeType.square,
            duration: duration,
            curve: Curves.linear,
            autoReverse: true,
          ),
        );
      }

      await tester.pumpWidget(build(const Duration(milliseconds: 1000)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shapeMorphProgress(tester), closeTo(0.1, 0.001));

      await tester.pumpWidget(build(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_shapeMorphProgress(tester), closeTo(0.35, 0.001));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning autoReverse off while looping stops the loop', (
      WidgetTester tester,
    ) async {
      Widget build({required bool autoReverse}) {
        return _wrap(
          ShapeMorph(
            fromShape: MicroShapeType.circle,
            toShape: MicroShapeType.square,
            duration: const Duration(milliseconds: 200),
            autoReverse: autoReverse,
          ),
        );
      }

      await tester.pumpWidget(build(autoReverse: true));
      await tester.pump(const Duration(milliseconds: 130));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(build(autoReverse: false));
      // The loop ends: at most one short settle to the nearest shape, then
      // nothing keeps ticking.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isFalse);

      // It rests on one of the two shapes.
      final double rest = _shapeMorphProgress(tester);
      expect(rest == 0.0 || rest == 1.0, isTrue);

      // Tap toggling works again once the loop is off.
      await tester.tap(find.byType(ShapeMorph));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
