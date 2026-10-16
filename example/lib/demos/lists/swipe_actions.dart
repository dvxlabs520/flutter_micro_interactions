import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry swipeActionsEntry = ComponentEntry(
  id: 'swipe-actions',
  name: 'Swipe Actions',
  category: Categories.lists,
  summary:
      'Drag a row sideways to reveal buttons behind it, like in mail apps. '
      'Ready made archive, favorite, share and delete actions.',
  apis: const ['SwipeActions', 'MicroSwipeAction'],
  tags: const [ComponentTag.gesture],
  knobs: [
    const SliderKnob(
      id: 'actionExtentRatio',
      label: 'Action extent ratio',
      min: 0.15,
      max: 0.5,
      initial: 0.25,
      divisions: 7,
      help: 'Fraction of the row width each action takes.',
    ),
    SelectKnob<int>(
      id: 'perSide',
      label: 'Actions per side',
      options: const [1, 2],
      initial: 2,
      labelOf: (v) => '$v',
    ),
    const ToggleKnob(
      id: 'fullSwipe',
      label: 'Full swipe performs first action',
      initial: false,
      help: 'Dragging past 60% of the row runs the first action on release.',
    ),
  ],
  preview: (context, knobs) => _SwipeDemo(knobs: knobs),
  thumbnail: (context) => const _SwipeThumb(),
  code: (knobs) {
    final bool two = knobs.pick<int>('perSide') == 2;
    return dartCall('SwipeActions', {
      'actionExtentRatio': knobs.arg('actionExtentRatio'),
      'performsFirstActionOnFullSwipe': knobs.arg('fullSwipe'),
      'leftActions': dartList([
        'MicroSwipeAction.archive(context, onPressed: () => archive(mail))',
        if (two)
          'MicroSwipeAction.favorite(context, onPressed: () => star(mail))',
      ]),
      'rightActions': dartList([
        'MicroSwipeAction.delete(context, onPressed: () => delete(mail))',
        if (two)
          'MicroSwipeAction.share(context, onPressed: () => share(mail))',
      ]),
      'child': 'MailTile(mail)',
    });
  },
  notes: const [
    'Every action with a callback is also exposed as a custom semantics '
        'action, so screen reader users can run it without the gesture.',
    'The row closes when an action runs, when you tap outside it, or when '
        'the list scrolls.',
    'Under reduced motion the reveal still works but snaps open and shut '
        'instead of springing.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

class _Mail {
  const _Mail(this.id, this.from, this.subject);

  final int id;
  final String from;
  final String subject;
}

const List<_Mail> _seed = [
  _Mail(1, 'Alice Bennett', 'Notes from the kickoff'),
  _Mail(2, 'Bruno Carvalho', 'TestFlight build 2.4 is ready'),
  _Mail(3, 'Chen Wei', 'Dataset for the Q4 forecast'),
  _Mail(4, 'Daniela Rossi', 'Launch checklist'),
  _Mail(5, 'Emeka Obi', 'API rate limits'),
  _Mail(6, 'Farah Khan', 'Customer feedback roundup'),
  _Mail(7, 'Gustav Lindqvist', 'Interview schedule'),
  _Mail(8, 'Hana Sato', 'Design review moved to 3 pm'),
];

class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo> {
  final List<_Mail> _mails = List.of(_seed);
  final Set<int> _starred = {3};

  void _remove(_Mail mail, String message) {
    setState(() => _mails.remove(mail));
    demoToast(context, message);
  }

  void _toggleStar(_Mail mail) {
    setState(() {
      if (!_starred.remove(mail.id)) _starred.add(mail.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool two = knobs.pick<int>('perSide') == 2;

    return PhoneFrame(
      title: 'Inbox',
      trailing: IconButton(
        tooltip: 'Restore messages',
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() {
          _mails
            ..clear()
            ..addAll(_seed);
        }),
        icon: const Icon(Icons.restart_alt, size: 20),
      ),
      child: _mails.isEmpty
          ? const Center(child: DemoCaption('Inbox zero'))
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: DemoCaption('Swipe a message left or right'),
                ),
                for (final _Mail mail in _mails)
                  DecoratedBox(
                    key: ValueKey(mail.id),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: SwipeActions(
                      actionExtentRatio: knobs.number('actionExtentRatio'),
                      performsFirstActionOnFullSwipe: knobs.flag('fullSwipe'),
                      leftActions: [
                        MicroSwipeAction.archive(
                          context,
                          onPressed: () => _remove(mail, 'Archived'),
                        ),
                        if (two)
                          MicroSwipeAction.favorite(
                            context,
                            onPressed: () => _toggleStar(mail),
                          ),
                      ],
                      rightActions: [
                        MicroSwipeAction.delete(
                          context,
                          onPressed: () => _remove(mail, 'Deleted'),
                        ),
                        if (two)
                          MicroSwipeAction.share(
                            context,
                            onPressed: () => demoToast(context, 'Link copied'),
                          ),
                      ],
                      child: DemoListRow(
                        title: mail.from,
                        subtitle: mail.subject,
                        color: demoAccents[mail.id % demoAccents.length],
                        background: scheme.surface,
                        trailing: _starred.contains(mail.id)
                            ? Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: scheme.tertiary,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A row caught half open, showing its actions.
class _SwipeThumb extends StatelessWidget {
  const _SwipeThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, Color bg, Color fg) {
      return Container(
        width: 64,
        color: bg,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const Gap(2),
            Text(label, style: TextStyle(color: fg, fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      width: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DemoListRow(
            title: _seed[0].from,
            subtitle: _seed[0].subject,
            color: demoAccents[1],
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          ClipRect(
            child: Stack(
              children: [
                Transform.translate(
                  offset: const Offset(-128, 0),
                  child: DemoListRow(
                    title: _seed[1].from,
                    subtitle: _seed[1].subject,
                    color: demoAccents[2],
                    background: scheme.surface,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      action(
                        Icons.share,
                        'Share',
                        scheme.primary,
                        scheme.onPrimary,
                      ),
                      action(
                        Icons.delete,
                        'Delete',
                        scheme.error,
                        scheme.onError,
                      ),
                    ],
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
