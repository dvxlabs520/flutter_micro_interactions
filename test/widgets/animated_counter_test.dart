import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/animated_counter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

String _counterText(WidgetTester tester) {
  final Text text = tester.widget<Text>(find.descendant(
    of: find.byType(AnimatedCounter),
    matching: find.byType(Text),
  ));
  return text.data!;
}

void main() {
  group('AnimatedCounter', () {
    testWidgets('renders the formatted initial value',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 42)));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('default formatter keeps the decimal places of value',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 3.25)));
      expect(find.text('3.25'), findsOneWidget);
    });

    testWidgets('count mode animates through intermediate values',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 0,
        duration: Duration(milliseconds: 400),
        curve: Curves.linear,
      )));
      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 100,
        duration: Duration(milliseconds: 400),
        curve: Curves.linear,
      )));

      await tester.pump(const Duration(milliseconds: 200));
      final int midway = int.parse(_counterText(tester));
      expect(midway, greaterThan(0));
      expect(midway, lessThan(100));

      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('rapid changes retarget and settle on the last value',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 0)));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 200)));
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('custom formatter is used', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(AnimatedCounter(
        value: 1250,
        formatter: (num v) => '\$${v.round()}',
      )));
      expect(find.text('\$1250'), findsOneWidget);
    });

    testWidgets('slideDigits renders one text per character and updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 41,
        mode: CounterAnimationMode.slideDigits,
      )));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 42,
        mode: CounterAnimationMode.slideDigits,
      )));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('slideDigits only animates the changed character',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 41,
        mode: CounterAnimationMode.slideDigits,
      )));
      await tester.pumpWidget(_wrap(const AnimatedCounter(
        value: 42,
        mode: CounterAnimationMode.slideDigits,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-swap the changed position shows both the old and new character.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('enabled false jumps instantly', (WidgetTester tester) async {
      await tester.pumpWidget(
          _wrap(const AnimatedCounter(value: 0, enabled: false)));
      await tester.pumpWidget(
          _wrap(const AnimatedCounter(value: 100, enabled: false)));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion jumps instantly', (WidgetTester tester) async {
      Widget build(num value) {
        return MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: AnimatedCounter(value: value))),
          ),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(100));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('semantics exposes the final value during the animation',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 0)));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-animation the rendered text is not the target yet, but the
      // semantics label already is.
      expect(_counterText(tester), isNot('100'));
      expect(
        tester.getSemantics(find.byType(AnimatedCounter)),
        matchesSemantics(label: '100'),
      );
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('semanticLabel overrides the default label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
          const AnimatedCounter(value: 5, semanticLabel: '5 unread messages')));
      expect(
        tester.getSemantics(find.byType(AnimatedCounter)),
        matchesSemantics(label: '5 unread messages'),
      );
      handle.dispose();
    });

    testWidgets('disposal mid-animation does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 0)));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
