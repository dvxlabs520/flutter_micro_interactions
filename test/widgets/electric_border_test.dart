import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/electric_border.dart';
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
  of: find.byType(ElectricBorder),
  matching: find.byType(CustomPaint),
);

dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painters().last).painter;

double _seconds(WidgetTester tester) =>
    (_painter(tester).seconds as num).toDouble();

double _fade(WidgetTester tester) =>
    (_painter(tester).fadeValue as num).toDouble();

const ValueKey<String> _captureKey = ValueKey<String>('capture');
const double _margin = 24;
const Size _card = Size(320, 140);
const double _radius = 16;

Widget _pixelScene({
  required bool active,
  bool enabled = true,
  double chaos = 0.6,
}) {
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
            child: ElectricBorder(
              active: active,
              enabled: enabled,
              chaos: chaos,
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

/// The furthest distances outside and inside the outline of pixels that
/// differ between [a] and [b] by more than [tolerance] levels.
(double, double) _spread(
  Uint8List a,
  Uint8List b,
  int width, {
  int tolerance = 6,
}) {
  double outside = 0.0;
  double inside = 0.0;
  for (int i = 0; i < a.length; i += 4) {
    bool changed = false;
    for (int c = 0; c < 3; c++) {
      if ((a[i + c] - b[i + c]).abs() > tolerance) changed = true;
    }
    if (!changed) continue;
    final int p = i ~/ 4;
    final double d = _outlineDistance(
      Offset(p % width + 0.5, p ~/ width + 0.5),
    );
    outside = math.max(outside, d);
    inside = math.max(inside, -d);
  }
  return (outside, inside);
}

void main() {
  group('ElectricBorder', () {
    testWidgets('renders its child with a decorative painter on top', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ElectricBorder(child: Text('Live'))));
      expect(find.text('Live'), findsOneWidget);
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
        Size(800, 48),
        Size(6, 6),
      ];
      for (final Brightness brightness in Brightness.values) {
        for (final Size size in sizes) {
          await tester.pumpWidget(
            _wrap(
              ElectricBorder(
                chaos: 1,
                borderRadius: BorderRadius.circular(
                  size.height < 60 ? 999 : 16,
                ),
                child: _box(size.width, size.height),
              ),
              brightness: brightness,
            ),
          );
          for (int i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          expect(tester.takeException(), isNull, reason: '$brightness $size');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the current moves over time at the given speed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(ElectricBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 16));
      final double s0 = _seconds(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double s1 = _seconds(tester);
      expect(tester.hasRunningAnimations, isTrue);
      expect(s1 - s0, closeTo(0.5, 0.01));

      // Doubling the speed keeps the time continuous and doubles its pace.
      await tester.pumpWidget(_wrap(ElectricBorder(speed: 2, child: _box())));
      expect(_seconds(tester), closeTo(s1, 0.001));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_seconds(tester) - s1, closeTo(1.0, 0.02));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('deactivating fades out over 300ms, then idles', (
      WidgetTester tester,
    ) async {
      Widget build(bool active) =>
          _wrap(ElectricBorder(active: active, child: _box()));

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 150));
      final double midFade = _fade(tester);
      expect(midFade, greaterThan(0.0));
      expect(midFade, lessThan(1.0));
      final double before = _seconds(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_seconds(tester), greaterThan(before));

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_fade(tester), greaterThan(0.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_fade(tester), 1.0);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('starting inactive schedules no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ElectricBorder(active: false, child: _box())),
      );
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion renders a frozen frame without tickers', (
      WidgetTester tester,
    ) async {
      Widget build(bool active) => _wrap(
        ElectricBorder(active: active, child: const Text('Still')),
        reducedMotion: true,
      );
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      final double rest = _seconds(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_seconds(tester), rest);
      expect(find.text('Still'), findsOneWidget);

      await tester.pumpWidget(build(false));
      expect(_fade(tester), 0.0);
      await tester.pumpWidget(build(true));
      expect(_fade(tester), 1.0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false renders a frozen frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ElectricBorder(enabled: false, child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_fade(tester), 1.0);
      final double rest = _seconds(tester);

      await tester.pumpWidget(_wrap(ElectricBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        _wrap(ElectricBorder(enabled: false, child: _box())),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_seconds(tester), rest);
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(ElectricBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          ElectricBorder(
            color: const Color(0xFF5BC0FF),
            thickness: 2.5,
            chaos: 0,
            speed: 3,
            borderRadius: BorderRadius.circular(999),
            sparks: false,
            child: _box(220, 48),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        _wrap(
          ElectricBorder(
            chaos: 1,
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
      await tester.pumpWidget(_wrap(ElectricBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(ElectricBorder(child: _box())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(ElectricBorder(active: false, child: _box())),
      );
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
          ElectricBorder(
            borderRadius: BorderRadius.circular(999),
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Boost'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        matchesSemantics(
          label: 'Boost',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('Boost'));
      expect(taps, 1);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the current stays on the border', (WidgetTester tester) async {
      await tester.pumpWidget(_pixelScene(active: false));
      await tester.pump();
      final (Uint8List plain, int width) = await _capture(tester);

      await tester.pumpWidget(_pixelScene(active: true, enabled: false));
      await tester.pump();
      final (Uint8List still, _) = await _capture(tester);
      final (double out0, double in0) = _spread(plain, still, width);
      expect(out0, lessThanOrEqualTo(8.0));
      expect(in0, lessThanOrEqualTo(10.0));
      final (double strongOut0, double strongIn0) = _spread(
        plain,
        still,
        width,
        tolerance: 30,
      );
      expect(strongOut0, lessThanOrEqualTo(6.0));
      expect(strongIn0, lessThanOrEqualTo(8.0));

      // Moving frames at full chaos, sparks included. Faint glow may reach
      // a little further; anything clearly visible stays within 9 pixels.
      await tester.pumpWidget(_pixelScene(active: true, chaos: 1));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 230));
        final (Uint8List frame, _) = await _capture(tester);
        final (double out, double inside) = _spread(plain, frame, width);
        expect(out, lessThanOrEqualTo(10.0));
        expect(inside, lessThanOrEqualTo(12.0));
        final (double strongOut, double strongIn) = _spread(
          plain,
          frame,
          width,
          tolerance: 30,
        );
        expect(strongOut, lessThanOrEqualTo(9.0));
        expect(strongIn, lessThanOrEqualTo(10.0));
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
