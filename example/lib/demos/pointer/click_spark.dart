import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry clickSparkEntry = ComponentEntry(
  id: 'click-spark',
  name: 'Click Spark',
  category: Categories.pointer,
  summary:
      'Bursts small sparks out of the exact point that was tapped. A light, '
      'cheerful confirmation for likes, favorites and other quick actions.',
  apis: const ['ClickSpark', 'ClickSparkShape'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    SelectKnob.enumeration(
      id: 'shape',
      label: 'Shape',
      values: ClickSparkShape.values,
      initial: ClickSparkShape.lines,
      typeName: 'ClickSparkShape',
    ),
    const SliderKnob(
      id: 'sparkCount',
      label: 'Spark count',
      min: 3,
      max: 20,
      initial: 8,
      divisions: 17,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'sparkSize',
      label: 'Spark size',
      min: 4,
      max: 24,
      initial: 10,
      divisions: 20,
    ),
    const SliderKnob(
      id: 'sparkRadius',
      label: 'Radius',
      min: 5,
      max: 60,
      initial: 15,
      divisions: 11,
      help: 'How far each spark travels from the tap.',
    ),
    const ColorKnob(id: 'sparkColor', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ClickSparkDemo(knobs: knobs),
  thumbnail: (context) => const _ClickSparkThumb(),
  code: (knobs) => dartCall('ClickSpark', {
    'shape': knobs.arg('shape'),
    'sparkCount': knobs.arg('sparkCount'),
    'sparkSize': knobs.arg('sparkSize'),
    'sparkRadius': knobs.arg('sparkRadius'),
    'sparkColor': knobs.arg('sparkColor'),
    'child': dartCall('IconButton', {
      'onPressed': 'toggleLike',
      'icon': 'const Icon(Icons.favorite_border)',
    }),
  }),
  notes: const [
    'Only taps spark: a pointer that moves beyond the tap slop, such as a '
        'scroll or a drag, does not. Events are observed, never consumed, so '
        'the child keeps working.',
    'Sparks are painted in an unclipped overlay that ignores pointers and '
        'adds no semantics.',
    'Under reduced motion, or with enabled set to false, no sparks are '
        'drawn and no frames are scheduled.',
  ],
);

class _ClickSparkDemo extends StatefulWidget {
  const _ClickSparkDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ClickSparkDemo> createState() => _ClickSparkDemoState();
}

class _ClickSparkDemoState extends State<_ClickSparkDemo> {
  bool _liked = false;

  ClickSpark _spark(Widget child) {
    final Knobs knobs = widget.knobs;
    return ClickSpark(
      shape: knobs.pick('shape'),
      sparkCount: knobs.number('sparkCount').round(),
      sparkSize: knobs.number('sparkSize'),
      sparkRadius: knobs.number('sparkRadius'),
      sparkColor: knobs.color('sparkColor'),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color likeColor = widget.knobs.color('sparkColor') ?? scheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DemoCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DemoAvatar('MR', color: demoAccents[4], size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maya Rivera',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '2h',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Shipped the new onboarding flow today. Thanks to everyone '
                  'who tested the early builds.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _spark(
                      IconButton(
                        tooltip: _liked ? 'Unlike' : 'Like',
                        onPressed: () => setState(() => _liked = !_liked),
                        icon: Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _liked ? likeColor : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      _liked ? '129' : '128',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '24',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _spark(
            Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  const DemoCaption('Tap anywhere in this area'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClickSparkThumb extends StatelessWidget {
  const _ClickSparkThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _SparkPainter(color: scheme.primary),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.favorite_rounded, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Static lines radiating from the center, for the thumbnail.
class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const int count = 8;
    for (int i = 0; i < count; i++) {
      final double a = i * 2 * math.pi / count;
      final Offset d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 40, c + d * 56, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.color != color;
}
