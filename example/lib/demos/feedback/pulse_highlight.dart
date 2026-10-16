import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry pulseHighlightEntry = ComponentEntry(
  id: 'pulse-highlight',
  name: 'Pulse Highlight',
  category: Categories.feedback,
  summary:
      'Soft rings that pulse out of a button to point at something new. '
      'Good for onboarding hints and feature announcements.',
  apis: const ['PulseHighlight', 'PulseHighlightController'],
  knobs: [
    SelectKnob<BoxShape>(
      id: 'shape',
      label: 'Shape',
      options: const [BoxShape.circle, BoxShape.rectangle],
      initial: BoxShape.circle,
      labelOf: (v) => v == BoxShape.circle ? 'Circle' : 'Rectangle',
      codeOf: (v) => 'BoxShape.${v.name}',
    ),
    SliderKnob(
      id: 'ringCount',
      label: 'Rings',
      min: 1,
      max: 4,
      initial: 2,
      divisions: 3,
      format: (v) => '${v.round()}',
      codeOf: (v) => '${v.round()}',
    ),
    const SliderKnob(
      id: 'maxRadiusFactor',
      label: 'Max radius factor',
      min: 1.2,
      max: 2.4,
      initial: 1.6,
      divisions: 12,
      help: 'How far the rings grow, as a multiple of the child size.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 600,
      max: 3000,
      initial: 1500,
      divisions: 24,
    ),
    SelectKnob<int?>(
      id: 'maxPulseCount',
      label: 'Pulses',
      options: const [null, 3],
      initial: null,
      labelOf: (v) => v == null ? 'Unlimited' : '$v then stop',
      codeOf: (v) => '$v',
    ),
  ],
  preview: (context, knobs) => _PulseDemo(knobs: knobs),
  thumbnail: (context) => const _PulseThumb(),
  code: (knobs) {
    final bool circle = knobs.pick<BoxShape>('shape') == BoxShape.circle;
    final String widget = dartCall('PulseHighlight', {
      'controller': 'hint',
      'shape': knobs.arg('shape'),
      'borderRadius': circle ? null : 'BorderRadius.circular(20)',
      'ringCount': knobs.arg('ringCount'),
      'maxRadiusFactor': knobs.arg('maxRadiusFactor'),
      'duration': knobs.arg('duration'),
      'maxPulseCount': knobs.arg('maxPulseCount'),
      'child': circle
          ? dartCall('IconButton.filledTonal', {
              'icon': 'const Icon(Icons.center_focus_strong)',
              'tooltip': quote('Focus mode'),
              'onPressed': 'openFocusMode',
            })
          : dartCall('FilledButton.tonal', {
              'onPressed': 'openFocusMode',
              'child': "const Text('Focus mode')",
            }),
    });
    return 'final hint = PulseHighlightController();\n\n'
        '$widget;\n\n'
        '// Show the hint again later:\n'
        'hint.start();';
  },
  notes: const [
    'The rings are decorative and excluded from semantics; the child keeps '
        'its own label and gestures.',
    'With stopOnTap (the default) a tap stops the pulses and still reaches '
        'the child.',
    'Under reduced motion the widget never pulses and renders only the '
        'child.',
  ],
);

class _PulseDemo extends StatefulWidget {
  const _PulseDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PulseDemo> createState() => _PulseDemoState();
}

class _PulseDemoState extends State<_PulseDemo> {
  final PulseHighlightController _hint = PulseHighlightController();
  bool _focus = false;

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _toggleFocus() {
    setState(() => _focus = !_focus);
    demoToast(context, _focus ? 'Focus mode on' : 'Focus mode off');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool circle = knobs.pick<BoxShape>('shape') == BoxShape.circle;

    final Widget target = circle
        ? IconButton.filledTonal(
            tooltip: 'Focus mode',
            isSelected: _focus,
            onPressed: _toggleFocus,
            icon: const Icon(Icons.center_focus_weak),
            selectedIcon: const Icon(Icons.center_focus_strong),
          )
        : FilledButton.tonalIcon(
            onPressed: _toggleFocus,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(
              _focus ? Icons.center_focus_strong : Icons.center_focus_weak,
              size: 18,
            ),
            label: const Text('Focus'),
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DemoCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                const DemoAvatar('MR', size: 36),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Good morning',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Maya Rivera',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                PulseHighlight(
                  controller: _hint,
                  shape: knobs.pick('shape'),
                  borderRadius: circle ? null : BorderRadius.circular(20),
                  ringCount: knobs.number('ringCount').round(),
                  maxRadiusFactor: knobs.number('maxRadiusFactor'),
                  duration: knobs.ms('duration'),
                  maxPulseCount: knobs.pick('maxPulseCount'),
                  child: target,
                ),
              ],
            ),
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New: Focus mode',
                        style: theme.textTheme.titleSmall,
                      ),
                      const Gap(2),
                      Text(
                        'Mute notifications while you work. Tap the '
                        'highlighted button to try it.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          TextButton.icon(
            onPressed: _hint.start,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Show hint again'),
          ),
        ],
      ),
    );
  }
}

class _PulseThumb extends StatelessWidget {
  const _PulseThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      height: 120,
      child: Center(
        child: PulseHighlight(
          maxRadiusFactor: 2,
          ringCount: 3,
          stopOnTap: false,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
