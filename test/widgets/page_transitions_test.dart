import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MicroPageRoute', () {
    for (final MicroTransitionType type in MicroTransitionType.values) {
      testWidgets('pushes and pops with the $type transition',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Home'))),
        );

        final NavigatorState navigator =
            tester.state<NavigatorState>(find.byType(Navigator));
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

    test('opaque matches the transition type', () {
      MicroPageRoute<void> route(MicroTransitionType type) =>
          MicroPageRoute<void>(type: type, child: const SizedBox());
      expect(route(MicroTransitionType.fade).opaque, isFalse);
      expect(route(MicroTransitionType.blur).opaque, isFalse);
      expect(route(MicroTransitionType.flip).opaque, isFalse);
      expect(route(MicroTransitionType.slideRight).opaque, isTrue);
      expect(route(MicroTransitionType.size).opaque, isTrue);
    });

    testWidgets('reduced motion falls back to a fade',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator));
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

    testWidgets('pushReplacement swaps the current page',
        (WidgetTester tester) async {
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
      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('pushAndRemoveUntil clears previous routes',
        (WidgetTester tester) async {
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

      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  });
}
