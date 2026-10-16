import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MicroReorderableList', () {
    testWidgets('renders keyed children in a ReorderableListView', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MicroReorderableList(
            onReorderItem: (int oldIndex, int newIndex) {},
            children: const <Widget>[
              ListTile(key: ValueKey<String>('a'), title: Text('Alpha')),
              ListTile(key: ValueKey<String>('b'), title: Text('Beta')),
            ],
          ),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    test('asserts when a child is missing a key', () {
      expect(
        () => MicroReorderableList(
          onReorderItem: (int oldIndex, int newIndex) {},
          children: const <Widget>[Text('no key')],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('builder constructor builds items lazily', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MicroReorderableList.builder(
            itemCount: 30,
            onReorderItem: (int oldIndex, int newIndex) {},
            itemBuilder: (BuildContext context, int index) => SizedBox(
              key: ValueKey<int>(index),
              height: 60,
              child: Text('Item $index'),
            ),
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 29'), findsNothing);
    });

    testWidgets('onReorderItem receives indexes adjusted for removal', (
      WidgetTester tester,
    ) async {
      final List<String> items = <String>['Alpha', 'Beta', 'Gamma'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MicroReorderableList(
                  onReorderItem: (int oldIndex, int newIndex) {
                    setState(() {
                      items.insert(newIndex, items.removeAt(oldIndex));
                    });
                  },
                  children: <Widget>[
                    for (final String item in items)
                      SizedBox(
                        key: ValueKey<String>(item),
                        height: 60,
                        child: Text(item),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Long-press then drag Alpha below Beta.
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (int i = 0; i < 4; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await drag.up();
      await tester.pumpAndSettle();

      expect(items, <String>['Beta', 'Alpha', 'Gamma']);
    });

    testWidgets('legacy onReorder still receives pre-removal indexes', (
      WidgetTester tester,
    ) async {
      final List<String> items = <String>['Alpha', 'Beta', 'Gamma'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MicroReorderableList(
                  // ignore: deprecated_member_use_from_same_package
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      items.insert(newIndex, items.removeAt(oldIndex));
                    });
                  },
                  children: <Widget>[
                    for (final String item in items)
                      SizedBox(
                        key: ValueKey<String>(item),
                        height: 60,
                        child: Text(item),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Long-press then drag Alpha below Beta.
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (int i = 0; i < 4; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await drag.up();
      await tester.pumpAndSettle();

      expect(items, <String>['Beta', 'Alpha', 'Gamma']);
    });

    testWidgets('showDragHandle wires explicit drag handles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MicroReorderableList(
            showDragHandle: true,
            onReorderItem: (int oldIndex, int newIndex) {},
            children: const <Widget>[
              ListTile(key: ValueKey<String>('a'), title: Text('Alpha')),
              ListTile(key: ValueKey<String>('b'), title: Text('Beta')),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byType(ReorderableDragStartListener), findsWidgets);
    });
  });
}
