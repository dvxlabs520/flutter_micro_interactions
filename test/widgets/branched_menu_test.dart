import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/branched_menu.dart';
import 'package:flutter_test/flutter_test.dart';

const List<BranchedMenuSection> _sections = <BranchedMenuSection>[
  BranchedMenuSection(
    title: 'Getting started',
    items: <BranchedMenuItem>[
      BranchedMenuItem(id: 'intro', label: 'Introduction'),
      BranchedMenuItem(id: 'install', label: 'Installation', badge: 'New'),
    ],
  ),
  BranchedMenuSection(
    title: 'Components',
    initiallyExpanded: false,
    items: <BranchedMenuItem>[
      BranchedMenuItem(
        id: 'button',
        label: 'Button',
        icon: Icon(Icons.smart_button),
      ),
      BranchedMenuItem(id: 'card', label: 'Card'),
    ],
  ),
];

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 260, child: child),
        ),
      ),
    ),
  );
}

class _Harness extends StatefulWidget {
  const _Harness({this.initial, this.onSelected, this.enabled = true});

  final String? initial;
  final ValueChanged<String>? onSelected;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String? _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return BranchedMenu(
      sections: _sections,
      selectedId: _selected,
      enabled: widget.enabled,
      onSelected: (String id) {
        setState(() => _selected = id);
        widget.onSelected?.call(id);
      },
    );
  }
}

/// The branch painter of the menu, read dynamically (it is private).
dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(BranchedMenu),
          matching: find.byType(CustomPaint),
        ),
      )
      .firstWhere((CustomPaint p) => p.painter != null);
  return paint.painter;
}

// ignore: avoid_dynamic_calls
double _traceValue(WidgetTester tester) =>
    (_painter(tester).trace as Animation<double>).value;

void main() {
  group('BranchedMenu', () {
    testWidgets('renders expanded sections and hides collapsed items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Button'), findsNothing);
    });

    testWidgets('header toggles its section with a size animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      final double collapsed = tester.getSize(find.byType(BranchedMenu)).height;
      await tester.tap(find.text('Components'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final double mid = tester.getSize(find.byType(BranchedMenu)).height;
      expect(mid, greaterThan(collapsed));
      expect(mid, lessThan(collapsed + 72));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(BranchedMenu)).height,
        closeTo(collapsed + 72, 0.01),
      );
      expect(find.text('Button'), findsOneWidget);

      await tester.tap(find.text('Components'));
      await tester.pumpAndSettle();
      expect(find.text('Button'), findsNothing);
    });

    testWidgets('selecting fires onSelected and traces the highlight', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(
        _wrap(_Harness(initial: 'intro', onSelected: selected.add)),
      );
      expect(_traceValue(tester), 1.0);
      // ignore: avoid_dynamic_calls
      expect(_painter(tester).to.id, 'intro');

      await tester.tap(find.text('Installation'));
      expect(selected, <String>['install']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double t = _traceValue(tester);
      expect(t, greaterThan(0.0));
      expect(t, lessThan(1.0));
      // ignore: avoid_dynamic_calls
      expect(_painter(tester).from.id, 'intro');
      // ignore: avoid_dynamic_calls
      expect(_painter(tester).to.id, 'install');
      await tester.pumpAndSettle();
      expect(_traceValue(tester), 1.0);
    });

    testWidgets('changing selection mid-trace does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(initial: 'intro')));
      await tester.tap(find.text('Installation'));
      await tester.pump();
      // Past the retract phase: the trace is growing towards 'install'.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Introduction'));
      await tester.pump(const Duration(milliseconds: 100));
      // The retract now starts from the partly drawn path to 'install'.
      // ignore: avoid_dynamic_calls
      expect(_painter(tester).from.id, 'install');
      await tester.tap(find.text('Components'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard: arrows move focus, Enter selects and toggles', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_wrap(_Harness(onSelected: selected.add)));
      // Focus the first header.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, <String>['install']);

      // Down to the collapsed header, Right expands it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Button'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, <String>['install', 'button']);

      // Left goes back to the header, Left again collapses.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Button'), findsNothing);

      // Enter on a header toggles it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Button'), findsOneWidget);
    });

    testWidgets('semantics: headers expanded, items selected', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Harness(initial: 'intro')));
      expect(
        tester.getSemantics(find.text('Getting started')),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Components')),
        isSemantics(isButton: true, isExpanded: false),
      );
      expect(
        tester.getSemantics(find.text('Introduction')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('Installation')),
        isSemantics(isButton: true, isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('reduced motion: instant toggle and trace', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _Harness(initial: 'intro'), reducedMotion: true),
      );
      await tester.tap(find.text('Components'));
      await tester.pump();
      expect(find.text('Button'), findsOneWidget);
      await tester.tap(find.text('Card'));
      await tester.pump();
      expect(_traceValue(tester), 1.0);
      // Let the InkWell splash finish; no trace or size animation runs.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Components'));
      await tester.pump();
      expect(find.text('Card'), findsNothing);
    });

    testWidgets('enabled false: dimmed, ignores taps', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(
        _wrap(_Harness(enabled: false, onSelected: selected.add)),
      );
      await tester.tap(find.text('Introduction'));
      await tester.tap(find.text('Components'));
      await tester.pump();
      expect(selected, isEmpty);
      expect(find.text('Button'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BranchedMenu),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('changing sections and disposing mid-animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(initial: 'intro')));
      await tester.tap(find.text('Components'));
      await tester.tap(find.text('Installation'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(
        _wrap(
          BranchedMenu(sections: _sections.sublist(0, 1), selectedId: 'card'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
