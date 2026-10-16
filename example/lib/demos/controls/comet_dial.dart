import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry cometDialEntry = ComponentEntry(
  id: 'comet-dial',
  name: 'Comet Dial',
  category: Categories.controls,
  summary:
      'A round dial you turn by angle like a physical knob, and can flick so '
      'it keeps spinning. A comet streak trails the lit head. Use it for a '
      'thermostat, a timer or any value with a wide range.',
  apis: const ['CometDial', 'CometDialCenterBuilder'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    SelectKnob<String>(
      id: 'variant',
      label: 'Example',
      options: const ['thermostat', 'timer'],
      initial: 'thermostat',
      labelOf: (v) => v == 'thermostat' ? 'Thermostat' : 'Timer',
    ),
    const SliderKnob(
      id: 'ticks',
      label: 'Ticks',
      min: 24,
      max: 96,
      initial: 60,
      divisions: 18,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'sweep',
      label: 'Sweep angle',
      min: 180,
      max: 360,
      initial: 300,
      divisions: 12,
      format: _degrees,
      codeOf: _sweepCode,
    ),
    const SliderKnob(
      id: 'friction',
      label: 'Friction',
      min: 0.01,
      max: 0.3,
      initial: 0.03,
      divisions: 29,
      help: 'Speed left after one second of coasting. Lower stops sooner.',
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _CometDialDemo(knobs: knobs),
  thumbnail: (context) => const _CometThumb(),
  code: (knobs) {
    final bool timer = knobs.pick<String>('variant') == 'timer';
    final String call = dartCall('CometDial', {
      'value': timer ? '_minutes' : '_target',
      'onChanged': timer
          ? '(double v) => setState(() => _minutes = v)'
          : '(double v) => setState(() => _target = v)',
      'min': timer ? null : '10',
      'max': timer ? '60' : '30',
      'divisions': timer ? '60' : '40',
      'ticks': knobs.arg('ticks'),
      'sweepAngle': knobs.arg('sweep'),
      'friction': knobs.arg('friction'),
      'activeColor': knobs.arg('activeColor'),
      'semanticLabel': timer ? "'Timer'" : "'Target temperature'",
      'semanticFormatterCallback': timer
          ? "(double v) => '\${v.round()} min'"
          : "(double v) => '\${v.toStringAsFixed(1)}°'",
    });
    final String state = timer
        ? 'double _minutes = 25;'
        : 'double _target = 21.5;';
    final String import = knobs.isDefault('sweep')
        ? ''
        : "import 'dart:math' as math;\n\n";
    return '$import$state\n\n$call';
  },
  notes: const [
    'Exposed as a slider with its formatted value and increase and decrease '
        'actions. The center content is decorative for assistive technology.',
    'When focused the arrow keys step the value, Page Up and Page Down take '
        'larger steps, and Home and End jump to min and max.',
    'Under reduced motion the head moves directly to the value, there is no '
        'comet streak, and flicks stop where the finger leaves.',
  ],
);

String _int(double v) => '${v.round()}';
String _degrees(double v) => '${v.round()}°';
String _sweepCode(double v) => '${v.round()} * math.pi / 180';

class _CometDialDemo extends StatefulWidget {
  const _CometDialDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CometDialDemo> createState() => _CometDialDemoState();
}

class _CometDialDemoState extends State<_CometDialDemo> {
  double _target = 21.5;
  double _minutes = 25;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool timer = knobs.pick<String>('variant') == 'timer';
    final Color? active = knobs.color('activeColor');
    final double sweep = knobs.number('sweep') * math.pi / 180;

    final Widget dial = timer
        ? CometDial(
            value: _minutes,
            onChanged: (double v) => setState(() => _minutes = v),
            max: 60,
            divisions: 60,
            ticks: knobs.number('ticks').round(),
            sweepAngle: sweep,
            friction: knobs.number('friction'),
            activeColor: active,
            semanticLabel: 'Timer',
            semanticFormatterCallback: (double v) => '${v.round()} min',
            centerBuilder: (context, v) => _Center(
              value: '${v.round()}',
              unit: 'min',
              caption: 'Focus session',
            ),
          )
        : CometDial(
            value: _target,
            onChanged: (double v) => setState(() => _target = v),
            min: 10,
            max: 30,
            divisions: 40,
            ticks: knobs.number('ticks').round(),
            sweepAngle: sweep,
            friction: knobs.number('friction'),
            activeColor: active,
            semanticLabel: 'Target temperature',
            semanticFormatterCallback: (double v) => '${v.toStringAsFixed(1)}°',
            centerBuilder: (context, v) => _Center(
              value: v.toStringAsFixed(1),
              unit: '°C',
              caption: v > 19 ? 'Heating' : 'Idle',
            ),
          );

    final String title = timer ? 'Timer' : 'Living room';
    final String detail = timer
        ? 'Ends at ${_endsAt(_minutes.round())}'
        : 'Now 19.0 °C  ·  Humidity 42%';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: timer ? Icons.timer_outlined : Icons.thermostat_rounded,
                  size: 32,
                  color: active,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            dial,
            const SizedBox(height: 8),
            const DemoCaption('Drag around the dial, or flick it'),
          ],
        ),
      ),
    );
  }

  static String _endsAt(int minutes) {
    final int total = 14 * 60 + 10 + minutes;
    final int h = (total ~/ 60) % 24;
    final int m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _Center extends StatelessWidget {
  const _Center({
    required this.value,
    required this.unit,
    required this.caption,
  });

  final String value;
  final String unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                unit,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CometThumb extends StatefulWidget {
  const _CometThumb();

  @override
  State<_CometThumb> createState() => _CometThumbState();
}

class _CometThumbState extends State<_CometThumb> {
  static const List<double> _stops = [72, 28, 88, 45];
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1600),
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
    return CometDial(
      value: _stops[_tick % _stops.length],
      onChanged: (_) {},
      size: 150,
      ticks: 48,
    );
  }
}
