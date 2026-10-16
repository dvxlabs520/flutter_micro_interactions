import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/pulse_heart.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  Widget body = Center(child: child);
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(home: Scaffold(body: body));
}

/// A parent that owns the like state, like a real app would.
class _Host extends StatefulWidget {
  const _Host({
    this.enableHaptics = true,
    this.duration = const Duration(milliseconds: 700),
  });

  final bool enableHaptics;
  final Duration duration;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool liked = false;
  int? count = 9;
  final List<bool> changes = <bool>[];

  @override
  Widget build(BuildContext context) {
    return PulseHeart(
      liked: liked,
      count: count,
      duration: widget.duration,
      enableHaptics: widget.enableHaptics,
      onChanged: (bool value) => setState(() {
        changes.add(value);
        liked = value;
        if (count != null) count = count! + (value ? 1 : -1);
      }),
    );
  }
}

/// The painter of the heart, read dynamically since its type is private.
dynamic _painter(WidgetTester tester) {
  final CustomPaint paint = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(PulseHeart),
          matching: find.byType(CustomPaint),
        ),
      )
      .firstWhere(
        (CustomPaint p) =>
            p.painter.runtimeType.toString() == '_PulseHeartPainter',
      );
  return paint.painter;
}

String _phase(WidgetTester tester) =>
    (_painter(tester).phase as Object).toString().split('.').last;

List<MethodCall> _mockHaptics(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  group('PulseHeart', () {
    testWidgets('renders an idle outline heart with a 48 pixel target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PulseHeart(liked: false, onChanged: (_) {}, size: 16)),
      );
      final Size size = tester.getSize(find.byType(PulseHeart));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(_phase(tester), 'idle');
      expect(_painter(tester).liked, isFalse);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('tap likes: the heart animates then settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pump();
      final _HostState host = tester.state<_HostState>(find.byType(_Host));
      expect(host.changes, <bool>[true]);
      expect(_phase(tester), 'liking');

      await tester.pump(const Duration(milliseconds: 100));
      final double early = _painter(tester).progress.value as double;
      await tester.pump(const Duration(milliseconds: 300));
      final double later = _painter(tester).progress.value as double;
      expect(early, greaterThan(0.0));
      expect(later, greaterThan(early));

      await tester.pump(const Duration(milliseconds: 400));
      expect(_phase(tester), 'idle');
      expect(_painter(tester).liked, isTrue);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('unlike plays the short animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PulseHeart));
      await tester.pump();
      expect(_phase(tester), 'unliking');
      // The unlike animation is a fraction of the like duration.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_phase(tester), 'idle');
      expect(_painter(tester).liked, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('count ticks over with the pulse when liking', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      expect(find.text('9'), findsOneWidget);
      await tester.tap(find.byType(PulseHeart));
      await tester.pump();
      // The new number waits for the heart to pulse back out.
      expect(find.text('10'), findsNothing);
      expect(find.text('9'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      // Rolling: the old value leaves while the new one enters.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
      expect(find.text('9'), findsNothing);
    });

    testWidgets('count rolls down right away when unliking', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PulseHeart));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('showCount false and null count render no number', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PulseHeart(
            liked: true,
            count: 3,
            showCount: false,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('3'), findsNothing);
      await tester.pumpWidget(
        _wrap(PulseHeart(liked: true, onChanged: (_) {})),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('exposes a toggle button with label and count value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(PulseHeart(liked: true, count: 12, onChanged: (_) {})),
      );
      expect(
        tester.getSemantics(find.byType(PulseHeart)),
        matchesSemantics(
          label: 'Like',
          value: '12',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantic tap toggles', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Host()));
      tester.semantics.tap(find.semantics.byLabel('Like'));
      await tester.pumpAndSettle();
      expect(tester.state<_HostState>(find.byType(_Host)).changes, <bool>[
        true,
      ]);
      handle.dispose();
    });

    testWidgets('keyboard: Enter and Space toggle, focus shows a ring', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      Finder ring() => find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            ((w.decoration as ShapeDecoration).shape as StadiumBorder)
                    .side
                    .width ==
                2.0,
      );
      expect(ring(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.state<_HostState>(find.byType(_Host)).changes, <bool>[
        true,
        false,
      ]);
    });

    testWidgets('disabled: dimmed, ignores taps, semantics disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      bool called = false;
      await tester.pumpWidget(
        _wrap(
          PulseHeart(
            liked: false,
            enabled: false,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(PulseHeart), warnIfMissed: false);
      await tester.pump();
      expect(called, isFalse);
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PulseHeart),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
      expect(
        tester.getSemantics(find.byType(PulseHeart)),
        matchesSemantics(
          label: 'Like',
          isButton: true,
          hasToggledState: true,
          hasEnabledState: true,
        ),
      );

      // A null onChanged disables too.
      await tester.pumpWidget(
        _wrap(const PulseHeart(liked: false, onChanged: null)),
      );
      await tester.tap(find.byType(PulseHeart), warnIfMissed: false);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      handle.dispose();
    });

    testWidgets('reduced motion: instant change, no frames scheduled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(), reducedMotion: true));
      await tester.tap(find.byType(PulseHeart));
      await tester.pump();
      expect(_phase(tester), 'idle');
      expect(_painter(tester).liked, isTrue);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('9'), findsNothing);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('haptics play on tap unless disabled', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = _mockHaptics(tester);
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pumpAndSettle();
      expect(calls.map((MethodCall c) => c.arguments), <Object?>[
        'HapticFeedbackType.lightImpact',
      ]);

      calls.clear();
      await tester.pumpWidget(_wrap(const _Host(enableHaptics: false)));
      await tester.tap(find.byType(PulseHeart));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('config changes and toggles mid-animation do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pump(const Duration(milliseconds: 120));
      // Unlike in the middle of the like animation.
      await tester.tap(find.byType(PulseHeart));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_phase(tester), 'unliking');
      await tester.pumpWidget(
        _wrap(const _Host(duration: Duration(milliseconds: 300))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(PulseHeart));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
