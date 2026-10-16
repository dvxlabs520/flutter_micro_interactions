import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry wakeSliderEntry = ComponentEntry(
  id: 'wake-slider',
  name: 'Wake Slider',
  category: Categories.controls,
  summary:
      'A thumbless slider drawn as a row of thin bars. Dragging fast raises '
      'a wake behind the handle that settles like water, which suits volume, '
      'brightness and other media controls.',
  apis: const ['WakeSlider'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    const SliderKnob(
      id: 'bars',
      label: 'Bars',
      min: 12,
      max: 48,
      initial: 32,
      divisions: 36,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'height',
      label: 'Height',
      min: 24,
      max: 64,
      initial: 40,
      divisions: 10,
    ),
    const SliderKnob(
      id: 'gap',
      label: 'Gap',
      min: 1,
      max: 6,
      initial: 3,
      divisions: 10,
    ),
    const SliderKnob(
      id: 'wakeStrength',
      label: 'Wake strength',
      min: 0,
      max: 2.5,
      initial: 1,
      divisions: 10,
      help: 'Drag quickly to see it. 0 turns the wake off.',
    ),
    const ToggleKnob(
      id: 'steps',
      label: 'Snap to 10 steps',
      initial: false,
      help: 'Sets divisions: 10, with a haptic tick per step.',
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _WakeSliderDemo(knobs: knobs),
  thumbnail: (context) => const _WakeThumb(),
  code: (knobs) {
    final bool steps = knobs.flag('steps');
    final String call = dartCall('WakeSlider', {
      'value': '_volume',
      'onChanged': '(double v) => setState(() => _volume = v)',
      'bars': knobs.arg('bars'),
      'height': knobs.arg('height'),
      'gap': knobs.arg('gap'),
      'wakeStrength': knobs.arg('wakeStrength'),
      if (steps) 'divisions': '10',
      if (steps) 'enableHaptics': 'true',
      'activeColor': knobs.arg('activeColor'),
      'semanticLabel': "'Volume'",
    });
    return 'double _volume = 0.6;\n\n$call';
  },
  notes: const [
    'Exposed as a slider with its formatted value (a percentage by default, '
        'or semanticFormatterCallback) and increase and decrease actions.',
    'When focused the arrow keys step the value, Page Up and Page Down take '
        'larger steps, and Home and End jump to the ends.',
    'Under reduced motion the handle moves directly to the new value and no '
        'wake is raised.',
  ],
);

String _int(double v) => '${v.round()}';

class _WakeSliderDemo extends StatefulWidget {
  const _WakeSliderDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_WakeSliderDemo> createState() => _WakeSliderDemoState();
}

class _WakeSliderDemoState extends State<_WakeSliderDemo> {
  double _volume = 0.6;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool steps = knobs.flag('steps');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const Image(
                    image: GeneratedImage(
                      style: SceneStyle.aurora,
                      seed: 7,
                      width: 160,
                      height: 160,
                    ),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Low Tide',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Harbor Lights',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.pause_rounded, color: scheme.onSurface),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  _volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_down_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WakeSlider(
                    value: _volume,
                    onChanged: (double v) => setState(() => _volume = v),
                    bars: knobs.number('bars').round(),
                    height: knobs.number('height'),
                    gap: knobs.number('gap'),
                    wakeStrength: knobs.number('wakeStrength'),
                    divisions: steps ? 10 : null,
                    enableHaptics: steps,
                    activeColor: knobs.color('activeColor'),
                    semanticLabel: 'Volume',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(_volume * 100).round()}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WakeThumb extends StatefulWidget {
  const _WakeThumb();

  @override
  State<_WakeThumb> createState() => _WakeThumbState();
}

class _WakeThumbState extends State<_WakeThumb> {
  static const List<double> _stops = [0.25, 0.8, 0.45, 0.95, 0.6];
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1400),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Icon(
            Icons.volume_down_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: WakeSlider(
              value: _stops[_tick % _stops.length],
              onChanged: (_) {},
              wakeStrength: 1.6,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.volume_up_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
