import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for SlideToConfirm, LiquidProgress and AnimatedCheck.
class ProgressConfirmationPage extends StatefulWidget {
  const ProgressConfirmationPage({super.key});

  @override
  State<ProgressConfirmationPage> createState() =>
      _ProgressConfirmationPageState();
}

class _ProgressConfirmationPageState extends State<ProgressConfirmationPage> {
  // Connected checkout flow.
  final SlideToConfirmController _checkoutSlide = SlideToConfirmController();
  final AnimatedCheckController _checkoutCheck = AnimatedCheckController();
  Timer? _paymentTimer;
  double _paymentProgress = 0.0;
  bool _paymentComplete = false;

  // AnimatedCheck variants.
  final AnimatedCheckController _markController = AnimatedCheckController();
  AnimatedCheckType _markType = AnimatedCheckType.check;

  // Rectangle liquid progress.
  double _uploadProgress = 0.35;

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _checkoutSlide.dispose();
    _checkoutCheck.dispose();
    _markController.dispose();
    super.dispose();
  }

  /// Simulates a payment being processed: the liquid fills in small steps
  /// and the check draws itself once the fill reaches 100 percent.
  void _startPayment() {
    _paymentTimer?.cancel();
    _paymentTimer =
        Timer.periodic(const Duration(milliseconds: 250), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _paymentProgress = (_paymentProgress + 0.12).clamp(0.0, 1.0);
      });
      if (_paymentProgress >= 1.0) {
        timer.cancel();
        setState(() {
          _paymentComplete = true;
        });
        _checkoutCheck.play();
      }
    });
  }

  void _resetPayment() {
    _paymentTimer?.cancel();
    _checkoutSlide.reset();
    _checkoutCheck.reset();
    setState(() {
      _paymentProgress = 0.0;
      _paymentComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DemoPage(
      title: 'Progress & Confirmation',
      description:
          'A slide gesture confirms an action, a liquid wave tracks its '
          'progress and a hand-drawn check reports the result.',
      children: [
        DemoSection(
          title: 'Checkout flow',
          description:
              'The three widgets working together: slide to pay, watch the '
              'payment process as the liquid fills, then see the check draw '
              'itself on completion.',
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: Center(
                  child: _paymentComplete
                      ? AnimatedCheck(
                          autoPlay: false,
                          controller: _checkoutCheck,
                          size: 72,
                          semanticLabel: 'Payment complete',
                        )
                      : LiquidProgress(
                          value: _paymentProgress,
                          size: 104,
                          showPercentage: true,
                          semanticLabel: 'Payment progress',
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _paymentComplete
                    ? 'Payment of \$24.99 complete'
                    : _paymentProgress > 0.0
                        ? 'Processing payment...'
                        : 'Order total: \$24.99',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              SlideToConfirm(
                controller: _checkoutSlide,
                label: 'Slide to pay \$24.99',
                onConfirmed: _startPayment,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _resetPayment,
                icon: const Icon(Icons.replay),
                label: const Text('Reset order'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'SlideToConfirm: automatic reset',
          description:
              'resetAfterConfirm springs the control back to its initial '
              'state shortly after confirming, so it can be reused without a '
              'controller. Styled here as a destructive action.',
          child: SlideToConfirm(
            label: 'Slide to delete account',
            fillColor: scheme.error,
            thumbColor: scheme.error,
            resetAfterConfirm: true,
            confirmedChild: Icon(Icons.delete_forever, color: scheme.onError),
            onConfirmed: () => showMessage(context, 'Account deleted'),
          ),
        ),
        DemoSection(
          title: 'AnimatedCheck: check and cross',
          description:
              'The stroke is revealed with path metrics, so it looks drawn '
              'rather than faded in. Switching the mark replays the '
              'animation; Replay draws the current mark again.',
          child: Column(
            children: [
              AnimatedCheck(
                type: _markType,
                controller: _markController,
                size: 64,
              ),
              const SizedBox(height: 16),
              SegmentedButton<AnimatedCheckType>(
                segments: const [
                  ButtonSegment(
                    value: AnimatedCheckType.check,
                    label: Text('Success'),
                    icon: Icon(Icons.check),
                  ),
                  ButtonSegment(
                    value: AnimatedCheckType.cross,
                    label: Text('Error'),
                    icon: Icon(Icons.close),
                  ),
                ],
                selected: {_markType},
                onSelectionChanged: (Set<AnimatedCheckType> selection) {
                  setState(() {
                    _markType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _markController.play,
                icon: const Icon(Icons.replay),
                label: const Text('Replay'),
              ),
            ],
          ),
        ),
        DemoSection(
          title: 'LiquidProgress: rectangle',
          description:
              'The same liquid wave in a rounded rectangle. Value changes '
              'retarget smoothly from the current animated level.',
          child: Column(
            children: [
              LiquidProgress(
                value: _uploadProgress,
                shape: LiquidProgressShape.rectangle,
                width: 220,
                height: 80,
                showPercentage: true,
                liquidColor: scheme.tertiary,
                semanticLabel: 'Upload progress',
              ),
              const SizedBox(height: 8),
              Slider(
                value: _uploadProgress,
                onChanged: (double value) {
                  setState(() {
                    _uploadProgress = value;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
