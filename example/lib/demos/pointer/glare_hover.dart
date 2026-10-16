import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

String _degrees(double v) => '${v.round()}.0';

final ComponentEntry glareHoverEntry = ComponentEntry(
  id: 'glare-hover',
  name: 'Glare Hover',
  category: Categories.pointer,
  summary:
      'A glossy streak of light that sweeps once across a card when the '
      'pointer enters. Gives covers, product shots and premium cards a '
      'polished sheen.',
  apis: const ['GlareHover', 'GlareHoverController'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'glareAngle',
      label: 'Angle',
      min: -180,
      max: 180,
      initial: -45,
      divisions: 24,
      format: _degrees,
      codeOf: _degrees,
      help: 'Direction of travel in degrees; 0 points up.',
    ),
    const SliderKnob(
      id: 'glareOpacity',
      label: 'Opacity',
      min: 0,
      max: 1,
      initial: 0.35,
      divisions: 20,
    ),
    const SliderKnob(
      id: 'glareSize',
      label: 'Size',
      min: 0.5,
      max: 5,
      initial: 2.5,
      divisions: 9,
      help: 'Larger values give a wider, softer band.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 2000,
      initial: 650,
      divisions: 36,
    ),
    const ToggleKnob(
      id: 'reverseOnExit',
      label: 'Reverse on exit',
      initial: true,
    ),
  ],
  preview: (context, knobs) => _GlareDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(width: 220, child: _AlbumCard()),
  code: (knobs) {
    final String glare = dartCall('GlareHover', {
      'controller': 'controller',
      'glareAngle': knobs.arg('glareAngle'),
      'glareOpacity': knobs.arg('glareOpacity'),
      'glareSize': knobs.arg('glareSize'),
      'duration': knobs.arg('duration'),
      'reverseOnExit': knobs.arg('reverseOnExit'),
      'borderRadius': 'BorderRadius.circular(20)',
      'child': 'const AlbumCard()',
    });
    return 'final controller = GlareHoverController();\n\n'
        '$glare\n\n'
        '// Play one sweep from code, for example after a purchase.\n'
        'controller.play();';
  },
  notes: const [
    'The glare does not follow the pointer: it sweeps once on enter and, by '
        'default, back on exit. Nothing moves while the pointer rests.',
    'On touch screens a press plays one sweep, and keyboard focus inside the '
        'child behaves like a hover. The band ignores pointers and adds no '
        'semantics.',
    'Under reduced motion, or with enabled set to false, no glare is painted '
        'and controller sweeps do nothing.',
  ],
);

class _GlareDemo extends StatefulWidget {
  const _GlareDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_GlareDemo> createState() => _GlareDemoState();
}

class _GlareDemoState extends State<_GlareDemo> {
  final GlareHoverController _controller = GlareHoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlareHover(
            controller: _controller,
            glareAngle: knobs.number('glareAngle'),
            glareOpacity: knobs.number('glareOpacity'),
            glareSize: knobs.number('glareSize'),
            duration: knobs.ms('duration'),
            reverseOnExit: knobs.flag('reverseOnExit'),
            borderRadius: BorderRadius.circular(20),
            child: const _AlbumCard(),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _controller.play,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Play sweep'),
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 1.25,
            child: Image(
              image: GeneratedImage(style: SceneStyle.orbits, seed: 5),
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Expanded(
                  child: DemoCardText(
                    title: 'Midnight Orbit',
                    body: 'Nova Lane  ·  12 tracks',
                  ),
                ),
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
