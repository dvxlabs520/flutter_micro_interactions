import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

enum _Layout { card, list, grid }

final ComponentEntry skeletonsEntry = ComponentEntry(
  id: 'skeletons',
  name: 'Skeletons',
  category: Categories.loading,
  summary:
      'Shimmering placeholders shaped like the content that is about to '
      'load, with a loader that cross-fades to the real thing.',
  apis: const [
    'LoadingSkeleton',
    'TextSkeleton',
    'CardSkeleton',
    'ListItemSkeleton',
    'GridItemSkeleton',
    'SkeletonScope',
    'SkeletonLoader',
  ],
  knobs: [
    SelectKnob<_Layout>(
      id: 'variant',
      label: 'Variant',
      options: _Layout.values,
      initial: _Layout.card,
      labelOf: (v) => switch (v) {
        _Layout.card => 'Card',
        _Layout.list => 'List',
        _Layout.grid => 'Grid',
      },
    ),
    const ToggleKnob(
      id: 'loading',
      label: 'Loading',
      initial: true,
      help: 'Turn it off to cross-fade to the real content.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Shimmer duration',
      min: 600,
      max: 3000,
      initial: 1500,
      divisions: 24,
    ),
  ],
  preview: (context, knobs) => _SkeletonDemo(knobs: knobs),
  thumbnail: (context) => const _SkeletonThumb(),
  code: (knobs) {
    final String skeleton = switch (knobs.pick<_Layout>('variant')) {
      _Layout.card => 'const CardSkeleton(imageHeight: 140)',
      _Layout.list => 'const ListItemSkeleton(hasTrailing: true)',
      _Layout.grid => 'const GridItemSkeleton(imageAspectRatio: 4 / 3)',
    };
    final String child = switch (knobs.pick<_Layout>('variant')) {
      _Layout.card => 'ArticleCard(article)',
      _Layout.list => 'MessageTile(message)',
      _Layout.grid => 'ProductTile(product)',
    };
    return dartCall('SkeletonScope', {
      'duration': knobs.arg('duration'),
      'child': dartCall('SkeletonLoader', {
        'loading': 'isLoading',
        'skeleton': skeleton,
        'child': child,
      }),
    });
  },
  notes: const [
    'Each skeleton is hidden from screen readers and announced as a single '
        '"Loading" node.',
    'SkeletonScope shares one shimmer animation between every skeleton '
        'below it, so they stay in sync and use one ticker.',
    'Under reduced motion the shimmer is static and SkeletonLoader swaps '
        'without a fade.',
  ],
);

class _SkeletonDemo extends StatelessWidget {
  const _SkeletonDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final bool loading = knobs.flag('loading');
    final Duration duration = knobs.ms('duration');
    final Widget body = switch (knobs.pick<_Layout>('variant')) {
      _Layout.card => _CardVariant(loading: loading),
      _Layout.list => _ListVariant(loading: loading),
      _Layout.grid => _GridVariant(loading: loading),
    };
    // The key restarts the shared shimmer when the duration changes.
    return SkeletonScope(
      key: ValueKey(duration),
      duration: duration,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: body,
      ),
    );
  }
}

class _CardVariant extends StatelessWidget {
  const _CardVariant({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SkeletonLoader(
      loading: loading,
      skeleton: const CardSkeleton(imageHeight: 140),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 140,
              width: double.infinity,
              child: Image(
                image: GeneratedImage(style: SceneStyle.mountains, seed: 1),
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A weekend in the Dolomites',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Gap(8),
                  Text(
                    'Three hikes, two refuges and the best polenta in '
                    'Val Gardena. A short guide for first timers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _ListVariant extends StatelessWidget {
  const _ListVariant({required this.loading});

  final bool loading;

  static const List<(String, String, String)> _rows = [
    ('Alice Bennett', 'Notes from the kickoff', '9:41'),
    ('Bruno Carvalho', 'TestFlight build 2.4 is ready', '9:12'),
    ('Chen Wei', 'Dataset for the Q4 forecast', '8:30'),
    ('Daniela Rossi', 'Launch checklist', 'Tue'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DemoCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _rows.length; i++)
            SkeletonLoader(
              loading: loading,
              skeleton: const ListItemSkeleton(
                hasTrailing: true,
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: DemoListRow(
                title: _rows[i].$1,
                subtitle: _rows[i].$2,
                color: demoAccents[i],
                trailing: Text(
                  _rows[i].$3,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridVariant extends StatelessWidget {
  const _GridVariant({required this.loading});

  final bool loading;

  static const List<(String, String)> _products = [
    ('Ceramic mug', r'$24'),
    ('Linen tote', r'$38'),
    ('Pour over set', r'$64'),
    ('Desk lamp', r'$89'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < 2; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int col = 0; col < 2; col++)
                Expanded(
                  child: SkeletonLoader(
                    loading: loading,
                    skeleton: const GridItemSkeleton(imageAspectRatio: 4 / 3),
                    child: _ProductTile(
                      index: row * 2 + col,
                      name: _products[row * 2 + col].$1,
                      price: _products[row * 2 + col].$2,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.index,
    required this.name,
    required this.price,
  });

  final int index;
  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: GeneratedImage.gallery[index + 1],
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Gap(6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            price,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonThumb extends StatelessWidget {
  const _SkeletonThumb();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 300,
      child: SkeletonScope(
        child: DemoCard(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListItemSkeleton(hasTrailing: true),
              ListItemSkeleton(hasTrailing: true),
            ],
          ),
        ),
      ),
    );
  }
}
