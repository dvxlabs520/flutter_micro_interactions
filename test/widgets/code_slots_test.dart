import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/src/code_slots.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The painter that draws the slots.
dynamic _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(CodeSlots),
        matching: find.byType(CustomPaint),
      ),
    )
    .firstWhere(
      (CustomPaint p) => p.painter.runtimeType.toString() == '_SlotsPainter',
    )
    .painter;

List<String?> _chars(WidgetTester tester) =>
    (_painter(tester).field.chars as List<String?>).toList();

String _shown(WidgetTester tester) => _chars(tester).whereType<String>().join();

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  group('CodeSlots', () {
    testWidgets('renders six empty slots by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      expect(_chars(tester), hasLength(6));
      expect(_shown(tester), isEmpty);
      // The row is 6 * 48 + 5 * 10 wide by default.
      expect(tester.getSize(find.byType(CodeSlots)), const Size(338, 56));
    });

    testWidgets('typing fills slots and calls onCompleted once', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      final List<String> completed = <String>[];
      await tester.pumpWidget(
        _wrap(
          CodeSlots(
            length: 4,
            onChanged: changes.add,
            onCompleted: completed.add,
          ),
        ),
      );
      await tester.tap(find.byType(CodeSlots));
      await tester.pump();
      for (final String text in <String>['1', '12', '123']) {
        await tester.enterText(find.byType(EditableText), text);
        await tester.pump();
      }
      expect(_shown(tester), '123');
      expect(completed, isEmpty);

      await tester.enterText(find.byType(EditableText), '1234');
      await tester.pump();
      expect(_shown(tester), '1234');
      expect(completed, <String>['1234']);
      expect(changes, <String>['1', '12', '123', '1234']);

      // Typing past the end is ignored and does not complete again.
      await tester.enterText(find.byType(EditableText), '12345');
      await tester.pump();
      expect(_shown(tester), '1234');
      expect(completed, <String>['1234']);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('a digit springs in from above and settles', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: controller)));
      controller.text = '7';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final List<double> age = _painter(tester).field.enterAge as List<double>;
      expect(age[0].isFinite, isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(
        (_painter(tester).field.enterAge as List<double>)[0],
        double.infinity,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('paste of a full code fills every slot', (
      WidgetTester tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': '12-34 56'};
          }
          if (call.method == 'Clipboard.hasStrings') {
            return <String, dynamic>{'value': true};
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
      final List<String> completed = <String>[];
      await tester.pumpWidget(_wrap(CodeSlots(onCompleted: completed.add)));
      await tester.tap(find.byType(CodeSlots));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_shown(tester), '123456');
      expect(completed, <String>['123456']);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('a pasted full code replaces a partial one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      await tester.tap(find.byType(CodeSlots));
      await tester.enterText(find.byType(EditableText), '12');
      await tester.pump();
      // The IME appends the pasted text at the cursor (the end).
      await tester.enterText(find.byType(EditableText), '12987654');
      await tester.pump();
      expect(_shown(tester), '987654');
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('backspace pops the last digit out', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: controller)));
      await tester.tap(find.byType(CodeSlots));
      await tester.enterText(find.byType(EditableText), '123');
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, '12');
      expect(_shown(tester), '12');
      final dynamic field = _painter(tester).field;
      expect((field.exitChars as List<String?>)[2], '3');
      await tester.pump(const Duration(milliseconds: 300));
      expect((_painter(tester).field.exitChars as List<String?>)[2], isNull);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('non digits are filtered when numeric', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      await tester.tap(find.byType(CodeSlots));
      await tester.enterText(find.byType(EditableText), '1a2-b3');
      await tester.pump();
      expect(_shown(tester), '123');
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('letters are accepted when numeric is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots(numeric: false)));
      await tester.tap(find.byType(CodeSlots));
      await tester.enterText(find.byType(EditableText), 'a1-B');
      await tester.pump();
      expect(_shown(tester), 'a1B');
      expect(_editable(tester).keyboardType, TextInputType.text);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('requests the numeric keyboard and one-time-code autofill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      final EditableText editable = _editable(tester);
      expect(editable.keyboardType, TextInputType.number);
      expect(editable.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(editable.autocorrect, isFalse);
      expect(editable.obscureText, isFalse);
    });

    testWidgets('controller changes show without calling onChanged', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final List<String> changes = <String>[];
      await tester.pumpWidget(
        _wrap(CodeSlots(controller: controller, onChanged: changes.add)),
      );
      controller.text = '42';
      await tester.pumpAndSettle();
      expect(_shown(tester), '42');
      expect(changes, isEmpty);

      // Swapping the controller shows the new code.
      final TextEditingController other = TextEditingController(text: '9');
      addTearDown(other.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: other)));
      await tester.pumpAndSettle();
      expect(_shown(tester), '9');
      // The old controller is no longer listened to.
      controller.text = '111';
      await tester.pump();
      expect(_shown(tester), '9');
    });

    testWidgets('the cursor always stays at the end', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: controller)));
      controller.text = '123';
      controller.selection = const TextSelection.collapsed(offset: 0);
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('hasError shakes once, then rests with error borders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      final Color normal = _painter(tester).activeColor as Color;
      await tester.pumpWidget(_wrap(const CodeSlots(hasError: true)));
      final Color error = _painter(tester).activeColor as Color;
      expect(error, isNot(normal));
      expect(
        error,
        Theme.of(tester.element(find.byType(CodeSlots))).colorScheme.error,
      );

      double maxShake = 0;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final double offset = _painter(tester).field.shakeOffset as double;
        maxShake = offset.abs() > maxShake ? offset.abs() : maxShake;
      }
      expect(maxShake, greaterThan(1.0));
      await tester.pumpAndSettle();
      expect(_painter(tester).field.shakeOffset, 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('exposes a single labelled text field to semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TextEditingController controller = TextEditingController(
        text: '12',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: controller)));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Verification code',
          value: '12',
          isTextField: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('obscure hides the code from semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TextEditingController controller = TextEditingController(
        text: '12',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(CodeSlots(controller: controller, obscure: true)),
      );
      await tester.pumpAndSettle();
      expect(_editable(tester).obscureText, isTrue);
      final SemanticsNode node = tester.getSemantics(find.byType(EditableText));
      expect(node.value, isNot(contains('12')));
      handle.dispose();
    });

    testWidgets('enabled false cannot be focused and ignores input', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _wrap(CodeSlots(enabled: false, focusNode: focusNode)),
      );
      await tester.tap(find.byType(CodeSlots), warnIfMissed: false);
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
      expect(_editable(tester).readOnly, isTrue);
      expect(
        find.ancestor(
          of: find.byType(EditableText),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('disabling while focused drops focus', (
      WidgetTester tester,
    ) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(focusNode: focusNode)));
      await tester.tap(find.byType(CodeSlots));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      await tester.pumpWidget(
        _wrap(CodeSlots(focusNode: focusNode, enabled: false)),
      );
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('focus brings in the accent border and a blinking caret', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      expect(_painter(tester).field.highlightAlpha, 0.0);
      await tester.tap(find.byType(CodeSlots));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_painter(tester).field.highlightAlpha, 1.0);
      expect(_painter(tester).showCaret, isTrue);
      final Set<double> opacities = <double>{};
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        opacities.add(_painter(tester).field.caretOpacity as double);
      }
      expect(opacities, containsAll(<double>[0.0, 1.0]));
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('the accent border glides to the next slot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots()));
      await tester.tap(find.byType(CodeSlots));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(EditableText), '1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final double mid = _painter(tester).field.highlight as double;
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_painter(tester).field.highlight, 1.0);
      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('reduced motion: instant digits, no shake, no frames', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(CodeSlots(controller: controller), reducedMotion: true),
      );
      await tester.tap(find.byType(CodeSlots));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '12');
      await tester.pump();
      expect(_shown(tester), '12');
      expect(
        (_painter(tester).field.enterAge as List<double>).every(
          (double a) => a == double.infinity,
        ),
        isTrue,
      );
      expect(_painter(tester).field.highlight, 2.0);
      expect(_painter(tester).field.caretOpacity, 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(
        _wrap(
          CodeSlots(controller: controller, hasError: true),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(_painter(tester).field.shakeOffset, 0.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('changing length mid animation does not throw', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(CodeSlots(controller: controller)));
      controller.text = '1234';
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(
        _wrap(CodeSlots(controller: controller, length: 4, hasError: true)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_chars(tester), hasLength(4));
      expect(_shown(tester), '1234');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid animation does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CodeSlots(autofocus: true)));
      await tester.enterText(find.byType(EditableText), '123');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
