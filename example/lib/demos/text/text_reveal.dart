import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry textRevealEntry = ComponentEntry(
  id: 'text-reveal',
  name: 'Text Reveal',
  category: Categories.text,
  summary:
      'A headline that enters one character or one word at a time, with a '
      'fade, slide, blur or scale.',
  apis: const [
    'TextReveal',
    'TextRevealEffect',
    'TextRevealSplit',
    'TextRevealController',
  ],
  tags: const [ComponentTag.newly],
  knobs: [
    const TextKnob(
      id: 'text',
      label: 'Text',
      initial: 'Make every interaction feel alive',
    ),
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: TextRevealEffect.values,
      initial: TextRevealEffect.slideUp,
      typeName: 'TextRevealEffect',
    ),
    SelectKnob.enumeration(
      id: 'split',
      label: 'Split by',
      values: TextRevealSplit.values,
      initial: TextRevealSplit.characters,
      typeName: 'TextRevealSplit',
    ),
    const SliderKnob.duration(
      id: 'stagger',
      label: 'Stagger',
      min: 10,
      max: 200,
      initial: 50,
      divisions: 19,
      help: 'Delay between two units.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 150,
      max: 1200,
      initial: 450,
      divisions: 21,
      help: 'How long each unit takes to appear.',
    ),
  ],
  preview: (context, knobs) => _TextRevealDemo(knobs: knobs),
  thumbnail: (context) => const _RevealThumb(),
  code: (knobs) => dartCall('TextReveal', {
    'text': knobs.code('text'),
    'effect': knobs.arg('effect'),
    'splitBy': knobs.arg('split'),
    'stagger': knobs.arg('stagger'),
    'duration': knobs.arg('duration'),
    'textAlign': 'TextAlign.center',
    'style': 'Theme.of(context).textTheme.headlineMedium',
  }),
  notes: const [
    'The widget exposes the full text (or semanticLabel) as a single '
        'semantics node; the animated units are excluded.',
    'Layout is final from the first frame: hidden units keep their place, so '
        'nothing reflows while the text reveals.',
    'Under reduced motion, or with enabled set to false, the final text is '
        'shown at once and onCompleted still fires.',
  ],
  replayable: true,
);

class _TextRevealDemo extends StatelessWidget {
  const _TextRevealDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    // A new key replays the whole hero whenever a knob changes.
    final String signature = [
      for (final String id in const [
        'text',
        'effect',
        'split',
        'stagger',
        'duration',
      ])
        knobs.valueOf(id),
    ].join('|');
    return _RevealHero(key: ValueKey(signature), knobs: knobs);
  }
}

class _RevealHero extends StatefulWidget {
  const _RevealHero({super.key, required this.knobs});

  final Knobs knobs;

  @override
  State<_RevealHero> createState() => _RevealHeroState();
}

class _RevealHeroState extends State<_RevealHero> {
  final TextRevealController _subtitle = TextRevealController();

  @override
  void dispose() {
    _subtitle.dispose();
    super.dispose();
  }

  /// Starts the subtitle once the headline is in, after the current frame
  /// (onCompleted may fire during a build under reduced motion).
  void _playSubtitle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _subtitle.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Version 3.0',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          const Gap(18),
          TextReveal(
            text: knobs.text('text'),
            effect: knobs.pick('effect'),
            splitBy: knobs.pick('split'),
            stagger: knobs.ms('stagger'),
            duration: knobs.ms('duration'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            onCompleted: _playSubtitle,
          ),
          const Gap(14),
          TextReveal(
            text:
                'Small, accessible animations that respect reduced motion '
                'and never block what people came to do.',
            controller: _subtitle,
            autoPlay: false,
            effect: TextRevealEffect.fade,
            splitBy: TextRevealSplit.words,
            stagger: const Duration(milliseconds: 25),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealThumb extends StatefulWidget {
  const _RevealThumb();

  @override
  State<_RevealThumb> createState() => _RevealThumbState();
}

class _RevealThumbState extends State<_RevealThumb> {
  final TextRevealController _controller = TextRevealController();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      _controller
        ..reset()
        ..play();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextReveal(
      text: 'Feel alive',
      controller: _controller,
      effect: TextRevealEffect.blur,
      style: Theme.of(
        context,
      ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
