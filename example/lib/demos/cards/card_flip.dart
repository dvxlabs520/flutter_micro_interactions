import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

String _perspective(double v) {
  if (v == 0) return '0.0';
  return v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
}

final ComponentEntry cardFlipEntry = ComponentEntry(
  id: 'card-flip',
  name: 'Card Flip',
  category: Categories.cards,
  summary:
      'A card with a front and a back joined by a 3D flip. Use it for '
      'flashcards, quiz answers or the back of a payment card.',
  apis: const ['CardFlip', 'CardFlipController'],
  knobs: [
    SelectKnob.enumeration(
      id: 'direction',
      label: 'Direction',
      values: Axis.values,
      initial: Axis.horizontal,
      typeName: 'Axis',
      help: 'Horizontal turns left to right, vertical top to bottom.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 1500,
      initial: 500,
      divisions: 13,
    ),
    const SliderKnob(
      id: 'perspective',
      label: 'Perspective',
      min: 0,
      max: 0.004,
      initial: 0.001,
      divisions: 8,
      format: _perspective,
      codeOf: _perspective,
      help: 'Depth of the 3D effect during the flip.',
    ),
    const ToggleKnob(id: 'flipOnTap', label: 'Flip on tap', initial: true),
  ],
  preview: (context, knobs) => _CardFlipDemo(knobs: knobs),
  thumbnail: (context) => const _CardFlipThumb(),
  code: (knobs) {
    final String card = dartCall('CardFlip', {
      'controller': 'controller',
      'direction': knobs.arg('direction'),
      'duration': knobs.arg('duration'),
      'perspective': knobs.arg('perspective'),
      'flipOnTap': knobs.arg('flipOnTap'),
      'front': "const Flashcard(text: 'la mariposa')",
      'back': "const Flashcard(text: 'the butterfly')",
    });
    return 'final controller = CardFlipController();\n\n'
        '$card\n\n'
        '// Flip from a button, or call showFront() and showBack().\n'
        'controller.flip();';
  },
  notes: const [
    'The hidden face is excluded from semantics and pointer events, and the '
        'card announces whether the front or the back is showing.',
    'Rapid taps stay in sync because the visible face is derived from the '
        'animation status. Pass isFlipped to control the face from a parent.',
    'Under reduced motion the faces swap instantly without rotation.',
  ],
);

class _CardFlipDemo extends StatefulWidget {
  const _CardFlipDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_CardFlipDemo> createState() => _CardFlipDemoState();
}

class _CardFlipDemoState extends State<_CardFlipDemo> {
  final CardFlipController _controller = CardFlipController();
  bool _back = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CardFlip(
              controller: _controller,
              direction: knobs.pick('direction'),
              duration: knobs.ms('duration'),
              perspective: knobs.number('perspective'),
              flipOnTap: knobs.flag('flipOnTap'),
              onFlip: (back) => setState(() => _back = back),
              front: const _Flashcard(back: false),
              back: const _Flashcard(back: true),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _controller.flip,
                icon: const Icon(Icons.flip_rounded, size: 18),
                label: const Text('Flip'),
              ),
              DemoCaption(
                _back
                    ? 'Showing the answer'
                    : knobs.flag('flipOnTap')
                    ? 'Tap the card to reveal'
                    : 'Use the Flip button',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Flashcard extends StatelessWidget {
  const _Flashcard({required this.back});

  final bool back;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = back ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.16),
              scheme.surfaceContainer,
            ),
            scheme.surfaceContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  back ? 'ENGLISH' : 'SPANISH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '3 / 20',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            back ? 'the butterfly' : 'la mariposa',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            back ? 'La mariposa vuela sobre las flores.' : 'noun, feminine',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flips a small flashcard every two seconds.
class _CardFlipThumb extends StatefulWidget {
  const _CardFlipThumb();

  @override
  State<_CardFlipThumb> createState() => _CardFlipThumbState();
}

class _CardFlipThumbState extends State<_CardFlipThumb> {
  final CardFlipController _controller = CardFlipController();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _controller.flip(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 160,
      child: CardFlip(
        controller: _controller,
        flipOnTap: false,
        front: const _Flashcard(back: false),
        back: const _Flashcard(back: true),
      ),
    );
  }
}
