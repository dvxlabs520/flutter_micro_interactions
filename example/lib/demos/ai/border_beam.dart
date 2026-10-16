import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry borderBeamEntry = ComponentEntry(
  id: 'border-beam',
  name: 'Border Beam',
  category: Categories.ai,
  summary:
      'A soft beam of colored light that travels around the border of a '
      'card, input or button while an agent is working.',
  apis: const ['BorderBeam', 'BorderBeamStyle', 'BorderBeamPalette'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'style',
      label: 'Style',
      values: BorderBeamStyle.values,
      initial: BorderBeamStyle.beam,
      typeName: 'BorderBeamStyle',
      help: 'Beam suits cards, line suits inputs, pulse suits buttons.',
    ),
    SelectKnob.enumeration(
      id: 'palette',
      label: 'Palette',
      values: BorderBeamPalette.values,
      initial: BorderBeamPalette.colorful,
      typeName: 'BorderBeamPalette',
    ),
    const SliderKnob(
      id: 'strength',
      label: 'Strength',
      min: 0.2,
      max: 2,
      initial: 1,
      divisions: 18,
    ),
    const SliderKnob(
      id: 'borderWidth',
      label: 'Border width',
      min: 0.5,
      max: 4,
      initial: 1.5,
      divisions: 14,
    ),
    const ToggleKnob(id: 'active', label: 'Active', initial: true),
    const ToggleKnob(
      id: 'innerGlow',
      label: 'Inner glow',
      initial: false,
      help: 'Soft light that fades inward from the edge.',
    ),
  ],
  preview: (context, knobs) => _BorderBeamDemo(knobs: knobs),
  thumbnail: (context) => const _AgentCard(width: 300, active: true),
  code: (knobs) {
    final BorderBeamStyle style = knobs.pick('style');
    final String radius = style == BorderBeamStyle.beam ? '16' : '28';
    return dartCall('BorderBeam', {
      'style': knobs.arg('style'),
      'palette': knobs.arg('palette'),
      'strength': knobs.arg('strength'),
      'borderWidth': knobs.arg('borderWidth'),
      'active': knobs.arg('active'),
      'innerGlow': knobs.arg('innerGlow'),
      'borderRadius': 'BorderRadius.circular($radius)',
      'child': switch (style) {
        BorderBeamStyle.beam => 'const AgentCard()',
        BorderBeamStyle.line => 'const SearchField()',
        BorderBeamStyle.pulse =>
          'FilledButton(onPressed: generate, '
              "child: const Text('Generate'))",
      },
    });
  },
  notes: const [
    'The beam is decorative: it ignores pointers and adds no semantics, so '
        'the child keeps its own hit testing and labels.',
    'Toggling active fades the effect in or out. When it is fully faded out '
        'no frames are scheduled.',
    'Under reduced motion the beam rests in place instead of travelling.',
  ],
);

class _BorderBeamDemo extends StatelessWidget {
  const _BorderBeamDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final BorderBeamStyle style = knobs.pick('style');
    final double radius = style == BorderBeamStyle.beam ? 16 : 28;
    final Widget child = switch (style) {
      BorderBeamStyle.beam => _AgentCard(active: knobs.flag('active')),
      BorderBeamStyle.line => const _SearchField(),
      BorderBeamStyle.pulse => FilledButton.icon(
        onPressed: () {},
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Generate'),
      ),
    };
    return BorderBeam(
      style: style,
      palette: knobs.pick('palette'),
      strength: knobs.number('strength'),
      borderWidth: knobs.number('borderWidth'),
      active: knobs.flag('active'),
      innerGlow: knobs.flag('innerGlow'),
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({this.width = 360, required this.active});

  final double width;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DemoCard(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ThinkingOrb(
                state: active
                    ? ThinkingOrbState.searching
                    : ThinkingOrbState.composing,
                size: 28,
                enabled: active,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Research agent',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                active ? 'Running' : 'Done',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (active)
            ShimmerText(
              'Reading 12 sources about motion design',
              style: theme.textTheme.bodySmall,
            )
          else
            Text(
              'Summary ready: 4 key findings',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: active ? 0.62 : 1,
              minHeight: 4,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: 380,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ask anything...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(Icons.arrow_upward_rounded, size: 18, color: scheme.primary),
        ],
      ),
    );
  }
}
