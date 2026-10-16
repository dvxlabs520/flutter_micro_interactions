import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry tiltCardEntry = ComponentEntry(
  id: 'tilt-card',
  name: 'Tilt Card',
  category: Categories.pointer,
  summary:
      'Tilts a card in 3D toward the pointer, with a slight lift and a '
      'glare that follows it. Suits membership cards, covers and product '
      'shots.',
  apis: const ['TiltCard'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'maxTilt',
      label: 'Max tilt',
      min: 0,
      max: 30,
      initial: 12,
      divisions: 30,
      help: 'Rotation in degrees when the pointer is at an edge.',
    ),
    const SliderKnob(
      id: 'scaleOnHover',
      label: 'Scale on hover',
      min: 1,
      max: 1.15,
      initial: 1.03,
      divisions: 15,
    ),
    const ToggleKnob(id: 'glare', label: 'Glare', initial: true),
    const SliderKnob(
      id: 'glareOpacity',
      label: 'Glare opacity',
      min: 0,
      max: 1,
      initial: 0.25,
      divisions: 20,
    ),
  ],
  preview: (context, knobs) => _TiltDemo(knobs: knobs),
  thumbnail: (context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX(0.18)
      ..rotateY(-0.32),
    child: const SizedBox(width: 280, child: _MembershipCard()),
  ),
  code: (knobs) => dartCall('TiltCard', {
    'maxTilt': knobs.arg('maxTilt'),
    'scaleOnHover': knobs.arg('scaleOnHover'),
    'glare': knobs.arg('glare'),
    'glareOpacity': knobs.flag('glare') ? knobs.arg('glareOpacity') : null,
    'borderRadius': 'BorderRadius.circular(20)',
    'child': 'const MembershipCard()',
  }),
  notes: const [
    'The pointer is read outside the transform, so the tilt never feeds back '
        'into itself, and events are observed without being consumed.',
    'On touch screens the card tilts while the finger is pressed and dragged '
        'over it. Device motion sensors are not used.',
    'The glare ignores pointers and adds no semantics. Under reduced '
        'motion, or with enabled set to false, the card renders flat.',
  ],
);

class _TiltDemo extends StatelessWidget {
  const _TiltDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TiltCard(
            maxTilt: knobs.number('maxTilt'),
            scaleOnHover: knobs.number('scaleOnHover'),
            glare: knobs.flag('glare'),
            glareOpacity: knobs.number('glareOpacity'),
            borderRadius: BorderRadius.circular(20),
            child: const _MembershipCard(),
          ),
          const SizedBox(height: 28),
          const DemoCaption('Move the pointer over the card, or drag on it.'),
        ],
      ),
    );
  }
}

/// A premium membership card painted from the theme colors over a
/// generated aurora image.
class _MembershipCard extends StatelessWidget {
  const _MembershipCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color ink = scheme.onPrimary;
    final TextStyle? label = theme.textTheme.labelSmall?.copyWith(
      color: ink.withValues(alpha: 0.7),
      letterSpacing: 1.2,
    );
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: GeneratedImage(style: SceneStyle.aurora, seed: 7),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.82),
                    scheme.shadow.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'NORTHWIND',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Text('MEMBER', style: label),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [
                              scheme.tertiary.withValues(alpha: 0.9),
                              ink.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.contactless_outlined, color: ink, size: 22),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '4821  0094  1170  3356',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'JORDAN LEE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: ink,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Text('VALID 09/29', style: label),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
