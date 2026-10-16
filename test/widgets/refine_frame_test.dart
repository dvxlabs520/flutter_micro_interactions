import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/refine_frame.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduced = false}) {
  final Widget app = MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 200.0, child: child)),
    ),
  );
  if (!reduced) {
    return app;
  }
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: app,
  );
}

const List<Widget> _stages = <Widget>[
  ColoredBox(key: ValueKey<String>('s0'), color: Color(0xFF333333)),
  ColoredBox(key: ValueKey<String>('s1'), color: Color(0xFF777777)),
  ColoredBox(key: ValueKey<String>('s2'), color: Color(0xFFBBBBBB)),
];

Finder _stage(int i) => find.byKey(ValueKey<String>('s$i'));

/// The curved progress of the current reveal, or null when none runs.
double? _revealProgress(WidgetTester tester) {
  final Finder finder = find.byWidgetPredicate(
    (Widget w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_RevealGlowPainter',
  );
  if (finder.evaluate().isEmpty) {
    return null;
  }
  final CustomPaint paint = tester.widget<CustomPaint>(finder);
  return ((paint.painter as dynamic).progress as Animation<double>).value;
}

Finder get _mask => find.descendant(
  of: find.byType(RefineFrame),
  matching: find.byType(ShaderMask),
);

/// Draws a small landscape and encodes it as PNG bytes.
Future<Uint8List> _makePng(WidgetTester tester) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Size size = Size(64.0, 64.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0.0, 64.0),
          const <Color>[Color(0xFF1B2A6B), Color(0xFFF4A261)],
        ),
    );
    canvas.drawCircle(
      const Offset(40.0, 30.0),
      9.0,
      Paint()..color = const Color(0xFFFFE8A3),
    );
    final ui.Image image = await recorder.endRecording().toImage(64, 64);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

void main() {
  group('RefineFrame', () {
    testWidgets('renders the current stage at a fixed aspect ratio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0, aspectRatio: 2.0)),
      );
      expect(_stage(0), findsOneWidget);
      expect(_stage(1), findsNothing);
      expect(
        tester.getSize(find.byType(RefineFrame)),
        const Size(200.0, 100.0),
      );
      expect(find.text('Refining 1/3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stepping reveals the next stage through a growing mask', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0)),
      );
      final Size size = tester.getSize(find.byType(RefineFrame));
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 1)),
      );
      expect(_stage(0), findsOneWidget);
      expect(_stage(1), findsOneWidget);
      expect(_mask, findsOneWidget);
      expect(_revealProgress(tester), 0.0);

      await tester.pump(const Duration(milliseconds: 350));
      final double mid = _revealProgress(tester)!;
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      // No layout shift during the reveal.
      expect(tester.getSize(find.byType(RefineFrame)), size);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_stage(0), findsNothing);
      expect(_stage(1), findsOneWidget);
      expect(_mask, findsNothing);
      expect(_revealProgress(tester), isNull);
      expect(tester.getSize(find.byType(RefineFrame)), size);
      expect(find.text('Refining 2/3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a change during a reveal is revealed right after', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0)),
      );
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 1)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 2)),
      );
      // Stage 1 keeps developing first; stage 2 waits.
      expect(_stage(1), findsOneWidget);
      expect(_stage(2), findsNothing);
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump();
      expect(_stage(1), findsOneWidget);
      expect(_stage(2), findsOneWidget);
      expect(_revealProgress(tester), lessThan(0.5));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(_stage(1), findsNothing);
      expect(_stage(2), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stage widgets keep their state when they settle', (
      WidgetTester tester,
    ) async {
      final List<Widget> stages = <Widget>[
        const ColoredBox(color: Color(0xFF000000)),
        const _Counter(key: ValueKey<String>('counter')),
      ];
      await tester.pumpWidget(_wrap(RefineFrame(stages: stages, stage: 0)));
      await tester.pumpWidget(_wrap(RefineFrame(stages: stages, stage: 1)));
      final State before = tester.state(find.byType(_Counter));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.state(find.byType(_Counter)), same(before));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('progress pill text, label builder and visibility', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RefineFrame(
            stages: _stages,
            stage: 1,
            labelBuilder: (int step, int total) => 'Step $step of $total',
          ),
        ),
      );
      expect(find.text('Step 2 of 3'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const RefineFrame(stages: _stages, stage: 1, showProgress: false),
        ),
      );
      expect(find.text('Refining 2/3'), findsNothing);

      // The final stage fades the overlay and pill out.
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 2)),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Refining 3/3'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0.0);
      // Grain and reveal are done: nothing left to animate.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('isGenerating false hides the overlay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RefineFrame(stages: _stages, stage: 1, isGenerating: false),
        ),
      );
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Refining 2/3'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0.0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('semantics: image label with the refining step', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 1)),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Image, refining step 2 of 3'),
        ),
        matchesSemantics(label: 'Image, refining step 2 of 3', isImage: true),
      );
      await tester.pumpWidget(
        _wrap(
          const RefineFrame(
            stages: _stages,
            stage: 2,
            semanticLabel: 'A mountain at sunset',
          ),
        ),
      );
      expect(find.bySemanticsLabel('A mountain at sunset'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('reduced motion: instant stage switch, no grain', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0), reduced: true),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_GrainPainter',
        ),
        findsNothing,
      );
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 1), reduced: true),
      );
      expect(_stage(0), findsNothing);
      expect(_stage(1), findsOneWidget);
      expect(_mask, findsNothing);
      expect(find.text('Refining 2/3'), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false: instant stage switch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0, enabled: false)),
      );
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 2, enabled: false)),
      );
      expect(_stage(2), findsOneWidget);
      expect(_mask, findsNothing);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('every reveal style runs without errors', (
      WidgetTester tester,
    ) async {
      for (final RefineRevealStyle style in RefineRevealStyle.values) {
        await tester.pumpWidget(
          _wrap(
            Directionality(
              textDirection: TextDirection.rtl,
              child: RefineFrame(
                stages: _stages,
                stage: 0,
                revealStyle: style,
                revealOrigin: Alignment.topLeft,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          _wrap(
            Directionality(
              textDirection: TextDirection.rtl,
              child: RefineFrame(
                stages: _stages,
                stage: 1,
                revealStyle: style,
                revealOrigin: Alignment.topLeft,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(_revealProgress(tester), greaterThan(0.0));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('blurred builds stages from one generated image', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = MemoryImage(await _makePng(tester));
      await tester.pumpWidget(
        _wrap(RefineFrame.blurred(image: image, stage: 0)),
      );
      final RefineFrame frame = tester.widget<RefineFrame>(
        find.byType(RefineFrame),
      );
      expect(frame.stages, hasLength(4));
      expect(find.text('Refining 1/4'), findsOneWidget);
      // The first stage is blurred.
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Step to the final, sharp stage.
      await tester.pumpWidget(
        _wrap(RefineFrame.blurred(image: image, stage: 3)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('config changes and disposal mid-reveal do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0)),
      );
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 2)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          const RefineFrame(
            stages: _stages,
            stage: 1,
            duration: Duration(milliseconds: 300),
            curve: Curves.linear,
            revealStyle: RefineRevealStyle.diagonal,
            aspectRatio: 4 / 3,
            borderRadius: BorderRadius.zero,
            showGrain: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Fewer stages than the one being revealed.
      await tester.pumpWidget(
        _wrap(
          const RefineFrame(stages: <Widget>[SizedBox(), SizedBox()], stage: 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('unbounded constraints fall back to a default width', (
      WidgetTester tester,
    ) async {
      Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

      await tester.pumpWidget(
        app(
          const UnconstrainedBox(
            child: RefineFrame(stages: _stages, stage: 0, aspectRatio: 2.0),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(RefineFrame)),
        const Size(RefineFrame.fallbackWidth, RefineFrame.fallbackWidth / 2),
      );

      await tester.pumpWidget(
        app(
          const UnconstrainedBox(
            child: Row(
              children: <Widget>[
                RefineFrame(stages: _stages, stage: 0),
                SizedBox(width: 10.0),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(RefineFrame)),
        const Size(RefineFrame.fallbackWidth, RefineFrame.fallbackWidth),
      );

      // Height bounded, width unbounded: the height drives the size.
      await tester.pumpWidget(
        app(
          SizedBox(
            height: 150.0,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const <Widget>[
                RefineFrame(stages: _stages, stage: 0, aspectRatio: 4 / 3),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(RefineFrame)),
        const Size(200.0, 150.0),
      );

      // Bounded layouts are unchanged.
      await tester.pumpWidget(
        _wrap(const RefineFrame(stages: _stages, stage: 0)),
      );
      expect(
        tester.getSize(find.byType(RefineFrame)),
        const Size(200.0, 200.0),
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
