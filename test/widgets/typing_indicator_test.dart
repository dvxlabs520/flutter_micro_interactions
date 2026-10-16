import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/typing_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Finder get _paint => find.descendant(
  of: find.byType(TypingIndicator),
  matching: find.byType(CustomPaint),
);

void main() {
  group('TypingIndicator', () {
    testWidgets('sizes itself from dot count, size and spacing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TypingIndicator(dotSize: 10, spacing: 5)),
      );
      final Size size = tester.getSize(_paint);
      // 3 dots of 10 with 2 gaps of 5; height adds the bounce travel.
      expect(size.width, 40);
      expect(size.height, 15);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('pulse style needs no vertical travel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TypingIndicator(
            style: TypingIndicatorStyle.pulse,
            dotCount: 4,
            dotSize: 6,
            spacing: 2,
          ),
        ),
      );
      final Size size = tester.getSize(_paint);
      expect(size.width, 30);
      expect(size.height, 6);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('every style animates continuously', (
      WidgetTester tester,
    ) async {
      for (final TypingIndicatorStyle style in TypingIndicatorStyle.values) {
        await tester.pumpWidget(_wrap(TypingIndicator(style: style)));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.binding.hasScheduledFrame, isTrue);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('reduced motion renders static dots', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TypingIndicator(), reduceMotion: true),
      );
      await tester.pump();
      expect(_paint, findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled toggles the loop', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const TypingIndicator(enabled: false)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_wrap(const TypingIndicator()));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(_wrap(const TypingIndicator(enabled: false)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('duration change mid-loop keeps animating', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const TypingIndicator()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          const TypingIndicator(
            duration: Duration(milliseconds: 600),
            style: TypingIndicatorStyle.wave,
            dotCount: 5,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('announces its semantic label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const TypingIndicator(semanticLabel: 'Assistant is typing')),
      );
      expect(find.bySemanticsLabel('Assistant is typing'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(_wrap(const SizedBox()));
    });
  });
}
