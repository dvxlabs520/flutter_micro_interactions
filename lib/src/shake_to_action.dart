import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Programmatic trigger for [ShakeToAction] and [ShakeAnimation].
///
/// ```dart
/// final controller = ShakeController();
/// // ...
/// ShakeAnimation(controller: controller, child: myWidget);
/// // later:
/// controller.shake();
/// ```
///
/// Calling [shake] plays the shake animation on every attached widget. On a
/// [ShakeToAction] it also fires `onShake`, exactly as if the user had
/// performed the shake gesture. Dispose the controller yourself when it is
/// no longer needed.
class ShakeController extends ChangeNotifier {
  /// Triggers the shake animation on attached widgets.
  void shake() {
    notifyListeners();
  }
}

/// Detects a vigorous back-and-forth drag ("shake" gesture) on its child and
/// runs [onShake] with a shake animation.
///
/// This widget is gesture based, not accelerometer based: it does not read
/// device motion sensors and does not react to physically shaking the
/// device. It detects a rapid horizontal back-and-forth drag on the child:
/// the pointer must reverse horizontal direction at least
/// [requiredReversals] times within [detectionWindow], each reversal moving
/// faster than [velocityThreshold] logical pixels per second. A plain drag
/// in one direction never triggers it.
///
/// ```dart
/// ShakeToAction(
///   onShake: () => undoLastAction(),
///   child: const NoteCard(),
/// )
/// ```
///
/// [onShake] can also be fired programmatically through [controller].
///
/// Under reduced motion the translation animation is skipped but callbacks
/// and haptics still fire.
class ShakeToAction extends StatefulWidget {
  /// Creates a shake to action widget.
  const ShakeToAction({
    super.key,
    required this.child,
    required this.onShake,
    this.controller,
    this.requiredReversals = 3,
    this.detectionWindow = const Duration(milliseconds: 600),
    this.velocityThreshold = 600.0,
    this.cooldown = const Duration(milliseconds: 500),
    this.duration = const Duration(milliseconds: 400),
    this.intensity = 8.0,
    this.enableHaptics = true,
    this.enabled = true,
  })  : assert(requiredReversals > 0, 'requiredReversals must be positive'),
        assert(velocityThreshold > 0, 'velocityThreshold must be positive'),
        assert(intensity >= 0, 'intensity must not be negative');

  /// The widget the gesture is detected on.
  final Widget child;

  /// Called when a shake gesture is detected (or [controller] fires).
  final VoidCallback onShake;

  /// Optional controller to trigger the shake programmatically.
  final ShakeController? controller;

  /// Number of horizontal direction reversals needed within
  /// [detectionWindow]. Defaults to 3.
  final int requiredReversals;

  /// Time window in which the reversals must happen.
  /// Defaults to 600 milliseconds.
  final Duration detectionWindow;

  /// Minimum horizontal pointer speed, in logical pixels per second, for a
  /// direction change to count as a reversal. Defaults to 600.
  final double velocityThreshold;

  /// Minimum time between two shake detections.
  /// Defaults to 500 milliseconds.
  final Duration cooldown;

  /// Duration of the shake animation. Defaults to 400 milliseconds.
  final Duration duration;

  /// Horizontal travel of the shake animation in logical pixels.
  /// Defaults to 8.
  final double intensity;

  /// Whether a heavy haptic impact plays when a shake is detected.
  /// Defaults to `true`.
  final bool enableHaptics;

  /// When `false`, gestures and controller triggers are ignored.
  final bool enabled;

  @override
  State<ShakeToAction> createState() => _ShakeToActionState();
}

class _ShakeToActionState extends State<ShakeToAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  DateTime? _lastTriggerTime;

  // Gesture heuristic state.
  int _lastDeltaSign = 0;
  DateTime? _lastMoveTime;
  final List<DateTime> _reversalTimes = <DateTime>[];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    widget.controller?.addListener(_onControllerShake);
  }

  @override
  void didUpdateWidget(ShakeToAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerShake);
      widget.controller?.addListener(_onControllerShake);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerShake);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerShake() {
    if (widget.enabled) {
      _trigger();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }
    final DateTime now = DateTime.now();
    final double dx = details.delta.dx;
    if (dx == 0) {
      return;
    }

    // Estimate horizontal speed from the time between pointer updates.
    double speed = double.infinity;
    if (_lastMoveTime != null) {
      final int elapsedMicros = now.difference(_lastMoveTime!).inMicroseconds;
      if (elapsedMicros > 0) {
        speed = dx.abs() /
            (elapsedMicros / Duration.microsecondsPerSecond);
      }
    }
    _lastMoveTime = now;

    final int sign = dx.sign.toInt();
    final bool reversed = _lastDeltaSign != 0 && sign != _lastDeltaSign;
    _lastDeltaSign = sign;

    if (reversed && speed >= widget.velocityThreshold) {
      _reversalTimes.add(now);
      _reversalTimes.removeWhere(
          (DateTime t) => now.difference(t) > widget.detectionWindow);
      if (_reversalTimes.length >= widget.requiredReversals) {
        _reversalTimes.clear();
        _trigger();
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _lastDeltaSign = 0;
    _lastMoveTime = null;
    _reversalTimes.clear();
  }

  void _trigger() {
    final DateTime now = DateTime.now();
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!) < widget.cooldown) {
      return;
    }
    _lastTriggerTime = now;

    if (widget.enableHaptics) {
      // Fire and forget; never delays the animation or callback.
      HapticFeedback.heavyImpact();
    }
    widget.onShake();

    if (!MicroMotion.isReduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
      child: _ShakeTransform(
        animation: _controller,
        intensity: widget.intensity,
        child: widget.child,
      ),
    );
  }
}

/// Applies a damped horizontal shake driven by [animation] to [child].
class _ShakeTransform extends StatelessWidget {
  const _ShakeTransform({
    required this.animation,
    required this.intensity,
    required this.child,
  });

  final Animation<double> animation;
  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final double t = animation.value;
        // Damped sine: fast oscillation that dies out towards the end.
        final double offset = math.sin(t * math.pi * 6) * intensity * (1 - t);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
    );
  }
}

/// Plays a horizontal shake animation on demand.
///
/// The animation is triggered through a [ShakeController]:
///
/// ```dart
/// final controller = ShakeController();
/// // ...
/// ShakeAnimation(
///   controller: controller,
///   child: const TextField(),
/// );
/// // on validation error:
/// controller.shake();
/// ```
///
/// Under reduced motion the widget renders its child without translating it.
class ShakeAnimation extends StatefulWidget {
  /// Creates a shake animation widget.
  const ShakeAnimation({
    super.key,
    required this.child,
    this.controller,
    this.duration = const Duration(milliseconds: 400),
    this.intensity = 8.0,
    this.enabled = true,
  }) : assert(intensity >= 0, 'intensity must not be negative');

  /// The widget to shake.
  final Widget child;

  /// Controller whose [ShakeController.shake] plays the animation.
  final ShakeController? controller;

  /// Duration of one shake. Defaults to 400 milliseconds.
  final Duration duration;

  /// Horizontal travel of the shake in logical pixels. Defaults to 8.
  final double intensity;

  /// When `false`, controller triggers are ignored.
  final bool enabled;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    widget.controller?.addListener(_onShake);
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onShake);
      widget.controller?.addListener(_onShake);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onShake);
    _controller.dispose();
    super.dispose();
  }

  void _onShake() {
    if (!widget.enabled) {
      return;
    }
    if (MicroMotion.isReduced(context)) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return _ShakeTransform(
      animation: _controller,
      intensity: widget.intensity,
      child: widget.child,
    );
  }
}

/// Builds a button-like widget that shakes when pressed while invalid.
///
/// The [builder] receives a callback to wire into the actual button. When
/// pressed and [isValid] is `true`, [onPressed] runs. When pressed and
/// [isValid] is `false`, the child shakes and [onInvalidPress] runs.
///
/// ```dart
/// ShakeButton(
///   isValid: form.isComplete,
///   onPressed: submit,
///   onInvalidPress: showValidationHint,
///   builder: (context, handlePressed) => ElevatedButton(
///     onPressed: handlePressed,
///     child: const Text('Submit'),
///   ),
/// )
/// ```
///
/// The invalid state is conveyed to assistive technology through
/// `Semantics(enabled: false)`.
class ShakeButton extends StatefulWidget {
  /// Creates a shake button.
  const ShakeButton({
    super.key,
    required this.builder,
    this.onPressed,
    this.onInvalidPress,
    this.isValid = true,
    this.intensity = 8.0,
    this.duration = const Duration(milliseconds: 400),
    this.enableHaptics = true,
    this.enabled = true,
  }) : assert(intensity >= 0, 'intensity must not be negative');

  /// Builds the button. The provided callback must be used as the button's
  /// press handler so the shake logic can run.
  final Widget Function(BuildContext context, VoidCallback handlePressed)
      builder;

  /// Called when the button is pressed while [isValid] is `true`.
  final VoidCallback? onPressed;

  /// Called when the button is pressed while [isValid] is `false`.
  final VoidCallback? onInvalidPress;

  /// Whether pressing the button runs [onPressed] instead of shaking.
  final bool isValid;

  /// Horizontal travel of the shake in logical pixels. Defaults to 8.
  final double intensity;

  /// Duration of the shake. Defaults to 400 milliseconds.
  final Duration duration;

  /// Whether an error haptic plays on an invalid press. Defaults to `true`.
  final bool enableHaptics;

  /// When `false`, presses are ignored entirely.
  final bool enabled;

  @override
  State<ShakeButton> createState() => _ShakeButtonState();
}

class _ShakeButtonState extends State<ShakeButton> {
  final ShakeController _shakeController = ShakeController();

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (!widget.enabled) {
      return;
    }
    if (widget.isValid) {
      widget.onPressed?.call();
    } else {
      if (widget.enableHaptics) {
        // Fire and forget; never delays the animation or callback.
        HapticFeedback.vibrate();
      }
      _shakeController.shake();
      widget.onInvalidPress?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: widget.enabled && widget.isValid,
      child: ShakeAnimation(
        controller: _shakeController,
        intensity: widget.intensity,
        duration: widget.duration,
        enabled: widget.enabled,
        child: widget.builder(context, _handlePressed),
      ),
    );
  }
}
