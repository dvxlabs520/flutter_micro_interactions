import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry toolCallChipEntry = ComponentEntry(
  id: 'tool-call-chip',
  name: 'Tool Call Chip',
  category: Categories.ai,
  summary:
      'A compact chip for one agent tool call, with a live progress fill, '
      'a ticking timer and a status that resolves to done or failed.',
  apis: const ['ToolCallChip', 'MicroStatus'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob<bool>(
      id: 'fails',
      label: 'Outcome',
      options: const [false, true],
      initial: false,
      labelOf: (v) => v ? 'One call fails' : 'All succeed',
      help: 'Makes the third call fail, to show the error shake.',
    ),
    const ToggleKnob(
      id: 'icons',
      label: 'Tool icons',
      initial: true,
      help: 'Without an icon the chip shows a status mark in every state.',
    ),
    const SliderKnob.duration(
      id: 'estimatedDuration',
      label: 'Estimated duration',
      min: 1000,
      max: 8000,
      initial: 4000,
      divisions: 14,
      help: 'The creeping fill covers about 80 percent after this long.',
    ),
    const ToggleKnob(id: 'showTimer', label: 'Timer', initial: true),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ToolCallDemo(knobs: knobs),
  thumbnail: (context) => const _ToolCallThumb(),
  code: (knobs) {
    return dartCall('ToolCallChip', {
      'label': "'Searching the web'",
      'icon': knobs.flag('icons') ? 'Icons.public' : null,
      'status': 'done ? MicroStatus.success : MicroStatus.loading',
      'estimatedDuration': knobs.arg('estimatedDuration'),
      'showTimer': knobs.arg('showTimer'),
      'color': knobs.arg('color'),
      'detail': "const Text('motion design accessibility guidelines')",
    });
  },
  notes: const [
    'The chip is announced as its label, its status (Pending, Running, Done '
        'or Failed) and the elapsed time in whole seconds.',
    'With a detail or an onTap it becomes a focusable button: Enter or '
        'Space toggles the detail, and the expanded state is exposed. A '
        'collapsed detail is hidden from assistive technology.',
    'Under reduced motion, or with enabled set to false, there is no wipe, '
        'shimmer or shake and status changes jump to their final look. The '
        'timer still counts.',
  ],
  replayable: true,
  stageHeight: 440,
);

/// One simulated tool call: when it starts and how long it runs, in tenths
/// of a second from the start of the run.
class _Call {
  const _Call({
    required this.label,
    required this.icon,
    required this.start,
    required this.length,
    this.detail,
    this.determinate = false,
    this.canFail = false,
  });

  final String label;
  final IconData icon;
  final int start;
  final int length;
  final String? detail;
  final bool determinate;
  final bool canFail;

  int get end => start + length;
}

const List<_Call> _calls = [
  _Call(
    label: 'Searching the web',
    icon: Icons.public,
    start: 4,
    length: 22,
    detail: 'motion design accessibility guidelines',
  ),
  _Call(
    label: 'Reading report.pdf',
    icon: Icons.description_outlined,
    start: 28,
    length: 26,
    detail: '12 pages, 4 charts',
    determinate: true,
  ),
  _Call(
    label: 'Running analysis.py',
    icon: Icons.terminal_rounded,
    start: 56,
    length: 18,
    canFail: true,
  ),
  _Call(
    label: 'Writing summary',
    icon: Icons.edit_note_rounded,
    start: 76,
    length: 16,
  ),
];

class _ToolCallDemo extends StatefulWidget {
  const _ToolCallDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ToolCallDemo> createState() => _ToolCallDemoState();
}

class _ToolCallDemoState extends State<_ToolCallDemo> {
  Timer? _timer;
  int _tick = 0;

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
    _tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() => _tick++);
      if (_tick > _calls.last.end) timer.cancel();
    });
  }

  bool get _running => _tick <= _calls.last.end;

  MicroStatus _statusOf(_Call call) {
    if (_tick < call.start) return MicroStatus.idle;
    if (_tick < call.end) return MicroStatus.loading;
    if (call.canFail && widget.knobs.pick<bool>('fails')) {
      return MicroStatus.error;
    }
    return MicroStatus.success;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool icons = widget.knobs.flag('icons');
    final bool failed =
        widget.knobs.pick<bool>('fails') && _tick >= _calls[2].end;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DemoCard(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ThinkingOrb(
                  state: _running
                      ? ThinkingOrbState.searching
                      : ThinkingOrbState.composing,
                  size: 26,
                  enabled: _running,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quarterly report review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  _running ? 'Running' : 'Done',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Gap(16),
            for (final _Call call in _calls) ...[
              ToolCallChip(
                label: call.label,
                icon: icons ? call.icon : null,
                status: _statusOf(call),
                progress:
                    call.determinate && _statusOf(call) == MicroStatus.loading
                    ? ((_tick - call.start) / call.length).clamp(0.0, 1.0)
                    : null,
                detail: call.detail == null
                    ? null
                    : Text(
                        call.detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                estimatedDuration: widget.knobs.ms('estimatedDuration'),
                showTimer: widget.knobs.flag('showTimer'),
                color: widget.knobs.color('color'),
              ),
              const Gap(8),
            ],
            const Gap(6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _running
                        ? 'Tap a chip with a chevron for details.'
                        : failed
                        ? 'Summary written without the analysis.'
                        : 'Summary ready: 4 key findings.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!_running)
                  TextButton(
                    onPressed: () => setState(_start),
                    child: const Text('Run again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCallThumb extends StatelessWidget {
  const _ToolCallThumb();

  @override
  Widget build(BuildContext context) {
    return const DemoCard(
      width: 260,
      padding: EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToolCallChip(
            label: 'Searching the web',
            icon: Icons.public,
            status: MicroStatus.success,
            elapsed: Duration(milliseconds: 2200),
          ),
          Gap(8),
          ToolCallChip(
            label: 'Reading report.pdf',
            icon: Icons.description_outlined,
            status: MicroStatus.loading,
            progress: 0.6,
            elapsed: Duration(milliseconds: 1400),
          ),
          Gap(8),
          ToolCallChip(
            label: 'Writing summary',
            icon: Icons.edit_note_rounded,
            status: MicroStatus.idle,
          ),
        ],
      ),
    );
  }
}
