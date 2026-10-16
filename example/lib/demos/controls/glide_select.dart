import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry glideSelectEntry = ComponentEntry(
  id: 'glide-select',
  name: 'Glide Select',
  category: Categories.controls,
  summary:
      'A compact select chip whose menu pops out of its corner, with a '
      'highlight pill that glides and stretches between rows. For short '
      'pickers in forms and toolbars.',
  apis: const ['GlideSelect', 'GlideSelectOption', 'GlideSelectMenuWidth'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    SelectKnob.enumeration(
      id: 'menuWidth',
      label: 'Menu width',
      values: GlideSelectMenuWidth.values,
      initial: GlideSelectMenuWidth.intrinsic,
      typeName: 'GlideSelectMenuWidth',
    ),
    const SliderKnob(
      id: 'itemHeight',
      label: 'Row height',
      min: 32,
      max: 52,
      initial: 40,
      divisions: 10,
    ),
    const SliderKnob(
      id: 'radius',
      label: 'Corner radius',
      min: 4,
      max: 16,
      initial: 12,
      divisions: 12,
      codeOf: _radiusCode,
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Open duration',
      min: 120,
      max: 600,
      initial: 260,
      divisions: 12,
    ),
    const ToggleKnob(id: 'icons', label: 'Icons', initial: true),
  ],
  preview: (context, knobs) => _GlideSelectDemo(knobs: knobs),
  thumbnail: (context) => const _GlideThumb(),
  code: (knobs) {
    final bool icons = knobs.flag('icons');
    String option(_Region r) {
      final String icon = icons ? ", icon: const RegionBadge('${r.code}')" : '';
      final String enabled = r.enabled ? '' : ', enabled: false';
      return "GlideSelectOption(value: '${r.id}', "
          "label: '${r.label}'$icon$enabled)";
    }

    final String call = dartCall('GlideSelect<String>', {
      'hint': "'Region'",
      'value': '_region',
      'onChanged': '(String region) => setState(() => _region = region)',
      'menuWidth': knobs.arg('menuWidth'),
      'itemHeight': knobs.arg('itemHeight'),
      'borderRadius': knobs.arg('radius'),
      'duration': knobs.arg('duration'),
      'options': dartList([
        for (final _Region r in _regions) option(r),
      ], type: 'GlideSelectOption<String>'),
    });
    return "String? _region = 'fra';\n\n$call";
  },
  notes: const [
    'The chip is a button with an expanded state, its hint as label and the '
        'selected option as value. Rows are buttons with a selected state.',
    'Keyboard: Enter, Space or the arrows open the menu; Up, Down, Home and '
        'End move the highlight, typing jumps to a matching label, and '
        'Escape or Tab closes it. Focus stays on the chip.',
    'Under reduced motion the menu appears instantly and the pill jumps '
        'between rows without gliding.',
  ],
);

String _radiusCode(double v) =>
    'const BorderRadius.all(Radius.circular(${v.round()}))';

class _Region {
  const _Region(this.id, this.label, this.code, {this.enabled = true});

  final String id;
  final String label;
  final String code;
  final bool enabled;
}

const List<_Region> _regions = [
  _Region('iad', 'US East (Virginia)', 'US'),
  _Region('sfo', 'US West (California)', 'US'),
  _Region('fra', 'Europe (Frankfurt)', 'EU'),
  _Region('hnd', 'Asia (Tokyo)', 'AP'),
  _Region('gru', 'South America (Sao Paulo)', 'SA'),
  _Region('cpt', 'Africa (Cape Town)', 'AF', enabled: false),
];

class _Plan {
  const _Plan(this.id, this.label, this.price);

  final String id;
  final String label;
  final int price;
}

const List<_Plan> _plans = [
  _Plan('s', 'Small, 1 vCPU', 7),
  _Plan('m', 'Medium, 2 vCPU', 18),
  _Plan('l', 'Large, 4 vCPU', 42),
];

class _GlideSelectDemo extends StatefulWidget {
  const _GlideSelectDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_GlideSelectDemo> createState() => _GlideSelectDemoState();
}

class _GlideSelectDemoState extends State<_GlideSelectDemo> {
  String? _region = 'fra';
  String? _plan;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool icons = knobs.flag('icons');
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(knobs.number('radius')),
    );
    final GlideSelectMenuWidth menuWidth = knobs.pick('menuWidth');
    final double itemHeight = knobs.number('itemHeight');
    final Duration duration = knobs.ms('duration');
    final _Plan? plan = _plans.where((p) => p.id == _plan).firstOrNull;

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
            Text('Deploy project', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'acme-web, main branch',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Region',
              child: GlideSelect<String>(
                hint: 'Region',
                value: _region,
                onChanged: (String v) => setState(() => _region = v),
                menuWidth: menuWidth,
                itemHeight: itemHeight,
                borderRadius: radius,
                duration: duration,
                options: [
                  for (final _Region r in _regions)
                    GlideSelectOption<String>(
                      value: r.id,
                      label: r.label,
                      enabled: r.enabled,
                      icon: icons ? _RegionCode(r.code) : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _Field(
              label: 'Instance',
              child: GlideSelect<String>(
                hint: 'Choose a size',
                value: _plan,
                onChanged: (String v) => setState(() => _plan = v),
                menuWidth: menuWidth,
                itemHeight: itemHeight,
                borderRadius: radius,
                duration: duration,
                options: [
                  for (final _Plan p in _plans)
                    GlideSelectOption<String>(
                      value: p.id,
                      label: p.label,
                      icon: icons ? const Icon(Icons.memory_rounded) : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan == null ? 'Pick a size' : '\$${plan.price} / month',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: plan == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: plan == null || _region == null
                      ? null
                      : () => demoToast(
                          context,
                          'Deploying to ${_regions.firstWhere((r) => r.id == _region).label}',
                        ),
                  child: const Text('Deploy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

/// A two letter region code in a small tinted square, used as the option
/// icon.
class _RegionCode extends StatelessWidget {
  const _RegionCode(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GlideThumb extends StatefulWidget {
  const _GlideThumb();

  @override
  State<_GlideThumb> createState() => _GlideThumbState();
}

class _GlideThumbState extends State<_GlideThumb> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 700),
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
    // A static picture of an open menu: the real menu lives in an overlay,
    // so the thumbnail draws one with a highlight that glides between rows.
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    const List<String> rows = ['US East', 'Europe', 'Asia'];
    final int hi = const [0, 1, 2, 1][_tick % 4];
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Europe', style: theme.textTheme.bodyMedium),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  left: 0,
                  right: 0,
                  top: hi * 34.0,
                  height: 34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (final String r in rows)
                      SizedBox(
                        height: 34,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              if (r == 'Europe')
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
