import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry spotlightCardEntry = ComponentEntry(
  id: 'spotlight-card',
  name: 'Spotlight Card',
  category: Categories.pointer,
  summary:
      'A card with a soft light that follows the pointer and brightens the '
      'nearest part of its border. Great for feature grids and pricing '
      'tiers.',
  apis: const ['SpotlightCard'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'radius',
      label: 'Radius',
      min: 60,
      max: 400,
      initial: 200,
      divisions: 17,
      help: 'Size of the spotlight and of the border glow.',
    ),
    const SliderKnob(
      id: 'borderWidth',
      label: 'Border width',
      min: 0,
      max: 4,
      initial: 1,
      divisions: 8,
    ),
    const ColorKnob(
      id: 'color',
      label: 'Spotlight color',
      swatches: demoSwatches,
      help: 'Also used for the border glow.',
    ),
  ],
  preview: (context, knobs) => _SpotlightDemo(knobs: knobs),
  thumbnail: (context) => const _SpotlightThumb(),
  code: (knobs) {
    final Color? color = knobs.color('color');
    return dartCall('SpotlightCard', {
      'radius': knobs.arg('radius'),
      'borderWidth': knobs.arg('borderWidth'),
      'spotlightColor': color == null
          ? null
          : colorCode(color.withValues(alpha: 0.25)),
      'borderGlowColor': color == null ? null : colorCode(color),
      'child': dartCall('FeatureTile', {
        'icon': 'Icons.bolt_rounded',
        'title': "'Edge network'",
        'body': "'Deploy to 35 regions with zero config.'",
      }),
    });
  },
  notes: const [
    'Pointer events are observed without being consumed, so buttons and '
        'gestures inside the card keep working. On touch screens the light '
        'shows while the finger is down and follows it.',
    'The spotlight is decorative and adds no semantics.',
    'Under reduced motion the light still follows the pointer, since it is '
        'direct manipulation, but it appears and disappears without fading.',
  ],
);

class _SpotlightDemo extends StatelessWidget {
  const _SpotlightDemo({required this.knobs});

  final Knobs knobs;

  static const List<(IconData, String, String)> _features = [
    (
      Icons.bolt_rounded,
      'Edge network',
      'Deploy to 35 regions with zero config. Cold starts under 50 ms.',
    ),
    (
      Icons.insights_rounded,
      'Live analytics',
      'Track requests, latency and errors as they happen, per deploy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Color? color = knobs.color('color');
    Widget card((IconData, String, String) f) {
      return SpotlightCard(
        radius: knobs.number('radius'),
        borderWidth: knobs.number('borderWidth'),
        spotlightColor: color?.withValues(alpha: 0.25),
        borderGlowColor: color,
        child: _FeatureTile(icon: f.$1, title: f.$2, body: f.$3, color: color),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 560;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 260, child: card(_features[0])),
                const SizedBox(width: 16),
                SizedBox(width: 260, child: card(_features[1])),
              ],
            ),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(_features[0]),
              const SizedBox(height: 16),
              card(_features[1]),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
    this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon, color: color),
        const SizedBox(height: 16),
        DemoCardText(title: title, body: body),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Learn more',
              style: theme.textTheme.labelLarge?.copyWith(
                color: color ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: color ?? theme.colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _SpotlightThumb extends StatelessWidget {
  const _SpotlightThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
        gradient: RadialGradient(
          center: const Alignment(0.55, -0.45),
          radius: 0.9,
          colors: [
            scheme.primary.withValues(alpha: 0.3),
            scheme.surfaceContainer,
          ],
        ),
      ),
      child: const DemoCardText(
        icon: Icons.bolt_rounded,
        title: 'Edge network',
        body: 'Deploy to 35 regions with zero config.',
      ),
    );
  }
}
