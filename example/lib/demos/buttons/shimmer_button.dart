import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry shimmerButtonEntry = ComponentEntry(
  id: 'shimmer-button',
  name: 'Shimmer Button',
  category: Categories.buttons,
  summary:
      'A primary button with a light band that sweeps across it every few '
      'seconds, to draw the eye to the one action that matters.',
  apis: const ['ShimmerButton'],
  knobs: [
    const SliderKnob.duration(
      id: 'shimmerDuration',
      label: 'Sweep duration',
      min: 600,
      max: 4000,
      initial: 2200,
      divisions: 17,
    ),
    const SliderKnob.duration(
      id: 'shimmerInterval',
      label: 'Pause between sweeps',
      min: 0,
      max: 4000,
      initial: 1200,
      divisions: 20,
    ),
    const SliderKnob(
      id: 'radius',
      label: 'Corner radius',
      min: 0,
      max: 28,
      initial: 12,
      divisions: 14,
    ),
    const ColorKnob(id: 'color', label: 'Background', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ShimmerButtonDemo(knobs: knobs),
  thumbnail: (context) => const SizedBox(width: 280, child: _CheckoutButton()),
  code: (knobs) {
    final Color? color = knobs.color('color');
    final String textColor = color == null
        ? 'Theme.of(context).colorScheme.onPrimary'
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? 'Colors.white'
        : 'Colors.black87';
    return dartCall('ShimmerButton', {
      'onPressed': 'openCheckout',
      'shimmerDuration': knobs.arg('shimmerDuration'),
      'shimmerInterval': knobs.arg('shimmerInterval'),
      'borderRadius': knobs.isDefault('radius')
          ? null
          : 'BorderRadius.circular(${knobs.number('radius').round()})',
      'backgroundColor': knobs.arg('color'),
      'child': dartCall(
        'Text',
        {'style': 'TextStyle(color: $textColor)'},
        positional: ["'Checkout securely'"],
      ),
    });
  },
  notes: const [
    'The button is announced as a button, can be activated with Enter or '
        'Space, and shows a visible border while it has keyboard focus.',
    'onPressed fires on tap up and never waits for the press animation. '
        'When it is null or enabled is false the button dims and the '
        'shimmer stops.',
    'Under reduced motion the shimmer never runs and the press scale is '
        'skipped; the button stays fully functional.',
  ],
);

class _ShimmerButtonDemo extends StatelessWidget {
  const _ShimmerButtonDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Order summary', style: theme.textTheme.titleMedium),
            const Gap(14),
            const _LineItem(
              title: 'Linen overshirt',
              detail: 'Sand, size M',
              price: r'$48.00',
            ),
            const Gap(10),
            const _LineItem(
              title: 'Canvas tote',
              detail: 'Natural',
              price: r'$18.00',
            ),
            const Gap(14),
            Divider(height: 1, color: scheme.outlineVariant),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: Text('Total', style: theme.textTheme.titleSmall),
                ),
                Text(r'$66.00', style: theme.textTheme.titleMedium),
              ],
            ),
            const Gap(4),
            Text(
              'Free shipping, arrives Thursday',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(18),
            _CheckoutButton(
              shimmerDuration: knobs.ms('shimmerDuration'),
              shimmerInterval: knobs.ms('shimmerInterval'),
              radius: knobs.number('radius'),
              color: knobs.color('color'),
              onPressed: () => demoToast(context, 'Proceeding to checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.title,
    required this.detail,
    required this.price,
  });

  final String title;
  final String detail;
  final String price;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        const IconBadge(icon: Icons.shopping_bag_outlined, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(price, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    this.shimmerDuration = const Duration(milliseconds: 2200),
    this.shimmerInterval = const Duration(milliseconds: 1200),
    this.radius = 12,
    this.color,
    this.onPressed,
  });

  final Duration shimmerDuration;
  final Duration shimmerInterval;
  final double radius;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = color ?? theme.colorScheme.primary;
    final Color foreground = color == null
        ? theme.colorScheme.onPrimary
        : ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return ShimmerButton(
      onPressed: onPressed ?? () {},
      shimmerDuration: shimmerDuration,
      shimmerInterval: shimmerInterval,
      borderRadius: BorderRadius.circular(radius),
      backgroundColor: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, size: 18, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Checkout securely',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
