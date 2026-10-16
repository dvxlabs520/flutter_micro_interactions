import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

/// The code the demo accepts, cut to the current length.
const String _demoCode = '24681357';

final ComponentEntry codeSlotsEntry = ComponentEntry(
  id: 'code-slots',
  name: 'Code Slots',
  category: Categories.buttons,
  summary:
      'A one-time code input with one slot per character. Each digit springs '
      'into its slot and a wrong code shakes the row. Works with paste and '
      'SMS autofill.',
  apis: const ['CodeSlots'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob(
      id: 'length',
      label: 'Length',
      min: 4,
      max: 8,
      initial: 6,
      divisions: 4,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'gap',
      label: 'Gap',
      min: 4,
      max: 16,
      initial: 10,
      divisions: 6,
    ),
    const SliderKnob(
      id: 'borderRadius',
      label: 'Corner radius',
      min: 4,
      max: 20,
      initial: 12,
      divisions: 8,
    ),
    const ToggleKnob(
      id: 'obscure',
      label: 'Obscure',
      initial: false,
      help: 'Shows dots instead of the characters.',
    ),
    const ToggleKnob(
      id: 'numeric',
      label: 'Digits only',
      initial: true,
      help: 'Off accepts letters too and asks for the text keyboard.',
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _CodeSlotsDemo(knobs: knobs),
  thumbnail: (context) => const _CodeThumb(),
  code: (knobs) => dartCall('CodeSlots', {
    'length': knobs.arg('length'),
    'gap': knobs.arg('gap'),
    'borderRadius': knobs.arg('borderRadius'),
    'obscure': knobs.arg('obscure'),
    'numeric': knobs.arg('numeric'),
    'activeColor': knobs.arg('activeColor'),
    'hasError': '_wrongCode',
    'onChanged': '(_) => setState(() => _wrongCode = false)',
    'onCompleted':
        '(String code) async {\n'
        '  final bool ok = await api.verify(code);\n'
        '  setState(() => _wrongCode = !ok);\n'
        '}',
  }),
  notes: const [
    'One invisible text field covers the row, so the platform keyboard, '
        'hardware keys, paste of a full code and SMS autofill all work. '
        'Pasted text is filtered, so 123-456 fills six slots.',
    'Exposed as a single text field labelled "Verification code" (or '
        'semanticLabel), whose value is obscured when obscure is true.',
    'Under reduced motion characters appear instantly, the caret does not '
        'blink and the error state shows without shaking.',
  ],
);

String _int(double v) => '${v.round()}';

enum _Status { typing, checking, wrong, verified }

class _CodeSlotsDemo extends StatefulWidget {
  const _CodeSlotsDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CodeSlotsDemo> createState() => _CodeSlotsDemoState();
}

class _CodeSlotsDemoState extends State<_CodeSlotsDemo> {
  final TextEditingController _controller = TextEditingController();
  _Status _status = _Status.typing;
  Timer? _timer;

  int get _length => widget.knobs.number('length').round();

  String get _expected => _demoCode.substring(0, _length);

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _verify(String code) {
    _timer?.cancel();
    setState(() => _status = _Status.checking);
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _status = code == _expected ? _Status.verified : _Status.wrong;
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    _controller.clear();
    setState(() => _status = _Status.typing);
  }

  void _fill() {
    _controller.text = _expected;
    _verify(_expected);
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int length = _length;
    final bool verified = _status == _Status.verified;

    final (String message, Color color) = switch (_status) {
      _Status.typing => (
        "Didn't get it? Resend in 0:24",
        scheme.onSurfaceVariant,
      ),
      _Status.checking => ('Checking the code', scheme.onSurfaceVariant),
      _Status.wrong => ('That code is not right. Try again.', scheme.error),
      _Status.verified => ('Email verified', scheme.tertiary),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: IconBadge(
                key: ValueKey(verified),
                icon: verified
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                size: 44,
                color: verified ? scheme.tertiary : knobs.color('activeColor'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Check your email',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the $length digit code we sent to ana@studio.dev',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            CodeSlots(
              key: ValueKey('code-$length'),
              length: length,
              controller: _controller,
              gap: knobs.number('gap'),
              borderRadius: knobs.number('borderRadius'),
              obscure: knobs.flag('obscure'),
              numeric: knobs.flag('numeric'),
              activeColor: knobs.color('activeColor'),
              enabled: !verified,
              hasError: _status == _Status.wrong,
              onChanged: (_) {
                if (_status == _Status.wrong) {
                  setState(() => _status = _Status.typing);
                }
              },
              onCompleted: _verify,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                message,
                key: ValueKey(_status),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (verified)
                  OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Start over'),
                  )
                else
                  TextButton(
                    onPressed: _status == _Status.checking ? null : _fill,
                    child: Text('Use demo code $_expected'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeThumb extends StatefulWidget {
  const _CodeThumb();

  @override
  State<_CodeThumb> createState() => _CodeThumbState();
}

class _CodeThumbState extends State<_CodeThumb> {
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      _tick = (_tick + 1) % 10;
      // Types the code one digit at a time, holds, then clears.
      _controller.text = _demoCode.substring(0, _tick.clamp(0, 6));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CodeSlots(
      controller: _controller,
      slotWidth: 44,
      slotHeight: 52,
      gap: 8,
    );
  }
}
