import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test: every exported widget builds once inside a plain MaterialApp.
///
/// Looping animations are configured off (or torn down before the test ends)
/// so no timers or tickers leak.
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  Future<void> smoke(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(wrap(child));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(Container());
    expect(tester.takeException(), isNull);
  }

  group('smoke: every exported widget builds', () {
    testWidgets('TapFeedback', (WidgetTester tester) async {
      await smoke(tester, TapFeedback(child: Text('x')));
    });

    testWidgets('ButtonStates', (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);
      await smoke(
        tester,
        ButtonStates(controller: controller, child: const Text('x')),
      );
    });

    testWidgets('HoverGlow', (WidgetTester tester) async {
      await smoke(tester, HoverGlow(child: Text('x')));
    });

    testWidgets('InputFocus', (WidgetTester tester) async {
      await smoke(tester, InputFocus(child: TextField()));
    });

    testWidgets('RippleEffect, RippleButton and WaterRipple', (
      WidgetTester tester,
    ) async {
      await smoke(
        tester,
        Column(
          children: <Widget>[
            RippleEffect(child: SizedBox(width: 50, height: 20)),
            RippleButton(onTap: () {}, child: const Text('x')),
            WaterRipple(autoPlay: false, child: Icon(Icons.mic)),
          ],
        ),
      );
    });

    testWidgets('FloatingLabel', (WidgetTester tester) async {
      await smoke(tester, FloatingLabel(label: 'Label'));
    });

    testWidgets('ElasticScroll, ElasticListView and ElasticGridView', (
      WidgetTester tester,
    ) async {
      await smoke(tester, ElasticScroll(child: Container(height: 10)));
      await smoke(tester, const ElasticListView(children: <Widget>[Text('x')]));
      await smoke(
        tester,
        const ElasticGridView(crossAxisCount: 2, children: <Widget>[Text('x')]),
      );
    });

    testWidgets('ParallaxScroll', (WidgetTester tester) async {
      await smoke(
        tester,
        ParallaxScroll(
          background: Container(color: Colors.blue),
          children: const <Widget>[SizedBox(height: 40, child: Text('x'))],
        ),
      );
    });

    testWidgets('PullToRefresh', (WidgetTester tester) async {
      await smoke(
        tester,
        PullToRefresh(
          onRefresh: () async {},
          child: ListView(children: const <Widget>[Text('x')]),
        ),
      );
    });

    testWidgets('SwipeActions', (WidgetTester tester) async {
      await smoke(
        tester,
        SwipeActions(
          rightActions: <MicroSwipeAction>[
            const MicroSwipeAction(
              icon: Icons.delete,
              label: 'Delete',
              backgroundColor: Colors.red,
            ),
          ],
          child: const ListTile(title: Text('x')),
        ),
      );
    });

    testWidgets('MicroReorderableList', (WidgetTester tester) async {
      await smoke(
        tester,
        MicroReorderableList(
          onReorder: (int oldIndex, int newIndex) {},
          children: const <Widget>[
            SizedBox(key: ValueKey<int>(0), height: 40, child: Text('x')),
          ],
        ),
      );
    });

    testWidgets('LongPressMenu', (WidgetTester tester) async {
      await smoke(
        tester,
        LongPressMenu(
          menuItems: <LongPressMenuItem>[LongPressMenuItem.copy()],
          child: const Text('x'),
        ),
      );
    });

    testWidgets('LoadingSkeleton family', (WidgetTester tester) async {
      await smoke(
        tester,
        SkeletonScope(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                LoadingSkeleton(width: 50, height: 10),
                TextSkeleton(),
                CardSkeleton(),
                ListItemSkeleton(),
                SizedBox(width: 100, height: 160, child: GridItemSkeleton()),
                SkeletonLoader(
                  loading: false,
                  skeleton: LoadingSkeleton(width: 50, height: 10),
                  child: Text('x'),
                ),
              ],
            ),
          ),
        ),
      );
    });

    testWidgets('MorphingShapes and ShapeMorph', (WidgetTester tester) async {
      await smoke(
        tester,
        Column(
          children: <Widget>[
            MorphingShapes(
              shapes: const <MicroShapeType>[
                MicroShapeType.circle,
                MicroShapeType.square,
              ],
            ),
            ShapeMorph(
              fromShape: MicroShapeType.triangle,
              toShape: MicroShapeType.star,
            ),
          ],
        ),
      );
    });

    testWidgets('MicroPageRoute via MicroNavigator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const Text('Home')));
      MicroNavigator.push(
        tester.element(find.text('Home')),
        const Scaffold(body: Text('Pushed')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pushed'), findsOneWidget);
    });

    testWidgets('ToastNotification', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const Text('Home')));
      tester
          .element(find.text('Home'))
          .showToast(
            message: 'Toast',
            duration: const Duration(milliseconds: 100),
          );
      await tester.pump();
      expect(find.text('Toast'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Toast'), findsNothing);
    });

    testWidgets('ShakeToAction, ShakeAnimation and ShakeButton', (
      WidgetTester tester,
    ) async {
      await smoke(
        tester,
        Column(
          children: <Widget>[
            ShakeToAction(onShake: () {}, child: const Text('a')),
            ShakeAnimation(child: Text('b')),
            ShakeButton(
              builder: (BuildContext context, VoidCallback handlePressed) =>
                  TextButton(onPressed: handlePressed, child: const Text('c')),
            ),
          ],
        ),
      );
    });

    testWidgets('CardFlip', (WidgetTester tester) async {
      await smoke(tester, CardFlip(front: Text('f'), back: Text('b')));
    });

    testWidgets('SuccessBurst', (WidgetTester tester) async {
      await smoke(tester, SuccessBurst(child: Icon(Icons.check)));
    });

    testWidgets('PulseHighlight', (WidgetTester tester) async {
      await smoke(
        tester,
        PulseHighlight(autoPlay: false, child: Icon(Icons.settings)),
      );
    });

    testWidgets('AnimatedCounter', (WidgetTester tester) async {
      await smoke(tester, AnimatedCounter(value: 42));
      await smoke(
        tester,
        AnimatedCounter(value: 42, mode: CounterAnimationMode.slideDigits),
      );
    });

    testWidgets('AnimatedBadge', (WidgetTester tester) async {
      await smoke(
        tester,
        AnimatedBadge(count: 3, child: Icon(Icons.shopping_cart)),
      );
    });

    testWidgets('StaggeredList and StaggeredItem', (WidgetTester tester) async {
      await smoke(tester, const StaggeredList(children: <Widget>[Text('x')]));
      await smoke(tester, const StaggeredItem(index: 0, child: Text('y')));
    });

    testWidgets('ShimmerButton', (WidgetTester tester) async {
      await smoke(
        tester,
        ShimmerButton(onPressed: () {}, child: const Text('x')),
      );
    });

    testWidgets('SlideToConfirm', (WidgetTester tester) async {
      await smoke(tester, SlideToConfirm(onConfirmed: () {}));
    });

    testWidgets('AnimatedCheck', (WidgetTester tester) async {
      await smoke(tester, const AnimatedCheck(autoPlay: false));
    });

    testWidgets('ExpandableFab', (WidgetTester tester) async {
      await smoke(
        tester,
        ExpandableFab(
          actions: <ExpandableFabAction>[
            ExpandableFabAction(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
        ),
      );
    });

    testWidgets('AnimatedGradientBorder', (WidgetTester tester) async {
      await smoke(
        tester,
        const AnimatedGradientBorder(autoPlay: false, child: Text('x')),
      );
    });

    testWidgets('TypewriterText', (WidgetTester tester) async {
      await smoke(
        tester,
        const TypewriterText(strings: <String>['hello'], autoPlay: false),
      );
    });

    testWidgets('LiquidProgress', (WidgetTester tester) async {
      await smoke(tester, const LiquidProgress(value: 0.5, animateWave: false));
    });
  });
}
