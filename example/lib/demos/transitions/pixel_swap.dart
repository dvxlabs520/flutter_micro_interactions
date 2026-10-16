import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry pixelSwapEntry = ComponentEntry(
  id: 'pixel-swap',
  name: 'Pixel Swap',
  category: Categories.transitions,
  summary:
      'Swaps two children pixel by pixel: the second one builds in as a '
      'grid of cells that pop in a wave from where the pointer entered.',
  apis: const ['PixelSwap', 'PixelSwapController', 'PixelSwapTrigger'],
  tags: const [ComponentTag.newly, ComponentTag.pointer],
  knobs: [
    SelectKnob.enumeration(
      id: 'trigger',
      label: 'Trigger',
      values: PixelSwapTrigger.values,
      initial: PixelSwapTrigger.hover,
      typeName: 'PixelSwapTrigger',
      help: 'Hover falls back to tap on touch screens.',
    ),
    SliderKnob(
      id: 'gridSize',
      label: 'Grid size',
      min: 4,
      max: 30,
      initial: 14,
      divisions: 26,
      format: (v) => '${v.round()}',
      codeOf: (v) => '${v.round()}',
      help: 'Cells across the shorter side.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Wave duration',
      min: 200,
      max: 1600,
      initial: 700,
      divisions: 14,
    ),
    const SliderKnob.duration(
      id: 'cellDuration',
      label: 'Cell duration',
      min: 100,
      max: 800,
      initial: 320,
      divisions: 14,
    ),
    const SliderKnob(
      id: 'gap',
      label: 'Gap',
      min: 0,
      max: 4,
      initial: 0,
      divisions: 8,
      help: 'Seams between cells during the wave, for a mosaic look.',
    ),
  ],
  preview: (context, knobs) => _PixelSwapDemo(knobs: knobs),
  thumbnail: (context) => const _PixelSwapThumb(),
  code: (knobs) {
    final PixelSwapTrigger trigger = knobs.pick('trigger');
    final String widget = dartCall('PixelSwap', {
      'controller': trigger == PixelSwapTrigger.manual ? 'controller' : null,
      'trigger': knobs.arg('trigger'),
      'gridSize': knobs.arg('gridSize'),
      'duration': knobs.arg('duration'),
      'cellDuration': knobs.arg('cellDuration'),
      'gap': knobs.arg('gap'),
      'borderRadius': 'BorderRadius.circular(20)',
      'first': 'const ProductPhoto()',
      'second': 'const ProductDetails()',
    });
    if (trigger != PixelSwapTrigger.manual) return widget;
    return 'final controller = PixelSwapController();\n\n'
        '$widget\n\n'
        '// Start the wave from a point, or from the center:\n'
        'controller.toggle();';
  },
  notes: const [
    'Only the visible child is exposed to assistive technology, can take '
        'focus and receives pointer input; the swap happens halfway through '
        'the wave.',
    'Reversing mid-wave is seamless: cells keep their current scale and turn '
        'around. Once the wave settles the second child is painted whole.',
    'Under reduced motion, or with enabled set to false, the children swap '
        'instantly. With enabled set to false hover and tap are ignored, '
        'while showSecond and the controller still work.',
  ],
  stageHeight: 460,
);

class _PixelSwapDemo extends StatefulWidget {
  const _PixelSwapDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_PixelSwapDemo> createState() => _PixelSwapDemoState();
}

class _PixelSwapDemoState extends State<_PixelSwapDemo> {
  final PixelSwapController _controller = PixelSwapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final PixelSwapTrigger trigger = knobs.pick('trigger');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelSwap(
          controller: _controller,
          trigger: trigger,
          gridSize: knobs.number('gridSize').round(),
          duration: knobs.ms('duration'),
          cellDuration: knobs.ms('cellDuration'),
          gap: knobs.number('gap'),
          borderRadius: BorderRadius.circular(20),
          first: const _ProductPhoto(),
          second: const _ProductDetails(),
        ),
        const Gap(16),
        if (trigger == PixelSwapTrigger.manual)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => OutlinedButton(
              onPressed: _controller.toggle,
              child: Text(
                _controller.isShowingSecond ? 'Show photo' : 'Show details',
              ),
            ),
          )
        else
          DemoCaption(
            trigger == PixelSwapTrigger.hover
                ? 'Hover the card, or tap it on touch'
                : 'Tap the card',
          ),
      ],
    );
  }
}

const double _width = 260;
const double _height = 320;

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({this.width = _width, this.height = _height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: GeneratedImage(
              style: SceneStyle.aurora,
              seed: 7,
              width: 520,
              height: 640,
            ),
            fit: BoxFit.cover,
            semanticLabel: 'Aurora art print',
          ),
          if (height > 200)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Aurora print',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onPrimary.withValues(alpha: 0.8),
    );
    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIMITED EDITION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              letterSpacing: 1.4,
            ),
          ),
          const Gap(8),
          Text(
            'Aurora print',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Giclee on cotton paper, 50 x 70 cm. Signed and numbered.',
            style: muted,
          ),
          const Spacer(),
          Text(
            '\$48',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
              ),
              onPressed: () =>
                  demoToast(context, 'Added to cart', type: ToastType.success),
              child: const Text('Add to cart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelSwapThumb extends StatefulWidget {
  const _PixelSwapThumb();

  @override
  State<_PixelSwapThumb> createState() => _PixelSwapThumbState();
}

class _PixelSwapThumbState extends State<_PixelSwapThumb> {
  late final Timer _timer;
  bool _second = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _second = !_second);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: PixelSwap(
        trigger: PixelSwapTrigger.manual,
        showSecond: _second,
        gridSize: 10,
        borderRadius: BorderRadius.circular(14),
        first: const _ProductPhoto(width: 220, height: 130),
        second: Container(
          color: scheme.primary,
          alignment: Alignment.center,
          child: Text(
            'Add to cart',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
