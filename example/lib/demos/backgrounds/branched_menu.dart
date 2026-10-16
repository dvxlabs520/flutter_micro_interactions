import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry branchedMenuEntry = ComponentEntry(
  id: 'branched-menu',
  name: 'Branched Menu',
  category: Categories.backgrounds,
  summary:
      'A collapsible navigation menu, like a docs sidebar, whose items branch '
      'off a vertical trunk. The selection is traced along the trunk from '
      'the old item to the new one.',
  apis: const ['BranchedMenu', 'BranchedMenuSection', 'BranchedMenuItem'],
  tags: const [ComponentTag.newly],
  knobs: [
    const SliderKnob.duration(
      id: 'traceDuration',
      label: 'Trace duration',
      min: 200,
      max: 1400,
      initial: 480,
      divisions: 12,
      help: 'Retract from the old item, then grow to the new one.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Expand duration',
      min: 100,
      max: 800,
      initial: 300,
      divisions: 14,
    ),
    const SliderKnob(
      id: 'indent',
      label: 'Indent',
      min: 16,
      max: 40,
      initial: 24,
      divisions: 12,
    ),
    const SliderKnob(
      id: 'itemHeight',
      label: 'Row height',
      min: 28,
      max: 44,
      initial: 36,
      divisions: 8,
    ),
    const ColorKnob(
      id: 'highlightColor',
      label: 'Highlight color',
      swatches: demoSwatches,
    ),
  ],
  preview: (context, knobs) => _BranchedMenuDemo(knobs: knobs),
  thumbnail: (context) => const _BranchedThumb(),
  code: (knobs) =>
      "String? _page = 'install';\n\n${dartCall('BranchedMenu', {'selectedId': '_page', 'onSelected': '(String id) => setState(() => _page = id)', 'traceDuration': knobs.arg('traceDuration'), 'duration': knobs.arg('duration'), 'indent': knobs.arg('indent'), 'itemHeight': knobs.arg('itemHeight'), 'highlightColor': knobs.arg('highlightColor'), 'sections': _sectionsCode})}",
  stageHeight: 480,
  notes: const [
    'Headers are buttons with an expanded state and items are buttons with '
        'a selected state. Up and Down move between visible rows, Right and '
        'Left expand and collapse, Enter or Space activates.',
    'When the section of the selected item collapses, the highlight follows '
        'it up to the section node.',
    'Under reduced motion, or when enabled is false, sections open and '
        'close instantly and the highlight jumps without tracing.',
  ],
);

const List<BranchedMenuSection> _sections = [
  BranchedMenuSection(
    title: 'Getting started',
    items: [
      BranchedMenuItem(id: 'intro', label: 'Introduction'),
      BranchedMenuItem(id: 'install', label: 'Installation'),
      BranchedMenuItem(id: 'theming', label: 'Theming'),
    ],
  ),
  BranchedMenuSection(
    title: 'Components',
    items: [
      BranchedMenuItem(id: 'button', label: 'Button', badge: 'New'),
      BranchedMenuItem(id: 'dialog', label: 'Dialog'),
      BranchedMenuItem(id: 'tooltip', label: 'Tooltip'),
    ],
  ),
  BranchedMenuSection(
    title: 'Export',
    initiallyExpanded: false,
    items: [
      BranchedMenuItem(id: 'pdf', label: 'PDF'),
      BranchedMenuItem(id: 'png', label: 'PNG'),
      BranchedMenuItem(id: 'svg', label: 'SVG', badge: 'Beta'),
    ],
  ),
];

const String _sectionsCode = '''const [
  BranchedMenuSection(
    title: 'Getting started',
    items: [
      BranchedMenuItem(id: 'intro', label: 'Introduction'),
      BranchedMenuItem(id: 'install', label: 'Installation'),
    ],
  ),
  BranchedMenuSection(
    title: 'Components',
    items: [
      BranchedMenuItem(id: 'button', label: 'Button', badge: 'New'),
      BranchedMenuItem(id: 'dialog', label: 'Dialog'),
    ],
  ),
]''';

class _BranchedMenuDemo extends StatefulWidget {
  const _BranchedMenuDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_BranchedMenuDemo> createState() => _BranchedMenuDemoState();
}

class _BranchedMenuDemoState extends State<_BranchedMenuDemo> {
  String? _page = 'install';

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (String section, String label) = _locate(_page);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$section / $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BranchedMenu(
              sections: _sections,
              selectedId: _page,
              onSelected: (String id) => setState(() => _page = id),
              traceDuration: knobs.ms('traceDuration'),
              duration: knobs.ms('duration'),
              indent: knobs.number('indent'),
              itemHeight: knobs.number('itemHeight'),
              highlightColor: knobs.color('highlightColor'),
            ),
          ],
        ),
      ),
    );
  }

  static (String, String) _locate(String? id) {
    for (final BranchedMenuSection s in _sections) {
      for (final BranchedMenuItem i in s.items) {
        if (i.id == id) return (s.title, i.label);
      }
    }
    return ('Docs', 'Home');
  }
}

class _BranchedThumb extends StatefulWidget {
  const _BranchedThumb();

  @override
  State<_BranchedThumb> createState() => _BranchedThumbState();
}

class _BranchedThumbState extends State<_BranchedThumb> {
  static const List<String> _order = ['install', 'button', 'intro', 'dialog'];
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => setState(() => _tick++),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: BranchedMenu(
        sections: const [
          BranchedMenuSection(
            title: 'Getting started',
            items: [
              BranchedMenuItem(id: 'intro', label: 'Introduction'),
              BranchedMenuItem(id: 'install', label: 'Installation'),
            ],
          ),
          BranchedMenuSection(
            title: 'Components',
            items: [
              BranchedMenuItem(id: 'button', label: 'Button', badge: 'New'),
              BranchedMenuItem(id: 'dialog', label: 'Dialog'),
            ],
          ),
        ],
        selectedId: _order[_tick % _order.length],
        itemHeight: 30,
      ),
    );
  }
}
