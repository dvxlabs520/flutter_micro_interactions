import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry warmTooltipEntry = ComponentEntry(
  id: 'warm-tooltip',
  name: 'Warm Tooltip',
  category: Categories.backgrounds,
  summary:
      'Tooltips that wait before the first one appears, then open instantly '
      'for neighbours while one shared bubble glides between them. Made for '
      'toolbars of icon buttons.',
  apis: const ['WarmTooltip', 'WarmTooltipGroup'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    const ToggleKnob(
      id: 'grouped',
      label: 'Grouped',
      initial: true,
      help: 'Off gives every button its own bubble and its own delay.',
    ),
    const SliderKnob.duration(
      id: 'warmDelay',
      label: 'Warm delay',
      min: 0,
      max: 1200,
      initial: 500,
      divisions: 12,
      help: 'Rest time before the first tooltip of a cold group.',
    ),
    const SliderKnob.duration(
      id: 'cooldown',
      label: 'Cooldown',
      min: 0,
      max: 1500,
      initial: 300,
      divisions: 15,
      help: 'How long the group stays warm after the last tooltip.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Glide duration',
      min: 80,
      max: 600,
      initial: 240,
      divisions: 13,
    ),
    const ToggleKnob(id: 'preferBelow', label: 'Prefer below', initial: false),
  ],
  preview: (context, knobs) => _WarmTooltipDemo(knobs: knobs),
  thumbnail: (context) => const _WarmThumb(),
  code: (knobs) {
    final bool grouped = knobs.flag('grouped');
    String tip(String message, String icon, String action) =>
        dartCall('WarmTooltip', {
          'message': "'$message'",
          'preferBelow': knobs.arg('preferBelow'),
          if (!grouped) 'waitDuration': knobs.arg('warmDelay'),
          'child':
              'IconButton(icon: const Icon(Icons.$icon), '
              'onPressed: $action)',
        });
    final String row = dartCall('Row', {
      'mainAxisSize': 'MainAxisSize.min',
      'children': dartList([
        tip('Bold', 'format_bold', '_bold'),
        tip('Italic', 'format_italic', '_italic'),
        tip('Insert link', 'link', '_link'),
      ], type: 'Widget'),
    });
    if (!grouped) return row;
    return dartCall('WarmTooltipGroup', {
      'warmDelay': knobs.arg('warmDelay'),
      'cooldown': knobs.arg('cooldown'),
      'duration': knobs.arg('duration'),
      'child': row,
    });
  },
  notes: const [
    'The child receives the message as its semantics tooltip; the bubble '
        'itself is decorative. Escape hides a visible tooltip.',
    'With a mouse the tooltip appears after the delay and hides on exit. On '
        'touch a long press shows it at once and it hides shortly after the '
        'finger lifts.',
    'Under reduced motion the bubble appears and moves without fade or '
        'glide. The delays still apply, because they are about intent.',
  ],
);

class _Tool {
  const _Tool(this.icon, this.message);

  final IconData icon;
  final String message;
}

const List<List<_Tool>> _toolGroups = [
  [
    _Tool(Icons.format_bold_rounded, 'Bold'),
    _Tool(Icons.format_italic_rounded, 'Italic'),
    _Tool(Icons.format_underlined_rounded, 'Underline'),
  ],
  [
    _Tool(Icons.format_list_bulleted_rounded, 'Bulleted list'),
    _Tool(Icons.format_quote_rounded, 'Quote'),
    _Tool(Icons.link_rounded, 'Insert link'),
  ],
];

class _WarmTooltipDemo extends StatefulWidget {
  const _WarmTooltipDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_WarmTooltipDemo> createState() => _WarmTooltipDemoState();
}

class _WarmTooltipDemoState extends State<_WarmTooltipDemo> {
  final Set<String> _active = {};

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool grouped = knobs.flag('grouped');
    final bool below = knobs.flag('preferBelow');

    Widget button(_Tool tool) {
      final bool on = _active.contains(tool.message);
      return WarmTooltip(
        message: tool.message,
        preferBelow: below,
        waitDuration: knobs.ms('warmDelay'),
        child: IconButton(
          icon: Icon(tool.icon, size: 20),
          isSelected: on,
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            backgroundColor: on ? scheme.surfaceContainerHighest : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            minimumSize: const Size(36, 36),
            fixedSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => setState(() {
            if (!_active.remove(tool.message)) _active.add(tool.message);
          }),
        ),
      );
    }

    Widget toolbar = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (int g, List<_Tool> tools) in _toolGroups.indexed) ...[
            if (g > 0)
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: scheme.surfaceContainerHighest,
              ),
            for (final _Tool t in tools) button(t),
          ],
        ],
      ),
    );
    if (grouped) {
      toolbar = WarmTooltipGroup(
        warmDelay: knobs.ms('warmDelay'),
        cooldown: knobs.ms('cooldown'),
        duration: knobs.ms('duration'),
        child: toolbar,
      );
    }

    final TextStyle? body = theme.textTheme.bodyMedium;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            toolbar,
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Launch notes', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'The new editor ships on Monday. Hover the toolbar: the '
                    'first tooltip waits, the next ones follow at once.',
                    style: body?.copyWith(
                      fontWeight: _active.contains('Bold')
                          ? FontWeight.w600
                          : null,
                      fontStyle: _active.contains('Italic')
                          ? FontStyle.italic
                          : null,
                      decoration: _active.contains('Underline')
                          ? TextDecoration.underline
                          : null,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _WarmThumb extends StatefulWidget {
  const _WarmThumb();

  @override
  State<_WarmThumb> createState() => _WarmThumbState();
}

class _WarmThumbState extends State<_WarmThumb> {
  static const List<_Tool> _tools = [
    _Tool(Icons.format_bold_rounded, 'Bold'),
    _Tool(Icons.format_italic_rounded, 'Italic'),
    _Tool(Icons.format_underlined_rounded, 'Underline'),
    _Tool(Icons.link_rounded, 'Insert link'),
  ];
  static const double _slot = 40;

  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 900),
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
    // A drawn bubble, because real tooltips need a hovering pointer.
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int i = const [0, 1, 2, 3, 2, 1][_tick % 6];
    return SizedBox(
      width: _slot * _tools.length + 8,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: 4 + i * _slot + _slot / 2 - 50,
            width: 100,
            top: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    _tools[i].message,
                    key: ValueKey(i),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  for (final (int k, _Tool t) in _tools.indexed)
                    Container(
                      width: _slot,
                      height: 36,
                      decoration: BoxDecoration(
                        color: k == i ? scheme.surfaceContainerHighest : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        t.icon,
                        size: 20,
                        color: scheme.onSurfaceVariant,
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
