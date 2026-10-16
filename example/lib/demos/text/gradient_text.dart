import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

/// A named set of gradient colors. `null` colors use the theme default.
class _Palette {
  const _Palette(this.name, this.colors);

  final String name;
  final List<Color>? colors;
}

const List<_Palette> _palettes = [
  _Palette('Theme', null),
  _Palette('Aurora', [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFF6E7BFF)]),
  _Palette('Sunset', [Color(0xFFF59E0B), Color(0xFFF472B6), Color(0xFFA78BFA)]),
  _Palette('Candy', [
    Color(0xFFFF3264),
    Color(0xFF288CFF),
    Color(0xFF32C850),
    Color(0xFFFF7828),
  ]),
];

String _paletteCode(_Palette p) => p.colors == null
    ? 'null'
    : 'const ${dartList([for (final Color c in p.colors!) colorCode(c)])}';

final ComponentEntry gradientTextEntry = ComponentEntry(
  id: 'gradient-text',
  name: 'Gradient Text',
  category: Categories.text,
  summary:
      'Text filled with a gradient that slides along an angle or rotates '
      'around the center. Works on icons too.',
  apis: const ['GradientText', 'GradientTextType', 'GradientTextController'],
  tags: const [ComponentTag.newly],
  knobs: [
    const TextKnob(id: 'text', label: 'Text', initial: 'Introducing Flow'),
    SelectKnob.enumeration(
      id: 'type',
      label: 'Type',
      values: GradientTextType.values,
      initial: GradientTextType.linear,
      typeName: 'GradientTextType',
    ),
    SelectKnob<_Palette>(
      id: 'palette',
      label: 'Colors',
      options: _palettes,
      initial: _palettes.first,
      labelOf: (p) => p.name,
      codeOf: _paletteCode,
      help: 'Theme uses primary, tertiary and secondary.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Cycle',
      min: 1000,
      max: 8000,
      initial: 3000,
      divisions: 14,
    ),
    const ToggleKnob(
      id: 'pingPong',
      label: 'Ping pong',
      initial: false,
      help: 'Move back and forth instead of looping.',
    ),
  ],
  preview: (context, knobs) => _GradientDemo(knobs: knobs),
  thumbnail: (context) => const _GradientThumb(),
  code: (knobs) => dartCall(
    'GradientText',
    {
      'type': knobs.arg('type'),
      'colors': knobs.arg('palette'),
      'duration': knobs.arg('duration'),
      'pingPong': knobs.arg('pingPong'),
      'textAlign': 'TextAlign.center',
      'style': 'Theme.of(context).textTheme.displaySmall',
    },
    positional: [knobs.code('text')],
  ),
  notes: const [
    'The glyphs are untouched for assistive technology: screen readers read '
        'the text normally.',
    'When the first and last colors differ, the first color is appended '
        'internally so the loop has no visible seam.',
    'Under reduced motion, or with enabled set to false, the gradient '
        'renders statically.',
  ],
);

class _GradientDemo extends StatelessWidget {
  const _GradientDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _Palette palette = knobs.pick('palette');
    final GradientTextType type = knobs.pick('type');
    final Duration duration = knobs.ms('duration');
    final bool pingPong = knobs.flag('pingPong');
    final String text = knobs.text('text');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientText.child(
            colors: palette.colors,
            type: type,
            duration: duration,
            pingPong: pingPong,
            child: const Icon(Icons.auto_awesome, size: 40),
          ),
          const Gap(16),
          GradientText(
            text.isEmpty ? ' ' : text,
            colors: palette.colors,
            type: type,
            duration: duration,
            pingPong: pingPong,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const Gap(14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              'Plan, write and ship in one calm workspace, with an assistant '
              'that knows your projects.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const Gap(22),
          FilledButton(
            onPressed: () => demoToast(context, 'You are on the list'),
            child: const Text('Join the waitlist'),
          ),
        ],
      ),
    );
  }
}

class _GradientThumb extends StatelessWidget {
  const _GradientThumb();

  @override
  Widget build(BuildContext context) {
    return GradientText(
      'Introducing Flow',
      colors: _palettes[3].colors,
      style: Theme.of(
        context,
      ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
