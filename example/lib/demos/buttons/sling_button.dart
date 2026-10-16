import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry slingButtonEntry = ComponentEntry(
  id: 'sling-button',
  name: 'Sling Button',
  category: Categories.buttons,
  summary:
      'A round send button you pull back like a slingshot and release to '
      'fire. A plain tap still sends, so it works as a regular send button '
      'with a playful extra.',
  apis: const ['SlingButton'],
  tags: const [ComponentTag.newly, ComponentTag.gesture],
  knobs: [
    const SliderKnob(
      id: 'maxPull',
      label: 'Max pull',
      min: 40,
      max: 140,
      initial: 80,
      divisions: 10,
      help: 'Leave about this much free space around the button.',
    ),
    const SliderKnob(
      id: 'threshold',
      label: 'Threshold',
      min: 0.2,
      max: 1,
      initial: 0.5,
      divisions: 8,
      help: 'Fraction of the max pull needed to fire on release.',
    ),
    SelectKnob<String>(
      id: 'axis',
      label: 'Axis',
      options: const ['any', 'horizontal', 'vertical'],
      initial: 'any',
      labelOf: (v) => switch (v) {
        'horizontal' => 'Horizontal',
        'vertical' => 'Vertical',
        _ => 'Any',
      },
      codeOf: (v) => 'Axis.$v',
    ),
    const SliderKnob(
      id: 'size',
      label: 'Size',
      min: 44,
      max: 72,
      initial: 56,
      divisions: 7,
    ),
    const ToggleKnob(id: 'fireOnTap', label: 'Fire on tap', initial: true),
  ],
  preview: (context, knobs) => _SlingButtonDemo(knobs: knobs),
  thumbnail: (context) => const _SlingThumb(),
  code: (knobs) => dartCall('SlingButton', {
    'maxPull': knobs.arg('maxPull'),
    'threshold': knobs.arg('threshold'),
    'axis': knobs.arg('axis'),
    'size': knobs.arg('size'),
    'fireOnTap': knobs.arg('fireOnTap'),
    'onFired': '() => chat.send(_composer.text)',
    'child': 'const Icon(Icons.send_rounded)',
  }),
  notes: const [
    'A button labelled semanticLabel ("Send" by default), at least 48 by 48. '
        'Enter, Space or assistive activation fires it.',
    'The stretch and the flight paint outside the widget, so leave about '
        'maxPull of free space and avoid clipping ancestors. Inside a '
        'scrollable, constrain the pull with axis.',
    'Pulling plays ticks that grow with the tension and firing plays a heavy '
        'impact. Under reduced motion the button returns instantly with no '
        'flight.',
  ],
);

const List<String> _replies = [
  'On my way',
  'Sounds good, see you at 7',
  'Can you send the address?',
];

class _SlingButtonDemo extends StatefulWidget {
  const _SlingButtonDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_SlingButtonDemo> createState() => _SlingButtonDemoState();
}

class _SlingButtonDemoState extends State<_SlingButtonDemo> {
  final TextEditingController _composer = TextEditingController(
    text: _replies.first,
  );
  final List<(String, bool)> _messages = [
    ('Dinner at the corner place tonight?', false),
    ('Table is booked for 7', false),
  ];
  int _next = 1;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _composer.text.trim();
    setState(() {
      if (text.isNotEmpty) _messages.add((text, true));
      if (_messages.length > 4) _messages.removeAt(0);
      _composer.text = _replies[_next % _replies.length];
      _next++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double size = knobs.number('size');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DemoCard(
        showBorder: false,
        radius: 12,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (String text, bool mine) in _messages)
              Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? scheme.primary : scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mine ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _composer,
                      onSubmitted: (_) => _send(),
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Message',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SlingButton(
                  maxPull: knobs.number('maxPull'),
                  threshold: knobs.number('threshold'),
                  axis: switch (knobs.pick<String>('axis')) {
                    'horizontal' => Axis.horizontal,
                    'vertical' => Axis.vertical,
                    _ => null,
                  },
                  size: size,
                  fireOnTap: knobs.flag('fireOnTap'),
                  onFired: _send,
                  child: Icon(Icons.send_rounded, size: size * 0.4),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DemoCaption(
              'Pull the button back and let go, or just tap it',
            ),
          ],
        ),
      ),
    );
  }
}

class _SlingThumb extends StatelessWidget {
  const _SlingThumb();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('On my way', style: theme.textTheme.bodyMedium),
            ),
          ),
          const SizedBox(width: 10),
          SlingButton(
            onFired: () {},
            child: const Icon(Icons.send_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}
