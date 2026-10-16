import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry hoverGlowEntry = ComponentEntry(
  id: 'hover-glow',
  name: 'Hover Glow',
  category: Categories.borders,
  summary:
      'A soft colored glow that blooms around a button or card when the '
      'mouse hovers it or the keyboard focuses it.',
  apis: const ['HoverGlow'],
  tags: const [ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'glowRadius',
      label: 'Glow radius',
      min: 0,
      max: 40,
      initial: 12,
      divisions: 20,
      help: 'Blur of the glow at full strength.',
    ),
    const SliderKnob(
      id: 'spreadRadius',
      label: 'Spread',
      min: 0,
      max: 16,
      initial: 4,
      divisions: 16,
    ),
    const SliderKnob(
      id: 'glowOpacity',
      label: 'Opacity',
      min: 0,
      max: 1,
      initial: 0.5,
      divisions: 20,
    ),
    const ColorKnob(id: 'glowColor', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _HoverGlowDemo(knobs: knobs),
  thumbnail: (context) => const _HoverGlowThumb(),
  code: (knobs) => dartCall('HoverGlow', {
    'glowColor': knobs.arg('glowColor'),
    'glowRadius': knobs.arg('glowRadius'),
    'spreadRadius': knobs.arg('spreadRadius'),
    'glowOpacity': knobs.arg('glowOpacity'),
    'borderRadius': 'BorderRadius.circular(24)',
    'child': dartCall('FilledButton.icon', {
      'onPressed': 'startTrial',
      'icon': 'const Icon(Icons.bolt_rounded)',
      'label': "const Text('Start free trial')",
    }),
  }),
  notes: const [
    'The glow appears on mouse hover and also when keyboard focus lands '
        'inside the child, so Tab navigation gets the same highlight.',
    'It is a decoration only: no semantics are added and the child keeps '
        'its own focus, labels and taps.',
    'Under reduced motion the glow switches on and off instantly instead '
        'of fading. With enabled set to false the child renders unchanged.',
  ],
);

class _HoverGlowDemo extends StatelessWidget {
  const _HoverGlowDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color? color = knobs.color('glowColor');

    HoverGlow glow({required double radius, required Widget child}) {
      return HoverGlow(
        glowColor: color,
        glowRadius: knobs.number('glowRadius'),
        spreadRadius: knobs.number('spreadRadius'),
        glowOpacity: knobs.number('glowOpacity'),
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          glow(
            radius: 16,
            child: Material(
              color: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => demoToast(context, 'Opening analytics'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(icon: Icons.insights_rounded, color: color),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: DemoCardText(
                          title: 'Usage analytics',
                          body:
                              'Requests, latency and errors for every '
                              'deploy, updated live.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          glow(
            radius: 24,
            child: FilledButton.icon(
              onPressed: () =>
                  demoToast(context, 'Trial started', type: ToastType.success),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Start free trial'),
            ),
          ),
          const SizedBox(height: 24),
          const DemoCaption('Hover the card or the button, or press Tab.'),
        ],
      ),
    );
  }
}

class _HoverGlowThumb extends StatelessWidget {
  const _HoverGlowThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.55),
            blurRadius: 22,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: scheme.onPrimary),
          const SizedBox(width: 8),
          Text(
            'Start free trial',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
