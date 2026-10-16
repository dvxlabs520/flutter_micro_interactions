import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry reorderableListEntry = ComponentEntry(
  id: 'reorderable-list',
  name: 'Reorderable List',
  category: Categories.lists,
  summary:
      'Drag items to put them in order. The dragged item lifts with a '
      'subtle scale and shadow.',
  apis: const ['MicroReorderableList'],
  tags: const [ComponentTag.gesture],
  knobs: [
    const ToggleKnob(
      id: 'showDragHandle',
      label: 'Show drag handle',
      initial: false,
      help: 'Only the handle starts a drag. Otherwise long press the item.',
    ),
    const SliderKnob(
      id: 'liftScale',
      label: 'Lift scale',
      min: 1,
      max: 1.12,
      initial: 1.04,
      divisions: 12,
    ),
    const SliderKnob(
      id: 'liftElevation',
      label: 'Lift elevation',
      min: 0,
      max: 16,
      initial: 4,
      divisions: 16,
    ),
  ],
  preview: (context, knobs) => _ReorderDemo(knobs: knobs),
  thumbnail: (context) => const _ReorderThumb(),
  code: (knobs) => dartCall('MicroReorderableList', {
    'showDragHandle': knobs.arg('showDragHandle'),
    'liftScale': knobs.arg('liftScale'),
    'liftElevation': knobs.arg('liftElevation'),
    'onReorderItem':
        '(oldIndex, newIndex) {\n'
        '  setState(() => tasks.insert(newIndex, tasks.removeAt(oldIndex)));\n'
        '}',
    'children':
        '[\n'
        '  for (final task in tasks)\n'
        '    TaskTile(key: ValueKey(task.id), task: task),\n'
        ']',
  }),
  notes: const [
    'Built on ReorderableListView, so items keep its move up and move down '
        'semantics actions. The drag handle is labelled "Drag to reorder".',
    'onReorderItem gets indexes already adjusted for the removed item, so '
        'insert(newIndex, removeAt(oldIndex)) just works.',
    'Every child needs a key. Under reduced motion the lifted item keeps '
        'its shadow but does not animate its scale.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

class _Task {
  const _Task(this.id, this.title, this.project, this.time);

  final int id;
  final String title;
  final String project;
  final String time;
}

const List<_Task> _seed = [
  _Task(1, 'Review pull request 482', 'Mobile', '9:30'),
  _Task(2, 'Write release notes', 'Launch', '10:00'),
  _Task(3, 'Fix login redirect', 'Web', '11:15'),
  _Task(4, 'Plan next sprint', 'Team', '13:00'),
  _Task(5, 'Update onboarding copy', 'Growth', '14:30'),
  _Task(6, 'Prepare demo for Friday', 'Launch', '16:00'),
  _Task(7, 'Reply to design feedback', 'Design', '17:00'),
];

class _ReorderDemo extends StatefulWidget {
  const _ReorderDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_ReorderDemo> createState() => _ReorderDemoState();
}

class _ReorderDemoState extends State<_ReorderDemo> {
  final List<_Task> _tasks = List.of(_seed);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Knobs knobs = widget.knobs;
    return PhoneFrame(
      title: 'Today',
      trailing: Text(
        '${_tasks.length} tasks',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: MicroReorderableList(
        showDragHandle: knobs.flag('showDragHandle'),
        liftScale: knobs.number('liftScale'),
        liftElevation: knobs.number('liftElevation'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        onReorderItem: (oldIndex, newIndex) {
          setState(() => _tasks.insert(newIndex, _tasks.removeAt(oldIndex)));
        },
        children: [
          for (int i = 0; i < _tasks.length; i++)
            _TaskTile(key: ValueKey(_tasks[i].id), task: _tasks[i], rank: i),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({super.key, required this.task, required this.rank});

  final _Task task;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = demoAccents[task.id % demoAccents.length];
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: rank == 0 ? scheme.primary : accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const Gap(2),
                Text(
                  '${task.project}  ·  ${task.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (rank == 0) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Next',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One task lifted above the others.
class _ReorderThumb extends StatelessWidget {
  const _ReorderThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TaskTile(task: _seed[0], rank: 1),
          Transform.scale(
            scale: 1.05,
            child: Material(
              elevation: 8,
              color: Colors.transparent,
              shadowColor: scheme.shadow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary),
                ),
                child: _TaskTile(task: _seed[1], rank: 0),
              ),
            ),
          ),
          _TaskTile(task: _seed[2], rank: 2),
        ],
      ),
    );
  }
}
