import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('SwipeActions', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            rightActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
                onPressed: () {},
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );
      expect(find.text('Row'), findsOneWidget);
    });

    testWidgets('drag left reveals right actions and tapping one fires it', (
      WidgetTester tester,
    ) async {
      bool deleted = false;
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            rightActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
                onPressed: () => deleted = true,
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );

      await tester.drag(find.text('Row'), const Offset(-250, 0));
      await tester.pumpAndSettle();

      // The action row is revealed to its full extent (25% of 800 = 200).
      final Size revealed = tester.getSize(
        find
            .ancestor(of: find.text('Delete'), matching: find.byType(SizedBox))
            .first,
      );
      expect(revealed.width, moreOrLessEquals(200.0, epsilon: 1.0));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('drag right reveals left actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            leftActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.archive,
                label: 'Archive',
                backgroundColor: Colors.blue,
                onPressed: () {},
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );

      await tester.drag(find.text('Row'), const Offset(250, 0));
      await tester.pumpAndSettle();
      final Size revealed = tester.getSize(
        find
            .ancestor(of: find.text('Archive'), matching: find.byType(SizedBox))
            .first,
      );
      expect(revealed.width, greaterThan(0));
    });

    testWidgets('full swipe triggers the first action when enabled', (
      WidgetTester tester,
    ) async {
      bool deleted = false;
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            performsFirstActionOnFullSwipe: true,
            rightActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
                onPressed: () => deleted = true,
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );

      await tester.drag(find.text('Row'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('enabled false renders the plain child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            enabled: false,
            rightActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('disposal while the spring runs does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SwipeActions(
            rightActions: <MicroSwipeAction>[
              MicroSwipeAction(
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
                onPressed: () {},
              ),
            ],
            child: const ListTile(title: Text('Row')),
          ),
        ),
      );

      await tester.drag(find.text('Row'), const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('MicroSwipeAction', () {
    testWidgets('factory constructors read colors from the theme', (
      WidgetTester tester,
    ) async {
      late MicroSwipeAction delete;
      late MicroSwipeAction archive;
      late MicroSwipeAction favorite;
      late MicroSwipeAction share;
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              scheme = Theme.of(context).colorScheme;
              delete = MicroSwipeAction.delete(context);
              archive = MicroSwipeAction.archive(context);
              favorite = MicroSwipeAction.favorite(context);
              share = MicroSwipeAction.share(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(delete.backgroundColor, scheme.error);
      expect(delete.label, 'Delete');
      expect(archive.backgroundColor, scheme.secondary);
      expect(favorite.backgroundColor, scheme.tertiary);
      expect(share.backgroundColor, scheme.primary);
    });
  });
}
