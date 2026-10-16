import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry animatedCounterEntry = ComponentEntry(
  id: 'animated-counter',
  name: 'Animated Counter',
  category: Categories.feedback,
  summary:
      'A number that counts or rolls to its new value. Use it for prices, '
      'stats and dashboard tiles; just give it a new value.',
  apis: const ['AnimatedCounter', 'CounterAnimationMode'],
  knobs: [
    SelectKnob.enumeration(
      id: 'mode',
      label: 'Mode',
      values: CounterAnimationMode.values,
      initial: CounterAnimationMode.count,
      typeName: 'CounterAnimationMode',
      help: 'Count tweens the number, slide digits rolls each digit.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 1500,
      initial: 500,
      divisions: 13,
    ),
    SelectKnob<int?>(
      id: 'fractionDigits',
      label: 'Fraction digits',
      options: const [null, 0, 2],
      initial: null,
      labelOf: (v) => v == null ? 'Auto' : '$v',
      codeOf: (v) => '$v',
    ),
    const ToggleKnob(id: 'currency', label: 'Currency prefix', initial: true),
  ],
  preview: (context, knobs) => _CounterDemo(knobs: knobs),
  thumbnail: (context) => const _CounterThumb(),
  code: (knobs) => dartCall('AnimatedCounter', {
    'value': 'revenue',
    'mode': knobs.arg('mode'),
    'duration': knobs.arg('duration'),
    'fractionDigits': knobs.arg('fractionDigits'),
    'prefix': knobs.flag('currency') ? r"r'$'" : null,
    'thousandsSeparator': quote(','),
    'style': 'Theme.of(context).textTheme.displaySmall',
  }),
  notes: const [
    'Screen readers always get the final value, never a number in the '
        'middle of the animation. semanticLabel overrides it.',
    'Quick successive changes retarget smoothly from the current animated '
        'value.',
    'Under reduced motion, or with enabled set to false, the text jumps to '
        'the new value.',
  ],
  stageHeight: 460,
);

const List<String> _products = [
  'Ceramic mug',
  'Linen tote',
  'Pour over set',
  'Notebook trio',
  'Desk lamp',
];

class _CounterDemo extends StatefulWidget {
  const _CounterDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CounterDemo> createState() => _CounterDemoState();
}

class _CounterDemoState extends State<_CounterDemo> {
  final math.Random _random = math.Random(4);
  int _revenue = 12480;
  int _orders = 86;
  final List<double> _bars = [0.35, 0.5, 0.42, 0.62, 0.55, 0.7, 0.48];
  String _last = 'Linen tote';

  void _addSale() {
    setState(() {
      final int amount = 40 + _random.nextInt(220);
      _revenue += amount;
      _orders += 1;
      _last = _products[_random.nextInt(_products.length)];
      _bars[_bars.length - 1] = math.min(1, _bars.last + amount / 900);
    });
  }

  void _refund() {
    if (_orders == 0) return;
    setState(() {
      final int amount = math.min(_revenue, 30 + _random.nextInt(90));
      _revenue -= amount;
      _orders -= 1;
      _bars[_bars.length - 1] = math.max(0.1, _bars.last - amount / 900);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final CounterAnimationMode mode = knobs.pick('mode');
    final Duration duration = knobs.ms('duration');
    final String? prefix = knobs.flag('currency') ? r'$' : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Live',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedCounter(
                value: _revenue,
                mode: mode,
                duration: duration,
                fractionDigits: knobs.pick('fractionDigits'),
                prefix: prefix,
                thousandsSeparator: ',',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const Gap(4),
            Row(
              children: [
                AnimatedCounter(
                  value: _orders,
                  mode: mode,
                  duration: duration,
                  suffix: ' orders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Flexible(
                  child: Text(
                    '  Last: $_last',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(18),
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < _bars.length; i++) ...[
                    if (i > 0) const Gap(6),
                    Expanded(
                      child: AnimatedFractionallySizedBox(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        heightFactor: _bars[i],
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == _bars.length - 1
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _refund,
                    child: const Text('Refund'),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addSale,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add sale'),
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

/// A stat tile that rolls up on its own.
class _CounterThumb extends StatefulWidget {
  const _CounterThumb();

  @override
  State<_CounterThumb> createState() => _CounterThumbState();
}

class _CounterThumbState extends State<_CounterThumb> {
  int _value = 12480;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      setState(() => _value += 137);
    });
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue today',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(4),
          AnimatedCounter(
            value: _value,
            mode: CounterAnimationMode.slideDigits,
            prefix: r'$',
            thousandsSeparator: ',',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
