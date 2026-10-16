import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry voiceWaveformEntry = ComponentEntry(
  id: 'voice-waveform',
  name: 'Voice Waveform',
  category: Categories.ai,
  summary:
      'Compact equalizer bars that follow a voice level, for recording '
      'pills and voice notes.',
  apis: const ['VoiceWaveform'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    const SliderKnob(
      id: 'barCount',
      label: 'Bars',
      min: 3,
      max: 12,
      initial: 5,
      divisions: 9,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'barWidth',
      label: 'Bar width',
      min: 2,
      max: 6,
      initial: 3,
      divisions: 8,
    ),
    const SliderKnob(
      id: 'maxHeight',
      label: 'Max height',
      min: 12,
      max: 40,
      initial: 24,
      divisions: 14,
    ),
    const ToggleKnob(
      id: 'active',
      label: 'Active',
      initial: true,
      help: 'Off collapses every bar to its resting height.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _RecordingDemo(knobs: knobs),
  thumbnail: (context) => const _WaveformThumb(),
  code: (knobs) => dartCall('VoiceWaveform', {
    'levelListenable': 'micLevel',
    'active': knobs.flag('active') ? 'isRecording' : 'false',
    'barCount': knobs.arg('barCount'),
    'barWidth': knobs.arg('barWidth'),
    'maxHeight': knobs.arg('maxHeight'),
    'color': knobs.arg('color'),
  }),
  notes: const [
    'The widget never touches the microphone: pass a loudness between 0 and '
        '1 as level, or push it through levelListenable to update every '
        'frame without rebuilding the parent.',
    'While active, the bars are announced with semanticLabel ("Recording" by '
        'default); the label is removed when active is false.',
    'Under reduced motion, or with enabled set to false, the bars show the '
        'level directly with no ripple, no per-bar movement and no ticker.',
  ],
  stageHeight: 380,
);

/// A speech-like loudness between 0 and 1 at time [t] in seconds.
double _speechLevel(double t, math.Random random) {
  final double phrase = ((math.sin(t * 0.9) + 0.35) / 0.5).clamp(0.0, 1.0);
  final double syllable = 0.5 + 0.5 * math.sin(t * 11 + math.sin(t * 3) * 2);
  final double jitter = 0.85 + random.nextDouble() * 0.3;
  return (phrase * (0.2 + 0.7 * syllable) * jitter).clamp(0.0, 1.0);
}

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _RecordingDemo extends StatefulWidget {
  const _RecordingDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_RecordingDemo> createState() => _RecordingDemoState();
}

class _RecordingDemoState extends State<_RecordingDemo> {
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  final math.Random _random = math.Random(3);
  late final Timer _levelTimer;
  Timer? _clockTimer;
  double _t = 0;
  int _seconds = 7;
  bool _recording = true;

  @override
  void initState() {
    super.initState();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _t += 0.06;
      final double target = _recording ? _speechLevel(_t, _random) : 0;
      _level.value = _level.value + (target - _level.value) * 0.5;
    });
    _startClock();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _toggle() {
    setState(() {
      _recording = !_recording;
      if (_recording) {
        _seconds = 0;
        _startClock();
      } else {
        _clockTimer?.cancel();
      }
    });
    if (!_recording) demoToast(context, 'Voice note saved');
  }

  @override
  void dispose() {
    _levelTimer.cancel();
    _clockTimer?.cancel();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool active = widget.knobs.flag('active') && _recording;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording ? scheme.error : scheme.outline,
                ),
              ),
              const Gap(10),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: _recording ? 'Recording ' : 'Voice note ',
                    children: [
                      TextSpan(
                        text: _clock(_seconds),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const Gap(16),
              VoiceWaveform(
                levelListenable: _level,
                active: active,
                barCount: widget.knobs.number('barCount').round(),
                barWidth: widget.knobs.number('barWidth'),
                maxHeight: widget.knobs.number('maxHeight'),
                color: widget.knobs.color('color'),
              ),
              const Gap(16),
              IconButton.filled(
                tooltip: _recording ? 'Stop recording' : 'Record again',
                onPressed: _toggle,
                style: IconButton.styleFrom(
                  backgroundColor: _recording ? scheme.error : scheme.primary,
                  foregroundColor: _recording
                      ? scheme.onError
                      : scheme.onPrimary,
                ),
                icon: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        DemoCaption(
          _recording ? 'Tap stop to save the note' : 'Tap the mic to record',
        ),
      ],
    );
  }
}

class _WaveformThumb extends StatelessWidget {
  const _WaveformThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.error,
            ),
          ),
          const Gap(10),
          Text('Recording 0:07', style: theme.textTheme.labelLarge),
          const Gap(16),
          const VoiceWaveform(level: 0.55, barCount: 7),
          const Gap(16),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.error,
            ),
            child: Icon(Icons.stop_rounded, size: 18, color: scheme.onError),
          ),
        ],
      ),
    );
  }
}
