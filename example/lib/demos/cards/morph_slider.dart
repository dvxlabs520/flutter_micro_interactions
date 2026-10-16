import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/generated_images.dart';

const List<(String, String, GeneratedImage)> _slides = [
  (
    'Northern ridge',
    'Four days on foot',
    GeneratedImage(style: SceneStyle.mountains, seed: 11),
  ),
  (
    'Dune sea',
    'Camp under the stars',
    GeneratedImage(style: SceneStyle.dunes, seed: 12),
  ),
  (
    'Harbor lights',
    'A weekend in the city',
    GeneratedImage(style: SceneStyle.city, seed: 13),
  ),
  (
    'Night sky',
    'Away from every light',
    GeneratedImage(style: SceneStyle.aurora, seed: 14),
  ),
];

final ComponentEntry morphSliderEntry = ComponentEntry(
  id: 'morph-slider',
  name: 'Morph Slider',
  category: Categories.cards,
  summary:
      'An image slider that melts, ripples or swirls from one picture into '
      'the next with a GPU shader.',
  apis: const ['MorphSlider', 'MorphSliderController', 'MorphEffect'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  stageHeight: 480,
  knobs: [
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: MorphEffect.values,
      initial: MorphEffect.melt,
      typeName: 'MorphEffect',
    ),
    const SliderKnob(
      id: 'intensity',
      label: 'Intensity',
      min: 0,
      max: 1,
      initial: 0.7,
      divisions: 20,
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 400,
      max: 2400,
      initial: 1100,
      divisions: 20,
    ),
    const ToggleKnob(id: 'autoPlay', label: 'Auto play', initial: false),
    const ToggleKnob(id: 'showArrows', label: 'Arrows', initial: true),
  ],
  preview: (context, knobs) => _MorphSliderDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(
    width: 300,
    height: 170,
    child: MorphSlider(
      images: [
        GeneratedImage(style: SceneStyle.mountains, seed: 11),
        GeneratedImage(style: SceneStyle.dunes, seed: 12),
      ],
      autoPlay: true,
      interval: Duration(seconds: 3),
      showArrows: false,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  code: (knobs) {
    final String call = dartCall('MorphSlider', {
      'images':
          'const <ImageProvider>[\n'
          "  AssetImage('assets/ridge.jpg'),\n"
          "  AssetImage('assets/dunes.jpg'),\n"
          "  AssetImage('assets/harbor.jpg'),\n"
          ']',
      'effect': knobs.arg('effect'),
      'intensity': knobs.arg('intensity'),
      'duration': knobs.arg('duration'),
      'autoPlay': knobs.arg('autoPlay'),
      'showArrows': knobs.arg('showArrows'),
      'aspectRatio': '16 / 10',
    });
    return '// Warm up the shader once, for example in main().\n'
        'await MorphSlider.precacheShader();\n\n$call';
  },
  notes: const [
    'The image area is one semantics node labelled with semanticLabels, or '
        '"Image 2 of 4", and screen readers can step through the images.',
    'Under reduced motion transitions swap images at once and auto play '
        'stops.',
    'The shader ships with the package; call precacheShader early so the '
        'first transition does not wait for it.',
  ],
);

class _MorphSliderDemo extends StatelessWidget {
  const _MorphSliderDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: MorphSlider(
        images: [for (final s in _slides) s.$3],
        effect: knobs.pick('effect'),
        intensity: knobs.number('intensity'),
        duration: knobs.ms('duration'),
        autoPlay: knobs.flag('autoPlay'),
        showArrows: knobs.flag('showArrows'),
        aspectRatio: 16 / 10,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        semanticLabels: [for (final s in _slides) s.$1],
        overlayBuilder: (context, index) => Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slides[index].$1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  _slides[index].$2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
