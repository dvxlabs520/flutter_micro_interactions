import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/streaming_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The render object that paints the reveal over the paragraph.
RenderObject _reveal(WidgetTester tester) =>
    tester.renderObject(find.byType(StreamingText));

Finder _richText(String text) => find.text(text, findRichText: true);

void main() {
  group('StreamingText', () {
    testWidgets('lays out the full text at once and fades it in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const StreamingText(text: 'Hello world')));
      // The paragraph holds every word from the first frame.
      expect(_richText('Hello world'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _reveal(tester),
        paints
          ..something((Symbol method, List<dynamic> _) => method == #saveLayer),
      );

      await tester.pumpAndSettle();
      expect(_reveal(tester), paintsExactlyCountTimes(#saveLayer, 0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('only newly appended words animate', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const StreamingText(text: 'Hello')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_wrap(const StreamingText(text: 'Hello there')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_richText('Hello there'), findsOneWidget);
      // One mask rect: only " there" is still appearing.
      expect(_reveal(tester), paintsExactlyCountTimes(#drawRect, 1));
      await tester.pumpAndSettle();
      expect(_reveal(tester), paintsExactlyCountTimes(#drawRect, 0));
    });

    testWidgets('words of one chunk are staggered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StreamingText(
            text: 'one two three',
            wordDelay: Duration(milliseconds: 100),
            duration: Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_reveal(tester), paintsExactlyCountTimes(#drawRect, 3));
      // The first word finishes before the others.
      await tester.pump(const Duration(milliseconds: 280));
      expect(_reveal(tester), paintsExactlyCountTimes(#drawRect, 2));
      await tester.pumpAndSettle();
      expect(_reveal(tester), paintsExactlyCountTimes(#drawRect, 0));
    });

    testWidgets('streaming does not relayout the paragraph every frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'a b c d e f g h')),
      );
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        _richText('a b c d e f g h'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Same render object, still laid out: frames only repaint.
      expect(
        tester.renderObject<RenderParagraph>(_richText('a b c d e f g h')),
        same(paragraph),
      );
      expect(paragraph.debugNeedsLayout, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('a non-extending update restarts the animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const StreamingText(text: 'First answer')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrap(const StreamingText(text: 'Second')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_richText('Second'), findsOneWidget);
      expect(
        _reveal(tester),
        paints
          ..something((Symbol method, List<dynamic> _) => method == #saveLayer),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('blur effect redraws arriving words through a blur layer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StreamingText(text: 'Blurry', effect: StreamingTextEffect.blur),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // The outer reveal layer plus one blurred layer for the word.
      expect(_reveal(tester), paintsExactlyCountTimes(#saveLayer, 2));
      await tester.pumpAndSettle();
      expect(_reveal(tester), paintsExactlyCountTimes(#saveLayer, 0));
    });

    testWidgets('reduced motion shows words instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'Hello'), reduceMotion: true),
      );
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'Hello there'), reduceMotion: true),
      );
      await tester.pump();
      expect(_richText('Hello there'), findsOneWidget);
      expect(_reveal(tester), paintsExactlyCountTimes(#saveLayer, 0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('disabling mid-stream settles everything', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const StreamingText(text: 'a b c d e')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'a b c d e', enabled: false)),
      );
      await tester.pump();
      expect(_reveal(tester), paintsExactlyCountTimes(#saveLayer, 0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('cursor pulses while streaming and hides when done', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'Hi', showCursor: true)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(_reveal(tester), paints..circle());
      // The cursor keeps the ticker alive after the words settle.
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(
        _wrap(
          const StreamingText(text: 'Hi', showCursor: true, isStreaming: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(_reveal(tester), isNot(paints..circle()));
    });

    testWidgets('cursor follows the visible words, not ahead of them', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'Hello', showCursor: true)),
      );
      await tester.pump(const Duration(seconds: 1));
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        _richText('Hello'),
      );
      final double helloEnd = paragraph
          .getOffsetForCaret(const TextPosition(offset: 5), Rect.zero)
          .dx;

      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'Hello wonderful', showCursor: true)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      double? cursorX;
      double? textX;
      expect(
        _reveal(tester),
        paints..everything((Symbol method, List<dynamic> args) {
          if (method == #drawParagraph) textX ??= (args[1] as Offset).dx;
          if (method == #drawCircle) cursorX = (args[0] as Offset).dx;
          return true;
        }),
      );
      // Just after "Hello", well before the end of the new word.
      expect(cursorX! - textX!, lessThan(helloEnd + 30));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('cursor is static and fully visible under reduced motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StreamingText(text: 'Hi', showCursor: true),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(_reveal(tester), paints..circle());
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('screen readers get the full text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const StreamingText(text: 'The answer is 42')),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('The answer is 42'), findsOneWidget);
      handle.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('disposing mid-stream does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StreamingText(text: 'some streaming words', showCursor: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
