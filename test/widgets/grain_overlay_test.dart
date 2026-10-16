import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/src/grain_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _content() => const SizedBox(
  width: 200,
  height: 120,
  child: ColoredBox(color: Colors.indigo),
);

Finder _grainPaint() => find.descendant(
  of: find.byType(GrainOverlay),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_GrainPainter',
  ),
);

dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_grainPaint()).painter;

ui.Image _image(WidgetTester tester) => _painter(tester).image as ui.Image;

int _frame(WidgetTester tester) =>
    (_painter(tester).frame as ValueNotifier<int>).value;

const Duration _interval = Duration(milliseconds: 100);

void main() {
  group('GrainOverlay', () {
    testWidgets('toggling the grain keeps the child state', (
      WidgetTester tester,
    ) async {
      final GlobalKey<_CounterState> counter = GlobalKey<_CounterState>();
      await tester.pumpWidget(
        _wrap(GrainOverlay(animated: false, child: _Counter(key: counter))),
      );
      counter.currentState!.value = 3;
      await tester.pumpWidget(
        _wrap(GrainOverlay(enabled: false, child: _Counter(key: counter))),
      );
      await tester.pumpWidget(
        _wrap(
          GrainOverlay(
            animated: false,
            opacity: 0,
            child: _Counter(key: counter),
          ),
        ),
      );
      expect(counter.currentState!.value, 3);
    });

    testWidgets('paints grain over the child on the first frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(GrainOverlay(child: _content())));
      expect(_grainPaint(), findsOneWidget);
      final ui.Image image = _image(tester);
      expect(image.width, greaterThan(0));
      expect(image.debugDisposed, isFalse);
      // The grain does not change the child's layout.
      expect(tester.getSize(find.byType(GrainOverlay)), const Size(200, 120));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the noise image is disposed with the last overlay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GrainOverlay(key: const Key('a'), child: _content()),
              GrainOverlay(key: const Key('b'), child: _content()),
            ],
          ),
        ),
      );
      final List<CustomPaint> paints = tester
          .widgetList<CustomPaint>(_grainPaint())
          .toList();
      final ui.Image shared = (paints[0].painter as dynamic).image as ui.Image;
      // One tile is shared by every overlay.
      expect((paints[1].painter as dynamic).image, same(shared));

      await tester.pumpWidget(
        _wrap(GrainOverlay(key: const Key('a'), child: _content())),
      );
      expect(shared.debugDisposed, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(shared.debugDisposed, isTrue);
    });

    testWidgets('the grain refreshes at the refresh interval', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(GrainOverlay(refreshInterval: _interval, child: _content())),
      );
      final int first = _frame(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_frame(tester), first);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(milliseconds: 60));
      final int second = _frame(tester);
      expect(second, isNot(first));
      await tester.pump(_interval);
      expect(_frame(tester), isNot(second));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the refresh timer stops on dispose', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(GrainOverlay(refreshInterval: _interval, child: _content())),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      // A leftover periodic timer would also fail the test here.
    });

    testWidgets('reduced motion shows static grain with no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GrainOverlay(refreshInterval: _interval, child: _content()),
          reducedMotion: true,
        ),
      );
      expect(_grainPaint(), findsOneWidget);
      final int first = _frame(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_frame(tester), first);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('animated false shows static grain with no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GrainOverlay(
            animated: false,
            refreshInterval: _interval,
            child: _content(),
          ),
        ),
      );
      final int first = _frame(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_frame(tester), first);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a disabled TickerMode pauses the refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TickerMode(
            enabled: false,
            child: GrainOverlay(refreshInterval: _interval, child: _content()),
          ),
        ),
      );
      final int first = _frame(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_frame(tester), first);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('enabled false paints only the child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(GrainOverlay(enabled: false, child: _content())),
      );
      expect(_grainPaint(), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('taps and semantics pass through to the child', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          GrainOverlay(
            animated: false,
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Press'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GrainOverlay));
      expect(taps, 1);
      expect(find.bySemanticsLabel('Press'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('config changes mid-animation are safe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(GrainOverlay(refreshInterval: _interval, child: _content())),
      );
      final ui.Image mono = _image(tester);
      await tester.pump(const Duration(milliseconds: 150));

      await tester.pumpWidget(
        _wrap(
          GrainOverlay(
            refreshInterval: const Duration(milliseconds: 40),
            monochrome: false,
            grainSize: 2,
            opacity: 0.3,
            blendMode: BlendMode.softLight,
            child: _content(),
          ),
        ),
      );
      // The monochrome tile has no other user left.
      expect(mono.debugDisposed, isTrue);
      expect(_image(tester), isNot(same(mono)));
      final int before = _frame(tester);
      await tester.pump(const Duration(milliseconds: 45));
      expect(_frame(tester), isNot(before));

      await tester.pumpWidget(
        _wrap(GrainOverlay(enabled: false, child: _content())),
      );
      expect(_grainPaint(), findsNothing);
      await tester.pumpWidget(
        _wrap(GrainOverlay(refreshInterval: _interval, child: _content())),
      );
      expect(_grainPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);
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
  int value = 0;

  @override
  Widget build(BuildContext context) => Text('$value');
}
