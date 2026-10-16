import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/lattice_loader.dart';
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

dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_LatticePainter',
    ),
  );
  return paint.painter as dynamic;
}

double _phase(WidgetTester tester) => _painter(tester).phase as double;

void main() {
  group('LatticeLoader', () {
    test('formatElapsed', () {
      expect(LatticeLoader.formatElapsed(Duration.zero), '00:00');
      expect(LatticeLoader.formatElapsed(const Duration(seconds: 7)), '00:07');
      expect(
        LatticeLoader.formatElapsed(const Duration(minutes: 12, seconds: 30)),
        '12:30',
      );
      expect(
        LatticeLoader.formatElapsed(const Duration(seconds: 3723)),
        '1:02:03',
      );
    });

    testWidgets('renders the label, the lattice and a ticking stopwatch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LatticeLoader(label: 'Generating')));
      expect(find.text('Generating'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      // 4 x 3 cells of 4 with gaps of 2.
      final Size size = tester.getSize(
        find.byWidgetPredicate(
          (Widget w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_LatticePainter',
        ),
      );
      expect(size, const Size(22.0, 16.0));

      await tester.pump(const Duration(seconds: 7));
      expect(find.text('00:07'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('01:07'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the diagonal wave travels across the cells', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LatticeLoader(waveSpeed: 1.0)));
      final double p0 = _phase(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double p1 = _phase(tester);
      expect(p1, isNot(equals(p0)));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Cells on the same diagonal share a brightness; the next diagonal
      // lags behind.
      final dynamic painter = _painter(tester);
      final double phase = _phase(tester);
      final double a = painter.intensity(1, 0, phase) as double;
      final double b = painter.intensity(0, 1, phase) as double;
      final double c = painter.intensity(2, 1, phase) as double;
      expect(a, closeTo(b, 1e-9));
      expect(a, isNot(closeTo(c, 1e-6)));
      // And the brightness of a cell changes over time.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        painter.intensity(1, 0, _phase(tester)) as double,
        isNot(closeTo(a, 1e-6)),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: still lattice, stopwatch still counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LatticeLoader(label: 'Working'), reduced: true),
      );
      final double p0 = _phase(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_phase(tester), p0);
      expect(find.text('00:02'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('enabled false: still lattice, stopwatch still counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LatticeLoader(enabled: false)));
      final double p0 = _phase(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(_phase(tester), p0);
      expect(find.text('00:03'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('active false freezes, active true restarts from zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LatticeLoader()));
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('00:04'), findsOneWidget);

      await tester.pumpWidget(_wrap(const LatticeLoader(active: false)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('00:04'), findsOneWidget);
      expect(_painter(tester).dimmed, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_wrap(const LatticeLoader()));
      expect(find.text('00:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('elapsed overrides the measured time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LatticeLoader(elapsed: Duration(seconds: 3723))),
      );
      expect(find.text('1:02:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1:02:03'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('showTimer false hides the stopwatch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LatticeLoader(label: 'Loading', showTimer: false)),
      );
      expect(find.text('00:00'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('semantics: label and elapsed time', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const LatticeLoader(label: 'Generating')));
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel('Generating, 3 seconds'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const LatticeLoader(
            semanticLabel: 'Creating image',
            elapsed: Duration(seconds: 61),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Creating image, 1 minute 1 second'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('config changes mid-animation and disposal do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LatticeLoader(label: 'A')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: LatticeLoader(
              label: 'B',
              columns: 6,
              rows: 2,
              cellSize: 6,
              gap: 3,
              waveSpeed: 2.5,
              color: Colors.orange,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_phase(tester), isNot(equals(0.0)));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes to its content under unbounded width', (
      WidgetTester tester,
    ) async {
      const String text = 'Generating a long answer';
      final Widget widget = const LatticeLoader(label: text);
      final Finder target = find.byType(LatticeLoader);
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
  });
}
