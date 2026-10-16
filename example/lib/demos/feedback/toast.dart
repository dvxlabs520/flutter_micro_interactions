import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry toastEntry = ComponentEntry(
  id: 'toast',
  name: 'Toast',
  category: Categories.feedback,
  summary:
      'Overlay toasts that stack, dismiss themselves and can be swiped '
      'away. Use them to confirm an action or report a problem without '
      'blocking the screen.',
  apis: const [
    'ToastNotification',
    'ToastContext',
    'ToastType',
    'ToastPosition',
  ],
  knobs: [
    SelectKnob.enumeration(
      id: 'position',
      label: 'Position',
      values: ToastPosition.values,
      initial: ToastPosition.top,
      typeName: 'ToastPosition',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 1000,
      max: 8000,
      initial: 3000,
      divisions: 14,
    ),
    const ToggleKnob(
      id: 'showProgress',
      label: 'Show progress',
      initial: false,
      help: 'A thin fuse that shrinks over the remaining time.',
    ),
    const ToggleKnob(
      id: 'action',
      label: 'Undo action',
      initial: false,
      help: 'Adds an Undo button that runs onAction and closes the toast.',
    ),
  ],
  preview: (context, knobs) => _ToastDemo(knobs: knobs),
  thumbnail: (context) => const _ToastThumb(),
  code: (knobs) {
    final bool action = knobs.flag('action');
    final String call = dartCall('context.showToast', {
      'message': quote('Profile saved'),
      'type': 'ToastType.success',
      'position': knobs.arg('position'),
      'duration': knobs.arg('duration'),
      'showProgress': knobs.arg('showProgress'),
      'actionLabel': action ? quote('Undo') : null,
      'onAction': action ? 'restoreProfile' : null,
    });
    return '$call;';
  },
  notes: const [
    'The message is announced to screen readers and the toast is a live '
        'region; the close button has a semantic label.',
    'With swipe to dismiss on (the default) the toast also exposes the '
        'dismiss semantics action, so it can be closed without the gesture.',
    'Hovering or pressing a toast pauses its countdown and the progress '
        'fuse.',
    'Under reduced motion toasts appear and disappear instantly and the '
        'fuse is hidden, while the countdown still runs.',
  ],
);

class _ToastSample {
  const _ToastSample(this.type, this.label, this.message, this.icon);

  final ToastType type;
  final String label;
  final String message;
  final IconData icon;
}

const List<_ToastSample> _samples = [
  _ToastSample(
    ToastType.success,
    'Success',
    'Profile saved',
    Icons.check_circle_outline,
  ),
  _ToastSample(
    ToastType.error,
    'Error',
    'Could not reach the server',
    Icons.error_outline,
  ),
  _ToastSample(
    ToastType.warning,
    'Warning',
    'Storage is almost full',
    Icons.warning_amber_rounded,
  ),
  _ToastSample(ToastType.info, 'Info', 'Message archived', Icons.info_outline),
];

Color _typeColor(ColorScheme scheme, ToastType type) => switch (type) {
  ToastType.success => demoAccents[3],
  ToastType.error => scheme.error,
  ToastType.warning => demoAccents[2],
  ToastType.info => scheme.primary,
};

class _ToastDemo extends StatelessWidget {
  const _ToastDemo({required this.knobs});

  final Knobs knobs;

  void _show(BuildContext context, _ToastSample sample) {
    final bool action = knobs.flag('action');
    context.showToast(
      message: sample.message,
      type: sample.type,
      position: knobs.pick('position'),
      duration: knobs.ms('duration'),
      showProgress: knobs.flag('showProgress'),
      actionLabel: action ? 'Undo' : null,
      onAction: action ? () => demoToast(context, 'Change undone') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a notification', style: theme.textTheme.titleMedium),
            const Gap(4),
            Text(
              'Each type has its own colors and icon.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            LayoutBuilder(
              builder: (context, constraints) {
                final double tileWidth = constraints.maxWidth >= 260
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final _ToastSample sample in _samples)
                      SizedBox(
                        width: tileWidth,
                        child: _TypeTile(
                          sample: sample,
                          onTap: () => _show(context, sample),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Gap(16),
            const Center(
              child: DemoCaption('Swipe a toast away, or hover it to pause'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.sample, required this.onTap});

  final _ToastSample sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color color = _typeColor(scheme, sample.type);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconBadge(icon: sample.icon, size: 32, color: color),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sample.label, style: theme.textTheme.titleSmall),
                    Text(
                      sample.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two static toasts, stacked like the real ones.
class _ToastThumb extends StatelessWidget {
  const _ToastThumb();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.92,
            child: Opacity(
              opacity: 0.7,
              child: _MiniToast(
                color: scheme.inverseSurface,
                foreground: scheme.onInverseSurface,
                icon: Icons.info_outline,
                message: 'Message archived',
                action: 'Undo',
              ),
            ),
          ),
          const Gap(8),
          _MiniToast(
            color: Colors.green.shade700,
            foreground: Colors.white,
            icon: Icons.check_circle_outline,
            message: 'Profile saved',
            fuse: 0.6,
          ),
        ],
      ),
    );
  }
}

class _MiniToast extends StatelessWidget {
  const _MiniToast({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.message,
    this.action,
    this.fuse,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String message;
  final String? action;
  final double? fuse;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(color: foreground, fontSize: 14);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 20),
                const Gap(12),
                Expanded(child: Text(message, style: style)),
                if (action != null)
                  Text(
                    action!,
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                const Gap(12),
                Icon(Icons.close, color: foreground, size: 18),
              ],
            ),
          ),
          if (fuse != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fuse,
                child: Container(
                  height: 3,
                  color: foreground.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
