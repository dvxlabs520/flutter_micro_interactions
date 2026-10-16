import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/reflective_card.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A 320 x 200 card centered on the 800 x 600 test screen, spanning
/// x 240..560 and y 200..400.
Widget _card({
  bool enabled = true,
  bool idleAnimation = false,
  ReflectiveCardFinish finish = ReflectiveCardFinish.chrome,
  bool holographic = false,
  Color? metalColor,
  ImageProvider? reflection,
  Duration idleDuration = const Duration(seconds: 6),
  VoidCallback? onPressed,
}) {
  return ReflectiveCard(
    width: 320,
    height: 200,
    enabled: enabled,
    idleAnimation: idleAnimation,
    finish: finish,
    holographic: holographic,
    metalColor: metalColor,
    reflection: reflection,
    idleDuration: idleDuration,
    child: Center(
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        child: const Text('Ada Lovelace'),
      ),
    ),
  );
}

Matrix4 _matrix(WidgetTester tester) {
  return tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ReflectiveCard),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
}

dynamic _painter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(ReflectiveCard),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_SurfacePainter',
          ),
        ),
      )
      .painter;
}

Offset _light(WidgetTester tester) => _painter(tester).motion.light as Offset;

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

/// An image provider that completes when the test says so.
class _DelayedImage extends ImageProvider<_DelayedImage> {
  final Completer<ImageInfo> completer = Completer<ImageInfo>();

  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DelayedImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DelayedImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(completer.future);
  }
}

void main() {
  group('ReflectiveCard', () {
    testWidgets('renders flat at rest with its child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(tester.getSize(find.byType(ReflectiveCard)), const Size(320, 200));
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('defaults to the ID-1 aspect ratio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ReflectiveCard(width: 428, idleAnimation: false)),
      );
      final Size size = tester.getSize(find.byType(ReflectiveCard));
      expect(size.width, 428);
      expect(size.height, closeTo(428 * 54 / 85.6, 0.01));
    });

    testWidgets('tilts toward the pointer and resets on exit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(550, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Springs in rather than jumping.
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      final Matrix4 m = _matrix(tester);
      expect(m, isNot(Matrix4.identity()));
      final Offset right = MatrixUtils.transformPoint(m, const Offset(160, 0));
      final Offset left = MatrixUtils.transformPoint(m, const Offset(-160, 0));
      // The right side, under the pointer, recedes and projects smaller.
      expect(right.dx.abs(), lessThan(left.dx.abs()));

      await mouse.moveTo(const Offset(750, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_matrix(tester), isNot(Matrix4.identity()));
      await tester.pumpAndSettle();
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('touch drag tilts and releases on lift', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture finger = await tester.startGesture(
        const Offset(260, 300),
      );
      await tester.pumpAndSettle();
      final Matrix4 pressed = _matrix(tester);
      expect(pressed, isNot(Matrix4.identity()));

      await finger.moveTo(const Offset(540, 220));
      await tester.pumpAndSettle();
      expect(_matrix(tester), isNot(pressed));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_matrix(tester), Matrix4.identity());
    });

    testWidgets('highlight position follows the tilt', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(250, 210));
      await tester.pumpAndSettle();
      final Offset topLeft = _light(tester);
      expect(topLeft.dx, lessThan(-0.8));
      expect(topLeft.dy, lessThan(-0.8));

      await mouse.moveTo(const Offset(550, 390));
      await tester.pumpAndSettle();
      final Offset bottomRight = _light(tester);
      expect(bottomRight.dx, greaterThan(0.8));
      expect(bottomRight.dy, greaterThan(0.8));

      // The child floats on a raised layer that shifts with the tilt.
      final Matrix4 raised = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byType(ElevatedButton),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      final Offset translated = Offset(raised.storage[12], raised.storage[13]);
      expect(translated.dx, greaterThan(0));
      expect(translated.dy, greaterThan(0));
    });

    testWidgets('child taps still fire while tilting', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(_card(onPressed: () => taps++)));
      await tester.tap(find.text('Ada Lovelace'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('every finish and a custom tint render', (
      WidgetTester tester,
    ) async {
      for (final ReflectiveCardFinish finish in ReflectiveCardFinish.values) {
        await tester.pumpWidget(_wrap(_card(finish: finish)));
        expect(tester.takeException(), isNull);
        expect(
          _painter(tester).hologram,
          finish == ReflectiveCardFinish.holographic,
        );
      }
      await tester.pumpWidget(
        _wrap(_card(metalColor: const Color(0xFF2F6FDB), holographic: true)),
      );
      expect(tester.takeException(), isNull);
      expect(_painter(tester).hologram, isTrue);
      // Text on the card picks a readable default color.
      final DefaultTextStyle style = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(style.style.color, isNotNull);
    });

    testWidgets('reflection image loads asynchronously', (
      WidgetTester tester,
    ) async {
      final _DelayedImage provider = _DelayedImage();
      await tester.pumpWidget(_wrap(_card(reflection: provider)));
      expect(_painter(tester).reflection, isNull);

      final ui.Image image = (await tester.runAsync(
        () => createTestImage(width: 40, height: 30),
      ))!;
      provider.completer.complete(ImageInfo(image: image));
      await tester.pump();
      await tester.pump();
      expect(_painter(tester).reflection, isNotNull);
      expect(tester.takeException(), isNull);

      // Removing the reflection clears it.
      await tester.pumpWidget(_wrap(_card()));
      expect(_painter(tester).reflection, isNull);
    });

    testWidgets('idle animation moves the light', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_card(idleAnimation: true)));
      final Offset first = _light(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_light(tester), isNot(first));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.hasRunningAnimations, isTrue);

      // Changing settings mid-loop does not throw.
      await tester.pumpWidget(
        _wrap(
          _card(
            idleAnimation: true,
            finish: ReflectiveCardFinish.gold,
            idleDuration: const Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(_wrap(_card()));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion renders a static sheen without frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_card(idleAnimation: true), reducedMotion: true),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(540, 220));
      await tester.pump();
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      final Offset light = _light(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_light(tester), light);
    });

    testWidgets('enabled false stays flat and static', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_card(enabled: false, idleAnimation: true)),
      );
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(540, 220));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disabling mid-tilt resets', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_card()));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(540, 220));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(_card(enabled: false)));
      await tester.pump();
      expect(_matrix(tester), Matrix4.identity());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('child semantics stay intact', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_card(idleAnimation: true)));
      expect(find.bySemanticsLabel('Ada Lovelace'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(idleAnimation: true)));
      final TestGesture mouse = await _mouse(tester);
      await mouse.moveTo(const Offset(540, 220));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
