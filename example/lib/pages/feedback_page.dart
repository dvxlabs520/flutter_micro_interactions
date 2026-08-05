import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for ToastNotification and the context.showToast extension.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  ToastPosition _position = ToastPosition.top;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Feedback & Toasts',
      description:
          'Overlay based toasts that stack, dismiss themselves and announce '
          'their message to assistive technology.',
      children: [
        DemoSection(
          title: 'Position',
          description: 'Where the next toasts will appear on screen.',
          child: SegmentedButton<ToastPosition>(
            segments: const [
              ButtonSegment(value: ToastPosition.top, label: Text('Top')),
              ButtonSegment(value: ToastPosition.center, label: Text('Center')),
              ButtonSegment(value: ToastPosition.bottom, label: Text('Bottom')),
            ],
            selected: {_position},
            onSelectionChanged: (selection) {
              setState(() {
                _position = selection.first;
              });
            },
          ),
        ),
        DemoSection(
          title: 'Toast types',
          description:
              'Each type has theme-aware default colors and an icon. Shown '
              'with the context.showToast extension; the static '
              'ToastNotification.show API takes the same parameters.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: () => context.showToast(
                  message: 'Profile saved successfully',
                  type: ToastType.success,
                  position: _position,
                ),
                child: const Text('Success'),
              ),
              FilledButton(
                onPressed: () => context.showToast(
                  message: 'Could not reach the server',
                  type: ToastType.error,
                  position: _position,
                ),
                child: const Text('Error'),
              ),
              FilledButton(
                onPressed: () => context.showToast(
                  message: 'A new version is available',
                  type: ToastType.info,
                  position: _position,
                ),
                child: const Text('Info'),
              ),
              FilledButton(
                onPressed: () => context.showToast(
                  message: 'Storage is almost full',
                  type: ToastType.warning,
                  position: _position,
                ),
                child: const Text('Warning'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'Action button and tap to dismiss',
          description:
              'actionLabel adds a button that runs onAction and closes the '
              'toast. dismissOnTap closes it when the body is tapped.',
          child: OutlinedButton.icon(
            onPressed: () {
              // The static API, equivalent to context.showToast.
              ToastNotification.show(
                context: context,
                message: 'Message deleted',
                type: ToastType.info,
                position: _position,
                actionLabel: 'Undo',
                onAction: () => showMessage(context, 'Delete undone'),
                dismissOnTap: true,
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete with undo'),
          ),
        ),
        DemoSection(
          title: 'Stacking',
          description:
              'Simultaneous toasts at the same position stack; the remaining '
              'toasts slide back into place when one is dismissed.',
          child: OutlinedButton.icon(
            onPressed: () {
              for (int i = 1; i <= 3; i++) {
                context.showToast(
                  message: 'Stacked toast $i of 3',
                  type: ToastType.info,
                  position: _position,
                  duration: Duration(seconds: 2 + i),
                );
              }
            },
            icon: const Icon(Icons.layers),
            label: const Text('Show three toasts'),
          ),
        ),
      ],
    );
  }
}
