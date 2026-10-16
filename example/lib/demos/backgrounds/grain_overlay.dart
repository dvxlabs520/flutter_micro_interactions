import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

const List<BlendMode> _blendModes = [
  BlendMode.overlay,
  BlendMode.softLight,
  BlendMode.srcOver,
  BlendMode.multiply,
];

final ComponentEntry grainOverlayEntry = ComponentEntry(
  id: 'grain-overlay',
  name: 'Grain Overlay',
  category: Categories.backgrounds,
  summary:
      'Animated film grain over any widget, for an analog, printed feel on '
      'gradients, hero images and flat surfaces.',
  apis: const ['GrainOverlay'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob<bool>(
      id: 'photo',
      label: 'Surface',
      options: const [false, true],
      initial: false,
      labelOf: (v) => v ? 'Photo' : 'Gradient',
    ),
    const SliderKnob(
      id: 'opacity',
      label: 'Opacity',
      min: 0,
      max: 0.4,
      initial: 0.08,
      divisions: 40,
    ),
    const SliderKnob(
      id: 'grainSize',
      label: 'Grain size',
      min: 0.5,
      max: 4,
      initial: 1,
      divisions: 7,
    ),
    SelectKnob<BlendMode>(
      id: 'blendMode',
      label: 'Blend mode',
      options: _blendModes,
      initial: BlendMode.overlay,
      labelOf: (v) => switch (v) {
        BlendMode.softLight => 'Soft light',
        BlendMode.srcOver => 'Normal',
        _ => '${v.name[0].toUpperCase()}${v.name.substring(1)}',
      },
      codeOf: (v) => 'BlendMode.${v.name}',
    ),
    const ToggleKnob(
      id: 'monochrome',
      label: 'Monochrome',
      initial: true,
      help: 'Off gives colored grain.',
    ),
    const ToggleKnob(id: 'animated', label: 'Animated', initial: true),
  ],
  preview: (context, knobs) => _GrainDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(
    width: 280,
    child: GrainOverlay(opacity: 0.2, child: _HeroCard(compact: true)),
  ),
  code: (knobs) {
    return dartCall('GrainOverlay', {
      'opacity': knobs.arg('opacity'),
      'grainSize': knobs.arg('grainSize'),
      'blendMode': knobs.arg('blendMode'),
      'monochrome': knobs.arg('monochrome'),
      'animated': knobs.arg('animated'),
      'child': knobs.pick<bool>('photo')
          ? "Image.asset('assets/hero.jpg', fit: BoxFit.cover)"
          : 'const LaunchHero()',
    });
  },
  notes: const [
    'The overlay ignores pointer events and adds no semantics, so taps and '
        'screen readers reach the child as if the grain were not there.',
    'A small noise tile is generated once and shared. Animating only moves '
        'the shader offset about 12 times per second, in its own repaint '
        'boundary, so the child never repaints because of it.',
    'Under reduced motion, or with animated set to false, the grain is '
        'static and no timer runs. With enabled set to false no grain is '
        'painted.',
  ],
  stageHeight: 400,
);

class _GrainDemo extends StatelessWidget {
  const _GrainDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final bool photo = knobs.pick<bool>('photo');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GrainOverlay(
        opacity: knobs.number('opacity'),
        grainSize: knobs.number('grainSize'),
        blendMode: knobs.pick('blendMode'),
        monochrome: knobs.flag('monochrome'),
        animated: knobs.flag('animated'),
        child: photo ? const _PhotoCard() : const _HeroCard(),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      height: compact ? 150 : 240,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
            scheme.tertiary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'SPRING RELEASE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              letterSpacing: 1.6,
            ),
          ),
          const Gap(6),
          Text(
            'Motion that feels printed',
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
          ),
          if (!compact) ...[
            const Gap(6),
            Text(
              'Twelve new effects, all respecting reduced motion.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: GeneratedImage(style: SceneStyle.dunes, seed: 3),
              fit: BoxFit.cover,
              semanticLabel: 'Dunes at dusk',
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Dunes at dusk',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
