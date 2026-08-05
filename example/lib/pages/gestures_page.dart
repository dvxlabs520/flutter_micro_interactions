import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for TapFeedback, HoverGlow, RippleEffect, LongPressMenu and
/// ShakeToAction.
class GesturesPage extends StatefulWidget {
  const GesturesPage({super.key});

  @override
  State<GesturesPage> createState() => _GesturesPageState();
}

class _GesturesPageState extends State<GesturesPage> {
  final ShakeController _shakeController = ShakeController();
  final WaterRippleController _waterController = WaterRippleController();
  bool _wavesPlaying = false;
  int _shakeCount = 0;

  @override
  void dispose() {
    _shakeController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Gestures & Taps',
      description:
          'Press, hover, long-press and shake interactions that make any '
          'widget feel responsive.',
      children: [
        DemoSection(
          title: 'TapFeedback',
          description:
              'Wraps any widget with a press animation. Four effects are '
              'available: scale, bounce, fade and scale-and-fade.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TapFeedback.scale(
                onTap: () => showMessage(context, 'Scale tap'),
                child: const _EffectChip(label: 'Scale', icon: Icons.zoom_in),
              ),
              TapFeedback.bounce(
                onTap: () => showMessage(context, 'Bounce tap'),
                child: const _EffectChip(
                    label: 'Bounce', icon: Icons.sports_basketball),
              ),
              TapFeedback.fade(
                onTap: () => showMessage(context, 'Fade tap'),
                child: const _EffectChip(label: 'Fade', icon: Icons.opacity),
              ),
              TapFeedback(
                effect: TapAnimationType.scaleAndFade,
                scaleDown: 0.9,
                opacity: 0.7,
                onTap: () => showMessage(context, 'Scale and fade tap'),
                child: const _EffectChip(
                    label: 'Scale + Fade', icon: Icons.auto_awesome),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'TapFeedback on real content',
          description: 'The same wrapper applied to a list card.',
          child: TapFeedback.scale(
            onTap: () => showMessage(context, 'Conversation opened'),
            child: Card(
              elevation: 3,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: const Text('Amelia Stone'),
                subtitle: const Text('Meeting moved to 3 PM, does that work?'),
                trailing: const Text('12:40'),
              ),
            ),
          ),
        ),
        DemoSection(
          title: 'HoverGlow',
          description:
              'Adds an animated glow on mouse hover or keyboard focus. '
              'Try it with a mouse or by tabbing to the button.',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HoverGlow(
                borderRadius: BorderRadius.circular(24),
                child: FilledButton.icon(
                  onPressed: () => showMessage(context, 'Glowing button'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Hover me'),
                ),
              ),
              HoverGlow(
                glowColor: Colors.teal,
                glowRadius: 18,
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        const Text('Glowing card'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'RippleEffect and RippleButton',
          description:
              'Expanding circles at the tap position, clipped to the widget. '
              'RippleButton is a ready-made surface using the same effect.',
          child: Column(
            children: [
              RippleEffect(
                borderRadius: BorderRadius.circular(12),
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Tap anywhere on this surface',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RippleButton(
                onTap: () => showMessage(context, 'Ripple button tapped'),
                child: const Text(
                  'Ripple Button',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'WaterRipple',
          description:
              'Looping concentric waves behind a widget, started and stopped '
              'with a WaterRippleController.',
          child: Column(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: WaterRipple(
                  autoPlay: false,
                  controller: _waterController,
                  child: const Center(child: Icon(Icons.mic, size: 44)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _wavesPlaying = !_wavesPlaying;
                  });
                  if (_wavesPlaying) {
                    _waterController.start();
                  } else {
                    _waterController.stop();
                  }
                },
                icon: Icon(_wavesPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_wavesPlaying ? 'Stop waves' : 'Start waves'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'LongPressMenu',
          description:
              'Long press the photo card to open a context menu at the press '
              'position.',
          child: LongPressMenu(
            menuItems: [
              LongPressMenuItem.copy(),
              LongPressMenuItem.share(),
              LongPressMenuItem.edit(),
              LongPressMenuItem.delete(),
            ],
            onSelected: (item) => showMessage(context, '${item.label} selected'),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.landscape, size: 56),
                  ),
                  const ListTile(
                    title: Text('Vacation photo'),
                    subtitle: Text('Long press for options'),
                  ),
                ],
              ),
            ),
          ),
        ),
        DemoSection(
          title: 'ShakeToAction',
          description:
              'Detects a rapid back-and-forth drag on the card. Drag left and '
              'right quickly, or trigger it with the button.',
          child: Column(
            children: [
              ShakeToAction(
                onShake: () {
                  setState(() {
                    _shakeCount++;
                  });
                  showMessage(context, 'Shake detected');
                },
                controller: _shakeController,
                requiredReversals: 3,
                velocityThreshold: 400,
                intensity: 12,
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.vibration, size: 40),
                        const SizedBox(height: 8),
                        const Text('Shake me with a quick drag'),
                        const SizedBox(height: 4),
                        Text('Shakes detected: $_shakeCount'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _shakeController.shake,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Trigger with ShakeController'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}
