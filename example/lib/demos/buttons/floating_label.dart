import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

const Map<Curve, (String, String)> _curves = {
  Curves.easeOut: ('Ease out', 'Curves.easeOut'),
  Curves.easeInOut: ('Ease in out', 'Curves.easeInOut'),
  Curves.easeOutBack: ('Ease out back', 'Curves.easeOutBack'),
  Curves.fastOutSlowIn: ('Fast out slow in', 'Curves.fastOutSlowIn'),
  Curves.linear: ('Linear', 'Curves.linear'),
};

final ComponentEntry floatingLabelEntry = ComponentEntry(
  id: 'floating-label',
  name: 'Floating Label',
  category: Categories.buttons,
  summary:
      'A form field whose label rests inside like a hint and slides up out '
      'of the way when the field is focused or filled.',
  apis: const ['FloatingLabel'],
  knobs: [
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 100,
      max: 800,
      initial: 200,
      divisions: 14,
    ),
    SelectKnob<Curve>(
      id: 'curve',
      label: 'Curve',
      options: _curves.keys.toList(),
      initial: Curves.easeOut,
      labelOf: (Curve c) => _curves[c]!.$1,
      codeOf: (Curve c) => _curves[c]!.$2,
    ),
    const ToggleKnob(id: 'prefixIcon', label: 'Prefix icon', initial: true),
  ],
  preview: (context, knobs) => _FloatingLabelDemo(knobs: knobs),
  thumbnail: (context) => const _FloatingLabelThumb(),
  code: (knobs) => dartCall('FloatingLabel', {
    'label': "'Email'",
    'hint': "'name@company.com'",
    'prefixIcon': knobs.flag('prefixIcon')
        ? 'const Icon(Icons.mail_outline_rounded)'
        : null,
    'keyboardType': 'TextInputType.emailAddress',
    'duration': knobs.arg('duration'),
    'curve': knobs.arg('curve'),
    'autovalidateMode': 'AutovalidateMode.onUserInteraction',
    'validator':
        "(value) => (value == null || !value.contains('@'))\n"
        "    ? 'Enter a valid email address'\n"
        '    : null',
  }),
  notes: const [
    'The field is a real TextFormField: the validator takes part in '
        'Form.validate() and errors render in the decoration, where screen '
        'readers pick them up.',
    'The label color follows focus and validation errors, so state is not '
        'conveyed by position alone.',
    'Under reduced motion the label jumps between its resting and floated '
        'positions without animating.',
  ],
);

class _FloatingLabelDemo extends StatefulWidget {
  const _FloatingLabelDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_FloatingLabelDemo> createState() => _FloatingLabelDemoState();
}

class _FloatingLabelDemoState extends State<_FloatingLabelDemo> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _obscure = true;

  void _submit() {
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      demoToast(context, 'Account created', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final Duration duration = knobs.ms('duration');
    final Curve curve = knobs.pick('curve');
    final bool icons = knobs.flag('prefixIcon');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemoCardText(
                title: 'Create your account',
                body: 'Use your work email to join your team.',
              ),
              const Gap(20),
              FloatingLabel(
                label: 'Email',
                hint: 'name@company.com',
                prefixIcon: icons
                    ? const Icon(Icons.mail_outline_rounded, size: 20)
                    : null,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                duration: duration,
                curve: curve,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const Gap(14),
              FloatingLabel(
                label: 'Password',
                hint: 'At least 8 characters',
                prefixIcon: icons
                    ? const Icon(Icons.lock_outline_rounded, size: 20)
                    : null,
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
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                duration: duration,
                curve: curve,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onSubmitted: (_) => _submit(),
                validator: (String? value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              const Gap(20),
              FilledButton(onPressed: _submit, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

/// One field at rest and one with its label floated.
class _FloatingLabelThumb extends StatelessWidget {
  const _FloatingLabelThumb();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThumbField(label: 'Email', value: 'ana@northwind.io', floated: true),
          SizedBox(height: 14),
          _ThumbField(label: 'Password'),
        ],
      ),
    );
  }
}

class _ThumbField extends StatelessWidget {
  const _ThumbField({required this.label, this.value, this.floated = false});

  final String label;
  final String? value;
  final bool floated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: floated ? scheme.primary : scheme.outlineVariant,
          width: floated ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: floated
                ? theme.textTheme.labelSmall?.copyWith(color: scheme.primary)
                : theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          if (value != null) Text(value!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
