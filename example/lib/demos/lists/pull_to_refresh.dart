import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry pullToRefreshEntry = ComponentEntry(
  id: 'pull-to-refresh',
  name: 'Pull to Refresh',
  category: Categories.lists,
  summary:
      'Pull down on a list to load new content, with a Material or a '
      'platform adaptive spinner.',
  apis: const ['PullToRefresh'],
  tags: const [ComponentTag.gesture],
  knobs: [
    SelectKnob<bool>(
      id: 'adaptive',
      label: 'Variant',
      options: const [false, true],
      initial: false,
      labelOf: (v) => v ? 'Adaptive' : 'Material',
      help: 'Adaptive shows the Cupertino spinner on iOS and macOS.',
    ),
    const SliderKnob(
      id: 'displacement',
      label: 'Displacement',
      min: 20,
      max: 100,
      initial: 40,
      divisions: 16,
      help: 'How far from the top the spinner settles.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _PullDemo(knobs: knobs),
  thumbnail: (context) => const _PullThumb(),
  code: (knobs) => dartCall(
    knobs.flag('adaptive') ? 'PullToRefresh.adaptive' : 'PullToRefresh',
    {
      'displacement': knobs.arg('displacement'),
      'refreshIndicatorColor': knobs.arg('color'),
      'onRefresh': 'fetchNewMail',
      'child': dartCall('ListView.builder', {
        'itemCount': 'messages.length',
        'itemBuilder': '(context, i) => MessageTile(messages[i])',
      }),
    },
  ),
  notes: const [
    'A thin wrapper around RefreshIndicator, so it keeps its semantics: '
        'the indicator is announced with the localized refresh label unless '
        'semanticsLabel is set.',
    'The spinner stays visible until the Future returned by onRefresh '
        'completes.',
    'The child must be scrollable even when its content is short; use '
        'AlwaysScrollableScrollPhysics for short lists.',
  ],
  stageHeight: 520,
  layout: StageLayout.fill,
);

class _Mail {
  const _Mail(this.from, this.subject, this.time);

  final String from;
  final String subject;
  final String time;
}

const List<_Mail> _incoming = [
  _Mail('Hana Sato', 'Design review moved to 3 pm', 'Now'),
  _Mail('Stripe', 'Your payout is on the way', 'Now'),
  _Mail('Chen Wei', 'Dataset for the Q4 forecast', 'Now'),
  _Mail('GitHub', 'New comment on pull request 482', 'Now'),
];

const List<_Mail> _initial = [
  _Mail('Alice Bennett', 'Notes from the kickoff', '9:41'),
  _Mail('Bruno Carvalho', 'TestFlight build 2.4 is ready', '9:12'),
  _Mail('Linear', 'Weekly summary for Mobile', '8:30'),
  _Mail('Daniela Rossi', 'Launch checklist', 'Tue'),
  _Mail('Emeka Obi', 'API rate limits', 'Tue'),
  _Mail('Farah Khan', 'Customer feedback roundup', 'Mon'),
  _Mail('Gustav Lindqvist', 'Interview schedule', 'Mon'),
  _Mail('Figma', 'Maya invited you to Onboarding', 'Sun'),
];

class _PullDemo extends StatefulWidget {
  const _PullDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PullDemo> createState() => _PullDemoState();
}

class _PullDemoState extends State<_PullDemo> {
  final List<_Mail> _mails = List.of(_initial);
  int _fresh = 0;
  int _next = 0;

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _mails.insert(0, _incoming[_next % _incoming.length]);
      _next++;
      _fresh = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;

    final Widget list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _mails.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.south_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const Gap(6),
                const DemoCaption('Pull down to check for new mail'),
              ],
            ),
          );
        }
        final int index = i - 1;
        final _Mail mail = _mails[index];
        final bool fresh = index < _fresh;
        return DemoListRow(
          title: mail.from,
          subtitle: mail.subject,
          color: demoAccents[mail.from.length % demoAccents.length],
          background: fresh ? scheme.primary.withValues(alpha: 0.08) : null,
          trailing: Text(
            mail.time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fresh ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );

    final double displacement = knobs.number('displacement');
    final Color? color = knobs.color('color');
    final Widget refresh = knobs.flag('adaptive')
        ? PullToRefresh.adaptive(
            onRefresh: _refresh,
            displacement: displacement,
            refreshIndicatorColor: color,
            child: list,
          )
        : PullToRefresh(
            onRefresh: _refresh,
            displacement: displacement,
            refreshIndicatorColor: color,
            child: list,
          );

    return PhoneFrame(
      title: 'Inbox',
      trailing: Text(
        '${_mails.length} messages',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      // Lets a mouse drag the list on desktop, like a finger.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: refresh,
      ),
    );
  }
}

class _PullThumb extends StatelessWidget {
  const _PullThumb();

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
          const Gap(12),
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              value: 0.7,
              strokeWidth: 2.5,
              color: scheme.primary,
            ),
          ),
          const Gap(8),
          for (int i = 0; i < 2; i++)
            DemoListRow(
              title: _initial[i].from,
              subtitle: _initial[i].subject,
              color: demoAccents[i],
            ),
        ],
      ),
    );
  }
}
