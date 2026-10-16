import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry pulseHeartEntry = ComponentEntry(
  id: 'pulse-heart',
  name: 'Pulse Heart',
  category: Categories.buttons,
  summary:
      'A like button whose heart collapses to a dot, changes color and '
      'pulses back out with a ring burst, while the count rolls to its new '
      'value.',
  apis: const ['PulseHeart'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob(
      id: 'size',
      label: 'Size',
      min: 20,
      max: 44,
      initial: 28,
      divisions: 12,
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 300,
      max: 1400,
      initial: 700,
      divisions: 11,
    ),
    const ToggleKnob(
      id: 'burst',
      label: 'Burst',
      initial: true,
      help: 'Ring and particles when liking.',
    ),
    const ToggleKnob(id: 'showCount', label: 'Show count', initial: true),
    const ColorKnob(
      id: 'likedColor',
      label: 'Liked color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _PulseHeartDemo(knobs: knobs),
  thumbnail: (context) => const _HeartThumb(),
  code: (knobs) {
    final String call = dartCall('PulseHeart', {
      'liked': '_liked',
      'count': '_likes',
      'onChanged':
          '(bool liked) => setState(() {\n'
          '  _liked = liked;\n'
          '  _likes += liked ? 1 : -1;\n'
          '})',
      'size': knobs.arg('size'),
      'duration': knobs.arg('duration'),
      'burst': knobs.arg('burst'),
      'showCount': knobs.arg('showCount'),
      'likedColor': knobs.arg('likedColor'),
    });
    return 'bool _liked = false;\nint _likes = 128;\n\n$call';
  },
  notes: const [
    'A single toggle button with semanticLabel as its label, the like state '
        'as its toggled state and the count as its value. Enter or Space '
        'activates it and the touch target is at least 48 by 48.',
    'Every change of liked is animated, including changes that do not come '
        'from a tap. A light haptic impact plays on tap.',
    'Under reduced motion the heart and the count change instantly with no '
        'burst.',
  ],
);

class _PulseHeartDemo extends StatefulWidget {
  const _PulseHeartDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PulseHeartDemo> createState() => _PulseHeartDemoState();
}

class _PulseHeartDemoState extends State<_PulseHeartDemo> {
  bool _liked = false;
  int _likes = 128;

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  const DemoAvatar('LK', size: 32, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Lena Kovac', style: theme.textTheme.titleSmall),
                        Text(
                          'Dolomites, 2 h ago',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onDoubleTap: _liked
                  ? null
                  : () => setState(() {
                      _liked = true;
                      _likes++;
                    }),
              child: const AspectRatio(
                aspectRatio: 16 / 10,
                child: Image(
                  image: GeneratedImage(style: SceneStyle.mountains, seed: 3),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
              child: Row(
                children: [
                  PulseHeart(
                    liked: _liked,
                    count: _likes,
                    onChanged: (bool liked) => setState(() {
                      _liked = liked;
                      _likes += liked ? 1 : -1;
                    }),
                    size: knobs.number('size'),
                    duration: knobs.ms('duration'),
                    burst: knobs.flag('burst'),
                    showCount: knobs.flag('showCount'),
                    likedColor: knobs.color('likedColor'),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.mode_comment_outlined,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '14',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'First light over the ridge. Worth the 4 am start.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartThumb extends StatefulWidget {
  const _HeartThumb();

  @override
  State<_HeartThumb> createState() => _HeartThumbState();
}

class _HeartThumbState extends State<_HeartThumb> {
  Timer? _timer;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => setState(() => _liked = !_liked),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PulseHeart(
        liked: _liked,
        count: _liked ? 129 : 128,
        onChanged: (_) {},
        size: 40,
      ),
    );
  }
}
