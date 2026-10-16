import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('LoadingSkeleton', () {
    testWidgets('shimmers while enabled without ever settling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LoadingSkeleton(width: 120, height: 16)));
      // Repeating animation: pump explicit durations, never pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue);
      expect(find.byType(LoadingSkeleton), findsOneWidget);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false with a child renders the child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LoadingSkeleton(enabled: false, child: Text('Loaded'))),
      );
      expect(find.text('Loaded'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false without a child renders a static rectangle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LoadingSkeleton(width: 100, height: 20, enabled: false)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getSize(find.byType(LoadingSkeleton)), const Size(100, 20));
    });

    testWidgets('reduced motion renders static', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: LoadingSkeleton(width: 120, height: 16)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('LoadingSkeleton duration', () {
    testWidgets('a duration change applies to its own running shimmer', (
      WidgetTester tester,
    ) async {
      Animation<double> animation() {
        final AnimatedBuilder builder = tester.widget<AnimatedBuilder>(
          find.descendant(
            of: find.byType(LoadingSkeleton),
            matching: find.byType(AnimatedBuilder),
          ),
        );
        return builder.animation as Animation<double>;
      }

      await tester.pumpWidget(
        _wrap(
          const LoadingSkeleton(
            width: 100,
            height: 16,
            duration: Duration(milliseconds: 1000),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation().value, closeTo(0.1, 0.001));

      await tester.pumpWidget(
        _wrap(
          const LoadingSkeleton(
            width: 100,
            height: 16,
            duration: Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(animation().value, closeTo(0.35, 0.001));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
  });

  group('SkeletonScope', () {
    testWidgets('shares one animation with descendant skeletons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SkeletonScope(
            child: Column(
              children: <Widget>[
                LoadingSkeleton(width: 100, height: 16),
                LoadingSkeleton(width: 100, height: 16),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoadingSkeleton), findsNWidgets(2));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a duration change applies while the shimmer is running', (
      WidgetTester tester,
    ) async {
      Animation<double>? shared;
      Widget build(Duration duration) {
        return _wrap(
          SkeletonScope(
            duration: duration,
            child: Builder(
              builder: (BuildContext context) {
                shared = SkeletonScope.maybeAnimationOf(context);
                return const LoadingSkeleton(width: 100, height: 16);
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(build(const Duration(milliseconds: 1000)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shared!.value, closeTo(0.1, 0.001));

      await tester.pumpWidget(build(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 50));
      // 50 ms of a 200 ms sweep is a quarter turn: 0.1 + 0.25.
      expect(shared!.value, closeTo(0.35, 0.001));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
  });

  group('composite skeletons', () {
    testWidgets('TextSkeleton renders the requested number of lines', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: TextSkeleton(lines: 3, enabled: false),
          ),
        ),
      );
      expect(find.byType(LoadingSkeleton), findsNWidgets(3));
    });

    testWidgets('CardSkeleton, ListItemSkeleton and GridItemSkeleton build', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SingleChildScrollView(
            child: Column(
              children: <Widget>[
                CardSkeleton(enabled: false),
                ListItemSkeleton(hasTrailing: true, enabled: false),
                SizedBox(
                  width: 200,
                  height: 300,
                  child: GridItemSkeleton(enabled: false),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CardSkeleton), findsOneWidget);
      expect(find.byType(ListItemSkeleton), findsOneWidget);
      expect(find.byType(GridItemSkeleton), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('SkeletonLoader', () {
    testWidgets('cross-fades from skeleton to content', (
      WidgetTester tester,
    ) async {
      Widget build({required bool loading}) {
        return _wrap(
          SkeletonLoader(
            loading: loading,
            skeleton: LoadingSkeleton(width: 100, height: 20, enabled: false),
            child: const Text('Content'),
          ),
        );
      }

      await tester.pumpWidget(build(loading: true));
      expect(find.byType(LoadingSkeleton), findsOneWidget);
      expect(find.text('Content'), findsNothing);

      await tester.pumpWidget(build(loading: false));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(LoadingSkeleton), findsNothing);
    });
  });
}
