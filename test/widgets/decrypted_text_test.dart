import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/decrypted_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

const Duration _tick = Duration(milliseconds: 50);

/// The currently displayed (possibly scrambled) text.
String _shown(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find.byKey(const ValueKey<String>('DecryptedText.visible')),
  );
  return text.textSpan!.toPlainText();
}

/// The displayed text split into grapheme clusters.
List<String> _graphemes(WidgetTester tester) =>
    _shown(tester).characters.toList();

void main() {
  group('DecryptedText', () {
    testWidgets('scrambles on mount and resolves to the text', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          DecryptedText(
            text: 'Decrypt me',
            seed: 7,
            maxIterations: 4,
            onCompleted: () => completed++,
          ),
        ),
      );
      final String first = _shown(tester);
      expect(first, isNot('Decrypt me'));
      expect(first.characters.length, 'Decrypt me'.characters.length);
      // The space never scrambles.
      expect(_graphemes(tester)[7], ' ');
      await tester.pump(_tick);
      final String second = _shown(tester);
      expect(second, isNot('Decrypt me'));
      expect(second, isNot(first));
      await tester.pump(_tick * 3);
      expect(_shown(tester), 'Decrypt me');
      expect(completed, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('interval sets the time between ticks', (
      WidgetTester tester,
    ) async {
      Widget build(Duration interval) => _wrap(
        DecryptedText(
          text: 'abc',
          characters: 'X',
          sequential: true,
          interval: interval,
        ),
      );
      await tester.pumpWidget(build(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_shown(tester), 'XXX');
      await tester.pump(const Duration(milliseconds: 50));
      expect(_shown(tester), 'aXX');
      // Changing the interval mid-run restarts the tick timer.
      await tester.pumpWidget(build(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_shown(tester), 'abX');
      await tester.pump(const Duration(milliseconds: 20));
      expect(_shown(tester), 'abc');
    });

    testWidgets('keeps the final layout size while scrambling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DecryptedText(text: 'Stable', seed: 1)),
      );
      final Size scrambling = tester.getSize(find.byType(DecryptedText));
      await tester.pump(_tick * 10);
      expect(_shown(tester), 'Stable');
      expect(tester.getSize(find.byType(DecryptedText)), scrambling);
    });

    testWidgets('sequential start resolves left to right', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          DecryptedText(
            text: 'abc',
            seed: 3,
            characters: 'XYZ',
            sequential: true,
            onCompleted: () => completed++,
          ),
        ),
      );
      expect(_graphemes(tester), everyElement(isIn(<String>['X', 'Y', 'Z'])));
      await tester.pump(_tick);
      expect(_graphemes(tester)[0], 'a');
      expect(
        _graphemes(tester).sublist(1),
        everyElement(isIn('XYZ'.split(''))),
      );
      await tester.pump(_tick);
      expect(_graphemes(tester).sublist(0, 2), <String>['a', 'b']);
      expect(_graphemes(tester)[2], isIn('XYZ'.split('')));
      await tester.pump(_tick);
      expect(_shown(tester), 'abc');
      expect(completed, 1);
    });

    testWidgets('sequential end resolves right to left', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DecryptedText(
            text: 'abc',
            characters: 'X',
            sequential: true,
            revealDirection: DecryptRevealDirection.end,
          ),
        ),
      );
      expect(_shown(tester), 'XXX');
      await tester.pump(_tick);
      expect(_shown(tester), 'XXc');
      await tester.pump(_tick);
      expect(_shown(tester), 'Xbc');
      await tester.pump(_tick);
      expect(_shown(tester), 'abc');
    });

    testWidgets('sequential center resolves from the middle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DecryptedText(
            text: 'abcde',
            characters: 'X',
            sequential: true,
            revealDirection: DecryptRevealDirection.center,
          ),
        ),
      );
      await tester.pump(_tick);
      expect(_shown(tester), 'XXcXX');
      await tester.pump(_tick);
      expect(_shown(tester), 'XbcXX');
      await tester.pump(_tick);
      expect(_shown(tester), 'XbcdX');
      await tester.pump(_tick * 2);
      expect(_shown(tester), 'abcde');
    });

    testWidgets('sequential random resolves one per tick', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DecryptedText(
            text: 'abcd',
            characters: 'X',
            seed: 11,
            sequential: true,
            revealDirection: DecryptRevealDirection.random,
          ),
        ),
      );
      for (int i = 1; i <= 3; i++) {
        await tester.pump(_tick);
        final int resolved = _graphemes(
          tester,
        ).where((String g) => g != 'X').length;
        expect(resolved, i);
      }
      await tester.pump(_tick);
      expect(_shown(tester), 'abcd');
    });

    testWidgets('never splits grapheme clusters', (WidgetTester tester) async {
      const String text = '\u{1F44D}\u{1F3FD} é';
      await tester.pumpWidget(
        _wrap(
          const DecryptedText(text: text, characters: 'X', sequential: true),
        ),
      );
      expect(_graphemes(tester), <String>['X', ' ', 'X']);
      await tester.pump(_tick);
      expect(_graphemes(tester), <String>['\u{1F44D}\u{1F3FD}', ' ', 'X']);
      await tester.pump(_tick);
      expect(_shown(tester), text);
    });

    testWidgets('unresolved glyphs use the encrypted style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DecryptedText(
            text: 'ab',
            characters: 'X',
            sequential: true,
            style: TextStyle(color: Color(0xFF000000)),
            encryptedStyle: TextStyle(color: Color(0xFFFF0000)),
          ),
        ),
      );
      await tester.pump(_tick);
      final Text text = tester.widget<Text>(
        find.byKey(const ValueKey<String>('DecryptedText.visible')),
      );
      final List<InlineSpan> spans = (text.textSpan! as TextSpan).children!;
      expect(spans, hasLength(2));
      expect((spans[0] as TextSpan).text, 'a');
      expect(spans[0].style, isNull);
      expect((spans[1] as TextSpan).text, 'X');
      expect(spans[1].style!.color, const Color(0xFFFF0000));
      await tester.pump(_tick);
    });

    testWidgets('hover trigger scrambles while hovered', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          DecryptedText(
            text: 'Hover',
            characters: 'X',
            animateOn: DecryptTrigger.hover,
            maxIterations: 3,
            onCompleted: () => completed++,
          ),
        ),
      );
      expect(_shown(tester), 'Hover');
      await tester.pump(const Duration(seconds: 1));
      expect(_shown(tester), 'Hover');

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(DecryptedText)));
      await tester.pump();
      expect(_shown(tester), 'XXXXX');

      // Leaving restores the final text at once.
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_shown(tester), 'Hover');
      await tester.pump(_tick * 5);
      expect(completed, 0);

      // Hovering long enough completes the run.
      await mouse.moveTo(tester.getCenter(find.byType(DecryptedText)));
      await tester.pump();
      await tester.pump(_tick * 3);
      expect(_shown(tester), 'Hover');
      expect(completed, 1);
    });

    testWidgets('controller play and reset', (WidgetTester tester) async {
      final DecryptedTextController controller = DecryptedTextController();
      addTearDown(controller.dispose);
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          DecryptedText(
            text: 'abc',
            characters: 'X',
            autoPlay: false,
            controller: controller,
            onCompleted: () => completed++,
          ),
        ),
      );
      expect(_shown(tester), 'abc');
      expect(controller.isAnimating, isFalse);

      controller.play();
      await tester.pump();
      expect(_shown(tester), 'XXX');
      expect(controller.isAnimating, isTrue);

      controller.reset();
      await tester.pump();
      expect(_shown(tester), 'abc');
      expect(controller.isAnimating, isFalse);
      await tester.pump(_tick * 20);
      expect(completed, 0);

      controller.play();
      await tester.pump(_tick * 10);
      expect(_shown(tester), 'abc');
      expect(completed, 1);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('changing the text mid-run restarts on the new text', (
      WidgetTester tester,
    ) async {
      Widget build(String text) =>
          _wrap(DecryptedText(text: text, characters: 'X', maxIterations: 4));
      await tester.pumpWidget(build('abc'));
      await tester.pump(_tick);
      await tester.pumpWidget(build('hello'));
      expect(_shown(tester), 'XXXXX');
      await tester.pump(_tick * 4);
      expect(_shown(tester), 'hello');
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion shows the final text at once', (
      WidgetTester tester,
    ) async {
      int completed = 0;
      await tester.pumpWidget(
        _wrap(
          DecryptedText(text: 'Plain', onCompleted: () => completed++),
          reducedMotion: true,
        ),
      );
      expect(_shown(tester), 'Plain');
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
          DecryptedText(
            text: 'Plain',
            enabled: false,
            onCompleted: () => completed++,
          ),
        ),
      );
      expect(_shown(tester), 'Plain');
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(completed, 1);
    });

    testWidgets('disabling mid-run resolves immediately', (
      WidgetTester tester,
    ) async {
      Widget build(bool enabled) =>
          _wrap(DecryptedText(text: 'abc', characters: 'X', enabled: enabled));
      await tester.pumpWidget(build(true));
      expect(_shown(tester), 'XXX');
      await tester.pumpWidget(build(false));
      expect(_shown(tester), 'abc');
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('semantics always expose the final text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const DecryptedText(text: 'Secret', characters: 'X')),
      );
      expect(_shown(tester), 'XXXXXX');
      expect(find.bySemanticsLabel('Secret'), findsOneWidget);
      expect(find.bySemanticsLabel('XXXXXX'), findsNothing);
      await tester.pump(_tick * 10);
      handle.dispose();
    });

    testWidgets('disposing mid-run does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const DecryptedText(text: 'abc')));
      await tester.pump(_tick);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_tick * 5);
      expect(tester.takeException(), isNull);
    });
  });
}
