import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

/// Whether a face is currently visible (its [Opacity] ancestor is 1.0).
bool _faceVisible(WidgetTester tester, String text) {
  final Opacity opacity = tester.widget<Opacity>(
    find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
  );
  return opacity.opacity == 1.0;
}

void main() {
  group('CardFlip', () {
    testWidgets('shows the front face initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(CardFlip(front: Text('Front'), back: Text('Back'))),
      );
      expect(_faceVisible(tester, 'Front'), isTrue);
      expect(_faceVisible(tester, 'Back'), isFalse);
    });

    testWidgets('tap flips to the back and reports through onFlip',
        (WidgetTester tester) async {
      bool? flipped;
      await tester.pumpWidget(
        _wrap(
          CardFlip(
            duration: const Duration(milliseconds: 200),
            onFlip: (bool value) => flipped = value,
            front: const Text('Front'),
            back: const Text('Back'),
          ),
        ),
      );

      await tester.tap(find.byType(CardFlip));
      expect(flipped, isTrue);
      await tester.pumpAndSettle();
      expect(_faceVisible(tester, 'Back'), isTrue);
      expect(_faceVisible(tester, 'Front'), isFalse);

      await tester.tap(find.byType(CardFlip));
      expect(flipped, isFalse);
      await tester.pumpAndSettle();
      expect(_faceVisible(tester, 'Front'), isTrue);
    });

    testWidgets('controller flip, showBack and showFront drive the card',
        (WidgetTester tester) async {
      final CardFlipController controller = CardFlipController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          CardFlip(
            controller: controller,
            duration: const Duration(milliseconds: 200),
            front: const Text('Front'),
            back: const Text('Back'),
          ),
        ),
      );
      expect(controller.isFront, isTrue);

      controller.flip();
      await tester.pumpAndSettle();
      expect(controller.isFront, isFalse);
      expect(_faceVisible(tester, 'Back'), isTrue);

      controller.showFront();
      await tester.pumpAndSettle();
      expect(controller.isFront, isTrue);
      expect(_faceVisible(tester, 'Front'), isTrue);

      controller.showBack();
      await tester.pumpAndSettle();
      expect(controller.isFront, isFalse);

      // showBack again is a no-op.
      controller.showBack();
      await tester.pumpAndSettle();
      expect(controller.isFront, isFalse);
    });

    testWidgets('controlled mode only reports; parent applies the value',
        (WidgetTester tester) async {
      bool isFlipped = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return CardFlip(
                isFlipped: isFlipped,
                duration: const Duration(milliseconds: 200),
                onFlip: (bool value) => setState(() => isFlipped = value),
                front: const Text('Front'),
                back: const Text('Back'),
              );
            },
          ),
        ),
      );
      expect(_faceVisible(tester, 'Front'), isTrue);

      await tester.tap(find.byType(CardFlip));
      await tester.pumpAndSettle();
      expect(isFlipped, isTrue);
      expect(_faceVisible(tester, 'Back'), isTrue);
    });

    testWidgets('enabled false ignores taps', (WidgetTester tester) async {
      bool? flipped;
      await tester.pumpWidget(
        _wrap(
          CardFlip(
            enabled: false,
            onFlip: (bool value) => flipped = value,
            front: const Text('Front'),
            back: const Text('Back'),
          ),
        ),
      );
      await tester.tap(find.byType(CardFlip));
      await tester.pump();
      expect(flipped, isNull);
      expect(_faceVisible(tester, 'Front'), isTrue);
    });

    testWidgets('reduced motion swaps faces instantly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: CardFlip(
                  front: const Text('Front'),
                  back: const Text('Back'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CardFlip));
      await tester.pump();
      expect(_faceVisible(tester, 'Back'), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal mid-flip does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(CardFlip(front: Text('Front'), back: Text('Back'))),
      );
      await tester.tap(find.byType(CardFlip));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
