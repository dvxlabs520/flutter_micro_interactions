import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry thinkingStepsEntry = ComponentEntry(
  id: 'thinking-steps',
  name: 'Thinking Steps',
  category: Categories.ai,
  summary:
      'A live reasoning trace for agents: steps with status marks, a '
      'running clock, and a header that collapses once the work is done.',
  apis: const ['ThinkingSteps', 'ThinkingStep', 'MicroStatus'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    const ToggleKnob(
      id: 'collapseWhenDone',
      label: 'Collapse when done',
      initial: true,
      help: 'Folds the steps into the header once thinking ends.',
    ),
    const SliderKnob.duration(
      id: 'stepTime',
      label: 'Step time',
      min: 300,
      max: 2000,
      initial: 900,
      divisions: 17,
      help: 'How long the simulated agent spends on each step.',
    ),
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Answer effect',
      values: StreamingTextEffect.values,
      initial: StreamingTextEffect.fade,
      typeName: 'StreamingTextEffect',
    ),
    const SliderKnob(
      id: 'markSize',
      label: 'Mark size',
      min: 12,
      max: 24,
      initial: 16,
      divisions: 6,
    ),
  ],
  preview: (context, knobs) => _AgentRunDemo(knobs: knobs),
  thumbnail: (context) => const _StepsThumb(),
  code: (knobs) {
    final String steps = dartList([
      "ThinkingStep(title: 'Reading the question', "
          'status: MicroStatus.success)',
      "ThinkingStep(title: 'Searching the docs', "
          "detail: 'motion.dart', status: MicroStatus.loading)",
      "ThinkingStep(title: 'Writing the answer')",
    ]);
    return dartCall('BorderBeam', {
      'active': 'working',
      'borderRadius': 'BorderRadius.circular(16)',
      'child': dartCall('Column', {
        'crossAxisAlignment': 'CrossAxisAlignment.start',
        'children': dartList([
          dartCall('ThinkingSteps', {
            'isThinking': 'thinking',
            'collapseWhenDone': knobs.arg('collapseWhenDone'),
            'markSize': knobs.arg('markSize'),
            'steps': steps,
          }),
          dartCall('StreamingText', {
            'text': 'answer',
            'isStreaming': 'streaming',
            'showCursor': 'true',
            'effect': knobs.arg('effect'),
          }),
        ]),
      }),
    });
  },
  notes: const [
    'The header is a focusable button: Enter or Space expands or collapses '
        'the steps, and its expanded state is exposed to screen readers.',
    'Each step is announced as its title, its status (Pending, In progress, '
        'Done or Failed) and its detail. Collapsed steps are hidden from '
        'assistive technology.',
    'Under reduced motion there is no shimmer and expanding, collapsing and '
        'step entrances jump to their final state; the clock still ticks.',
  ],
  stageHeight: 540,
);

const String _question = 'How do I respect reduced motion in Flutter?';

const String _answer =
    'Read MediaQuery.disableAnimations, or wrap your app in MicroMotion, '
    'and skip to the final frame when it is set. Keep the change of state '
    'visible: swap the content instantly instead of hiding it, so people '
    'still see what happened.';

const List<(String, String?)> _plan = [
  ('Reading the question', null),
  ('Searching the docs', 'motion.dart, media_query.dart'),
  ('Comparing approaches', '3 options'),
  ('Writing the answer', null),
];

enum _Phase { thinking, streaming, done }

class _AgentRunDemo extends StatefulWidget {
  const _AgentRunDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_AgentRunDemo> createState() => _AgentRunDemoState();
}

class _AgentRunDemoState extends State<_AgentRunDemo> {
  final List<ThinkingStep> _steps = [];
  _Phase _phase = _Phase.thinking;
  String _streamed = '';
  Timer? _timer;

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
    _steps.clear();
    _streamed = '';
    _phase = _Phase.thinking;
    _scheduleStep(0, first: true);
  }

  void _restart() => setState(_start);

  /// Marks the previous step done and starts step [index], one step time
  /// apart, then streams the answer.
  void _scheduleStep(int index, {bool first = false}) {
    final Duration wait = first
        ? const Duration(milliseconds: 400)
        : widget.knobs.ms('stepTime');
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {
        if (_steps.isNotEmpty) {
          final ThinkingStep last = _steps.removeLast();
          _steps.add(
            ThinkingStep(
              title: last.title,
              detail: last.detail,
              status: MicroStatus.success,
            ),
          );
        }
        if (index < _plan.length) {
          final (String title, String? detail) = _plan[index];
          _steps.add(
            ThinkingStep(
              title: title,
              detail: detail,
              status: MicroStatus.loading,
            ),
          );
          _scheduleStep(index + 1);
        } else {
          _phase = _Phase.streaming;
          _streamAnswer();
        }
      });
    });
  }

  /// Appends one to three words at a time, like tokens from a model.
  void _streamAnswer() {
    final List<String> words = _answer.split(' ');
    int index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (!mounted) return;
      setState(() {
        final int end = math.min(words.length, index + 1 + index % 3);
        _streamed = words.sublist(0, end).join(' ');
        index = end;
        if (index >= words.length) {
          _phase = _Phase.done;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool thinking = _phase == _Phase.thinking;
    final bool working = _phase != _Phase.done;
    final TextStyle? answerStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              _question,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
          const Gap(14),
          BorderBeam(
            active: working,
            borderRadius: BorderRadius.circular(16),
            child: DemoCard(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThinkingSteps(
                    steps: List.of(_steps),
                    isThinking: thinking,
                    collapseWhenDone: widget.knobs.flag('collapseWhenDone'),
                    markSize: widget.knobs.number('markSize'),
                  ),
                  if (_streamed.isNotEmpty) ...[
                    const Gap(12),
                    // The invisible full answer reserves the final height,
                    // so the card does not grow line by line.
                    Stack(
                      children: [
                        Opacity(
                          opacity: 0,
                          child: Text(_answer, style: answerStyle),
                        ),
                        StreamingText(
                          text: _streamed,
                          isStreaming: _phase == _Phase.streaming,
                          showCursor: true,
                          effect: widget.knobs.pick('effect'),
                          style: answerStyle,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Gap(16),
          Center(
            child: OutlinedButton.icon(
              onPressed: working ? null : _restart,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Run again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsThumb extends StatelessWidget {
  const _StepsThumb();

  @override
  Widget build(BuildContext context) {
    return BorderBeam(
      borderRadius: BorderRadius.circular(16),
      child: const DemoCard(
        width: 300,
        padding: EdgeInsets.all(16),
        child: ThinkingSteps(
          collapsible: false,
          steps: [
            ThinkingStep(
              title: 'Reading the question',
              status: MicroStatus.success,
            ),
            ThinkingStep(
              title: 'Searching the docs',
              status: MicroStatus.loading,
            ),
            ThinkingStep(title: 'Writing the answer'),
          ],
        ),
      ),
    );
  }
}
