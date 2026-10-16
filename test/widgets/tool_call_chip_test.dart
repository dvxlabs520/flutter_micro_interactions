import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/status_mark.dart';
import 'package:flutter_micro_interactions/src/tool_call_chip.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduced = false}) {
  final Widget app = MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
  if (!reduced) {
    return app;
  }
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: app,
  );
}

/// The live fill model drawn by the chip painter.
dynamic _fill(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_ChipPainter',
    ),
  );
  return (paint.painter as dynamic).fill;
}

double _fillValue(WidgetTester tester) => _fill(tester).fill as double;

/// Horizontal offset of the shake transform, or 0 when not shaking.
double _shakeOffset(WidgetTester tester) {
  double result = 0.0;
  for (final Transform t in tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(ToolCallChip),
      matching: find.byType(Transform),
    ),
  )) {
    final double dx = t.transform.getTranslation().x;
    if (dx.abs() > result.abs()) {
      result = dx;
    }
  }
  return result;
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('ToolCallChip', () {
    test('formatElapsed', () {
      expect(
        ToolCallChip.formatElapsed(const Duration(milliseconds: 2460)),
        '2.4s',
      );
      expect(ToolCallChip.formatElapsed(Duration.zero), '0.0s');
      expect(ToolCallChip.formatElapsed(const Duration(seconds: 12)), '12s');
      expect(ToolCallChip.formatElapsed(const Duration(seconds: 65)), '1m 5s');
    });

    testWidgets('renders label and a live timer while loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Searching the web',
            icon: Icons.public,
            status: MicroStatus.loading,
          ),
        ),
      );
      expect(find.text('Searching the web'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.text('0.0s'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('2.4s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fill creeps forward and the light band moves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(label: 'Thinking', status: MicroStatus.loading),
        ),
      );
      await _frames(tester, 10);
      final double f1 = _fillValue(tester);
      final double s1 = _fill(tester).sheen as double;
      await _frames(tester, 30);
      final double f2 = _fillValue(tester);
      final double s2 = _fill(tester).sheen as double;
      expect(f1, greaterThan(0.0));
      expect(f2, greaterThan(f1));
      expect(f2, lessThan(1.0));
      expect(s2, isNot(equals(s1)));
      expect(_fill(tester).sheenStrength, greaterThan(0.0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('determinate progress drives the fill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Uploading',
            status: MicroStatus.loading,
            progress: 0.4,
          ),
        ),
      );
      await _frames(tester, 60);
      expect(_fillValue(tester), closeTo(0.4, 0.01));
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Uploading',
            status: MicroStatus.loading,
            progress: 0.8,
          ),
        ),
      );
      await _frames(tester, 60);
      expect(_fillValue(tester), closeTo(0.8, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('success completes the fill, freezes the timer and settles', (
      WidgetTester tester,
    ) async {
      Widget build(MicroStatus status) => _wrap(
        ToolCallChip(
          label: 'Searching the web',
          icon: Icons.public,
          status: status,
        ),
      );
      await tester.pumpWidget(build(MicroStatus.loading));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('1.2s'), findsOneWidget);
      final double before = _fillValue(tester);

      await tester.pumpWidget(build(MicroStatus.success));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fillValue(tester), greaterThan(before));
      // The icon is replaced by the status mark with a checkmark.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.public), findsNothing);
      expect(
        tester.widget<StatusMark>(find.byType(StatusMark)).status,
        MicroStatus.success,
      );
      expect(_fillValue(tester), 1.0);

      // The timer is frozen.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('1.2s'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('error shakes, then stops scheduling frames', (
      WidgetTester tester,
    ) async {
      Widget build(MicroStatus status) =>
          _wrap(ToolCallChip(label: 'Running code', status: status));
      await tester.pumpWidget(build(MicroStatus.loading));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(MicroStatus.error));

      double maxShake = 0.0;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        maxShake = _shakeOffset(tester).abs() > maxShake
            ? _shakeOffset(tester).abs()
            : maxShake;
      }
      expect(maxShake, greaterThan(0.5));

      await tester.pump(const Duration(seconds: 1));
      expect(_shakeOffset(tester), 0.0);
      expect(_fillValue(tester), 1.0);
      expect(
        tester.widget<StatusMark>(find.byType(StatusMark)).status,
        MicroStatus.error,
      );
      expect(find.text('0.5s'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('going back to loading starts a new run from zero', (
      WidgetTester tester,
    ) async {
      Widget build(MicroStatus status) =>
          _wrap(ToolCallChip(label: 'Retrying', status: status));
      await tester.pumpWidget(build(MicroStatus.loading));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(build(MicroStatus.error));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(build(MicroStatus.loading));
      expect(find.text('0.0s'), findsOneWidget);
      expect(_fillValue(tester), lessThan(0.05));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0.3s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('idle shows no timer and no fill', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const ToolCallChip(label: 'Pending', status: MicroStatus.idle)),
      );
      expect(find.textContaining('s'), findsNothing);
      expect(_fillValue(tester), 0.0);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('elapsed overrides the measured time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Queried',
            status: MicroStatus.success,
            elapsed: Duration(milliseconds: 12500),
          ),
        ),
      );
      expect(find.text('12s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('12s'), findsOneWidget);
    });

    testWidgets('tapping expands and collapses the detail', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          ToolCallChip(
            label: 'Queried database',
            status: MicroStatus.success,
            detail: const Text('42 rows'),
            onTap: () => taps++,
            onExpansionChanged: changes.add,
          ),
        ),
      );
      expect(find.text('42 rows'), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

      await tester.tap(find.text('Queried database'));
      await tester.pumpAndSettle();
      expect(find.text('42 rows'), findsOneWidget);
      expect(changes, <bool>[true]);
      expect(taps, 1);

      await tester.tap(find.text('Queried database'));
      await tester.pumpAndSettle();
      expect(find.text('42 rows'), findsNothing);
      expect(changes, <bool>[true, false]);
      expect(taps, 2);
    });

    testWidgets('initiallyExpanded shows the detail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Read file',
            status: MicroStatus.success,
            initiallyExpanded: true,
            detail: Text('main.dart'),
          ),
        ),
      );
      expect(find.text('main.dart'), findsOneWidget);
    });

    testWidgets('semantics: label, status, time and expanded state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Searching the web',
            status: MicroStatus.loading,
            detail: Text('query'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2100));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Searching the web, Running, 2 seconds'),
        ),
        matchesSemantics(
          label: 'Searching the web, Running, 2 seconds',
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Searching the web',
            semanticLabel: 'Web search',
            status: MicroStatus.success,
            elapsed: Duration(seconds: 1),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Web search, Done, 1 second'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('reduced motion: no wipe or shake, timer still counts', (
      WidgetTester tester,
    ) async {
      Widget build(MicroStatus status, {double? progress}) => _wrap(
        ToolCallChip(label: 'Working', status: status, progress: progress),
        reduced: true,
      );
      await tester.pumpWidget(build(MicroStatus.loading));
      expect(_fillValue(tester), 0.0);
      expect(_fill(tester).sheenStrength, 0.0);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('1.0s'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(build(MicroStatus.loading, progress: 0.5));
      expect(_fillValue(tester), 0.5);

      await tester.pumpWidget(build(MicroStatus.error));
      await tester.pump();
      expect(_fillValue(tester), 1.0);
      expect(_shakeOffset(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false renders statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Working',
            status: MicroStatus.loading,
            enabled: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_fillValue(tester), 0.0);
      expect(find.text('0.5s'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ToolCallChip(label: 'A', status: MicroStatus.loading)),
      );
      await _frames(tester, 5);
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'B',
            status: MicroStatus.loading,
            progress: 0.3,
            color: Colors.teal,
            duration: Duration(milliseconds: 200),
            wipeDuration: Duration(milliseconds: 900),
            curve: Curves.linear,
            detail: Text('d'),
          ),
        ),
      );
      await _frames(tester, 5);
      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: ToolCallChip(
              label: 'C',
              status: MicroStatus.success,
              elapsed: Duration(seconds: 3),
            ),
          ),
        ),
      );
      await _frames(tester, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-animation leaves no pending work', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ToolCallChip(label: 'A', status: MicroStatus.loading)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(const ToolCallChip(label: 'A', status: MicroStatus.error)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes to its content under unbounded width', (
      WidgetTester tester,
    ) async {
      const String text = 'Searching the web';
      final Widget widget = const ToolCallChip(
        label: text,
        icon: Icons.public,
        status: MicroStatus.loading,
        detail: Text('Query'),
        initiallyExpanded: true,
      );
      final Finder target = find.byType(ToolCallChip);
      final Finder label = find.text(text);

      // Natural size, with plenty of room.
      await tester.pumpWidget(_wrap(widget));
      final double natural = tester.getSize(target).width;

      final Map<String, Widget> hosts = <String, Widget>{
        'Row': Row(children: <Widget>[widget]),
        'horizontal ListView': ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[widget],
        ),
        'UnconstrainedBox': UnconstrainedBox(child: widget),
      };
      for (final MapEntry<String, Widget> host in hosts.entries) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: host.value)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: host.key);
        expect(tester.getSize(target).width, natural, reason: host.key);
        final RenderParagraph paragraph = tester.renderObject(label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: host.key);
      }

      // A bounded width still shrinks the label with an ellipsis.
      await tester.pumpWidget(
        _wrap(SizedBox(width: natural / 2, child: widget)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(target).width, lessThanOrEqualTo(natural / 2));
      final RenderParagraph paragraph = tester.renderObject(label);
      expect(paragraph.didExceedMaxLines, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('expanding a narrow detail keeps the chip size and centering', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ToolCallChip(
            label: 'Searching the web',
            status: MicroStatus.success,
            detail: Text('Q'),
          ),
        ),
      );
      final Finder chip = find.byType(ToolCallChip);
      final Rect collapsed = tester.getRect(chip);
      expect(collapsed.center.dx, closeTo(400.0, 0.01));

      await tester.tap(find.text('Searching the web'));
      await tester.pumpAndSettle();
      expect(find.text('Q').hitTestable(), findsOneWidget);
      final Rect expanded = tester.getRect(chip);
      expect(expanded.width, closeTo(collapsed.width, 0.01));
      expect(expanded.center.dx, closeTo(400.0, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}
