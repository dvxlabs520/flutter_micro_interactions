import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry bellToggleEntry = ComponentEntry(
  id: 'bell-toggle',
  name: 'Bell Toggle',
  category: Categories.buttons,
  summary:
      'A pill shaped notification toggle: turning it on rings the bell and '
      'fills the pill outward from it, turning it off strikes the bell '
      'through. For subscribe, follow and remind me actions.',
  apis: const ['BellToggle'],
  tags: const [ComponentTag.newly],
  knobs: [
    const TextKnob(id: 'offLabel', label: 'Off label', initial: 'Notify me'),
    const TextKnob(
      id: 'onLabel',
      label: 'On label',
      initial: 'Notifications on',
    ),
    const SliderKnob(
      id: 'height',
      label: 'Height',
      min: 32,
      max: 52,
      initial: 40,
      divisions: 10,
    ),
    const SliderKnob.duration(
      id: 'ringDuration',
      label: 'Ring duration',
      min: 400,
      max: 2000,
      initial: 1000,
      divisions: 16,
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _BellToggleDemo(knobs: knobs),
  thumbnail: (context) => const _BellThumb(),
  code: (knobs) {
    final String call = dartCall('BellToggle', {
      'value': '_subscribed',
      'onChanged': '(bool value) => setState(() => _subscribed = value)',
      'offLabel': knobs.arg('offLabel'),
      'onLabel': knobs.arg('onLabel'),
      'height': knobs.arg('height'),
      'ringDuration': knobs.arg('ringDuration'),
      'activeColor': knobs.arg('activeColor'),
    });
    return 'bool _subscribed = false;\n\n$call';
  },
  notes: const [
    'A toggle button labelled by semanticLabel or the visible label, with '
        'value as its toggled state. Enter or Space activates it and the '
        'touch target is at least 48 pixels tall.',
    'The bell is painted, so it does not depend on an icon font. Haptic '
        'feedback plays on tap unless enableHaptics is false.',
    'Under reduced motion the state changes instantly: no ring, no shrink '
        'and no slide.',
  ],
);

class _BellToggleDemo extends StatefulWidget {
  const _BellToggleDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_BellToggleDemo> createState() => _BellToggleDemoState();
}

class _BellToggleDemoState extends State<_BellToggleDemo> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String off = knobs.text('offLabel');
    final String on = knobs.text('onLabel');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LIVE THU 18:00',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _on ? '1,249 waiting' : '1,248 waiting',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Motion design office hours',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Bring a prototype and get live feedback on timing, easing and '
              'springs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const DemoAvatar('NS', size: 28, color: Color(0xFFA78BFA)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Northwind Studio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: BellToggle(
                value: _on,
                onChanged: (bool value) => setState(() => _on = value),
                offLabel: off.isEmpty ? 'Notify me' : off,
                onLabel: on.isEmpty ? 'Notifications on' : on,
                height: knobs.number('height'),
                ringDuration: knobs.ms('ringDuration'),
                activeColor: knobs.color('activeColor'),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _on
                    ? 'We will remind you 10 minutes before it starts.'
                    : 'Get a reminder before the session starts.',
                key: ValueKey(_on),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellThumb extends StatefulWidget {
  const _BellThumb();

  @override
  State<_BellThumb> createState() => _BellThumbState();
}

class _BellThumbState extends State<_BellThumb> {
  Timer? _timer;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1800),
      (_) => setState(() => _on = !_on),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BellToggle(value: _on, onChanged: (_) {}, height: 44);
  }
}
