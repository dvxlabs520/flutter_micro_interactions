import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry jellyRadioEntry = ComponentEntry(
  id: 'jelly-radio',
  name: 'Jelly Radio',
  category: Categories.controls,
  summary:
      'Radio chips where the chosen one swells and wobbles like jelly and '
      'nudges its neighbours aside. Use it for a short list of exclusive '
      'options such as a shipping speed or a size.',
  apis: const ['JellyRadioGroup', 'JellyRadioItem'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob(
      id: 'selectedScale',
      label: 'Selected scale',
      min: 1,
      max: 1.2,
      initial: 1.08,
      divisions: 20,
    ),
    const SliderKnob(
      id: 'pushDistance',
      label: 'Push distance',
      min: 0,
      max: 14,
      initial: 6,
      divisions: 14,
      help: 'How far the neighbours are pushed away, in pixels.',
    ),
    SelectKnob<String>(
      id: 'shape',
      label: 'Shape',
      options: const ['stadium', 'rounded'],
      initial: 'stadium',
      labelOf: (v) => v == 'stadium' ? 'Stadium' : 'Rounded',
      codeOf: (v) => v == 'stadium'
          ? 'const StadiumBorder()'
          : 'RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))',
    ),
    const ToggleKnob(id: 'icons', label: 'Icons', initial: false),
    const ColorKnob(
      id: 'selectedColor',
      label: 'Selected color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _JellyRadioDemo(knobs: knobs),
  thumbnail: (context) => const _JellyThumb(),
  code: (knobs) {
    final bool icons = knobs.flag('icons');
    String item(_Option o) {
      final String icon = icons
          ? ', icon: const Icon(Icons.${_iconNames[o.id]})'
          : '';
      return "JellyRadioItem(value: '${o.id}', label: const Text('${o.label}')$icon)";
    }

    final String call = dartCall('JellyRadioGroup<String>', {
      'items': dartList([
        for (final _Option o in _options) item(o),
      ], type: 'JellyRadioItem<String>'),
      'value': '_shipping',
      'onChanged': '(String value) => setState(() => _shipping = value)',
      'wrap': 'true',
      'selectedScale': knobs.arg('selectedScale'),
      'pushDistance': knobs.arg('pushDistance'),
      'shape': knobs.arg('shape'),
      'selectedColor': knobs.arg('selectedColor'),
    });
    return "String _shipping = 'standard';\n\n$call";
  },
  notes: const [
    'Each chip is exposed as a checked or unchecked member of a mutually '
        'exclusive group with a 48 by 48 tap target. The group is one focus '
        'stop and the arrow keys move the selection.',
    'A selection click haptic plays when the user changes the selection, '
        'unless enableHaptics is false.',
    'Under reduced motion the selection changes instantly: no overshoot, no '
        'wobble and no push.',
  ],
);

class _Option {
  const _Option(this.id, this.label, this.icon, this.price, this.eta);

  final String id;
  final String label;
  final IconData icon;
  final double price;
  final String eta;
}

const List<_Option> _options = [
  _Option(
    'standard',
    'Standard',
    Icons.local_shipping_outlined,
    4.99,
    'Arrives Tue, Oct 21',
  ),
  _Option('express', 'Express', Icons.bolt_rounded, 12.5, 'Arrives tomorrow'),
  _Option(
    'pickup',
    'Pickup',
    Icons.storefront_outlined,
    0,
    'Ready today after 4 pm',
  ),
];

const Map<String, String> _iconNames = {
  'standard': 'local_shipping_outlined',
  'express': 'bolt_rounded',
  'pickup': 'storefront_outlined',
};

const double _subtotal = 86;

String _money(double v) => v == 0 ? 'Free' : '\$${v.toStringAsFixed(2)}';

class _JellyRadioDemo extends StatefulWidget {
  const _JellyRadioDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_JellyRadioDemo> createState() => _JellyRadioDemoState();
}

class _JellyRadioDemoState extends State<_JellyRadioDemo> {
  String _shipping = 'standard';

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _Option chosen = _options.firstWhere((o) => o.id == _shipping);
    final bool icons = knobs.flag('icons');
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
            Text('Delivery', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Choose how your order gets to you.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            JellyRadioGroup<String>(
              items: [
                for (final _Option o in _options)
                  JellyRadioItem<String>(
                    value: o.id,
                    label: Text(o.label),
                    icon: icons ? Icon(o.icon) : null,
                  ),
              ],
              value: _shipping,
              onChanged: (String value) => setState(() => _shipping = value),
              wrap: true,
              selectedScale: knobs.number('selectedScale'),
              pushDistance: knobs.number('pushDistance'),
              shape: knobs.pick<String>('shape') == 'stadium'
                  ? null
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
              selectedColor: knobs.color('selectedColor'),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Line(
                    label: chosen.eta,
                    value: _money(chosen.price),
                    muted: true,
                  ),
                  const SizedBox(height: 6),
                  const _Line(label: 'Subtotal', value: r'$86.00', muted: true),
                  const SizedBox(height: 10),
                  _Line(
                    label: 'Total',
                    value: '\$${(_subtotal + chosen.price).toStringAsFixed(2)}',
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

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = muted
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.titleSmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _JellyThumb extends StatefulWidget {
  const _JellyThumb();

  @override
  State<_JellyThumb> createState() => _JellyThumbState();
}

class _JellyThumbState extends State<_JellyThumb> {
  static const List<String> _sizes = ['S', 'M', 'L', 'XL'];
  Timer? _timer;
  int _tick = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1100),
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
    const List<int> order = [1, 2, 0, 3];
    return JellyRadioGroup<String>(
      items: [
        for (final String s in _sizes)
          JellyRadioItem<String>(value: s, label: Text(s)),
      ],
      value: _sizes[order[_tick % order.length]],
      onChanged: (_) {},
      chipPadding: const EdgeInsets.symmetric(horizontal: 18),
    );
  }
}
