import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry shimmerTextEntry = ComponentEntry(
  id: 'shimmer-text',
  name: 'Shimmer Text',
  category: Categories.ai,
  summary:
      'A soft band of light that sweeps across a status line, the classic '
      '"Thinking..." look of AI assistants. Works on icons too.',
  apis: const ['ShimmerText'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    const TextKnob(id: 'text', label: 'Text', initial: 'Thinking...'),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Sweep duration',
      min: 600,
      max: 3000,
      initial: 1600,
      divisions: 24,
    ),
    const SliderKnob(
      id: 'bandWidth',
      label: 'Band width',
      min: 0.1,
      max: 1,
      initial: 0.35,
      divisions: 18,
      help: 'Width of the highlight, as a fraction of the text width.',
    ),
    const SliderKnob.duration(
      id: 'interval',
      label: 'Pause between sweeps',
      min: 0,
      max: 1500,
      initial: 0,
      divisions: 15,
    ),
  ],
  preview: (context, knobs) => _ShimmerDemo(knobs: knobs),
  thumbnail: (context) => const _ShimmerThumb(),
  code: (knobs) {
    final Map<String, String?> timing = {
      'duration': knobs.arg('duration'),
      'interval': knobs.arg('interval'),
      'bandWidth': knobs.arg('bandWidth'),
    };
    return dartCall('Row', {
      'children': dartList([
        dartCall('ShimmerText.child', {
          ...timing,
          'child': 'const Icon(Icons.auto_awesome, size: 18)',
        }),
        'const SizedBox(width: 8)',
        dartCall(
          'ShimmerText',
          {...timing, 'style': 'Theme.of(context).textTheme.titleSmall'},
          positional: [knobs.code('text')],
        ),
      ]),
    });
  },
  notes: const [
    'The glyphs are untouched for assistive technology: screen readers read '
        'the text normally.',
    'ShimmerText.child applies the same sweep to any widget; its own colors '
        'are replaced by the shimmer.',
    'The sweep follows the ambient Directionality. Under reduced motion, or '
        'with enabled set to false, the text renders statically in its base '
        'color.',
  ],
  stageHeight: 380,
);

class _ShimmerDemo extends StatelessWidget {
  const _ShimmerDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Duration duration = knobs.ms('duration');
    final Duration interval = knobs.ms('interval');
    final double bandWidth = knobs.number('bandWidth');
    final String text = knobs.text('text');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                'Plan a three day trip to Lisbon in May',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const Gap(24),
          Row(
            children: [
              ShimmerText.child(
                duration: duration,
                interval: interval,
                bandWidth: bandWidth,
                child: const Icon(Icons.auto_awesome, size: 18),
              ),
              const Gap(8),
              Flexible(
                child: ShimmerText(
                  text.isEmpty ? ' ' : text,
                  duration: duration,
                  interval: interval,
                  bandWidth: bandWidth,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const Gap(10),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              'Checking flights, hotels and the weather in May',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerThumb extends StatelessWidget {
  const _ShimmerThumb();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ShimmerText.child(child: Icon(Icons.auto_awesome, size: 24)),
        const Gap(10),
        ShimmerText('Thinking...', style: textTheme.headlineSmall),
      ],
    );
  }
}
