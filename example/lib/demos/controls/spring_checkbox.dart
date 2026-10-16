import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

const Map<String, SpringDescription> _springs = {
  'default': SpringDescription(mass: 1, stiffness: 120, damping: 15.5),
  'snappy': SpringDescription(mass: 1, stiffness: 260, damping: 30),
  'bouncy': SpringDescription(mass: 1, stiffness: 160, damping: 9),
};

final ComponentEntry springCheckboxEntry = ComponentEntry(
  id: 'spring-checkbox',
  name: 'Spring Checkbox',
  category: Categories.controls,
  summary:
      'A checkbox row where one spring fills the box, draws the tick and '
      'strikes through the label in sequence. Made for to-do lists and '
      'checklists.',
  apis: const ['SpringCheckbox'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob<String>(
      id: 'spring',
      label: 'Spring',
      options: _springs.keys.toList(),
      initial: 'default',
      labelOf: (v) => switch (v) {
        'snappy' => 'Snappy',
        'bouncy' => 'Bouncy',
        _ => 'Default',
      },
      codeOf: (v) {
        final SpringDescription s = _springs[v]!;
        return 'const SpringDescription(mass: 1, '
            'stiffness: ${s.stiffness.round()}, damping: ${s.damping.round()})';
      },
    ),
    const ToggleKnob(
      id: 'strikeThrough',
      label: 'Strike through',
      initial: true,
    ),
    const ToggleKnob(
      id: 'selectAll',
      label: 'Select all row',
      initial: true,
      help: 'Adds a tristate parent checkbox that shows a dash when mixed.',
    ),
    const SliderKnob(
      id: 'borderRadius',
      label: 'Corner radius',
      min: 0,
      max: 11,
      initial: 6,
      divisions: 11,
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _SpringCheckboxDemo(knobs: knobs),
  thumbnail: (context) => const _CheckThumb(),
  code: (knobs) {
    final String call = dartCall('SpringCheckbox', {
      'value': '_done',
      'onChanged': '(bool? value) => setState(() => _done = value!)',
      'label': "const Text('Water the plants')",
      'spring': knobs.arg('spring'),
      'strikeThrough': knobs.arg('strikeThrough'),
      'borderRadius': knobs.arg('borderRadius'),
      'activeColor': knobs.arg('activeColor'),
    });
    final String single = 'bool _done = false;\n\n$call';
    if (!knobs.flag('selectAll')) return single;
    final String all = dartCall('SpringCheckbox', {
      'tristate': 'true',
      'value': 'allDone ? true : (noneDone ? false : null)',
      'onChanged': '(bool? value) => setAll(value ?? false)',
      'strikeThrough': 'false',
      'label': "const Text('Select all')",
      'activeColor': knobs.arg('activeColor'),
    });
    return '$single\n\n// Parent row of a list\n$all';
  },
  stageHeight: 460,
  notes: const [
    'The row is one checked, unchecked or mixed control labelled by '
        'semanticLabel or the label text. It is keyboard focusable and Enter '
        'or Space toggles it; tapping the label toggles it too.',
    'One spring drives the fill, the tick and the strike in order, so a '
        'toggle mid-animation reverses smoothly. A selection click haptic '
        'plays on toggle.',
    'Under reduced motion every change is instant.',
  ],
);

const List<String> _tasks = [
  'Reply to the design review',
  'Book a table for Friday',
  'Water the plants',
  'Renew the domain',
  'Send the invoice to Lumen',
];

class _SpringCheckboxDemo extends StatefulWidget {
  const _SpringCheckboxDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SpringCheckboxDemo> createState() => _SpringCheckboxDemoState();
}

class _SpringCheckboxDemoState extends State<_SpringCheckboxDemo> {
  final List<bool> _done = [true, false, true, false, false];

  int get _count => _done.where((d) => d).length;

  void _setAll(bool value) {
    setState(() {
      for (int i = 0; i < _done.length; i++) {
        _done[i] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SpringDescription spring = _springs[knobs.pick<String>('spring')]!;
    final double radius = knobs.number('borderRadius');
    final Color? active = knobs.color('activeColor');
    final int count = _count;
    final bool? all = count == _done.length
        ? true
        : (count == 0 ? false : null);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Today', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '$count of ${_done.length} done',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: count / _done.length),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: active ?? scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (knobs.flag('selectAll'))
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: SpringCheckbox(
                  tristate: true,
                  value: all,
                  onChanged: (bool? v) => _setAll(v ?? false),
                  strikeThrough: false,
                  spring: spring,
                  borderRadius: radius,
                  activeColor: active,
                  label: Text('Select all', style: theme.textTheme.titleSmall),
                ),
              ),
            for (int i = 0; i < _tasks.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: SpringCheckbox(
                  value: _done[i],
                  onChanged: (bool? v) => setState(() => _done[i] = v!),
                  strikeThrough: knobs.flag('strikeThrough'),
                  spring: spring,
                  borderRadius: radius,
                  activeColor: active,
                  labelStyle: theme.textTheme.bodyMedium,
                  label: Text(
                    _tasks[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckThumb extends StatefulWidget {
  const _CheckThumb();

  @override
  State<_CheckThumb> createState() => _CheckThumbState();
}

class _CheckThumbState extends State<_CheckThumb> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => setState(() => _tick++),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Checks the three rows one by one, then clears them together.
    final int phase = _tick % 5;
    return DemoCard(
      width: 250,
      showBorder: false,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 3; i++)
            SpringCheckbox(
              value: phase > i && phase < 4,
              onChanged: (_) {},
              label: Text(
                const [
                  'Book a table',
                  'Water the plants',
                  'Renew the domain',
                ][i],
              ),
            ),
        ],
      ),
    );
  }
}
