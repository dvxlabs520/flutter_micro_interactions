import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

enum _Variant { button, toAction, animation }

final ComponentEntry shakeEntry = ComponentEntry(
  id: 'shake',
  name: 'Shake',
  category: Categories.buttons,
  summary:
      'A damped horizontal shake that says no: on a button pressed while a '
      'form is invalid, on demand through a controller, or as a quick drag '
      'gesture that triggers an action.',
  apis: const [
    'ShakeButton',
    'ShakeToAction',
    'ShakeAnimation',
    'ShakeController',
  ],
  tags: const [ComponentTag.gesture],
  knobs: [
    SelectKnob<_Variant>(
      id: 'variant',
      label: 'Variant',
      options: _Variant.values,
      initial: _Variant.button,
      labelOf: (_Variant v) => switch (v) {
        _Variant.button => 'ShakeButton',
        _Variant.toAction => 'ShakeToAction',
        _Variant.animation => 'ShakeAnimation',
      },
    ),
    const SliderKnob(
      id: 'intensity',
      label: 'Intensity',
      min: 2,
      max: 24,
      initial: 8,
      divisions: 11,
      help: 'Horizontal travel in logical pixels.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 1000,
      initial: 400,
      divisions: 16,
    ),
  ],
  preview: (context, knobs) => _ShakeDemo(knobs: knobs),
  thumbnail: (context) => const _ShakeThumb(),
  code: (knobs) {
    final String? intensity = knobs.arg('intensity');
    final String? duration = knobs.arg('duration');
    switch (knobs.pick<_Variant>('variant')) {
      case _Variant.button:
        return dartCall('ShakeButton', {
          'isValid': 'termsAccepted',
          'intensity': intensity,
          'duration': duration,
          'onPressed': 'createAccount',
          'onInvalidPress': 'showTermsHint',
          'builder':
              '(context, handlePressed) => ${dartCall('FilledButton', {'onPressed': 'handlePressed', 'child': "const Text('Create account')"})}',
        });
      case _Variant.toAction:
        return dartCall('ShakeToAction', {
          'intensity': intensity,
          'duration': duration,
          'onShake': 'undoLastEdit',
          'child': 'const ShoppingListCard()',
        });
      case _Variant.animation:
        return 'final shake = ShakeController();\n\n'
            '${dartCall('ShakeAnimation', {'controller': 'shake', 'intensity': intensity, 'duration': duration, 'child': 'const VerificationCodeField()'})}\n\n'
            '// When the code is rejected:\n'
            'shake.shake();';
    }
  },
  notes: const [
    'ShakeToAction reacts to a rapid back and forth horizontal drag, not to '
        'device motion sensors. A ShakeController can trigger it as well.',
    'ShakeButton exposes the invalid state to screen readers as disabled '
        'and plays an error haptic on an invalid press; ShakeToAction plays '
        'a heavy impact when a shake is detected.',
    'Under reduced motion the translation is skipped, but callbacks and '
        'haptics still fire.',
  ],
);

class _ShakeDemo extends StatelessWidget {
  const _ShakeDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final double intensity = knobs.number('intensity');
    final Duration duration = knobs.ms('duration');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: switch (knobs.pick<_Variant>('variant')) {
        _Variant.button => _SignUpDemo(
          intensity: intensity,
          duration: duration,
        ),
        _Variant.toAction => _UndoDemo(
          intensity: intensity,
          duration: duration,
        ),
        _Variant.animation => _CodeDemo(
          intensity: intensity,
          duration: duration,
        ),
      },
    );
  }
}

class _SignUpDemo extends StatefulWidget {
  const _SignUpDemo({required this.intensity, required this.duration});

  final double intensity;
  final Duration duration;

  @override
  State<_SignUpDemo> createState() => _SignUpDemoState();
}

class _SignUpDemoState extends State<_SignUpDemo> {
  bool _accepted = false;
  bool _showHint = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DemoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DemoCardText(
            title: 'Create your account',
            body: 'Start a free 14 day trial. No card needed.',
          ),
          const Gap(16),
          const _ReadOnlyField(
            icon: Icons.mail_outline,
            text: 'jordan@hey.com',
          ),
          const Gap(12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _accepted = !_accepted;
              if (_accepted) _showHint = false;
            }),
            child: Row(
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (bool? value) => setState(() {
                    _accepted = value ?? false;
                    if (_accepted) _showHint = false;
                  }),
                ),
                Expanded(
                  child: Text(
                    'I agree to the Terms and Privacy Policy',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showHint
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      'Accept the terms to continue',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const Gap(12),
          ShakeButton(
            isValid: _accepted,
            intensity: widget.intensity,
            duration: widget.duration,
            onPressed: () =>
                demoToast(context, 'Account created', type: ToastType.success),
            onInvalidPress: () => setState(() => _showHint = true),
            builder: (context, handlePressed) => FilledButton(
              onPressed: handlePressed,
              child: const Text('Create account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _groceries = [
  'Oat milk',
  'Sourdough loaf',
  'Basil',
  'Lemons',
];

class _UndoDemo extends StatefulWidget {
  const _UndoDemo({required this.intensity, required this.duration});

  final double intensity;
  final Duration duration;

  @override
  State<_UndoDemo> createState() => _UndoDemoState();
}

class _UndoDemoState extends State<_UndoDemo> {
  final ShakeController _shake = ShakeController();
  int _count = _groceries.length;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _undo() {
    if (_count == 0) return;
    setState(() => _count--);
    demoToast(context, 'Removed ${_groceries[_count]}');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShakeToAction(
          controller: _shake,
          intensity: widget.intensity,
          duration: widget.duration,
          onShake: _undo,
          child: DemoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.checklist_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Groceries',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$_count items',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                if (_count == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Nothing left to undo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final String item in _groceries.take(_count))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(item, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Gap(14),
        const DemoCaption('Drag the card left and right quickly to undo'),
        const Gap(12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _count == 0 ? null : _shake.shake,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Shake with controller'),
            ),
            TextButton(
              onPressed: _count == _groceries.length
                  ? null
                  : () => setState(() => _count = _groceries.length),
              child: const Text('Restore'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodeDemo extends StatefulWidget {
  const _CodeDemo({required this.intensity, required this.duration});

  final double intensity;
  final Duration duration;

  @override
  State<_CodeDemo> createState() => _CodeDemoState();
}

class _CodeDemoState extends State<_CodeDemo> {
  final ShakeController _shake = ShakeController();
  bool _rejected = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _verify() {
    setState(() => _rejected = true);
    _shake.shake();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DemoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DemoCardText(
            icon: Icons.shield_outlined,
            title: 'Check your email',
            body: 'Enter the 4 digit code we sent to jordan@hey.com',
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          const Gap(18),
          ShakeAnimation(
            controller: _shake,
            intensity: widget.intensity,
            duration: widget.duration,
            child: _CodeBoxes(
              digits: '4821',
              color: _rejected ? scheme.error : scheme.outlineVariant,
            ),
          ),
          const Gap(10),
          SizedBox(
            height: 18,
            child: _rejected
                ? Text(
                    'That code is not valid. Try again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  )
                : null,
          ),
          const Gap(10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _verify,
              child: const Text('Verify'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.digits, required this.color});

  final String digits;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (int i, String digit) in digits.split('').indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(digit, style: theme.textTheme.titleLarge),
          ),
        ],
      ],
    );
  }
}

/// The code boxes, shaking in a loop with a red outline.
class _ShakeThumb extends StatefulWidget {
  const _ShakeThumb();

  @override
  State<_ShakeThumb> createState() => _ShakeThumbState();
}

class _ShakeThumbState extends State<_ShakeThumb> {
  final ShakeController _shake = ShakeController();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1400),
      (_) => _shake.shake(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShakeAnimation(
      controller: _shake,
      child: _CodeBoxes(
        digits: '4821',
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
