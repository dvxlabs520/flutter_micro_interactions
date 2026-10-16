import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

/// Ready made color sets for the palette knob. `theme` keeps the widget
/// default (primary and tertiary of the color scheme).
enum _Palette {
  theme(null),
  aurora([Color(0xFF6E7BFF), Color(0xFF38BDF8), Color(0xFF34D399)]),
  sunset([Color(0xFFF59E0B), Color(0xFFF472B6), Color(0xFFA78BFA)]),
  ocean([Color(0xFF38BDF8), Color(0xFF6E7BFF)]);

  const _Palette(this.colors);

  final List<Color>? colors;

  String get code => colors == null
      ? 'null'
      : 'const ${dartList([for (final Color c in colors!) colorCode(c)])}';
}

final ComponentEntry animatedGradientBorderEntry = ComponentEntry(
  id: 'animated-gradient-border',
  name: 'Animated Gradient Border',
  category: Categories.borders,
  summary:
      'A sweeping gradient that rotates around the edge of a card or '
      'button, with an optional soft glow. Use it to mark the one item '
      'that deserves attention, such as a recommended plan.',
  apis: const ['AnimatedGradientBorder', 'AnimatedGradientBorderController'],
  knobs: [
    const SliderKnob(
      id: 'borderWidth',
      label: 'Border width',
      min: 0.5,
      max: 6,
      initial: 2,
      divisions: 11,
    ),
    const SliderKnob(
      id: 'glowRadius',
      label: 'Glow radius',
      min: 0,
      max: 16,
      initial: 0,
      divisions: 16,
      help: 'A blurred copy of the stroke. 0 turns the glow off.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 1000,
      max: 6000,
      initial: 3000,
      divisions: 10,
      help: 'Time for one full rotation.',
    ),
    SelectKnob<_Palette>(
      id: 'palette',
      label: 'Palette',
      options: _Palette.values,
      initial: _Palette.theme,
      labelOf: (p) => switch (p) {
        _Palette.theme => 'Theme',
        _Palette.aurora => 'Aurora',
        _Palette.sunset => 'Sunset',
        _Palette.ocean => 'Ocean',
      },
      codeOf: (p) => p.code,
    ),
    const ToggleKnob(
      id: 'animate',
      label: 'Animate',
      initial: true,
      help: 'Calls start() and stop() on the controller.',
    ),
  ],
  preview: (context, knobs) => _GradientBorderDemo(knobs: knobs),
  thumbnail: (context) => const AnimatedGradientBorder(
    borderWidth: 2,
    glowRadius: 6,
    borderRadius: BorderRadius.all(Radius.circular(20)),
    padding: EdgeInsets.all(18),
    child: SizedBox(width: 240, child: _PlanContent(compact: true)),
  ),
  code: (knobs) {
    final String border = dartCall('AnimatedGradientBorder', {
      'controller': 'controller',
      'autoPlay': knobs.flag('animate') ? null : 'false',
      'colors': knobs.arg('palette'),
      'borderWidth': knobs.arg('borderWidth'),
      'glowRadius': knobs.arg('glowRadius'),
      'duration': knobs.arg('duration'),
      'borderRadius': 'BorderRadius.circular(20)',
      'padding': 'const EdgeInsets.all(20)',
      'backgroundColor': 'Theme.of(context).colorScheme.surfaceContainer',
      'child': "const PricingCard(plan: 'Pro')",
    });
    return 'final controller = AnimatedGradientBorderController();\n\n'
        '$border\n\n'
        '// Pause or resume the sweep, for example when the plan is chosen.\n'
        'controller.stop();\n'
        'controller.start();';
  },
  notes: const [
    'The border is decorative and adds no semantics; the child keeps its '
        'own labels and hit testing.',
    'Under reduced motion, or with enabled set to false, the border renders '
        'statically and never animates.',
    'The controller reports isPlaying, which also turns false when the '
        'widget stops itself because of reduced motion.',
  ],
);

class _GradientBorderDemo extends StatefulWidget {
  const _GradientBorderDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_GradientBorderDemo> createState() => _GradientBorderDemoState();
}

class _GradientBorderDemoState extends State<_GradientBorderDemo> {
  final AnimatedGradientBorderController _controller =
      AnimatedGradientBorderController();

  @override
  void didUpdateWidget(_GradientBorderDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.knobs.flag('animate')) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final _Palette palette = knobs.pick('palette');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: AnimatedGradientBorder(
        controller: _controller,
        autoPlay: knobs.flag('animate'),
        colors: palette.colors,
        borderWidth: knobs.number('borderWidth'),
        glowRadius: knobs.number('glowRadius'),
        duration: knobs.ms('duration'),
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(20),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        child: const _PlanContent(),
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Pro', style: theme.textTheme.titleMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Recommended',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              r'$12',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'per seat / month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            'For growing teams that ship every week.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final String feature in const [
            'Unlimited projects',
            'Priority support',
            'Advanced analytics',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 18, color: scheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(feature, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => demoToast(
                context,
                'Upgraded to Pro',
                type: ToastType.success,
              ),
              child: const Text('Upgrade to Pro'),
            ),
          ),
        ],
      ],
    );
  }
}
