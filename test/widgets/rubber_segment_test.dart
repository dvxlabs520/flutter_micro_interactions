import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/rubber_segment.dart';
import 'package:flutter_test/flutter_test.dart';

const List<RubberSegmentItem<int>> _items = <RubberSegmentItem<int>>[
  RubberSegmentItem<int>(value: 0, label: Text('Day')),
  RubberSegmentItem<int>(value: 1, label: Text('Week')),
  RubberSegmentItem<int>(value: 2, label: Text('Month')),
];

Widget _wrap(Widget child, {bool reduced = false, TextDirection? direction}) {
  Widget body = Scaffold(body: Center(child: child));
  if (direction != null) {
    body = Directionality(textDirection: direction, child: body);
  }
  final Widget app = MaterialApp(home: body);
  if (reduced) {
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }
  return app;
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<int> calls,
  int initial = 0,
  bool accept = true,
  bool reduced = false,
  bool fitContent = false,
  TextDirection? direction,
  List<RubberSegmentItem<int>> items = _items,
}) async {
  int value = initial;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return _wrap(
          RubberSegment<int>(
            items: items,
            value: value,
            fitContent: fitContent,
            onChanged: (int v) {
              calls.add(v);
              if (accept) setState(() => value = v);
            },
          ),
          reduced: reduced,
          direction: direction,
        );
      },
    ),
  );
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(RubberSegment<int>))).colorScheme;

/// Rounded rectangles painted by the control in [color] with [style].
List<RRect> _rrects(
  WidgetTester tester,
  Color color, {
  PaintingStyle style = PaintingStyle.fill,
}) {
  final List<RRect> found = <RRect>[];
  expect(
    tester.renderObject(find.byType(RubberSegment<int>)),
    paints..everything((Symbol method, List<dynamic> args) {
      if (method == #drawRRect) {
        final Paint paint = args[1] as Paint;
        if (paint.style == style &&
            paint.color.toARGB32() == color.toARGB32()) {
          found.add(args[0] as RRect);
        }
      }
      return true;
    }),
  );
  return found;
}

Rect _thumb(WidgetTester tester) =>
    _rrects(tester, _scheme(tester).primary).single.outerRect;

/// The label color of [text] as a 32-bit ARGB value.
int? _labelColor(WidgetTester tester, String text) {
  return tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style
      .color
      ?.toARGB32();
}

/// Width of the segment that holds [label]: the tight width the control
/// gives it.
double _segmentWidth(WidgetTester tester, Finder label) {
  return tester
      .getSize(
        find.ancestor(of: label, matching: find.byType(GestureDetector)).first,
      )
      .width;
}

/// Delivers a 'fontsChange' system message, as the engine does when a font
/// finishes loading (for example a web font).
Future<void> _sendFontsChange(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.system.name,
    SystemChannels.system.codec.encodeMessage(<String, Object?>{
      'type': 'fontsChange',
    }),
    (ByteData? data) {},
  );
}

/// Width of a [_FontSensitiveLabel] in the "currently loaded font".
double _fakeFontWidth = 40.0;

/// A label whose width depends on the loaded fonts.
class _FontSensitiveLabel extends LeafRenderObjectWidget {
  const _FontSensitiveLabel();

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFontSensitiveLabel();
}

/// Mimics [RenderParagraph] when a font finishes loading: it lays out again
/// with the new width, but its intrinsic width (measured with a separate,
/// cached painter in [RenderParagraph]) keeps the width of the old font.
class _RenderFontSensitiveLabel extends RenderBox
    with RelayoutWhenSystemFontsChangeMixin {
  final double _intrinsicWidth = _fakeFontWidth;
  double _width = _fakeFontWidth;

  /// The width this label needs to show its text in full.
  double get wanted => _width;

  @override
  void systemFontsDidChange() {
    _width = _fakeFontWidth;
    super.systemFontsDidChange();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth;

  @override
  double computeMinIntrinsicHeight(double width) => 20.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 20.0;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(_intrinsicWidth, 20.0));

  @override
  void performLayout() {
    size = constraints.constrain(Size(_width, 20.0));
  }
}

/// A font file shipped with the Flutter SDK, used to load a real font in the
/// middle of a test. Null when it cannot be found.
File? _sdkFont() {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return null;
  final File file = File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  return file.existsSync() ? file : null;
}

void main() {
  group('RubberSegment', () {
    testWidgets('renders equal segments with the thumb on the selection', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <int>[], initial: 1);
      final Size size = tester.getSize(find.byType(RubberSegment<int>));
      expect(size.height, greaterThanOrEqualTo(48));
      final Rect thumb = _thumb(tester);
      // Width of one of three equal segments inside 4 px padding.
      expect(thumb.width, closeTo((size.width - 8) / 3, 0.01));
      expect(thumb.height, closeTo(32, 0.01));
      expect(thumb.left, closeTo(4 + thumb.width, 0.01));
      final ColorScheme scheme = _scheme(tester);
      expect(_labelColor(tester, 'Week'), scheme.onPrimary.toARGB32());
      expect(_labelColor(tester, 'Day'), scheme.onSurfaceVariant.toARGB32());
    });

    testWidgets('tap requests a value; thumb only moves on rebuild', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls, accept: false);
      final Rect before = _thumb(tester);
      await tester.tap(find.text('Month'));
      await tester.tap(find.text('Day'));
      await tester.pump(const Duration(milliseconds: 100));
      // Tapping the already selected segment does not report again.
      expect(calls, <int>[2]);
      expect(_thumb(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('leading edge moves first, thumb stretches then settles', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls);
      final Rect rest = _thumb(tester);
      await tester.tap(find.text('Month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final Rect early = _thumb(tester);
      final double leadingMoved = early.right - rest.right;
      final double trailingMoved = early.left - rest.left;
      expect(leadingMoved, greaterThan(0));
      expect(leadingMoved, greaterThan(trailingMoved * 1.5));

      double maxWidth = early.width;
      double minHeight = early.height;
      double minWidthLate = double.infinity;
      double maxHeight = 0;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final Rect thumb = _thumb(tester);
        if (thumb.width > maxWidth) {
          maxWidth = thumb.width;
          minHeight = thumb.height;
        }
        if (i > 15 && thumb.width < minWidthLate) minWidthLate = thumb.width;
        if (thumb.height > maxHeight) maxHeight = thumb.height;
      }
      // Elongated and thinner while stretched across the gap.
      expect(maxWidth, greaterThan(rest.width * 1.3));
      expect(minHeight, lessThan(rest.height));
      // Squashes into place: briefly shorter and taller than at rest.
      expect(minWidthLate, lessThan(rest.width * 0.99));
      expect(maxHeight, greaterThan(rest.height));

      await tester.pumpAndSettle();
      final Rect end = _thumb(tester);
      expect(end.width, closeTo(rest.width, 0.01));
      expect(end.left, closeTo(rest.left + rest.width * 2, 0.01));
    });

    testWidgets('moving backwards leads with the other edge', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls, initial: 2);
      final Rect rest = _thumb(tester);
      await tester.tap(find.text('Day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final Rect early = _thumb(tester);
      final double leadingMoved = rest.left - early.left;
      final double trailingMoved = rest.right - early.right;
      expect(leadingMoved, greaterThan(trailingMoved * 1.5));
      await tester.pumpAndSettle();
    });

    testWidgets('label colors blend as the thumb passes', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls);
      final ColorScheme scheme = _scheme(tester);
      await tester.tap(find.text('Month'));
      await tester.pump();
      bool sawBlend = false;
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final int? week = _labelColor(tester, 'Week');
        if (week != scheme.onPrimary.toARGB32() &&
            week != scheme.onSurfaceVariant.toARGB32()) {
          sawBlend = true;
        }
      }
      expect(sawBlend, isTrue);
      await tester.pumpAndSettle();
      expect(_labelColor(tester, 'Month'), scheme.onPrimary.toARGB32());
      expect(_labelColor(tester, 'Week'), scheme.onSurfaceVariant.toARGB32());
    });

    testWidgets('fitContent sizes segments to their content', (
      WidgetTester tester,
    ) async {
      const List<RubberSegmentItem<int>> items = <RubberSegmentItem<int>>[
        RubberSegmentItem<int>(value: 0, label: Text('A')),
        RubberSegmentItem<int>(value: 1, label: Text('A much longer label')),
      ];
      await _pumpHost(tester, calls: <int>[], items: items, fitContent: true);
      final double first = _thumb(tester).width;
      await _pumpHost(
        tester,
        calls: <int>[],
        items: items,
        fitContent: true,
        initial: 1,
      );
      await tester.pumpAndSettle();
      final double second = _thumb(tester).width;
      expect(second, greaterThan(first * 2));
      expect(first, greaterThanOrEqualTo(48));

      await _pumpHost(tester, calls: <int>[], items: items, initial: 1);
      await tester.pumpAndSettle();
      final Size total = tester.getSize(find.byType(RubberSegment<int>));
      expect(_thumb(tester).width, closeTo((total.width - 8) / 2, 0.01));
    });

    testWidgets('RTL places the first segment on the right', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, calls: <int>[], direction: TextDirection.rtl);
      final Size size = tester.getSize(find.byType(RubberSegment<int>));
      expect(_thumb(tester).right, closeTo(size.width - 4, 0.01));
    });

    testWidgets('keyboard: focus ring and arrows step with wrap-around', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls);
      final Color primary = _scheme(tester).primary;
      expect(_rrects(tester, primary, style: PaintingStyle.stroke), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _rrects(tester, primary, style: PaintingStyle.stroke),
        hasLength(1),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(calls, <int>[1, 2, 0, 2]);
    });

    testWidgets('semantics: checked members of an exclusive group', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls);
      expect(
        tester.getSemantics(find.text('Day')),
        isSemantics(
          label: 'Day',
          isButton: true,
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Week')),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Week'));
      await tester.pumpAndSettle();
      expect(calls, <int>[1]);
      handle.dispose();
    });

    testWidgets('disabled: dimmed, ignores taps, semantics disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const RubberSegment<int>(items: _items, value: 0, onChanged: null),
        ),
      );
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(RubberSegment<int>),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));
      expect(
        tester.getSemantics(find.text('Week')),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      handle.dispose();

      final List<int> calls = <int>[];
      await tester.pumpWidget(
        _wrap(
          RubberSegment<int>(
            items: _items,
            value: 0,
            enabled: false,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.tap(find.text('Week'), warnIfMissed: false);
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('reduced motion: thumb jumps with no stretch or frames', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls, reduced: true);
      final Rect rest = _thumb(tester);
      await tester.tap(find.text('Month'));
      await tester.pump();
      final Rect moved = _thumb(tester);
      expect(moved.width, closeTo(rest.width, 0.01));
      expect(moved.height, closeTo(rest.height, 0.01));
      expect(moved.left, closeTo(rest.left + rest.width * 2, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rapid changes, item changes and dispose do not throw', (
      WidgetTester tester,
    ) async {
      final List<int> calls = <int>[];
      await _pumpHost(tester, calls: calls);
      await tester.tap(find.text('Month'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Day'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(calls, <int>[2, 0, 1]);
      final Size size = tester.getSize(find.byType(RubberSegment<int>));
      final Rect thumb = _thumb(tester);
      expect(thumb.left, closeTo(4 + (size.width - 8) / 3, 0.01));

      await tester.pumpWidget(
        _wrap(RubberSegment<int>(items: _items, value: 2, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(
        _wrap(
          RubberSegment<int>(
            items: _items.sublist(0, 2),
            value: 1,
            height: 44,
            thumbColor: Colors.teal,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(
        _wrap(RubberSegment<int>(items: _items, value: 0, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('re-measures labels when a font finishes loading', (
      WidgetTester tester,
    ) async {
      // The family is unknown at first, so the test font is used; then the
      // real font arrives under that family, as a web font would.
      const String family = 'RubberSegmentLateFont';
      const TextStyle style = TextStyle(fontSize: 14.0, fontFamily: family);
      await tester.pumpWidget(
        _wrap(
          RubberSegment<int>(
            items: _items,
            value: 0,
            fitContent: true,
            textStyle: style,
            onChanged: (_) {},
          ),
        ),
      );
      final Finder month = find.text('Month');
      final double before = tester.getSize(month).width;
      expect(_segmentWidth(tester, month), closeTo(before + 32.0, 0.01));

      await tester.runAsync(() async {
        final FontLoader loader = FontLoader(family)
          ..addFont(
            Future<ByteData>.value(
              ByteData.sublistView(_sdkFont()!.readAsBytesSync()),
            ),
          );
        await loader.load();
      });
      await tester.pump();
      await tester.pump();

      final double after = tester.getSize(month).width;
      expect(after, isNot(closeTo(before, 0.5)));
      final RenderParagraph paragraph = tester.renderObject(month);
      expect(paragraph.didExceedMaxLines, isFalse);
      // Sized for the new font, not the fallback it was first measured in.
      expect(_segmentWidth(tester, month), closeTo(after + 32.0, 0.01));
      expect(tester.takeException(), isNull);
    }, skip: _sdkFont() == null);

    testWidgets('a fontsChange message relayouts with fresh label widths', (
      WidgetTester tester,
    ) async {
      _fakeFontWidth = 40.0;
      addTearDown(() => _fakeFontWidth = 40.0);
      const List<RubberSegmentItem<int>> items = <RubberSegmentItem<int>>[
        RubberSegmentItem<int>(value: 0, label: _FontSensitiveLabel()),
        RubberSegmentItem<int>(value: 1, label: Text('Week')),
      ];
      await tester.pumpWidget(
        _wrap(
          RubberSegment<int>(
            items: items,
            value: 0,
            fitContent: true,
            onChanged: (_) {},
          ),
        ),
      );
      final Finder label = find.byType(_FontSensitiveLabel);
      expect(_segmentWidth(tester, label), closeTo(72.0, 0.01));

      // A wider font arrives.
      _fakeFontWidth = 90.0;
      await _sendFontsChange(tester);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      await tester.pump();

      final _RenderFontSensitiveLabel box = tester.renderObject(label);
      expect(box.wanted, 90.0);
      // The label is not truncated: its segment grew to fit it.
      expect(box.size.width, closeTo(90.0, 0.01));
      expect(_segmentWidth(tester, label), closeTo(122.0, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('re-measures labels when text scale or style changes', (
      WidgetTester tester,
    ) async {
      Future<void> pump({double scale = 1.0, double fontSize = 14.0}) {
        return tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: RubberSegment<int>(
                    items: _items,
                    value: 0,
                    fitContent: true,
                    textStyle: TextStyle(fontSize: fontSize),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final Finder month = find.text('Month');
      void expectFits() {
        final RenderParagraph paragraph = tester.renderObject(month);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          _segmentWidth(tester, month),
          closeTo(tester.getSize(month).width + 32.0, 0.01),
        );
      }

      await pump();
      final double base = _segmentWidth(tester, month);
      expectFits();

      await pump(scale: 2.0);
      expect(_segmentWidth(tester, month), greaterThan(base));
      expectFits();

      await pump(fontSize: 22.0);
      expect(_segmentWidth(tester, month), greaterThan(base));
      expectFits();
      expect(tester.takeException(), isNull);
    });
  });
}
