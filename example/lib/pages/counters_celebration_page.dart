import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for SuccessBurst, PulseHighlight, AnimatedBadge and
/// AnimatedCounter.
class CountersCelebrationPage extends StatefulWidget {
  const CountersCelebrationPage({super.key});

  @override
  State<CountersCelebrationPage> createState() =>
      _CountersCelebrationPageState();
}

class _CountersCelebrationPageState extends State<CountersCelebrationPage> {
  final SuccessBurstController _burstController = SuccessBurstController();
  final PulseHighlightController _pulseController = PulseHighlightController();

  ParticleShape _shape = ParticleShape.mixed;
  int _cartCount = 0;

  /// Bumped to remount the maxPulseCount demo so its hint plays again.
  int _hintGeneration = 0;

  @override
  void dispose() {
    _burstController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _completeOrder() {
    _burstController.burst();
    context.showToast(
      message: 'Order #1042 completed',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DemoPage(
      title: 'Counters & Celebration',
      description:
          'Particle bursts, pulsing attention hints and animated numbers '
          'for moments worth celebrating.',
      children: [
        DemoSection(
          title: 'SuccessBurst: complete an order',
          description:
              'A SuccessBurstController fires a one-shot particle burst from '
              'the checkmark when the order completes. Particles '
              'intentionally overflow the widget, so leave room around it.',
          child: Column(
            children: [
              Padding(
                // Room for the particles to fly beyond the icon.
                padding: const EdgeInsets.all(32),
                child: SuccessBurst(
                  controller: _burstController,
                  child: Icon(
                    Icons.check_circle,
                    size: 48,
                    color: scheme.primary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _completeOrder,
                icon: const Icon(Icons.shopping_bag),
                label: const Text('Complete order'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'SuccessBurst: particle shapes',
          description:
              'burstOnTap triggers a burst on every tap. Pick the '
              'ParticleShape used for the confetti; mixed combines circles '
              'and rectangles.',
          child: Column(
            children: [
              SegmentedButton<ParticleShape>(
                segments: const [
                  ButtonSegment(
                    value: ParticleShape.mixed,
                    label: Text('Mixed'),
                  ),
                  ButtonSegment(
                    value: ParticleShape.circle,
                    label: Text('Circles'),
                  ),
                  ButtonSegment(
                    value: ParticleShape.rectangle,
                    label: Text('Rectangles'),
                  ),
                ],
                selected: {_shape},
                onSelectionChanged: (selection) {
                  setState(() {
                    _shape = selection.first;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: SuccessBurst(
                  burstOnTap: true,
                  shapes: _shape,
                  particleCount: 32,
                  spreadRadius: 64,
                  child: Icon(
                    Icons.celebration,
                    size: 48,
                    color: scheme.tertiary,
                  ),
                ),
              ),
              Text(
                'Tap the icon to burst',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'AnimatedBadge + AnimatedCounter: cart',
          description:
              'Adding or removing items bounces the badge on the cart icon '
              'and drives both AnimatedCounter modes with the same value: '
              'count tweens the number, slideDigits rolls each changed '
              'digit like an odometer.',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: _cartCount == 0
                        ? null
                        : () => setState(() => _cartCount--),
                    icon: const Icon(Icons.remove),
                    tooltip: 'Remove item',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: AnimatedBadge(
                      count: _cartCount,
                      maxCount: 9,
                      child: const Icon(Icons.shopping_cart, size: 36),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _cartCount++),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add item',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      AnimatedCounter(
                        value: _cartCount,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'count',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      AnimatedCounter(
                        value: _cartCount,
                        mode: CounterAnimationMode.slideDigits,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'slideDigits',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // A formatter turns the same value into a realistic subtotal.
              AnimatedCounter(
                value: _cartCount * 12.5,
                formatter: (value) =>
                    'Subtotal: \$${value.toStringAsFixed(2)}',
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'PulseHighlight: start and stop',
          description:
              'A PulseHighlightController starts and stops the rings around '
              'the settings icon. Tapping the icon also stops them '
              '(stopOnTap).',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: PulseHighlight(
                  controller: _pulseController,
                  autoPlay: false,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: () =>
                        showMessage(context, 'Settings opened'),
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pulseController.start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pulseController.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'PulseHighlight: maxPulseCount',
          description:
              'An onboarding hint that pulses three times and then stops on '
              'its own. Replaying remounts the widget with a new key.',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: PulseHighlight(
                  key: ValueKey<int>(_hintGeneration),
                  maxPulseCount: 3,
                  pulseColor: scheme.tertiary,
                  child: Icon(
                    Icons.notifications,
                    size: 32,
                    color: scheme.tertiary,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _hintGeneration++),
                icon: const Icon(Icons.replay),
                label: const Text('Play hint again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
