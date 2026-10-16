import 'dart:async';

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Text with a soft band of light that sweeps across its glyphs, the
/// classic "Thinking..." look of AI assistants.
///
/// ```dart
/// ShimmerText(
///   'Thinking...',
///   style: Theme.of(context).textTheme.titleMedium,
/// )
/// ```
///
/// The text is painted in [baseColor] and a [highlightColor] band slides
/// across it, pauses for [interval], then slides again. The sweep follows
/// the ambient [Directionality]. Use [ShimmerText.child] to apply the same
/// sweep to any widget, such as an icon next to the label.
///
/// The glyphs are untouched for assistive technology: screen readers read
/// the text normally. Under reduced motion, or when [enabled] is false,
/// the text renders statically in [baseColor].
class ShimmerText extends StatefulWidget {
  /// Creates shimmering text.
  const ShimmerText(
    String this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1600),
    this.interval = Duration.zero,
    this.curve = Curves.easeInOut,
    this.bandWidth = 0.35,
    this.enabled = true,
  }) : child = null,
       assert(
         bandWidth > 0 && bandWidth <= 1,
         'bandWidth must be in the range (0, 1]',
       );

  /// Applies the shimmer sweep to an arbitrary [child].
  ///
  /// The child should paint opaque pixels where the sweep must show, for
  /// example text or icons. Its own colors are replaced by the shimmer.
  const ShimmerText.child({
    super.key,
    required Widget this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1600),
    this.interval = Duration.zero,
    this.curve = Curves.easeInOut,
    this.bandWidth = 0.35,
    this.enabled = true,
  }) : text = null,
       style = null,
       textAlign = null,
       maxLines = null,
       overflow = null,
       assert(
         bandWidth > 0 && bandWidth <= 1,
         'bandWidth must be in the range (0, 1]',
       );

  /// The text to display. Null when using [ShimmerText.child].
  final String? text;

  /// The widget to shimmer. Null when using the default constructor.
  final Widget? child;

  /// Style of the text. Its color is ignored; use [baseColor] instead.
  final TextStyle? style;

  /// How the text is aligned horizontally.
  final TextAlign? textAlign;

  /// Maximum number of lines for the text.
  final int? maxLines;

  /// How visual overflow is handled.
  final TextOverflow? overflow;

  /// Resting color of the glyphs. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant` at 70 percent alpha.
  final Color? baseColor;

  /// Color at the center of the moving band. Defaults to the theme's
  /// `colorScheme.onSurface`.
  final Color? highlightColor;

  /// Length of one sweep. Defaults to 1600 milliseconds.
  final Duration duration;

  /// Pause between two sweeps. Defaults to no pause.
  final Duration interval;

  /// Curve applied to each sweep. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Width of the highlight band as a fraction of the widget width, in the
  /// range (0, 1]. Defaults to 0.35.
  final double bandWidth;

  /// When false the text renders statically in [baseColor].
  final bool enabled;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _sweep;
  Timer? _intervalTimer;
  bool _reducedMotion = false;

  bool get _animating => widget.enabled && !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
    _sweep = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(ShimmerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _sweep.dispose();
      _sweep = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.enabled != oldWidget.enabled) {
      _sync();
    }
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    _sweep.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_animating) {
      _intervalTimer?.cancel();
      _intervalTimer = null;
      _controller
        ..stop()
        ..value = 0.0;
      return;
    }
    if (!_controller.isAnimating && _intervalTimer == null) {
      _controller.forward(from: 0.0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.interval == Duration.zero) {
      _controller.forward(from: 0.0);
      return;
    }
    _intervalTimer?.cancel();
    _intervalTimer = Timer(widget.interval, () {
      _intervalTimer = null;
      if (mounted && _animating) {
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base =
        widget.baseColor ?? scheme.onSurfaceVariant.withValues(alpha: 0.7);
    final Color highlight = widget.highlightColor ?? scheme.onSurface;

    final Widget content =
        widget.child ??
        Text(
          widget.text!,
          style: (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
            color: base,
          ),
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );

    if (!_animating) {
      if (widget.child == null) return content;
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) =>
            LinearGradient(colors: <Color>[base, base]).createShader(bounds),
        child: content,
      );
    }

    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double half = widget.bandWidth / 2;
    return AnimatedBuilder(
      animation: _sweep,
      child: content,
      builder: (BuildContext context, Widget? child) {
        // The band center travels from just outside one edge to just
        // outside the other, so each sweep starts and ends fully dimmed.
        final double t = rtl ? 1 - _sweep.value : _sweep.value;
        final double center = -half + t * (1 + widget.bandWidth);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          // The gradient keeps stable stops and is shifted horizontally;
          // clamping paints [base] everywhere outside the band.
          shaderCallback: (Rect bounds) =>
              LinearGradient(
                colors: <Color>[base, highlight, base],
                stops: <double>[0.5 - half, 0.5, 0.5 + half],
              ).createShader(
                bounds.shift(Offset((center - 0.5) * bounds.width, 0)),
              ),
          child: child,
        );
      },
    );
  }
}
