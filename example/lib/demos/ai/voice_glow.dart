import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry voiceGlowEntry = ComponentEntry(
  id: 'voice-glow',
  name: 'Voice Glow',
  category: Categories.ai,
  summary:
      'A sound reactive glow that rises from the bottom edge of a chat '
      'composer or voice screen while the user speaks.',
  apis: const ['VoiceGlow', 'VoiceGlowState', 'VoiceGlowPalette'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'state',
      label: 'State',
      values: VoiceGlowState.values,
      initial: VoiceGlowState.listening,
      typeName: 'VoiceGlowState',
    ),
    SelectKnob.enumeration(
      id: 'palette',
      label: 'Palette',
      values: VoiceGlowPalette.values,
      initial: VoiceGlowPalette.colorful,
      typeName: 'VoiceGlowPalette',
    ),
    const SliderKnob(
      id: 'strength',
      label: 'Strength',
      min: 0.2,
      max: 2,
      initial: 1,
      divisions: 18,
    ),
    const SliderKnob(
      id: 'reach',
      label: 'Reach',
      min: 0.4,
      max: 2.4,
      initial: 1.2,
      divisions: 20,
      help: 'How high the glow rises with the voice.',
    ),
    const ToggleKnob(
      id: 'speech',
      label: 'Simulate speech',
      initial: true,
      help: 'Feeds a fake microphone level into the glow.',
    ),
  ],
  preview: (context, knobs) => _VoiceGlowDemo(knobs: knobs),
  thumbnail: (context) => const _VoiceGlowThumb(),
  code: (knobs) => dartCall('VoiceGlow', {
    'levelListenable': 'micLevel',
    'state': knobs.arg('state'),
    'palette': knobs.arg('palette'),
    'strength': knobs.arg('strength'),
    'reach': knobs.arg('reach'),
    'borderRadius': 'BorderRadius.circular(24)',
    'child': 'const ChatComposer()',
  }),
  notes: const [
    'The widget never touches the microphone: compute a loudness between 0 '
        'and 1 in your audio code and pass it as level, or push it through '
        'levelListenable to update every frame without rebuilding.',
    'The glow is decorative. It ignores pointers and adds no semantics, so '
        'the composer keeps its own labels and hit testing.',
    'Under reduced motion the breathing, drift, beam sweep and hue drift '
        'stop, but the glow still follows the level. With enabled set to '
        'false a static idle frame is shown.',
  ],
  stageHeight: 400,
);

/// A speech-like loudness between 0 and 1 at time [t] in seconds: phrases
/// with pauses, and syllables inside each phrase.
double _speechLevel(double t, math.Random random) {
  final double phrase = ((math.sin(t * 0.9) + 0.35) / 0.5).clamp(0.0, 1.0);
  final double syllable = 0.5 + 0.5 * math.sin(t * 11 + math.sin(t * 3) * 2);
  final double jitter = 0.85 + random.nextDouble() * 0.3;
  return (phrase * (0.2 + 0.7 * syllable) * jitter).clamp(0.0, 1.0);
}

class _VoiceGlowDemo extends StatefulWidget {
  const _VoiceGlowDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_VoiceGlowDemo> createState() => _VoiceGlowDemoState();
}

class _VoiceGlowDemoState extends State<_VoiceGlowDemo> {
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  final math.Random _random = math.Random(7);
  late final Timer _timer;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  void _tick() {
    _t += 0.06;
    final bool speaking =
        widget.knobs.flag('speech') &&
        widget.knobs.pick<VoiceGlowState>('state') == VoiceGlowState.listening;
    final double target = speaking ? _speechLevel(_t, _random) : 0;
    _level.value = _level.value + (target - _level.value) * 0.45;
  }

  @override
  void dispose() {
    _timer.cancel();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final VoiceGlowState state = widget.knobs.pick('state');
    final bool hasTranscript =
        state == VoiceGlowState.listening || state == VoiceGlowState.processing;
    final String status = switch (state) {
      VoiceGlowState.idle => 'Tap the mic and start talking',
      VoiceGlowState.listening => 'Listening',
      VoiceGlowState.processing => 'Finding places near you',
      VoiceGlowState.off => 'Voice is off',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceGlow(
            levelListenable: _level,
            state: state,
            palette: widget.knobs.pick('palette'),
            strength: widget.knobs.number('strength'),
            reach: widget.knobs.number('reach'),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasTranscript
                        ? 'Find a quiet cafe near the station with good wifi'
                        : 'Ask anything',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: state == VoiceGlowState.listening
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(20),
                  Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                      const Gap(14),
                      Icon(
                        Icons.language_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state == VoiceGlowState.listening
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                        ),
                        child: Icon(
                          state == VoiceGlowState.off
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          size: 20,
                          color: state == VoiceGlowState.listening
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Gap(14),
          DemoCaption(status),
        ],
      ),
    );
  }
}

class _VoiceGlowThumb extends StatelessWidget {
  const _VoiceGlowThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return VoiceGlow(
      level: 0.6,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 300,
        height: 56,
        padding: const EdgeInsets.only(left: 20, right: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Listening...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
              ),
              child: Icon(Icons.mic_rounded, size: 20, color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
