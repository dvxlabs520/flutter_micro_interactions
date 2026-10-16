import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

/// Made up company names with generic icons, so no real brand is shown.
const List<(IconData, String)> _logos = [
  (Icons.hexagon_outlined, 'Northwind'),
  (Icons.bolt_rounded, 'Voltline'),
  (Icons.change_history_rounded, 'Vertex'),
  (Icons.blur_on_rounded, 'Lumen'),
  (Icons.public_rounded, 'Orbital'),
  (Icons.air_rounded, 'Kite'),
];

const List<String> _stack = [
  'Flutter',
  'Dart',
  'Firebase',
  'GraphQL',
  'Rive',
  'Riverpod',
];

final ComponentEntry logoLoopEntry = ComponentEntry(
  id: 'logo-loop',
  name: 'Logo Loop',
  category: Categories.cards,
  summary:
      'A seamless, endlessly scrolling strip of logos, badges or chips. Use it '
      'for "trusted by" rows, tech stacks and sponsor lists.',
  apis: const ['LogoLoop', 'LogoLoopDirection'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'direction',
      label: 'Direction',
      values: LogoLoopDirection.values,
      initial: LogoLoopDirection.left,
      typeName: 'LogoLoopDirection',
    ),
    const SliderKnob(
      id: 'speed',
      label: 'Speed',
      min: 10,
      max: 200,
      initial: 60,
      divisions: 19,
      help: 'Logical pixels per second.',
    ),
    const SliderKnob(
      id: 'gap',
      label: 'Gap',
      min: 8,
      max: 80,
      initial: 32,
      divisions: 18,
    ),
    const ToggleKnob(
      id: 'pauseOnHover',
      label: 'Pause on hover',
      initial: true,
    ),
    const ToggleKnob(
      id: 'scaleOnHover',
      label: 'Scale on hover',
      initial: false,
    ),
    const ToggleKnob(id: 'fadeOut', label: 'Fade edges', initial: true),
  ],
  preview: (context, knobs) => _LogoLoopDemo(knobs: knobs),
  thumbnail: (context) => SizedBox(
    width: 300,
    child: LogoLoop(
      children: [
        for (final (IconData icon, String name) in _logos)
          _Logo(icon: icon, name: name),
      ],
    ),
  ),
  code: (knobs) => dartCall('LogoLoop', {
    'direction': knobs.arg('direction'),
    'speed': knobs.arg('speed'),
    'gap': knobs.arg('gap'),
    'pauseOnHover': knobs.arg('pauseOnHover'),
    'scaleOnHover': knobs.arg('scaleOnHover'),
    'fadeOut': knobs.arg('fadeOut'),
    'children': dartList([
      "const PartnerLogo('Northwind')",
      "const PartnerLogo('Voltline')",
      "const PartnerLogo('Vertex')",
      "const PartnerLogo('Lumen')",
    ]),
  }),
  notes: const [
    'Screen readers see each child once; the repeated copies are excluded '
        'from semantics. Children must not use GlobalKeys.',
    'Hovering pauses the loop, or slows it when hoverSpeed is set. Speed '
        'changes ease in instead of snapping.',
    'Under reduced motion, or with enabled set to false, nothing scrolls on '
        'its own: one run is shown in a scroll view the user can drag.',
  ],
);

class _LogoLoopDemo extends StatelessWidget {
  const _LogoLoopDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final LogoLoopDirection direction = knobs.pick('direction');
    final bool vertical =
        direction == LogoLoopDirection.up ||
        direction == LogoLoopDirection.down;

    LogoLoop loop(List<Widget> children, {bool reverse = false}) {
      final double speed = knobs.number('speed');
      return LogoLoop(
        direction: direction,
        speed: reverse ? -speed * 0.75 : speed,
        gap: knobs.number('gap'),
        pauseOnHover: knobs.flag('pauseOnHover'),
        scaleOnHover: knobs.flag('scaleOnHover'),
        fadeOut: knobs.flag('fadeOut'),
        children: children,
      );
    }

    final List<Widget> logos = [
      for (final (IconData icon, String name) in _logos)
        _Logo(icon: icon, name: name),
    ];
    final List<Widget> chips = [for (final String s in _stack) _Chip(s)];

    final Widget strips = vertical
        ? SizedBox(
            height: 240,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                loop(logos),
                const SizedBox(width: 32),
                loop(chips, reverse: true),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              loop(logos),
              const SizedBox(height: 20),
              loop(chips, reverse: true),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DemoCaption('Trusted by teams at'),
          const SizedBox(height: 20),
          strips,
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color c = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: c),
        const SizedBox(width: 8),
        Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: c,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
