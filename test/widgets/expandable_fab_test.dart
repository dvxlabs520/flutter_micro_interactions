import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/expandable_fab.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget fab, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: const SizedBox.expand(),
        floatingActionButton: fab,
      ),
    ),
  );
}

List<ExpandableFabAction> _actions({
  VoidCallback? onEdit,
  VoidCallback? onShare,
  VoidCallback? onDelete,
}) {
  return <ExpandableFabAction>[
    ExpandableFabAction(
      icon: const Icon(Icons.edit),
      label: 'Edit',
      onPressed: onEdit,
    ),
    ExpandableFabAction(
      icon: const Icon(Icons.share),
      label: 'Share',
      onPressed: onShare,
    ),
    ExpandableFabAction(
      icon: const Icon(Icons.delete),
      onPressed: onDelete,
    ),
  ];
}

Finder _fab() => find.byType(ExpandableFab);

void main() {
  group('ExpandableFab', () {
    testWidgets('opens on tap and shows all actions',
        (WidgetTester tester) async {
      final List<bool> toggles = <bool>[];
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(), onToggle: toggles.add)),
      );
      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(toggles, <bool>[true]);

      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(toggles, <bool>[true, false]);
    });

    testWidgets('action tap fires its callback and closes the fab',
        (WidgetTester tester) async {
      bool edited = false;
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(onEdit: () => edited = true))),
      );
      await tester.tap(_fab());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      expect(edited, isTrue, reason: 'callback fires immediately on tap');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('closeOnAction false keeps the fab open',
        (WidgetTester tester) async {
      bool shared = false;
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(onShare: () => shared = true),
            closeOnAction: false,
          ),
        ),
      );
      await tester.tap(_fab());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();
      expect(shared, isTrue);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('controller open, close, toggle and isOpen stay in sync',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(), controller: controller)),
      );
      expect(controller.isOpen, isFalse);

      controller.open();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      controller.close();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byIcon(Icons.edit), findsNothing);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // Self-close by tapping the fab keeps the controller truthful.
      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
    });

    testWidgets('tap outside closes the fab', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(ExpandableFab(actions: _actions())));
      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('closeOnTapOutside false keeps the fab open',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(actions: _actions(), closeOnTapOutside: false),
        ),
      );
      await tester.tap(_fab());
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('Escape closes the fab', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(ExpandableFab(actions: _actions())));
      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('rapid toggle spam ends in a consistent state',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(), controller: controller)),
      );

      // Five quick taps mid-animation: odd count must end open.
      for (int i = 0; i < 5; i++) {
        await tester.tap(_fab(), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // One more tap: even count total, must end closed.
      await tester.tap(_fab(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('interleaved controller and tap commands stay consistent',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(), controller: controller)),
      );

      controller.open();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(_fab(), warnIfMissed: false); // close
      await tester.pump(const Duration(milliseconds: 30));
      controller.toggle(); // open
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('enabled false cannot open, by tap or controller',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(),
            controller: controller,
            enabled: false,
          ),
        ),
      );

      await tester.tap(_fab(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);

      controller.open();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('turning enabled off while open closes the fab',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(ExpandableFab(actions: _actions(), controller: controller)),
      );
      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(),
            controller: controller,
            enabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('reduced motion opens and closes instantly',
        (WidgetTester tester) async {
      final ExpandableFabController controller = ExpandableFabController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(actions: _actions(), controller: controller),
          reducedMotion: true,
        ),
      );

      // The controller avoids the tap's ink splash, so a single frame must
      // show the fully expanded state with no running animations.
      controller.open();
      await tester.pump();
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      controller.close();
      await tester.pump();
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      // Tapping still opens instantly (item entrances are skipped).
      await tester.tap(_fab());
      await tester.pump();
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('radial direction shows all actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(),
            direction: ExpandableFabDirection.radial,
          ),
        ),
      );
      await tester.tap(_fab());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);

      // Radial actions remain tappable at their arc positions.
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(onDelete: () => tapped = true),
            direction: ExpandableFabDirection.radial,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      expect(tapped, isTrue);
    });

    testWidgets('disposal while open throws nothing and cleans the overlay',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(ExpandableFab(actions: _actions())));
      await tester.tap(_fab());
      // Dispose mid-open-animation.
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.edit), findsNothing);

      // The global Escape handler is gone too: no exception, no effect.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing timing parameters while open is safe',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(ExpandableFab(actions: _actions())));
      await tester.tap(_fab());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        _wrap(
          ExpandableFab(
            actions: _actions(),
            duration: const Duration(milliseconds: 150),
            staggerDelay: const Duration(milliseconds: 10),
            curve: Curves.easeOut,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
