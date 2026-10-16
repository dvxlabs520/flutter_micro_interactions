import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry gradualBlurEntry = ComponentEntry(
  id: 'gradual-blur',
  name: 'Gradual Blur',
  category: Categories.backgrounds,
  summary:
      'A progressive blur that grows stronger toward one edge. Softens '
      'content that scrolls under a header, a footer or a floating toolbar.',
  apis: const ['GradualBlur', 'GradualBlurEdge'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'edge',
      label: 'Edge',
      values: GradualBlurEdge.values,
      initial: GradualBlurEdge.bottom,
      typeName: 'GradualBlurEdge',
    ),
    const SliderKnob(
      id: 'extent',
      label: 'Extent',
      min: 24,
      max: 200,
      initial: 96,
      divisions: 22,
      help: 'Thickness of the blurred band.',
    ),
    const SliderKnob(
      id: 'strength',
      label: 'Strength',
      min: 0,
      max: 2,
      initial: 1,
      divisions: 20,
    ),
    const SliderKnob(
      id: 'layers',
      label: 'Layers',
      min: 1,
      max: 10,
      initial: 6,
      divisions: 9,
      format: _int,
      codeOf: _int,
      help: 'More layers give a smoother ramp but cost more.',
    ),
    const ToggleKnob(
      id: 'fade',
      label: 'Fade to surface',
      initial: false,
      help: 'Adds a fadeColor gradient over the band.',
    ),
  ],
  preview: (context, knobs) => _GradualBlurDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(
    width: 260,
    height: 170,
    child: GradualBlur(extent: 80, child: _PhotoGrid(scrollable: false)),
  ),
  code: (knobs) => dartCall('GradualBlur', {
    'edge': knobs.arg('edge'),
    'extent': knobs.arg('extent'),
    'strength': knobs.arg('strength'),
    'layers': knobs.arg('layers'),
    'fadeColor': knobs.flag('fade')
        ? 'Theme.of(context).colorScheme.surface'
        : null,
    'child': dartCall('GridView.count', {
      'crossAxisCount': '2',
      'children': 'photoTiles',
    }),
  }),
  notes: const [
    'The blur is decorative: it never receives pointer events and adds no '
        'semantics, so the content underneath stays scrollable and tappable.',
    'It is static, so reduced motion does not change it. With enabled set '
        'to false nothing is painted over the child.',
    'Each layer is a BackdropFilter. Keep layers between 4 and 8 and the '
        'band as short as the design allows.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

class _GradualBlurDemo extends StatelessWidget {
  const _GradualBlurDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PhoneFrame(
      width: 360,
      title: 'Explore',
      trailing: Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant),
      child: GradualBlur(
        edge: knobs.pick('edge'),
        extent: knobs.number('extent'),
        strength: knobs.number('strength'),
        layers: knobs.number('layers').round(),
        fadeColor: knobs.flag('fade') ? scheme.surface : null,
        child: const _PhotoGrid(),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({this.scrollable = true});

  final bool scrollable;

  static const List<String> _titles = [
    'Alpine lakes',
    'Northern lights',
    'Desert camps',
    'City nights',
    'Night sky',
    'Ridge walks',
    'Aurora cabins',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GridView.builder(
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: GeneratedImage.gallery.length * 2,
      itemBuilder: (context, index) {
        final int i = index % GeneratedImage.gallery.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: GeneratedImage.gallery[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _titles[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ],
        );
      },
    );
  }
}
