import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() {
  return const MaterialApp(home: Scaffold(body: Text('Home')));
}

void main() {
  group('ToastNotification', () {
    testWidgets('show displays the toast and it auto-dismisses',
        (WidgetTester tester) async {
      bool dismissed = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Saved!',
        duration: const Duration(seconds: 1),
        onDismiss: () => dismissed = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Saved!'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('close button removes the toast early',
        (WidgetTester tester) async {
      bool dismissed = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Closable',
        onDismiss: () => dismissed = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Closable'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Closable'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('action button runs onAction and dismisses',
        (WidgetTester tester) async {
      bool acted = false;
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Deleted',
        actionLabel: 'Undo',
        onAction: () => acted = true,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(acted, isTrue);
      expect(find.text('Deleted'), findsNothing);
    });

    testWidgets('dismissOnTap closes the toast when its body is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Tap me away',
        dismissOnTap: true,
        showCloseButton: false,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Tap me away'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Tap me away'), findsNothing);
    });

    testWidgets('announces the message to assistive technology',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      ToastNotification.show(
        context: tester.element(find.text('Home')),
        message: 'Announced',
        duration: const Duration(milliseconds: 100),
      );
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Announced'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });
  });

  group('context.showToast', () {
    testWidgets('extension shows a toast', (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      tester
          .element(find.text('Home'))
          .showToast(message: 'Via extension', type: ToastType.success);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Via extension'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Let it dismiss itself so no timers leak into the next test.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Via extension'), findsNothing);
    });
  });

  group('stacking and reduced motion', () {
    testWidgets('two toasts stack at different offsets',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      final BuildContext context = tester.element(find.text('Home'));
      context.showToast(
          message: 'First', duration: const Duration(milliseconds: 500));
      context.showToast(
          message: 'Second', duration: const Duration(milliseconds: 500));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      final double firstTop = tester.getTopLeft(find.text('First')).dy;
      final double secondTop = tester.getTopLeft(find.text('Second')).dy;
      expect(secondTop, greaterThan(firstTop));

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('reduced motion shows and hides instantly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      tester.element(find.text('Home')).showToast(
            message: 'Instant',
            duration: const Duration(milliseconds: 200),
          );

      await tester.pump();
      expect(find.text('Instant'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('Instant'), findsNothing);
    });
  });
}
