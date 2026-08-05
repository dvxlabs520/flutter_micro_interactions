import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

/// The wrapping [Material] that InputFocus animates elevation on.
Material _emphasisMaterial(WidgetTester tester) {
  return tester.widget<Material>(
    find
        .descendant(of: find.byType(InputFocus), matching: find.byType(Material))
        .first,
  );
}

void main() {
  group('InputFocus', () {
    testWidgets('renders its child at rest with zero elevation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(InputFocus(child: TextField())),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(_emphasisMaterial(tester).elevation, 0.0);
    });

    testWidgets('lifts on focus and settles back on unfocus',
        (WidgetTester tester) async {
      bool? focused;
      await tester.pumpWidget(
        _wrap(
          InputFocus(
            elevation: 4.0,
            onFocusChange: (bool value) => focused = value,
            child: const TextField(),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(focused, isTrue);
      expect(_emphasisMaterial(tester).elevation, moreOrLessEquals(4.0));

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(focused, isFalse);
      expect(_emphasisMaterial(tester).elevation, moreOrLessEquals(0.0));
    });

    testWidgets('InputFocus.animate builds the same widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(InputFocus.animate(scale: 1.05, child: const TextField())),
      );
      expect(find.byType(InputFocus), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('enabled false renders the child unchanged',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(InputFocus(enabled: false, child: const TextField())),
      );
      // The disabled wrapper builds the child directly, with no listening
      // Focus/Material shell of its own.
      Widget? built;
      tester
          .element(find.byType(InputFocus))
          .visitChildren((Element child) => built ??= child.widget);
      expect(built, isA<TextField>());
    });

    testWidgets('reduced motion applies the emphasis instantly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: InputFocus(child: const TextField())),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump();
      // The emphasis is at full strength immediately, without animating.
      expect(_emphasisMaterial(tester).elevation, moreOrLessEquals(4.0));
      await tester.pumpAndSettle();
    });

    testWidgets('disposal mid-animation does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(InputFocus(child: TextField())),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
