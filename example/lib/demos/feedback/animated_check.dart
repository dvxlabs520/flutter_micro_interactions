import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry animatedCheckEntry = ComponentEntry(
  id: 'animated-check',
  name: 'Animated Check',
  category: Categories.feedback,
  summary:
      'A checkmark or cross drawn with a hand drawn stroke. Use it to close '
      'a loading flow with a clear result.',
  apis: const ['AnimatedCheck', 'AnimatedCheckController', 'AnimatedCheckType'],
  knobs: [
    SelectKnob.enumeration(
      id: 'type',
      label: 'Type',
      values: AnimatedCheckType.values,
      initial: AnimatedCheckType.check,
      typeName: 'AnimatedCheckType',
    ),
    const SliderKnob(
      id: 'size',
      label: 'Size',
      min: 32,
      max: 120,
      initial: 48,
      divisions: 22,
    ),
    const SliderKnob(
      id: 'strokeWidth',
      label: 'Stroke width',
      min: 2,
      max: 8,
      initial: 4,
      divisions: 12,
    ),
    const ToggleKnob(id: 'showCircle', label: 'Show circle', initial: true),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 300,
      max: 1500,
      initial: 700,
      divisions: 12,
    ),
  ],
  preview: (context, knobs) => _CheckDemo(knobs: knobs),
  thumbnail: (context) => const _CheckThumb(),
  code: (knobs) {
    final bool check = knobs.pick('type') == AnimatedCheckType.check;
    return dartCall('AnimatedCheck', {
      'type': knobs.arg('type'),
      'size': knobs.arg('size'),
      'strokeWidth': knobs.arg('strokeWidth'),
      'showCircle': knobs.arg('showCircle'),
      'duration': knobs.arg('duration'),
      'semanticLabel': quote(check ? 'Payment complete' : 'Payment failed'),
      'onCompleted': 'showReceipt',
    });
  },
  notes: const [
    'While the stroke is drawing the graphic is hidden from screen readers; '
        "once complete it exposes semanticLabel ('Success' or 'Error' by "
        'default).',
    'Changing type replays the animation with the new mark. Use an '
        'AnimatedCheckController to play or reset it after async work.',
    'Under reduced motion the full mark renders at once and onCompleted '
        'still fires.',
  ],
  replayable: true,
);

class _CheckDemo extends StatefulWidget {
  const _CheckDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CheckDemo> createState() => _CheckDemoState();
}

class _CheckDemoState extends State<_CheckDemo> {
  final AnimatedCheckController _controller = AnimatedCheckController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool check = knobs.pick('type') == AnimatedCheckType.check;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DemoCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCheck(
              controller: _controller,
              type: knobs.pick('type'),
              size: knobs.number('size'),
              strokeWidth: knobs.number('strokeWidth'),
              showCircle: knobs.flag('showCircle'),
              duration: knobs.ms('duration'),
              semanticLabel: check ? 'Payment complete' : 'Payment failed',
            ),
            const Gap(18),
            Text(
              check ? 'Payment complete' : 'Payment failed',
              style: theme.textTheme.titleMedium,
            ),
            const Gap(6),
            Text(
              check
                  ? r'$24.99 to Northwind Coffee. A receipt is on its way.'
                  : 'Your card was declined. Try another payment method.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            TextButton.icon(
              onPressed: _controller.play,
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Draw again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckThumb extends StatelessWidget {
  const _CheckThumb();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThumbTile(type: AnimatedCheckType.check, label: 'Saved'),
        Gap(16),
        _ThumbTile(type: AnimatedCheckType.cross, label: 'Failed'),
      ],
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({required this.type, required this.label});

  final AnimatedCheckType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCheck(type: type, size: 52),
          const Gap(10),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
