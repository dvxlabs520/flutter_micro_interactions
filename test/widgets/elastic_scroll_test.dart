import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ElasticScrollPhysics', () {
    test('frictionFactor equals elasticity with no overscroll', () {
      const ElasticScrollPhysics physics =
          ElasticScrollPhysics(elasticity: 0.4);
      expect(physics.frictionFactor(0.0), moreOrLessEquals(0.4));
      expect(physics.frictionFactor(0.5), lessThan(0.4));
    });

    test('applyTo preserves configuration', () {
      const ElasticScrollPhysics physics = ElasticScrollPhysics(
        elasticity: 0.5,
        stiffness: 200.0,
        damping: 0.9,
      );
      final ElasticScrollPhysics applied = physics.applyTo(null);
      expect(applied.elasticity, 0.5);
      expect(applied.stiffness, 200.0);
      expect(applied.damping, 0.9);
    });
  });

  group('ElasticScroll', () {
    testWidgets('renders child and applies elastic physics',
        (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ElasticScroll(
            controller: controller,
            child: Column(
              children: List<Widget>.generate(
                30,
                (int i) => SizedBox(height: 50, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);

      final SingleChildScrollView scrollView =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.physics, isA<ElasticScrollPhysics>());

      // The content actually scrolls.
      await tester.drag(find.byType(ElasticScroll), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('enabled false falls back to default physics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ElasticScroll(enabled: false, child: Container(height: 10))),
      );
      final SingleChildScrollView scrollView =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.physics, isNull);
    });

    testWidgets('reduced motion clamps instead of bouncing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ElasticScroll(child: Container(height: 10)),
            ),
          ),
        ),
      );
      final SingleChildScrollView scrollView =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.physics, isA<ClampingScrollPhysics>());
    });
  });

  group('ElasticListView', () {
    testWidgets('children constructor renders items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ElasticListView(
            children: List<Widget>.generate(
              5,
              (int i) => ListTile(title: Text('Tile $i')),
            ),
          ),
        ),
      );
      expect(find.text('Tile 0'), findsOneWidget);
      expect(find.text('Tile 4'), findsOneWidget);
    });

    testWidgets('builder constructor builds items lazily',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ElasticListView.builder(
            itemCount: 40,
            itemBuilder: (BuildContext context, int index) =>
                SizedBox(height: 50, child: Text('Row $index')),
          ),
        ),
      );
      expect(find.text('Row 0'), findsOneWidget);
      expect(find.text('Row 39'), findsNothing);
    });
  });

  group('ElasticGridView', () {
    testWidgets('children and builder constructors render tiles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ElasticGridView(
            crossAxisCount: 2,
            children: List<Widget>.generate(4, (int i) => Text('Cell $i')),
          ),
        ),
      );
      expect(find.text('Cell 0'), findsOneWidget);
      expect(find.text('Cell 3'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          ElasticGridView.builder(
            crossAxisCount: 3,
            itemCount: 9,
            itemBuilder: (BuildContext context, int index) =>
                Text('GridCell $index'),
          ),
        ),
      );
      expect(find.text('GridCell 0'), findsOneWidget);
      expect(find.text('GridCell 8'), findsOneWidget);
    });
  });
}
