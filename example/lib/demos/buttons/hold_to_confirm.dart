import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry holdToConfirmEntry = ComponentEntry(
  id: 'hold-to-confirm',
  name: 'Hold to Confirm',
  category: Categories.buttons,
  summary:
      'A button that fills while it is held and confirms only when the fill '
      'completes, a calm guard for destructive or important actions.',
  apis: const ['HoldToConfirm', 'HoldFillStyle', 'HoldToConfirmController'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    SelectKnob.enumeration(
      id: 'fillStyle',
      label: 'Fill style',
      values: HoldFillStyle.values,
      initial: HoldFillStyle.horizontal,
      typeName: 'HoldFillStyle',
    ),
    const SliderKnob.duration(
      id: 'holdDuration',
      label: 'Hold duration',
      min: 500,
      max: 3000,
      initial: 1500,
      divisions: 10,
    ),
    const ToggleKnob(
      id: 'destructive',
      label: 'Destructive colors',
      initial: true,
      help: 'Uses the error color for the fill and label.',
    ),
  ],
  preview: (context, knobs) => _HoldToConfirmDemo(knobs: knobs),
  thumbnail: (context) => const _HoldThumb(),
  code: (knobs) {
    final bool destructive = knobs.flag('destructive');
    final String call = dartCall('HoldToConfirm', {
      'fillStyle': knobs.arg('fillStyle'),
      'holdDuration': knobs.arg('holdDuration'),
      if (destructive) ...{
        'fillColor': 'scheme.error',
        'backgroundColor': 'scheme.errorContainer',
        'foregroundColor': 'scheme.onErrorContainer',
        'fillForegroundColor': 'scheme.onError',
      },
      'onConfirmed': destructive ? 'deleteProject' : 'archiveProject',
      'child': destructive
          ? "const Text('Hold to delete project')"
          : "const Text('Hold to archive project')",
    });
    if (!destructive) return call;
    return 'final scheme = Theme.of(context).colorScheme;\n\n$call';
  },
  notes: const [
    'Screen readers get a button whose tap confirms directly, and Enter or '
        'Space confirms when focused, so nobody has to press and hold.',
    'Releasing early drains the fill and nothing happens. A selection click '
        'plays when the hold starts and a heavy impact when it confirms.',
    'Under reduced motion the hold still takes holdDuration, since the '
        'delay is functional, but the liquid wave is static and draining '
        'jumps instantly.',
  ],
);

class _HoldToConfirmDemo extends StatelessWidget {
  const _HoldToConfirmDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool destructive = knobs.flag('destructive');
    final Color accent = destructive ? scheme.error : scheme.primary;
    final double seconds = knobs.number('holdDuration') / 1000;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: destructive
                      ? Icons.delete_outline_rounded
                      : Icons.inventory_2_outlined,
                  color: accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DemoCardText(
                    title: destructive ? 'Delete project' : 'Archive project',
                    body: destructive
                        ? 'Removes Northwind Studio with its 24 files and '
                              'all deployments. This cannot be undone.'
                        : 'Hides Northwind Studio from the dashboard. You '
                              'can restore it from settings.',
                  ),
                ),
              ],
            ),
            const Gap(20),
            HoldToConfirm(
              fillStyle: knobs.pick('fillStyle'),
              holdDuration: knobs.ms('holdDuration'),
              fillColor: destructive ? scheme.error : null,
              backgroundColor: destructive ? scheme.errorContainer : null,
              foregroundColor: destructive ? scheme.onErrorContainer : null,
              fillForegroundColor: destructive ? scheme.onError : null,
              confirmedChild: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(destructive ? 'Deleted' : 'Archived'),
                ],
              ),
              onConfirmed: () => demoToast(
                context,
                destructive ? 'Project deleted' : 'Project archived',
                type: ToastType.success,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    destructive
                        ? Icons.delete_outline_rounded
                        : Icons.inventory_2_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      destructive
                          ? 'Hold to delete project'
                          : 'Hold to archive project',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            DemoCaption(
              'Press and hold for ${seconds.toStringAsFixed(1)} s. '
              'Release early to cancel.',
            ),
          ],
        ),
      ),
    );
  }
}

/// A destructive hold button caught about two thirds of the way through.
class _HoldThumb extends StatelessWidget {
  const _HoldThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    const double width = 280;
    const double fill = 0.64;
    Widget label(Color color) => SizedBox(
      width: width,
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Hold to delete project',
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          ColoredBox(
            color: scheme.errorContainer,
            child: label(scheme.onErrorContainer),
          ),
          ClipRect(
            clipper: const _FractionClipper(fill),
            child: ColoredBox(
              color: scheme.error,
              child: label(scheme.onError),
            ),
          ),
        ],
      ),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
