import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/status_mark.dart';
import 'package:flutter_micro_interactions/src/thinking_steps.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  Widget body = Padding(padding: const EdgeInsets.all(16), child: child);
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(home: Scaffold(body: body));
}

const List<ThinkingStep> _doneSteps = <ThinkingStep>[
  ThinkingStep(
    title: 'Read the question',
    detail: 'Two parts',
    status: MicroStatus.success,
  ),
  ThinkingStep(title: 'Search the docs', status: MicroStatus.success),
  ThinkingStep(title: 'Write the answer'),
];

const List<ThinkingStep> _activeSteps = <ThinkingStep>[
  ThinkingStep(title: 'Read the question', status: MicroStatus.success),
  ThinkingStep(title: 'Search the docs', status: MicroStatus.loading),
  ThinkingStep(title: 'Write the answer'),
];

/// Ends a test by removing the widget so tickers and timers are disposed.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  group('ThinkingSteps', () {
    testWidgets('renders steps, details and the header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _doneSteps)));
      expect(find.text('Thinking 0s'), findsOneWidget);
      expect(find.text('Read the question'), findsOneWidget);
      expect(find.text('Two parts'), findsOneWidget);
      expect(find.text('Write the answer'), findsOneWidget);
      expect(find.byType(StatusMark), findsNWidgets(3));
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('header clock ticks while thinking and freezes when done', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _doneSteps)));
      expect(find.text('Thinking 0s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Thinking 1s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Thinking 2s'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const ThinkingSteps(steps: _doneSteps, isThinking: false)),
      );
      expect(find.text('Thought for 2s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Thought for 2s'), findsOneWidget);

      // Thinking again starts a new measurement.
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _doneSteps)));
      expect(find.text('Thinking 0s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Thinking 1s'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('formats minutes and honours the elapsed override', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: _doneSteps,
            isThinking: false,
            elapsed: Duration(seconds: 75),
          ),
        ),
      );
      expect(find.text('Thought for 1m 15s'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(steps: _doneSteps, elapsed: Duration(seconds: 9)),
        ),
      );
      expect(find.text('Thinking 9s'), findsOneWidget);
      // With an override no internal timer runs.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Thinking 9s'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('headerBuilder replaces the default header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ThinkingSteps(
            steps: _doneSteps,
            headerBuilder:
                (BuildContext context, Duration elapsed, bool isThinking) {
                  return Text('Custom ${elapsed.inSeconds} $isThinking');
                },
          ),
        ),
      );
      expect(find.text('Custom 0 true'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Custom 1 true'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('collapses smoothly when thinking is done', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          ThinkingSteps(steps: _doneSteps, onExpansionChanged: changes.add),
        ),
      );
      final double expandedHeight = tester
          .getSize(find.byType(ThinkingSteps))
          .height;
      await tester.pumpWidget(
        _wrap(
          ThinkingSteps(
            steps: _doneSteps,
            isThinking: false,
            onExpansionChanged: changes.add,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final double midHeight = tester
          .getSize(find.byType(ThinkingSteps))
          .height;
      expect(midHeight, lessThan(expandedHeight));
      expect(find.text('Read the question'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      // Fully collapsed: the steps are offstage.
      expect(find.text('Read the question'), findsNothing);
      expect(
        tester.getSize(find.byType(ThinkingSteps)).height,
        lessThan(midHeight),
      );
      expect(changes, <bool>[false]);
      await _teardown(tester);
    });

    testWidgets('collapseWhenDone false keeps the list open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ThinkingSteps(steps: _doneSteps, collapseWhenDone: false)),
      );
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: _doneSteps,
            collapseWhenDone: false,
            isThinking: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read the question'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('tapping the header toggles the list', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          ThinkingSteps(steps: _doneSteps, onExpansionChanged: changes.add),
        ),
      );
      await tester.tap(find.text('Thinking 0s'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read the question'), findsNothing);
      await tester.tap(find.text('Thinking 0s'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read the question'), findsOneWidget);
      expect(changes, <bool>[false, true]);
      await _teardown(tester);
    });

    testWidgets('initiallyExpanded false starts collapsed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ThinkingSteps(steps: _doneSteps, initiallyExpanded: false)),
      );
      expect(find.text('Read the question'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('collapsible false has no chevron and no button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: _doneSteps,
            collapsible: false,
            initiallyExpanded: false,
          ),
        ),
      );
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.text('Read the question'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Thinking 0s')),
        isNot(isSemantics(isButton: true)),
      );
      await _teardown(tester);
      handle.dispose();
    });

    testWidgets('keyboard activation toggles the header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _doneSteps)));
      final Element element = tester.element(find.byType(ThinkingSteps));
      FocusScope.of(element).nextFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read the question'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read the question'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('new steps fade and grow in', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _doneSteps)));
      // Initial steps do not animate in.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: <ThinkingStep>[
              ..._doneSteps,
              ThinkingStep(title: 'Double check'),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      FadeTransition fade() => tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Double check'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final double opacity = fade().opacity.value;
      expect(opacity, greaterThan(0.0));
      expect(opacity, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fade().opacity.value, 1.0);
      await _teardown(tester);
    });

    testWidgets('active step shimmers; finished steps do not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _activeSteps)));
      expect(
        find.ancestor(
          of: find.text('Search the docs'),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Read the question'),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Completing the step stops the shimmer.
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            isThinking: false,
            collapseWhenDone: false,
            steps: <ThinkingStep>[
              ThinkingStep(
                title: 'Read the question',
                status: MicroStatus.success,
              ),
              ThinkingStep(
                title: 'Search the docs',
                status: MicroStatus.success,
              ),
              ThinkingStep(
                title: 'Write the answer',
                status: MicroStatus.success,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _teardown(tester);
    });

    testWidgets('semantics: header expanded state and step statuses', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _activeSteps)));
      expect(
        tester.getSemantics(find.text('Thinking 0s')),
        isSemantics(
          label: 'Thinking 0s',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Read the question, Done'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Search the docs, In progress'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Write the answer, Pending'),
        findsOneWidget,
      );

      // Semantic tap collapses; collapsed steps leave the semantics tree.
      final SemanticsNode node = tester.getSemantics(find.text('Thinking 0s'));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getSemantics(find.text('Thinking 0s')),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );
      expect(find.bySemanticsLabel('Read the question, Done'), findsNothing);
      await _teardown(tester);
      handle.dispose();
    });

    testWidgets('reduced motion: no shimmer, instant collapse, clock ticks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ThinkingSteps(steps: _activeSteps), reducedMotion: true),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Thinking 1s'), findsOneWidget);

      await tester.tap(find.text('Thinking 1s'));
      await tester.pump();
      expect(find.text('Read the question'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // New steps appear without an entrance animation.
      await tester.tap(find.text('Thinking 1s'));
      await tester.pump();
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: <ThinkingStep>[
              ..._activeSteps,
              ThinkingStep(title: 'Double check'),
            ],
          ),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Double check'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('enabled false renders statically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ThinkingSteps(steps: _activeSteps, enabled: false)),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _teardown(tester);
    });

    testWidgets('config changes mid-animation and disposal do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ThinkingSteps(steps: _activeSteps)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: _doneSteps,
            isThinking: false,
            duration: Duration(milliseconds: 600),
            curve: Curves.linear,
            markSize: 20,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        _wrap(
          const ThinkingSteps(
            steps: <ThinkingStep>[ThinkingStep(title: 'Only one')],
            collapsible: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Dispose mid-animation with the clock running.
      await _teardown(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL layout renders without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: const ThinkingSteps(steps: _activeSteps)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    testWidgets('shimmer sweeps in the reading direction', (
      WidgetTester tester,
    ) async {
      // Returns the highlight's horizontal position across the active
      // title, as a fraction of the title width, at a fixed point of the
      // sweep (30 percent of the period).
      Future<double> highlightAt(TextDirection direction) async {
        final GlobalKey boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: const SizedBox(
                      width: 400,
                      child: ThinkingSteps(
                        steps: <ThinkingStep>[
                          ThinkingStep(
                            title: 'WWWWWWWWWWWWWWWWWWWW',
                            status: MicroStatus.loading,
                          ),
                        ],
                        titleStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF000000),
                        ),
                        shimmerColor: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Shimmer period is 1600 ms; 480 ms is 30 percent of it.
        await tester.pump(const Duration(milliseconds: 480));
        final Offset origin = tester.getTopLeft(find.byKey(boundaryKey));
        final Rect title = tester
            .getRect(find.text('WWWWWWWWWWWWWWWWWWWW'))
            .shift(-origin);
        final Element element = tester.element(find.byKey(boundaryKey));
        final ByteData? captured = await tester.runAsync<ByteData?>(() async {
          final ui.Image image = await captureImage(element);
          final ByteData? data = await image.toByteData();
          image.dispose();
          return data;
        });
        final ByteData bytes = captured!;
        final int width = tester.getSize(find.byKey(boundaryKey)).width.round();
        final int y = title.center.dy.round();
        int brightestX = -1;
        int brightest = -1;
        for (int x = title.left.ceil(); x < title.right.floor(); x++) {
          final int offset = (y * width + x) * 4;
          final int red = bytes.getUint8(offset);
          if (red > brightest) {
            brightest = red;
            brightestX = x;
          }
        }
        await _teardown(tester);
        return (brightestX - title.left) / title.width;
      }

      final double ltr = await highlightAt(TextDirection.ltr);
      final double rtl = await highlightAt(TextDirection.rtl);
      // At 30 percent of the sweep the band is near the start edge: the
      // left in LTR and the right in RTL.
      expect(ltr, lessThan(0.4));
      expect(rtl, greaterThan(0.6));
      expect(ltr + rtl, closeTo(1.0, 0.1));
    });

    testWidgets('lays out under unbounded width, sized to its content', (
      WidgetTester tester,
    ) async {
      const List<ThinkingStep> steps = <ThinkingStep>[
        ThinkingStep(
          title: 'Read',
          detail: 'Short detail',
          status: MicroStatus.success,
        ),
        ThinkingStep(title: 'Search', status: MicroStatus.loading),
        ThinkingStep(title: 'Write'),
      ];
      final Map<String, Widget Function(Widget)> hosts =
          <String, Widget Function(Widget)>{
            'Row': (Widget child) => Row(children: <Widget>[child]),
            'UnconstrainedBox': (Widget child) =>
                UnconstrainedBox(child: child),
            'horizontal ListView': (Widget child) => ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[child],
            ),
          };
      for (final MapEntry<String, Widget Function(Widget)> host
          in hosts.entries) {
        Widget build({required bool thinking, bool collapsible = true}) {
          return MaterialApp(
            home: Scaffold(
              body: host.value(
                ThinkingSteps(
                  steps: steps,
                  isThinking: thinking,
                  collapsible: collapsible,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(build(thinking: true));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: host.key);
        expect(find.text('Short detail'), findsOneWidget, reason: host.key);
        final double width = tester.getSize(find.byType(ThinkingSteps)).width;
        expect(width, greaterThan(0.0), reason: host.key);
        // Content sized: far narrower than the 800 pixel test screen.
        expect(width, lessThan(400.0), reason: host.key);
        expect(
          tester.getSize(find.byType(ThinkingSteps)).width,
          greaterThanOrEqualTo(tester.getSize(find.text('Short detail')).width),
          reason: host.key,
        );

        // Collapse animation, mid-way and to the end.
        await tester.pumpWidget(build(thinking: false));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull, reason: host.key);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: host.key);
        expect(find.text('Short detail'), findsNothing, reason: host.key);

        // Expand again by tapping the header, then the non-collapsible form.
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Short detail'), findsOneWidget, reason: host.key);
        await tester.pumpWidget(build(thinking: true, collapsible: false));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: host.key);
        await _teardown(tester);
      }
    });

    testWidgets('bounded width: long text wraps within the available width', (
      WidgetTester tester,
    ) async {
      final String long = List<String>.filled(12, 'word').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ThinkingSteps(
                  title: long,
                  steps: <ThinkingStep>[
                    ThinkingStep(
                      title: long,
                      detail: long,
                      status: MicroStatus.success,
                    ),
                    const ThinkingStep(title: 'Next'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ThinkingSteps)).width, 300.0);
      // Header text and step text wrap instead of overflowing.
      expect(
        tester.getSize(find.textContaining('word').first).width,
        lessThanOrEqualTo(300.0),
      );
      for (final Element element in find.textContaining('word').evaluate()) {
        final RenderBox box = element.renderObject! as RenderBox;
        final Offset topLeft = box.localToGlobal(Offset.zero);
        final double screenLeft = tester
            .getTopLeft(find.byType(ThinkingSteps))
            .dx;
        expect(
          topLeft.dx + box.size.width,
          lessThanOrEqualTo(screenLeft + 300.01),
        );
      }
      await _teardown(tester);
    });
  });
}
