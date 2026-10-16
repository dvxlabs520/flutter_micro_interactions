import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/animated_counter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// The clipped rolling column (a [Stack] inside the counter) holding
/// [glyph], or null when the glyph is static.
Element? _rollingColumn(WidgetTester tester, String glyph) {
  Element? column;
  bool insideCounter = false;
  tester.element(find.text(glyph)).visitAncestorElements((Element element) {
    if (element.widget is AnimatedCounter) {
      insideCounter = true;
      return false;
    }
    if (column == null && element.widget is Stack) {
      column = element;
    }
    return true;
  });
  return insideCounter ? column : null;
}

Widget _slide(num value, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: AnimatedCounter(
            value: value,
            mode: CounterAnimationMode.slideDigits,
            curve: Curves.linear,
            duration: const Duration(milliseconds: 400),
            style: const TextStyle(fontSize: 20, height: 1.5),
          ),
        ),
      ),
    ),
  );
}

String _counterText(WidgetTester tester) {
  final Text text = tester.widget<Text>(
    find.descendant(
      of: find.byType(AnimatedCounter),
      matching: find.byType(Text),
    ),
  );
  return text.data!;
}

void main() {
  group('AnimatedCounter', () {
    testWidgets('renders the formatted initial value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 42)));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('default formatter keeps the decimal places of value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 3.25)));
      expect(find.text('3.25'), findsOneWidget);
    });

    testWidgets('count mode animates through intermediate values', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 0,
            duration: Duration(milliseconds: 400),
            curve: Curves.linear,
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 100,
            duration: Duration(milliseconds: 400),
            curve: Curves.linear,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      final int midway = int.parse(_counterText(tester));
      expect(midway, greaterThan(0));
      expect(midway, lessThan(100));

      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('rapid changes retarget and settle on the last value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 0)));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 200)));
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('custom formatter is used', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedCounter(value: 1250, formatter: (num v) => '\$${v.round()}'),
        ),
      );
      expect(find.text('\$1250'), findsOneWidget);
    });

    testWidgets('slideDigits renders one text per character and updates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 41,
            mode: CounterAnimationMode.slideDigits,
          ),
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 42,
            mode: CounterAnimationMode.slideDigits,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('slideDigits only animates the changed character', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 41,
            mode: CounterAnimationMode.slideDigits,
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 42,
            mode: CounterAnimationMode.slideDigits,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-swap the changed position shows both the old and new character.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('enabled false jumps instantly', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(value: 0, enabled: false)),
      );
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(value: 100, enabled: false)),
      );
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion jumps instantly', (WidgetTester tester) async {
      Widget build(num value) {
        return MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: AnimatedCounter(value: value)),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(100));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('semantics exposes the final value during the animation', (
      WidgetTester tester,
    ) async {
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

    testWidgets('semanticLabel overrides the default label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(value: 5, semanticLabel: '5 unread messages'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AnimatedCounter)),
        matchesSemantics(label: '5 unread messages'),
      );
      handle.dispose();
    });

    testWidgets('disposal mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 0)));
      await tester.pumpWidget(_wrap(const AnimatedCounter(value: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(Container());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
  group('AnimatedCounter formatting options', () {
    testWidgets('fractionDigits, separator, prefix and suffix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 1234567.5,
            fractionDigits: 2,
            thousandsSeparator: ',',
            prefix: r'$',
            suffix: ' USD',
          ),
        ),
      );
      expect(find.text(r'$1,234,567.50 USD'), findsOneWidget);
    });

    testWidgets('fractionDigits applies to int values', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(value: 7, fractionDigits: 1)),
      );
      expect(find.text('7.0'), findsOneWidget);
    });

    testWidgets('grouping handles negatives and short numbers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(value: -1234, thousandsSeparator: '.')),
      );
      expect(find.text('-1.234'), findsOneWidget);
      await tester.pumpWidget(
        _wrap(const AnimatedCounter(value: 999, thousandsSeparator: ',')),
      );
      await tester.pumpAndSettle();
      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('formatter takes precedence over the conveniences', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedCounter(
            value: 1000,
            prefix: r'$',
            thousandsSeparator: ',',
            formatter: (num v) => 'n=${v.round()}',
          ),
        ),
      );
      expect(find.text('n=1000'), findsOneWidget);
    });

    testWidgets('count mode formats intermediate values', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 0,
            prefix: r'$',
            thousandsSeparator: ',',
            curve: Curves.linear,
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 100000,
            prefix: r'$',
            thousandsSeparator: ',',
            curve: Curves.linear,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final String midway = _counterText(tester);
      expect(midway, startsWith(r'$'));
      expect(midway, contains(','));
      await tester.pumpAndSettle();
      expect(find.text(r'$100,000'), findsOneWidget);
    });

    testWidgets('slideDigits keeps prefix, suffix and separators static', (
      WidgetTester tester,
    ) async {
      Widget counter(num value) => _wrap(
        AnimatedCounter(
          value: value,
          mode: CounterAnimationMode.slideDigits,
          prefix: r'$',
          suffix: '%',
          thousandsSeparator: ',',
        ),
      );
      await tester.pumpWidget(counter(1234));
      expect(find.text(r'$'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text(','), findsOneWidget);
      await tester.pumpWidget(counter(1239));
      await tester.pump(const Duration(milliseconds: 100));
      // Only the changed digit animates: old and new are both present.
      expect(find.text('4'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text(r'$'), findsOneWidget);
      // Static pieces never sit inside a rolling (clipped) column.
      for (final String piece in <String>[r'$', '%', ',']) {
        expect(find.text(piece), findsOneWidget);
        expect(_rollingColumn(tester, piece), isNull);
      }
      expect(_rollingColumn(tester, '9'), isNotNull);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsNothing);

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(r'$1,239%'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('slideDigits handles growing and shrinking digit counts', (
      WidgetTester tester,
    ) async {
      Widget counter(num value) => _wrap(
        AnimatedCounter(
          value: value,
          mode: CounterAnimationMode.slideDigits,
          thousandsSeparator: ',',
        ),
      );
      await tester.pumpWidget(counter(999));
      await tester.pumpWidget(counter(1000));
      await tester.pumpAndSettle();
      expect(find.text(','), findsOneWidget);
      await tester.pumpWidget(counter(5));
      await tester.pumpAndSettle();
      expect(find.text(','), findsNothing);
      expect(find.text('5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing format options without a value change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 12345,
            mode: CounterAnimationMode.slideDigits,
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const AnimatedCounter(
            value: 12345,
            mode: CounterAnimationMode.slideDigits,
            thousandsSeparator: ',',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(','), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
  group('AnimatedCounter slideDigits columns', () {
    testWidgets('a new leading digit rolls in and the width grows smoothly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_slide(9));
      final double oneDigit = tester
          .getSize(find.byType(AnimatedCounter))
          .width;
      await tester.pumpWidget(_slide(10));
      await tester.pump(const Duration(milliseconds: 200));
      // The new "1" column rolls instead of popping in.
      expect(_rollingColumn(tester, '1'), isNotNull);
      final double restTop = tester.getTopLeft(find.byType(AnimatedCounter)).dy;
      expect(tester.getTopLeft(find.text('1')).dy, greaterThan(restTop));
      final double midWidth = tester
          .getSize(find.byType(AnimatedCounter))
          .width;
      expect(midWidth, greaterThan(oneDigit));
      expect(midWidth, lessThan(oneDigit * 2));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AnimatedCounter)).width,
        moreOrLessEquals(oneDigit * 2),
      );
      // Place value alignment: the units column went 9 -> 0.
      expect(find.text('9'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a removed digit rolls out and the width settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_slide(9));
      final double oneDigit = tester
          .getSize(find.byType(AnimatedCounter))
          .width;
      await tester.pumpWidget(_slide(100));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_slide(9));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_rollingColumn(tester, '1'), isNotNull);
      final double midWidth = tester
          .getSize(find.byType(AnimatedCounter))
          .width;
      expect(midWidth, greaterThan(oneDigit));
      expect(midWidth, lessThan(oneDigit * 3));
      await tester.pumpAndSettle();
      // No padding is kept once settled.
      expect(find.text('1'), findsNothing);
      expect(find.text(' '), findsNothing);
      expect(
        tester.getSize(find.byType(AnimatedCounter)).width,
        moreOrLessEquals(oneDigit),
      );
    });

    testWidgets('rolling columns are clipped to exactly one line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_slide(41));
      final double lineHeight = tester.getSize(find.text('4')).height;
      expect(
        tester.getSize(find.byType(AnimatedCounter)).height,
        moreOrLessEquals(lineHeight),
      );
      await tester.pumpWidget(_slide(42));
      await tester.pump(const Duration(milliseconds: 200));
      final Element? column = _rollingColumn(tester, '2');
      expect(column, isNotNull);
      expect((column!.widget as Stack).clipBehavior, Clip.hardEdge);
      expect(column.size!.height, moreOrLessEquals(lineHeight));
      // Mid-roll the two glyphs are exactly one line apart, so at most one
      // full glyph is visible through the one-line clip.
      final double outgoing = tester.getTopLeft(find.text('1')).dy;
      final double incoming = tester.getTopLeft(find.text('2')).dy;
      expect(incoming - outgoing, moreOrLessEquals(lineHeight));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(_rollingColumn(tester, '2'), isNull);
    });

    testWidgets('reads left to right in RTL', (WidgetTester tester) async {
      await tester.pumpWidget(_slide(12, direction: TextDirection.rtl));
      expect(
        tester.getTopLeft(find.text('1')).dx,
        lessThan(tester.getTopLeft(find.text('2')).dx),
      );
      await tester.pumpWidget(_slide(123, direction: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('2')).dx,
        lessThan(tester.getTopLeft(find.text('3')).dx),
      );
    });

    testWidgets('rapid retargets settle on the final value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_slide(5));
      await tester.pumpWidget(_slide(50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_slide(500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(_slide(7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('5'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('reduced motion settles instantly with no frames', (
      WidgetTester tester,
    ) async {
      Widget reduced(num value) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _slide(value),
      );
      await tester.pumpWidget(reduced(9));
      await tester.pumpWidget(reduced(10));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('9'), findsNothing);
      expect(_rollingColumn(tester, '1'), isNull);
    });
  });
}
