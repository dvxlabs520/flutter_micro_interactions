import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry pixelTransitionEntry = ComponentEntry(
  id: 'pixel-transition',
  name: 'Pixel Transition',
  category: Categories.transitions,
  summary:
      'A retro pixel dissolve between two children: cells cover the first '
      'one, then clear away to reveal the second. Great for cards that '
      'reveal details on hover or tap.',
  apis: const [
    'PixelTransition',
    'PixelTransitionController',
    'PixelTransitionTrigger',
  ],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'trigger',
      label: 'Trigger',
      values: PixelTransitionTrigger.values,
      initial: PixelTransitionTrigger.hover,
      typeName: 'PixelTransitionTrigger',
      help: 'Hover falls back to tap on touch screens.',
    ),
    const SliderKnob(
      id: 'gridSize',
      label: 'Grid size',
      min: 4,
      max: 40,
      initial: 12,
      divisions: 36,
      format: _int,
      codeOf: _int,
      help: 'Cells along each side.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 2000,
      initial: 600,
      divisions: 18,
      help: 'Half to cover, half to reveal.',
    ),
    const ColorKnob(id: 'pixelColor', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _PixelDemo(knobs: knobs),
  thumbnail: (context) => const _PixelThumb(),
  code: (knobs) {
    final String widget = dartCall('PixelTransition', {
      'controller': 'controller',
      'trigger': knobs.arg('trigger'),
      'gridSize': knobs.arg('gridSize'),
      'duration': knobs.arg('duration'),
      'pixelColor': knobs.arg('pixelColor'),
      'borderRadius': 'BorderRadius.circular(20)',
      'firstChild': 'const StayPhoto()',
      'secondChild': 'const StayDetails()',
    });
    return 'final controller = PixelTransitionController();\n\n'
        '$widget\n\n'
        '// Switch sides from code, or call showFirst() and showSecond().\n'
        'controller.toggle();';
  },
  notes: const [
    'Only the child on screen is visible to screen readers and receives '
        'pointer events. With the tap trigger the widget exposes a tap '
        'action, so screen reader users can switch sides.',
    'Both children stay mounted, so their state survives transitions.',
    'Under reduced motion, or with enabled set to false, the sides swap '
        'instantly without cells.',
  ],
  stageHeight: 460,
);

class _PixelDemo extends StatefulWidget {
  const _PixelDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PixelDemo> createState() => _PixelDemoState();
}

class _PixelDemoState extends State<_PixelDemo> {
  final PixelTransitionController _controller = PixelTransitionController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final PixelTransitionTrigger trigger = knobs.pick('trigger');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelTransition(
          controller: _controller,
          trigger: trigger,
          gridSize: knobs.number('gridSize').round(),
          duration: knobs.ms('duration'),
          pixelColor: knobs.color('pixelColor'),
          borderRadius: BorderRadius.circular(20),
          firstChild: const _StayPhoto(),
          secondChild: const _StayDetails(),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _controller.toggle,
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('Toggle'),
            ),
            DemoCaption(switch (trigger) {
              PixelTransitionTrigger.hover => 'Hover or tap the card',
              PixelTransitionTrigger.tap => 'Tap the card',
              PixelTransitionTrigger.manual => 'Use the Toggle button',
            }),
          ],
        ),
      ],
    );
  }
}

const double _side = 240;

class _StayPhoto extends StatelessWidget {
  const _StayPhoto();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SizedBox(
      width: _side,
      height: _side,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: GeneratedImage(style: SceneStyle.dunes, seed: 3),
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Desert camp', style: theme.textTheme.labelMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _StayDetails extends StatelessWidget {
  const _StayDetails();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: _side,
      height: _side,
      padding: const EdgeInsets.all(20),
      color: scheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desert camp', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Wadi Rum, Jordan',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final (IconData icon, String text) in const [
            (Icons.star_rounded, '4.9  ·  212 reviews'),
            (Icons.nights_stay_outlined, 'Stargazing tent'),
            (Icons.local_dining_outlined, 'Dinner included'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(r'$140 / night', style: theme.textTheme.titleSmall),
              ),
              FilledButton(
                onPressed: () => demoToast(context, 'Added to trip'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Reserve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A photo half covered by cells, as a still frame of the dissolve.
class _PixelThumb extends StatelessWidget {
  const _PixelThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const int grid = 8;
    const double cell = 160 / grid;
    // A fixed scatter of covered cells.
    const List<int> covered = [
      1, 3, 6, 8, 10, 12, 15, 17, 19, 22, 24, 27, 29, 30, 33, 35, 36, 38, //
      41, 43, 46, 47, 49, 52, 54, 57, 59, 60, 63,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            const Positioned.fill(
              child: Image(
                image: GeneratedImage(style: SceneStyle.dunes, seed: 3),
                fit: BoxFit.cover,
              ),
            ),
            for (final int i in covered)
              Positioned(
                left: (i % grid) * cell,
                top: (i ~/ grid) * cell,
                width: cell,
                height: cell,
                child: ColoredBox(color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}
