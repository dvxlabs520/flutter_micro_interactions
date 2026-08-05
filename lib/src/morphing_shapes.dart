import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The shapes that [MorphingShapes] and [ShapeMorph] can draw and morph
/// between.
enum MicroShapeType {
  /// A circle.
  circle,

  /// A square.
  square,

  /// An upward pointing triangle.
  triangle,

  /// A five pointed star.
  star,

  /// A heart.
  heart,

  /// A diamond (square rotated 45 degrees).
  diamond,
}

/// Programmatic control for a [MorphingShapes] widget.
///
/// Attach an instance through [MorphingShapes.controller] and call
/// [morphToNext] or [morphTo] to drive the widget without gestures.
///
/// ```dart
/// final controller = MorphingShapesController();
/// // ...
/// MorphingShapes(
///   shapes: const [MicroShapeType.circle, MicroShapeType.star],
///   controller: controller,
/// );
/// // later:
/// controller.morphToNext();
/// ```
///
/// The controller does not own the animation; dispose it yourself when it is
/// no longer needed.
class MorphingShapesController extends ChangeNotifier {
  bool _pendingNext = false;
  MicroShapeType? _pendingTarget;

  /// Asks the attached widget to morph to the next shape in its list.
  void morphToNext() {
    _pendingNext = true;
    _pendingTarget = null;
    notifyListeners();
  }

  /// Asks the attached widget to morph to [shape].
  ///
  /// Does nothing if the widget's shape list does not contain [shape].
  void morphTo(MicroShapeType shape) {
    _pendingTarget = shape;
    _pendingNext = false;
    notifyListeners();
  }
}

/// A widget that cycles through a list of shapes with a real path morph.
///
/// The morph samples both shape outlines at evenly spaced points and
/// interpolates each point pair, so the outline actually deforms from one
/// shape into the other.
///
/// ```dart
/// MorphingShapes(
///   shapes: const [
///     MicroShapeType.circle,
///     MicroShapeType.square,
///     MicroShapeType.star,
///   ],
///   autoPlay: true,
/// )
/// ```
///
/// Control options:
/// * [autoPlay] cycles shapes automatically every [autoPlayDuration].
/// * [morphOnTap] lets the user tap the shape to advance (off by default).
/// * [controller] allows programmatic morphs.
///
/// Under reduced motion the shape swaps instantly and auto play still
/// advances but without the morph animation. The drawing is decorative and
/// excluded from semantics unless [semanticLabel] is provided.
class MorphingShapes extends StatefulWidget {
  /// Creates a morphing shapes widget.
  const MorphingShapes({
    super.key,
    required this.shapes,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOut,
    this.autoPlay = false,
    this.autoPlayDuration = const Duration(seconds: 2),
    this.size = const Size(100, 100),
    this.color,
    this.controller,
    this.morphOnTap = false,
    this.onShapeChanged,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The shapes to morph between. Must not be empty.
  final List<MicroShapeType> shapes;

  /// Duration of one morph. Defaults to 800 milliseconds.
  final Duration duration;

  /// Curve of the morph. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Whether the widget cycles through [shapes] automatically.
  final bool autoPlay;

  /// Pause between automatic morphs. Defaults to 2 seconds.
  final Duration autoPlayDuration;

  /// Size of the drawing area. Defaults to 100 x 100.
  final Size size;

  /// Fill color of the shape. Defaults to `colorScheme.primary`.
  final Color? color;

  /// Optional controller for programmatic morphs.
  final MorphingShapesController? controller;

  /// Whether tapping the shape morphs to the next one. Defaults to `false`.
  final bool morphOnTap;

  /// Called with the new shape after each completed morph.
  final ValueChanged<MicroShapeType>? onShapeChanged;

  /// When `false`, auto play, taps and controller commands are ignored and
  /// the current shape renders statically.
  final bool enabled;

  /// Optional semantic label. When null the drawing is excluded from
  /// semantics entirely.
  final String? semanticLabel;

  @override
  State<MorphingShapes> createState() => _MorphingShapesState();
}

class _MorphingShapesState extends State<MorphingShapes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _animation;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;
  int _nextIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    widget.controller?.addListener(_onControllerCommand);
    _scheduleAutoPlay();
  }

  @override
  void didUpdateWidget(MorphingShapes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerCommand);
      widget.controller?.addListener(_onControllerCommand);
    }
    if (!listEquals(widget.shapes, oldWidget.shapes)) {
      // Clamp indices when the list shrinks or changes.
      _currentIndex = _currentIndex.clamp(0, widget.shapes.length - 1);
      _nextIndex = _nextIndex.clamp(0, widget.shapes.length - 1);
    }
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.autoPlayDuration != oldWidget.autoPlayDuration ||
        widget.enabled != oldWidget.enabled) {
      _scheduleAutoPlay();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerCommand);
    _autoPlayTimer?.cancel();
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onControllerCommand() {
    final MorphingShapesController controller = widget.controller!;
    if (!widget.enabled) {
      return;
    }
    if (controller._pendingNext) {
      controller._pendingNext = false;
      _morphToNext();
    } else if (controller._pendingTarget != null) {
      final MicroShapeType target = controller._pendingTarget!;
      controller._pendingTarget = null;
      final int index = widget.shapes.indexOf(target);
      if (index != -1) {
        _morphToIndex(index);
      }
    }
  }

  void _scheduleAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (widget.autoPlay && widget.enabled && widget.shapes.length > 1) {
      _autoPlayTimer = Timer(widget.autoPlayDuration, () {
        if (mounted) {
          _morphToNext();
        }
      });
    }
  }

  void _morphToNext() {
    if (widget.shapes.length <= 1) {
      _scheduleAutoPlay();
      return;
    }
    _morphToIndex((_currentIndex + 1) % widget.shapes.length);
  }

  void _morphToIndex(int index) {
    if (index == _currentIndex || _controller.isAnimating) {
      _scheduleAutoPlay();
      return;
    }
    if (MicroMotion.isReduced(context)) {
      // Instant swap under reduced motion.
      setState(() {
        _currentIndex = index;
        _nextIndex = index;
      });
      widget.onShapeChanged?.call(widget.shapes[index]);
      _scheduleAutoPlay();
      return;
    }
    setState(() {
      _nextIndex = index;
    });
    _controller.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex = _nextIndex;
      });
      _controller.reset();
      widget.onShapeChanged?.call(widget.shapes[_currentIndex]);
      _scheduleAutoPlay();
    });
  }

  void _handleTap() {
    if (widget.enabled && widget.morphOnTap) {
      _morphToNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? Theme.of(context).colorScheme.primary;
    final Widget painting = RepaintBoundary(
      child: SizedBox.fromSize(
        size: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _MorphingShapePainter(
                currentShape: widget.shapes[_currentIndex],
                nextShape: widget.shapes[_nextIndex],
                progress: _animation.value,
                color: color,
              ),
            );
          },
        ),
      ),
    );

    final Widget semantics = widget.semanticLabel != null
        ? Semantics(
            label: widget.semanticLabel,
            child: ExcludeSemantics(child: painting),
          )
        : ExcludeSemantics(child: painting);

    if (!widget.morphOnTap) {
      return semantics;
    }
    return GestureDetector(
      onTap: _handleTap,
      child: semantics,
    );
  }
}

/// A widget that morphs between exactly two shapes, toggling on tap.
///
/// ```dart
/// ShapeMorph(
///   fromShape: MicroShapeType.circle,
///   toShape: MicroShapeType.heart,
/// )
/// ```
///
/// With [autoReverse] the widget loops between the two shapes on its own
/// (rendered static under reduced motion). Otherwise a tap toggles between
/// them when [morphOnTap] is `true` (the default).
class ShapeMorph extends StatefulWidget {
  /// Creates a shape morph widget.
  const ShapeMorph({
    super.key,
    required this.fromShape,
    required this.toShape,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeInOut,
    this.size = const Size(80, 80),
    this.color,
    this.autoReverse = false,
    this.morphOnTap = true,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The starting shape.
  final MicroShapeType fromShape;

  /// The ending shape.
  final MicroShapeType toShape;

  /// Duration of the morph. Defaults to 600 milliseconds.
  final Duration duration;

  /// Curve of the morph. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Size of the drawing area. Defaults to 80 x 80.
  final Size size;

  /// Fill color of the shape. Defaults to `colorScheme.primary`.
  final Color? color;

  /// Whether the morph loops back and forth automatically.
  final bool autoReverse;

  /// Whether tapping toggles the morph (ignored while [autoReverse] is on).
  /// Defaults to `true`.
  final bool morphOnTap;

  /// When `false`, gestures and auto reverse are ignored.
  final bool enabled;

  /// Optional semantic label. When null the drawing is excluded from
  /// semantics entirely.
  final String? semanticLabel;

  @override
  State<ShapeMorph> createState() => _ShapeMorphState();
}

class _ShapeMorphState extends State<ShapeMorph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAutoReverse();
  }

  @override
  void didUpdateWidget(ShapeMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.autoReverse != oldWidget.autoReverse ||
        widget.enabled != oldWidget.enabled) {
      _syncAutoReverse();
    }
  }

  void _syncAutoReverse() {
    final bool shouldLoop =
        widget.autoReverse && widget.enabled && !MicroMotion.isReduced(context);
    if (shouldLoop) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else if (widget.autoReverse) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled || widget.autoReverse || _controller.isAnimating) {
      return;
    }
    if (MicroMotion.isReduced(context)) {
      // Instant swap under reduced motion.
      _controller.value = _controller.value == 0.0 ? 1.0 : 0.0;
      return;
    }
    if (_controller.value == 0.0) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? Theme.of(context).colorScheme.primary;
    final Widget painting = RepaintBoundary(
      child: SizedBox.fromSize(
        size: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _MorphingShapePainter(
                currentShape: widget.fromShape,
                nextShape: widget.toShape,
                progress: _animation.value,
                color: color,
              ),
            );
          },
        ),
      ),
    );

    final Widget semantics = widget.semanticLabel != null
        ? Semantics(
            label: widget.semanticLabel,
            child: ExcludeSemantics(child: painting),
          )
        : ExcludeSemantics(child: painting);

    if (widget.autoReverse || !widget.morphOnTap) {
      return semantics;
    }
    return GestureDetector(
      onTap: _toggle,
      child: semantics,
    );
  }
}

/// Number of points used to sample each shape outline for morphing.
const int _sampleCount = 90;

/// Cache of sampled outlines keyed by shape and canvas size.
final Map<String, List<Offset>> _sampleCache = <String, List<Offset>>{};

class _MorphingShapePainter extends CustomPainter {
  _MorphingShapePainter({
    required this.currentShape,
    required this.nextShape,
    required this.progress,
    required this.color,
  });

  final MicroShapeType currentShape;
  final MicroShapeType nextShape;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (progress <= 0.0 || currentShape == nextShape) {
      canvas.drawPath(_shapePath(currentShape, size), paint);
      return;
    }
    if (progress >= 1.0) {
      canvas.drawPath(_shapePath(nextShape, size), paint);
      return;
    }

    final List<Offset> from = _sampledOutline(currentShape, size);
    final List<Offset> to = _sampledOutline(nextShape, size);
    final Path morphed = Path();
    for (int i = 0; i < _sampleCount; i++) {
      final Offset point = Offset.lerp(from[i], to[i], progress)!;
      if (i == 0) {
        morphed.moveTo(point.dx, point.dy);
      } else {
        morphed.lineTo(point.dx, point.dy);
      }
    }
    morphed.close();
    canvas.drawPath(morphed, paint);
  }

  /// Returns [_sampleCount] points evenly spaced along the outline of
  /// [shape], sampled across the whole path metric chain (all contours) and
  /// cached per shape and size.
  static List<Offset> _sampledOutline(MicroShapeType shape, Size size) {
    final String key = '$shape-${size.width}x${size.height}';
    final List<Offset>? cached = _sampleCache[key];
    if (cached != null) {
      return cached;
    }
    final Path path = _shapePath(shape, size);
    final List<PathMetric> metrics = path.computeMetrics().toList();
    final double totalLength =
        metrics.fold(0.0, (double sum, PathMetric m) => sum + m.length);
    final List<Offset> points = <Offset>[];
    if (totalLength == 0) {
      points.addAll(List<Offset>.filled(_sampleCount, size.center(Offset.zero)));
    } else {
      for (int i = 0; i < _sampleCount; i++) {
        double distance = totalLength * i / _sampleCount;
        Offset position = size.center(Offset.zero);
        for (final PathMetric metric in metrics) {
          if (distance <= metric.length) {
            position = metric.getTangentForOffset(distance)?.position ??
                position;
            break;
          }
          distance -= metric.length;
        }
        points.add(position);
      }
    }
    _sampleCache[key] = points;
    return points;
  }

  static Path _shapePath(MicroShapeType shape, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2;
    switch (shape) {
      case MicroShapeType.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
      case MicroShapeType.square:
        return Path()
          ..addRect(Rect.fromCenter(
              center: center, width: radius * 2, height: radius * 2));
      case MicroShapeType.triangle:
        return Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx - radius, center.dy + radius)
          ..lineTo(center.dx + radius, center.dy + radius)
          ..close();
      case MicroShapeType.star:
        return _starPath(center, radius);
      case MicroShapeType.heart:
        return _heartPath(center, radius);
      case MicroShapeType.diamond:
        return Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close();
    }
  }

  static Path _starPath(Offset center, double radius) {
    final Path path = Path();
    const int points = 5;
    const double angle = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final double currentRadius = i.isEven ? radius : radius * 0.5;
      final double x =
          center.dx + currentRadius * math.cos(i * angle - math.pi / 2);
      final double y =
          center.dy + currentRadius * math.sin(i * angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static Path _heartPath(Offset center, double radius) {
    final Path path = Path();
    final double width = radius * 2;
    final double height = radius * 1.8;
    path.moveTo(center.dx, center.dy + height * 0.3);
    path.cubicTo(
      center.dx - width * 0.5,
      center.dy - height * 0.1,
      center.dx - width * 0.5,
      center.dy - height * 0.5,
      center.dx,
      center.dy - height * 0.2,
    );
    path.cubicTo(
      center.dx + width * 0.5,
      center.dy - height * 0.5,
      center.dx + width * 0.5,
      center.dy - height * 0.1,
      center.dx,
      center.dy + height * 0.3,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MorphingShapePainter oldDelegate) {
    return oldDelegate.currentShape != currentShape ||
        oldDelegate.nextShape != nextShape ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
