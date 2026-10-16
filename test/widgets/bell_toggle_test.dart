import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/bell_toggle.dart';
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

/// A parent that owns the toggle state.
class _Host extends StatefulWidget {
  const _Host({this.enableHaptics = true});

  final bool enableHaptics;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool value = false;
  final List<bool> changes = <bool>[];

  @override
  Widget build(BuildContext context) {
    return BellToggle(
      value: value,
      enableHaptics: widget.enableHaptics,
      onChanged: (bool next) => setState(() {
        changes.add(next);
        value = next;
      }),
    );
  }
}

/// The first bell painter, read dynamically since its type is private.
dynamic _bell(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BellToggle),
        matching: find.byType(CustomPaint),
      ),
    )
    .firstWhere(
      (CustomPaint p) => p.painter.runtimeType.toString() == '_BellPainter',
    )
    .painter;

void main() {
  group('BellToggle', () {
    testWidgets('renders the off label at rest with a 48 pixel target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      // The label is drawn in the off colors and, clipped, in the on colors.
      expect(find.text('Notify me'), findsWidgets);
      expect(find.text('Notifications on'), findsNothing);
      expect(
        tester.getSize(find.byType(BellToggle)).height,
        greaterThanOrEqualTo(48.0),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('turning on rings, swaps the label and widens the pill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      final double offWidth = tester.getSize(find.byType(BellToggle)).width;
      await tester.tap(find.byType(BellToggle));
      await tester.pump();
      expect(tester.state<_HostState>(find.byType(_Host)).changes, <bool>[
        true,
      ]);
      await tester.pump(const Duration(milliseconds: 150));
      // Both labels are on screen while they cross.
      expect(find.text('Notify me'), findsWidgets);
      expect(find.text('Notifications on'), findsWidgets);
      final double midWidth = tester.getSize(find.byType(BellToggle)).width;
      expect(_bell(tester).ring.value, greaterThan(0.0));

      await tester.pumpAndSettle();
      final double onWidth = tester.getSize(find.byType(BellToggle)).width;
      expect(onWidth, greaterThan(offWidth));
      expect(midWidth, greaterThan(offWidth));
      expect(midWidth, lessThan(onWidth));
      expect(find.text('Notify me'), findsNothing);
      expect(find.text('Notifications on'), findsWidgets);
    });

    testWidgets('the wobble stays within 18 degrees, decays, then stops', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(BellToggle));
      await tester.pump();

      const double limit = 18.0 * math.pi / 180.0;
      double early = 0.0;
      double late = 0.0;
      for (int ms = 0; ms < 1000; ms += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final double angle = (_bell(tester).bellAngle as double).abs();
        expect(angle, lessThanOrEqualTo(limit));
        if (ms < 250) early = math.max(early, angle);
        if (ms >= 600) late = math.max(late, angle);
      }
      expect(early, greaterThan(limit * 0.4));
      expect(late, lessThan(early * 0.25));

      await tester.pump(const Duration(milliseconds: 50));
      expect(_bell(tester).bellAngle, 0.0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('turning off plays a short shrink and restores the label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(BellToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BellToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_bell(tester).shrink.value, greaterThan(0.0));
      expect(_bell(tester).ring.value, 0.0);
      await tester.pumpAndSettle();
      expect(_bell(tester).shrink.value, 0.0);
      expect(_bell(tester).fill.value, 0.0);
      expect(find.text('Notify me'), findsWidgets);
      expect(find.text('Notifications on'), findsNothing);
    });

    testWidgets('semantics: toggle button labeled with the current state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const _Host()));
      expect(
        tester.getSemantics(find.byType(BellToggle)),
        matchesSemantics(
          label: 'Notify me',
          isButton: true,
          hasToggledState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Notify me'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(BellToggle)),
        matchesSemantics(
          label: 'Notifications on',
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

    testWidgets('semanticLabel overrides the visible label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          BellToggle(
            value: true,
            semanticLabel: 'Release alerts',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Release alerts'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keyboard: Enter and Space toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.state<_HostState>(find.byType(_Host)).changes, <bool>[
        true,
        false,
      ]);
    });

    testWidgets('disabled: dimmed and ignores input', (
      WidgetTester tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(
          BellToggle(
            value: false,
            enabled: false,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(BellToggle), warnIfMissed: false);
      await tester.pump();
      expect(called, isFalse);
      final Opacity opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(BellToggle),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.5);

      await tester.pumpWidget(
        _wrap(const BellToggle(value: false, onChanged: null)),
      );
      await tester.tap(find.byType(BellToggle), warnIfMissed: false);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: instant state, no ring, no frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host(), reducedMotion: true));
      await tester.tap(find.byType(BellToggle));
      await tester.pump();
      expect(_bell(tester).fill.value, 1.0);
      expect(_bell(tester).ring.value, 0.0);
      expect(find.text('Notify me'), findsNothing);
      expect(find.text('Notifications on'), findsWidgets);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('haptics: light on, selection click off', (
      WidgetTester tester,
    ) async {
      final List<Object?> calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(BellToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BellToggle));
      await tester.pumpAndSettle();
      expect(calls, <Object?>[
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.selectionClick',
      ]);

      calls.clear();
      await tester.pumpWidget(_wrap(const _Host(enableHaptics: false)));
      await tester.tap(find.byType(BellToggle));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('config changes and disposing mid-ring do not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.tap(find.byType(BellToggle));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(
        _wrap(
          Directionality(
            textDirection: TextDirection.rtl,
            child: BellToggle(
              value: true,
              height: 32,
              duration: const Duration(milliseconds: 200),
              ringDuration: const Duration(milliseconds: 400),
              curve: Curves.linear,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
