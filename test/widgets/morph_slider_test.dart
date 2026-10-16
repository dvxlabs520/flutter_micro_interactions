import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/morph_slider.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Color> _palette = <Color>[
  Color(0xFFE2557B),
  Color(0xFF1FA2A6),
  Color(0xFFFFB86B),
  Color(0xFF3A1F4F),
];

/// Encodes small procedurally drawn PNGs so the slider decodes real images.
Future<List<MemoryImage>> _makeImages(WidgetTester tester, int count) async {
  final List<MemoryImage>? images = await tester.runAsync(() async {
    final List<MemoryImage> out = <MemoryImage>[];
    for (int i = 0; i < count; i++) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 64, 40),
        Paint()..color = _palette[i % _palette.length],
      );
      canvas.drawCircle(
        Offset(16.0 + i * 8, 20),
        10,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final ui.Image image = await recorder.endRecording().toImage(64, 40);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      out.add(MemoryImage(data!.buffer.asUint8List()));
    }
    return out;
  });
  return images!;
}

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 250, child: child)),
      ),
    ),
  );
}

final Finder _painterFinder = find.byWidgetPredicate(
  (Widget w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_MorphPainter',
);

dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painterFinder).painter;

double _progress(WidgetTester tester) =>
    ((_painter(tester).progress) as Animation<double>).value;

/// Label of the semantics node that describes the shown image.
String? _imageLabel(WidgetTester tester) {
  final Semantics node = tester.widget<Semantics>(
    find.byWidgetPredicate(
      (Widget w) => w is Semantics && (w.properties.image ?? false),
    ),
  );
  return node.properties.label;
}

bool _transitioning(WidgetTester tester) =>
    _painter(tester).transitioning as bool;

/// Lets image decoding (real async work) finish, then pumps.
Future<void> _settleImages(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (_painter(tester).from != null) return;
  }
}

/// Moves a pointer slowly so the release carries no fling velocity.
Future<TestGesture> _slowDrag(
  WidgetTester tester,
  double dx, {
  int steps = 8,
}) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.byType(MorphSlider)),
  );
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 60));
  }
  // Hold still so the velocity tracker reports no fling.
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

void main() {
  tearDown(() => MorphSlider.debugForceFallback = false);

  group('MorphSlider', () {
    testWidgets('renders and loads the current image', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      await tester.pumpWidget(_wrap(MorphSlider(images: images)));
      await _settleImages(tester);

      expect(_painter(tester).from, isA<ui.Image>());
      expect(_transitioning(tester), isFalse);
      expect(_imageLabel(tester), 'Image 1 of 3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('next animates progress from 0 to 1 and changes the index', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.linear,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await _settleImages(tester);

      controller.next();
      await tester.pump();
      expect(controller.index, 1);
      expect(changes, <int>[1]);
      expect(controller.isAnimating, isTrue);
      expect(_transitioning(tester), isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      final double p1 = _progress(tester);
      await tester.pump(const Duration(milliseconds: 250));
      final double p2 = _progress(tester);
      expect(p1, closeTo(0.25, 0.02));
      expect(p2, closeTo(0.5, 0.02));

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(_transitioning(tester), isFalse);
      expect(controller.isAnimating, isFalse);
      expect(_imageLabel(tester), 'Image 2 of 3');

      controller.previous();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(changes, <int>[1, 0]);
    });

    testWidgets('loop wraps around and loop false stops at the ends', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      controller.previous();
      await tester.pumpAndSettle();
      expect(controller.index, 2);
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.index, 0);

      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller, loop: false)),
      );
      controller.previous();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      controller.jumpTo(2);
      await tester.pump();
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('arrow buttons and keyboard navigate', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(controller.index, 0);

      final Focus focus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(MorphSlider),
              matching: find.byType(Focus),
            )
            .first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.index, 0);
    });

    testWidgets('tapToNavigate uses the tapped half', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            tapToNavigate: true,
            showArrows: false,
          ),
        ),
      );
      final Rect box = tester.getRect(find.byType(MorphSlider));
      await tester.tapAt(box.centerRight - const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.tapAt(box.centerLeft + const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(controller.index, 0);
    });

    testWidgets('dragging scrubs the progress and a short drag cancels', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await _settleImages(tester);

      final TestGesture gesture = await _slowDrag(tester, -100);
      final double scrubbed = _progress(tester);
      // 100 px of a 400 px wide slider, normalized by 85 % of the width.
      expect(scrubbed, closeTo(100 / 340, 0.05));
      expect(_transitioning(tester), isTrue);
      expect(controller.isAnimating, isTrue);
      expect(controller.index, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(changes, isEmpty);
      expect(_transitioning(tester), isFalse);
    });

    testWidgets('dragging past halfway completes the transition', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await _settleImages(tester);

      final TestGesture gesture = await _slowDrag(tester, -240);
      expect(_progress(tester), greaterThan(0.5));
      await gesture.up();
      await tester.pump();
      expect(changes, <int>[1]);
      final double released = _progress(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_progress(tester), greaterThan(released));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(_transitioning(tester), isFalse);

      // Dragging right goes back.
      final TestGesture back = await _slowDrag(tester, 260);
      await back.up();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(changes, <int>[1, 0]);
    });

    testWidgets('grabbing a running transition scrubs it without a jump', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            curve: Curves.linear,
            duration: const Duration(milliseconds: 1000),
            onIndexChanged: changes.add,
          ),
        ),
      );
      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final double before = _progress(tester);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(MorphSlider)),
      );
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_transitioning(tester), isTrue);
      // Progress continues from where it was, plus the 24 px just dragged.
      expect(_progress(tester), closeTo(before + 24 / 340, 0.03));

      // Dragging back past the start and releasing returns to image 0.
      for (int i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(changes, <int>[1, 0]);
    });

    testWidgets('a quick fling completes even a short drag', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      await tester.fling(find.byType(MorphSlider), const Offset(-80, 0), 1500);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    });

    testWidgets('controller animateTo, jumpTo and listeners', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 4);
      final MorphSliderController controller = MorphSliderController(
        initialIndex: 1,
      );
      addTearDown(controller.dispose);
      int notifications = 0;
      controller.addListener(() => notifications++);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      expect(_imageLabel(tester), 'Image 2 of 4');

      controller.animateTo(3);
      await tester.pump();
      expect(controller.index, 3);
      expect(controller.isAnimating, isTrue);
      expect(_painter(tester).direction, 1);
      await tester.pumpAndSettle();

      controller.animateTo(0);
      await tester.pump();
      expect(_painter(tester).direction, -1);
      await tester.pumpAndSettle();
      expect(controller.index, 0);

      controller.jumpTo(2);
      await tester.pump();
      expect(controller.index, 2);
      expect(controller.isAnimating, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      expect(notifications, 3);
    });

    testWidgets('next during a transition retargets from the new image', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 4);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      controller.next();
      await tester.pump(const Duration(milliseconds: 300));
      controller.next();
      await tester.pump();
      expect(controller.index, 2);
      expect(_progress(tester), lessThan(0.05));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('autoplay advances and pauses while dragging or hovering', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            autoPlay: true,
            interval: const Duration(seconds: 2),
            duration: const Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2100));
      expect(controller.index, 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.isAnimating, isFalse);

      // Holding a drag pauses autoplay.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(MorphSlider)),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(seconds: 5));
      expect(controller.index, 1);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.index, 1);

      // Autoplay resumes after the drag.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(controller.index, 2);
      await tester.pump(const Duration(milliseconds: 600));

      // Hovering pauses autoplay.
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(MorphSlider)));
      await tester.pump(const Duration(seconds: 5));
      expect(controller.index, 2);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(controller.index, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('indicators track the index and jump on tap', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 4);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            semanticLabels: const <String>['Coast', 'Forest', 'City', 'Dunes'],
          ),
        ),
      );
      double dotWidth(int i) =>
          tester.getSize(find.byKey(ValueKey<int>(i))).width;
      expect(dotWidth(0), 22);
      expect(dotWidth(1), 6);

      await tester.tap(find.byKey(const ValueKey<int>(2)));
      await tester.pump();
      expect(controller.index, 2);
      await tester.pump(const Duration(milliseconds: 550));
      // Mid-transition the width is shared between the old and new dots.
      expect(dotWidth(0), inExclusiveRange(6, 22));
      expect(dotWidth(2), inExclusiveRange(6, 22));
      await tester.pumpAndSettle();
      expect(dotWidth(0), 6);
      expect(dotWidth(2), 22);

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const ValueKey<int>(2))),
        matchesSemantics(
          label: 'City',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('City'), findsWidgets);
      handle.dispose();

      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, showIndicators: false)),
      );
      expect(find.byKey(const ValueKey<int>(2)), findsNothing);
    });

    testWidgets('image semantics support increase and decrease', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      expect(_imageLabel(tester), 'Image 1 of 3');
      final SemanticsNode node = tester.getSemantics(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && (w.properties.image ?? false),
        ),
      );
      expect(node.value, '1 / 3');
      expect(node.increasedValue, '2 / 3');
      tester.semantics.increase(
        find.semantics.byPredicate(
          (SemanticsNode n) =>
              n.label == 'Image 1 of 3' &&
              n.getSemanticsData().hasAction(SemanticsAction.increase),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      handle.dispose();
    });

    testWidgets('overlay captions crossfade during a transition', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            overlayBuilder: (BuildContext context, int index) =>
                Text('Caption $index'),
          ),
        ),
      );
      expect(find.text('Caption 0'), findsOneWidget);
      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Caption 0'), findsOneWidget);
      expect(find.text('Caption 1'), findsOneWidget);
      final FadeTransition outgoing = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Caption 0'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(outgoing.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Caption 0'), findsNothing);
      expect(find.text('Caption 1'), findsOneWidget);
    });

    testWidgets('uses the morph shader once it has loaded', (
      WidgetTester tester,
    ) async {
      final bool ready = (await tester.runAsync(MorphSlider.precacheShader))!;
      expect(ready, isTrue, reason: 'shader should load in flutter test');
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            effect: MorphEffect.ripple,
          ),
        ),
      );
      await _settleImages(tester);
      await _settleNeighbor(tester);
      expect(_painter(tester).usesShader, isTrue);

      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_painter(tester).debugLastPaintUsedShader, isTrue);
      expect(_painter(tester).effect, MorphEffect.ripple);

      // Changing the effect mid-transition is fine.
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            effect: MorphEffect.swirl,
            intensity: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester).effect, MorphEffect.swirl);
      expect(_painter(tester).debugLastPaintUsedShader, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to a crossfade without the shader', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(MorphSlider.precacheShader);
      MorphSlider.debugForceFallback = true;
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      await _settleImages(tester);
      expect(_painter(tester).usesShader, isFalse);

      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_transitioning(tester), isTrue);
      expect(_progress(tester), inExclusiveRange(0, 1));
      expect(_painter(tester).debugLastPaintUsedShader, isFalse);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled false crossfades and does not autoplay', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(MorphSlider.precacheShader);
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            enabled: false,
            autoPlay: true,
            interval: const Duration(seconds: 1),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(controller.index, 0);
      expect(_painter(tester).usesShader, isFalse);

      controller.next();
      await tester.pump();
      expect(controller.isAnimating, isTrue);
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    });

    testWidgets('reduced motion swaps instantly and skips autoplay', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            autoPlay: true,
            interval: const Duration(seconds: 1),
            onIndexChanged: changes.add,
          ),
          reducedMotion: true,
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(controller.index, 0);

      controller.next();
      await tester.pump();
      expect(controller.index, 1);
      expect(changes, <int>[1]);
      expect(_transitioning(tester), isFalse);
      expect(controller.isAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // A drag still navigates, without scrubbing.
      final TestGesture gesture = await _slowDrag(tester, -150);
      expect(_progress(tester), 0);
      await gesture.up();
      await tester.pump();
      expect(controller.index, 2);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('turning on reduced motion mid-transition finishes it', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      controller.next();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          MorphSlider(images: images, controller: controller),
          reducedMotion: true,
        ),
      );
      expect(_transitioning(tester), isFalse);
      expect(controller.index, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('shrinking the image list clamps the index', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 4);
      final MorphSliderController controller = MorphSliderController(
        initialIndex: 3,
      );
      addTearDown(controller.dispose);
      final List<int> changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images,
            controller: controller,
            onIndexChanged: changes.add,
          ),
        ),
      );
      controller.previous();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          MorphSlider(
            images: images.sublist(0, 2),
            controller: controller,
            onIndexChanged: changes.add,
          ),
        ),
      );
      await tester.pump();
      expect(controller.index, 1);
      expect(_transitioning(tester), isFalse);
      expect(changes.last, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping providers reloads the image', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 4);
      await tester.pumpWidget(_wrap(MorphSlider(images: images.sublist(0, 2))));
      await _settleImages(tester);
      final ui.Image first = _painter(tester).from as ui.Image;
      await tester.pumpWidget(_wrap(MorphSlider(images: images.sublist(2, 4))));
      await tester.pump();
      expect(_painter(tester).from, isNull);
      await _settleImages(tester);
      final ui.Image second = _painter(tester).from as ui.Image;
      expect(second.isCloneOf(first), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing image shows the placeholder icon', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 2);
      final MemoryImage broken = MemoryImage(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
      await tester.pumpWidget(
        _wrap(MorphSlider(images: <ImageProvider>[broken, images[1]])),
      );
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-transition and mid-load does not throw', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController controller = MorphSliderController();
      addTearDown(controller.dispose);

      // Mid-load: images are still decoding.
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      // Mid-transition and mid-drag.
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      controller.next();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(controller.isAnimating, isFalse);
      // Calls on a detached controller are ignored.
      controller.next();
      expect(controller.index, 1);

      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: controller)),
      );
      final TestGesture gesture = await _slowDrag(tester, -120, steps: 3);
      await tester.pumpWidget(const SizedBox());
      await gesture.up();
      expect(tester.takeException(), isNull);
    });

    testWidgets('swapping controllers moves the attachment', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 3);
      final MorphSliderController a = MorphSliderController();
      final MorphSliderController b = MorphSliderController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: a)),
      );
      a.next();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(MorphSlider(images: images, controller: b)),
      );
      expect(b.index, 1);
      a.next();
      await tester.pumpAndSettle();
      expect(b.index, 1);
      b.next();
      await tester.pumpAndSettle();
      expect(b.index, 2);
    });

    testWidgets('uses 16:9 when the height is unbounded', (
      WidgetTester tester,
    ) async {
      final List<MemoryImage> images = await _makeImages(tester, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                SizedBox(width: 320, child: MorphSlider(images: images)),
              ],
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(MorphSlider));
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
    });
  });
}

/// Makes sure the neighbor image used by the next transition has decoded.
Future<void> _settleNeighbor(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}
