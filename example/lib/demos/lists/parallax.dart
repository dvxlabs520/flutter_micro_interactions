import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

enum _Variant { scroll, image }

final ComponentEntry parallaxEntry = ComponentEntry(
  id: 'parallax',
  name: 'Parallax',
  category: Categories.lists,
  summary:
      'Backgrounds and images that move slower than the content as you '
      'scroll, for a sense of depth in headers and feeds.',
  apis: const ['ParallaxScroll', 'ParallaxLayer', 'ParallaxImage'],
  knobs: [
    SelectKnob<_Variant>(
      id: 'variant',
      label: 'Variant',
      options: _Variant.values,
      initial: _Variant.image,
      labelOf: (v) => v == _Variant.scroll ? 'ParallaxScroll' : 'ParallaxImage',
      help: 'A background behind a whole list, or one image per list item.',
    ),
    const SliderKnob(
      id: 'factor',
      label: 'Parallax factor',
      min: 0,
      max: 1,
      initial: 0.3,
      divisions: 10,
      help: '0 keeps the image still relative to its frame, 1 pans the most.',
    ),
    const SliderKnob(
      id: 'height',
      label: 'Image height',
      min: 140,
      max: 260,
      initial: 200,
      divisions: 12,
      help: 'ParallaxImage only.',
    ),
  ],
  preview: (context, knobs) => _ParallaxDemo(knobs: knobs),
  thumbnail: (context) => const _ParallaxThumb(),
  code: (knobs) {
    final double factor = knobs.number('factor');
    if (knobs.pick<_Variant>('variant') == _Variant.scroll) {
      return dartCall('ParallaxScroll', {
        'parallaxFactor': factor == 0.5 ? null : formatNumber(factor),
        'background': "Image.asset('assets/aurora.jpg', fit: BoxFit.cover)",
        'children':
            '[\n'
            '  const SizedBox(height: 220),\n'
            '  for (final stop in itinerary) StopCard(stop),\n'
            ']',
      });
    }
    final String image = dartCall('ParallaxImage', {
      'imageProvider': 'AssetImage(trip.photo)',
      'parallaxFactor': knobs.arg('factor'),
      'height': knobs.arg('height'),
      'semanticLabel': 'trip.title',
    });
    return dartCall('ListView', {
      'children': '[\n  for (final trip in trips)\n${indent(image, 4)},\n]',
    });
  },
  notes: const [
    'Backgrounds and layers of ParallaxScroll are decorative and excluded '
        'from semantics. ParallaxImage is decorative unless you give it a '
        'semanticLabel.',
    'Both are driven by the scroll position with no setState per frame.',
    'Under reduced motion the background and images stay still.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

const List<(String, String)> _trips = [
  ('Dolomites', 'Italy  ·  5 nights'),
  ('Lofoten', 'Norway  ·  4 nights'),
  ('Wadi Rum', 'Jordan  ·  3 nights'),
  ('Shibuya', 'Japan  ·  6 nights'),
  ('Atacama', 'Chile  ·  4 nights'),
  ('Patagonia', 'Argentina  ·  7 nights'),
  ('Tromso', 'Norway  ·  3 nights'),
];

/// A portrait version of a gallery scene, so the image stays taller than
/// its frame at every width.
GeneratedImage _portrait(int i) {
  final GeneratedImage scene =
      GeneratedImage.gallery[i % GeneratedImage.gallery.length];
  return GeneratedImage(
    style: scene.style,
    seed: scene.seed,
    width: 600,
    height: 800,
  );
}

class _ParallaxDemo extends StatelessWidget {
  const _ParallaxDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final bool scroll = knobs.pick<_Variant>('variant') == _Variant.scroll;
    return PhoneFrame(
      title: scroll ? 'Northern lights' : 'Trips',
      // Lets a mouse drag the content on desktop, like a finger.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: scroll
            ? _ScrollVariant(factor: knobs.number('factor'))
            : _FeedVariant(
                factor: knobs.number('factor'),
                height: knobs.number('height'),
              ),
      ),
    );
  }
}

class _FeedVariant extends StatelessWidget {
  const _FeedVariant({required this.factor, required this.height});

  final double factor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _trips.length,
      separatorBuilder: (context, i) => const Gap(14),
      itemBuilder: (context, i) {
        final (String title, String subtitle) = _trips[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ParallaxImage(
                imageProvider: _portrait(i),
                parallaxFactor: factor,
                height: height,
                semanticLabel: title,
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xAA000000)],
                      stops: [0.45, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScrollVariant extends StatelessWidget {
  const _ScrollVariant({required this.factor});

  final double factor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ParallaxScroll(
      parallaxFactor: factor,
      background: const Image(
        image: GeneratedImage(style: SceneStyle.aurora, seed: 7),
        fit: BoxFit.cover,
      ),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        SizedBox(
          height: 200,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tromso, Norway',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '3 nights  ·  February',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final (int i, (String day, String plan)) in const [
          ('Day 1', 'Arrive and check in at the harbour lodge'),
          ('Day 1', 'Evening aurora walk on Prestvannet lake'),
          ('Day 2', 'Fjord cruise and whale watching'),
          ('Day 2', 'Dog sledding under the polar night'),
          ('Day 3', 'Arctic Cathedral and cable car'),
          ('Day 3', 'Northern lights chase by minibus'),
          ('Day 4', 'Brunch at the old town and fly home'),
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DemoCard(
              padding: const EdgeInsets.all(14),
              radius: 14,
              child: Row(
                children: [
                  IconBadge(
                    icon: i.isEven
                        ? Icons.place_outlined
                        : Icons.nightlight_outlined,
                    size: 34,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(plan, style: theme.textTheme.titleSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ParallaxThumb extends StatelessWidget {
  const _ParallaxThumb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 150,
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const Gap(8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OverflowBox(
                  maxHeight: 220,
                  alignment: Alignment(0, -1 + i * 0.8),
                  child: Image(
                    image: GeneratedImage.gallery[const [0, 2, 3][i]],
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
