import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/status_mark.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  Widget body = Center(child: child);
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(home: Scaffold(body: body));
}

/// One recorded canvas call of the StatusMark painter.
class _Call {
  _Call(this.method, this.args);
  final Symbol method;
  final List<dynamic> args;
}

/// Records every canvas call the StatusMark painter makes this frame.
List<_Call> _record(WidgetTester tester) {
  final List<_Call> calls = <_Call>[];
  final RenderObject renderObject = tester.renderObject(
    find.descendant(
      of: find.byType(StatusMark),
      matching: find.byType(CustomPaint),
    ),
  );
  expect(
    renderObject,
    paints..everything((Symbol method, List<dynamic> args) {
      calls.add(_Call(method, args));
      return true;
    }),
  );
  return calls;
}

/// Sweep angles of the solid (round cap) arcs, ignoring idle dashes.
List<double> _solidSweeps(WidgetTester tester) {
  return <double>[
    for (final _Call call in _record(tester))
      if (call.method == #drawArc &&
          (call.args[4] as Paint).strokeCap == StrokeCap.round)
        call.args[2] as double,
  ];
}

/// Start angles of the solid arcs.
List<double> _solidStarts(WidgetTester tester) {
  return <double>[
    for (final _Call call in _record(tester))
      if (call.method == #drawArc &&
          (call.args[4] as Paint).strokeCap == StrokeCap.round)
        call.args[1] as double,
  ];
}

int _count(WidgetTester tester, Symbol method) =>
    _record(tester).where((_Call call) => call.method == method).length;

const List<MicroStatus> _all = MicroStatus.values;

void main() {
  group('StatusMark', () {
    testWidgets('renders idle by default as a dashed ring', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const StatusMark()));
      final Finder paint = find.descendant(
        of: find.byType(StatusMark),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(paint), const Size(20, 20));
      // Dashes only: butt-capped arcs, no solid arc, no marks.
      expect(_count(tester, #drawArc), greaterThanOrEqualTo(6));
      expect(_solidSweeps(tester), isEmpty);
      expect(_count(tester, #drawPath), 0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('transitions between every pair of states without throwing', (
      WidgetTester tester,
    ) async {
      for (final MicroStatus a in _all) {
        for (final MicroStatus b in _all) {
          await tester.pumpWidget(_wrap(StatusMark(status: a)));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpWidget(_wrap(StatusMark(status: b)));
          await tester.pump(const Duration(milliseconds: 100));
          _record(tester);
          await tester.pump(const Duration(milliseconds: 300));
          _record(tester);
        }
        // Determinate loading as an extra state, both ways.
        await tester.pumpWidget(_wrap(StatusMark(status: a)));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(
          _wrap(const StatusMark(status: MicroStatus.loading, progress: 0.4)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(_wrap(StatusMark(status: a)));
        await tester.pump(const Duration(milliseconds: 100));
        _record(tester);
      }
      // Retarget mid-transition, repeatedly.
      for (final MicroStatus s in _all) {
        await tester.pumpWidget(_wrap(StatusMark(status: s)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading rotates continuously; other states settle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final double start1 = _solidStarts(tester).single;
      await tester.pump(const Duration(milliseconds: 250));
      final double start2 = _solidStarts(tester).single;
      expect(start2, isNot(closeTo(start1, 0.01)));
      expect(tester.binding.hasScheduledFrame, isTrue);
      // Still spinning much later.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.success)),
      );
      // Settles: pumpAndSettle would time out if the spin kept going.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('loading to success closes the ring before the check draws', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final double spinningSweep = _solidSweeps(tester).single;
      expect(spinningSweep, closeTo(0.28 * 2 * math.pi, 0.01));

      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.success)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Early: the arc has grown, but no checkmark yet.
      final List<double> sweeps = _solidSweeps(tester);
      expect(sweeps.single, greaterThan(spinningSweep));
      expect(_count(tester, #drawPath), 0);

      await tester.pumpAndSettle();
      // Final: a full circle plus the checkmark path.
      expect(_count(tester, #drawCircle), 1);
      expect(_count(tester, #drawPath), greaterThanOrEqualTo(1));
      expect(_solidSweeps(tester), isEmpty);
    });

    testWidgets('error draws a cross and settles', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const StatusMark()));
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.error)),
      );
      await tester.pump(const Duration(milliseconds: 280));
      // Shake in progress: the canvas is translated off center.
      final List<_Call> calls = _record(tester);
      final _Call translate = calls.firstWhere(
        (_Call call) => call.method == #translate,
      );
      expect((translate.args[0] as double).abs(), greaterThan(0.0));
      await tester.pumpAndSettle();
      // Both cross strokes are drawn.
      expect(_count(tester, #drawPath), 2);
      expect(_count(tester, #drawCircle), 1);
    });

    testWidgets('determinate progress animates to the new value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading, progress: 0.2)),
      );
      await tester.pumpAndSettle();
      expect(_solidSweeps(tester).single, closeTo(0.2 * 2 * math.pi, 0.001));
      // Starts at the top.
      expect(_solidStarts(tester).single, closeTo(-math.pi / 2, 0.001));

      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading, progress: 0.8)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final double mid = _solidSweeps(tester).single;
      expect(mid, greaterThan(0.2 * 2 * math.pi));
      expect(mid, lessThan(0.8 * 2 * math.pi));
      await tester.pumpAndSettle();
      expect(_solidSweeps(tester).single, closeTo(0.8 * 2 * math.pi, 0.001));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('semantics labels per status and progress value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const Map<MicroStatus, String> labels = <MicroStatus, String>{
        MicroStatus.idle: 'Idle',
        MicroStatus.loading: 'Loading',
        MicroStatus.success: 'Done',
        MicroStatus.error: 'Failed',
      };
      for (final MapEntry<MicroStatus, String> entry in labels.entries) {
        await tester.pumpWidget(_wrap(StatusMark(status: entry.key)));
        expect(
          tester.getSemantics(find.byType(StatusMark)),
          isSemantics(label: entry.value),
        );
      }
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading, progress: 0.42)),
      );
      expect(
        tester.getSemantics(find.byType(StatusMark)),
        isSemantics(label: 'Loading', value: '42%'),
      );
      await tester.pumpWidget(
        _wrap(
          const StatusMark(
            status: MicroStatus.success,
            semanticLabel: 'Upload complete',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(StatusMark)),
        isSemantics(label: 'Upload complete'),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('reduced motion: no rotation and transitions jump', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusMark(status: MicroStatus.loading),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // A static three-quarter arc stands in for the spinner.
      expect(_solidSweeps(tester).single, closeTo(0.75 * 2 * math.pi, 0.001));

      await tester.pumpWidget(
        _wrap(
          const StatusMark(status: MicroStatus.success),
          reducedMotion: true,
        ),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      // The final frame immediately: full circle and checkmark.
      expect(_count(tester, #drawCircle), 1);
      expect(_count(tester, #drawPath), 1);
    });

    testWidgets('enabled false renders final frames statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading, enabled: false)),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.error, enabled: false)),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_count(tester, #drawPath), 2);

      // Re-enabling while loading starts the spinner again.
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('config changes mid-animation and disposal do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.loading)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          const StatusMark(
            status: MicroStatus.loading,
            size: 32,
            strokeWidth: 3,
            duration: Duration(milliseconds: 600),
            spinDuration: Duration(milliseconds: 500),
            curve: Curves.linear,
            loadingColor: Colors.purple,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(const StatusMark(status: MicroStatus.error, size: 32)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Dispose mid-transition.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('success color adapts to dark theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Center(child: StatusMark(status: MicroStatus.success)),
        ),
      );
      final _Call circle = _record(
        tester,
      ).firstWhere((_Call call) => call.method == #drawCircle);
      expect(
        (circle.args[2] as Paint).color,
        isSameColorAs(const Color(0xFF81C784)),
      );
    });
  });
}
