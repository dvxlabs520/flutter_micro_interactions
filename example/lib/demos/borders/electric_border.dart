import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry electricBorderEntry = ComponentEntry(
  id: 'electric-border',
  name: 'Electric Border',
  category: Categories.borders,
  summary:
      'Crackling strands of current that crawl along the border of a card or '
      'button, with the occasional spark. Good for live, boosted or '
      'high energy states.',
  apis: const ['ElectricBorder'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob(
      id: 'chaos',
      label: 'Chaos',
      min: 0,
      max: 1,
      initial: 0.6,
      divisions: 20,
      help: 'How far the strands stray from the outline.',
    ),
    const SliderKnob(
      id: 'speed',
      label: 'Speed',
      min: 0.25,
      max: 3,
      initial: 1,
      divisions: 11,
    ),
    const SliderKnob(
      id: 'thickness',
      label: 'Thickness',
      min: 0.5,
      max: 4,
      initial: 1.5,
      divisions: 7,
    ),
    const ToggleKnob(id: 'sparks', label: 'Sparks', initial: true),
    const ToggleKnob(
      id: 'active',
      label: 'Active',
      initial: true,
      help: 'Fades the current in or out.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ElectricDemo(knobs: knobs),
  thumbnail: (context) => const ElectricBorder(
    child: SizedBox(width: 260, child: _LiveCard(live: true)),
  ),
  code: (knobs) => dartCall('ElectricBorder', {
    'color': knobs.arg('color'),
    'chaos': knobs.arg('chaos'),
    'speed': knobs.arg('speed'),
    'thickness': knobs.arg('thickness'),
    'sparks': knobs.arg('sparks'),
    'active': knobs.arg('active'),
    'borderRadius': 'BorderRadius.circular(16)',
    'child': 'const LiveStreamCard()',
  }),
  notes: const [
    'The current is painted on top of the child, ignores pointers and adds '
        'no semantics. Nothing is painted more than 10 pixels outside the '
        'bounds.',
    'Toggling active fades the effect over 300 milliseconds; once faded out '
        'no frames are scheduled.',
    'Under reduced motion, or with enabled set to false, a single frozen '
        'frame is shown without sparks.',
  ],
);

class _ElectricDemo extends StatelessWidget {
  const _ElectricDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final bool active = knobs.flag('active');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ElectricBorder(
        color: knobs.color('color'),
        chaos: knobs.number('chaos'),
        speed: knobs.number('speed'),
        thickness: knobs.number('thickness'),
        sparks: knobs.flag('sparks'),
        active: active,
        child: _LiveCard(live: active),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live});

  final bool live;

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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: live ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                live ? 'LIVE' : 'OFFLINE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: live ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                live ? '12.4k' : '0',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DemoAvatar('KO', color: demoAccents[1], size: 40),
              const SizedBox(width: 12),
              const Expanded(
                child: DemoCardText(
                  title: 'Finals night',
                  body: 'Kai Oduya  ·  Speedrun league',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
