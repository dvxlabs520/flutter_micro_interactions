import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../../catalog/categories.dart';
import '../../catalog/models.dart';
import '../../shared/demo_kit.dart';

enum _Variant { morphingShapes, shapeMorph }

enum _ShapeSet {
  basics([
    MicroShapeType.circle,
    MicroShapeType.square,
    MicroShapeType.triangle,
  ]),
  playful([MicroShapeType.heart, MicroShapeType.star, MicroShapeType.diamond]),
  all(MicroShapeType.values);

  const _ShapeSet(this.shapes);

  final List<MicroShapeType> shapes;
}

String _shapeName(MicroShapeType s) =>
    s.name[0].toUpperCase() + s.name.substring(1);

final ComponentEntry morphingShapesEntry = ComponentEntry(
  id: 'morphing-shapes',
  name: 'Morphing Shapes',
  category: Categories.transitions,
  summary:
      'Shapes whose outline really deforms from one into the next. Cycle '
      'through a list with MorphingShapes, or toggle between two with '
      'ShapeMorph.',
  apis: const [
    'MorphingShapes',
    'MorphingShapesController',
    'ShapeMorph',
    'MicroShapeType',
  ],
  knobs: [
    SelectKnob<_Variant>(
      id: 'variant',
      label: 'Variant',
      options: _Variant.values,
      initial: _Variant.morphingShapes,
      labelOf: (v) => switch (v) {
        _Variant.morphingShapes => 'MorphingShapes',
        _Variant.shapeMorph => 'ShapeMorph',
      },
    ),
    SelectKnob<_ShapeSet>(
      id: 'shapes',
      label: 'Shapes',
      options: _ShapeSet.values,
      initial: _ShapeSet.basics,
      labelOf: (s) => switch (s) {
        _ShapeSet.basics => 'Basics',
        _ShapeSet.playful => 'Playful',
        _ShapeSet.all => 'All six',
      },
      help: 'ShapeMorph uses the first two.',
    ),
    const SliderKnob.duration(
      id: 'duration',
      label: 'Duration',
      min: 200,
      max: 2000,
      initial: 800,
      divisions: 18,
    ),
    const ToggleKnob(
      id: 'autoPlay',
      label: 'Auto play',
      initial: true,
      help: 'autoPlay for MorphingShapes, autoReverse for ShapeMorph.',
    ),
    const ColorKnob(id: 'color', label: 'Color', swatches: demoSwatches),
  ],
  preview: (context, knobs) => _MorphDemo(knobs: knobs),
  thumbnail: (context) => const MorphingShapes(
    shapes: [MicroShapeType.circle, MicroShapeType.star, MicroShapeType.heart],
    size: Size(110, 110),
    duration: Duration(milliseconds: 600),
    autoPlay: true,
    autoPlayDuration: Duration(milliseconds: 900),
  ),
  code: (knobs) {
    final _Variant variant = knobs.pick('variant');
    final List<MicroShapeType> shapes = knobs.pick<_ShapeSet>('shapes').shapes;
    final bool auto = knobs.flag('autoPlay');
    final int ms = knobs.number('duration').round();
    if (variant == _Variant.shapeMorph) {
      return dartCall('ShapeMorph', {
        'fromShape': 'MicroShapeType.${shapes[0].name}',
        'toShape': 'MicroShapeType.${shapes[1].name}',
        'duration': ms == 600 ? null : knobs.code('duration'),
        'autoReverse': auto ? 'true' : null,
        'color': knobs.arg('color'),
        'size': 'const Size(140, 140)',
        'semanticLabel': "'Favorite'",
      });
    }
    final String widget = dartCall('MorphingShapes', {
      'controller': 'controller',
      'shapes':
          'const ${dartList([for (final MicroShapeType s in shapes) 'MicroShapeType.${s.name}'])}',
      'duration': knobs.arg('duration'),
      'autoPlay': auto ? 'true' : null,
      'color': knobs.arg('color'),
      'size': 'const Size(140, 140)',
      'onShapeChanged': '(shape) => setState(() => current = shape)',
    });
    return 'final controller = MorphingShapesController();\n\n'
        '$widget\n\n'
        '// Drive it from buttons or app state.\n'
        'controller.morphToNext();\n'
        'controller.morphTo(MicroShapeType.${shapes.last.name});';
  },
  notes: const [
    'The drawing is decorative and excluded from semantics unless you pass '
        'a semanticLabel.',
    'Under reduced motion MorphingShapes swaps shapes instantly (auto play '
        'still advances) and ShapeMorph does not loop.',
    'With enabled set to false, auto play, taps and controller commands are '
        'ignored and the current shape renders statically.',
  ],
);

class _MorphDemo extends StatefulWidget {
  const _MorphDemo({required this.knobs});

  final Knobs knobs;

  @override
  State<_MorphDemo> createState() => _MorphDemoState();
}

class _MorphDemoState extends State<_MorphDemo> {
  final MorphingShapesController _controller = MorphingShapesController();
  MicroShapeType? _current;
  (_ShapeSet, _Variant)? _setup;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Knobs knobs = widget.knobs;
    final _Variant variant = knobs.pick('variant');
    final _ShapeSet set = knobs.pick('shapes');
    if ((set, variant) != _setup) {
      // The keyed MorphingShapes below restarts from the first shape.
      _setup = (set, variant);
      _current = null;
    }
    final bool auto = knobs.flag('autoPlay');
    final Color? color = knobs.color('color');
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget stage = Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: variant == _Variant.morphingShapes
          ? MorphingShapes(
              // A new list starts again from its first shape.
              key: ValueKey(set),
              controller: _controller,
              shapes: set.shapes,
              duration: knobs.ms('duration'),
              autoPlay: auto,
              color: color,
              size: const Size(140, 140),
              onShapeChanged: (shape) => setState(() => _current = shape),
            )
          : ShapeMorph(
              // Remount so turning the loop off also stops it.
              key: ValueKey('$set-$auto'),
              fromShape: set.shapes[0],
              toShape: set.shapes[1],
              duration: knobs.ms('duration'),
              autoReverse: auto,
              color: color,
              size: const Size(140, 140),
            ),
    );

    if (variant == _Variant.shapeMorph) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          stage,
          const SizedBox(height: 20),
          DemoCaption(
            auto
                ? 'Loops between ${_shapeName(set.shapes[0]).toLowerCase()} '
                      'and ${_shapeName(set.shapes[1]).toLowerCase()}.'
                : 'Tap the shape to toggle it.',
          ),
        ],
      );
    }

    final MicroShapeType current = _current ?? set.shapes.first;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          stage,
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final MicroShapeType shape in set.shapes)
                ChoiceChip(
                  label: Text(_shapeName(shape)),
                  selected: shape == current,
                  onSelected: (_) => _controller.morphTo(shape),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _controller.morphToNext,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('Next shape'),
          ),
        ],
      ),
    );
  }
}
