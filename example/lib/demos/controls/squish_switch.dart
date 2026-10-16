import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

/// Spring presets offered by the playground, keyed by knob value.
const Map<String, SpringDescription> _springs = {
  'default': SpringDescription(mass: 1, stiffness: 520, damping: 26),
  'bouncy': SpringDescription(mass: 1, stiffness: 520, damping: 12),
  'soft': SpringDescription(mass: 1, stiffness: 240, damping: 20),
};

const Map<String, Size> _sizes = {
  'compact': Size(44, 26),
  'default': Size(52, 32),
  'large': Size(64, 38),
};

final ComponentEntry squishSwitchEntry = ComponentEntry(
  id: 'squish-switch',
  name: 'Squish Switch',
  category: Categories.controls,
  summary:
      'An on and off switch whose thumb stretches with speed and squashes '
      'against the end of the track, for settings that deserve a little '
      'physical feel.',
  apis: const ['SquishSwitch'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    const SliderKnob(
      id: 'stretch',
      label: 'Stretch',
      min: 0,
      max: 2.5,
      initial: 1,
      divisions: 10,
      help: '0 turns the squash off, above 1 exaggerates it.',
    ),
    SelectKnob<String>(
      id: 'spring',
      label: 'Spring',
      options: _springs.keys.toList(),
      initial: 'default',
      labelOf: (v) => switch (v) {
        'bouncy' => 'Bouncy',
        'soft' => 'Soft',
        _ => 'Default',
      },
      codeOf: (v) {
        final SpringDescription s = _springs[v]!;
        return 'const SpringDescription(mass: 1, '
            'stiffness: ${s.stiffness.round()}, damping: ${s.damping.round()})';
      },
      help: 'Less damping overshoots more, so the squash is stronger.',
    ),
    SelectKnob<String>(
      id: 'size',
      label: 'Size',
      options: _sizes.keys.toList(),
      initial: 'default',
      labelOf: (v) => switch (v) {
        'compact' => 'Compact',
        'large' => 'Large',
        _ => 'Default',
      },
      codeOf: (v) {
        final Size s = _sizes[v]!;
        return 'Size(${s.width.round()}, ${s.height.round()})';
      },
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
    const ToggleKnob(id: 'enabled', label: 'Enabled', initial: true),
  ],
  preview: (context, knobs) => _SquishSwitchDemo(knobs: knobs),
  thumbnail: (context) => const _SquishThumb(),
  code: (knobs) {
    final String call = dartCall('SquishSwitch', {
      'value': '_wifi',
      'onChanged': '(bool value) => setState(() => _wifi = value)',
      'stretch': knobs.arg('stretch'),
      'spring': knobs.arg('spring'),
      'size': knobs.arg('size'),
      'activeColor': knobs.arg('activeColor'),
      'enabled': knobs.arg('enabled'),
      'semanticLabel': "'Wi-Fi'",
    });
    return 'bool _wifi = true;\n\n$call';
  },
  stageHeight: 440,
  notes: const [
    'Exposed as a toggled control with the optional semantic label. It is '
        'keyboard focusable with a focus ring: Enter or Space toggles it and '
        'the arrow keys move it to the off or on side.',
    'The thumb can be tapped, dragged or flicked. A light haptic impact '
        'plays on toggle unless enableHaptics is false.',
    'Under reduced motion changes are instant, with no stretch or squash. '
        'A null onChanged or enabled: false renders it dimmed.',
  ],
);

class _Setting {
  const _Setting(this.icon, this.title, this.subtitle, this.color);

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

const List<_Setting> _settings = [
  _Setting(Icons.wifi_rounded, 'Wi-Fi', 'Studio 5G', Color(0xFF38BDF8)),
  _Setting(
    Icons.bluetooth_rounded,
    'Bluetooth',
    '2 devices connected',
    Color(0xFF6E7BFF),
  ),
  _Setting(
    Icons.notifications_none_rounded,
    'Notifications',
    'Banners and sounds',
    Color(0xFFF472B6),
  ),
  _Setting(
    Icons.dark_mode_outlined,
    'Do not disturb',
    'Until 7:00',
    Color(0xFFA78BFA),
  ),
  _Setting(
    Icons.battery_saver_outlined,
    'Low power mode',
    'Reduces background activity',
    Color(0xFF34D399),
  ),
];

class _SquishSwitchDemo extends StatefulWidget {
  const _SquishSwitchDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SquishSwitchDemo> createState() => _SquishSwitchDemoState();
}

class _SquishSwitchDemoState extends State<_SquishSwitchDemo> {
  final List<bool> _values = [true, false, true, false, false];

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                'SETTINGS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            for (int i = 0; i < _settings.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    IconBadge(
                      icon: _settings[i].icon,
                      size: 34,
                      color: _settings[i].color,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _settings[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            _settings[i].subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SquishSwitch(
                      value: _values[i],
                      onChanged: (bool value) =>
                          setState(() => _values[i] = value),
                      stretch: knobs.number('stretch'),
                      spring: _springs[knobs.pick<String>('spring')]!,
                      size: _sizes[knobs.pick<String>('size')]!,
                      activeColor: knobs.color('activeColor'),
                      enabled: knobs.flag('enabled'),
                      semanticLabel: _settings[i].title,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SquishThumb extends StatefulWidget {
  const _SquishThumb();

  @override
  State<_SquishThumb> createState() => _SquishThumbState();
}

class _SquishThumbState extends State<_SquishThumb> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1300),
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
    final ThemeData theme = Theme.of(context);
    return DemoCard(
      width: 260,
      showBorder: false,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  IconBadge(
                    icon: _settings[i].icon,
                    size: 30,
                    color: _settings[i].color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _settings[i].title,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  SquishSwitch(
                    value: (_tick + i).isEven,
                    onChanged: (_) {},
                    stretch: 1.4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
