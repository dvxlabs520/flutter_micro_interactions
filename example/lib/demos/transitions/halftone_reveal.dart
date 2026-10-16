import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry halftoneRevealEntry = ComponentEntry(
  id: 'halftone-reveal',
  name: 'Halftone Reveal',
  category: Categories.transitions,
  summary:
      'An image printed as halftone dots that swell into the real photo '
      'under the pointer, or across the whole frame on demand.',
  apis: const ['HalftoneReveal', 'HalftoneRevealController'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'cellSize',
      label: 'Cell size',
      min: 4,
      max: 20,
      initial: 8,
      divisions: 16,
      help: 'Side of one halftone cell, one dot per cell.',
    ),
    const SliderKnob(
      id: 'revealRadius',
      label: 'Reveal radius',
      min: 40,
      max: 220,
      initial: 120,
      divisions: 18,
    ),
    const SliderKnob(
      id: 'softness',
      label: 'Softness',
      min: 0,
      max: 1,
      initial: 0.5,
      divisions: 10,
      help: 'Width of the ring where dots merge into the photo.',
    ),
    const ToggleKnob(
      id: 'colored',
      label: 'Colored dots',
      initial: false,
      help: 'Each dot takes the color of the image under it.',
    ),
    const ToggleKnob(id: 'invert', label: 'Invert', initial: false),
  ],
  preview: (context, knobs) => _HalftoneDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(
    width: 260,
    height: 150,
    child: IgnorePointer(
      child: HalftoneReveal(
        image: _image,
        cellSize: 6,
        colored: true,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  ),
  code: (knobs) {
    final String widget = dartCall('HalftoneReveal', {
      'image': "const AssetImage('assets/alpine_ridge.jpg')",
      'controller': 'controller',
      'cellSize': knobs.arg('cellSize'),
      'revealRadius': knobs.arg('revealRadius'),
      'softness': knobs.arg('softness'),
      'colored': knobs.arg('colored'),
      'invert': knobs.arg('invert'),
      'borderRadius': 'BorderRadius.circular(16)',
      'semanticLabel': "'Alpine ridge at sunrise'",
    });
    return 'final controller = HalftoneRevealController();\n\n'
        'AspectRatio(\n'
        '  aspectRatio: 3 / 2,\n'
        '  child: ${indent(widget).trimLeft()},\n'
        ')\n\n'
        '// Show the whole photo, or go back to the print:\n'
        'controller.toggle();';
  },
  notes: const [
    'The widget is exposed as an image with semanticLabel. The dots are '
        'sampled once per image, size and cell size, so a frame only draws a '
        'cached layer plus the dots near the pointer.',
    'With a mouse the window follows hover; on touch it follows a press and '
        'drag, and heals back into dots when the pointer leaves.',
    'Under reduced motion the window opens and closes instantly and tracks '
        'the pointer without smoothing; full reveals jump to their final '
        'state. With enabled set to false it is a static print.',
  ],
  stageHeight: 460,
);

const GeneratedImage _image = GeneratedImage(
  style: SceneStyle.mountains,
  seed: 1,
  width: 720,
  height: 480,
);

class _HalftoneDemo extends StatefulWidget {
  const _HalftoneDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_HalftoneDemo> createState() => _HalftoneDemoState();
}

class _HalftoneDemoState extends State<_HalftoneDemo> {
  final HalftoneRevealController _controller = HalftoneRevealController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 2,
            child: HalftoneReveal(
              image: _image,
              controller: _controller,
              cellSize: knobs.number('cellSize'),
              revealRadius: knobs.number('revealRadius'),
              softness: knobs.number('softness'),
              colored: knobs.flag('colored'),
              invert: knobs.flag('invert'),
              borderRadius: BorderRadius.circular(16),
              semanticLabel: 'Alpine ridge at sunrise',
            ),
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alpine ridge, edition of 50',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const Gap(2),
                    Text(
                      'Hover or drag over the print',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => OutlinedButton(
                  onPressed: _controller.toggle,
                  child: Text(
                    _controller.isRevealed ? 'Show print' : 'Show photo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
