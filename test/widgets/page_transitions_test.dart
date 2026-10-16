import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MicroPageRoute', () {
    for (final MicroTransitionType type in MicroTransitionType.values) {
      testWidgets('pushes and pops with the $type transition', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Home'))),
        );

        final NavigatorState navigator = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        navigator.push(
          MicroPageRoute<void>(
            type: type,
            child: const Scaffold(body: Text('Second')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);

        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Second'), findsNothing);
      });
    }

    testWidgets('reuses one CurvedAnimation and disposes it with the route', (
      WidgetTester tester,
    ) async {
      final MicroPageRoute<void> route = MicroPageRoute<void>(
        type: MicroTransitionType.slideRight,
        child: const Scaffold(body: Text('Second')),
      );
      int created = 0;
      int disposed = 0;
      void onEvent(ObjectEvent event) {
        final Object object = event.object;
        if (object is! CurvedAnimation ||
            route.animation == null ||
            !identical(object.parent, route.animation)) {
          return;
        }
        if (event is ObjectCreated) created++;
        if (event is ObjectDisposed) disposed++;
      }

      FlutterMemoryAllocations.instance.addListener(onEvent);
      addTearDown(
        () => FlutterMemoryAllocations.instance.removeListener(onEvent),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigator.push(route);
      await tester.pumpAndSettle();

      // Rebuild the route's transitions: a page pushed and popped on top
      // forces the route scope to rebuild, and direct calls to
      // buildTransitions stand in for any other rebuild.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Text('Third'),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.text('Second'));
      for (int i = 0; i < 5; i++) {
        route.buildTransitions(
          context,
          route.animation!,
          route.secondaryAnimation!,
          const SizedBox(),
        );
      }
      expect(created, 1);
      expect(disposed, 0);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
      expect(disposed, created);
    });

    test('opaque matches the transition type', () {
      MicroPageRoute<void> route(MicroTransitionType type) =>
          MicroPageRoute<void>(type: type, child: const SizedBox());
      expect(route(MicroTransitionType.fade).opaque, isFalse);
      expect(route(MicroTransitionType.blur).opaque, isFalse);
      expect(route(MicroTransitionType.flip).opaque, isFalse);
      expect(route(MicroTransitionType.slideRight).opaque, isTrue);
      expect(route(MicroTransitionType.size).opaque, isTrue);
    });

    testWidgets('reduced motion falls back to a fade', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigator.push(
        MicroPageRoute<void>(
          type: MicroTransitionType.slideRight,
          child: const Scaffold(body: Text('Second')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
    });
  });

  group('MicroNavigator', () {
    testWidgets('push shows the new page', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      MicroNavigator.push(
        tester.element(find.text('Home')),
        const Scaffold(body: Text('Detail')),
        type: MicroTransitionType.slideBottom,
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('pushReplacement swaps the current page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      MicroNavigator.pushReplacement(
        tester.element(find.text('Home')),
        const Scaffold(body: Text('Replacement')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Replacement'), findsOneWidget);

      // The original route is gone: popping is not possible.
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('pushAndRemoveUntil clears previous routes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      final BuildContext context = tester.element(find.text('Home'));
      MicroNavigator.push(context, const Scaffold(body: Text('Middle')));
      await tester.pumpAndSettle();

      MicroNavigator.pushAndRemoveUntil(
        tester.element(find.text('Middle')),
        const Scaffold(body: Text('Final')),
        (Route<dynamic> route) => false,
      );
      await tester.pumpAndSettle();
      expect(find.text('Final'), findsOneWidget);

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(navigator.canPop(), isFalse);
    });
  });
}
