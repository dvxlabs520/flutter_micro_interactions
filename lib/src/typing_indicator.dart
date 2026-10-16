import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// How the dots of a [TypingIndicator] move.
enum TypingIndicatorStyle {
  /// Each dot hops up and back down in turn.
  bounce,

  /// Each dot brightens and grows slightly in turn.
  pulse,

  /// The dots rise and fall together along a smooth wave.
  wave,
}

/// Animated dots that signal that someone, or an AI assistant, is typing
/// a reply.
///
/// ```dart
/// const TypingIndicator()
/// ```
///
/// The dots animate in sequence on a single looping controller. Place the
/// indicator inside a chat bubble, or use it alone next to an avatar.
///
/// Accessibility: the indicator is exposed with [semanticLabel] (defaults
/// to "Typing") so screen readers can announce it. Under reduced motion,
/// or when [enabled] is false, the dots render statically.
class TypingIndicator extends StatefulWidget {
  /// Creates a typing indicator.
  const TypingIndicator({
    super.key,
    this.style = TypingIndicatorStyle.bounce,
    this.dotCount = 3,
    this.dotSize = 8.0,
    this.spacing = 4.0,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
    this.travel,
    this.enabled = true,
    this.semanticLabel = 'Typing',
  }) : assert(dotCount > 0, 'dotCount must be positive'),
       assert(dotSize > 0, 'dotSize must be positive'),
       assert(spacing >= 0, 'spacing must not be negative');

  /// How the dots move. Defaults to [TypingIndicatorStyle.bounce].
  final TypingIndicatorStyle style;

  /// Number of dots. Defaults to 3.
  final int dotCount;

  /// Diameter of each dot. Defaults to 8.
  final double dotSize;

  /// Gap between dots. Defaults to 4.
  final double spacing;

  /// Color of the dots. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant`.
  final Color? color;

  /// Length of one full cycle across all dots. Defaults to 1200
  /// milliseconds.
  final Duration duration;

  /// How far a dot moves up in the bounce and wave styles. Defaults to
  /// half of [dotSize].
  final double? travel;

  /// When false the dots render statically.
  final bool enabled;

  /// Label announced by screen readers. Defaults to "Typing".
  final String? semanticLabel;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..repeat();
      }
    }
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    final bool play = widget.enabled && !MicroMotion.isReduced(context);
    if (play && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!play && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final double travel = widget.travel ?? widget.dotSize / 2;
    final bool movesVertically = widget.style != TypingIndicatorStyle.pulse;
    final double width =
        widget.dotCount * widget.dotSize +
        (widget.dotCount - 1) * widget.spacing;
    final double height = widget.dotSize + (movesVertically ? travel : 0);

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: widget.semanticLabel != null,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(width, height),
            painter: _TypingDotsPainter(
              progress: _controller,
              style: widget.style,
              count: widget.dotCount,
              dotSize: widget.dotSize,
              spacing: widget.spacing,
              travel: travel,
              color: color,
              animating: _controller.isAnimating,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDotsPainter extends CustomPainter {
  _TypingDotsPainter({
    required this.progress,
    required this.style,
    required this.count,
    required this.dotSize,
    required this.spacing,
    required this.travel,
    required this.color,
    required this.animating,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final TypingIndicatorStyle style;
  final int count;
  final double dotSize;
  final double spacing;
  final double travel;
  final Color color;
  final bool animating;

  /// A 0..1..0 bump for dot [index] at time [t], active during the part of
  /// the cycle that belongs to that dot.
  double _bump(double t, int index) {
    // Every dot gets an equal slot; the bump spans two slots so neighbors
    // overlap a little, which reads as a smooth chain.
    final double slot = 1 / (count + 1);
    final double local = (t - index * slot) / (2 * slot);
    if (local <= 0 || local >= 1) return 0;
    return math.sin(local * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double radius = dotSize / 2;
    final double restY = size.height - radius;
    final Paint paint = Paint();

    for (int i = 0; i < count; i++) {
      final double x = radius + i * (dotSize + spacing);
      double y = restY;
      double scale = 1;
      double opacity = 1;

      if (animating) {
        switch (style) {
          case TypingIndicatorStyle.bounce:
            final double b = _bump(t, i);
            y -= b * travel;
            opacity = 0.5 + 0.5 * b;
          case TypingIndicatorStyle.pulse:
            final double b = _bump(t, i);
            scale = 0.75 + 0.25 * b;
            opacity = 0.35 + 0.65 * b;
          case TypingIndicatorStyle.wave:
            final double phase = 2 * math.pi * (t - i / count);
            final double w = (math.sin(phase) + 1) / 2;
            y -= w * travel;
            opacity = 0.5 + 0.5 * w;
        }
      } else if (style == TypingIndicatorStyle.pulse) {
        opacity = 0.6;
      }

      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawCircle(Offset(x, y), radius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TypingDotsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.style != style ||
        oldDelegate.count != count ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.spacing != spacing ||
        oldDelegate.travel != travel ||
        oldDelegate.color != color ||
        oldDelegate.animating != animating;
  }
}
