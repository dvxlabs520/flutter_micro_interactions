import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry longPressMenuEntry = ComponentEntry(
  id: 'long-press-menu',
  name: 'Long Press Menu',
  category: Categories.backgrounds,
  summary:
      'Opens a context menu right where the user long presses, with a '
      'haptic tick. Handy for photos, messages and list items.',
  apis: const ['LongPressMenu', 'LongPressMenuItem'],
  tags: const [ComponentTag.gesture],
  knobs: [
    const ToggleKnob(
      id: 'haptics',
      label: 'Haptics',
      initial: true,
      help: 'A medium impact when the menu opens.',
    ),
    const SliderKnob(
      id: 'radius',
      label: 'Menu radius',
      min: 0,
      max: 24,
      initial: 8,
      divisions: 12,
    ),
    const SliderKnob(
      id: 'elevation',
      label: 'Elevation',
      min: 0,
      max: 24,
      initial: 8,
      divisions: 12,
    ),
  ],
  preview: (context, knobs) => _LongPressDemo(knobs: knobs),
  thumbnail: (context) => const _LongPressThumb(),
  code: (knobs) => dartCall('LongPressMenu', {
    'enableHaptics': knobs.arg('haptics'),
    'menuBorderRadius': knobs.arg('radius'),
    'menuElevation': knobs.arg('elevation'),
    'menuItems': dartList([
      'LongPressMenuItem.favorite(onTap: addToFavorites)',
      'LongPressMenuItem.share(onTap: sharePhoto)',
      'LongPressMenuItem.copy(onTap: copyLink)',
      'LongPressMenuItem.delete(onTap: deletePhoto)',
    ]),
    'child': 'PhotoCard(photo: photo)',
  }),
  notes: const [
    'Every enabled item is also exposed as a custom semantics action, so '
        'screen reader users can run it without the long press.',
    'Destructive items, such as Delete, are drawn with the error color.',
    'A medium impact haptic fires when the menu opens, unless haptics are '
        'turned off. With enabled set to false the child renders without the '
        'gesture.',
  ],
);

class _LongPressDemo extends StatelessWidget {
  const _LongPressDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LongPressMenu(
            enableHaptics: knobs.flag('haptics'),
            menuBorderRadius: knobs.number('radius'),
            menuElevation: knobs.number('elevation'),
            menuItems: [
              LongPressMenuItem.favorite(
                onTap: () => demoToast(context, 'Added to favorites'),
              ),
              LongPressMenuItem.share(
                onTap: () => demoToast(context, 'Share sheet opened'),
              ),
              LongPressMenuItem.copy(
                onTap: () => demoToast(context, 'Link copied'),
              ),
              LongPressMenuItem.delete(
                onTap: () =>
                    demoToast(context, 'Photo deleted', type: ToastType.error),
              ),
            ],
            child: const _PhotoCard(),
          ),
          const SizedBox(height: 20),
          const DemoCaption('Press and hold the photo.'),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 10,
            child: Image(
              image: GeneratedImage(style: SceneStyle.mountains, seed: 1),
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
            child: Row(
              children: [
                const Expanded(
                  child: DemoCardText(
                    title: 'Lago di Braies',
                    body: 'Dolomites, Italy  ·  4.2 MB',
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LongPressThumb extends StatelessWidget {
  const _LongPressThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget item(IconData icon, String label, {bool destructive = false}) {
      final Color? c = destructive ? scheme.error : null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c ?? scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: c)),
          ],
        ),
      );
    }

    return SizedBox(
      width: 330,
      height: 190,
      child: Stack(
        children: [
          const Positioned(left: 0, top: 0, child: _PhotoCard(width: 220)),
          Positioned(
            right: 0,
            top: 40,
            child: Material(
              color: scheme.surfaceContainerHighest,
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item(Icons.favorite, 'Favorite'),
                    item(Icons.share, 'Share'),
                    item(Icons.delete, 'Delete', destructive: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
