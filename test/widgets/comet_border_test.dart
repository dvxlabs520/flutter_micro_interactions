import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/comet_border.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  bool reducedMotion = false,
  Brightness brightness = Brightness.dark,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _box([double width = 320, double height = 140]) =>
    SizedBox(width: width, height: height);

Finder _painters() => find.descendant(
  of: find.byType(CometBorder),
  matching: find.byType(CustomPaint),
);

dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painters().last).painter;

double _progress(WidgetTester tester) =>
    (_painter(tester).headProgress as num).toDouble();

double _fade(WidgetTester tester) =>
    (_painter(tester).fadeValue as num).toDouble();

const ValueKey<String> _captureKey = ValueKey<String>('capture');
const double _margin = 24;
const Size _card = Size(320, 140);
const double _radius = 16;

Widget _pixelScene({required bool active, bool enabled = true}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          color: const Color(0xFF1C1B1F),
          child: Padding(
            padding: const EdgeInsets.all(_margin),
            child: CometBorder(
              active: active,
              enabled: enabled,
              child: Container(
                width: _card.width,
                height: _card.height,
                decoration: const BoxDecoration(
                  color: Color(0xFF36343B),
                  borderRadius: BorderRadius.all(Radius.circular(_radius)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<(Uint8List, int)> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_captureKey),
  );
  final (ByteData, int)? result = await tester.runAsync<(ByteData, int)>(
    () async {
      final ui.Image image = await boundary.toImage();
      final ByteData? bytes = await image.toByteData();
      final int width = image.width;
      image.dispose();
      return (bytes!, width);
    },
  );
  return (result!.$1.buffer.asUint8List(), result.$2);
}

/// Distance of [p] from the card's rounded outline; positive outside.
double _outlineDistance(Offset p) {
  final Offset c = const Offset(_margin, _margin) + _card.center(Offset.zero);
  final double qx = (p.dx - c.dx).abs() - (_card.width / 2 - _radius);
  final double qy = (p.dy - c.dy).abs() - (_card.height / 2 - _radius);
  final double outside = math.sqrt(
    math.pow(math.max(qx, 0.0), 2) + math.pow(math.max(qy, 0.0), 2),
  );
  return outside + math.min(math.max(qx, qy), 0.0) - _radius;
}

/// Largest distance from the outline of a pixel that differs between [a]
/// and [b] by more than [tolerance] levels.
double _maxSpread(Uint8List a, Uint8List b, int width, {int tolerance = 6}) {
  double worst = 0.0;
  for (int i = 0; i < a.length; i += 4) {
    bool changed = false;
    for (int c = 0; c < 3; c++) {
      if ((a[i + c] - b[i + c]).abs() > tolerance) changed = true;
    }
    if (!changed) continue;
    final int p = i ~/ 4;
    final Offset o = Offset(p % width + 0.5, p ~/ width + 0.5);
    worst = math.max(worst, _outlineDistance(o).abs());
  }
  return worst;
}

void main() {
  group('CometBorder', () {
    testWidgets('renders its child with a decorative painter on top', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CometBorder(child: Text('Star'))));
      expect(find.text('Star'), findsOneWidget);
      expect(_painters(), findsOneWidget);
      expect(_fade(tester), 1.0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('paints at several sizes, shapes and themes', (
      WidgetTester tester,
    ) async {
      const List<Size> sizes = <Size>[
        Size(40, 24),
        Size(320, 140),
        Size(600, 48),
        Size(10, 10),
      ];
      for (final Brightness brightness in Brightness.values) {
        for (final Size size in sizes) {
          for (final int count in <int>[1, 3]) {
            await tester.pumpWidget(
              _wrap(
                CometBorder(
                  cometCount: count,
                  clockwise: count == 1,
                  tailLength: count == 1 ? 1.0 : 0.25,
                  borderRadius: BorderRadius.circular(
                    size.height < 60 ? 999 : 16,
                  ),
                  child: _box(size.width, size.height),
                ),
                brightness: brightness,
              ),
            );
            for (int i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 350));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$brightness $size $count',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the head travels at one lap per duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometBorder(duration: const Duration(seconds: 2), child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final double p0 = _progress(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double p1 = _progress(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double p2 = _progress(tester);
      expect(tester.hasRunningAnimations, isTrue);
      expect(p1 - p0, closeTo(0.25, 0.01));
      expect(p2 - p1, closeTo(0.25, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a duration change keeps the head position continuous', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometBorder(duration: const Duration(seconds: 4), child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 800));
      final double before = _progress(tester);
      await tester.pumpWidget(
        _wrap(CometBorder(duration: const Duration(seconds: 1), child: _box())),
      );
      expect(_progress(tester), closeTo(before, 0.001));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_progress(tester) - before, closeTo(0.25, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('deactivating fades out over 300ms, then idles', (
      WidgetTester tester,
    ) async {
      Widget build(bool active) =>
          _wrap(CometBorder(active: active, child: _box()));

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 150));
      final double midFade = _fade(tester);
      expect(midFade, greaterThan(0.0));
      expect(midFade, lessThan(1.0));
      // The comet keeps moving while it fades.
      final double before = _progress(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_progress(tester), isNot(equals(before)));

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Re-activating fades back in and resumes the motion.
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_fade(tester), greaterThan(0.0));
      expect(_fade(tester), lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fade(tester), 1.0);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('starting inactive schedules no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CometBorder(active: false, child: _box())));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion renders a static frame without tickers', (
      WidgetTester tester,
    ) async {
      Widget build(bool active) => _wrap(
        CometBorder(active: active, child: const Text('Still')),
        reducedMotion: true,
      );
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      expect(_progress(tester), 0.0);
      await tester.pump(const Duration(seconds: 1));
      expect(_progress(tester), 0.0);
      expect(find.text('Still'), findsOneWidget);

      // Toggling is instant.
      await tester.pumpWidget(build(false));
      expect(_fade(tester), 0.0);
      await tester.pumpWidget(build(true));
      expect(_fade(tester), 1.0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false renders statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometBorder(enabled: false, child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_fade(tester), 1.0);
      expect(_progress(tester), 0.0);

      await tester.pumpWidget(_wrap(CometBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        _wrap(CometBorder(enabled: false, child: _box())),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_progress(tester), 0.0);
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CometBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          CometBorder(
            color: Colors.amber,
            tailLength: 0.6,
            thickness: 2,
            duration: const Duration(milliseconds: 1500),
            cometCount: 4,
            clockwise: false,
            borderRadius: BorderRadius.circular(999),
            showTrack: false,
            twinkle: false,
            child: _box(200, 48),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          CometBorder(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomRight: Radius.circular(4),
            ),
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-animation and mid-fade does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CometBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(CometBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(CometBorder(active: false, child: _box())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('child semantics and taps are preserved', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          CometBorder(
            borderRadius: BorderRadius.circular(999),
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Join'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        matchesSemantics(
          label: 'Join',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('Join'));
      expect(taps, 1);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the effect stays on the border', (WidgetTester tester) async {
      await tester.pumpWidget(_pixelScene(active: false));
      await tester.pump();
      final (Uint8List plain, int width) = await _capture(tester);

      // Static frame.
      await tester.pumpWidget(_pixelScene(active: true, enabled: false));
      await tester.pump();
      final (Uint8List still, _) = await _capture(tester);
      expect(_maxSpread(plain, still, width), lessThanOrEqualTo(8.5));

      // Several moving frames, stardust included.
      await tester.pumpWidget(_pixelScene(active: true));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 370));
        final (Uint8List frame, _) = await _capture(tester);
        expect(_maxSpread(plain, frame, width), lessThanOrEqualTo(8.5));
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
