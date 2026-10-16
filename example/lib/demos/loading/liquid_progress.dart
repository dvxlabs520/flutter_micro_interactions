import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry liquidProgressEntry = ComponentEntry(
  id: 'liquid-progress',
  name: 'Liquid Progress',
  category: Categories.loading,
  summary:
      'A progress indicator filled with a moving liquid wave. Fits uploads, '
      'downloads, battery and goal tracking.',
  apis: const ['LiquidProgress', 'LiquidProgressShape'],
  knobs: [
    SelectKnob.enumeration(
      id: 'shape',
      label: 'Shape',
      values: LiquidProgressShape.values,
      initial: LiquidProgressShape.circle,
      typeName: 'LiquidProgressShape',
      help: 'Circle shows an upload, rectangle a battery.',
    ),
    const SliderKnob(
      id: 'value',
      label: 'Value',
      min: 0,
      max: 1,
      initial: 0.62,
      divisions: 50,
    ),
    const SliderKnob(
      id: 'waveAmplitude',
      label: 'Wave amplitude',
      min: 0,
      max: 16,
      initial: 6,
      divisions: 16,
    ),
    const ToggleKnob(
      id: 'showPercentage',
      label: 'Show percentage',
      initial: false,
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _LiquidDemo(knobs: knobs),
  thumbnail: (context) => const _LiquidThumb(),
  code: (knobs) {
    final bool circle = knobs.pick('shape') == LiquidProgressShape.circle;
    return dartCall('LiquidProgress', {
      'value': circle ? 'uploadProgress' : 'batteryLevel',
      'shape': knobs.arg('shape'),
      'size': circle ? '88' : null,
      'width': circle ? null : '150',
      'height': circle ? null : '72',
      'waveAmplitude': knobs.arg('waveAmplitude'),
      'showPercentage': knobs.arg('showPercentage'),
      'liquidColor': knobs.arg('color'),
      'semanticLabel': quote(circle ? 'Upload progress' : 'Battery level'),
    });
  },
  notes: const [
    'Exposed to screen readers with its label and the target value as a '
        'percent, never a level in the middle of the animation.',
    'The percentage label is drawn twice and clipped, so it stays legible '
        'over both the liquid and the background.',
    'Under reduced motion the wave stops scrolling and value changes jump '
        'instantly.',
  ],
);

class _LiquidDemo extends StatefulWidget {
  const _LiquidDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_LiquidDemo> createState() => _LiquidDemoState();
}

class _LiquidDemoState extends State<_LiquidDemo> {
  /// Set while the in-demo simulation runs; otherwise the knob drives the
  /// value.
  double? _simulated;
  double _lastKnob = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lastKnob = widget.knobs.number('value');
  }

  @override
  void didUpdateWidget(_LiquidDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double knob = widget.knobs.number('value');
    if (knob != _lastKnob) {
      // The value knob takes over again.
      _lastKnob = knob;
      _stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _simulated = null;
  }

  void _simulate() {
    _timer?.cancel();
    setState(() => _simulated = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      setState(() {
        _simulated = ((_simulated ?? 0) + 0.08).clamp(0.0, 1.0);
        if (_simulated! >= 1) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool circle = knobs.pick('shape') == LiquidProgressShape.circle;
    final double value = _simulated ?? knobs.number('value');
    final int percent = (value * 100).round();
    final bool running = _timer?.isActive ?? false;

    final Widget progress = LiquidProgress(
      value: value,
      shape: knobs.pick('shape'),
      size: 88,
      width: 150,
      height: 72,
      waveAmplitude: knobs.number('waveAmplitude'),
      showPercentage: knobs.flag('showPercentage'),
      liquidColor: knobs.color('color'),
      semanticLabel: circle ? 'Upload progress' : 'Battery level',
    );

    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final Widget details = circle
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'brand-assets.zip',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const Gap(4),
              Text('${(value * 24).toStringAsFixed(1)} of 24 MB', style: muted),
              const Gap(2),
              Text(
                value >= 1 ? 'Uploaded' : 'Uploading to Team drive',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Battery $percent%', style: theme.textTheme.titleSmall),
              const Gap(4),
              Text(
                value >= 1
                    ? 'Fully charged'
                    : 'About ${(value * 9).floor()} h '
                          '${((value * 9 % 1) * 60).round()} min left',
                style: muted,
              ),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (circle)
              Row(
                children: [
                  progress,
                  const Gap(18),
                  Expanded(child: details),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      progress,
                      Container(
                        width: 7,
                        height: 26,
                        decoration: BoxDecoration(
                          color: knobs.color('color') ?? scheme.primary,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  details,
                ],
              ),
            const Gap(18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: running ? null : _simulate,
                icon: Icon(
                  circle ? Icons.cloud_upload_outlined : Icons.bolt_rounded,
                  size: 18,
                ),
                label: Text(circle ? 'Simulate upload' : 'Simulate charging'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidThumb extends StatelessWidget {
  const _LiquidThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LiquidProgress(value: 0.64, size: 96, showPercentage: true),
        const Gap(24),
        LiquidProgress(
          value: 0.4,
          shape: LiquidProgressShape.rectangle,
          width: 130,
          height: 64,
          liquidColor: scheme.tertiary,
          showPercentage: true,
        ),
      ],
    );
  }
}
