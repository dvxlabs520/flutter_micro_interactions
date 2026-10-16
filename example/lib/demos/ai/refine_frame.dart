import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';
import '../../shared/generated_images.dart';

final ComponentEntry refineFrameEntry = ComponentEntry(
  id: 'refine-frame',
  name: 'Refine Frame',
  category: Categories.ai,
  summary:
      'A media frame for image generation that develops a picture from '
      'noisy and blurry drafts to the final image, without any layout shift.',
  apis: const ['RefineFrame', 'RefineRevealStyle', 'RefineLabelBuilder'],
  tags: const [ComponentTag.newly, ComponentTag.ai],
  knobs: [
    SliderKnob(
      id: 'steps',
      label: 'Steps',
      min: 2,
      max: 8,
      initial: 4,
      divisions: 6,
      format: (v) => '${v.round()}',
      codeOf: (v) => '${v.round()}',
    ),
    SelectKnob.enumeration(
      id: 'revealStyle',
      label: 'Reveal',
      values: RefineRevealStyle.values,
      initial: RefineRevealStyle.radial,
      typeName: 'RefineRevealStyle',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Reveal duration',
      min: 200,
      max: 1600,
      initial: 700,
      divisions: 14,
    ),
    const ToggleKnob(
      id: 'showGrain',
      label: 'Grain overlay',
      initial: true,
      help: 'Animated film grain and a slow scanline while generating.',
    ),
    const ToggleKnob(id: 'showProgress', label: 'Progress pill', initial: true),
  ],
  preview: (context, knobs) => _RefineDemo(knobs: knobs),
  thumbnail: (context) => const _RefineThumb(),
  code: (knobs) {
    return dartCall('RefineFrame.blurred', {
      'image': 'MemoryImage(previewBytes)',
      'stage': 'step',
      'steps': knobs.arg('steps'),
      'isGenerating': 'generating',
      'aspectRatio': '4 / 3',
      'revealStyle': knobs.arg('revealStyle'),
      'duration': knobs.arg('duration'),
      'showGrain': knobs.arg('showGrain'),
      'showProgress': knobs.arg('showProgress'),
      'semanticLabel': "'Mountain lake at dawn'",
    });
  },
  notes: const [
    'The frame is one image node labelled with semanticLabel, followed by '
        'the refining step (for example step 2 of 4) while generating. The '
        'stage widgets are not exposed.',
    'The frame keeps the same aspect ratio and radius for every stage, so '
        'nothing around it moves. A stage change during a reveal is queued, '
        'never skipped.',
    'Under reduced motion, or with enabled set to false, stages switch '
        'instantly and the overlay has no grain or scanline; the progress '
        'pill is still shown.',
  ],
  replayable: true,
  stageHeight: 500,
);

const GeneratedImage _image = GeneratedImage(
  style: SceneStyle.mountains,
  seed: 1,
  width: 640,
  height: 480,
);

class _RefineDemo extends StatefulWidget {
  const _RefineDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_RefineDemo> createState() => _RefineDemoState();
}

class _RefineDemoState extends State<_RefineDemo> {
  Timer? _timer;
  int _stage = 0;
  int _steps = 4;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_RefineDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int steps = widget.knobs.number('steps').round();
    if (steps != _steps) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _steps = widget.knobs.number('steps').round();
    _stage = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (timer) {
      if (!mounted) return;
      setState(() => _stage++);
      if (_stage >= _steps - 1) timer.cancel();
    });
  }

  bool get _generating => _stage < _steps - 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: DemoCard(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A quiet mountain lake at dawn, soft light',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Gap(12),
            RefineFrame.blurred(
              image: _image,
              stage: _stage.clamp(0, _steps - 1),
              steps: _steps,
              isGenerating: _generating,
              aspectRatio: 4 / 3,
              revealStyle: widget.knobs.pick('revealStyle'),
              duration: widget.knobs.ms('duration'),
              showGrain: widget.knobs.flag('showGrain'),
              showProgress: widget.knobs.flag('showProgress'),
              borderRadius: BorderRadius.circular(12),
              semanticLabel: 'Mountain lake at dawn',
            ),
            const Gap(10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _generating
                        ? 'Generating, step ${_stage + 1} of $_steps'
                        : 'Done in $_steps steps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _generating ? null : () => setState(_start),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Regenerate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefineThumb extends StatefulWidget {
  const _RefineThumb();

  @override
  State<_RefineThumb> createState() => _RefineThumbState();
}

class _RefineThumbState extends State<_RefineThumb> {
  late final Timer _timer;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted) setState(() => _stage = (_stage + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: RefineFrame.blurred(
        image: _image,
        stage: _stage,
        aspectRatio: 16 / 9,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
