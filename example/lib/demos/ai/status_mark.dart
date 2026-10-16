import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry statusMarkEntry = ComponentEntry(
  id: 'status-mark',
  name: 'Status Mark',
  category: Categories.ai,
  summary:
      'One small glyph that morphs between idle, loading, success and '
      'error, for task lists, tool calls and deploy steps.',
  apis: const ['StatusMark', 'MicroStatus'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'status',
      label: 'Status',
      values: MicroStatus.values,
      initial: MicroStatus.loading,
      typeName: 'MicroStatus',
      help: 'Any state can follow any other; every change animates.',
    ),
    const SliderKnob(
      id: 'size',
      label: 'Size',
      min: 16,
      max: 72,
      initial: 48,
      divisions: 14,
    ),
    const SliderKnob(
      id: 'strokeWidth',
      label: 'Stroke width',
      min: 1,
      max: 6,
      initial: 3,
      divisions: 10,
    ),
  ],
  preview: (context, knobs) => _StatusMarkDemo(knobs: knobs),
  thumbnail: (context) => const _StatusThumb(),
  code: (knobs) => dartCall('StatusMark', {
    'status': knobs.code('status'),
    'size': knobs.code('size'),
    'strokeWidth': knobs.code('strokeWidth'),
  }),
  notes: const [
    'The glyph is one semantics node labelled Idle, Loading, Done or Failed '
        '(or semanticLabel). A determinate progress is also exposed as a '
        'percentage.',
    'Going to error draws a cross and gives the glyph a short horizontal '
        'shake. Setting progress while loading makes the arc determinate.',
    'Under reduced motion, or with enabled set to false, the loading arc '
        'stops rotating (a static three-quarter arc) and every transition '
        'jumps to its final frame.',
  ],
  stageHeight: 500,
);

const List<(String, String)> _tasks = [
  ('Install dependencies', '14s'),
  ('Run tests', '41s'),
  ('Build web bundle', '1m 2s'),
  ('Upload to CDN', '9s'),
];

class _StatusMarkDemo extends StatefulWidget {
  const _StatusMarkDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_StatusMarkDemo> createState() => _StatusMarkDemoState();
}

class _StatusMarkDemoState extends State<_StatusMarkDemo> {
  final List<MicroStatus> _statuses = List.filled(
    _tasks.length,
    MicroStatus.idle,
  );
  late final Timer _timer;
  int _run = 128;
  int _current = 0;
  int _rest = 0;

  /// Every second run fails at the tests, to show the error state.
  bool get _failingRun => _run.isOdd;

  bool get _finished =>
      _current >= _tasks.length || _statuses.contains(MicroStatus.error);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(_advance);
    });
  }

  /// Moves the pipeline one step: idle to loading, loading to done, and a
  /// new run after a short rest once everything has finished.
  void _advance() {
    if (_finished) {
      if (++_rest < 3) return;
      _rest = 0;
      _current = 0;
      _run++;
      _statuses.fillRange(0, _statuses.length, MicroStatus.idle);
      return;
    }
    switch (_statuses[_current]) {
      case MicroStatus.idle:
        _statuses[_current] = MicroStatus.loading;
      case MicroStatus.loading:
        final bool fail = _failingRun && _current == 1;
        _statuses[_current] = fail ? MicroStatus.error : MicroStatus.success;
        if (!fail) _current++;
      case MicroStatus.success:
      case MicroStatus.error:
        _current++;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MicroStatus status = widget.knobs.pick('status');
    final bool failed = _statuses.contains(MicroStatus.error);
    final String summary = failed
        ? 'Failed'
        : _current >= _tasks.length
        ? 'Deployed'
        : 'Running';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 76,
            child: Center(
              child: StatusMark(
                status: status,
                size: widget.knobs.number('size'),
                strokeWidth: widget.knobs.number('strokeWidth'),
              ),
            ),
          ),
          const Gap(8),
          Text(
            StatusMark.defaultLabelFor(status),
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          DemoCard(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Deploy #$_run',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        summary,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: failed
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < _tasks.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        StatusMark(status: _statuses[i], size: 18),
                        const Gap(12),
                        Expanded(
                          child: Text(
                            _tasks[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _statuses[i] == MicroStatus.idle
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          switch (_statuses[i]) {
                            MicroStatus.success => _tasks[i].$2,
                            MicroStatus.error => '2 failed',
                            _ => '',
                          },
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _statuses[i] == MicroStatus.error
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusThumb extends StatelessWidget {
  const _StatusThumb();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusMark(size: 44, strokeWidth: 3),
        Gap(24),
        StatusMark(status: MicroStatus.loading, size: 44, strokeWidth: 3),
        Gap(24),
        StatusMark(status: MicroStatus.success, size: 44, strokeWidth: 3),
        Gap(24),
        StatusMark(status: MicroStatus.error, size: 44, strokeWidth: 3),
      ],
    );
  }
}
