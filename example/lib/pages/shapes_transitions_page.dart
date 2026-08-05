import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for MorphingShapes, ShapeMorph, CardFlip and MicroPageRoute.
class ShapesTransitionsPage extends StatefulWidget {
  const ShapesTransitionsPage({super.key});

  @override
  State<ShapesTransitionsPage> createState() => _ShapesTransitionsPageState();
}

class _ShapesTransitionsPageState extends State<ShapesTransitionsPage> {
  final MorphingShapesController _morphController = MorphingShapesController();
  final CardFlipController _flipController = CardFlipController();
  bool _isFlipped = false;

  static const List<(String, MicroTransitionType)> _transitions = [
    ('Fade', MicroTransitionType.fade),
    ('Slide right', MicroTransitionType.slideRight),
    ('Slide bottom', MicroTransitionType.slideBottom),
    ('Scale', MicroTransitionType.scale),
    ('Rotate', MicroTransitionType.rotate),
    ('Size', MicroTransitionType.size),
    ('Flip', MicroTransitionType.flip),
    ('Blur', MicroTransitionType.blur),
  ];

  @override
  void dispose() {
    _morphController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Shapes & Transitions',
      description:
          'Path-morphing shapes, 3D card flips and animated page routes.',
      children: [
        const DemoSection(
          title: 'MorphingShapes',
          description:
              'Cycles through a list of shapes with a real outline morph. '
              'This one auto plays and also advances on tap.',
          child: MorphingShapes(
            shapes: [
              MicroShapeType.circle,
              MicroShapeType.square,
              MicroShapeType.triangle,
              MicroShapeType.star,
            ],
            size: Size(130, 130),
            autoPlay: true,
            morphOnTap: true,
          ),
        ),
        DemoSection(
          title: 'MorphingShapes with a controller',
          description:
              'MorphingShapesController drives morphs programmatically.',
          child: Column(
            children: [
              MorphingShapes(
                shapes: const [
                  MicroShapeType.heart,
                  MicroShapeType.diamond,
                  MicroShapeType.star,
                ],
                size: const Size(110, 110),
                controller: _morphController,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _morphController.morphToNext,
                    child: const Text('Next shape'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _morphController.morphTo(MicroShapeType.heart),
                    child: const Text('Morph to heart'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const DemoSection(
          title: 'ShapeMorph',
          description: 'Morphs between exactly two shapes. Tap to toggle.',
          child: ShapeMorph(
            fromShape: MicroShapeType.circle,
            toShape: MicroShapeType.square,
            size: Size(90, 90),
            color: Colors.orange,
          ),
        ),
        DemoSection(
          title: 'CardFlip: uncontrolled',
          description: 'Tap the card; it flips itself and reports the state.',
          child: SizedBox(
            width: 190,
            height: 240,
            child: CardFlip(
              front: const _CardFace(
                title: 'Question',
                body: 'What animates a page route in this package?',
                icon: Icons.help_outline,
                color: Colors.indigo,
              ),
              back: const _CardFace(
                title: 'Answer',
                body: 'MicroPageRoute, or the MicroNavigator helpers.',
                icon: Icons.lightbulb_outline,
                color: Colors.green,
              ),
              onFlip: (flipped) =>
                  showMessage(context, flipped ? 'Back shown' : 'Front shown'),
            ),
          ),
        ),
        DemoSection(
          title: 'CardFlip: controlled and controller driven',
          description:
              'With isFlipped the parent owns the state; a CardFlipController '
              'flips without taps.',
          child: Column(
            children: [
              SizedBox(
                width: 190,
                height: 240,
                child: CardFlip(
                  isFlipped: _isFlipped,
                  onFlip: (flipped) {
                    setState(() {
                      _isFlipped = flipped;
                    });
                  },
                  controller: _flipController,
                  direction: Axis.vertical,
                  front: const _CardFace(
                    title: 'Front',
                    body: 'The parent decides which face is visible.',
                    icon: Icons.credit_card,
                    color: Colors.purple,
                  ),
                  back: const _CardFace(
                    title: 'Back',
                    body: 'Flipped through state or the controller.',
                    icon: Icons.qr_code,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isFlipped = !_isFlipped;
                      });
                    },
                    child: Text(_isFlipped ? 'Show front' : 'Show back'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _flipController.flip,
                    icon: const Icon(Icons.flip),
                    label: const Text('Controller flip'),
                  ),
                ],
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'MicroPageRoute',
          description:
              'Every transition type, pushed with MicroNavigator.push. The '
              'navigation in this example app uses the same routes.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (String name, MicroTransitionType type)
                  in _transitions)
                ActionChip(
                  label: Text(name),
                  onPressed: () {
                    MicroNavigator.push(
                      context,
                      _TransitionDemoPage(title: name),
                      type: type,
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TransitionDemoPage extends StatelessWidget {
  const _TransitionDemoPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$title transition')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 88,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '$title transition',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Pop this page to see the reverse animation.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // MicroNavigator also wraps pushReplacement and
                // pushAndRemoveUntil.
                MicroNavigator.pushReplacement(
                  context,
                  _TransitionDemoPage(title: '$title (replaced)'),
                  type: MicroTransitionType.fade,
                );
              },
              child: const Text('Push replacement'),
            ),
          ],
        ),
      ),
    );
  }
}
