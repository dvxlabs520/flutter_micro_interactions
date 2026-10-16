import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry magnetEntry = ComponentEntry(
  id: 'magnet',
  name: 'Magnet',
  category: Categories.pointer,
  summary:
      'Pulls a button toward the pointer when it comes close, then lets it '
      'spring back. A playful touch for the main call to action.',
  apis: const ['Magnet'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'strength',
      label: 'Strength',
      min: 0,
      max: 1,
      initial: 0.3,
      divisions: 20,
      help: 'Share of the pointer offset the child moves by.',
    ),
    const SliderKnob(
      id: 'padding',
      label: 'Padding',
      min: 0,
      max: 160,
      initial: 60,
      divisions: 16,
      help: 'How far around the child the pull reaches.',
    ),
    const ToggleKnob(
      id: 'showArea',
      label: 'Show activation area',
      initial: false,
    ),
  ],
  preview: (context, knobs) => _MagnetDemo(knobs: knobs),
  thumbnail: (context) => const _MagnetThumb(),
  code: (knobs) => dartCall('Magnet', {
    'strength': knobs.arg('strength'),
    'padding': knobs.arg('padding'),
    'child': dartCall('FilledButton', {
      'onPressed': 'getStarted',
      'child': "const Text('Get started')",
    }),
  }),
  notes: const [
    'The magnet only observes pointer events, so it never blocks taps or '
        'hover effects of the child or of nearby widgets. The hit area moves '
        'with the child.',
    'On touch screens the child follows the finger while it is down inside '
        'the area and springs back when it lifts.',
    'The effect adds no semantics. Under reduced motion, or with enabled '
        'set to false, the child never moves.',
  ],
);

class _MagnetDemo extends StatelessWidget {
  const _MagnetDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double padding = knobs.number('padding');
    final Widget button = FilledButton.icon(
      onPressed: () => demoToast(context, 'Welcome aboard'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: const Text('Get started'),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ready to ship faster?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const DemoCaption(
            'Set up your first project in under five minutes. '
            'No credit card required.',
          ),
          const SizedBox(height: 56),
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (knobs.flag('showArea'))
                Positioned(
                  left: -padding,
                  top: -padding,
                  right: -padding,
                  bottom: -padding,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(26 + padding),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ),
              Magnet(
                strength: knobs.number('strength'),
                padding: padding,
                child: button,
              ),
            ],
          ),
          const SizedBox(height: 56),
          const DemoCaption('Move the pointer near the button.'),
        ],
      ),
    );
  }
}

class _MagnetThumb extends StatelessWidget {
  const _MagnetThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: 260,
      height: 120,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(18, -8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Get started',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 34,
            top: 22,
            child: Transform.flip(
              flipX: true,
              child: Icon(
                Icons.near_me_rounded,
                size: 22,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
