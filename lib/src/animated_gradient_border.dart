import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Programmatic control for an [AnimatedGradientBorder] widget.
///
/// ```dart
/// final controller = AnimatedGradientBorderController();
/// // ...
/// AnimatedGradientBorder(
///   controller: controller,
///   autoPlay: false,
///   child: const Card(child: Text('Featured')),
/// );
/// // later:
/// controller.start();
/// controller.stop();
/// ```
///
/// [isPlaying] reflects whether the attached border is currently
/// animating; it also turns `false` when the widget stops itself (reduced
/// motion, `enabled: false`). Dispose the controller yourself when it is
/// no longer needed.
class AnimatedGradientBorderController extends ChangeNotifier {
  bool _isPlaying = false;

  /// Whether the attached [AnimatedGradientBorder] is currently animating.
  bool get isPlaying => _isPlaying;

  /// Starts (or resumes) the sweep animation.
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    notifyListeners();
  }

  /// Stops the sweep animation.
  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }
}

/// An animated sweeping gradient border around any child.
///
/// A rounded-rectangle border stroked with a [SweepGradient] rotates
/// around the child, which suits highlighted cards, buttons or avatars:
///
/// ```dart
/// AnimatedGradientBorder(
///   borderWidth: 3,
///   glowRadius: 6,
///   child: const Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Featured'),
///   ),
/// )
/// ```
///
/// The gradient renders seamlessly: when the first and last entries of
/// [colors] differ, the first color is appended internally so the sweep
/// has no visible seam. The child is clipped to the inner radius and sits
/// on [backgroundColor].
///
/// The border is decorative and adds no semantics; the child's semantics
/// are untouched. Under reduced motion the border renders statically and
/// never animates.
class AnimatedGradientBorder extends StatefulWidget {
  /// Creates an animated gradient border around [child].
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.colors,
    this.borderWidth = 2.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.duration = const Duration(seconds: 3),
    this.curve = Curves.linear,
    this.autoPlay = true,
    this.controller,
    this.padding,
    this.backgroundColor,
    this.glowRadius = 0.0,
    this.enabled = true,
  })  : assert(borderWidth >= 0, 'borderWidth must not be negative'),
        assert(glowRadius >= 0, 'glowRadius must not be negative');

  /// The widget surrounded by the border.
  final Widget child;

  /// Colors of the sweep gradient. Defaults to
  /// `[colorScheme.primary, colorScheme.tertiary, colorScheme.primary]`.
  /// When the first and last colors differ, the first color is appended
  /// internally so the gradient wraps without a seam.
  final List<Color>? colors;

  /// Thickness of the border stroke. Defaults to 2.
  final double borderWidth;

  /// Corner rounding of the border. Defaults to a 12 pixel circular
  /// radius.
  final BorderRadius borderRadius;

  /// Duration of one full rotation of the gradient. Defaults to 3
  /// seconds.
  final Duration duration;

  /// Curve applied to each rotation cycle. Defaults to [Curves.linear].
  final Curve curve;

  /// Whether the sweep starts on its own. Ignored under reduced motion.
  /// Defaults to `true`.
  final bool autoPlay;

  /// Optional controller to start and stop the sweep. The caller owns and
  /// disposes it.
  final AnimatedGradientBorderController? controller;

  /// Space between the border and the child. Defaults to
  /// `EdgeInsets.all(borderWidth)`.
  final EdgeInsetsGeometry? padding;

  /// Fill behind the child inside the border. Defaults to the theme's
  /// `colorScheme.surface`.
  final Color? backgroundColor;

  /// Radius of an optional soft outer glow drawn with a blurred stroke.
  /// 0 (the default) disables the glow.
  final double glowRadius;

  /// When `false` the sweep never animates; the border renders statically
  /// and the child renders normally. Defaults to `true`.
  final bool enabled;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _progress;
  bool _shouldPlay = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    _shouldPlay = widget.autoPlay || (widget.controller?.isPlaying ?? false);
    widget.controller?.addListener(_handleControllerChanged);
    widget.controller?._isPlaying = _shouldPlay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(AnimatedGradientBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..repeat();
      }
    }
    if (widget.curve != oldWidget.curve) {
      _progress.dispose();
      _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      widget.controller?._isPlaying = _shouldPlay;
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _shouldPlay = widget.autoPlay;
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _shouldPlay = widget.controller!.isPlaying;
    _syncPlayback();
  }

  void _syncPlayback() {
    final bool reduced = MicroMotion.isReduced(context);
    final bool play = _shouldPlay && widget.enabled && !reduced;
    if (play) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.0;
    }
    widget.controller?._isPlaying = play;
  }

  List<Color> _effectiveColors(ColorScheme scheme) {
    final List<Color>? given = widget.colors;
    List<Color> colors;
    if (given == null || given.isEmpty) {
      colors = <Color>[scheme.primary, scheme.tertiary, scheme.primary];
    } else if (given.length == 1) {
      colors = <Color>[given.first, given.first];
    } else if (given.first != given.last) {
      colors = <Color>[...given, given.first];
    } else {
      colors = given;
    }
    return colors;
  }

  BorderRadius _innerRadius() {
    final double d = widget.borderWidth;
    Radius deflate(Radius radius) => Radius.elliptical(
          math.max(0, radius.x - d),
          math.max(0, radius.y - d),
        );
    final BorderRadius r = widget.borderRadius;
    return BorderRadius.only(
      topLeft: deflate(r.topLeft),
      topRight: deflate(r.topRight),
      bottomLeft: deflate(r.bottomLeft),
      bottomRight: deflate(r.bottomRight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EdgeInsetsGeometry padding =
        widget.padding ?? EdgeInsets.all(widget.borderWidth);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _GradientBorderPainter(
          progress: _progress,
          colors: _effectiveColors(scheme),
          borderWidth: widget.borderWidth,
          borderRadius: widget.borderRadius,
          backgroundColor: widget.backgroundColor ?? scheme.surface,
          glowRadius: widget.glowRadius,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.borderWidth),
          child: ClipRRect(
            borderRadius: _innerRadius(),
            child: Padding(padding: padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.progress,
    required this.colors,
    required this.borderWidth,
    required this.borderRadius,
    required this.backgroundColor,
    required this.glowRadius,
  }) : super(repaint: progress);

  /// Rotation progress of the sweep, 0..1 for one full turn.
  final Animation<double> progress;

  /// Seamless color list (first equals last).
  final List<Color> colors;

  /// Thickness of the stroke.
  final double borderWidth;

  /// Corner rounding of the outer border edge.
  final BorderRadius borderRadius;

  /// Fill behind the child inside the border.
  final Color backgroundColor;

  /// Blur radius of the optional outer glow; 0 disables it.
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect strokeRect = rect.deflate(borderWidth / 2);
    if (strokeRect.isEmpty) return;
    final RRect stroke = borderRadius.toRRect(strokeRect);

    // Only the rotation changes per frame; colors and stops are stable.
    final SweepGradient gradient = SweepGradient(
      colors: colors,
      transform: GradientRotation(progress.value * 2 * math.pi),
    );
    final Shader shader = gradient.createShader(rect);

    if (glowRadius > 0) {
      final Paint glowPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + glowRadius
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawRRect(stroke, glowPaint);
    }

    if (borderWidth > 0) {
      final Rect innerRect = rect.deflate(borderWidth);
      if (!innerRect.isEmpty) {
        Radius deflate(Radius radius) => Radius.elliptical(
              math.max(0, radius.x - borderWidth),
              math.max(0, radius.y - borderWidth),
            );
        final RRect inner = RRect.fromRectAndCorners(
          innerRect,
          topLeft: deflate(borderRadius.topLeft),
          topRight: deflate(borderRadius.topRight),
          bottomLeft: deflate(borderRadius.bottomLeft),
          bottomRight: deflate(borderRadius.bottomRight),
        );
        canvas.drawRRect(inner, Paint()..color = backgroundColor);
      }
      final Paint borderPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawRRect(stroke, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        !listEquals(oldDelegate.colors, colors) ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.glowRadius != glowRadius;
  }
}
