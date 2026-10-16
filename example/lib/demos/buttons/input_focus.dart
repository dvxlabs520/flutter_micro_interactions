import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry inputFocusEntry = ComponentEntry(
  id: 'input-focus',
  name: 'Input Focus',
  category: Categories.buttons,
  summary:
      'Gently scales and lifts a text field while it is focused, so the '
      'field being edited stands out in a dense form.',
  apis: const ['InputFocus'],
  knobs: [
    const SliderKnob(
      id: 'scale',
      label: 'Scale',
      min: 1,
      max: 1.08,
      initial: 1.02,
      divisions: 8,
    ),
    const SliderKnob(
      id: 'elevation',
      label: 'Elevation',
      min: 0,
      max: 16,
      initial: 4,
      divisions: 16,
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 100,
      max: 600,
      initial: 200,
      divisions: 10,
    ),
  ],
  preview: (context, knobs) => _InputFocusDemo(knobs: knobs),
  thumbnail: (context) => const _InputFocusThumb(),
  code: (knobs) => dartCall('InputFocus', {
    'scale': knobs.arg('scale'),
    'elevation': knobs.arg('elevation'),
    'duration': knobs.arg('duration'),
    'borderRadius': 'BorderRadius.circular(10)',
    'child': dartCall('TextField', {
      'keyboardType': 'TextInputType.emailAddress',
      'decoration': "const InputDecoration(labelText: 'Email')",
    }),
  }),
  notes: const [
    'The wrapper never takes focus and is skipped by keyboard traversal; it '
        'only listens to focus changes of the field inside, so Tab moves '
        'between fields as usual.',
    'At rest the child renders unchanged, with zero elevation and a '
        'transparent backing material.',
    'Under reduced motion the emphasis switches instantly instead of '
        'animating.',
  ],
);

class _InputFocusDemo extends StatefulWidget {
  const _InputFocusDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_InputFocusDemo> createState() => _InputFocusDemoState();
}

class _InputFocusDemoState extends State<_InputFocusDemo> {
  bool _obscure = true;

  Widget _focusable(Widget child) {
    final Knobs knobs = widget.knobs;
    return InputFocus(
      scale: knobs.number('scale'),
      elevation: knobs.number('elevation'),
      duration: knobs.ms('duration'),
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoCardText(
              title: 'Welcome back',
              body: 'Sign in to continue to your workspace.',
            ),
            const Gap(20),
            _focusable(
              const TextField(
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@company.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
              ),
            ),
            const Gap(14),
            _focusable(
              TextField(
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => demoToast(context, 'Reset link sent'),
                child: const Text('Forgot password?'),
              ),
            ),
            const Gap(4),
            FilledButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                demoToast(context, 'Signed in');
              },
              child: const Text('Sign in'),
            ),
            const Gap(12),
            Text(
              'Click a field or press Tab to move focus',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two fields, the second one lifted as if focused.
class _InputFocusThumb extends StatelessWidget {
  const _InputFocusThumb();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FakeField(
            icon: Icons.mail_outline_rounded,
            text: 'ana@northwind.io',
          ),
          SizedBox(height: 14),
          _FakeField(
            icon: Icons.lock_outline_rounded,
            text: 'Password',
            focused: true,
          ),
        ],
      ),
    );
  }
}

class _FakeField extends StatelessWidget {
  const _FakeField({
    required this.icon,
    required this.text,
    this.focused = false,
  });

  final IconData icon;
  final String text;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Transform.scale(
      scale: focused ? 1.04 : 1,
      child: Material(
        color: Colors.transparent,
        elevation: focused ? 6 : 0,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? scheme.primary : scheme.outlineVariant,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: focused ? scheme.onSurfaceVariant : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
