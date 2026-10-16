import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry tapFeedbackEntry = ComponentEntry(
  id: 'tap-feedback',
  name: 'Tap Feedback',
  category: Categories.buttons,
  summary:
      'Wraps any widget with a short press animation, so custom cards and '
      'tiles feel as responsive as built in buttons.',
  apis: const ['TapFeedback', 'TapAnimationType'],
  knobs: [
    SelectKnob.enumeration(
      id: 'effect',
      label: 'Effect',
      values: TapAnimationType.values,
      initial: TapAnimationType.scale,
      typeName: 'TapAnimationType',
    ),
    const SliderKnob(
      id: 'scaleDown',
      label: 'Scale down',
      min: 0.8,
      max: 1,
      initial: 0.95,
      divisions: 20,
      help: 'Used by the scale, bounce and scale and fade effects.',
    ),
    const SliderKnob(
      id: 'opacity',
      label: 'Pressed opacity',
      min: 0.3,
      max: 1,
      initial: 0.8,
      divisions: 14,
      help: 'Used by the fade and scale and fade effects.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 50,
      max: 600,
      initial: 150,
      divisions: 11,
    ),
  ],
  preview: (context, knobs) => _TapFeedbackDemo(knobs: knobs),
  thumbnail: (context) => const _TapFeedbackThumb(),
  code: (knobs) => dartCall('TapFeedback', {
    'effect': knobs.arg('effect'),
    'scaleDown': knobs.arg('scaleDown'),
    'opacity': knobs.arg('opacity'),
    'duration': knobs.arg('duration'),
    'onTap': '() => openConversation(thread)',
    'child': 'ConversationTile(thread: thread)',
  }),
  notes: const [
    'The wrapper is exposed to screen readers as a button and can be '
        'activated with Enter or Space when focused.',
    'onTap fires on tap up and never waits for the animation. A light '
        'haptic plays on press unless enableHaptics is false.',
    'Under reduced motion no animation plays, but taps, haptics and '
        'callbacks still work.',
  ],
);

class _TapFeedbackDemo extends StatelessWidget {
  const _TapFeedbackDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget pressable({required String message, required Widget child}) {
      return TapFeedback(
        effect: knobs.pick('effect'),
        scaleDown: knobs.number('scaleDown'),
        opacity: knobs.number('opacity'),
        duration: knobs.ms('duration'),
        onTap: () => demoToast(context, message),
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (int i, _Action action) in _actions.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: pressable(
                    message: action.message,
                    child: _ActionTile(action: action),
                  ),
                ),
              ],
            ],
          ),
          const Gap(16),
          Text(
            'Recent',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(8),
          for (final (int i, _Thread thread) in _threads.indexed) ...[
            if (i > 0) const Gap(8),
            pressable(
              message: 'Opened chat with ${thread.name}',
              child: _ThreadCard(thread: thread, accent: demoAccents[i]),
            ),
          ],
          const Gap(16),
          const DemoCaption('Press and hold any tile or card'),
        ],
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.message);

  final String label;
  final IconData icon;
  final String message;
}

const List<_Action> _actions = [
  _Action('Send', Icons.north_east_rounded, 'Send money'),
  _Action('Request', Icons.south_west_rounded, 'Request money'),
  _Action('Top up', Icons.add_rounded, 'Top up balance'),
];

class _Thread {
  const _Thread(this.name, this.message, this.time);

  final String name;
  final String message;
  final String time;
}

const List<_Thread> _threads = [
  _Thread('Amelia Stone', 'Meeting moved to 3 PM, does that work?', '12:40'),
  _Thread('Diego Ramos', 'Sent you the invoice for March', '09:15'),
];

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DemoCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      radius: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: action.icon, size: 34),
          const Gap(8),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.accent});

  final _Thread thread;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DemoListRow(
        title: thread.name,
        subtitle: thread.message,
        color: accent,
        initials: thread.name
            .split(' ')
            .map((String part) => part.substring(0, 1))
            .join(),
        trailing: Text(
          thread.time,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Three action tiles; the middle one presses and releases in a loop.
class _TapFeedbackThumb extends StatefulWidget {
  const _TapFeedbackThumb();

  @override
  State<_TapFeedbackThumb> createState() => _TapFeedbackThumbState();
}

class _TapFeedbackThumbState extends State<_TapFeedbackThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 40),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.9,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 12,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(0.9), weight: 16),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.9,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 12),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Row(
        children: [
          for (final (int i, _Action action) in _actions.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: i == 1
                  ? ScaleTransition(
                      scale: _scale,
                      child: _ActionTile(action: action),
                    )
                  : _ActionTile(action: action),
            ),
          ],
        ],
      ),
    );
  }
}
