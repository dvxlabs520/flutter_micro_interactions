import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Gently scales and lifts its child when a descendant gains focus.
///
/// Wrap a text field (or any focusable widget) to give it a subtle
/// emphasis animation while it is being edited. The wrapper itself never
/// takes focus and is skipped by keyboard traversal; it only listens to
/// focus changes of its descendants.
///
/// At rest the child renders completely unchanged: the elevation is zero
/// and the backing [Material] uses a fully transparent color.
///
/// When the platform requests reduced motion the emphasis switches
/// instantly instead of animating.
///
/// ```dart
/// InputFocus(
///   child: TextField(
///     decoration: InputDecoration(labelText: 'Email'),
///   ),
/// )
/// ```
class InputFocus extends StatefulWidget {
  /// Creates an input focus widget.
  const InputFocus({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
    this.scale = 1.02,
    this.elevation = 4.0,
    this.borderRadius,
    this.shadowColor,
    this.focusNode,
    this.onFocusChange,
    this.enabled = true,
  }) : assert(scale > 0, 'scale must be positive'),
       assert(elevation >= 0, 'elevation must not be negative');

  /// The widget to animate, typically a text field.
  final Widget child;

  /// Length of the focus animation. Defaults to 200 milliseconds.
  final Duration duration;

  /// Curve of the focus animation. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Scale factor while focused. Defaults to 1.02.
  final double scale;

  /// Shadow elevation while focused. Defaults to 4.0. Set to 0 to keep
  /// only the scale effect.
  final double elevation;

  /// Corner rounding used for the focused shadow. When null no rounding
  /// is applied.
  final BorderRadius? borderRadius;

  /// Color of the focused shadow. Defaults to the theme's shadow color.
  final Color? shadowColor;

  /// Optional focus node for the listening wrapper. When provided the
  /// caller owns and disposes it; this widget only listens.
  final FocusNode? focusNode;

  /// Called with the new focus state whenever it changes.
  final ValueChanged<bool>? onFocusChange;

  /// Whether the animation is active. When false the child renders
  /// unchanged.
  final bool enabled;

  /// Convenience wrapper with the same defaults as the constructor.
  static Widget animate({
    Key? key,
    required Widget child,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
    double scale = 1.02,
    double elevation = 4.0,
    BorderRadius? borderRadius,
    Color? shadowColor,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    bool enabled = true,
  }) {
    return InputFocus(
      key: key,
      duration: duration,
      curve: curve,
      scale: scale,
      elevation: elevation,
      borderRadius: borderRadius,
      shadowColor: shadowColor,
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      enabled: enabled,
      child: child,
    );
  }

  @override
  State<InputFocus> createState() => _InputFocusState();
}

class _InputFocusState extends State<InputFocus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(_animation);
  }

  @override
  void didUpdateWidget(InputFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve || widget.scale != oldWidget.scale) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.scale,
      ).animate(_animation);
    }
    if (!widget.enabled && oldWidget.enabled) {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged(bool hasFocus) {
    if (!mounted) return;
    if (MicroMotion.isReduced(context)) {
      _controller.value = hasFocus ? 1.0 : 0.0;
    } else if (hasFocus) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onFocusChange?.call(hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _handleFocusChanged,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              elevation: widget.elevation * _animation.value,
              shadowColor: widget.shadowColor,
              borderRadius: widget.borderRadius,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
