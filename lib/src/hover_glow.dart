import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Adds an animated glow around its child on mouse hover or keyboard focus.
///
/// The glow fades in when the pointer enters (or the widget subtree gains
/// focus) and fades out when it leaves, driven entirely by the animation
/// value so the exit fade is smooth. Colors default to the theme's
/// `colorScheme.primary`.
///
/// When the platform requests reduced motion the glow switches instantly
/// instead of animating.
///
/// HoverGlow adds no focus stop of its own: keyboard focus glow appears
/// while a focusable descendant (for example a button passed as [child])
/// has focus. Wrapping a non-focusable child gives a hover-only glow.
///
/// ```dart
/// HoverGlow(
///   borderRadius: BorderRadius.circular(12),
///   child: const Card(child: Padding(
///     padding: EdgeInsets.all(24),
///     child: Text('Hover me'),
///   )),
/// )
/// ```
class HoverGlow extends StatefulWidget {
  /// Creates a hover glow widget.
  const HoverGlow({
    super.key,
    required this.child,
    this.glowColor,
    this.glowRadius = 12.0,
    this.spreadRadius = 4.0,
    this.glowOpacity = 0.5,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
    this.onHoverChanged,
    this.enabled = true,
  }) : assert(glowRadius >= 0, 'glowRadius must not be negative'),
       assert(spreadRadius >= 0, 'spreadRadius must not be negative'),
       assert(
         glowOpacity >= 0 && glowOpacity <= 1.0,
         'glowOpacity must be in [0, 1]',
       );

  /// The widget that receives the glow.
  final Widget child;

  /// Color of the glow. Defaults to the theme's `colorScheme.primary`.
  final Color? glowColor;

  /// Blur radius of the glow shadow at full strength.
  final double glowRadius;

  /// Spread radius of the glow shadow at full strength.
  final double spreadRadius;

  /// Peak opacity of the glow, in `[0, 1]`.
  final double glowOpacity;

  /// Corner rounding of the glow shape. When null the glow follows a
  /// rectangular outline.
  final BorderRadius? borderRadius;

  /// Length of the fade animation. Defaults to 200 milliseconds.
  final Duration duration;

  /// Curve of the fade animation. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Called when the hover state changes.
  final ValueChanged<bool>? onHoverChanged;

  /// Whether the glow reacts to hover and focus. When false the child
  /// renders unchanged.
  final bool enabled;

  @override
  State<HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<HoverGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;
  bool _hovered = false;
  bool _focused = false;

  /// The node of the internal focus detector. It can never take focus and
  /// is skipped by traversal, so HoverGlow adds no Tab stop of its own; it
  /// only reports when a focusable descendant gains or loses focus.
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'HoverGlow',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didUpdateWidget(HoverGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (!widget.enabled && oldWidget.enabled) {
      _hovered = false;
      _focused = false;
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateGlow() {
    final bool active = _hovered || _focused;
    if (MicroMotion.isReduced(context)) {
      _controller.value = active ? 1.0 : 0.0;
    } else if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleHoverHighlight(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    _updateGlow();
    widget.onHoverChanged?.call(hovered);
  }

  void _handleFocusHighlight(bool focused) {
    if (_focused == focused) return;
    _focused = focused;
    _updateGlow();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final Color color =
        widget.glowColor ?? Theme.of(context).colorScheme.primary;
    return FocusableActionDetector(
      focusNode: _focusNode,
      onShowHoverHighlight: _handleHoverHighlight,
      onShowFocusHighlight: _handleFocusHighlight,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          final double t = _animation.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: t == 0.0
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: widget.glowOpacity * t),
                        blurRadius: widget.glowRadius * t,
                        spreadRadius: widget.spreadRadius * t,
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
