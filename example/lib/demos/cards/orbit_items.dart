import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry orbitItemsEntry = ComponentEntry(
  id: 'orbit-items',
  name: 'Orbit Items',
  category: Categories.cards,
  summary:
      'Avatars, icons or images that orbit evenly spaced around a center '
      'widget. Good for integration showcases and team sections.',
  apis: const ['OrbitItems', 'OrbitShape'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    SelectKnob.enumeration(
      id: 'shape',
      label: 'Shape',
      values: OrbitShape.values,
      initial: OrbitShape.circle,
      typeName: 'OrbitShape',
    ),
    SliderKnob(
      id: 'duration',
      label: 'Revolution',
      min: 4,
      max: 30,
      initial: 12,
      divisions: 26,
      format: (v) => '${v.round()} s',
      codeOf: (v) => 'Duration(seconds: ${v.round()})',
      help: 'Time for one full turn.',
    ),
    const ToggleKnob(
      id: 'depth',
      label: 'Depth',
      initial: false,
      help: 'Items higher up shrink and dim. Best with an ellipse.',
    ),
    const ToggleKnob(id: 'showPath', label: 'Orbit line', initial: false),
    const ToggleKnob(id: 'clockwise', label: 'Clockwise', initial: true),
    const ToggleKnob(
      id: 'rotateItems',
      label: 'Rotate items',
      initial: false,
      help: 'Items turn to follow the direction of travel.',
    ),
  ],
  preview: (context, knobs) => _OrbitDemo(knobs: knobs),
  thumbnail: (context) => const _OrbitThumb(),
  code: (knobs) {
    return dartCall('SizedBox.square', {
      'dimension': '300',
      'child': dartCall('OrbitItems', {
        'shape': knobs.arg('shape'),
        'duration': knobs.arg('duration'),
        'depth': knobs.arg('depth'),
        'showPath': knobs.arg('showPath'),
        'clockwise': knobs.arg('clockwise'),
        'rotateItems': knobs.arg('rotateItems'),
        'center': 'const AppLogo(size: 72)',
        'children':
            '[\n'
            '  for (final Integration i in integrations)\n'
            '    IntegrationBadge(integration: i),\n'
            ']',
      }),
    });
  },
  notes: const [
    'The center and the items keep their own semantics and stay tappable; '
        'taps follow the moving items. The orbit line is decorative.',
    'Hovering with a mouse pauses the orbit when pauseOnHover is set (the '
        'default), easing to a stop and back.',
    'Under reduced motion, or with enabled set to false, the items rest at '
        'their evenly spaced starting positions and nothing moves.',
  ],
  stageHeight: 460,
);

const List<(IconData, String)> _integrations = [
  (Icons.chat_bubble_rounded, 'Chat'),
  (Icons.mail_rounded, 'Mail'),
  (Icons.calendar_month_rounded, 'Calendar'),
  (Icons.cloud_rounded, 'Storage'),
  (Icons.code_rounded, 'Repository'),
  (Icons.payments_rounded, 'Payments'),
  (Icons.description_rounded, 'Docs'),
];

class _OrbitDemo extends StatelessWidget {
  const _OrbitDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = math.min(constraints.maxWidth, 320);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: side,
              child: OrbitItems(
                shape: knobs.pick('shape'),
                duration: Duration(seconds: knobs.number('duration').round()),
                depth: knobs.flag('depth'),
                showPath: knobs.flag('showPath'),
                clockwise: knobs.flag('clockwise'),
                rotateItems: knobs.flag('rotateItems'),
                center: const _AppLogo(size: 72),
                children: [
                  for (int i = 0; i < _integrations.length; i++)
                    _IntegrationBadge(
                      icon: _integrations[i].$1,
                      name: _integrations[i].$2,
                      color: demoAccents[i % demoAccents.length],
                    ),
                ],
              ),
            ),
            const Gap(8),
            Text('Works with your stack', style: theme.textTheme.titleMedium),
            const Gap(4),
            const DemoCaption('Tap an integration to connect it'),
          ],
        );
      },
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Relay',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35),
              blurRadius: size * 0.4,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        child: Icon(
          Icons.bolt_rounded,
          size: size * 0.55,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _IntegrationBadge extends StatelessWidget {
  const _IntegrationBadge({
    required this.icon,
    required this.name,
    required this.color,
    this.size = 46,
  });

  final IconData icon;
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: name,
      child: Material(
        color: scheme.surfaceContainer,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => demoToast(context, '$name connected'),
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: size * 0.46, color: color),
          ),
        ),
      ),
    );
  }
}

class _OrbitThumb extends StatelessWidget {
  const _OrbitThumb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 150,
      child: OrbitItems(
        shape: OrbitShape.ellipse,
        depth: true,
        showPath: true,
        duration: const Duration(seconds: 10),
        center: const _AppLogo(size: 48),
        children: [
          for (int i = 0; i < 6; i++)
            _IntegrationBadge(
              icon: _integrations[i].$1,
              name: _integrations[i].$2,
              color: demoAccents[i],
              size: 34,
            ),
        ],
      ),
    );
  }
}
