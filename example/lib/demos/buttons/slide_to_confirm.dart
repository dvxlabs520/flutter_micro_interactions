import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry slideToConfirmEntry = ComponentEntry(
  id: 'slide-to-confirm',
  name: 'Slide to Confirm',
  category: Categories.buttons,
  summary:
      'Drag a thumb across the track to confirm a payment or another action '
      'that should not happen by accident, with an optional loading state '
      'while the work completes.',
  apis: const ['SlideToConfirm', 'SlideToConfirmController'],
  tags: const [ComponentTag.gesture],
  knobs: [
    const ToggleKnob(
      id: 'async',
      label: 'Async confirm',
      initial: true,
      help: 'Uses onConfirmAsync, so the thumb spins until payment ends.',
    ),
    const ToggleKnob(
      id: 'resetAfterConfirm',
      label: 'Reset after confirm',
      initial: false,
    ),
    const SliderKnob(
      id: 'height',
      label: 'Height',
      min: 44,
      max: 72,
      initial: 56,
      divisions: 14,
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _SlideToConfirmDemo(knobs: knobs),
  thumbnail: (context) => const _SlideThumb(),
  code: (knobs) {
    final bool async = knobs.flag('async');
    final bool autoReset = knobs.flag('resetAfterConfirm');
    final String control = dartCall('SlideToConfirm', {
      if (!autoReset) 'controller': 'controller',
      'label': r"'Slide to pay \$24.99'",
      'height': knobs.arg('height'),
      'fillColor': knobs.arg('color'),
      'thumbColor': knobs.arg('color'),
      'resetAfterConfirm': knobs.arg('resetAfterConfirm'),
      if (async) ...{
        'onConfirmAsync': '() => payments.charge(order)',
        'loadingSemanticLabel': "'Processing payment'",
        'onError': '(error, stackTrace) => showPaymentError(error)',
      } else
        'onConfirmed': '() => payments.charge(order)',
    });
    if (autoReset) return control;
    return 'final controller = SlideToConfirmController();\n\n'
        '$control\n\n'
        '// Later, to start a new order:\n'
        'controller.reset();';
  },
  notes: const [
    'Screen readers get a button labelled with the label text whose tap '
        'confirms directly, and Enter or Space confirms when focused, so '
        'nobody has to perform the drag.',
    'While onConfirmAsync is pending the control is locked and '
        'loadingSemanticLabel is announced once. If the future fails the '
        'thumb springs back so the user can retry.',
    'A light haptic plays on confirmation. Under reduced motion dragging '
        'still works, the spring and settle animations jump to their end, '
        'and the loading spinner becomes a static hourglass.',
  ],
  stageHeight: 460,
);

class _SlideToConfirmDemo extends StatefulWidget {
  const _SlideToConfirmDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SlideToConfirmDemo> createState() => _SlideToConfirmDemoState();
}

class _SlideToConfirmDemoState extends State<_SlideToConfirmDemo> {
  final SlideToConfirmController _controller = SlideToConfirmController();
  Timer? _resetTimer;
  bool _paid = false;

  /// Matches SlideToConfirm.resetDelay, so the receipt and the control
  /// return to rest together.
  static const Duration _resetDelay = Duration(milliseconds: 1200);

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _markPaid() {
    if (!mounted) return;
    setState(() => _paid = true);
    if (widget.knobs.flag('resetAfterConfirm')) {
      _resetTimer?.cancel();
      _resetTimer = Timer(_resetDelay, () {
        if (mounted) setState(() => _paid = false);
      });
    }
  }

  Future<void> _charge() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    _markPaid();
  }

  void _newOrder() {
    _resetTimer?.cancel();
    _controller.reset();
    setState(() => _paid = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool async = knobs.flag('async');
    final bool autoReset = knobs.flag('resetAfterConfirm');
    final Color? color = knobs.color('color');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DemoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.local_cafe_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Harbor Coffee Roasters',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '2 bags, Visa ending 4242',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Divider(height: 1, color: scheme.outlineVariant),
                SizedBox(
                  height: 116,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _paid
                          ? const _Receipt(key: ValueKey('paid'))
                          : _controller.isLoading
                          ? const _Processing(key: ValueKey('loading'))
                          : const _Total(key: ValueKey('total')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          SlideToConfirm(
            controller: _controller,
            label: r'Slide to pay $24.99',
            height: knobs.number('height'),
            fillColor: color,
            thumbColor: color,
            resetAfterConfirm: autoReset,
            resetDelay: _resetDelay,
            loadingSemanticLabel: 'Processing payment',
            onConfirmed: async ? null : _markPaid,
            onConfirmAsync: async ? _charge : null,
          ),
          const Gap(8),
          AnimatedOpacity(
            opacity: _paid && !autoReset ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Center(
              child: TextButton.icon(
                onPressed: _paid && !autoReset ? _newOrder : null,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Start a new order'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Order total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(4),
        Text(r'$24.99', style: theme.textTheme.headlineMedium),
      ],
    );
  }
}

class _Processing extends StatelessWidget {
  const _Processing({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: ShimmerText(
        'Processing payment',
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedCheck(
          size: 52,
          color: theme.colorScheme.tertiary,
          semanticLabel: 'Payment complete',
        ),
        const Gap(10),
        Text(r'Payment of $24.99 complete', style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// A track caught mid slide.
class _SlideThumb extends StatelessWidget {
  const _SlideThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SizedBox(
      width: 300,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Container(
              width: 168,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            Positioned(
              left: 112,
              top: 0,
              bottom: 0,
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.onPrimary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.arrow_forward, color: scheme.onPrimary),
              ),
            ),
            Positioned(
              left: 180,
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  'Slide to pay',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
