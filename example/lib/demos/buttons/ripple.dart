import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

enum _Variant { effect, button, water }

final ComponentEntry rippleEntry = ComponentEntry(
  id: 'ripple',
  name: 'Ripple',
  category: Categories.buttons,
  summary:
      'Expanding circles from the exact tap position on any surface, a ready '
      'made ripple button, and looping water waves for listening states.',
  apis: const [
    'RippleEffect',
    'RippleButton',
    'WaterRipple',
    'WaterRippleController',
  ],
  knobs: [
    SelectKnob<_Variant>(
      id: 'variant',
      label: 'Variant',
      options: _Variant.values,
      initial: _Variant.effect,
      labelOf: (_Variant v) => switch (v) {
        _Variant.effect => 'RippleEffect',
        _Variant.button => 'RippleButton',
        _Variant.water => 'WaterRipple',
      },
    ),
    const SliderKnob(
      id: 'rippleCount',
      label: 'Rings per tap',
      min: 1,
      max: 6,
      initial: 3,
      divisions: 5,
      codeOf: _intCode,
      help: 'RippleEffect only.',
    ),
    const SliderKnob(
      id: 'rippleRadius',
      label: 'Ripple radius',
      min: 40,
      max: 240,
      initial: 100,
      divisions: 20,
      help: 'RippleEffect only.',
    ),
    const SliderKnob(
      id: 'waveCount',
      label: 'Wave count',
      min: 1,
      max: 8,
      initial: 5,
      divisions: 7,
      codeOf: _intCode,
      help: 'WaterRipple only.',
    ),
    const ColorKnob(id: 'color', label: 'Ripple color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _RippleDemo(knobs: knobs),
  thumbnail: (context) => const _RippleThumb(),
  code: (knobs) {
    final _Variant variant = knobs.pick('variant');
    switch (variant) {
      case _Variant.effect:
        return dartCall('RippleEffect', {
          'rippleCount': knobs.arg('rippleCount'),
          'rippleRadius': knobs.arg('rippleRadius'),
          'rippleColor': _translucent(knobs),
          'borderRadius': 'BorderRadius.circular(16)',
          'onTap': 'openAlbum',
          'child': 'const AlbumCover()',
        });
      case _Variant.button:
        return dartCall('RippleButton', {
          'onTap': 'continueSetup',
          'rippleColor': _translucent(knobs),
          'borderRadius': 'BorderRadius.circular(12)',
          'child': "const Text('Continue')",
        });
      case _Variant.water:
        final String waves = dartCall('WaterRipple', {
          'controller': 'waves',
          'waveCount': knobs.arg('waveCount'),
          'rippleColor': knobs.arg('color'),
          'child': 'const SizedBox.square(dimension: 220)',
        });
        return 'final waves = WaterRippleController();\n\n'
            'Stack(\n'
            '  alignment: Alignment.center,\n'
            '  children: [\n'
            '    ${indent(waves, 4).trimLeft()},\n'
            '    MicButton(onPressed: toggleListening),\n'
            '  ],\n'
            ')\n\n'
            '// When recording starts and stops:\n'
            'waves.start();\n'
            'waves.stop();';
    }
  },
  notes: const [
    'RippleButton is announced as a button and can be activated with Enter '
        'or Space. RippleEffect adds no semantics of its own, so give the '
        'child a label when it acts as a button.',
    'WaterRipple waves are decorative paint and never appear in the '
        'semantics tree.',
    'Under reduced motion no tap ripples are painted, though onTap still '
        'fires, and WaterRipple renders static instead of looping.',
  ],
);

String _intCode(double v) => '${v.round()}';

/// Tap ripples are filled circles, so a custom color is passed translucent.
String? _translucent(Knobs knobs) {
  final String? color = knobs.arg('color');
  return color == null ? null : '$color.withValues(alpha: 0.4)';
}

class _RippleDemo extends StatelessWidget {
  const _RippleDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return switch (knobs.pick<_Variant>('variant')) {
      _Variant.effect => _AlbumDemo(knobs: knobs),
      _Variant.button => _OnboardingDemo(color: knobs.color('color')),
      _Variant.water => _VoiceDemo(knobs: knobs),
    };
  }
}

class _AlbumDemo extends StatelessWidget {
  const _AlbumDemo({required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RippleEffect(
            rippleCount: knobs.number('rippleCount').round(),
            rippleRadius: knobs.number('rippleRadius'),
            rippleColor: knobs.color('color')?.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            child: const _AlbumCover(),
          ),
          const Gap(14),
          Text('Low Tide Sessions', style: theme.textTheme.titleMedium),
          const Gap(2),
          Text(
            'Mara Okafor, 12 tracks',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(14),
          const DemoCaption('Tap anywhere on the cover, tap fast for more'),
        ],
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: GeneratedImage(style: SceneStyle.dunes, seed: 3),
              fit: BoxFit.cover,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black87,
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

class _OnboardingDemo extends StatelessWidget {
  const _OnboardingDemo({required this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DemoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoCardText(
              icon: Icons.notifications_active_outlined,
              title: 'Stay in the loop',
              body:
                  'Get a heads up when a teammate mentions you or a build '
                  'finishes. You can change this any time.',
            ),
            const Gap(20),
            RippleButton(
              onTap: () => demoToast(context, 'Notifications turned on'),
              rippleColor: color?.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Continue',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
            const Gap(8),
            RippleButton(
              onTap: () => demoToast(context, 'Skipped for now'),
              backgroundColor: scheme.surfaceContainerHighest,
              rippleColor: (color ?? scheme.primary).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Not now',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceDemo extends StatefulWidget {
  const _VoiceDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_VoiceDemo> createState() => _VoiceDemoState();
}

class _VoiceDemoState extends State<_VoiceDemo> {
  final WaterRippleController _waves = WaterRippleController();

  @override
  void dispose() {
    _waves.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_waves.isPlaying) {
      _waves.stop();
    } else {
      _waves.start();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool listening = _waves.isPlaying;
    final Color accent = widget.knobs.color('color') ?? scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Stopped waves paint nothing, so no fade is needed.
              WaterRipple(
                controller: _waves,
                autoPlay: false,
                waveCount: widget.knobs.number('waveCount').round(),
                rippleColor: widget.knobs.color('color'),
                child: const SizedBox.square(dimension: 220),
              ),
              Semantics(
                button: true,
                label: listening ? 'Stop listening' : 'Start listening',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: listening ? accent : scheme.surfaceContainer,
                      border: Border.all(
                        color: listening ? accent : scheme.outlineVariant,
                      ),
                    ),
                    child: Icon(
                      listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 32,
                      color: listening ? scheme.surface : accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          listening ? 'Listening...' : 'Tap the mic to dictate',
          style: theme.textTheme.titleSmall,
        ),
        const Gap(4),
        DemoCaption(
          listening
              ? 'Waves loop until the controller stops them'
              : 'Ask for a recap of today',
        ),
        const Gap(16),
        OutlinedButton.icon(
          onPressed: _toggle,
          icon: Icon(listening ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(listening ? 'Stop' : 'Start'),
        ),
      ],
    );
  }
}

/// A cover with frozen ripple rings, as if just tapped.
class _RippleThumb extends StatelessWidget {
  const _RippleThumb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Stack(
        children: [
          const _AlbumCover(height: 140),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(painter: _RingsPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.38, size.height * 0.48);
    for (final (double radius, double alpha) in const [
      (36.0, 0.42),
      (70.0, 0.28),
      (104.0, 0.16),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => false;
}
