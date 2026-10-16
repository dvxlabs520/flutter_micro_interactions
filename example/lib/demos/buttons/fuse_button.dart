import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry fuseButtonEntry = ComponentEntry(
  id: 'fuse-button',
  name: 'Fuse Button',
  category: Categories.buttons,
  summary:
      'An action button that turns into "Done, Undo" while a thin fuse burns '
      'down, and only commits the action when the fuse runs out. A calm '
      'alternative to a confirmation dialog.',
  apis: const ['FuseButton', 'FuseTrack'],
  tags: const [ComponentTag.newly],
  knobs: [
    SelectKnob.enumeration(
      id: 'track',
      label: 'Track',
      values: FuseTrack.values,
      initial: FuseTrack.border,
      typeName: 'FuseTrack',
    ),
    const SliderKnob.duration(
      id: 'undoWindow',
      label: 'Undo window',
      min: 2000,
      max: 10000,
      initial: 5000,
      divisions: 8,
    ),
    SelectKnob<String>(
      id: 'shape',
      label: 'Shape',
      options: const ['stadium', 'rounded'],
      initial: 'stadium',
      labelOf: (v) => v == 'stadium' ? 'Stadium' : 'Rounded',
      codeOf: (v) => 'BorderRadius.circular(8)',
    ),
    const ToggleKnob(
      id: 'pauseOnHover',
      label: 'Pause on hover',
      initial: true,
      help: 'The fuse stops while a mouse pointer rests on the button.',
    ),
    const ToggleKnob(
      id: 'resetAfterCommit',
      label: 'Reset after commit',
      initial: false,
    ),
  ],
  preview: (context, knobs) => _FuseButtonDemo(knobs: knobs),
  thumbnail: (context) => const _FuseThumb(),
  code: (knobs) => dartCall('FuseButton', {
    'track': knobs.arg('track'),
    'undoWindow': knobs.arg('undoWindow'),
    'borderRadius': knobs.arg('shape'),
    'pauseOnHover': knobs.arg('pauseOnHover'),
    'resetAfterCommit': knobs.arg('resetAfterCommit'),
    'onPressed': '() => setState(() => _archived = true)',
    'onUndo': '() => setState(() => _archived = false)',
    'onCommit': '() => mail.archive(thread)',
    'doneChild': "const Text('Archived')",
    'child': "const Text('Archive')",
  }),
  notes: const [
    'While the undo window is open the button is a live region, so screen '
        'readers announce the done state and the Undo option. Enter or Space '
        'activates it, and Escape also undoes during the window.',
    'onPressed runs at once for an optimistic update; onCommit runs only '
        'when the fuse burns out. If the widget is removed during the '
        'window, neither onCommit nor onUndo is called.',
    'Under reduced motion state changes are instant and the fuse is a thin '
        'static bar that shrinks, without the spark and glow.',
  ],
);

enum _Mail { inbox, pending, archived }

class _FuseButtonDemo extends StatefulWidget {
  const _FuseButtonDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_FuseButtonDemo> createState() => _FuseButtonDemoState();
}

class _FuseButtonDemoState extends State<_FuseButtonDemo> {
  _Mail _state = _Mail.inbox;
  int _round = 0;

  void _restart() => setState(() {
    _state = _Mail.inbox;
    _round++;
  });

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool reset = knobs.flag('resetAfterCommit');
    final bool gone = _state != _Mail.inbox;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: gone ? 0.4 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const DemoAvatar('JP', size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Jonas Park',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '09:12',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Venue options for the offsite',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'I shortlisted three places near the lake. The second '
                    'one has a big terrace and fits all of us.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FuseButton(
                  key: ValueKey(_round),
                  track: knobs.pick('track'),
                  undoWindow: knobs.ms('undoWindow'),
                  borderRadius: knobs.pick<String>('shape') == 'stadium'
                      ? null
                      : BorderRadius.circular(8),
                  pauseOnHover: knobs.flag('pauseOnHover'),
                  resetAfterCommit: reset,
                  onPressed: () => setState(() => _state = _Mail.pending),
                  onUndo: () => setState(() => _state = _Mail.inbox),
                  onCommit: () {
                    demoToast(context, 'Moved to Archive');
                    setState(
                      () => _state = reset ? _Mail.inbox : _Mail.archived,
                    );
                  },
                  doneChild: const Text('Archived'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.archive_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Archive'),
                    ],
                  ),
                ),
                if (_state == _Mail.archived)
                  TextButton(
                    onPressed: _restart,
                    child: const Text('Reset demo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FuseThumb extends StatelessWidget {
  const _FuseThumb();

  @override
  Widget build(BuildContext context) {
    // A drawn "done" state, since the real fuse starts only on press.
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(seconds: 5),
      builder: (context, t, _) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Archived', style: theme.textTheme.labelLarge),
                const SizedBox(width: 14),
                Icon(Icons.undo_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Undo',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
