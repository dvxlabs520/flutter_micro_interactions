import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/typewriter_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

Widget _wrapReduced(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Reads the currently visible (typed) substring.
String _visible(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find.byKey(const ValueKey<String>('TypewriterText.visible')),
  );
  final TextSpan span = text.textSpan! as TextSpan;
  return (span.children!.first as TextSpan).text ?? '';
}

/// Reads the cursor span, or null when no cursor is rendered.
TextSpan? _cursorSpan(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find.byKey(const ValueKey<String>('TypewriterText.visible')),
  );
  final TextSpan span = text.textSpan! as TextSpan;
  if (span.children!.length < 2) return null;
  return span.children![1] as TextSpan;
}

void main() {
  group('TypewriterText', () {
    testWidgets('types a full string character by character',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: 'abc',
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
      )));
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'abc');
      // Non-loop single string: nothing further is scheduled.
      await tester.pump(const Duration(seconds: 2));
      expect(_visible(tester), 'abc');
    });

    testWidgets('advances through multiple strings with deletion',
        (WidgetTester tester) async {
      int completed = 0;
      int all = 0;
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['ab', 'cd'],
        typeSpeed: const Duration(milliseconds: 100),
        deleteSpeed: const Duration(milliseconds: 50),
        pauseBetween: const Duration(milliseconds: 300),
        showCursor: false,
        onStringCompleted: () => completed++,
        onAllCompleted: () => all++,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'ab');
      expect(completed, 1);
      // Pause expiry deletes the first character.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_visible(tester), 'a');
      // Second deletion empties the text and advances to the next string.
      await tester.pump(const Duration(milliseconds: 50));
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'c');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'cd');
      expect(completed, 2);
      expect(all, 1);
      // loop: false stays on the final string; onAllCompleted fired once.
      await tester.pump(const Duration(seconds: 3));
      expect(_visible(tester), 'cd');
      expect(all, 1);
    });

    testWidgets('deleteBeforeNext false clears instantly',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['ab', 'c'],
        typeSpeed: const Duration(milliseconds: 100),
        pauseBetween: const Duration(milliseconds: 300),
        deleteBeforeNext: false,
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_visible(tester), 'ab');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'c');
    });

    testWidgets('loop true cycles back to the first string',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['a', 'b'],
        typeSpeed: const Duration(milliseconds: 100),
        deleteSpeed: const Duration(milliseconds: 50),
        pauseBetween: const Duration(milliseconds: 200),
        loop: true,
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      // Pause, then the single character is deleted and the index advances.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'b');
      // And back around to the first string.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      // Dispose to cancel looping timers before the test ends.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller start, stop and reset',
        (WidgetTester tester) async {
      final TypewriterController controller = TypewriterController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: 'abc',
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
        autoPlay: false,
        controller: controller,
      )));
      // autoPlay false: nothing types until start().
      await tester.pump(const Duration(milliseconds: 500));
      expect(_visible(tester), '');
      expect(controller.isTyping, isFalse);

      controller.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      expect(controller.isTyping, isTrue);

      controller.stop();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_visible(tester), 'a');
      expect(controller.isTyping, isFalse);

      controller.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'ab');

      controller.reset();
      await tester.pump();
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('emoji strings are typed by grapheme cluster',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: '\u{1F389}\u{1F44D}\u{1F3FD}é',
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), '\u{1F389}');
      await tester.pump(const Duration(milliseconds: 100));
      // The skin-tone modifier stays glued to its base emoji.
      expect(_visible(tester), '\u{1F389}\u{1F44D}\u{1F3FD}');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), '\u{1F389}\u{1F44D}\u{1F3FD}é');
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty-string element is skipped without hanging',
        (WidgetTester tester) async {
      int completed = 0;
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['', 'ab'],
        typeSpeed: const Duration(milliseconds: 100),
        deleteSpeed: const Duration(milliseconds: 50),
        pauseBetween: const Duration(milliseconds: 200),
        showCursor: false,
        onStringCompleted: () => completed++,
      )));
      // First tick completes the empty string immediately.
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, 1);
      // Pause, then nothing to delete: advance and type the next string.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'ab');
      expect(completed, 2);
    });

    testWidgets('reduced motion shows the last string complete, no timers',
        (WidgetTester tester) async {
      int all = 0;
      await tester.pumpWidget(_wrapReduced(TypewriterText(
        strings: const <String>['a', 'bb'],
        onAllCompleted: () => all++,
      )));
      await tester.pump();
      expect(_visible(tester), 'bb');
      expect(all, 1);
      // No timers pending: advancing time changes nothing and the test
      // framework would fail on leftover timers.
      await tester.pump(const Duration(seconds: 5));
      expect(_visible(tester), 'bb');
      expect(all, 1);
    });

    testWidgets('reduced motion with loop shows the first string, no cycle',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapReduced(TypewriterText(
        strings: const <String>['first', 'second'],
        loop: true,
      )));
      await tester.pump(const Duration(seconds: 5));
      expect(_visible(tester), 'first');
    });

    testWidgets('disposal mid-typing leaves no pending timers',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['abcdef', 'ghi'],
        typeSpeed: const Duration(milliseconds: 100),
        loop: true,
      )));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false freezes and enabled true resumes',
        (WidgetTester tester) async {
      Widget build({required bool enabled}) {
        return _wrap(TypewriterText(
          strings: const <String>['abc'],
          typeSpeed: const Duration(milliseconds: 100),
          showCursor: false,
          enabled: enabled,
        ));
      }

      await tester.pumpWidget(build(enabled: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'a');
      await tester.pumpWidget(build(enabled: false));
      await tester.pump(const Duration(seconds: 1));
      expect(_visible(tester), 'a');
      await tester.pumpWidget(build(enabled: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'abc');
    });

    testWidgets('changing strings restarts cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['abcdef'],
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_visible(tester), 'abc');
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['xy'],
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
      )));
      expect(_visible(tester), '');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'x');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'xy');
    });

    testWidgets('semantics exposes the full target while typing',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: 'hello',
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'h');
      expect(
        tester.getSemantics(find.byType(TypewriterText)),
        matchesSemantics(label: 'hello'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      handle.dispose();
    });

    testWidgets('semanticLabel overrides the default label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: 'hello',
        showCursor: false,
        autoPlay: false,
        semanticLabel: 'Greeting',
      )));
      expect(
        tester.getSemantics(find.byType(TypewriterText)),
        matchesSemantics(label: 'Greeting'),
      );
      handle.dispose();
    });

    testWidgets('cursor blinks on its own timer', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText.single(
        text: 'a',
        typeSpeed: const Duration(milliseconds: 100),
        cursorBlinkSpeed: const Duration(milliseconds: 200),
        cursorColor: Colors.red,
      )));
      TextSpan cursor = _cursorSpan(tester)!;
      expect(cursor.text, '|');
      expect(cursor.style!.color!.a, greaterThan(0.0));
      await tester.pump(const Duration(milliseconds: 200));
      cursor = _cursorSpan(tester)!;
      expect(cursor.style!.color!.a, 0.0);
      await tester.pump(const Duration(milliseconds: 200));
      cursor = _cursorSpan(tester)!;
      expect(cursor.style!.color!.a, greaterThan(0.0));
      // Dispose so the blink timer is cancelled before the test ends.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid config changes mid-animation do not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['abc', 'def'],
        typeSpeed: const Duration(milliseconds: 100),
        showCursor: false,
        loop: true,
      )));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['abc', 'def'],
        typeSpeed: const Duration(milliseconds: 20),
        deleteSpeed: const Duration(milliseconds: 10),
        pauseBetween: const Duration(milliseconds: 50),
        showCursor: false,
        loop: true,
      )));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(_wrap(TypewriterText(
        strings: const <String>['zz'],
        typeSpeed: const Duration(milliseconds: 20),
        showCursor: false,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), 'zz');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
