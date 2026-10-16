import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry rotatingTextEntry = ComponentEntry(
  id: 'rotating-text',
  name: 'Rotating Text',
  category: Categories.text,
  summary:
      'A word that cycles through phrases, each letter sliding out of a mask '
      'in turn. Made for hero headlines.',
  apis: const [
    'RotatingText',
    'RotatingTextController',
    'RotatingTextSplit',
    'RotatingTextStaggerFrom',
  ],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'staggerFrom',
      label: 'Stagger from',
      values: RotatingTextStaggerFrom.values,
      initial: RotatingTextStaggerFrom.first,
      typeName: 'RotatingTextStaggerFrom',
    ),
    SelectKnob.enumeration(
      id: 'split',
      label: 'Split by',
      values: RotatingTextSplit.values,
      initial: RotatingTextSplit.characters,
      typeName: 'RotatingTextSplit',
    ),
    const SliderKnob.duration(
      id: 'interval',
      label: 'Interval',
      min: 800,
      max: 4000,
      initial: 2000,
      divisions: 16,
      help: 'Time each phrase stays on screen.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 1200,
      initial: 500,
      divisions: 10,
      help: 'How long each letter takes to slide.',
    ),
  ],
  preview: (context, knobs) => _RotatingDemo(knobs: knobs),
  thumbnail: (context) => const _RotatingHeadline(),
  code: (knobs) => dartCall('Row', {
    'mainAxisSize': 'MainAxisSize.min',
    'children': dartList([
      "const Text('Build ')",
      dartCall('RotatingText', {
        'texts': "const ['faster', 'smoother', 'together']",
        'staggerFrom': knobs.arg('staggerFrom'),
        'splitBy': knobs.arg('split'),
        'interval': knobs.arg('interval'),
        'duration': knobs.arg('duration'),
        'style': 'Theme.of(context).textTheme.headlineMedium',
      }),
    ]),
  }),
  notes: const [
    'The current phrase is the semantics label. It is not a live region, so '
        'screen readers are not interrupted on every change.',
    'Under reduced motion phrases still change every interval, because the '
        'content is informative, but each change is instant.',
    'With enabled set to false nothing rotates on its own; a '
        'RotatingTextController can still switch phrases.',
  ],
  stageHeight: 380,
);

const List<String> _words = ['faster', 'smoother', 'together'];

class _RotatingDemo extends StatelessWidget {
  const _RotatingDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RotatingHeadline(
          staggerFrom: knobs.pick('staggerFrom'),
          split: knobs.pick('split'),
          interval: knobs.ms('interval'),
          duration: knobs.ms('duration'),
        ),
        const Gap(16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'The component library for teams that care about the details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
        const Gap(24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => demoToast(context, 'Welcome aboard'),
              child: const Text('Get started'),
            ),
            OutlinedButton(
              onPressed: () => demoToast(context, 'Opening the docs'),
              child: const Text('Read the docs'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RotatingHeadline extends StatelessWidget {
  const _RotatingHeadline({
    this.staggerFrom = RotatingTextStaggerFrom.first,
    this.split = RotatingTextSplit.characters,
    this.interval = const Duration(milliseconds: 2000),
    this.duration = const Duration(milliseconds: 500),
  });

  final RotatingTextStaggerFrom staggerFrom;
  final RotatingTextSplit split;
  final Duration interval;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? style = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Build', style: style),
        const Gap(10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: RotatingText(
            texts: _words,
            staggerFrom: staggerFrom,
            splitBy: split,
            interval: interval,
            duration: duration,
            style: style?.copyWith(color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
