import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/rotating_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Texts of every rendered unit: the incoming phrase first, then the
/// outgoing phrase while a transition runs.
List<String> _units(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(RotatingText),
          matching: find.byType(Text),
        ),
      )
      .map((Text t) => t.data!)
      .toList();
}

/// Opacity of every rendered unit, in the same order as [_units].
List<double> _opacities(WidgetTester tester) {
  return tester
      .widgetList<Opacity>(
        find.descendant(
          of: find.byType(RotatingText),
          matching: find.byType(Opacity),
        ),
      )
      .map((Opacity o) => o.opacity)
      .toList();
}

const Duration _interval = Duration(milliseconds: 1000);
const Duration _duration = Duration(milliseconds: 200);
const Duration _stagger = Duration(milliseconds: 20);

void main() {
  group('RotatingText', () {
    testWidgets('renders the first phrase', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const RotatingText(texts: <String>['ab', 'cd'])),
      );
      expect(_units(tester), <String>['a', 'b']);
      expect(_opacities(tester), everyElement(1.0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cycles at the interval and wraps around', (
      WidgetTester tester,
    ) async {
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['ab', 'cd', 'ef'],
            interval: _interval,
            duration: _duration,
            stagger: _stagger,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await tester.pump(_interval);
      expect(changes, <int>[1]);
      // Mid-transition both phrases are on screen.
      expect(_units(tester), <String>['c', 'd', 'a', 'b']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_units(tester), <String>['c', 'd']);
      await tester.pump(const Duration(milliseconds: 700));
      expect(changes, <int>[1, 2]);
      await tester.pump(_interval);
      expect(changes, <int>[1, 2, 0]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_units(tester), <String>['a', 'b']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('loop false stops on the last phrase', (
      WidgetTester tester,
    ) async {
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['a', 'b'],
            interval: _interval,
            duration: _duration,
            loop: false,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(_interval * 5);
      expect(changes, <int>[1]);
      expect(_units(tester), <String>['b']);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('units slide and fade with a stagger', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['abc', 'xyz'],
            interval: _interval,
            duration: _duration,
            stagger: Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 60));
      final List<double> opacities = _opacities(tester);
      // Incoming x, y, z then outgoing a, b, c.
      expect(opacities[0], greaterThan(opacities[1]));
      expect(opacities[1], greaterThan(0.0));
      expect(opacities[2], 0.0);
      expect(opacities[3], lessThan(opacities[4]));
      expect(opacities[5], 1.0);
      final List<FractionalTranslation> translations = tester
          .widgetList<FractionalTranslation>(
            find.descendant(
              of: find.byType(RotatingText),
              matching: find.byType(FractionalTranslation),
            ),
          )
          .toList();
      // Incoming units rise from below; outgoing units leave upwards.
      expect(translations[0].translation.dy, inExclusiveRange(0.0, 1.0));
      expect(translations[2].translation.dy, 1.0);
      expect(translations[3].translation.dy, inExclusiveRange(-1.0, 0.0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('staggerFrom last moves the last unit first', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['abc', 'xyz'],
            interval: _interval,
            duration: _duration,
            stagger: Duration(milliseconds: 50),
            staggerFrom: RotatingTextStaggerFrom.last,
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 60));
      final List<double> opacities = _opacities(tester);
      expect(opacities[2], greaterThan(opacities[1]));
      expect(opacities[0], 0.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('staggerFrom center moves the middle unit first', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['abc', 'xyz'],
            interval: _interval,
            duration: _duration,
            stagger: Duration(milliseconds: 50),
            staggerFrom: RotatingTextStaggerFrom.center,
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 30));
      final List<double> opacities = _opacities(tester);
      expect(opacities[1], greaterThan(0.0));
      expect(opacities[0], 0.0);
      expect(opacities[2], 0.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('animateSize eases the width between phrases', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['a', 'aaaaa'],
            style: TextStyle(fontSize: 10),
            interval: _interval,
            duration: _duration,
          ),
        ),
      );
      final double start = tester.getSize(find.byType(RotatingText)).width;
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = tester.getSize(find.byType(RotatingText)).width;
      await tester.pump(const Duration(milliseconds: 300));
      final double end = tester.getSize(find.byType(RotatingText)).width;
      expect(start, closeTo(10, 1));
      expect(end, closeTo(50, 2));
      expect(mid, greaterThan(start));
      expect(mid, lessThan(end));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('animateSize false jumps to the new width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['a', 'aaaaa'],
            style: TextStyle(fontSize: 10),
            interval: _interval,
            duration: _duration,
            animateSize: false,
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getSize(find.byType(RotatingText)).width, closeTo(50, 2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('splits by words and never splits graphemes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RotatingText(texts: <String>['\u{1F44D}\u{1F3FD}é'])),
      );
      expect(_units(tester), <String>['\u{1F44D}\u{1F3FD}', 'é']);
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['hello big world'],
            splitBy: RotatingTextSplit.words,
          ),
        ),
      );
      expect(_units(tester), <String>['hello', ' ', 'big', ' ', 'world']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('joining scripts and right-to-left contexts use words', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['\u0645\u0631\u062D\u0628\u0627 \u0628\u0643'],
          ),
        ),
      );
      expect(_units(tester), <String>[
        '\u0645\u0631\u062D\u0628\u0627',
        ' ',
        '\u0628\u0643',
      ]);
      final Row row = tester.widget<Row>(
        find.descendant(
          of: find.byType(RotatingText),
          matching: find.byType(Row),
        ),
      );
      expect(row.textDirection, TextDirection.rtl);

      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['\u0928\u092E\u0938\u094D\u0924\u0947'],
          ),
        ),
      );
      expect(_units(tester), <String>['\u0928\u092E\u0938\u094D\u0924\u0947']);

      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: RotatingText(texts: <String>['ab cd']),
          ),
        ),
      );
      expect(_units(tester), <String>['ab', ' ', 'cd']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('controller navigation and playback', (
      WidgetTester tester,
    ) async {
      final RotatingTextController controller = RotatingTextController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['a', 'b', 'c'],
            interval: _interval,
            duration: _duration,
            autoPlay: false,
            controller: controller,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await tester.pump(_interval * 3);
      expect(changes, isEmpty);

      controller.next();
      await tester.pump();
      expect(controller.currentIndex, 1);
      controller.previous();
      await tester.pump();
      expect(controller.currentIndex, 0);
      controller.previous();
      await tester.pump();
      expect(controller.currentIndex, 2);
      controller.jumpTo(1);
      await tester.pump();
      expect(controller.currentIndex, 1);
      expect(changes, <int>[1, 0, 2, 1]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_units(tester), <String>['b']);

      controller.start();
      await tester.pump(_interval);
      expect(controller.currentIndex, 2);
      controller.stop();
      await tester.pump(_interval * 3);
      expect(controller.currentIndex, 2);
      expect(changes, <int>[1, 0, 2, 1, 2]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a manual change restarts the interval', (
      WidgetTester tester,
    ) async {
      final RotatingTextController controller = RotatingTextController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['a', 'b', 'c'],
            interval: _interval,
            duration: _duration,
            controller: controller,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      controller.next();
      await tester.pump(const Duration(milliseconds: 800));
      expect(controller.currentIndex, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.currentIndex, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion switches instantly at the interval', (
      WidgetTester tester,
    ) async {
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['ab', 'cd'],
            interval: _interval,
            duration: _duration,
            onIndexChanged: changes.add,
          ),
          reducedMotion: true,
        ),
      );
      expect(find.byType(AnimatedSize), findsNothing);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(_interval);
      expect(changes, <int>[1]);
      expect(_units(tester), <String>['c', 'd']);
      expect(_opacities(tester), everyElement(1.0));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('enabled false does not rotate', (WidgetTester tester) async {
      final RotatingTextController controller = RotatingTextController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          RotatingText(
            texts: const <String>['ab', 'cd'],
            interval: _interval,
            enabled: false,
            controller: controller,
          ),
        ),
      );
      await tester.pump(_interval * 3);
      expect(_units(tester), <String>['a', 'b']);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Navigation still works, instantly.
      controller.next();
      await tester.pump();
      expect(_units(tester), <String>['c', 'd']);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('semantics expose the current phrase', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['first', 'second'],
            interval: _interval,
            duration: _duration,
          ),
        ),
      );
      expect(find.bySemanticsLabel('first'), findsOneWidget);
      expect(find.bySemanticsLabel('f'), findsNothing);
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('second'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('changing texts mid-transition does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['a', 'b', 'c'],
            interval: _interval,
            duration: _duration,
          ),
        ),
      );
      await tester.pump(_interval * 2);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['x'],
            interval: _interval,
            duration: _duration,
          ),
        ),
      );
      expect(_units(tester), <String>['x']);
      await tester.pump(_interval * 2);
      expect(_units(tester), <String>['x']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-transition does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RotatingText(
            texts: <String>['a', 'b'],
            interval: _interval,
            duration: _duration,
          ),
        ),
      );
      await tester.pump(_interval);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_interval);
      expect(tester.takeException(), isNull);
    });
  });
}
