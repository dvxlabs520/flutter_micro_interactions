import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

const List<String> _lines = [
  'ship faster.',
  'design with care.',
  'sleep at night.',
];

final ComponentEntry typewriterTextEntry = ComponentEntry(
  id: 'typewriter-text',
  name: 'Typewriter Text',
  category: Categories.text,
  summary:
      'Text that types itself out with a blinking cursor, then deletes and '
      'moves on to the next string.',
  apis: const ['TypewriterText', 'TypewriterController'],
  knobs: [
    const SliderKnob.duration(
      id: 'typeSpeed',
      label: 'Type speed',
      min: 20,
      max: 200,
      initial: 60,
      divisions: 18,
      help: 'Delay per typed character.',
    ),
    const SliderKnob.duration(
      id: 'deleteSpeed',
      label: 'Delete speed',
      min: 10,
      max: 150,
      initial: 40,
      divisions: 14,
    ),
    const SliderKnob.duration(
      id: 'pauseBetween',
      label: 'Pause',
      min: 300,
      max: 4000,
      initial: 1500,
      divisions: 37,
      help: 'How long a finished string stays before deleting.',
    ),
    const ToggleKnob(
      id: 'loop',
      label: 'Loop',
      initial: false,
      help: 'Off stops on the last string.',
    ),
    const ToggleKnob(id: 'showCursor', label: 'Cursor', initial: true),
  ],
  preview: (context, knobs) => _TypewriterDemo(knobs: knobs),
  thumbnail: (context) => const _TerminalThumb(),
  code: (knobs) => dartCall('TypewriterText', {
    'strings': "const ['ship faster.', 'design with care.', 'sleep at night.']",
    'typeSpeed': knobs.arg('typeSpeed'),
    'deleteSpeed': knobs.arg('deleteSpeed'),
    'pauseBetween': knobs.arg('pauseBetween'),
    'loop': knobs.arg('loop'),
    'showCursor': knobs.arg('showCursor'),
    'style': 'Theme.of(context).textTheme.headlineMedium',
  }),
  notes: const [
    'The semantics label is always the full target string, never the partly '
        'typed text, and no live region is used, so screen readers are not '
        'flooded per character.',
    'The full current string is laid out invisibly under the typed part, so '
        'the size stays constant while typing.',
    'Under reduced motion each string is shown complete without timers: the '
        'first string when looping, otherwise the last one.',
  ],
  replayable: true,
  stageHeight: 380,
);

class _TypewriterDemo extends StatelessWidget {
  const _TypewriterDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // A new key restarts the sequence whenever a knob changes.
    final String signature = [
      for (final Knob<Object?> k in knobs.all) knobs.valueOf(k.id),
    ].join('|');
    final TextStyle? headline = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FOR PRODUCT TEAMS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.6,
            ),
          ),
          const Gap(14),
          Text(
            'Tools that help you',
            textAlign: TextAlign.center,
            style: headline,
          ),
          TypewriterText(
            key: ValueKey(signature),
            strings: _lines,
            typeSpeed: knobs.ms('typeSpeed'),
            deleteSpeed: knobs.ms('deleteSpeed'),
            pauseBetween: knobs.ms('pauseBetween'),
            loop: knobs.flag('loop'),
            showCursor: knobs.flag('showCursor'),
            textAlign: TextAlign.center,
            cursorColor: scheme.primary,
            style: headline?.copyWith(color: scheme.primary),
          ),
          const Gap(20),
          Text(
            'Plan, build and ship in one place.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalThumb extends StatelessWidget {
  const _TerminalThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? mono = theme.textTheme.titleMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier'],
    );
    return DemoCard(
      width: 300,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final Color c in const [
                Color(0xFFF87171),
                Color(0xFFFBBF24),
                Color(0xFF34D399),
              ]) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const Gap(6),
              ],
            ],
          ),
          const Gap(16),
          Row(
            children: [
              Text('\$ ', style: mono?.copyWith(color: scheme.primary)),
              Expanded(
                child: TypewriterText(
                  strings: const ['flutter pub get', 'flutter run'],
                  loop: true,
                  pauseBetween: const Duration(milliseconds: 1200),
                  style: mono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
