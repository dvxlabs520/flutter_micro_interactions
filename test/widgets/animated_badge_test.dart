import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/animated_badge.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// The visibility scale currently applied to the badge (the outer of the
/// two nested [ScaleTransition]s).
double _badgeScale(WidgetTester tester) {
  final ScaleTransition scale = tester
      .widgetList<ScaleTransition>(
        find.descendant(
          of: find.byType(AnimatedBadge),
          matching: find.byType(ScaleTransition),
        ),
      )
      .first;
  return scale.scale.value;
}

void main() {
  group('AnimatedBadge', () {
    testWidgets('renders the child and the count', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 3, child: Icon(Icons.shopping_cart))),
      );
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(_badgeScale(tester), 1.0);
    });

    testWidgets('badge is hidden at zero unless showZero is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 0, child: Icon(Icons.shopping_cart))),
      );
      expect(_badgeScale(tester), 0.0);

      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 0,
            showZero: true,
            child: Icon(Icons.shopping_cart),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(_badgeScale(tester), 1.0);
    });

    testWidgets('maxCount caps the rendered text', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 150,
            maxCount: 99,
            child: Icon(Icons.notifications),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('scales in when the count becomes positive and out at zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 0, child: Icon(Icons.shopping_cart))),
      );
      expect(_badgeScale(tester), 0.0);

      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 1, child: Icon(Icons.shopping_cart))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(_badgeScale(tester), 1.0);

      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 0, child: Icon(Icons.shopping_cart))),
      );
      await tester.pumpAndSettle();
      expect(_badgeScale(tester), 0.0);
    });

    testWidgets('bounces when the count changes while visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 1, child: Icon(Icons.shopping_cart))),
      );
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 2, child: Icon(Icons.shopping_cart))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('enabled false updates instantly', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 0,
            enabled: false,
            child: Icon(Icons.shopping_cart),
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 5,
            enabled: false,
            child: Icon(Icons.shopping_cart),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      expect(_badgeScale(tester), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion updates instantly', (
      WidgetTester tester,
    ) async {
      Widget build(int count) {
        return MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: AnimatedBadge(
                  count: count,
                  child: const Icon(Icons.shopping_cart),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(3));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      expect(_badgeScale(tester), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('semantics merges the badge label with the child', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 4, child: Text('Cart'))),
      );
      expect(
        tester.getSemantics(find.byType(AnimatedBadge)),
        matchesSemantics(label: 'Cart\n4 items'),
      );
      handle.dispose();
    });

    testWidgets('semanticLabel overrides the default label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 4,
            semanticLabel: '4 unread notifications',
            child: Text('Bell'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AnimatedBadge)),
        matchesSemantics(label: 'Bell\n4 unread notifications'),
      );
      handle.dispose();
    });

    testWidgets('announceChanges true runs without error on count change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 1,
            announceChanges: true,
            child: Icon(Icons.shopping_cart),
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedBadge(
            count: 2,
            announceChanges: true,
            child: Icon(Icons.shopping_cart),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 0, child: Icon(Icons.shopping_cart))),
      );
      await tester.pumpWidget(
        _wrap(const AnimatedBadge(count: 1, child: Icon(Icons.shopping_cart))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
