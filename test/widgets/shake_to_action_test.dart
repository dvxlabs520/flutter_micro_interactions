import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('ShakeToAction', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ShakeToAction(onShake: () {}, child: const Text('Shake me'))),
      );
      expect(find.text('Shake me'), findsOneWidget);
    });

    testWidgets('controller.shake fires onShake and plays the animation',
        (WidgetTester tester) async {
      final ShakeController controller = ShakeController();
      addTearDown(controller.dispose);
      int shakes = 0;
      await tester.pumpWidget(
        _wrap(
          ShakeToAction(
            controller: controller,
            onShake: () => shakes++,
            child: const Text('Shake me'),
          ),
        ),
      );

      controller.shake();
      expect(shakes, 1);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('cooldown swallows rapid consecutive triggers',
        (WidgetTester tester) async {
      final ShakeController controller = ShakeController();
      addTearDown(controller.dispose);
      int shakes = 0;
      await tester.pumpWidget(
        _wrap(
          ShakeToAction(
            controller: controller,
            cooldown: const Duration(seconds: 30),
            onShake: () => shakes++,
            child: const Text('Shake me'),
          ),
        ),
      );

      controller.shake();
      controller.shake();
      expect(shakes, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('enabled false ignores controller triggers',
        (WidgetTester tester) async {
      final ShakeController controller = ShakeController();
      addTearDown(controller.dispose);
      int shakes = 0;
      await tester.pumpWidget(
        _wrap(
          ShakeToAction(
            controller: controller,
            enabled: false,
            onShake: () => shakes++,
            child: const Text('Shake me'),
          ),
        ),
      );
      controller.shake();
      expect(shakes, 0);
    });

    testWidgets('reduced motion fires the callback without animating',
        (WidgetTester tester) async {
      final ShakeController controller = ShakeController();
      addTearDown(controller.dispose);
      int shakes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ShakeToAction(
                controller: controller,
                onShake: () => shakes++,
                child: const Text('Shake me'),
              ),
            ),
          ),
        ),
      );
      controller.shake();
      await tester.pump();
      expect(shakes, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('ShakeAnimation', () {
    testWidgets('plays when the controller fires and disposes safely mid-run',
        (WidgetTester tester) async {
      final ShakeController controller = ShakeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ShakeAnimation(controller: controller, child: const Text('Field')),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);

      controller.shake();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 100));

      // Dispose while the shake is still running.
      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Firing after disposal is a safe no-op.
      controller.shake();
      expect(tester.takeException(), isNull);
    });
  });

  group('ShakeButton', () {
    testWidgets('valid press runs onPressed without shaking',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(
          ShakeButton(
            onPressed: () => pressed = true,
            builder: (BuildContext context, VoidCallback handlePressed) =>
                ElevatedButton(
              onPressed: handlePressed,
              child: const Text('Submit'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(pressed, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('invalid press shakes and runs onInvalidPress',
        (WidgetTester tester) async {
      bool pressed = false;
      bool invalid = false;
      await tester.pumpWidget(
        _wrap(
          ShakeButton(
            isValid: false,
            onPressed: () => pressed = true,
            onInvalidPress: () => invalid = true,
            builder: (BuildContext context, VoidCallback handlePressed) =>
                ElevatedButton(
              onPressed: handlePressed,
              child: const Text('Submit'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(pressed, isFalse);
      expect(invalid, isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });
  });
}
