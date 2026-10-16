import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry streamingTextEntry = ComponentEntry(
  id: 'streaming-text',
  name: 'Streaming Text',
  category: Categories.ai,
  summary:
      'Text that fades or unblurs each new word as tokens arrive, for '
      'streaming answers from a language model.',
  apis: const ['StreamingText', 'StreamingTextEffect'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: StreamingTextEffect.values,
      initial: StreamingTextEffect.fade,
      typeName: 'StreamingTextEffect',
    ),
    const SliderKnob.duration(
      id: 'wordDelay',
      label: 'Word delay',
      min: 0,
      max: 120,
      initial: 25,
      divisions: 24,
      help: 'Gap between words of one chunk, so big chunks flow in.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Word duration',
      min: 100,
      max: 1200,
      initial: 400,
      divisions: 22,
    ),
    const SliderKnob(
      id: 'blurSigma',
      label: 'Blur sigma',
      min: 0,
      max: 12,
      initial: 4,
      divisions: 12,
      help: 'Used by the blur effect.',
    ),
    const ToggleKnob(id: 'showCursor', label: 'Cursor', initial: false),
  ],
  preview: (context, knobs) => _StreamingChatDemo(knobs: knobs),
  thumbnail: (context) => const _StreamingThumb(),
  code: (knobs) {
    final String call = dartCall('StreamingText', {
      'text': 'reply',
      'isStreaming': '!done',
      'effect': knobs.arg('effect'),
      'wordDelay': knobs.arg('wordDelay'),
      'duration': knobs.arg('duration'),
      'blurSigma': knobs.arg('blurSigma'),
      'showCursor': knobs.arg('showCursor'),
      'style': 'Theme.of(context).textTheme.bodyMedium',
    });
    return '// reply grows as tokens arrive from the model\n$call';
  },
  notes: const [
    'Only newly appended words animate; text already on screen never moves. '
        'A text that does not extend the previous one animates in again.',
    'Screen readers always get the full current text, not the partly faded '
        'words.',
    'Under reduced motion, or with enabled set to false, words appear '
        'instantly and the cursor does not pulse.',
  ],
  stageHeight: 460,
);

const String _prompt = 'Can you summarize the release notes?';

const String _reply =
    'Version 2.4 adds offline sync, so drafts are saved even without a '
    'connection. Search is about twice as fast on large workspaces, and a '
    'new shortcuts panel lists every command. Two fixes stand out: images '
    'no longer flicker while scrolling, and exports keep their file names.';

class _StreamingChatDemo extends StatefulWidget {
  const _StreamingChatDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_StreamingChatDemo> createState() => _StreamingChatDemoState();
}

class _StreamingChatDemoState extends State<_StreamingChatDemo> {
  static final List<String> _words = _reply.split(' ');

  String _text = '';
  bool _streaming = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Appends one to three words every 90 ms, then waits and starts over.
  void _stream() {
    _timer?.cancel();
    int index = 0;
    _text = '';
    _streaming = true;
    _timer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) return;
      setState(() {
        final int end = math.min(_words.length, index + 1 + index % 3);
        _text = _words.sublist(0, end).join(' ');
        index = end;
        if (index >= _words.length) {
          timer.cancel();
          _streaming = false;
          _timer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(_stream);
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? style = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
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
                _prompt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const Gap(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.auto_awesome, size: 30),
              const Gap(10),
              Expanded(
                child: DemoCard(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  // The invisible full reply reserves the final height, so
                  // the bubble does not grow line by line while streaming.
                  child: Stack(
                    children: [
                      Opacity(opacity: 0, child: Text(_reply, style: style)),
                      StreamingText(
                        text: _text,
                        isStreaming: _streaming,
                        effect: widget.knobs.pick('effect'),
                        wordDelay: widget.knobs.ms('wordDelay'),
                        duration: widget.knobs.ms('duration'),
                        blurSigma: widget.knobs.number('blurSigma'),
                        showCursor: widget.knobs.flag('showCursor'),
                        style: style,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(_stream),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Stream again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingThumb extends StatelessWidget {
  const _StreamingThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.auto_awesome, size: 28),
          const Gap(10),
          Expanded(
            child: DemoCard(
              padding: const EdgeInsets.all(12),
              radius: 14,
              child: StreamingText(
                text:
                    'Version 2.4 adds offline sync, so drafts are saved '
                    'even without a connection.',
                showCursor: true,
                effect: StreamingTextEffect.blur,
                wordDelay: const Duration(milliseconds: 80),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
