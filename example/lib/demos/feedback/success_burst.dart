import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry successBurstEntry = ComponentEntry(
  id: 'success-burst',
  name: 'Success Burst',
  category: Categories.feedback,
  summary:
      'A one-shot burst of confetti from a widget, for the moment an order, '
      'payment or upload succeeds.',
  apis: const ['SuccessBurst', 'SuccessBurstController', 'ParticleShape'],
  knobs: [
    SelectKnob.enumeration(
      id: 'shapes',
      label: 'Shapes',
      values: ParticleShape.values,
      initial: ParticleShape.mixed,
      typeName: 'ParticleShape',
    ),
    SliderKnob(
      id: 'particleCount',
      label: 'Particles',
      min: 6,
      max: 60,
      initial: 24,
      divisions: 54,
      format: (v) => '${v.round()}',
      codeOf: (v) => '${v.round()}',
    ),
    const SliderKnob(
      id: 'spreadRadius',
      label: 'Spread radius',
      min: 40,
      max: 140,
      initial: 80,
      divisions: 20,
    ),
    const ToggleKnob(
      id: 'burstOnTap',
      label: 'Burst on tap',
      initial: false,
      help: 'Tapping the icon fires another burst.',
    ),
  ],
  preview: (context, knobs) => _SuccessBurstDemo(knobs: knobs),
  thumbnail: (context) => const _BurstThumb(),
  code: (knobs) {
    final String widget = dartCall('SuccessBurst', {
      'controller': 'controller',
      'shapes': knobs.arg('shapes'),
      'particleCount': knobs.arg('particleCount'),
      'spreadRadius': knobs.arg('spreadRadius'),
      'burstOnTap': knobs.arg('burstOnTap'),
      'child': 'const Icon(Icons.check_circle, size: 56)',
    });
    return 'final controller = SuccessBurstController();\n\n'
        '$widget;\n\n'
        '// When the order goes through:\n'
        'controller.burst();';
  },
  notes: const [
    'The particle layer is decorative: it ignores pointers and is excluded '
        'from semantics, so the child keeps its own label.',
    'Particles fly beyond the bounds of the child on purpose. Leave some '
        'room around it.',
    'Under reduced motion no particles are drawn, and onCompleted still '
        'fires.',
  ],
  stageHeight: 520,
);

enum _OrderStep { review, processing, done }

class _SuccessBurstDemo extends StatefulWidget {
  const _SuccessBurstDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SuccessBurstDemo> createState() => _SuccessBurstDemoState();
}

class _SuccessBurstDemoState extends State<_SuccessBurstDemo> {
  final SuccessBurstController _controller = SuccessBurstController();
  _OrderStep _step = _OrderStep.review;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    setState(() => _step = _OrderStep.processing);
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _step = _OrderStep.done);
      _controller.burst();
    });
  }

  void _reset() => setState(() => _step = _OrderStep.review);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool done = _step == _OrderStep.done;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuccessBurst(
              controller: _controller,
              shapes: knobs.pick('shapes'),
              particleCount: knobs.number('particleCount').round(),
              spreadRadius: knobs.number('spreadRadius'),
              burstOnTap: knobs.flag('burstOnTap'),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: done
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey('done'),
                        size: 56,
                        color: scheme.primary,
                      )
                    : const IconBadge(
                        key: ValueKey('bag'),
                        icon: Icons.shopping_bag_outlined,
                        size: 56,
                      ),
              ),
            ),
            const Gap(16),
            Text(
              done ? 'Order placed' : 'Review your order',
              style: theme.textTheme.titleMedium,
            ),
            const Gap(4),
            Text(
              done ? 'Arrives Thursday, October 22' : 'Order #1042',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(20),
            const _LineItem(label: 'Ceramic pour over set', price: r'$64.00'),
            const _LineItem(label: 'Single origin beans x2', price: r'$38.00'),
            const _LineItem(label: 'Shipping', price: 'Free'),
            Divider(height: 24, color: scheme.outlineVariant),
            const _LineItem(label: 'Total', price: r'$102.00', strong: true),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: done
                  ? OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Start a new order'),
                    )
                  : FilledButton(
                      onPressed: _step == _OrderStep.review ? _complete : null,
                      child: _step == _OrderStep.processing
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : const Text('Complete order'),
                    ),
            ),
            if (knobs.flag('burstOnTap')) ...[
              const Gap(12),
              const DemoCaption('Tap the icon to burst again'),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.label,
    required this.price,
    this.strong = false,
  });

  final String label;
  final String price;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = strong
        ? theme.textTheme.titleSmall
        : theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const Gap(12),
          Text(price, style: style),
        ],
      ),
    );
  }
}

/// A check with confetti frozen mid flight.
class _BurstThumb extends StatelessWidget {
  const _BurstThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = [
      scheme.primary,
      scheme.tertiary,
      demoAccents[3],
      demoAccents[4],
    ];
    final math.Random random = math.Random(7);
    return SizedBox(
      width: 220,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 22; i++) _particle(random, i, colors),
          Icon(Icons.check_circle, size: 56, color: scheme.primary),
        ],
      ),
    );
  }

  Widget _particle(math.Random random, int i, List<Color> colors) {
    final double angle = i / 22 * math.pi * 2 + random.nextDouble();
    final double distance = 44 + random.nextDouble() * 36;
    final double size = 5 + random.nextDouble() * 4;
    final bool circle = i.isEven;
    return Transform.translate(
      offset: Offset(
        math.cos(angle) * distance * 1.3,
        math.sin(angle) * distance * 0.8,
      ),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: circle ? size : size * 0.5,
          decoration: BoxDecoration(
            color: colors[i % colors.length],
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
      ),
    );
  }
}
