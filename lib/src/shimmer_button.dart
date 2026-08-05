import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A button with a periodic shimmer sweep across its surface, meant for
/// primary calls to action.
///
/// ```dart
/// ShimmerButton(
///   onPressed: () => debugPrint('Pressed!'),
///   child: const Text('Get started'),
/// )
/// ```
///
/// A diagonal highlight band sweeps across the button, pauses for
/// [shimmerInterval], then sweeps again. The sweep direction follows the
/// ambient [Directionality]. Pressing scales the button down slightly;
/// [onPressed] fires immediately on tap-up and never waits for animations.
///
/// The button is exposed to assistive technology as a button and can be
/// activated with the keyboard (Enter or Space) when focused; keyboard
/// focus shows a visible highlight border.
///
/// When [onPressed] is null or [enabled] is false the button renders in a
/// dimmed disabled style with no shimmer and no press feedback. Under
/// reduced motion the shimmer never runs and the press feedback is
/// skipped, but the button stays fully functional.
class ShimmerButton extends StatefulWidget {
  /// Creates a shimmer button.
  const ShimmerButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.shimmerColor,
    this.shimmerDuration = const Duration(milliseconds: 2200),
    this.shimmerInterval = const Duration(milliseconds: 1200),
    this.pressDuration = const Duration(milliseconds: 120),
    this.curve = Curves.easeInOut,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.elevation = 0,
    this.enableHaptics = false,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(elevation >= 0, 'elevation must not be negative');

  /// The content of the button, typically a [Text].
  final Widget child;

  /// Called immediately on tap-up or keyboard activation. When null the
  /// button renders disabled.
  final VoidCallback? onPressed;

  /// Background color of the button. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? backgroundColor;

  /// Color of the shimmer highlight band. Defaults to the theme's
  /// `colorScheme.onPrimary` at 35 percent alpha.
  final Color? shimmerColor;

  /// Length of one shimmer sweep. Defaults to 2200 milliseconds.
  final Duration shimmerDuration;

  /// Pause between two consecutive sweeps. Defaults to 1200 milliseconds.
  final Duration shimmerInterval;

  /// Length of the press scale animation. Defaults to 120 milliseconds.
  final Duration pressDuration;

  /// Curve applied to the sweep and press animations. Defaults to
  /// [Curves.easeInOut].
  final Curve curve;

  /// Corner radius of the button surface. Defaults to a 12 pixel circular
  /// radius on all corners.
  final BorderRadius borderRadius;

  /// Padding around [child]. Defaults to 24 horizontal by 14 vertical.
  final EdgeInsetsGeometry padding;

  /// Elevation of the button surface. Defaults to 0.
  final double elevation;

  /// Whether a light haptic impact is triggered on press. Defaults to
  /// false.
  final bool enableHaptics;

  /// When false the button renders disabled, exactly as if [onPressed]
  /// were null.
  final bool enabled;

  /// Optional semantic label announced for the button.
  final String? semanticLabel;

  @override
  State<ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<ShimmerButton>
    with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _pressController;
  late CurvedAnimation _sweepAnimation;
  late CurvedAnimation _pressAnimation;
  Timer? _intervalTimer;
  bool _focused = false;

  /// Cached reduce-motion flag, refreshed in [didChangeDependencies].
  bool _reducedMotion = false;

  /// Scale of the button while pressed.
  static const double _pressedScale = 0.96;

  /// Opacity of the whole button when disabled.
  static const double _disabledOpacity = 0.5;

  /// Width of the shimmer band as a fraction of the button width.
  static const double _bandWidthFactor = 0.45;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _sweepController =
        AnimationController(vsync: this, duration: widget.shimmerDuration);
    _pressController =
        AnimationController(vsync: this, duration: widget.pressDuration);
    _sweepAnimation =
        CurvedAnimation(parent: _sweepController, curve: widget.curve);
    _pressAnimation =
        CurvedAnimation(parent: _pressController, curve: widget.curve);
    _sweepController.addStatusListener(_onSweepStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _syncShimmer();
  }

  @override
  void didUpdateWidget(ShimmerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shimmerDuration != oldWidget.shimmerDuration) {
      _sweepController.duration = widget.shimmerDuration;
    }
    if (widget.pressDuration != oldWidget.pressDuration) {
      _pressController.duration = widget.pressDuration;
    }
    if (widget.curve != oldWidget.curve) {
      _sweepAnimation.dispose();
      _pressAnimation.dispose();
      _sweepAnimation =
          CurvedAnimation(parent: _sweepController, curve: widget.curve);
      _pressAnimation =
          CurvedAnimation(parent: _pressController, curve: widget.curve);
    }
    final bool wasInteractive =
        oldWidget.enabled && oldWidget.onPressed != null;
    if (_interactive != wasInteractive) {
      if (!_interactive) {
        _pressController.value = 0.0;
      }
      _syncShimmer();
    }
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    _sweepController.removeStatusListener(_onSweepStatus);
    _sweepAnimation.dispose();
    _pressAnimation.dispose();
    _sweepController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  /// Starts or stops the shimmer loop to match the current state.
  void _syncShimmer() {
    if (!_interactive || _reducedMotion) {
      _intervalTimer?.cancel();
      _intervalTimer = null;
      _sweepController.stop();
      _sweepController.value = 0.0;
      return;
    }
    if (!_sweepController.isAnimating && _intervalTimer == null) {
      _sweepController.forward(from: 0.0);
    }
  }

  void _onSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _sweepController.value = 0.0;
    _intervalTimer?.cancel();
    _intervalTimer = Timer(widget.shimmerInterval, () {
      _intervalTimer = null;
      if (mounted && _interactive && !_reducedMotion) {
        _sweepController.forward(from: 0.0);
      }
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_interactive) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    if (_reducedMotion) return;
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_interactive) return;
    // Fire immediately; never wait for animations.
    widget.onPressed?.call();
    if (!_reducedMotion) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!_interactive || _reducedMotion) return;
    _pressController.reverse();
  }

  void _activateFromKeyboard() {
    if (!_interactive) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
    if (_reducedMotion) return;
    // Play a quick press-and-release so keyboard users get feedback too.
    _pressController.forward().then((_) {
      if (mounted) _pressController.reverse();
    });
  }

  /// The moving highlight band, painted above the button surface.
  Widget _buildShimmerOverlay(BuildContext context, Color shimmerColor) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    // Fractional translation relative to the band's own (full) size: the
    // band starts fully outside one edge and ends outside the other.
    final Animation<Offset> slide = _sweepAnimation.drive(
      Tween<Offset>(
        begin: Offset(rtl ? 1.5 : -1.5, 0),
        end: Offset(rtl ? -1.5 : 1.5, 0),
      ),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: SlideTransition(
              position: slide,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: rtl ? Alignment.topRight : Alignment.topLeft,
                    end: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
                    stops: const <double>[
                      0.5 - _bandWidthFactor / 2,
                      0.5,
                      0.5 + _bandWidthFactor / 2,
                    ],
                    colors: <Color>[
                      shimmerColor.withValues(alpha: 0),
                      shimmerColor,
                      shimmerColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color backgroundColor =
        widget.backgroundColor ?? colorScheme.primary;
    final Color shimmerColor =
        widget.shimmerColor ?? colorScheme.onPrimary.withValues(alpha: 0.35);
    final bool interactive = _interactive;

    Widget surface = Material(
      color: backgroundColor,
      elevation: widget.elevation,
      borderRadius: widget.borderRadius,
      child: Padding(padding: widget.padding, child: widget.child),
    );

    surface = Stack(
      children: <Widget>[
        surface,
        if (interactive && !_reducedMotion)
          _buildShimmerOverlay(context, shimmerColor),
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    surface = ScaleTransition(
      scale: _pressAnimation.drive(
        Tween<double>(begin: 1.0, end: _pressedScale),
      ),
      child: surface,
    );

    if (!interactive) {
      return Semantics(
        button: true,
        enabled: false,
        label: widget.semanticLabel,
        child: Opacity(opacity: _disabledOpacity, child: surface),
      );
    }

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        onShowFocusHighlight: (bool focused) {
          if (focused != _focused) {
            setState(() => _focused = focused);
          }
        },
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
          child: surface,
        ),
      ),
    );
  }
}
