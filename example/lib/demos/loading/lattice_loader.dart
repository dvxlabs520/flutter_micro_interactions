import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry latticeLoaderEntry = ComponentEntry(
  id: 'lattice-loader',
  name: 'Lattice Loader',
  category: Categories.loading,
  summary:
      'A compact status row for long agent tasks: a small grid of cells '
      'that brighten in a diagonal wave, a label and a live stopwatch.',
  apis: const ['LatticeLoader'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    const TextKnob(id: 'label', label: 'Label', initial: 'Generating'),
    SliderKnob(
      id: 'columns',
      label: 'Columns',
      min: 2,
      max: 8,
      initial: 4,
      divisions: 6,
      format: _int,
      codeOf: _int,
    ),
    SliderKnob(
      id: 'rows',
      label: 'Rows',
      min: 1,
      max: 6,
      initial: 3,
      divisions: 5,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'cellSize',
      label: 'Cell size',
      min: 2,
      max: 10,
      initial: 4,
      divisions: 16,
    ),
    const SliderKnob(
      id: 'waveSpeed',
      label: 'Wave speed',
      min: 0.3,
      max: 2.4,
      initial: 0.9,
      divisions: 21,
      help: 'Waves crossing the lattice per second.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _LatticeDemo(knobs: knobs),
  thumbnail: (context) => const _LatticeThumb(),
  code: (knobs) {
    return dartCall('LatticeLoader', {
      'label': 'working ? ${knobs.code('label')} : ${quote('Generated in')}',
      'active': 'working',
      'columns': knobs.arg('columns'),
      'rows': knobs.arg('rows'),
      'cellSize': knobs.arg('cellSize'),
      'waveSpeed': knobs.arg('waveSpeed'),
      'color': knobs.arg('color'),
    });
  },
  notes: const [
    'The row is announced as one node: the label (or semanticLabel, Working '
        'by default) followed by the elapsed time in words. The lattice itself '
        'is decorative.',
    'Setting active to false stops the wave, dims the cells and freezes the '
        'stopwatch, which suits a Generated in 00:07 summary. Turning it back '
        'on measures again from zero.',
    'Under reduced motion, or with enabled set to false, the lattice shows a '
        'still diagonal gradient and schedules no frames; the stopwatch still '
        'counts.',
  ],
  replayable: true,
  stageHeight: 380,
);

class _LatticeDemo extends StatefulWidget {
  const _LatticeDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_LatticeDemo> createState() => _LatticeDemoState();
}

class _LatticeDemoState extends State<_LatticeDemo> {
  Timer? _timer;
  bool _working = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _working = true;
    _timer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _working = false);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String label = widget.knobs.text('label');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DemoCard(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build a landing page for a coffee roastery',
              style: theme.textTheme.titleSmall,
            ),
            const Gap(14),
            LatticeLoader(
              label: _working ? (label.isEmpty ? null : label) : 'Generated in',
              active: _working,
              columns: widget.knobs.number('columns').round(),
              rows: widget.knobs.number('rows').round(),
              cellSize: widget.knobs.number('cellSize'),
              waveSpeed: widget.knobs.number('waveSpeed'),
              color: widget.knobs.color('color'),
            ),
            const Gap(16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: _working
                  ? const _Placeholder(key: ValueKey('placeholder'))
                  : Column(
                      key: const ValueKey('result'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final String line in const [
                          'Hero with seasonal blend',
                          'Subscription pricing table',
                          'Brewing guide and FAQ',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: scheme.tertiary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const Gap(10),
            Align(
              alignment: Alignment.centerRight,
              child: _working
                  ? OutlinedButton(onPressed: _stop, child: const Text('Stop'))
                  : FilledButton(
                      onPressed: () => setState(_start),
                      child: const Text('Run again'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    final Color c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final double f in const [0.9, 0.7, 0.8])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FractionallySizedBox(
              widthFactor: f,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LatticeThumb extends StatelessWidget {
  const _LatticeThumb();

  @override
  Widget build(BuildContext context) {
    return const DemoCard(
      width: 240,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LatticeLoader(label: 'Generating', cellSize: 6, gap: 3),
          Gap(12),
          LatticeLoader(
            label: 'Generated in',
            active: false,
            cellSize: 6,
            gap: 3,
            elapsed: Duration(seconds: 7),
          ),
        ],
      ),
    );
  }
}
