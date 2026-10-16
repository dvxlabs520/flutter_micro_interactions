import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry expandableFabEntry = ComponentEntry(
  id: 'expandable-fab',
  name: 'Expandable Fab',
  category: Categories.backgrounds,
  summary:
      'A floating action button that fans out into a few labeled quick '
      'actions, in a line or on an arc, with a staggered entrance.',
  apis: const [
    'ExpandableFab',
    'ExpandableFabAction',
    'ExpandableFabController',
    'ExpandableFabDirection',
  ],
  knobs: [
    SelectKnob.enumeration(
      id: 'direction',
      label: 'Direction',
      values: ExpandableFabDirection.values,
      initial: ExpandableFabDirection.up,
      typeName: 'ExpandableFabDirection',
    ),
    const SliderKnob(
      id: 'distance',
      label: 'Distance',
      min: 48,
      max: 140,
      initial: 72,
      divisions: 23,
      help: 'Spacing between actions, or the arc radius when radial.',
    ),
    const SliderKnob.duration(
      id: 'stagger',
      label: 'Stagger',
      min: 0,
      max: 150,
      initial: 40,
      divisions: 15,
      help: 'Delay between the entrances of consecutive actions.',
    ),
  ],
  preview: (context, knobs) => _FabDemo(knobs: knobs),
  thumbnail: (context) => const _FabThumb(),
  code: (knobs) {
    String action(String icon, String label, String handler) =>
        dartCall('ExpandableFabAction', {
          'icon': 'const Icon(Icons.$icon)',
          'label': "'$label'",
          'onPressed': handler,
        });
    final String fab = dartCall('ExpandableFab', {
      'direction': knobs.arg('direction'),
      'distance': knobs.arg('distance'),
      'staggerDelay': knobs.arg('stagger'),
      'actions': dartList([
        action('edit', 'Compose', 'compose'),
        action('photo_camera', 'Camera', 'openCamera'),
        action('mic', 'Voice note', 'recordVoiceNote'),
      ]),
    });
    return 'Scaffold(\n'
        '  body: const InboxList(),\n'
        '  floatingActionButton: ${indent(fab).trimLeft()},\n'
        ')';
  },
  notes: const [
    'The widget is only the 56 by 56 main button, so it drops into '
        'floatingActionButton. The actions render in the app Overlay and can '
        'spill outside their parent.',
    'Each label doubles as the tooltip and semantics label of its action. '
        'Tapping outside or pressing Escape closes the fab.',
    'Under reduced motion the fab opens and closes instantly, without '
        'stagger.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

class _FabDemo extends StatefulWidget {
  const _FabDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_FabDemo> createState() => _FabDemoState();
}

class _FabDemoState extends State<_FabDemo> {
  final ExpandableFabController _controller = ExpandableFabController();

  static const List<(String, String, String)> _mail = [
    ('Ava Chen', 'Design review moved to Thursday', 'AC'),
    ('Northwind Billing', 'Your invoice for October is ready', 'NB'),
    ('Leo Martin', 'Photos from the offsite', 'LM'),
    ('Priya Shah', 'Re: Launch checklist', 'PS'),
    ('Sam Okafor', 'Can you review my pull request?', 'SO'),
    ('Mia Rossi', 'Lunch next week?', 'MR'),
    ('Team Digest', 'Five updates from your projects', 'TD'),
  ];

  @override
  void didUpdateWidget(_FabDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Close before the layout of the actions changes.
    _controller.close();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ExpandableFabDirection direction = widget.knobs.pick('direction');

    // Put the fab where the chosen direction has room inside the frame.
    final Alignment anchor = switch (direction) {
      ExpandableFabDirection.down => Alignment.topRight,
      ExpandableFabDirection.right => Alignment.bottomLeft,
      _ => Alignment.bottomRight,
    };

    return PhoneFrame(
      width: 360,
      title: 'Inbox',
      trailing: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
      child: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            itemCount: _mail.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, indent: 68, color: scheme.outlineVariant),
            itemBuilder: (context, index) {
              final (String from, String subject, String initials) =
                  _mail[index];
              return DemoListRow(
                title: from,
                subtitle: subject,
                initials: initials,
                color: demoAccents[index % demoAccents.length],
                trailing: Text(
                  '${9 + index}:${index.isEven ? '30' : '05'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: anchor,
                child: ExpandableFab(
                  controller: _controller,
                  direction: direction,
                  distance: widget.knobs.number('distance'),
                  staggerDelay: widget.knobs.ms('stagger'),
                  actions: [
                    ExpandableFabAction(
                      icon: const Icon(Icons.edit_outlined),
                      label: 'Compose',
                      onPressed: () => demoToast(context, 'New message'),
                    ),
                    ExpandableFabAction(
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: 'Camera',
                      onPressed: () => demoToast(context, 'Opening the camera'),
                    ),
                    ExpandableFabAction(
                      icon: const Icon(Icons.mic_none_rounded),
                      label: 'Voice note',
                      onPressed: () => demoToast(context, 'Recording started'),
                    ),
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

class _FabThumb extends StatelessWidget {
  const _FabThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget mini(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        mini(Icons.mic_none_rounded, 'Voice note'),
        const SizedBox(height: 12),
        mini(Icons.photo_camera_outlined, 'Camera'),
        const SizedBox(height: 12),
        mini(Icons.edit_outlined, 'Compose'),
        const SizedBox(height: 14),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.close_rounded, color: scheme.onPrimaryContainer),
        ),
      ],
    );
  }
}
