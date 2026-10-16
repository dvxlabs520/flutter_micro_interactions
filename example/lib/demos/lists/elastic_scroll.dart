import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

enum _Variant { list, grid, scroll }

final ComponentEntry elasticScrollEntry = ComponentEntry(
  id: 'elastic-scroll',
  name: 'Elastic Scroll',
  category: Categories.lists,
  summary:
      'Scroll physics that let content stretch past its edges and spring '
      'back. Ready made list, grid and single child versions.',
  apis: const [
    'ElasticListView',
    'ElasticGridView',
    'ElasticScroll',
    'ElasticScrollPhysics',
  ],
  tags: const [ComponentTag.gesture],
  knobs: [
    SelectKnob<_Variant>(
      id: 'variant',
      label: 'Variant',
      options: _Variant.values,
      initial: _Variant.list,
      labelOf: (v) => switch (v) {
        _Variant.list => 'ListView',
        _Variant.grid => 'GridView',
        _Variant.scroll => 'Scroll',
      },
    ),
    const SliderKnob(
      id: 'elasticity',
      label: 'Elasticity',
      min: 0.1,
      max: 1,
      initial: 0.3,
      divisions: 9,
      help: 'How far a drag past the edge moves the content.',
    ),
    const SliderKnob(
      id: 'stiffness',
      label: 'Stiffness',
      min: 20,
      max: 400,
      initial: 100,
      divisions: 19,
      help: 'Higher values snap back faster.',
    ),
    const SliderKnob(
      id: 'damping',
      label: 'Damping',
      min: 0.3,
      max: 1.2,
      initial: 0.8,
      divisions: 9,
      help: 'Below 1 the content overshoots slightly.',
    ),
  ],
  preview: (context, knobs) => _ElasticDemo(knobs: knobs),
  thumbnail: (context) => const _ElasticThumb(),
  code: (knobs) {
    final Map<String, String?> physics = {
      'elasticity': knobs.arg('elasticity'),
      'stiffness': knobs.arg('stiffness'),
      'damping': knobs.arg('damping'),
    };
    return switch (knobs.pick<_Variant>('variant')) {
      _Variant.list => dartCall('ElasticListView.builder', {
        ...physics,
        'itemCount': 'activity.length',
        'itemBuilder': '(context, i) => ActivityTile(activity[i])',
      }),
      _Variant.grid => dartCall('ElasticGridView', {
        'crossAxisCount': '3',
        'mainAxisSpacing': '4',
        'crossAxisSpacing': '4',
        ...physics,
        'children': '[for (final photo in photos) PhotoTile(photo)]',
      }),
      _Variant.scroll => dartCall('ElasticScroll', {
        ...physics,
        'padding': 'const EdgeInsets.all(20)',
        'child': 'const ArticleBody()',
      }),
    };
  },
  notes: const [
    'The effect comes entirely from ElasticScrollPhysics, so it adds no '
        'semantics and keeps the scrollable fully accessible. The physics '
        'also work on any ListView or CustomScrollView.',
    'Under reduced motion the physics clamp at the edges and nothing '
        'bounces. With enabled set to false the ambient physics apply.',
    'Drag past the top or bottom edge and release to feel the spring.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

const List<(String, String)> _activity = [
  ('Alice Bennett', 'Commented on Onboarding v3'),
  ('Bruno Carvalho', 'Shipped build 2.4 to TestFlight'),
  ('Chen Wei', 'Shared Q4 forecast'),
  ('Daniela Rossi', 'Moved Launch checklist to Done'),
  ('Emeka Obi', 'Raised API rate limits'),
  ('Farah Khan', 'Closed 12 support tickets'),
  ('Gustav Lindqvist', 'Scheduled 3 interviews'),
  ('Hana Sato', 'Approved the design review'),
  ('Ines Duarte', 'Signed a new customer'),
  ('Jonas Weber', 'Updated the budget'),
  ('Katya Petrova', 'Filed a regression'),
  ('Liam Murphy', 'Fixed the Android crash'),
];

class _ElasticDemo extends StatelessWidget {
  const _ElasticDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double elasticity = knobs.number('elasticity');
    final double stiffness = knobs.number('stiffness');
    final double damping = knobs.number('damping');
    final _Variant variant = knobs.pick('variant');

    final Widget body = switch (variant) {
      _Variant.list => ElasticListView.builder(
        elasticity: elasticity,
        stiffness: stiffness,
        damping: damping,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _activity.length,
        itemBuilder: (context, i) {
          final (String name, String action) = _activity[i];
          return DemoListRow(
            title: name,
            subtitle: action,
            color: demoAccents[i % demoAccents.length],
            trailing: Text(
              '${i * 7 + 2}m',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
      _Variant.grid => ElasticGridView(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        elasticity: elasticity,
        stiffness: stiffness,
        damping: damping,
        padding: const EdgeInsets.all(4),
        children: [
          for (int i = 0; i < 24; i++)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image(
                image: GeneratedImage(
                  style: SceneStyle.values[i % SceneStyle.values.length],
                  seed: i + 1,
                  width: 240,
                  height: 240,
                ),
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
      _Variant.scroll => ElasticScroll(
        elasticity: elasticity,
        stiffness: stiffness,
        damping: damping,
        padding: const EdgeInsets.all(20),
        child: const _Article(),
      ),
    };

    return PhoneFrame(
      title: switch (variant) {
        _Variant.list => 'Activity',
        _Variant.grid => 'Photos',
        _Variant.scroll => 'Article',
      },
      // Lets a mouse drag the content on desktop, like a finger.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: body,
      ),
    );
  }
}

class _Article extends StatelessWidget {
  const _Article();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? body = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESIGN NOTES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const Gap(8),
        Text(
          'Why motion should feel physical',
          style: theme.textTheme.headlineSmall,
        ),
        const Gap(16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const AspectRatio(
            aspectRatio: 16 / 9,
            child: Image(
              image: GeneratedImage(style: SceneStyle.dunes, seed: 3),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Gap(16),
        Text(
          'People read motion as a material. When a list stops dead at its '
          'edge it feels like a wall; when it gives a little and springs '
          'back it feels like something you can hold.',
          style: body,
        ),
        const Gap(12),
        Text(
          'The trick is restraint. A small stretch with a quick, well damped '
          'return tells the user they reached the end without slowing them '
          'down.',
          style: body,
        ),
        const Gap(12),
        Text(
          'Tune elasticity for how far the content follows the finger, '
          'stiffness for how fast it returns, and damping for how much it '
          'overshoots on the way back.',
          style: body,
        ),
      ],
    );
  }
}

/// A list stretched past its top edge.
class _ElasticThumb extends StatelessWidget {
  const _ElasticThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 26,
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              size: 18,
              color: scheme.primary,
            ),
          ),
          for (int i = 0; i < 2; i++)
            Transform.translate(
              offset: Offset(0, 4 - i * 4.0),
              child: DemoListRow(
                title: _activity[i].$1,
                subtitle: _activity[i].$2,
                color: demoAccents[i],
              ),
            ),
        ],
      ),
    );
  }
}
