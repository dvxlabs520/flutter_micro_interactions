import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry cometBorderEntry = ComponentEntry(
  id: 'comet-border',
  name: 'Comet Border',
  category: Categories.borders,
  summary:
      'A twinkling star that laps the border of a card or button, trailing '
      'a fading tail and a little stardust. A calm way to mark something '
      'new or live.',
  apis: const ['CometBorder'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob(
      id: 'tailLength',
      label: 'Tail length',
      min: 0.05,
      max: 1,
      initial: 0.25,
      divisions: 19,
      help: 'Share of the outline covered by the tail.',
    ),
    const SliderKnob(
      id: 'thickness',
      label: 'Thickness',
      min: 0.5,
      max: 4,
      initial: 1.5,
      divisions: 7,
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Lap time',
      min: 1000,
      max: 10000,
      initial: 4000,
      divisions: 18,
    ),
    const SliderKnob(
      id: 'cometCount',
      label: 'Comets',
      min: 1,
      max: 8,
      initial: 1,
      divisions: 7,
      format: _int,
      codeOf: _int,
    ),
    const ToggleKnob(id: 'showTrack', label: 'Show track', initial: true),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _CometDemo(knobs: knobs),
  thumbnail: (context) => const CometBorder(
    child: SizedBox(width: 260, child: _ReleaseCard(compact: true)),
  ),
  code: (knobs) => dartCall('CometBorder', {
    'color': knobs.arg('color'),
    'tailLength': knobs.arg('tailLength'),
    'thickness': knobs.arg('thickness'),
    'duration': knobs.arg('duration'),
    'cometCount': knobs.arg('cometCount'),
    'showTrack': knobs.arg('showTrack'),
    'borderRadius': 'BorderRadius.circular(16)',
    'child': 'const ReleaseCard()',
  }),
  notes: const [
    'The comet is painted on top of the child, ignores pointers and adds no '
        'semantics, so the child keeps its own labels and hit testing.',
    'Toggling active fades the effect in or out; once faded out no frames '
        'are scheduled.',
    'Under reduced motion, or with enabled set to false, the comet rests at '
        'the top left corner with its tail and track.',
  ],
);

class _CometDemo extends StatelessWidget {
  const _CometDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: CometBorder(
        color: knobs.color('color'),
        tailLength: knobs.number('tailLength'),
        thickness: knobs.number('thickness'),
        duration: knobs.ms('duration'),
        cometCount: knobs.number('cometCount').round(),
        showTrack: knobs.flag('showTrack'),
        child: const _ReleaseCard(),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DemoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.rocket_launch_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Release 4.2', style: theme.textTheme.titleMedium),
              ),
              Text(
                'New',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Offline mode, faster sync and a redesigned editor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        demoToast(context, 'Opening release notes'),
                    child: const Text('Notes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => demoToast(
                      context,
                      'Update installed',
                      type: ToastType.success,
                    ),
                    child: const Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
