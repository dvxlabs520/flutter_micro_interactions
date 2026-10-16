import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

const Map<String, SpringDescription> _trailing = {
  'default': SpringDescription(mass: 1, stiffness: 300, damping: 25),
  'elastic': SpringDescription(mass: 1, stiffness: 150, damping: 13),
  'tight': SpringDescription(mass: 1, stiffness: 600, damping: 40),
};

const Map<String, double?> _shapes = {'pill': null, 'rounded': 10, 'square': 4};

final ComponentEntry rubberSegmentEntry = ComponentEntry(
  id: 'rubber-segment',
  name: 'Rubber Segment',
  category: Categories.controls,
  summary:
      'A segmented control whose thumb stretches like rubber across the gap '
      'to the new segment, then squashes into place. Good for switching a '
      'time range or a view.',
  apis: const ['RubberSegment', 'RubberSegmentItem'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob<String>(
      id: 'trailing',
      label: 'Trailing edge',
      options: _trailing.keys.toList(),
      initial: 'default',
      labelOf: (v) => switch (v) {
        'elastic' => 'Elastic',
        'tight' => 'Tight',
        _ => 'Default',
      },
      codeOf: (v) {
        final SpringDescription s = _trailing[v]!;
        return 'const SpringDescription(mass: 1, '
            'stiffness: ${s.stiffness.round()}, damping: ${s.damping.round()})';
      },
      help:
          'A softer trailing spring lags more, so the thumb stretches further.',
    ),
    SelectKnob<String>(
      id: 'shape',
      label: 'Shape',
      options: _shapes.keys.toList(),
      initial: 'pill',
      labelOf: (v) => switch (v) {
        'rounded' => 'Rounded',
        'square' => 'Square',
        _ => 'Pill',
      },
      codeOf: (v) => 'BorderRadius.circular(${_shapes[v]!.round()})',
    ),
    const SliderKnob(
      id: 'height',
      label: 'Height',
      min: 32,
      max: 52,
      initial: 40,
      divisions: 10,
    ),
    const ToggleKnob(
      id: 'fitContent',
      label: 'Fit content',
      initial: false,
      help: 'Each segment as wide as its label instead of equal widths.',
    ),
    const ColorKnob(
      id: 'thumbColor',
      label: 'Thumb color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _RubberSegmentDemo(knobs: knobs),
  thumbnail: (context) => const _RubberThumb(),
  code: (knobs) {
    final String call = dartCall('RubberSegment<String>', {
      'items': dartList([
        for (final String r in _ranges.keys)
          "RubberSegmentItem(value: '${r.toLowerCase()}', label: Text('$r'))",
      ], type: 'RubberSegmentItem<String>'),
      'value': '_range',
      'onChanged': '(String value) => setState(() => _range = value)',
      'trailingSpring': knobs.arg('trailing'),
      'borderRadius': knobs.arg('shape'),
      'height': knobs.arg('height'),
      'fitContent': knobs.arg('fitContent'),
      'thumbColor': knobs.arg('thumbColor'),
    });
    return "String _range = 'week';\n\n$call";
  },
  notes: const [
    'Each segment is exposed as a checked or unchecked member of a mutually '
        'exclusive group. The control is one focus stop; the arrow keys '
        'select the previous or next segment.',
    'The interactive area is at least 48 pixels tall even when the height '
        'is smaller. A selection click haptic plays on change.',
    'Under reduced motion the thumb jumps straight to the new segment with '
        'no stretch.',
  ],
);

class _Summary {
  const _Summary(this.revenue, this.delta, this.orders, this.average);

  final String revenue;
  final double delta;
  final String orders;
  final String average;
}

const Map<String, _Summary> _ranges = {
  'Day': _Summary(r'$1,284', 4.2, '38', r'$33.79'),
  'Week': _Summary(r'$8,940', 12.5, '262', r'$34.12'),
  'Month': _Summary(r'$36,215', -2.1, '1,048', r'$34.56'),
};

const Map<String, String> _compared = {
  'Day': 'yesterday',
  'Week': 'last week',
  'Month': 'last month',
};

class _RubberSegmentDemo extends StatefulWidget {
  const _RubberSegmentDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_RubberSegmentDemo> createState() => _RubberSegmentDemoState();
}

class _RubberSegmentDemoState extends State<_RubberSegmentDemo> {
  String _range = 'Week';

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _Summary s = _ranges[_range]!;
    final bool up = s.delta >= 0;
    final double? radius = _shapes[knobs.pick<String>('shape')];
    final bool fit = knobs.flag('fitContent');
    final Widget segment = RubberSegment<String>(
      items: [
        for (final String r in _ranges.keys)
          RubberSegmentItem<String>(value: r, label: Text(r)),
      ],
      value: _range,
      onChanged: (String value) => setState(() => _range = value),
      trailingSpring: _trailing[knobs.pick<String>('trailing')]!,
      borderRadius: radius == null ? null : BorderRadius.circular(radius),
      height: knobs.number('height'),
      fitContent: fit,
      thumbColor: knobs.color('thumbColor'),
    );
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
            if (fit)
              segment
            else
              SizedBox(width: double.infinity, child: segment),
            const SizedBox(height: 20),
            Text(
              'Revenue',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.revenue,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (up ? scheme.tertiary : scheme.error).withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${up ? '+' : ''}${s.delta.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: up ? scheme.tertiary : scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Compared with ${_compared[_range]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Orders', value: s.orders),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(label: 'Average order', value: s.average),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RubberThumb extends StatefulWidget {
  const _RubberThumb();

  @override
  State<_RubberThumb> createState() => _RubberThumbState();
}

class _RubberThumbState extends State<_RubberThumb> {
  static const List<String> _order = ['Day', 'Month', 'Week'];
  Timer? _timer;
  int _tick = 2;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1200),
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
    return RubberSegment<String>(
      items: [
        for (final String r in _ranges.keys)
          RubberSegmentItem<String>(value: r, label: Text(r)),
      ],
      value: _order[_tick % _order.length],
      onChanged: (_) {},
    );
  }
}
