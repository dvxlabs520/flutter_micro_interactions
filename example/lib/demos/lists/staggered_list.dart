import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry staggeredListEntry = ComponentEntry(
  id: 'staggered-list',
  name: 'Staggered List',
  category: Categories.lists,
  summary:
      'List items that fade and slide in one after another when a screen '
      'opens. Use StaggeredItem to stagger any column.',
  apis: const ['StaggeredList', 'StaggeredItem', 'StaggerEffect'],
  knobs: [
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: StaggerEffect.values,
      initial: StaggerEffect.fadeSlideUp,
      typeName: 'StaggerEffect',
    ),
    const SliderKnob.duration(
      id: 'staggerDelay',
      label: 'Stagger',
      min: 20,
      max: 200,
      initial: 60,
      divisions: 18,
      help: 'Delay between consecutive items.',
    ),
    const SliderKnob.duration(
      id: 'itemDuration',
      label: 'Item duration',
      min: 200,
      max: 1000,
      initial: 400,
      divisions: 16,
    ),
    const SliderKnob(
      id: 'slideOffset',
      label: 'Slide offset',
      min: 0,
      max: 80,
      initial: 24,
      divisions: 16,
    ),
  ],
  preview: (context, knobs) => _StaggeredDemo(knobs: knobs),
  thumbnail: (context) => const _StaggerThumb(),
  code: (knobs) => dartCall('StaggeredList.builder', {
    'effect': knobs.arg('effect'),
    'staggerDelay': knobs.arg('staggerDelay'),
    'itemDuration': knobs.arg('itemDuration'),
    'slideOffset': knobs.arg('slideOffset'),
    'itemCount': 'contacts.length',
    'itemBuilder': '(context, i) => ContactTile(contacts[i])',
  }),
  notes: const [
    'The entrance is decorative and adds no semantics beyond the children '
        'own.',
    'Each entrance runs once per item, so rebuilds do not replay it. In a '
        'builder list, items that scroll into view later wait at most three '
        'stagger steps.',
    'Under reduced motion, or with enabled set to false, the items render '
        'in place at once.',
  ],
  replayable: true,
  stageHeight: 520,
  layout: StageLayout.fill,
);

const List<(String, String)> _contacts = [
  ('Alice Bennett', 'Product designer'),
  ('Bruno Carvalho', 'iOS engineer'),
  ('Chen Wei', 'Data scientist'),
  ('Daniela Rossi', 'Marketing lead'),
  ('Emeka Obi', 'Backend engineer'),
  ('Farah Khan', 'Support manager'),
  ('Gustav Lindqvist', 'Recruiter'),
  ('Hana Sato', 'Engineering manager'),
  ('Ines Duarte', 'Sales'),
  ('Jonas Weber', 'Finance'),
  ('Katya Petrova', 'QA engineer'),
  ('Liam Murphy', 'Android engineer'),
];

String _initials(String name) =>
    name.split(' ').map((part) => part[0]).take(2).join();

class _StaggeredDemo extends StatelessWidget {
  const _StaggeredDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final StaggerEffect effect = knobs.pick('effect');
    final Duration delay = knobs.ms('staggerDelay');
    final Duration itemDuration = knobs.ms('itemDuration');
    final double offset = knobs.number('slideOffset');
    return PhoneFrame(
      title: 'Contacts',
      trailing: Icon(
        Icons.person_add_alt_1_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      // A new key remounts the list, so every knob change replays the
      // entrance.
      child: StaggeredList.builder(
        key: ValueKey('$effect-$delay-$itemDuration-$offset'),
        effect: effect,
        staggerDelay: delay,
        itemDuration: itemDuration,
        slideOffset: offset,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _contacts.length,
        itemBuilder: (context, i) {
          final (String name, String role) = _contacts[i];
          return DemoListRow(
            title: name,
            subtitle: role,
            initials: _initials(name),
            color: demoAccents[i % demoAccents.length],
          );
        },
      ),
    );
  }
}

/// Rows that stagger in, then replay every few seconds.
class _StaggerThumb extends StatefulWidget {
  const _StaggerThumb();

  @override
  State<_StaggerThumb> createState() => _StaggerThumbState();
}

class _StaggerThumbState extends State<_StaggerThumb> {
  int _round = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      setState(() => _round++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 260,
      child: Column(
        key: ValueKey(_round),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            StaggeredItem(
              index: i,
              staggerDelay: const Duration(milliseconds: 120),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    DemoAvatar(
                      _initials(_contacts[i].$1),
                      size: 28,
                      color: demoAccents[i],
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 110,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Gap(6),
                          Container(
                            width: 70,
                            height: 6,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
