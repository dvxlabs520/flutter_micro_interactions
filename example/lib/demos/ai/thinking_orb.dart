import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry thinkingOrbEntry = ComponentEntry(
  id: 'thinking-orb',
  name: 'Thinking Orb',
  category: Categories.ai,
  summary:
      'A dotted, pseudo-3D orb that replaces a spinner in AI interfaces, '
      'with one animation for each kind of work an agent does.',
  apis: const ['ThinkingOrb', 'ThinkingOrbState'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'state',
      label: 'State',
      values: ThinkingOrbState.values,
      initial: ThinkingOrbState.working,
      typeName: 'ThinkingOrbState',
    ),
    const SliderKnob(
      id: 'size',
      label: 'Size',
      min: 24,
      max: 120,
      initial: 64,
      divisions: 24,
      help: 'Below 40 a sparser tuning keeps the dots readable.',
    ),
    const SliderKnob(
      id: 'speed',
      label: 'Speed',
      min: 0,
      max: 3,
      initial: 1,
      divisions: 12,
      help: '0 freezes the current frame.',
    ),
    const ColorKnob(id: 'color', label: 'Ink', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ThinkingOrbDemo(knobs: knobs),
  thumbnail: (context) => const _OrbThumb(),
  code: (knobs) => dartCall('ThinkingOrb', {
    'state': knobs.code('state'),
    'size': knobs.arg('size'),
    'speed': knobs.arg('speed'),
    'color': knobs.arg('color'),
  }),
  notes: const [
    'The orb is a single semantics node labelled with semanticLabel, or with '
        'the state label such as "Searching..." when no label is given.',
    'Changing state crossfades between the two animations over '
        'transitionDuration (250 ms by default).',
    'Under reduced motion, or with enabled set to false, the orb paints one '
        'static frame, schedules no frames and switches states instantly.',
    'The ink defaults to colorScheme.onSurface, so the orb reads on light '
        'and dark surfaces.',
  ],
  stageHeight: 440,
);

/// What an agent might be doing in each state, for the inline example.
String _activityFor(ThinkingOrbState state) => switch (state) {
  ThinkingOrbState.working => 'Running 3 tools',
  ThinkingOrbState.searching => 'Searching the web',
  ThinkingOrbState.solving => 'Solving the equation',
  ThinkingOrbState.listening => 'Listening to you',
  ThinkingOrbState.connecting => 'Connecting to your calendar',
  ThinkingOrbState.weaving => 'Merging 4 sources',
  ThinkingOrbState.composing => 'Drafting a reply',
  ThinkingOrbState.thinking => 'Thinking it through',
  ThinkingOrbState.shaping => 'Sketching a layout',
};

class _ThinkingOrbDemo extends StatelessWidget {
  const _ThinkingOrbDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ThinkingOrbState state = knobs.pick('state');
    final double speed = knobs.number('speed');
    final Color? color = knobs.color('color');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 132,
          child: Center(
            child: ThinkingOrb(
              state: state,
              size: knobs.number('size'),
              speed: speed,
              color: color,
            ),
          ),
        ),
        const Gap(12),
        Text(
          state.label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const Gap(32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThinkingOrb(state: state, size: 22, speed: speed, color: color),
                const Gap(10),
                Flexible(
                  child: Text(
                    _activityFor(state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(10),
        const DemoCaption('Inline size, next to a status line'),
      ],
    );
  }
}

class _OrbThumb extends StatelessWidget {
  const _OrbThumb();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThinkingOrb(state: ThinkingOrbState.searching, size: 56),
        Gap(20),
        ThinkingOrb(state: ThinkingOrbState.solving, size: 56),
        Gap(20),
        ThinkingOrb(state: ThinkingOrbState.thinking, size: 56),
        Gap(20),
        ThinkingOrb(state: ThinkingOrbState.shaping, size: 56),
      ],
    );
  }
}
