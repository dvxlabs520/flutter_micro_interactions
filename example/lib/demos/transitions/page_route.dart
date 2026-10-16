import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

const List<(String, Curve, String)> _curves = [
  ('Ease in out', Curves.easeInOut, 'Curves.easeInOut'),
  ('Ease out cubic', Curves.easeOutCubic, 'Curves.easeOutCubic'),
  ('Fast out slow in', Curves.fastOutSlowIn, 'Curves.fastOutSlowIn'),
  ('Ease out back', Curves.easeOutBack, 'Curves.easeOutBack'),
  ('Linear', Curves.linear, 'Curves.linear'),
];

final ComponentEntry pageRouteEntry = ComponentEntry(
  id: 'page-route',
  name: 'Page Route',
  category: Categories.transitions,
  summary:
      'A page route with ten ready made transitions: fades, slides, scale, '
      'rotate, size, a 3D flip and a blur. Push it directly or through the '
      'MicroNavigator helpers.',
  apis: const ['MicroPageRoute', 'MicroNavigator', 'MicroTransitionType'],
  knobs: [
    SelectKnob.enumeration(
      id: 'type',
      label: 'Transition',
      values: MicroTransitionType.values,
      initial: MicroTransitionType.fade,
      typeName: 'MicroTransitionType',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 150,
      max: 1200,
      initial: 300,
      divisions: 21,
      help: 'Used for both the push and the pop.',
    ),
    SelectKnob<(String, Curve, String)>(
      id: 'curve',
      label: 'Curve',
      options: _curves,
      initial: _curves.first,
      labelOf: (c) => c.$1,
      codeOf: (c) => c.$3,
    ),
  ],
  preview: (context, knobs) => _PageRouteDemo(knobs: knobs),
  thumbnail: (context) => const _PageRouteThumb(),
  code: (knobs) {
    final String? duration = knobs.arg('duration');
    final String push = dartCall(
      'MicroNavigator.push',
      {
        'type': knobs.arg('type'),
        'duration': duration,
        'reverseDuration': duration,
        'curve': knobs.arg('curve'),
      },
      positional: ['context', "const DestinationPage(city: 'Lisbon')"],
    );
    final String route = dartCall('MicroPageRoute', {
      'type': knobs.arg('type'),
      'duration': duration,
      'reverseDuration': duration,
      'curve': knobs.arg('curve'),
      'child': "const DestinationPage(city: 'Lisbon')",
    });
    return '$push;\n\n'
        '// Or build the route yourself:\n'
        'Navigator.of(context).push(${indent(route).trimLeft()});';
  },
  notes: const [
    'Types that can reveal the previous page while animating (fade, scale, '
        'rotate, flip and blur) are not opaque, so the outgoing page stays '
        'visible behind them.',
    'Under reduced motion every type falls back to a plain fade.',
    'MicroNavigator also wraps pushReplacement and pushAndRemoveUntil with '
        'the same options.',
  ],
  stageHeight: 520,
);

const List<(String, String, SceneStyle, int)> _places = [
  ('Lisbon', 'Portugal  ·  3 nights', SceneStyle.city, 4),
  ('Dolomites', 'Italy  ·  5 nights', SceneStyle.mountains, 1),
  ('Wadi Rum', 'Jordan  ·  2 nights', SceneStyle.dunes, 3),
  ('Tromso', 'Norway  ·  4 nights', SceneStyle.aurora, 2),
];

class _PageRouteDemo extends StatefulWidget {
  const _PageRouteDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PageRouteDemo> createState() => _PageRouteDemoState();
}

class _PageRouteDemoState extends State<_PageRouteDemo> {
  void _open(BuildContext navContext, int index) {
    final Knobs knobs = widget.knobs;
    final (String _, Curve curve, String _) = knobs.pick('curve');
    MicroNavigator.push<void>(
      navContext,
      _DetailPage(index: index),
      type: knobs.pick('type'),
      duration: knobs.ms('duration'),
      reverseDuration: knobs.ms('duration'),
      curve: curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            height: 380,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (navContext) =>
                      _ListPage(onOpen: (i) => _open(navContext, i)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const DemoCaption('Tap a trip to push its page.'),
      ],
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Trips'),
        backgroundColor: scheme.surface,
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final (String city, String meta, SceneStyle style, int seed) =
              _places[index];
          return ListTile(
            onTap: () => onOpen(index),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(
                image: GeneratedImage(
                  style: style,
                  seed: seed,
                  width: 240,
                  height: 240,
                ),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(city, style: theme.textTheme.titleSmall),
            subtitle: Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (String city, String meta, SceneStyle style, int seed) =
        _places[index];
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(city), backgroundColor: scheme.surface),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image(
              image: GeneratedImage(style: style, seed: seed),
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pop back to see the reverse transition.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => demoToast(context, 'Trip booked'),
                    child: const Text('Book this trip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageRouteThumb extends StatelessWidget {
  const _PageRouteThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget screen({required bool detail}) {
      Widget bar(double width, {double height = 8, Color? color}) => Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color ?? scheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      );
      return Container(
        width: 120,
        height: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: detail ? scheme.surfaceContainer : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: detail
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(-6, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: detail
              ? [
                  bar(
                    96,
                    height: 54,
                    color: scheme.primary.withValues(alpha: 0.5),
                  ),
                  bar(70),
                  bar(90),
                  bar(50),
                ]
              : [
                  bar(50, color: scheme.onSurfaceVariant),
                  for (int i = 0; i < 4; i++) bar(i.isEven ? 90 : 72),
                ],
        ),
      );
    }

    return SizedBox(
      width: 220,
      height: 180,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: screen(detail: false)),
          Positioned(right: 0, bottom: 0, child: screen(detail: true)),
        ],
      ),
    );
  }
}
