import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/glide_select.dart';
import 'package:flutter_test/flutter_test.dart';

const List<GlideSelectOption<String>> _options = <GlideSelectOption<String>>[
  GlideSelectOption<String>(value: 'apple', label: 'Apple'),
  GlideSelectOption<String>(value: 'banana', label: 'Banana'),
  GlideSelectOption<String>(value: 'cherry', label: 'Cherry', enabled: false),
  GlideSelectOption<String>(value: 'date', label: 'Date'),
];

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  Alignment alignment = Alignment.topCenter,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(alignment: alignment, child: child),
        ),
      ),
    ),
  );
}

/// A stateful harness so the controlled [GlideSelect] updates on change.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    this.initial,
    this.onChanged,
    this.enabled = true,
  });

  final String? initial;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return GlideSelect<String>(
      hint: 'Fruit',
      options: _options,
      value: _value,
      enabled: widget.enabled,
      onChanged: (String value) {
        setState(() => _value = value);
        widget.onChanged?.call(value);
      },
    );
  }
}

Finder get _chip => find.byType(GlideSelect<String>);

/// The menu rows live in the overlay; the chip shows only one label.
bool _menuShown(WidgetTester tester) =>
    find.text('Banana').evaluate().isNotEmpty;

/// The highlight pill painter's current top edge.
double _pillTop(WidgetTester tester) {
  final CustomPaint paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere(
        (CustomPaint p) => p.painter.runtimeType.toString() == '_PillPainter',
      );
  // ignore: avoid_dynamic_calls
  return ((paint.painter! as dynamic).top as Animation<double>).value;
}

void main() {
  group('GlideSelect', () {
    testWidgets('shows the hint, then the selected label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      expect(find.text('Fruit'), findsOneWidget);
      await tester.pumpWidget(
        _wrap(const _Harness(key: ValueKey<int>(2), initial: 'date')),
      );
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('tap opens with a pop from the corner and tap outside closes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      expect(_menuShown(tester), isFalse);

      await tester.tap(_chip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      // Mid animation the menu is scaled down towards its corner.
      final Iterable<Transform> transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('Banana'),
          matching: find.byType(Transform),
        ),
      );
      expect(
        transforms.any((Transform t) => t.transform.storage[0] < 1.0),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isTrue);
      expect(find.text('Apple'), findsOneWidget);

      await tester.tapAt(const Offset(780, 580));
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isFalse);
    });

    testWidgets('tapping a row fires onChanged, closes and shows a check', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana'));
      expect(changes, <String>['banana']);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isTrue, reason: 'chip now shows Banana');
      expect(find.text('Apple'), findsNothing);

      await tester.tap(_chip);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('disabled options cannot be picked', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cherry'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(_menuShown(tester), isTrue);
    });

    testWidgets('keyboard: open, arrows skip disabled, Enter selects', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      await tester.pumpWidget(_wrap(_Harness(onChanged: changes.add)));
      final FocusNode node = Focus.of(tester.element(find.text('Fruit')));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isTrue);
      final double first = _pillTop(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final double second = _pillTop(tester);
      expect(second, greaterThan(first));

      // Cherry is disabled: one more step lands on Date.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_pillTop(tester) - second, closeTo(80.0, 0.5));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(changes, <String>['date']);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isFalse);
    });

    testWidgets('highlight pill glides with a spring between rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      final double start = _pillTop(tester);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: tester.getCenter(find.text('Apple')));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Date')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final double mid = _pillTop(tester);
      expect(mid, greaterThan(start));
      expect(mid, lessThan(start + 120.0));
      await tester.pumpAndSettle();
      expect(_pillTop(tester), closeTo(start + 120.0, 0.5));
      await mouse.removePointer();
    });

    testWidgets('type-ahead jumps to a matching label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      Focus.of(tester.element(find.text('Fruit'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final double first = _pillTop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(_pillTop(tester), closeTo(first + 120.0, 0.5));
      // Let the type-ahead buffer timer expire.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Escape closes the menu', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isFalse);
    });

    testWidgets('opens below, and flips above when there is no room', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      final Rect chip = tester.getRect(_chip);
      expect(tester.getRect(find.text('Apple')).top, greaterThan(chip.bottom));
      await tester.tapAt(const Offset(780, 580));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(const _Harness(), alignment: Alignment.bottomCenter),
      );
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      final Rect low = tester.getRect(_chip);
      expect(tester.getRect(find.text('Date')).bottom, lessThan(low.top));
    });

    testWidgets('semantics: chip is an expandable button, rows selectable', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Harness(initial: 'apple')));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Fruit').first),
        isSemantics(
          isButton: true,
          isEnabled: true,
          hasExpandedState: true,
          isExpanded: false,
          label: 'Fruit',
          value: 'Apple',
          hasTapAction: true,
        ),
      );
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Banana'), findsOneWidget);
      final SemanticsNode apple = tester.getSemantics(
        find.bySemanticsLabel('Apple').last,
      );
      expect(apple, isSemantics(isSelected: true));
      handle.dispose();
    });

    testWidgets('enabled false: dimmed and cannot open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(enabled: false)));
      await tester.tap(_chip, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_menuShown(tester), isFalse);
      expect(find.byType(Opacity), findsWidgets);
    });

    testWidgets('reduced motion: opens and closes instantly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness(), reducedMotion: true));
      await tester.tap(_chip);
      await tester.pump();
      expect(_menuShown(tester), isTrue);
      // One more frame settles the focus change caused by the tap.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_menuShown(tester), isFalse);
    });

    testWidgets('disposing while open does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.tap(_chip);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
