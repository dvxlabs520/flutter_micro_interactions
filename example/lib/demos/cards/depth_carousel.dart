import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry depthCarouselEntry = ComponentEntry(
  id: 'depth-carousel',
  name: 'Depth Carousel',
  category: Categories.cards,
  summary:
      'Cards on a 3D rail that recedes into depth. Drag, swipe, tap a side '
      'card, use the arrow keys or drive it with a controller.',
  apis: const [
    'DepthCarousel',
    'DepthCarouselController',
    'DepthCarouselSemanticValueBuilder',
  ],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    const SliderKnob(
      id: 'spacing',
      label: 'Spacing',
      min: 0.2,
      max: 1.1,
      initial: 0.55,
      divisions: 18,
      help: 'Distance between neighbors, as a fraction of the card width.',
    ),
    const SliderKnob(
      id: 'depth',
      label: 'Depth',
      min: 0,
      max: 400,
      initial: 150,
      divisions: 16,
    ),
    const SliderKnob(
      id: 'rotation',
      label: 'Rotation',
      min: 0,
      max: 40,
      initial: 12,
      divisions: 20,
      help: 'Degrees added per step away from the front.',
    ),
    const SliderKnob(
      id: 'depthFade',
      label: 'Depth fade',
      min: 0,
      max: 0.6,
      initial: 0.25,
      divisions: 12,
    ),
    const ToggleKnob(id: 'loop', label: 'Loop', initial: false),
    const ToggleKnob(id: 'autoPlay', label: 'Auto play', initial: false),
  ],
  preview: (context, knobs) => _CarouselDemo(knobs: knobs),
  thumbnail: (context) => const _CarouselThumb(),
  code: (knobs) {
    final String carousel = dartCall('DepthCarousel', {
      'controller': 'controller',
      'spacing': knobs.arg('spacing'),
      'depth': knobs.arg('depth'),
      'rotation': knobs.arg('rotation'),
      'depthFade': knobs.arg('depthFade'),
      'loop': knobs.arg('loop'),
      'autoPlay': knobs.arg('autoPlay'),
      'onIndexChanged': '(int i) => setState(() => current = i)',
      'children': '[for (final Trip trip in trips) TripCard(trip: trip)]',
    });
    return 'final controller = DepthCarouselController();\n\n'
        '$carousel\n\n'
        'IconButton(\n'
        '  onPressed: controller.next,\n'
        '  icon: const Icon(Icons.chevron_right_rounded),\n'
        ')';
  },
  notes: const [
    'The carousel is one semantics node with increase and decrease actions '
        'and a value such as Item 2 of 7. The front card and its neighbors keep '
        'their own semantics; cards further back are excluded.',
    'When focused, the arrow keys move between cards. Mouse wheels and '
        'trackpads step through them, and auto play pauses while the rail is '
        'hovered, dragged or focused.',
    'Under reduced motion transitions jump to their target and auto play is '
        'turned off; dragging still follows the finger. With enabled set to '
        'false the rail ignores all input.',
  ],
  stageHeight: 480,
);

const List<(String, String)> _trips = [
  ('Alpine ridge', 'Switzerland'),
  ('Northern lights', 'Iceland'),
  ('Desert dusk', 'Morocco'),
  ('City at night', 'Tokyo'),
  ('Observatory', 'Chile'),
  ('Valley sunrise', 'Norway'),
  ('Aurora coast', 'Canada'),
];

class _CarouselDemo extends StatefulWidget {
  const _CarouselDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CarouselDemo> createState() => _CarouselDemoState();
}

class _CarouselDemoState extends State<_CarouselDemo> {
  final DepthCarouselController _controller = DepthCarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Knobs knobs = widget.knobs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 320,
            child: DepthCarousel(
              controller: _controller,
              spacing: knobs.number('spacing'),
              depth: knobs.number('depth'),
              rotation: knobs.number('rotation'),
              depthFade: knobs.number('depthFade'),
              loop: knobs.flag('loop'),
              autoPlay: knobs.flag('autoPlay'),
              semanticLabel: 'Trips',
              children: [
                for (int i = 0; i < _trips.length; i++) _TripCard(index: i),
              ],
            ),
          ),
          const Gap(16),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final int index = _controller.index;
              final bool loop = knobs.flag('loop');
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    tooltip: 'Previous',
                    onPressed: loop || index > 0 ? _controller.previous : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  SizedBox(
                    width: 132,
                    child: Column(
                      children: [
                        Text(
                          _trips[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '${index + 1} of ${_trips.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Next',
                    onPressed: loop || index < _trips.length - 1
                        ? _controller.next
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.index, this.compact = false});

  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String title, String place) = _trips[index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image:
                GeneratedImage.gallery[index % GeneratedImage.gallery.length],
            fit: BoxFit.cover,
            semanticLabel: title,
          ),
          if (!compact)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    place.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CarouselThumb extends StatelessWidget {
  const _CarouselThumb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 150,
      child: IgnorePointer(
        child: DepthCarousel(
          initialIndex: 2,
          itemExtent: const Size(96, 128),
          children: [
            for (int i = 0; i < 5; i++) _TripCard(index: i, compact: true),
          ],
        ),
      ),
    );
  }
}
