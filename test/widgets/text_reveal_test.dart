import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/text_reveal.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Opacity of every animated unit, in text order.
List<double> _opacities(WidgetTester tester) {
  return tester
      .widgetList<Opacity>(
        find.descendant(
          of: find.byType(TextReveal),
          matching: find.byType(Opacity),
        ),
      )
      .map((Opacity o) => o.opacity)
      .toList();
}

/// Texts of every animated unit, in text order.
List<String> _units(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(TextReveal),
          matching: find.byType(Text),
        ),
      )
      .where((Text t) => t.data != null)
      .map((Text t) => t.data!)
      .toList();
}

void main() {
  group('TextReveal', () {
    testWidgets('renders every unit and ends fully revealed', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(TextReveal(text: 'Hi you', onCompleted: () => completed++)),
      );
      expect(_units(tester), <String>['H', 'i', 'y', 'o', 'u']);
      expect(_opacities(tester), everyElement(0.0));
      await tester.pumpAndSettle();
      expect(_opacities(tester), everyElement(1.0));
      expect(completed, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('units progress with a stagger', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: 'abc',
            effect: TextRevealEffect.fade,
            duration: Duration(milliseconds: 300),
            stagger: Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final List<double> mid = _opacities(tester);
      expect(mid[0], greaterThan(0.0));
      expect(mid[0], lessThan(1.0));
      expect(mid[1], greaterThan(0.0));
      expect(mid[1], lessThan(mid[0]));
      expect(mid[2], 0.0);
      // Total = 300 + 2 * 100 milliseconds.
      await tester.pump(const Duration(milliseconds: 350));
      expect(_opacities(tester), everyElement(1.0));
    });

    testWidgets('splits by words', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: 'one two  three',
            splitBy: TextRevealSplit.words,
          ),
        ),
      );
      expect(_units(tester), <String>['one', 'two', 'three']);
      await tester.pumpAndSettle();
    });

    testWidgets('never splits grapheme clusters', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const TextReveal(text: 'a\u{1F44D}\u{1F3FD}é')),
      );
      expect(_units(tester), <String>['a', '\u{1F44D}\u{1F3FD}', 'é']);
      await tester.pumpAndSettle();
    });

    testWidgets('joining and complex scripts fall back to words', (
      WidgetTester tester,
    ) async {
      const Map<String, List<String>> samples = <String, List<String>>{
        '\u0645\u0631\u062D\u0628\u0627 \u0628\u0643': <String>[
          '\u0645\u0631\u062D\u0628\u0627',
          '\u0628\u0643',
        ], // Arabic
        '\u05E9\u05DC\u05D5\u05DD': <String>[
          '\u05E9\u05DC\u05D5\u05DD',
        ], // Hebrew
        '\u072B\u0720\u0721\u0710': <String>[
          '\u072B\u0720\u0721\u0710',
        ], // Syriac
        '\u078B\u07A8\u0788\u07AC': <String>[
          '\u078B\u07A8\u0788\u07AC',
        ], // Thaana
        '\u07D2\u07DE\u07CF': <String>['\u07D2\u07DE\u07CF'], // N'Ko
        '\u1828\u1823\u1829': <String>['\u1828\u1823\u1829'], // Mongolian
        '\u0928\u092E\u0938\u094D\u0924\u0947 ok': <String>[
          '\u0928\u092E\u0938\u094D\u0924\u0947',
          'ok',
        ], // Devanagari mixed with Latin
      };
      for (final MapEntry<String, List<String>> sample in samples.entries) {
        await tester.pumpWidget(
          _wrap(
            TextReveal(
              key: ValueKey<String>(sample.key),
              text: sample.key,
              enabled: false,
            ),
          ),
        );
        expect(_units(tester), sample.value, reason: sample.key);
      }
    });

    testWidgets('right-to-left text is laid out right to left', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: '\u0645\u0631\u062D\u0628\u0627 \u0628\u0643',
            enabled: false,
          ),
        ),
      );
      final Text paragraph = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(TextReveal),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(paragraph.textDirection, TextDirection.rtl);
      // First word sits to the right of the second one.
      expect(
        tester.getCenter(find.text('\u0645\u0631\u062D\u0628\u0627')).dx,
        greaterThan(tester.getCenter(find.text('\u0628\u0643')).dx),
      );
    });

    testWidgets('right-to-left text wraps and keeps line breaks', (
      WidgetTester tester,
    ) async {
      const String a = '\u0645\u0631\u062D\u0628\u0627';
      const String b = '\u0628\u0643';
      const String c = '\u0633\u0644\u0627\u0645';
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 120,
            child: TextReveal(
              text: '$a $b $c\n\n$b',
              style: TextStyle(fontSize: 10),
              enabled: false,
            ),
          ),
        ),
      );
      final Rect ra = tester.getRect(find.text(a));
      final Rect rc = tester.getRect(find.text(c));
      final List<Rect> rb = find.text(b).evaluate().map((Element e) {
        final RenderBox box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }).toList();
      // 'a b' fit on the first line, right to left; 'c' wraps.
      expect(rb.first.top, ra.top);
      expect(rb.first.right, lessThan(ra.left));
      expect(rc.top, greaterThan(ra.top));
      // The blank line keeps its height before the last line.
      expect(rb.last.top - rc.top, closeTo(2 * ra.height, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a right-to-left context falls back to words', (
      WidgetTester tester,
    ) async {
      Widget build(TextDirection direction) => _wrap(
        Directionality(
          textDirection: direction,
          child: const TextReveal(text: 'ab cd'),
        ),
      );
      await tester.pumpWidget(build(TextDirection.ltr));
      expect(_units(tester), <String>['a', 'b', 'c', 'd']);
      await tester.pump(const Duration(milliseconds: 100));
      // Switching direction mid-animation regroups the units.
      await tester.pumpWidget(build(TextDirection.rtl));
      expect(_units(tester), <String>['ab', 'cd']);
      await tester.pumpAndSettle();
      expect(_opacities(tester), everyElement(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps at spaces and keeps words on one line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 60,
            child: TextReveal(
              text: 'aaaa bbbb',
              style: TextStyle(fontSize: 10),
              enabled: false,
            ),
          ),
        ),
      );
      final List<double> aTops = tester
          .widgetList<Text>(find.text('a'))
          .map((Text t) => tester.getTopLeft(find.byWidget(t)).dy)
          .toList();
      final Iterable<Element> bs = find.text('b').evaluate();
      final List<Offset> bOffsets = bs
          .map(
            (Element e) => tester.getTopLeft(
              find.byElementPredicate((Element other) => identical(other, e)),
            ),
          )
          .toList();
      expect(bOffsets, hasLength(4));
      // Every b sits on the same, lower line.
      for (final Offset offset in bOffsets) {
        expect(offset.dy, bOffsets.first.dy);
        expect(offset.dy, greaterThan(aTops.first));
      }
      // Characters of the word stay in order.
      for (int i = 1; i < bOffsets.length; i++) {
        expect(bOffsets[i].dx, greaterThan(bOffsets[i - 1].dx));
      }
    });

    testWidgets('respects the text scaler exactly once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const TextReveal(
                      text: 'ab cd',
                      style: TextStyle(fontSize: 10),
                      enabled: false,
                    ),
                    Text(
                      'ab cd',
                      key: const ValueKey<String>('plain'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // Double scaling would make the reveal about twice as wide.
      expect(
        tester.getSize(find.byType(TextReveal)).width,
        closeTo(
          tester.getSize(find.byKey(const ValueKey<String>('plain'))).width,
          2.0,
        ),
      );
    });

    testWidgets('slideUp translates units from below', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: 'a',
            style: TextStyle(fontSize: 20),
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      Transform transform() => tester.widget<Transform>(
        find.descendant(
          of: find.byType(TextReveal),
          matching: find.byType(Transform),
        ),
      );
      expect(transform().transform.getTranslation().y, closeTo(8.0, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = transform().transform.getTranslation().y;
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(8.0));
      await tester.pumpAndSettle();
      expect(transform().transform.getTranslation().y, 0.0);
    });

    testWidgets('blur clears to sharp text', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: 'a',
            effect: TextRevealEffect.blur,
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      ImageFiltered filtered() => tester.widget<ImageFiltered>(
        find.descendant(
          of: find.byType(TextReveal),
          matching: find.byType(ImageFiltered),
        ),
      );
      expect(filtered().enabled, isTrue);
      await tester.pumpAndSettle();
      expect(filtered().enabled, isFalse);
    });

    testWidgets('scale grows units to full size', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const TextReveal(text: 'a', effect: TextRevealEffect.scale)),
      );
      double scale() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(TextReveal),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .entry(0, 0);
      expect(scale(), closeTo(0.6, 0.001));
      await tester.pumpAndSettle();
      expect(scale(), closeTo(1.0, 0.001));
    });

    testWidgets('controller play and reset', (WidgetTester tester) async {
      final TextRevealController controller = TextRevealController();
      addTearDown(controller.dispose);
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          TextReveal(
            text: 'ab',
            autoPlay: false,
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_opacities(tester), everyElement(0.0));
      expect(controller.isAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      controller.play();
      await tester.pump();
      expect(controller.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacities(tester).first, greaterThan(0.0));
      await tester.pumpAndSettle();
      expect(_opacities(tester), everyElement(1.0));
      expect(controller.isCompleted, isTrue);
      expect(completed, 1);

      controller.reset();
      await tester.pump();
      expect(_opacities(tester), everyElement(0.0));
      expect(controller.isCompleted, isFalse);

      controller.play();
      await tester.pumpAndSettle();
      expect(completed, 2);

      // play() on a completed reveal replays it.
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_opacities(tester).last, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(completed, 3);
    });

    testWidgets('changing the text replays the reveal', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      Widget build(String text) =>
          _wrap(TextReveal(text: text, onCompleted: () => completed++));
      await tester.pumpWidget(build('ab'));
      await tester.pumpAndSettle();
      expect(completed, 1);
      await tester.pumpWidget(build('xyz'));
      expect(_units(tester), <String>['x', 'y', 'z']);
      expect(_opacities(tester), everyElement(0.0));
      await tester.pumpAndSettle();
      expect(_opacities(tester), everyElement(1.0));
      expect(completed, 2);
    });

    testWidgets('changing text mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const TextReveal(text: 'abc')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(
        _wrap(
          const TextReveal(
            text: 'hello world',
            splitBy: TextRevealSplit.words,
            duration: Duration(milliseconds: 200),
            stagger: Duration(milliseconds: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacities(tester), everyElement(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion shows the final text at once', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          TextReveal(text: 'abc', onCompleted: () => completed++),
          reducedMotion: true,
        ),
      );
      expect(_opacities(tester), everyElement(1.0));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(completed, 1);
    });

    testWidgets('enabled false shows the final text at once', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          TextReveal(
            text: 'abc',
            enabled: false,
            autoPlay: false,
            onCompleted: () => completed++,
          ),
        ),
      );
      expect(_opacities(tester), everyElement(1.0));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(completed, 1);
    });

    testWidgets('disabling mid-animation completes it', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      Widget build(bool enabled) => _wrap(
        TextReveal(
          text: 'abc',
          enabled: enabled,
          onCompleted: () => completed++,
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(_opacities(tester), everyElement(1.0));
      expect(completed, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('exposes the full text as one semantics label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const TextReveal(text: 'Hello world')));
      expect(find.bySemanticsLabel('Hello world'), findsOneWidget);
      expect(find.bySemanticsLabel('H'), findsNothing);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      final TextRevealController controller = TextRevealController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(TextReveal(text: 'abcdef', controller: controller)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(controller.isAnimating, isFalse);
      // Calls after detaching are ignored.
      controller.play();
      controller.reset();
    });
  });
}
