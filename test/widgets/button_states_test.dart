import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('ButtonStateController', () {
    test('starts idle and transitions between states', () {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);
      expect(controller.state, MicroButtonState.idle);

      controller.setLoading();
      expect(controller.state, MicroButtonState.loading);
      controller.setSuccess();
      expect(controller.state, MicroButtonState.success);
      controller.setError();
      expect(controller.state, MicroButtonState.error);
      controller.setIdle();
      expect(controller.state, MicroButtonState.idle);
    });

    test('accepts a custom initial state', () {
      final ButtonStateController controller =
          ButtonStateController(MicroButtonState.loading);
      addTearDown(controller.dispose);
      expect(controller.state, MicroButtonState.loading);
    });
  });

  group('ButtonStates', () {
    testWidgets('shows child while idle and swaps custom builders per state',
        (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ButtonStates(
            controller: controller,
            loadingBuilder: (_) => const Text('LOADING'),
            successBuilder: (_) => const Text('SUCCESS'),
            errorBuilder: (_) => const Text('ERROR'),
            child: const Text('IDLE'),
          ),
        ),
      );
      expect(find.text('IDLE'), findsOneWidget);

      controller.setLoading();
      await tester.pumpAndSettle();
      expect(find.text('LOADING'), findsOneWidget);
      expect(find.text('IDLE'), findsNothing);

      controller.setSuccess();
      await tester.pumpAndSettle();
      expect(find.text('SUCCESS'), findsOneWidget);

      controller.setError();
      await tester.pumpAndSettle();
      expect(find.text('ERROR'), findsOneWidget);

      controller.setIdle();
      await tester.pumpAndSettle();
      expect(find.text('IDLE'), findsOneWidget);
    });

    testWidgets('default builders show spinner and icons',
        (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(ButtonStates(controller: controller, child: const Text('Save'))),
      );

      controller.setLoading();
      // The spinner repeats forever, so pump explicit durations instead of
      // pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.setSuccess();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      controller.setError();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('announces state changes to assistive technology',
        (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ButtonStates(
            controller: controller,
            successBuilder: (_) => const Text('OK'),
            child: const Text('Save'),
          ),
        ),
      );

      controller.setSuccess();
      await tester.pumpAndSettle();
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Success'),
      );
    });

    testWidgets('auto-resets success back to idle', (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);
      final List<MicroButtonState> seen = <MicroButtonState>[];

      await tester.pumpWidget(
        _wrap(
          ButtonStates(
            controller: controller,
            autoResetDuration: const Duration(milliseconds: 100),
            onStateChanged: seen.add,
            successBuilder: (_) => const Text('OK'),
            child: const Text('Save'),
          ),
        ),
      );

      controller.setSuccess();
      // Do not pumpAndSettle here: it would advance past the auto-reset
      // timer. The success content is visible while the switch runs.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('OK'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(seen, <MicroButtonState>[
        MicroButtonState.success,
        MicroButtonState.idle,
      ]);
    });

    testWidgets('reduced motion swaps content instantly',
        (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ButtonStates(
                controller: controller,
                successBuilder: (_) => const Text('OK'),
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      );

      controller.setSuccess();
      await tester.pump();
      await tester.pump();
      expect(find.text('OK'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal while switching does not throw',
        (WidgetTester tester) async {
      final ButtonStateController controller = ButtonStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          ButtonStates(
            controller: controller,
            successBuilder: (_) => const Text('OK'),
            child: const Text('Save'),
          ),
        ),
      );

      controller.setSuccess();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);

      // Controller changes after disposal are ignored safely.
      controller.setIdle();
      expect(tester.takeException(), isNull);
    });
  });
}
