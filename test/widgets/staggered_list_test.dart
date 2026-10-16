import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/staggered_list.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

double _opacityOf(WidgetTester tester, String text) {
  final FadeTransition fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
        .first,
  );
  return fade.opacity.value;
}

void main() {
  group('StaggeredList', () {
    testWidgets('renders all children and finishes the entrance', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList(
            children: const <Widget>[
              Text('Item 0'),
              Text('Item 1'),
              Text('Item 2'),
            ],
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Finite animation: settle lets all stagger timers fire and finish.
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Item 0'), 1.0);
      expect(_opacityOf(tester, 'Item 2'), 1.0);
    });

    testWidgets('staggers items: later items start hidden', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList(
            staggerDelay: const Duration(milliseconds: 100),
            itemDuration: const Duration(milliseconds: 200),
            children: const <Widget>[Text('Item 0'), Text('Item 1')],
          ),
        ),
      );

      // Index 1 waits 100ms before starting; it is still invisible here.
      expect(_opacityOf(tester, 'Item 1'), 0.0);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(tester, 'Item 1'), greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Item 1'), 1.0);
    });

    testWidgets('enabled false renders children in place instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList(
            enabled: false,
            children: const <Widget>[Text('Item 0'), Text('Item 1')],
          ),
        ),
      );
      // No timers, no animation: fully visible on the first frame.
      expect(_opacityOf(tester, 'Item 0'), 1.0);
      expect(_opacityOf(tester, 'Item 1'), 1.0);
    });

    testWidgets('reduced motion renders children in place instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            StaggeredList(
              children: const <Widget>[Text('Item 0'), Text('Item 1')],
            ),
          ),
        ),
      );
      expect(_opacityOf(tester, 'Item 0'), 1.0);
      expect(_opacityOf(tester, 'Item 1'), 1.0);
    });

    testWidgets('builder variant builds and animates lazy items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList.builder(
            itemCount: 50,
            itemBuilder: (BuildContext context, int index) =>
                SizedBox(height: 40, child: Text('Item $index')),
          ),
        ),
      );
      expect(find.text('Item 0'), findsOneWidget);
      // Off-screen items are not built (and own no controllers).
      expect(find.text('Item 49'), findsNothing);

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Item 0'), 1.0);
    });

    testWidgets(
      'builder items entering the viewport later play a capped entrance',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            StaggeredList.builder(
              staggerDelay: const Duration(milliseconds: 100),
              itemDuration: const Duration(milliseconds: 200),
              itemCount: 50,
              itemBuilder: (BuildContext context, int index) =>
                  SizedBox(height: 100, child: Text('Item $index')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll a deep item into view; its natural slot (index * delay) is
        // long past, so its delay is capped at 3 * staggerDelay = 300ms.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(find.text('Item 25'), findsOneWidget);
        expect(_opacityOf(tester, 'Item 25'), 0.0);

        // Capped delay (300ms) plus the item duration (200ms) is enough.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 200));
        expect(_opacityOf(tester, 'Item 25'), 1.0);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('animateOnlyOnce false replays when a new list is provided', (
      WidgetTester tester,
    ) async {
      Widget build(List<Widget> children) => _wrap(
        StaggeredList(
          animateOnlyOnce: false,
          staggerDelay: const Duration(milliseconds: 100),
          children: children,
        ),
      );

      await tester.pumpWidget(
        build(const <Widget>[Text('Item 0'), Text('Item 1')]),
      );
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Item 1'), 1.0);

      // A different list instance remounts the items and replays.
      await tester.pumpWidget(
        build(<Widget>[const Text('Item 0'), const Text('Item 1')]),
      );
      await tester.pump();
      expect(_opacityOf(tester, 'Item 1'), 0.0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Item 1'), 1.0);
    });

    testWidgets('animateOnlyOnce true does not replay on rebuild', (
      WidgetTester tester,
    ) async {
      Widget build(List<Widget> children) =>
          _wrap(StaggeredList(children: children));

      await tester.pumpWidget(build(const <Widget>[Text('Item 0')]));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(<Widget>[const Text('Item 0')]));
      await tester.pump();
      expect(_opacityOf(tester, 'Item 0'), 1.0);
    });

    testWidgets('cancels pending stagger timers on dispose', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList(
            staggerDelay: const Duration(seconds: 1),
            children: const <Widget>[Text('Item 0'), Text('Item 1')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Removing the list mid-stagger must cancel item timers; the test
      // framework fails if any timer were left pending here.
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('scroll direction, padding and shrinkWrap are forwarded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StaggeredList(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const <Widget>[Text('Item 0')],
          ),
        ),
      );
      final ListView listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
      expect(listView.padding, const EdgeInsets.all(8));
      expect(listView.shrinkWrap, isTrue);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
      await tester.pumpAndSettle();
    });
  });

  group('StaggeredItem', () {
    testWidgets('works standalone inside a Column', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: const <Widget>[
              StaggeredItem(index: 0, child: Text('A')),
              StaggeredItem(index: 1, child: Text('B')),
            ],
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(_opacityOf(tester, 'B'), 0.0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'B'), 1.0);
    });

    testWidgets('supports every effect, including RTL slide directions', (
      WidgetTester tester,
    ) async {
      for (final StaggerEffect effect in StaggerEffect.values) {
        for (final TextDirection direction in TextDirection.values) {
          await tester.pumpWidget(
            Directionality(
              textDirection: direction,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: StaggeredItem(
                  index: 0,
                  effect: effect,
                  child: const Text('X'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('X'),
            findsOneWidget,
            reason: '$effect in $direction',
          );
        }
      }
    });

    testWidgets('maxDelay caps the start delay', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: <Widget>[
              StaggeredItem(
                index: 100,
                staggerDelay: Duration(milliseconds: 100),
                itemDuration: Duration(milliseconds: 200),
                maxDelay: Duration(milliseconds: 300),
                child: Text('Deep'),
              ),
            ],
          ),
        ),
      );
      // Without the cap this item would wait 10 seconds.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacityOf(tester, 'Deep'), 1.0);
    });
  });
}
