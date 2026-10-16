import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry revealOnScrollEntry = ComponentEntry(
  id: 'reveal-on-scroll',
  name: 'Reveal On Scroll',
  category: Categories.lists,
  summary:
      'Plays a short entrance the first time a widget scrolls into view. '
      'Works in any scrollable, with no plugins.',
  apis: const ['RevealOnScroll', 'RevealEffect'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: RevealEffect.values,
      initial: RevealEffect.slideUp,
      typeName: 'RevealEffect',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 1400,
      initial: 600,
      divisions: 12,
    ),
    const SliderKnob(
      id: 'distance',
      label: 'Distance',
      min: 0,
      max: 120,
      initial: 40,
      divisions: 12,
      help: 'How far the slide effects travel.',
    ),
    const SliderKnob(
      id: 'threshold',
      label: 'Threshold',
      min: 0,
      max: 1,
      initial: 0.15,
      divisions: 20,
      help: 'Visible fraction needed to start the entrance.',
    ),
    const ToggleKnob(
      id: 'once',
      label: 'Once',
      initial: true,
      help: 'Off replays the entrance each time a post enters again.',
    ),
  ],
  preview: (context, knobs) => _FeedDemo(knobs: knobs),
  thumbnail: (context) => const _RevealThumb(),
  code: (knobs) {
    return dartCall('ListView.builder', {
      'itemCount': 'posts.length',
      'itemBuilder':
          '(context, i) => ${dartCall('RevealOnScroll', {'effect': knobs.arg('effect'), 'duration': knobs.arg('duration'), 'distance': knobs.arg('distance'), 'threshold': knobs.arg('threshold'), 'once': knobs.arg('once'), 'child': 'PostCard(post: posts[i])'})}',
    });
  },
  notes: const [
    'The child is laid out at its final size from the start and only its '
        'opacity, transform and filters change, so scrolling never jumps. '
        'While hidden it keeps its semantics, so screen readers can reach it.',
    'Visibility is measured from the enclosing scrollables at most once per '
        'frame. Without a scrollable the child reveals right after it mounts.',
    'Under reduced motion, or with enabled set to false, the child is shown '
        'immediately; onRevealed still fires when it scrolls into view.',
  ],
  replayable: true,
  stageHeight: 540,
  layout: StageLayout.fill,
);

class _Post {
  const _Post(this.author, this.time, this.text, [this.image]);

  final String author;
  final String time;
  final String text;
  final GeneratedImage? image;
}

const List<_Post> _posts = [
  _Post(
    'Maya Chen',
    '2 min',
    'Shipped the new onboarding today. Three screens instead of seven.',
  ),
  _Post(
    'Leo Martin',
    '18 min',
    'First light over the ridge this morning.',
    GeneratedImage(
      style: SceneStyle.mountains,
      seed: 1,
      width: 480,
      height: 270,
    ),
  ),
  _Post(
    'Ines Duarte',
    '1 h',
    'Reminder: design review moves to Thursday at 10.',
  ),
  _Post(
    'Sam Okafor',
    '2 h',
    'Played with mesh gradients for the new launch page.',
    GeneratedImage(style: SceneStyle.aurora, seed: 2, width: 480, height: 270),
  ),
  _Post(
    'Ava Rossi',
    '3 h',
    'Our accessibility audit is done: 14 fixes, all small.',
  ),
  _Post(
    'Noah Kim',
    '5 h',
    'Night shift view from the office.',
    GeneratedImage(style: SceneStyle.city, seed: 4, width: 480, height: 270),
  ),
  _Post('Maya Chen', '6 h', 'Anyone up for lunch near the river on Friday?'),
  _Post(
    'Leo Martin',
    '8 h',
    'Desert road trip, day three.',
    GeneratedImage(style: SceneStyle.dunes, seed: 3, width: 480, height: 270),
  ),
  _Post(
    'Ines Duarte',
    '1 d',
    'New icon set is in the library. Feedback welcome.',
  ),
];

class _FeedDemo extends StatelessWidget {
  const _FeedDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RevealEffect effect = knobs.pick('effect');
    final bool once = knobs.flag('once');
    return PhoneFrame(
      title: 'Feed',
      trailing: Icon(
        Icons.edit_square,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      child: ListView.separated(
        // A new key replays the entrances when the effect changes.
        key: ValueKey('${effect.name}-$once'),
        padding: const EdgeInsets.all(14),
        itemCount: _posts.length,
        separatorBuilder: (context, i) => const Gap(12),
        itemBuilder: (context, i) => RevealOnScroll(
          effect: effect,
          duration: knobs.ms('duration'),
          distance: knobs.number('distance'),
          threshold: knobs.number('threshold'),
          once: once,
          child: _PostCard(post: _posts[i], color: demoAccents[i % 6]),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.color});

  final _Post post;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> names = post.author.split(' ');
    return DemoCard(
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DemoAvatar(
                '${names.first[0]}${names.last[0]}',
                color: color,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                post.time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(post.text, style: theme.textTheme.bodyMedium),
          if (post.image != null) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image(
                  image: post.image!,
                  fit: BoxFit.cover,
                  semanticLabel: post.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevealThumb extends StatelessWidget {
  const _RevealThumb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const Gap(8),
            RevealOnScroll(
              delay: Duration(milliseconds: 120 * i),
              child: DemoCard(
                padding: const EdgeInsets.all(10),
                radius: 12,
                child: Row(
                  children: [
                    DemoAvatar(
                      ['MC', 'LM', 'ID'][i],
                      color: demoAccents[i],
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
