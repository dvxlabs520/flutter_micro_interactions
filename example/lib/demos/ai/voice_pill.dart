import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry voicePillEntry = ComponentEntry(
  id: 'voice-pill',
  name: 'Voice Pill',
  category: Categories.ai,
  summary:
      'A round microphone button that swells into a recording capsule with '
      'live bars, a timer and a stop button. Fits the end of a composer.',
  apis: const ['VoicePill'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob<bool>(
      id: 'red',
      label: 'Recording color',
      options: const [false, true],
      initial: false,
      labelOf: (v) => v ? 'Error red' : 'Primary',
    ),
    const ToggleKnob(
      id: 'cancel',
      label: 'Cancel button',
      initial: true,
      help: 'Shown at the start of the capsule when onCancel is set.',
    ),
    SelectKnob<IconData>(
      id: 'stopIcon',
      label: 'Stop icon',
      options: const [Icons.stop_rounded, Icons.check_rounded],
      initial: Icons.stop_rounded,
      labelOf: (v) => v == Icons.stop_rounded ? 'Stop' : 'Check',
      codeOf: (v) => v == Icons.stop_rounded
          ? 'Icons.stop_rounded'
          : 'Icons.check_rounded',
    ),
    SliderKnob(
      id: 'barCount',
      label: 'Bars',
      min: 5,
      max: 15,
      initial: 9,
      divisions: 10,
      format: (v) => '${v.round()}',
      codeOf: (v) => '${v.round()}',
    ),
    SliderKnob(
      id: 'expandedWidth',
      label: 'Expanded width',
      min: 160,
      max: 260,
      initial: 208,
      divisions: 25,
      format: (v) => '${v.round()} px',
      codeOf: (v) => formatNumber(v.roundToDouble()),
    ),
    const ToggleKnob(id: 'enableHaptics', label: 'Haptics', initial: false),
  ],
  preview: (context, knobs) => _ComposerDemo(knobs: knobs),
  thumbnail: (context) => const _VoicePillThumb(),
  code: (knobs) {
    final bool red = knobs.pick<bool>('red');
    return dartCall('VoicePill', {
      'recording': 'isRecording',
      'onChanged': '(bool value) => setState(() => isRecording = value)',
      'onCancel': knobs.flag('cancel') ? 'discardRecording' : null,
      'levelListenable': 'micLevel',
      'recordingColor': red ? 'Theme.of(context).colorScheme.error' : null,
      'recordingForegroundColor': red
          ? 'Theme.of(context).colorScheme.onError'
          : null,
      'stopIcon': knobs.arg('stopIcon'),
      'barCount': knobs.arg('barCount'),
      'expandedWidth': knobs.arg('expandedWidth'),
      'enableHaptics': knobs.arg('enableHaptics'),
    });
  },
  notes: const [
    'The main button is announced as Start recording or Stop recording and '
        'is focusable: Enter or Space activates it. While recording, the '
        'timer is exposed as Recording with the time as its value.',
    'The widget records nothing itself: it calls onChanged and the parent '
        'decides by rebuilding with a new recording value. Feed the bars '
        'from your own audio stack through level or levelListenable.',
    'Under reduced motion, or with enabled set to false, the capsule opens '
        'and closes instantly with no spring or squash, and the bars show the '
        'level directly. Haptics are off unless enableHaptics is set.',
  ],
  stageHeight: 440,
);

/// A speech-like loudness between 0 and 1 at time [t] in seconds.
double _speechLevel(double t, math.Random random) {
  final double phrase = ((math.sin(t * 0.9) + 0.35) / 0.5).clamp(0.0, 1.0);
  final double syllable = 0.5 + 0.5 * math.sin(t * 11 + math.sin(t * 3) * 2);
  final double jitter = 0.85 + random.nextDouble() * 0.3;
  return (phrase * (0.2 + 0.7 * syllable) * jitter).clamp(0.0, 1.0);
}

class _ComposerDemo extends StatefulWidget {
  const _ComposerDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ComposerDemo> createState() => _ComposerDemoState();
}

class _ComposerDemoState extends State<_ComposerDemo> {
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  final math.Random _random = math.Random(5);
  final Stopwatch _stopwatch = Stopwatch();
  final List<Duration> _notes = [];
  Timer? _levelTimer;
  bool _recording = false;

  @override
  void dispose() {
    _levelTimer?.cancel();
    _level.dispose();
    super.dispose();
  }

  void _setRecording(bool value) {
    setState(() {
      _recording = value;
      if (value) {
        _stopwatch
          ..reset()
          ..start();
        _levelTimer?.cancel();
        _levelTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
          final double t = _stopwatch.elapsedMilliseconds / 1000;
          final double target = _speechLevel(t, _random);
          _level.value = _level.value + (target - _level.value) * 0.5;
        });
      } else {
        _stopwatch.stop();
        _levelTimer?.cancel();
        _level.value = 0;
        final Duration length = _stopwatch.elapsed;
        _notes.add(
          length < const Duration(seconds: 1)
              ? const Duration(seconds: 1)
              : length,
        );
        if (_notes.length > 2) _notes.removeAt(0);
      }
    });
  }

  void _cancel() {
    setState(() {
      _recording = false;
      _stopwatch.stop();
      _levelTimer?.cancel();
      _level.value = 0;
    });
    demoToast(context, 'Recording discarded');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool red = widget.knobs.pick<bool>('red');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bubble(
            mine: false,
            child: Text(
              'Want me to draft the reply to Maya? Just tell me what to say.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          for (final Duration note in _notes) ...[
            const Gap(10),
            _Bubble(mine: true, child: _VoiceNote(length: note)),
          ],
          const Gap(18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _recording ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                VoicePill(
                  recording: _recording,
                  onChanged: _setRecording,
                  onCancel: widget.knobs.flag('cancel') ? _cancel : null,
                  levelListenable: _level,
                  recordingColor: red ? scheme.error : null,
                  recordingForegroundColor: red ? scheme.onError : null,
                  stopIcon: widget.knobs.pick<IconData>('stopIcon'),
                  barCount: widget.knobs.number('barCount').round(),
                  expandedWidth: widget.knobs.number('expandedWidth'),
                  enableHaptics: widget.knobs.flag('enableHaptics'),
                ),
              ],
            ),
          ),
          const Gap(12),
          DemoCaption(
            _recording
                ? 'Talk, then tap stop to send'
                : 'Tap the microphone to record a voice note',
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child});

  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: scheme.outlineVariant),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _VoiceNote extends StatelessWidget {
  const _VoiceNote({required this.length});

  final Duration length;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow_rounded, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        VoiceWaveform(
          level: 0.45,
          barCount: 12,
          maxHeight: 18,
          color: scheme.primary,
          enabled: false,
          semanticLabel: 'Voice note',
        ),
        const SizedBox(width: 10),
        Text(
          VoicePill.formatElapsed(length),
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VoicePillThumb extends StatelessWidget {
  const _VoicePillThumb();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VoicePill(recording: false, onChanged: (_) {}),
        const SizedBox(width: 16),
        VoicePill(
          recording: true,
          onChanged: (_) {},
          onCancel: () {},
          level: 0.6,
          elapsed: const Duration(seconds: 12),
        ),
      ],
    );
  }
}
