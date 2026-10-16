import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_micro_interactions/src/border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _box([double width = 350, double height = 140]) =>
    SizedBox(width: width, height: height);

Finder _painters() => find.descendant(
  of: find.byType(BorderBeam),
  matching: find.byType(CustomPaint),
);

/// The painter drawn above the child.
dynamic _frontPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painters().last).painter;

double _turns(WidgetTester tester) =>
    (_frontPainter(tester).beamTurns as num).toDouble();

double _fade(WidgetTester tester) =>
    (_frontPainter(tester).fadeValue as num).toDouble();

const ValueKey<String> _captureKey = ValueKey<String>('capture');
const double _margin = 20;
const Size _card = Size(200, 100);
const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

/// A dark card wrapped in a [BorderBeam] inside a captured margin. Uses
/// `enabled: false` so the frame is deterministic.
Widget _pixelScene({
  required BorderBeamStyle style,
  required bool innerGlow,
  bool active = true,
  Brightness brightness = Brightness.dark,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          color: const Color(0xFF141218),
          child: Padding(
            padding: const EdgeInsets.all(_margin),
            child: BorderBeam(
              style: style,
              innerGlow: innerGlow,
              active: active,
              enabled: false,
              brightness: brightness,
              borderRadius: _radius,
              child: Container(
                width: _card.width,
                height: _card.height,
                decoration: const BoxDecoration(
                  color: Color(0xFF36343B),
                  borderRadius: _radius,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Renders the captured boundary to raw RGBA bytes.
Future<Uint8List> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_captureKey),
  );
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData();
    image.dispose();
    return bytes;
  });
  return data!.buffer.asUint8List();
}

/// Pixel positions where [a] and [b] differ by more than gradient dither
/// noise (2 levels in any channel), as pixel centers.
List<Offset> _diff(Uint8List a, Uint8List b, int width) {
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < a.length; i += 4) {
    bool changed = false;
    for (int c = 0; c < 4; c++) {
      if ((a[i + c] - b[i + c]).abs() > 2) changed = true;
    }
    if (changed) {
      final int p = i ~/ 4;
      out.add(Offset(p % width + 0.5, p ~/ width + 0.5));
    }
  }
  return out;
}

void main() {
  group('BorderBeam', () {
    testWidgets('renders its child with a decorative painter on top', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const BorderBeam(child: Text('Thinking'))));
      expect(find.text('Thinking'), findsOneWidget);
      expect(_painters(), findsOneWidget);
      expect(_fade(tester), 1.0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('every style paints at several sizes', (
      WidgetTester tester,
    ) async {
      const List<Size> sizes = <Size>[
        Size(70, 36),
        Size(350, 140),
        Size(600, 60),
      ];
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        for (final Brightness brightness in Brightness.values) {
          for (final Size size in sizes) {
            await tester.pumpWidget(
              _wrap(
                BorderBeam(
                  style: style,
                  brightness: brightness,
                  innerGlow: size.width > 300,
                  borderRadius: BorderRadius.circular(
                    size.height < 60 ? 999 : 16,
                  ),
                  child: _box(size.width, size.height),
                ),
              ),
            );
            for (int i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 400));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$style $brightness $size',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('paints a single decorative layer above the child', (
      WidgetTester tester,
    ) async {
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        await tester.pumpWidget(_wrap(BorderBeam(style: style, child: _box())));
        expect(_painters(), findsOneWidget, reason: '$style');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the beam angle progresses over time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BorderBeam(
            duration: const Duration(milliseconds: 2000),
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final double t0 = _turns(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double t1 = _turns(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double t2 = _turns(tester);

      expect(tester.hasRunningAnimations, isTrue);
      expect(t1 - t0, closeTo(0.25, 0.01));
      expect(t2 - t1, closeTo(0.25, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('default durations depend on the style', (_) async {
      expect(
        BorderBeam.defaultDurationFor(BorderBeamStyle.beam),
        const Duration(milliseconds: 1960),
      );
      expect(
        BorderBeam.defaultDurationFor(BorderBeamStyle.line),
        const Duration(milliseconds: 3100),
      );
      expect(
        BorderBeam.defaultDurationFor(BorderBeamStyle.pulse),
        const Duration(milliseconds: 2300),
      );
    });

    testWidgets('deactivating fades out, fires onDeactivated, then idles', (
      WidgetTester tester,
    ) async {
      int deactivated = 0;
      Widget build(bool active) => _wrap(
        BorderBeam(
          active: active,
          onDeactivated: () => deactivated++,
          child: _box(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 250));
      final double midFade = _fade(tester);
      expect(midFade, greaterThan(0.0));
      expect(midFade, lessThan(1.0));
      // Motion keeps running during the fade out.
      final double turnsBefore = _turns(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_turns(tester), isNot(equals(turnsBefore)));
      expect(deactivated, 0);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(deactivated, 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(deactivated, 1);
    });

    testWidgets('re-activating fades in and fires onActivated', (
      WidgetTester tester,
    ) async {
      int activated = 0;
      int deactivated = 0;
      Widget build(bool active) => _wrap(
        BorderBeam(
          active: active,
          onActivated: () => activated++,
          onDeactivated: () => deactivated++,
          child: _box(),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(_fade(tester), 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(activated, 0);

      await tester.pumpWidget(build(true));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fade(tester), inExclusiveRange(0.0, 1.0));
      expect(activated, 0);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_fade(tester), 1.0);
      expect(activated, 1);
      // The motion keeps looping while active.
      expect(tester.hasRunningAnimations, isTrue);

      // Reversing mid fade only fires the final callback.
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 700));
      expect(deactivated, 0);
      expect(activated, 2);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion renders a static frame without tickers', (
      WidgetTester tester,
    ) async {
      int activated = 0;
      int deactivated = 0;
      Widget build(bool active) => _wrap(
        BorderBeam(
          active: active,
          onActivated: () => activated++,
          onDeactivated: () => deactivated++,
          child: const Text('Still'),
        ),
        reducedMotion: true,
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.hasRunningAnimations, isFalse);
      final double rest = _turns(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_turns(tester), rest);
      expect(find.text('Still'), findsOneWidget);

      // Toggling is instant and the callbacks still fire.
      await tester.pumpWidget(build(false));
      expect(_fade(tester), 0.0);
      expect(deactivated, 1);
      await tester.pumpWidget(build(true));
      expect(_fade(tester), 1.0);
      expect(activated, 1);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion is static for every style', (
      WidgetTester tester,
    ) async {
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        await tester.pumpWidget(
          _wrap(BorderBeam(style: style, child: _box()), reducedMotion: true),
        );
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$style');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('enabled false renders statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(BorderBeam(enabled: false, child: _box())));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_fade(tester), 1.0);
      final double rest = _turns(tester);

      // Enabling starts the motion; disabling again freezes it.
      await tester.pumpWidget(_wrap(BorderBeam(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_wrap(BorderBeam(enabled: false, child: _box())));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_turns(tester), rest);
    });

    testWidgets('style, palette and duration changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(BorderBeam(child: _box())));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        _wrap(
          BorderBeam(
            style: BorderBeamStyle.line,
            palette: BorderBeamPalette.ocean,
            duration: const Duration(milliseconds: 900),
            strength: 0.5,
            borderWidth: 2,
            hueRange: 90,
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      for (final BorderBeamPalette palette in BorderBeamPalette.values) {
        await tester.pumpWidget(
          _wrap(
            BorderBeam(
              style: BorderBeamStyle.pulse,
              palette: palette,
              staticColors: true,
              child: _box(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpWidget(
        _wrap(
          BorderBeam(
            style: BorderBeamStyle.beam,
            innerGlow: true,
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a duration change keeps the beam angle continuous', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BorderBeam(duration: const Duration(seconds: 2), child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      final double before = _turns(tester);
      await tester.pumpWidget(
        _wrap(BorderBeam(duration: const Duration(seconds: 1), child: _box())),
      );
      expect(_turns(tester), closeTo(before, 0.001));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_turns(tester) - before, closeTo(0.25, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing mid-fade does not throw', (
      WidgetTester tester,
    ) async {
      int callbacks = 0;
      await tester.pumpWidget(
        _wrap(BorderBeam(onDeactivated: () => callbacks++, child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          BorderBeam(
            active: false,
            onDeactivated: () => callbacks++,
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(callbacks, 0);
    });

    testWidgets('child semantics and pointer input are preserved', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          BorderBeam(
            style: BorderBeamStyle.line,
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Send'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        matchesSemantics(
          label: 'Send',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('Send'));
      expect(taps, 1);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('custom colors and light tuning paint without error', (
      WidgetTester tester,
    ) async {
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        await tester.pumpWidget(
          _wrap(
            BorderBeam(
              style: style,
              brightness: Brightness.light,
              colors: const <Color>[Colors.red, Colors.blue],
              child: _box(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$style');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('strength zero and zero border width are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BorderBeam(strength: 0, borderWidth: 0, child: _box())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without innerGlow nothing paints off the border ring', (
      WidgetTester tester,
    ) async {
      final int width = (_card.width + _margin * 2).toInt();
      final Rect card = const Offset(_margin, _margin) & _card;
      final RRect outer = _radius.toRRect(card);
      // One pixel of anti-aliasing on the curved outer edge.
      final RRect aa = outer.inflate(1);
      // The ring band is 1.5 pixels wide; allow one extra pixel of
      // anti-aliasing.
      final RRect core = outer.deflate(2.5);
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        for (final Brightness brightness in Brightness.values) {
          await tester.pumpWidget(
            _pixelScene(
              style: style,
              innerGlow: false,
              active: false,
              brightness: brightness,
            ),
          );
          final Uint8List baseline = await _capture(tester);
          await tester.pumpWidget(
            _pixelScene(style: style, innerGlow: false, brightness: brightness),
          );
          final Uint8List lit = await _capture(tester);
          final List<Offset> changed = _diff(baseline, lit, width);
          expect(changed, isNotEmpty, reason: '$style $brightness paints');
          for (final Offset p in changed) {
            expect(
              card.contains(p) && aa.contains(p) && !core.contains(p),
              isTrue,
              reason: '$style $brightness painted off the ring at $p',
            );
          }
        }
      }
    });

    testWidgets('innerGlow paints the soft inner light', (
      WidgetTester tester,
    ) async {
      final int width = (_card.width + _margin * 2).toInt();
      final Rect card = const Offset(_margin, _margin) & _card;
      final RRect outer = _radius.toRRect(card);
      // One pixel of anti-aliasing on the curved outer edge.
      final RRect aa = outer.inflate(1);
      final RRect core = outer.deflate(4);
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        await tester.pumpWidget(
          _pixelScene(style: style, innerGlow: true, active: false),
        );
        final Uint8List baseline = await _capture(tester);
        await tester.pumpWidget(_pixelScene(style: style, innerGlow: true));
        final Uint8List lit = await _capture(tester);
        final List<Offset> changed = _diff(baseline, lit, width);
        expect(
          changed.where(core.contains),
          isNotEmpty,
          reason: '$style inner light',
        );
        // The inner light stays inside the widget bounds.
        expect(
          changed.every((Offset p) => card.contains(p) && aa.contains(p)),
          isTrue,
          reason: '$style',
        );
        // The card center stays untouched.
        expect(
          changed.where((Offset p) => (p - card.center).distance < 10),
          isEmpty,
        );
      }
    });

    testWidgets('the ring stays on the border while animating', (
      WidgetTester tester,
    ) async {
      final Rect card = const Offset(_margin, _margin) & _card;
      final RRect outer = _radius.toRRect(card);
      // One pixel of anti-aliasing on the curved outer edge.
      final RRect aa = outer.inflate(1);
      final RRect core = outer.deflate(2.5);
      final int width = (_card.width + _margin * 2).toInt();
      Widget scene(bool active, BorderBeamStyle style) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _captureKey,
            child: ColoredBox(
              color: const Color(0xFF141218),
              child: Padding(
                padding: const EdgeInsets.all(_margin),
                child: BorderBeam(
                  style: style,
                  active: active,
                  borderRadius: _radius,
                  child: Container(
                    width: _card.width,
                    height: _card.height,
                    color: const Color(0xFF36343B),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final BorderBeamStyle style in BorderBeamStyle.values) {
        await tester.pumpWidget(scene(false, style));
        await tester.pump();
        final Uint8List baseline = await _capture(tester);
        await tester.pumpWidget(scene(true, style));
        await tester.pump(const Duration(milliseconds: 1500));
        final Uint8List lit = await _capture(tester);
        final List<Offset> changed = _diff(baseline, lit, width);
        expect(changed, isNotEmpty, reason: '$style');
        for (final Offset p in changed) {
          expect(
            card.contains(p) && aa.contains(p) && !core.contains(p),
            isTrue,
            reason: '$style painted off the ring at $p',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    test('rejects out of range parameters', () {
      expect(
        () => BorderBeam(strength: 1.5, child: _box()),
        throwsAssertionError,
      );
      expect(
        () => BorderBeam(colors: const <Color>[], child: _box()),
        throwsAssertionError,
      );
      expect(
        () => BorderBeam(borderWidth: -1, child: _box()),
        throwsAssertionError,
      );
    });
  });
}
