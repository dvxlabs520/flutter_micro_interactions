import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry scrubFieldEntry = ComponentEntry(
  id: 'scrub-field',
  name: 'Scrub Field',
  category: Categories.controls,
  summary:
      'A compact number chip, like the ones in design tools: drag sideways '
      'to scrub the value, or tap to type an exact number. Past a limit it '
      'stretches like a rubber band.',
  apis: const ['ScrubField'],
  tags: const [ComponentTag.newly, ComponentTag.gesture, ComponentTag.pointer],
  knobs: [
    const SliderKnob(
      id: 'sensitivity',
      label: 'Sensitivity',
      min: 1,
      max: 12,
      initial: 4,
      divisions: 11,
      help: 'Pixels of drag per step. Lower scrubs faster.',
    ),
    const SliderKnob(
      id: 'maxOvershoot',
      label: 'Max overshoot',
      min: 0,
      max: 40,
      initial: 18,
      divisions: 8,
      help: 'How far the chip stretches past a limit. 0 turns it off.',
    ),
    const SliderKnob(
      id: 'radius',
      label: 'Corner radius',
      min: 2,
      max: 12,
      initial: 8,
      divisions: 10,
      codeOf: _radiusCode,
    ),
    const ColorKnob(
      id: 'accentColor',
      label: 'Accent color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _ScrubFieldDemo(knobs: knobs),
  thumbnail: (context) => const _ScrubThumb(),
  code: (knobs) {
    final String call = dartCall('ScrubField', {
      'label': "'W'",
      'suffix': "'px'",
      'value': '_width',
      'min': '1',
      'max': '1200',
      'onChanged': '(double v) => setState(() => _width = v)',
      'sensitivity': knobs.arg('sensitivity'),
      'maxOvershoot': knobs.arg('maxOvershoot'),
      'borderRadius': knobs.arg('radius'),
      'accentColor': knobs.arg('accentColor'),
    });
    return 'double _width = 240;\n\n$call';
  },
  stageHeight: 480,
  notes: const [
    'Exposed as an adjustable control with its formatted value and the '
        'values one step up and down; activating it opens the text field.',
    'When focused the arrow keys step the value (Shift for ten steps) and '
        'Enter or Space starts typing. Enter or blur commits, Escape cancels. '
        'On desktop the cursor shows a resize arrow.',
    'Under reduced motion there is no rubber band: the value simply stops '
        'at the limit.',
  ],
);

String _radiusCode(double v) =>
    'const BorderRadius.all(Radius.circular(${v.round()}))';

class _ScrubFieldDemo extends StatefulWidget {
  const _ScrubFieldDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ScrubFieldDemo> createState() => _ScrubFieldDemoState();
}

class _ScrubFieldDemoState extends State<_ScrubFieldDemo> {
  double _w = 240;
  double _h = 160;
  double _radius = 16;
  double _rotation = 0;
  double _opacity = 100;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = knobs.color('accentColor') ?? scheme.primary;

    Widget field({
      required String label,
      required double value,
      required ValueChanged<double> onChanged,
      required double min,
      required double max,
      String? suffix,
    }) {
      return ScrubField(
        label: label,
        suffix: suffix,
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        sensitivity: knobs.number('sensitivity'),
        maxOvershoot: knobs.number('maxOvershoot'),
        borderRadius: BorderRadius.all(Radius.circular(knobs.number('radius'))),
        accentColor: knobs.color('accentColor'),
        backgroundColor: scheme.surface,
      );
    }

    // The frame is drawn at 40 percent of its size inside a fixed canvas.
    const double scale = 0.4;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.rotate(
                  angle: _rotation * math.pi / 180,
                  child: Opacity(
                    opacity: _opacity / 100,
                    child: Container(
                      width: _w * scale,
                      height: _h * scale,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(_radius * scale),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'FRAME',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: field(
                    label: 'W',
                    value: _w,
                    min: 1,
                    max: 600,
                    onChanged: (v) => setState(() => _w = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: field(
                    label: 'H',
                    value: _h,
                    min: 1,
                    max: 360,
                    onChanged: (v) => setState(() => _h = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: field(
                    label: 'R',
                    suffix: '°',
                    value: _rotation,
                    min: -180,
                    max: 180,
                    onChanged: (v) => setState(() => _rotation = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: field(
                    label: 'Radius',
                    value: _radius,
                    min: 0,
                    max: 80,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            field(
              label: 'Opacity',
              suffix: '%',
              value: _opacity,
              min: 0,
              max: 100,
              onChanged: (v) => setState(() => _opacity = v),
            ),
            const SizedBox(height: 10),
            const DemoCaption('Drag a field sideways, or tap it to type'),
          ],
        ),
      ),
    );
  }
}

class _ScrubThumb extends StatefulWidget {
  const _ScrubThumb();

  @override
  State<_ScrubThumb> createState() => _ScrubThumbState();
}

class _ScrubThumbState extends State<_ScrubThumb> {
  Timer? _timer;
  double _w = 240;
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        _w += 4.0 * _dir;
        if (_w >= 320 || _w <= 180) _dir = -_dir;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrubField(label: 'W', value: _w, onChanged: (_) {}, width: 104),
        const SizedBox(width: 8),
        ScrubField(label: 'H', value: 160, onChanged: (_) {}, width: 104),
        const SizedBox(width: 8),
        ScrubField(
          label: 'Opacity',
          suffix: '%',
          value: 100,
          onChanged: (_) {},
        ),
      ],
    );
  }
}
