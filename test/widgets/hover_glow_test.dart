import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// The [DecoratedBox] that HoverGlow paints its shadow with.
BoxDecoration _glowDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(HoverGlow),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('HoverGlow', () {
    testWidgets('renders its child without a glow at rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HoverGlow(
            child: SizedBox(width: 100, height: 50, child: Text('Hover')),
          ),
        ),
      );
      expect(find.text('Hover'), findsOneWidget);
      expect(_glowDecoration(tester).boxShadow, isNull);
    });

    testWidgets('fades the glow in on hover and out on exit', (
      WidgetTester tester,
    ) async {
      // Hover highlights require traditional focus highlight mode.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      bool? hovered;
      await tester.pumpWidget(
        _wrap(
          HoverGlow(
            glowColor: Colors.blue,
            onHoverChanged: (bool value) => hovered = value,
            child: const SizedBox(width: 100, height: 50, child: Text('Hover')),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pumpAndSettle();
      expect(hovered, isTrue);
      expect(_glowDecoration(tester).boxShadow, isNotNull);
      expect(_glowDecoration(tester).boxShadow, isNotEmpty);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(hovered, isFalse);
      expect(_glowDecoration(tester).boxShadow, isNull);
    });

    testWidgets('adds no Tab focus stop of its own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HoverGlow(
                child: TextButton(onPressed: () {}, child: const Text('First')),
              ),
              TextButton(onPressed: () {}, child: const Text('Second')),
            ],
          ),
        ),
      );

      final FocusNode first = Focus.of(tester.element(find.text('First')));
      final FocusNode second = Focus.of(tester.element(find.text('Second')));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(second.hasPrimaryFocus, isTrue);
    });

    testWidgets('a non-focusable child gets no focus stop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const HoverGlow(child: SizedBox(width: 100, height: 50))),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Whatever holds focus now, it is not inside the HoverGlow.
      final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
      bool insideGlow = false;
      focused?.visitAncestorElements((Element ancestor) {
        if (ancestor.widget is HoverGlow) {
          insideGlow = true;
          return false;
        }
        return true;
      });
      expect(insideGlow, isFalse);
    });

    testWidgets('glows while a focusable descendant has keyboard focus', (
      WidgetTester tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        _wrap(
          HoverGlow(
            glowColor: Colors.blue,
            child: TextButton(onPressed: () {}, child: const Text('Inner')),
          ),
        ),
      );
      expect(_glowDecoration(tester).boxShadow, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Inner'))).hasPrimaryFocus,
        isTrue,
      );
      expect(_glowDecoration(tester).boxShadow, isNotNull);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_glowDecoration(tester).boxShadow, isNull);
    });

    testWidgets('enabled false renders the child unchanged', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(HoverGlow(enabled: false, child: Text('Plain'))),
      );
      expect(find.text('Plain'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HoverGlow),
          matching: find.byType(FocusableActionDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('reduced motion switches the glow instantly', (
      WidgetTester tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: HoverGlow(
                  glowColor: Colors.red,
                  child: const SizedBox(
                    width: 100,
                    height: 50,
                    child: Text('Hover'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pump();
      await tester.pump();
      expect(_glowDecoration(tester).boxShadow, isNotNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposal mid-fade does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HoverGlow(
            child: SizedBox(width: 100, height: 50, child: Text('Hover')),
          ),
        ),
      );

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Hover')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
