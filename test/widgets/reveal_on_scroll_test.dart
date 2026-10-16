import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/reveal_on_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(body: child),
    ),
  );
}

/// Current opacity of the [RevealOnScroll] with [key].
double _opacity(WidgetTester tester, Key key) {
  final FadeTransition fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byKey(key, skipOffstage: false),
          matching: find.byType(FadeTransition, skipOffstage: false),
        )
        .first,
  );
  return fade.opacity.value;
}

/// Current transform applied by the [RevealOnScroll] with [key].
Matrix4 _transform(WidgetTester tester, Key key) {
  final Transform transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byKey(key, skipOffstage: false),
          matching: find.byType(Transform, skipOffstage: false),
        )
        .first,
  );
  return transform.transform;
}

Widget _box(String label, {double height = 200, double? width}) {
  return SizedBox(
    height: height,
    width: width,
    child: ColoredBox(color: Colors.blue, child: Text(label)),
  );
}

const Duration _duration = Duration(milliseconds: 600);

void main() {
  group('RevealOnScroll', () {
    testWidgets('reveals a visible child with the default slide up', (
      WidgetTester tester,
    ) async {
      const Key key = Key('first');
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                RevealOnScroll(key: key, child: _box('first')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('first'), findsOneWidget);
      expect(_opacity(tester, key), 0.0);

      await tester.pump(); // Visibility check runs after the first frame.
      await tester.pump(const Duration(milliseconds: 150));
      final double midOpacity = _opacity(tester, key);
      final double midShift = _transform(tester, key).getTranslation().y;
      expect(midOpacity, greaterThan(0.0));
      expect(midOpacity, lessThan(1.0));
      expect(midShift, greaterThan(0.0));
      expect(midShift, lessThan(40.0));

      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
      expect(_transform(tester, key).getTranslation().y, 0.0);
    });

    testWidgets('children below the fold stay hidden until scrolled in', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      const Key top = Key('top');
      const Key below = Key('below');
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: <Widget>[
                RevealOnScroll(key: top, child: _box('top')),
                const SizedBox(height: 1200),
                RevealOnScroll(key: below, child: _box('below')),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, top), 1.0);
      expect(_opacity(tester, below), 0.0);

      // Partly visible, but below the 15% threshold.
      controller.jumpTo(1400 - 600 + 20);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacity(tester, below), 0.0);

      controller.jumpTo(1400 - 600 + 100);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacity(tester, below), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, below), 1.0);
    });

    testWidgets('lazy ListView items animate as they are scrolled in', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ListView.builder(
            controller: controller,
            itemCount: 30,
            itemBuilder: (BuildContext context, int i) =>
                RevealOnScroll(key: ValueKey<int>(i), child: _box('item $i')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(0)), 1.0);
      expect(_opacity(tester, const ValueKey<int>(2)), 1.0);
      // Built in the cache extent below the viewport, but not visible.
      expect(
        find.byKey(const ValueKey<int>(3), skipOffstage: false),
        findsOneWidget,
      );
      expect(_opacity(tester, const ValueKey<int>(3)), 0.0);

      controller.jumpTo(2000);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      expect(_opacity(tester, const ValueKey<int>(10)), 0.0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacity(tester, const ValueKey<int>(10)), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(10)), 1.0);
    });

    testWidgets('once keeps the child revealed after leaving the viewport', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      const Key key = Key('once');
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: <Widget>[
                RevealOnScroll(key: key, child: _box('once')),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);

      controller.jumpTo(1000);
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump();
      expect(_opacity(tester, key), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('once false resets after leaving and replays on return', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      const Key key = Key('again');
      int revealed = 0;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: <Widget>[
                RevealOnScroll(
                  key: key,
                  once: false,
                  onRevealed: () => revealed++,
                  child: _box('again'),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
      expect(revealed, 1);

      // Still partly visible: stays revealed.
      controller.jumpTo(190);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump();
      expect(_opacity(tester, key), 1.0);

      // Completely out of view: resets.
      controller.jumpTo(1000);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump();
      expect(_opacity(tester, key), 0.0);

      controller.jumpTo(0);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester, key), greaterThan(0.0));
      expect(_opacity(tester, key), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
      expect(revealed, 2);
    });

    testWidgets('reveals on mount without a Scrollable ancestor', (
      WidgetTester tester,
    ) async {
      const Key key = Key('plain');
      int revealed = 0;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: RevealOnScroll(
              key: key,
              effect: RevealEffect.scale,
              onRevealed: () => revealed++,
              child: _box('plain', width: 100),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacity(tester, key), greaterThan(0.0));
      expect(revealed, 0);
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
      expect(revealed, 1);
    });

    testWidgets('works in a horizontal list', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: 20,
              itemBuilder: (BuildContext context, int i) => RevealOnScroll(
                key: ValueKey<int>(i),
                effect: RevealEffect.slideLeft,
                child: _box('h$i', width: 300),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(0)), 1.0);
      expect(_opacity(tester, const ValueKey<int>(2)), 1.0);
      expect(_opacity(tester, const ValueKey<int>(3)), 0.0);

      controller.jumpTo(600);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump(const Duration(milliseconds: 100));
      final double shift = _transform(
        tester,
        const ValueKey<int>(3),
      ).getTranslation().x;
      expect(shift, greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(3)), 1.0);
    });

    testWidgets('a carousel below the fold waits for the outer scroll', (
      WidgetTester tester,
    ) async {
      final ScrollController outer = ScrollController();
      addTearDown(outer.dispose);
      const Key key = Key('carousel-item');
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: outer,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 900),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      RevealOnScroll(key: key, child: _box('c', width: 200)),
                    ],
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 0.0);

      outer.jumpTo(600);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
    });

    testWidgets('works with slivers in a CustomScrollView', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            controller: controller,
            slivers: <Widget>[
              const SliverToBoxAdapter(child: SizedBox(height: 700)),
              SliverList.builder(
                itemCount: 10,
                itemBuilder: (BuildContext context, int i) => RevealOnScroll(
                  key: ValueKey<int>(i),
                  effect: RevealEffect.fade,
                  child: _box('s$i', height: 100),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(0)), 0.0);

      controller.jumpTo(300);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pumpAndSettle();
      expect(_opacity(tester, const ValueKey<int>(0)), 1.0);
      expect(_opacity(tester, const ValueKey<int>(1)), 1.0);
    });

    testWidgets('reduced motion shows the child at once without frames', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      const Key top = Key('top');
      const Key below = Key('below');
      int revealed = 0;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: <Widget>[
                RevealOnScroll(key: top, child: _box('top')),
                const SizedBox(height: 1200),
                RevealOnScroll(
                  key: below,
                  onRevealed: () => revealed++,
                  child: _box('below'),
                ),
              ],
            ),
          ),
          reducedMotion: true,
        ),
      );
      expect(_opacity(tester, top), 1.0);
      expect(_opacity(tester, below), 1.0);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(revealed, 0);

      controller.jumpTo(1000);
      await tester.pump(); // Runs the visibility check.
      await tester.pump(); // First tick of the entrance.
      await tester.pump();
      expect(revealed, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('enabled false shows the child at once', (
      WidgetTester tester,
    ) async {
      const Key key = Key('off');
      await tester.pumpWidget(
        _wrap(RevealOnScroll(key: key, enabled: false, child: _box('off'))),
      );
      expect(_opacity(tester, key), 1.0);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('delay postpones the entrance', (WidgetTester tester) async {
      const Key key = Key('late');
      await tester.pumpWidget(
        _wrap(
          RevealOnScroll(
            key: key,
            delay: const Duration(milliseconds: 300),
            child: _box('late'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_opacity(tester, key), 0.0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, key), greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);
    });

    testWidgets('layout never changes during the reveal', (
      WidgetTester tester,
    ) async {
      const Key key = Key('layout');
      for (final RevealEffect effect in RevealEffect.values) {
        await tester.pumpWidget(
          _wrap(
            ListView(
              children: <Widget>[
                RevealOnScroll(key: key, effect: effect, child: _box('layout')),
              ],
            ),
          ),
        );
        final Size before = tester.getSize(find.text('layout'));
        final Rect boxBefore = tester.getRect(find.byKey(key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getRect(find.byKey(key)), boxBefore, reason: '$effect');
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(key)), boxBefore, reason: '$effect');
        expect(tester.getSize(find.text('layout')), before, reason: '$effect');
        expect(_opacity(tester, key), 1.0, reason: '$effect');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('hidden children keep their semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 700),
                RevealOnScroll(child: _box('hidden label')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('hidden label'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      const Key key = Key('change');
      await tester.pumpWidget(
        _wrap(RevealOnScroll(key: key, child: _box('x'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          RevealOnScroll(
            key: key,
            effect: RevealEffect.tilt,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            initialOpacity: 0.3,
            once: false,
            threshold: 0.5,
            child: _box('x'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_opacity(tester, key), 1.0);

      // Turning the animation off mid-way completes it at once.
      await tester.pumpWidget(
        _wrap(RevealOnScroll(key: key, enabled: false, child: _box('x'))),
      );
      expect(_opacity(tester, key), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation or mid-delay does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: <Widget>[
              RevealOnScroll(effect: RevealEffect.blur, child: _box('a')),
              RevealOnScroll(
                delay: const Duration(seconds: 1),
                child: _box('b'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every effect reaches the identity transform', (
      WidgetTester tester,
    ) async {
      for (final RevealEffect effect in RevealEffect.values) {
        final Key key = ValueKey<RevealEffect>(effect);
        await tester.pumpWidget(
          _wrap(
            RevealOnScroll(
              key: key,
              effect: effect,
              duration: _duration,
              child: _box(effect.name),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final bool moves =
            effect != RevealEffect.fade && effect != RevealEffect.blur;
        expect(
          _transform(tester, key).isIdentity(),
          !moves,
          reason: '$effect mid-animation',
        );
        if (effect == RevealEffect.blur) {
          final ImageFiltered filtered = tester.widget<ImageFiltered>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(ImageFiltered),
            ),
          );
          expect(filtered.enabled, isTrue);
        }
        await tester.pumpAndSettle();
        expect(_transform(tester, key).isIdentity(), isTrue, reason: '$effect');
        final ImageFiltered filtered = tester.widget<ImageFiltered>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(ImageFiltered),
          ),
        );
        expect(filtered.enabled, isFalse, reason: '$effect');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
