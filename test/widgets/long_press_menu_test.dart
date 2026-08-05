import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('LongPressMenu', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LongPressMenu(
            menuItems: <LongPressMenuItem>[LongPressMenuItem.copy()],
            child: const ListTile(title: Text('Press me')),
          ),
        ),
      );
      expect(find.text('Press me'), findsOneWidget);
    });

    testWidgets('long press opens the menu and selecting an item fires '
        'onTap and onSelected', (WidgetTester tester) async {
      bool copied = false;
      LongPressMenuItem? selected;
      await tester.pumpWidget(
        _wrap(
          LongPressMenu(
            onSelected: (LongPressMenuItem item) => selected = item,
            menuItems: <LongPressMenuItem>[
              LongPressMenuItem.copy(onTap: () => copied = true),
              LongPressMenuItem.delete(),
            ],
            child: const ListTile(title: Text('Press me')),
          ),
        ),
      );

      await tester.longPress(find.text('Press me'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, isTrue);
      expect(selected, isNotNull);
      expect(selected!.label, 'Copy');
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('destructive items use the error color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LongPressMenu(
            menuItems: <LongPressMenuItem>[LongPressMenuItem.delete()],
            child: const ListTile(title: Text('Press me')),
          ),
        ),
      );
      await tester.longPress(find.text('Press me'));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Delete'));
      final Color error = Theme.of(context).colorScheme.error;
      final Text label = tester.widget<Text>(find.text('Delete'));
      expect(label.style?.color, error);

      // Close the menu.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('enabled false attaches no gesture',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LongPressMenu(
            enabled: false,
            menuItems: <LongPressMenuItem>[LongPressMenuItem.copy()],
            child: const ListTile(title: Text('Press me')),
          ),
        ),
      );
      await tester.longPress(find.text('Press me'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsNothing);
    });
  });

  group('LongPressMenuItem', () {
    test('standard factories carry the expected labels and flags', () {
      expect(LongPressMenuItem.copy().label, 'Copy');
      expect(LongPressMenuItem.share().label, 'Share');
      expect(LongPressMenuItem.edit().label, 'Edit');
      expect(LongPressMenuItem.favorite().label, 'Favorite');
      final LongPressMenuItem delete = LongPressMenuItem.delete();
      expect(delete.label, 'Delete');
      expect(delete.destructive, isTrue);
    });
  });
}
