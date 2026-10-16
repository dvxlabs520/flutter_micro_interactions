import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/gradient_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: textDirection,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

const List<Color> _colors = <Color>[
  Color(0xFFFF0000),
  Color(0xFF00FF00),
  Color(0xFF0000FF),
];

/// Renders the gradient text to raw RGBA bytes.
Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find
        .descendant(
          of: find.byType(GradientText),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData();
    image.dispose();
    return bytes;
  });
  return data!.buffer.asUint8List();
}

void main() {
  group('GradientText', () {
    testWidgets('renders the text inside a shader mask', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const GradientText('Gradient')));
      expect(find.text('Gradient'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GradientText),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('linear gradient moves and loops seamlessly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GradientText(
            'MMMMMMMM',
            colors: _colors,
            style: TextStyle(fontSize: 20),
            duration: Duration(milliseconds: 1000),
          ),
        ),
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      final Uint8List start = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final Uint8List quarter = await _pixels(tester);
      expect(quarter, isNot(equals(start)));
      // One full cycle later the frame is identical again.
      await tester.pump(const Duration(milliseconds: 750));
      final Uint8List full = await _pixels(tester);
      expect(full, equals(start));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sweep gradient rotates', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const GradientText(
            'MMMM',
            colors: _colors,
            type: GradientTextType.sweep,
            style: TextStyle(fontSize: 30),
            duration: Duration(milliseconds: 1000),
          ),
        ),
      );
      final Uint8List start = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await _pixels(tester), isNot(equals(start)));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('follows the text direction', (WidgetTester tester) async {
      const GradientText text = GradientText(
        'MMMMMMMM',
        colors: _colors,
        style: TextStyle(fontSize: 20),
        enabled: false,
      );
      await tester.pumpWidget(_wrap(text));
      final Uint8List ltr = await _pixels(tester);
      await tester.pumpWidget(_wrap(text, textDirection: TextDirection.rtl));
      final Uint8List rtl = await _pixels(tester);
      expect(rtl, isNot(equals(ltr)));
    });

    testWidgets('pingPong and config changes mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const GradientText('Hello')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(
        _wrap(
          const GradientText(
            'Hello',
            colors: _colors,
            type: GradientTextType.sweep,
            duration: Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            pingPong: true,
            angle: 0.8,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('child constructor fills any widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GradientText.child(child: Icon(Icons.star))),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('controller starts and stops the animation', (
      WidgetTester tester,
    ) async {
      final GradientTextController controller = GradientTextController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          GradientText(
            'MMMMMMMM',
            colors: _colors,
            autoPlay: false,
            controller: controller,
            duration: const Duration(milliseconds: 1000),
          ),
        ),
      );
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final Uint8List still = await _pixels(tester);

      controller.start();
      await tester.pump();
      expect(controller.isPlaying, isTrue);
      await tester.pump(const Duration(milliseconds: 250));
      expect(await _pixels(tester), isNot(equals(still)));

      controller.stop();
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(await _pixels(tester), equals(still));
    });

    testWidgets('stop is honored while the widget is disabled', (
      WidgetTester tester,
    ) async {
      final GradientTextController controller = GradientTextController();
      addTearDown(controller.dispose);
      Widget build(bool enabled) => _wrap(
        GradientText(
          'Text',
          autoPlay: false,
          enabled: enabled,
          controller: controller,
        ),
      );
      await tester.pumpWidget(build(false));
      controller.start();
      await tester.pump();
      expect(controller.isPlayRequested, isTrue);
      expect(controller.isPlaying, isFalse);
      controller.stop();
      await tester.pump();
      expect(controller.isPlayRequested, isFalse);
      // Enabling again must not animate: the caller stopped it.
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // A later start() works normally.
      controller.start();
      await tester.pump();
      expect(controller.isPlaying, isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('requests survive reduced motion', (WidgetTester tester) async {
      final GradientTextController controller = GradientTextController();
      addTearDown(controller.dispose);
      Widget build(bool reduced) => _wrap(
        GradientText('Text', controller: controller),
        reducedMotion: reduced,
      );
      // autoPlay counts as a request, so stop() works under reduced motion.
      await tester.pumpWidget(build(true));
      expect(controller.isPlayRequested, isTrue);
      expect(controller.isPlaying, isFalse);
      controller.stop();
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // A start() made under reduced motion applies once motion is back.
      await tester.pumpWidget(build(true));
      controller.start();
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      await tester.pumpWidget(build(false));
      expect(controller.isPlaying, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(controller.isPlaying, isFalse);
    });

    testWidgets('reduced motion renders a static gradient', (
      WidgetTester tester,
    ) async {
      final GradientTextController controller = GradientTextController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          GradientText('Static', controller: controller),
          reducedMotion: true,
        ),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(controller.isPlaying, isFalse);
    });

    testWidgets('enabled false renders a static gradient', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GradientText('Static', enabled: false)),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('keeps the text semantics', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const GradientText('Readable')));
      expect(find.bySemanticsLabel('Readable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const GradientText('Bye')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
