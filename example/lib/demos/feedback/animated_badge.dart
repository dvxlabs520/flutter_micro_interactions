import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry animatedBadgeEntry = ComponentEntry(
  id: 'animated-badge',
  name: 'Animated Badge',
  category: Categories.feedback,
  summary:
      'A count badge on the corner of an icon that pops in, bounces when '
      'the count changes and scales out at zero. For carts and inboxes.',
  apis: const ['AnimatedBadge'],
  knobs: [
    SelectKnob<int?>(
      id: 'maxCount',
      label: 'Max count',
      options: const [null, 9, 99],
      initial: null,
      labelOf: (v) => v == null ? 'None' : '$v+',
      codeOf: (v) => '$v',
      help: 'Counts above it render as 9+ or 99+.',
    ),
    const SliderKnob(
      id: 'badgeSize',
      label: 'Badge size',
      min: 14,
      max: 26,
      initial: 18,
      divisions: 12,
    ),
    const ToggleKnob(
      id: 'showZero',
      label: 'Show zero',
      initial: false,
      help: 'Keep the badge visible with 0 instead of hiding it.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _BadgeDemo(knobs: knobs),
  thumbnail: (context) => const _BadgeThumb(),
  code: (knobs) => dartCall('AnimatedBadge', {
    'count': 'cartCount',
    'maxCount': knobs.arg('maxCount'),
    'badgeSize': knobs.arg('badgeSize'),
    'showZero': knobs.arg('showZero'),
    'badgeColor': knobs.arg('color'),
    'semanticLabel': r"'$cartCount items in cart'",
    'child': 'const Icon(Icons.shopping_bag_outlined)',
  }),
  notes: const [
    'The badge is merged with its child and reports semanticLabel, which '
        "defaults to '<count> items'.",
    'Set announceChanges to have count changes announced politely to '
        'assistive technology. It is off by default to avoid noise.',
    'Under reduced motion, or with enabled set to false, the badge appears, '
        'disappears and updates instantly.',
  ],
);

class _BadgeDemo extends StatefulWidget {
  const _BadgeDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_BadgeDemo> createState() => _BadgeDemoState();
}

class _BadgeDemoState extends State<_BadgeDemo> {
  int _cart = 2;
  int _inbox = 8;

  Widget _badge(int count, IconData icon, String label) {
    final Knobs knobs = widget.knobs;
    final Color? color = knobs.color('color');
    return AnimatedBadge(
      count: count,
      maxCount: knobs.pick('maxCount'),
      badgeSize: knobs.number('badgeSize'),
      showZero: knobs.flag('showZero'),
      badgeColor: color,
      textColor: color == null
          ? null
          : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : const Color(0xFF0B0D12),
      semanticLabel: '$count $label',
      child: Icon(icon, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DemoCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 22, 18),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.storefront_outlined, size: 32),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      'Northwind',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _badge(_inbox, Icons.mail_outline, 'unread messages'),
                  const Gap(24),
                  _badge(_cart, Icons.shopping_bag_outlined, 'items in cart'),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            _ControlRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Cart',
              children: [
                IconButton.outlined(
                  tooltip: 'Remove item',
                  onPressed: _cart == 0 ? null : () => setState(() => _cart--),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const Gap(8),
                IconButton.filledTonal(
                  tooltip: 'Add item',
                  onPressed: () => setState(() => _cart++),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            _ControlRow(
              icon: Icons.mail_outline,
              label: 'Inbox',
              children: [
                IconButton.outlined(
                  tooltip: 'Mark all as read',
                  onPressed: _inbox == 0
                      ? null
                      : () => setState(() => _inbox = 0),
                  icon: const Icon(Icons.done_all, size: 18),
                ),
                const Gap(8),
                IconButton.filledTonal(
                  tooltip: 'New message',
                  onPressed: () => setState(() => _inbox++),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.label,
    required this.children,
  });

  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const Gap(10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          ...children,
        ],
      ),
    );
  }
}

/// A cart whose badge ticks up on its own.
class _BadgeThumb extends StatefulWidget {
  const _BadgeThumb();

  @override
  State<_BadgeThumb> createState() => _BadgeThumbState();
}

class _BadgeThumbState extends State<_BadgeThumb> {
  int _count = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      setState(() => _count = _count % 5 + 1);
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
      width: 200,
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBadge(
            count: 3,
            badgeSize: 22,
            child: Icon(
              Icons.mail_outline,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Gap(36),
          AnimatedBadge(
            count: _count,
            badgeSize: 22,
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 44,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
