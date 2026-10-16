import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

enum _Outcome { success, error }

final ComponentEntry buttonStatesEntry = ComponentEntry(
  id: 'button-states',
  name: 'Button States',
  category: Categories.buttons,
  summary:
      'Animates a button between idle, loading, success and error content, '
      'driven by a controller that can run the whole request for you.',
  apis: const ['ButtonStates', 'ButtonStateController', 'MicroButtonState'],
  knobs: [
    SelectKnob<_Outcome>(
      id: 'outcome',
      label: 'Outcome',
      options: _Outcome.values,
      initial: _Outcome.success,
      labelOf: (_Outcome v) => v == _Outcome.success ? 'Success' : 'Error',
      help: 'Whether the simulated save request succeeds or throws.',
    ),
    const SliderKnob.duration(
      id: 'resetAfter',
      label: 'Reset after',
      min: 500,
      max: 5000,
      initial: 2000,
      divisions: 18,
      help: 'How long success or error stays before returning to idle.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Swap duration',
      min: 100,
      max: 800,
      initial: 300,
      divisions: 14,
    ),
  ],
  preview: (context, knobs) => _ButtonStatesDemo(knobs: knobs),
  thumbnail: (context) => const _ButtonStatesThumb(),
  code: (knobs) {
    final String? resetAfter = knobs.arg('resetAfter');
    final String run = resetAfter == null
        ? 'controller.run(api.saveSettings);'
        : 'controller.run(\n  api.saveSettings,\n  resetAfter: $resetAfter,\n);';
    final String widget = dartCall('ButtonStates', {
      'controller': 'controller',
      'duration': knobs.arg('duration'),
      'successBuilder': '(context) => const SavedLabel()',
      'errorBuilder': '(context) => const RetryLabel()',
      'child': dartCall('FilledButton', {
        'onPressed': 'save',
        'child': "const Text('Save changes')",
      }),
    });
    return 'final controller = ButtonStateController();\n\n'
        '// Loading, then success, or error when saveSettings throws.\n'
        'Future<void> save() => $run\n\n'
        '$widget';
  },
  notes: const [
    'Every state change is announced to screen readers as Loading, '
        'Success or Error.',
    'run returns to idle after resetAfter only if nothing else changed the '
        'state meanwhile, and it is safe to dispose the controller while '
        'the task is pending.',
    'Under reduced motion the content swaps instantly instead of fading '
        'and resizing.',
  ],
);

class _ButtonStatesDemo extends StatefulWidget {
  const _ButtonStatesDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ButtonStatesDemo> createState() => _ButtonStatesDemoState();
}

class _ButtonStatesDemoState extends State<_ButtonStatesDemo> {
  final ButtonStateController _controller = ButtonStateController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool fail = widget.knobs.pick<_Outcome>('outcome') == _Outcome.error;
    await _controller.run<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (fail) throw StateError('Network unavailable');
    }, resetAfter: widget.knobs.ms('resetAfter'));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoCardText(
              title: 'Workspace',
              body: 'Changes apply to everyone in Northwind Studio.',
            ),
            const Gap(16),
            const _SettingRow(label: 'Name', value: 'Northwind Studio'),
            Divider(height: 1, color: scheme.outlineVariant),
            const _SettingRow(label: 'Visibility', value: 'Private'),
            Divider(height: 1, color: scheme.outlineVariant),
            const _SettingRow(label: 'Region', value: 'Frankfurt'),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => Text(
                      _controller.state == MicroButtonState.success
                          ? 'Up to date'
                          : 'Unsaved',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ButtonStates(
                  controller: _controller,
                  duration: widget.knobs.ms('duration'),
                  loadingBuilder: (context) => _StatusPill(
                    color: scheme.primary,
                    leading: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    label: 'Saving',
                  ),
                  successBuilder: (context) => _StatusPill(
                    color: scheme.tertiary,
                    leading: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    label: 'Saved',
                  ),
                  errorBuilder: (context) => _StatusPill(
                    color: scheme.error,
                    leading: Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    label: 'Not saved',
                  ),
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A button sized pill shown in place of the button while busy or done.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.color,
    required this.leading,
    required this.label,
  });

  final Color color;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The three states side by side.
class _ButtonStatesThumb extends StatelessWidget {
  const _ButtonStatesThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Save changes')),
        const SizedBox(width: 10),
        _StatusPill(
          color: scheme.primary,
          leading: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: 0.7,
              color: scheme.primary,
            ),
          ),
          label: 'Saving',
        ),
        const SizedBox(width: 10),
        _StatusPill(
          color: scheme.tertiary,
          leading: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: scheme.tertiary,
          ),
          label: 'Saved',
        ),
      ],
    );
  }
}
