import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// The visual effect played by [TapFeedback] when the child is pressed.
enum TapAnimationType {
  /// Scale down while pressed, scale back on release.
  scale,

  /// Scale down while pressed, overshoot slightly on release before
  /// settling back to the resting size.
  bounce,

  /// Fade to a lower opacity while pressed.
  fade,

  /// Scale down and fade at the same time while pressed.
  scaleAndFade,
}

/// Wraps any widget and plays a short visual feedback animation on tap.
///
/// The effect is chosen with [effect] (see [TapAnimationType]). The widget
/// is exposed to assistive technology as a button and can be activated with
/// the keyboard (Enter or Space) when focused.
///
/// [onTap] fires immediately on tap-up; it never waits for animations.
///
/// The gesture detector uses [HitTestBehavior.opaque] so the whole child
/// area is tappable, including transparent regions. Interactive children
/// (for example an [ElevatedButton]) still receive their own tap events
/// because they sit deeper in the hit-test order; in that case prefer
/// leaving [onTap] null here and keeping the child's own callback.
///
/// When the platform requests reduced motion no animation is played, but
/// taps, haptics and callbacks still work.
///
/// Example:
/// ```dart
/// TapFeedback.scale(
///   onTap: () => debugPrint('Tapped!'),
///   child: const Card(child: Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Tap me'),
///   )),
/// )
/// ```
class TapFeedback extends StatefulWidget {
  /// Creates a tap feedback widget.
  const TapFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.effect = TapAnimationType.scale,
    this.scaleDown = 0.95,
    this.scaleUp = 1.05,
    this.opacity = 0.8,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeInOut,
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(scaleDown > 0 && scaleDown <= 1.0, 'scaleDown must be in (0, 1]'),
       assert(scaleUp >= 1.0, 'scaleUp must be >= 1.0'),
       assert(opacity >= 0 && opacity <= 1.0, 'opacity must be in [0, 1]');

  /// The widget below this widget in the tree.
  final Widget child;

  /// Called immediately when a tap completes (on tap-up) or when the
  /// widget is activated with the keyboard.
  final VoidCallback? onTap;

  /// Which feedback animation to play.
  final TapAnimationType effect;

  /// Scale factor while pressed. Must be in `(0, 1]`.
  ///
  /// Used by [TapAnimationType.scale], [TapAnimationType.bounce] and
  /// [TapAnimationType.scaleAndFade].
  final double scaleDown;

  /// Overshoot scale factor for [TapAnimationType.bounce]. Must be `>= 1.0`.
  final double scaleUp;

  /// Opacity while pressed, in `[0, 1]`.
  ///
  /// Used by [TapAnimationType.fade] and [TapAnimationType.scaleAndFade].
  final double opacity;

  /// Length of the press animation. Defaults to 150 milliseconds.
  final Duration duration;

  /// Curve applied to the press animation. Defaults to [Curves.easeInOut].
  ///
  /// The bounce release always uses an ease-out sequence regardless of
  /// this value.
  final Curve curve;

  /// Whether a light haptic impact is triggered on press.
  final bool enableHaptics;

  /// Whether the feedback is active.
  ///
  /// When false the child is rendered unchanged and no gestures, haptics
  /// or callbacks fire.
  final bool enabled;

  /// Optional semantic label announced for the button.
  final String? semanticLabel;

  /// A plain scale-down feedback, the most common press effect.
  static Widget scale({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double scale = 0.95,
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeInOut,
    bool enableHaptics = true,
    bool enabled = true,
  }) {
    return TapFeedback(
      key: key,
      onTap: onTap,
      scaleDown: scale,
      duration: duration,
      curve: curve,
      enableHaptics: enableHaptics,
      enabled: enabled,
      child: child,
    );
  }

  /// A scale feedback that overshoots slightly on release for a bouncy feel.
  static Widget bounce({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double scaleDown = 0.95,
    double scaleUp = 1.02,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
    bool enableHaptics = true,
    bool enabled = true,
  }) {
    return TapFeedback(
      key: key,
      onTap: onTap,
      effect: TapAnimationType.bounce,
      scaleDown: scaleDown,
      scaleUp: scaleUp,
      duration: duration,
      curve: curve,
      enableHaptics: enableHaptics,
      enabled: enabled,
      child: child,
    );
  }

  /// An opacity-only feedback; the child dims while pressed.
  static Widget fade({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double opacity = 0.7,
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeInOut,
    bool enableHaptics = true,
    bool enabled = true,
  }) {
    return TapFeedback(
      key: key,
      onTap: onTap,
      effect: TapAnimationType.fade,
      opacity: opacity,
      duration: duration,
      curve: curve,
      enableHaptics: enableHaptics,
      enabled: enabled,
      child: child,
    );
  }

  /// A combined scale and opacity feedback.
  static Widget scaleAndOpacity({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double scale = 0.95,
    double opacity = 0.8,
    Duration duration = const Duration(milliseconds: 150),
    Curve curve = Curves.easeInOut,
    bool enableHaptics = true,
    bool enabled = true,
  }) {
    return TapFeedback(
      key: key,
      onTap: onTap,
      effect: TapAnimationType.scaleAndFade,
      scaleDown: scale,
      opacity: opacity,
      duration: duration,
      curve: curve,
      enableHaptics: enableHaptics,
      enabled: enabled,
      child: child,
    );
  }

  @override
  State<TapFeedback> createState() => _TapFeedbackState();
}

class _TapFeedbackState extends State<TapFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ProxyAnimation _scale;
  late final ProxyAnimation _opacity;

  /// Cached reduce-motion flag, updated in [didChangeDependencies] so that
  /// gesture callbacks arriving during tree teardown (for example a tap
  /// cancel while the widget is being removed) never look up an inherited
  /// widget on a deactivated element.
  bool _reducedMotion = false;

  bool get _usesScale =>
      widget.effect == TapAnimationType.scale ||
      widget.effect == TapAnimationType.bounce ||
      widget.effect == TapAnimationType.scaleAndFade;

  bool get _usesOpacity =>
      widget.effect == TapAnimationType.fade ||
      widget.effect == TapAnimationType.scaleAndFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = ProxyAnimation(const AlwaysStoppedAnimation<double>(1.0));
    _opacity = ProxyAnimation(const AlwaysStoppedAnimation<double>(1.0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
  }

  @override
  void didUpdateWidget(TapFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _scale.parent = const AlwaysStoppedAnimation<double>(1.0);
      _opacity.parent = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animatable<double> _pressScaleTween() => Tween<double>(
    begin: 1.0,
    end: widget.scaleDown,
  ).chain(CurveTween(curve: widget.curve));

  Animatable<double> _pressOpacityTween() => Tween<double>(
    begin: 1.0,
    end: widget.opacity,
  ).chain(CurveTween(curve: widget.curve));

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    if (MicroMotion.isReduced(context)) return;
    if (_usesScale) {
      _scale.parent = _controller.drive(_pressScaleTween());
    }
    if (_usesOpacity) {
      _opacity.parent = _controller.drive(_pressOpacityTween());
    }
    _controller.forward(from: 0.0);
  }

  void _release() {
    if (!mounted || _reducedMotion) return;
    if (widget.effect == TapAnimationType.bounce) {
      // Play the bounce sequence forward from the pressed scale.
      _scale.parent = _controller.drive(
        TweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: widget.scaleDown,
              end: widget.scaleUp,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 55,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: widget.scaleUp,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 45,
          ),
        ]),
      );
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    // Fire immediately; never wait for animations.
    widget.onTap?.call();
    _release();
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    _release();
  }

  void _activateFromKeyboard() {
    if (!widget.enabled) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
    if (MicroMotion.isReduced(context)) return;
    // Play a quick press-and-release so keyboard users get feedback too.
    if (_usesScale && widget.effect != TapAnimationType.bounce) {
      _scale.parent = _controller.drive(_pressScaleTween());
    }
    if (_usesOpacity) {
      _opacity.parent = _controller.drive(_pressOpacityTween());
    }
    if (widget.effect == TapAnimationType.bounce) {
      _scale.parent = _controller.drive(
        TweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 1.0,
              end: widget.scaleDown,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 30,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: widget.scaleDown,
              end: widget.scaleUp,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 40,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: widget.scaleUp,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 30,
          ),
        ]),
      );
      _controller.forward(from: 0.0);
    } else {
      _controller.forward(from: 0.0).then((_) {
        if (mounted) _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (_usesScale) {
      child = ScaleTransition(scale: _scale, child: child);
    }
    if (_usesOpacity) {
      child = FadeTransition(opacity: _opacity, child: child);
    }

    if (!widget.enabled) {
      return child;
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateFromKeyboard();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
      ),
    );
  }
}
