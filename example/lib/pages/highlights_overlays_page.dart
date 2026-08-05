import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for TypewriterText, AnimatedGradientBorder and ExpandableFab.
class HighlightsOverlaysPage extends StatefulWidget {
  const HighlightsOverlaysPage({super.key});

  @override
  State<HighlightsOverlaysPage> createState() => _HighlightsOverlaysPageState();
}

class _HighlightsOverlaysPageState extends State<HighlightsOverlaysPage> {
  final TypewriterController _welcomeTyping = TypewriterController();
  final AnimatedGradientBorderController _borderController =
      AnimatedGradientBorderController();
  final ExpandableFabController _fabController = ExpandableFabController();
  bool _borderAnimating = true;
  ExpandableFabDirection _fabDirection = ExpandableFabDirection.up;

  @override
  void dispose() {
    _welcomeTyping.dispose();
    _borderController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return DemoPage(
      title: 'Highlights & Overlays',
      description:
          'Typing text for hero sections, sweeping gradient borders for '
          'featured content, and a fab that expands into quick actions.',
      children: [
        DemoSection(
          title: 'TypewriterText: looping hero',
          description:
              'Cycles through several strings, deleting each one before '
              'typing the next. Layout is reserved up front, so the line '
              'below never jumps while characters appear.',
          child: SizedBox(
            width: double.infinity,
            child: TypewriterText(
              strings: const [
                'Ship delightful details.',
                'Animate the small stuff.',
                'Micro-interactions, macro impact.',
              ],
              loop: true,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DemoSection(
          title: 'TypewriterText.single: replay',
          description:
              'A single string typed once, driven by a TypewriterController. '
              'Replay restarts it from the first character.',
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: TypewriterText.single(
                  text: 'Welcome back, Jordan. You have 3 new notifications.',
                  controller: _welcomeTyping,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _welcomeTyping.reset,
                icon: const Icon(Icons.replay),
                label: const Text('Replay'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'AnimatedGradientBorder: featured card',
          description:
              'A sweeping gradient with a soft glow marks the recommended '
              'plan. The controller pauses and resumes the sweep.',
          child: Column(
            children: [
              AnimatedGradientBorder(
                controller: _borderController,
                borderWidth: 3,
                glowRadius: 6,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Pro Plan', style: theme.textTheme.titleMedium),
                          const SizedBox(width: 8),
                          const Chip(
                            label: Text('Recommended'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$12 / month',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlimited projects, priority support and advanced '
                        'analytics for growing teams.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Animate border'),
                value: _borderAnimating,
                onChanged: (bool value) {
                  setState(() {
                    _borderAnimating = value;
                  });
                  if (value) {
                    _borderController.start();
                  } else {
                    _borderController.stop();
                  }
                },
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'AnimatedGradientBorder + ShimmerButton',
          description:
              'The border composes with any child. Here it wraps a '
              'ShimmerButton, stacking two attention cues on the primary '
              'call to action.',
          child: AnimatedGradientBorder(
            borderWidth: 2,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(4),
            child: ShimmerButton(
              onPressed: () => showMessage(context, 'Trial started'),
              child: Text(
                'Start free trial',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        DemoSection(
          title: 'ExpandableFab',
          description:
              'The main button expands into mini actions with a staggered '
              'entrance. Actions render through the app Overlay, so they '
              'can spill outside their parent. Tap outside or press Escape '
              'to close.',
          child: Column(
            children: [
              SegmentedButton<ExpandableFabDirection>(
                segments: const [
                  ButtonSegment(
                    value: ExpandableFabDirection.up,
                    label: Text('Up'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: ExpandableFabDirection.left,
                    label: Text('Left'),
                    icon: Icon(Icons.arrow_back),
                  ),
                  ButtonSegment(
                    value: ExpandableFabDirection.radial,
                    label: Text('Radial'),
                    icon: Icon(Icons.donut_large),
                  ),
                ],
                selected: {_fabDirection},
                onSelectionChanged: (Set<ExpandableFabDirection> selection) {
                  _fabController.close();
                  setState(() {
                    _fabDirection = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Text(
                        'Inbox',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: ExpandableFab(
                        controller: _fabController,
                        direction: _fabDirection,
                        distance: _fabDirection == ExpandableFabDirection.radial
                            ? 96
                            : 60,
                        actions: [
                          ExpandableFabAction(
                            icon: const Icon(Icons.edit),
                            label: 'Compose',
                            onPressed: () =>
                                showMessage(context, 'Composing a message'),
                          ),
                          ExpandableFabAction(
                            icon: const Icon(Icons.photo_camera),
                            label: 'Camera',
                            onPressed: () =>
                                showMessage(context, 'Opening the camera'),
                          ),
                          ExpandableFabAction(
                            icon: const Icon(Icons.mic),
                            label: 'Voice note',
                            onPressed: () =>
                                showMessage(context, 'Recording a voice note'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
