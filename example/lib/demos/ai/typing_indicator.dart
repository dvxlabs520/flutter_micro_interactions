import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _int(double v) => '${v.round()}';

final ComponentEntry typingIndicatorEntry = ComponentEntry(
  id: 'typing-indicator',
  name: 'Typing Indicator',
  category: Categories.ai,
  summary:
      'Animated dots that say someone, or an assistant, is writing a reply. '
      'Three motion styles: bounce, pulse and wave.',
  apis: const ['TypingIndicator', 'TypingIndicatorStyle'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SelectKnob.enumeration(
      id: 'style',
      label: 'Style',
      values: TypingIndicatorStyle.values,
      initial: TypingIndicatorStyle.bounce,
      typeName: 'TypingIndicatorStyle',
    ),
    const SliderKnob(
      id: 'dotCount',
      label: 'Dots',
      min: 1,
      max: 6,
      initial: 3,
      divisions: 5,
      format: _int,
      codeOf: _int,
    ),
    const SliderKnob(
      id: 'dotSize',
      label: 'Dot size',
      min: 4,
      max: 14,
      initial: 8,
      divisions: 10,
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _ChatThreadDemo(knobs: knobs),
  thumbnail: (context) => const _TypingThumb(),
  code: (knobs) => dartCall('TypingIndicator', {
    'style': knobs.arg('style'),
    'dotCount': knobs.arg('dotCount'),
    'dotSize': knobs.arg('dotSize'),
    'color': knobs.arg('color'),
  }),
  notes: const [
    'The indicator is exposed with semanticLabel, "Typing" by default, so '
        'screen readers can announce it.',
    'All dots run on a single looping controller. Under reduced motion, or '
        'with enabled set to false, the dots render statically.',
  ],
  stageHeight: 440,
);

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child, required this.mine});

  final Widget child;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const Radius r = Radius.circular(18);
    const Radius tail = Radius.circular(4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: mine ? r : tail,
          bottomRight: mine ? tail : r,
        ),
      ),
      child: child,
    );
  }
}

class _ChatThreadDemo extends StatelessWidget {
  const _ChatThreadDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double dotSize = knobs.number('dotSize');

    Widget text(String value, {bool mine = false}) => Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: mine ? scheme.onPrimary : scheme.onSurface,
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DemoCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  DemoAvatar('MC', color: demoAccents[4], size: 34),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Maya Chen', style: theme.textTheme.titleSmall),
                        Text(
                          'typing...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Bubble(
                      mine: false,
                      child: text('Did the new build fix the scroll jank?'),
                    ),
                  ),
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Bubble(
                      mine: true,
                      child: text(
                        'Yes, frames stay under 8 ms now.',
                        mine: true,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _Bubble(
                      mine: true,
                      child: text('Want a screen recording?', mine: true),
                    ),
                  ),
                  const Gap(12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Bubble(
                      mine: false,
                      child: SizedBox(
                        height: math.max(20, dotSize * 2.4),
                        child: Center(
                          widthFactor: 1,
                          child: TypingIndicator(
                            style: knobs.pick('style'),
                            dotCount: knobs.number('dotCount').round(),
                            dotSize: dotSize,
                            color: knobs.color('color'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingThumb extends StatelessWidget {
  const _TypingThumb();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DemoAvatar('MC', color: demoAccents[4], size: 40),
        const Gap(10),
        const _Bubble(
          mine: false,
          child: SizedBox(
            height: 24,
            child: Center(widthFactor: 1, child: TypingIndicator(dotSize: 10)),
          ),
        ),
      ],
    );
  }
}
