import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('FloatingLabel', () {
    testWidgets('renders label and a real TextFormField',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(FloatingLabel(label: 'Email')));
      expect(find.text('Email'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows the hint only once the label floats on focus',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(FloatingLabel(label: 'Email', hint: 'name@example.com')),
      );
      expect(find.text('name@example.com'), findsNothing);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(find.text('name@example.com'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('name@example.com'), findsNothing);
    });

    testWidgets('label stays floated while the field has text',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FloatingLabel(
            label: 'Email',
            controller: controller,
          ),
        ),
      );
      final double restingY = tester.getTopLeft(find.text('Email')).dy;

      await tester.enterText(find.byType(TextFormField), 'hello');
      await tester.pumpAndSettle();
      expect(controller.text, 'hello');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      // Non-empty text keeps the label floated above its resting position.
      expect(tester.getTopLeft(find.text('Email')).dy, lessThan(restingY));
    });

    testWidgets('validator participates in Form.validate',
        (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: FloatingLabel(
              label: 'Email',
              validator: (String? value) =>
                  (value == null || !value.contains('@')) ? 'Invalid email' : null,
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Invalid email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Invalid email'), findsNothing);
    });

    testWidgets('onChanged fires as the user types',
        (WidgetTester tester) async {
      String? latest;
      await tester.pumpWidget(
        _wrap(
          FloatingLabel(label: 'Name', onChanged: (String value) => latest = value),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'abc');
      expect(latest, 'abc');
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion floats the label instantly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: FloatingLabel(label: 'Email', hint: 'hint!'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.pump();
      // The label floated instantly, so the hint is already showing.
      expect(find.text('hint!'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('disposal mid-float does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(FloatingLabel(label: 'Email')));
      await tester.tap(find.byType(TextFormField));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
