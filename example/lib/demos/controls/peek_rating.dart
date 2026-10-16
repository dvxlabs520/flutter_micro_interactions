import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry peekRatingEntry = ComponentEntry(
  id: 'peek-rating',
  name: 'Peek Rating',
  category: Categories.controls,
  summary:
      'A star rating that previews the value under the pointer with a '
      'lifting wave and commits it with a pop and a small sparkle. For '
      'reviews and quick feedback.',
  apis: const ['PeekRating'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const ToggleKnob(
      id: 'allowHalf',
      label: 'Half stars',
      initial: false,
      help: 'The left half of each star picks a half value.',
    ),
    const SliderKnob(
      id: 'size',
      label: 'Star size',
      min: 20,
      max: 44,
      initial: 28,
      divisions: 12,
    ),
    const SliderKnob(
      id: 'spacing',
      label: 'Spacing',
      min: 0,
      max: 16,
      initial: 6,
      divisions: 8,
    ),
    const SliderKnob.duration(
      id: 'waveDelay',
      label: 'Wave delay',
      min: 0,
      max: 120,
      initial: 35,
      divisions: 24,
      help: 'Extra delay per star of distance from the pointer.',
    ),
    const ColorKnob(
      id: 'activeColor',
      label: 'Active color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _PeekRatingDemo(knobs: knobs),
  thumbnail: (context) => const _PeekThumb(),
  code: (knobs) {
    final String call = dartCall('PeekRating', {
      'value': '_rating',
      'onChanged': '(double rating) => setState(() => _rating = rating)',
      'allowHalf': knobs.arg('allowHalf'),
      'size': knobs.arg('size'),
      'spacing': knobs.arg('spacing'),
      'waveDelay': knobs.arg('waveDelay'),
      'activeColor': knobs.arg('activeColor'),
      'semanticLabel': "'Delivery rating'",
    });
    return 'double _rating = 0;\n\n$call';
  },
  stageHeight: 480,
  notes: const [
    'Exposed as a slider whose value reads like "3 of 5", with increase and '
        'decrease actions. When focused the arrow keys change the value, Home '
        'clears it and End sets the maximum.',
    'Hover previews on desktop; on touch, drag across the stars to preview '
        'and lift to commit. readOnly shows the value at full opacity without '
        'interaction.',
    'Under reduced motion the preview still recolors the stars, but there '
        'is no wave, pop or sparkle.',
  ],
);

const List<String> _words = [
  'Tap a star to rate',
  'Poor',
  'Could be better',
  'Okay',
  'Good',
  'Excellent',
];

const List<String> _tags = ['On time', 'Friendly', 'Well packed', 'Careful'];

class _PeekRatingDemo extends StatefulWidget {
  const _PeekRatingDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PeekRatingDemo> createState() => _PeekRatingDemoState();
}

class _PeekRatingDemoState extends State<_PeekRatingDemo> {
  double _rating = 0;
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool half = knobs.flag('allowHalf');
    final double rating = half ? _rating : _rating.ceilToDouble();
    final String word = _words[rating.ceil()];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DemoAvatar('MR', size: 48, color: Color(0xFF38BDF8)),
            const SizedBox(height: 10),
            Text(
              'How was your delivery?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Marco delivered your order at 12:40',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PeekRating(
                value: rating,
                onChanged: (double v) => setState(() => _rating = v),
                allowHalf: half,
                size: knobs.number('size'),
                spacing: knobs.number('spacing'),
                waveDelay: knobs.ms('waveDelay'),
                activeColor: knobs.color('activeColor'),
                semanticLabel: 'Delivery rating',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rating == 0 ? word : '$word, ${_format(rating)} of 5',
              style: theme.textTheme.labelMedium?.copyWith(
                color: rating == 0 ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final String t in _tags)
                  _TagChip(
                    label: t,
                    selected: _picked.contains(t),
                    onTap: () => setState(() {
                      if (!_picked.remove(t)) _picked.add(t);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: rating == 0
                    ? null
                    : () {
                        demoToast(context, 'Thanks for your feedback');
                        setState(() {
                          _rating = 0;
                          _picked.clear();
                        });
                      },
                child: const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeekThumb extends StatefulWidget {
  const _PeekThumb();

  @override
  State<_PeekThumb> createState() => _PeekThumbState();
}

class _PeekThumbState extends State<_PeekThumb> {
  static const List<double> _stops = [4, 2, 5, 3];
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
    return PeekRating(
      value: _stops[_tick % _stops.length],
      onChanged: (_) {},
      readOnly: true,
      size: 34,
      spacing: 8,
    );
  }
}
