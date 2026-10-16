import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/halftone_reveal.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 64 x 32 PNG: black left half, white right half, painted procedurally.
Future<Uint8List> _splitPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas
    ..drawRect(
      const Rect.fromLTWH(0, 0, 32, 32),
      Paint()..color = const Color(0xFF000000),
    )
    ..drawRect(
      const Rect.fromLTWH(32, 0, 32, 32),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(64, 32);
  picture.dispose();
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<MemoryImage> _image(WidgetTester tester) async {
  late Uint8List bytes;
  await tester.runAsync(() async => bytes = await _splitPng());
  return MemoryImage(bytes);
}

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 160 x 80 halftone centered on the 800 x 600 test screen, spanning
/// x 320..480 and y 260..340. With 8 px cells the grid is 20 x 10.
Widget _halftone(
  ImageProvider image, {
  bool enabled = true,
  bool revealed = false,
  bool invert = false,
  bool colored = false,
  double cellSize = 8,
  double revealRadius = 40,
  Color? dotColor,
  HalftoneRevealController? controller,
  String? semanticLabel,
}) {
  return SizedBox(
    width: 160,
    height: 80,
    child: HalftoneReveal(
      image: image,
      enabled: enabled,
      revealed: revealed,
      invert: invert,
      colored: colored,
      cellSize: cellSize,
      revealRadius: revealRadius,
      dotColor: dotColor,
      controller: controller,
      semanticLabel: semanticLabel,
    ),
  );
}

dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(HalftoneReveal),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_HalftonePainter',
      ),
    ),
  );
  return paint.painter;
}

double _hover(WidgetTester tester) =>
    (_painter(tester).hover as Animation<double>).value;

double _full(WidgetTester tester) =>
    (_painter(tester).full as Animation<double>).value;

Offset? _center(WidgetTester tester) =>
    _painter(tester).revealCenter as Offset?;

/// Lets the image decode and the tone sampling finish; both need real
/// asynchronous work outside the fake test clock.
Future<void> _load(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    if (_painter(tester).scene != null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  fail('image did not load');
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

const Offset _inside = Offset(400, 300);

/// Pumps [count] frames of 16 ms, like a running app.
Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('HalftoneReveal', () {
    testWidgets('paints nothing but the background until the image loads', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      expect(_painter(tester).scene, isNull);
      expect(tester.getSize(find.byType(HalftoneReveal)), const Size(160, 80));

      await _load(tester);
      final dynamic scene = _painter(tester).scene;
      expect(scene, isNotNull);
      expect(scene.grid.cols, 20);
      expect(scene.grid.rows, 10);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('darker cells get bigger dots', (WidgetTester tester) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);
      final dynamic scene = _painter(tester).scene;
      final double dark = scene.dotRadius(2, 5) as double;
      final double light = scene.dotRadius(17, 5) as double;
      expect(dark, greaterThan(3.0));
      expect(light, lessThan(0.5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('invert and light dots flip which tones get big dots', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image, invert: true)));
      await _load(tester);
      dynamic scene = _painter(tester).scene;
      expect(
        scene.dotRadius(17, 5) as double,
        greaterThan(scene.dotRadius(2, 5) as double),
      );

      // Light dots on a dark theme: brighter regions get the big dots.
      await tester.pumpWidget(
        _wrap(_halftone(image), brightness: Brightness.dark),
      );
      // Let the theme transition finish.
      await tester.pump(const Duration(milliseconds: 500));
      scene = _painter(tester).scene;
      expect(
        scene.dotRadius(17, 5) as double,
        greaterThan(scene.dotRadius(2, 5) as double),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('exposes the semantic label as an image', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(
        _wrap(_halftone(image, semanticLabel: 'Split test card')),
      );
      expect(
        tester.getSemantics(find.byType(HalftoneReveal)),
        matchesSemantics(label: 'Split test card', isImage: true),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('hover opens the window, follows the pointer and heals', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);
      expect(_center(tester), isNull);

      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_inside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_hover(tester), greaterThan(0.0));
      expect(_center(tester), const Offset(80, 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hover(tester), 1.0);

      // The window glides towards the new position instead of jumping.
      await mouse.moveTo(_inside + const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final double glide = _center(tester)!.dx;
      expect(glide, greaterThan(80));
      expect(glide, lessThan(120));
      await _frames(tester, 40);
      expect(_center(tester)!.dx, closeTo(120, 0.5));

      // Leaving heals over the duration, not instantly.
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final double healing = _hover(tester);
      expect(healing, greaterThan(0.0));
      expect(healing, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hover(tester), 0.0);
      expect(_center(tester), isNull);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a finger reveals while pressed and heals on release', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);

      final TestGesture finger = await tester.startGesture(
        _inside - const Offset(40, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hover(tester), 1.0);
      expect(_center(tester), const Offset(40, 40));

      await finger.moveTo(_inside);
      await tester.pump();
      await _frames(tester, 40);
      expect(_center(tester)!.dx, closeTo(80, 0.5));

      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_hover(tester), 0.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('revealed animates to the full photo and back', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);
      expect(_full(tester), 0.0);

      await tester.pumpWidget(_wrap(_halftone(image, revealed: true)));
      await tester.pump(const Duration(milliseconds: 200));
      final double mid = _full(tester);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_full(tester), 1.0);

      await tester.pumpWidget(_wrap(_halftone(image)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_full(tester), 0.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('controller reveals, hides and toggles', (
      WidgetTester tester,
    ) async {
      final HalftoneRevealController controller = HalftoneRevealController();
      addTearDown(controller.dispose);
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image, controller: controller)));
      await _load(tester);

      controller.reveal();
      expect(controller.isRevealed, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_full(tester), 1.0);

      controller.toggle();
      expect(controller.isRevealed, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_full(tester), 0.0);

      controller.toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_full(tester), 1.0);
      controller.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_full(tester), 0.0);

      // The declarative flag is mirrored into the controller.
      await tester.pumpWidget(
        _wrap(_halftone(image, controller: controller, revealed: true)),
      );
      expect(controller.isRevealed, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion reveals instantly and schedules no frames', (
      WidgetTester tester,
    ) async {
      final HalftoneRevealController controller = HalftoneRevealController();
      addTearDown(controller.dispose);
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(
        _wrap(_halftone(image, controller: controller), reducedMotion: true),
      );
      await _load(tester);

      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_inside);
      await tester.pump();
      expect(_hover(tester), 1.0);
      await mouse.moveTo(_inside + const Offset(30, 0));
      await tester.pump();
      expect(_center(tester), const Offset(110, 40));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_hover(tester), 0.0);

      controller.reveal();
      await tester.pump();
      expect(_full(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('enabled false is a static halftone', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image, enabled: false)));
      await _load(tester);

      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_inside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_hover(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);

      // A declarative reveal still applies, without animation.
      await tester.pumpWidget(
        _wrap(_halftone(image, enabled: false, revealed: true)),
      );
      expect(_full(tester), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disabling while hovered heals immediately', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_inside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(_wrap(_halftone(image, enabled: false)));
      expect(_hover(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('colored mode and config changes mid-animation work', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image, colored: true)));
      await _load(tester);
      expect(_painter(tester).scene.colored, isTrue);

      await tester.pumpWidget(
        _wrap(_halftone(image, colored: true, revealed: true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // A new cell size resamples asynchronously; the old grid stays
      // visible meanwhile.
      await tester.pumpWidget(
        _wrap(
          _halftone(
            image,
            revealed: true,
            cellSize: 10,
            dotColor: Colors.teal,
            revealRadius: 80,
          ),
        ),
      );
      expect(_painter(tester).scene, isNotNull);
      for (int i = 0; i < 100; i++) {
        if (_painter(tester).scene.grid.cell == 10.0) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(_painter(tester).scene.grid.cell, 10.0);
      expect(_painter(tester).scene.grid.cols, 16);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing while the image loads does not throw', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await tester.pumpWidget(const SizedBox());
      // Let the decode finish after the widget is gone.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing at any point of loading or sampling is safe', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      // Dispose after a growing amount of real time, so the widget goes
      // away during decoding, during tone sampling and after both.
      for (final int ms in <int>[0, 1, 2, 4, 8, 16, 32]) {
        await tester.pumpWidget(_wrap(_halftone(image, cellSize: 8 + ms / 10)));
        await tester.runAsync(
          () => Future<void>.delayed(Duration(milliseconds: ms)),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      final MemoryImage image = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(image)));
      await _load(tester);
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(_inside);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.moveTo(_inside + const Offset(50, 10));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(_wrap(_halftone(image, revealed: true)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping the image provider reloads', (
      WidgetTester tester,
    ) async {
      final MemoryImage first = await _image(tester);
      await tester.pumpWidget(_wrap(_halftone(first)));
      await _load(tester);
      final dynamic before = _painter(tester).scene;

      final MemoryImage second = MemoryImage(
        Uint8List.fromList(first.bytes),
        scale: 1.0001,
      );
      await tester.pumpWidget(_wrap(_halftone(second)));
      expect(_painter(tester).scene, isNull);
      await _load(tester);
      expect(identical(_painter(tester).scene, before), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
