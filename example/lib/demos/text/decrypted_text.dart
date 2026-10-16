import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

final ComponentEntry decryptedTextEntry = ComponentEntry(
  id: 'decrypted-text',
  name: 'Decrypted Text',
  category: Categories.text,
  summary:
      'Text that scrambles through random glyphs before resolving, like a '
      'message being decrypted. Plays on mount or on hover.',
  apis: const [
    'DecryptedText',
    'DecryptedTextController',
    'DecryptRevealDirection',
    'DecryptTrigger',
  ],
  tags: const [ComponentTag.newly],
  knobs: [
    const TextKnob(id: 'text', label: 'Text', initial: 'Access granted'),
    SelectKnob.enumeration(
      id: 'direction',
      label: 'Reveal from',
      values: DecryptRevealDirection.values,
      initial: DecryptRevealDirection.start,
      typeName: 'DecryptRevealDirection',
      help: 'Order in which characters resolve when sequential.',
    ),
    const ToggleKnob(
      id: 'sequential',
      label: 'Sequential',
      initial: false,
      help: 'Resolve one character per tick instead of all at once.',
    ),
    SelectKnob.enumeration(
      id: 'trigger',
      label: 'Trigger',
      values: DecryptTrigger.values,
      initial: DecryptTrigger.mount,
      typeName: 'DecryptTrigger',
    ),
    const SliderKnob.duration(
      id: 'interval',
      label: 'Tick',
      min: 20,
      max: 200,
      initial: 50,
      divisions: 18,
    ),
  ],
  preview: (context, knobs) => _DecryptDemo(knobs: knobs),
  thumbnail: (context) => const _DecryptThumb(),
  code: (knobs) => dartCall('DecryptedText', {
    'text': knobs.code('text'),
    'sequential': knobs.arg('sequential'),
    'revealDirection': knobs.arg('direction'),
    'animateOn': knobs.arg('trigger'),
    'interval': knobs.arg('interval'),
    'style': 'Theme.of(context).textTheme.titleLarge',
  }),
  notes: const [
    'The semantics label is always the final text (or semanticLabel), never '
        'the scrambled glyphs.',
    'The final text is laid out invisibly under the scramble, so the widget '
        'keeps its size while it runs. Whitespace never scrambles.',
    'The hover trigger needs a mouse; on touch screens use the mount '
        'trigger or a DecryptedTextController.',
    'Under reduced motion, or with enabled set to false, the final text is '
        'shown at once and no timers run.',
  ],
  replayable: true,
);

class _DecryptDemo extends StatelessWidget {
  const _DecryptDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final String signature = [
      for (final String id in const [
        'text',
        'direction',
        'sequential',
        'trigger',
        'interval',
      ])
        knobs.valueOf(id),
    ].join('|');
    return _VaultCard(key: ValueKey(signature), knobs: knobs);
  }
}

class _VaultCard extends StatefulWidget {
  const _VaultCard({super.key, required this.knobs});

  final Knobs knobs;

  @override
  State<_VaultCard> createState() => _VaultCardState();
}

class _VaultCardState extends State<_VaultCard> {
  final DecryptedTextController _controller = DecryptedTextController();
  late bool _unlocked =
      widget.knobs.pick<DecryptTrigger>('trigger') == DecryptTrigger.hover;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCompleted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _unlocked = true);
    });
  }

  void _again() {
    setState(() => _unlocked = false);
    _controller
      ..reset()
      ..play();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Knobs knobs = widget.knobs;
    final bool hover =
        knobs.pick<DecryptTrigger>('trigger') == DecryptTrigger.hover;
    final String text = knobs.text('text');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: DemoCard(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: _unlocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      color: _unlocked ? scheme.tertiary : scheme.primary,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        'Team vault',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      _unlocked ? 'Unlocked' : 'Verifying',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Gap(20),
                DecryptedText(
                  text: text.isEmpty ? ' ' : text,
                  controller: _controller,
                  sequential: knobs.flag('sequential'),
                  revealDirection: knobs.pick('direction'),
                  animateOn: knobs.pick('trigger'),
                  interval: knobs.ms('interval'),
                  onCompleted: _onCompleted,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  encryptedStyle: TextStyle(
                    color: scheme.primary.withValues(alpha: 0.7),
                  ),
                ),
                const Gap(6),
                Text(
                  hover
                      ? 'Hover the line above with a mouse'
                      : 'Signed in with a hardware key',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        TextButton.icon(
          onPressed: _again,
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Decrypt again'),
        ),
      ],
    );
  }
}

class _DecryptThumb extends StatefulWidget {
  const _DecryptThumb();

  @override
  State<_DecryptThumb> createState() => _DecryptThumbState();
}

class _DecryptThumbState extends State<_DecryptThumb> {
  final DecryptedTextController _controller = DecryptedTextController();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      _controller
        ..reset()
        ..play();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecryptedText(
      text: 'Access granted',
      controller: _controller,
      sequential: true,
      revealDirection: DecryptRevealDirection.center,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      encryptedStyle: TextStyle(color: theme.colorScheme.primary),
    );
  }
}
