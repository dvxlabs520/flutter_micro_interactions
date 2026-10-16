import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry reflectiveCardEntry = ComponentEntry(
  id: 'reflective-card',
  name: 'Reflective Card',
  category: Categories.cards,
  summary:
      'A metal card that tilts toward the pointer and catches the light, '
      'like a chrome membership card turned in the hand.',
  apis: const ['ReflectiveCard', 'ReflectiveCardFinish'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    SelectKnob.enumeration(
      id: 'finish',
      label: 'Finish',
      values: ReflectiveCardFinish.values,
      initial: ReflectiveCardFinish.chrome,
      typeName: 'ReflectiveCardFinish',
    ),
    const SliderKnob(
      id: 'maxTilt',
      label: 'Max tilt',
      min: 0,
      max: 30,
      initial: 14,
      divisions: 15,
      help: 'Degrees reached with the pointer at an edge.',
    ),
    const ToggleKnob(
      id: 'holographic',
      label: 'Holographic foil',
      initial: false,
      help: 'Always on for the holographic finish.',
    ),
    const ToggleKnob(id: 'brushed', label: 'Brushed texture', initial: true),
    const ToggleKnob(
      id: 'reflection',
      label: 'Reflection',
      initial: false,
      help: 'A faint image that drifts opposite to the tilt.',
    ),
    const ToggleKnob(id: 'idleAnimation', label: 'Idle sweep', initial: true),
  ],
  preview: (context, knobs) => _ReflectiveDemo(knobs: knobs),
  thumbnail: (context) => const ReflectiveCard(
    width: 220,
    child: _MemberCardContent(compact: true),
  ),
  code: (knobs) {
    return dartCall('ReflectiveCard', {
      'finish': knobs.arg('finish'),
      'maxTilt': knobs.arg('maxTilt'),
      'holographic': knobs.arg('holographic'),
      'brushed': knobs.arg('brushed'),
      'reflection': knobs.flag('reflection')
          ? "const AssetImage('assets/studio.jpg')"
          : null,
      'idleAnimation': knobs.arg('idleAnimation'),
      'width': '340',
      'child': 'const MemberCardContent()',
    });
  },
  notes: const [
    'All metal and light layers are decorative and add no semantics; the '
        'semantics of the child are untouched.',
    'Pointer events are observed without being consumed, so buttons inside '
        'the card keep working. On touch, the card tilts while a finger drags '
        'over it and springs back on release.',
    'Under reduced motion, or with enabled set to false, the card renders '
        'flat with a static sheen: no tilt, no idle sweep and no animation.',
  ],
  stageHeight: 400,
);

class _ReflectiveDemo extends StatelessWidget {
  const _ReflectiveDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ReflectiveCard(
            finish: knobs.pick('finish'),
            maxTilt: knobs.number('maxTilt'),
            holographic: knobs.flag('holographic'),
            brushed: knobs.flag('brushed'),
            reflection: knobs.flag('reflection')
                ? const GeneratedImage(
                    style: SceneStyle.city,
                    seed: 4,
                    width: 480,
                    height: 320,
                  )
                : null,
            idleAnimation: knobs.flag('idleAnimation'),
            child: const _MemberCardContent(),
          ),
        ),
        const Gap(28),
        const DemoCaption('Hover the card, or press and drag on touch'),
      ],
    );
  }
}

/// The printed side of a membership card. Text and icon colors come from
/// the card, so they read well on every finish.
class _MemberCardContent extends StatelessWidget {
  const _MemberCardContent({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double s = compact ? 0.66 : 1;
    return Padding(
      padding: EdgeInsets.all(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.all_inclusive_rounded, size: 22 * s),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  'ATELIER CLUB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Text(
                'PLATINUM',
                style: TextStyle(
                  fontSize: 10 * s,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 34 * s,
            height: 26 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5 * s),
              border: Border.all(
                color: (DefaultTextStyle.of(context).style.color ?? Colors.grey)
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            '4021  8830  0042  1987',
            maxLines: 1,
            style: TextStyle(
              fontSize: 15 * s,
              letterSpacing: 1.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 10 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'ADA LOVELACE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                'SINCE 2021',
                style: TextStyle(fontSize: 10 * s, letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
