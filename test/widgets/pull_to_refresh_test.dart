import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Widget _list() {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: List<Widget>.generate(
      10,
      (int i) => SizedBox(height: 60, child: Text('Item $i')),
    ),
  );
}

void main() {
  group('PullToRefresh', () {
    testWidgets('renders the scrollable child', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(PullToRefresh(onRefresh: () async {}, child: _list())),
      );
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('pulling down triggers onRefresh and shows the indicator '
        'until the future completes', (WidgetTester tester) async {
      final Completer<void> completer = Completer<void>();
      bool refreshed = false;
      await tester.pumpWidget(
        _wrap(
          PullToRefresh(
            onRefresh: () {
              refreshed = true;
              return completer.future;
            },
            child: _list(),
          ),
        ),
      );

      await tester.fling(find.text('Item 0'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(refreshed, isTrue);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('adaptive constructor builds', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(PullToRefresh.adaptive(onRefresh: () async {}, child: _list())),
      );
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('passes styling parameters through',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PullToRefresh(
            onRefresh: () async {},
            refreshIndicatorColor: Colors.red,
            backgroundColor: Colors.yellow,
            displacement: 60,
            child: _list(),
          ),
        ),
      );
      final RefreshIndicator indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      expect(indicator.color, Colors.red);
      expect(indicator.backgroundColor, Colors.yellow);
      expect(indicator.displacement, 60);
    });
  });
}
