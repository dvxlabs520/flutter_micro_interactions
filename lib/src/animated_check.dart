import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The mark drawn by an [AnimatedCheck].
enum AnimatedCheckType {
  /// A checkmark, for success states.
  check,

  /// A cross, for error states.
  cross,
}

/// Programmatic control for an [AnimatedCheck] widget.
///
/// ```dart
/// final controller = AnimatedCheckController();
/// // ...
/// AnimatedCheck(autoPlay: false, controller: controller);
/// // later, when the operation finishes:
/// controller.play();
/// ```
///
/// [isComplete] reflects whether the attached mark is fully drawn. Dispose
/// the controller yourself when it is no longer needed.
class AnimatedCheckController extends ChangeNotifier {
  _CheckCommand? _pending;
  bool _isComplete = false;

  /// Whether the attached mark is fully drawn.
  bool get isComplete => _isComplete;

  /// Draws the mark from the beginning.
  void play() {
    _pending = _CheckCommand.play;
    notifyListeners();
  }

  /// Clears the mark so [play] can draw it again.
  void reset() {
    _pending = _CheckCommand.reset;
    notifyListeners();
  }
}

enum _CheckCommand { play, reset }

/// A checkmark or cross drawn with a progressively revealed stroke, for
/// loading-to-result flows.
///
/// ```dart
/// AnimatedCheck(
///   type: AnimatedCheckType.check,
///   onCompleted: () => Navigator.of(context).pop(),
/// )
/// ```
///
/// With [showCircle] a circle is drawn over roughly the first half of
/// [duration] and the mark over the remainder; without it the mark uses the
/// whole duration. The stroke is revealed with round caps using path
/// metrics, so it looks hand-drawn rather than faded in.
///
/// The animation starts automatically when [autoPlay] is `true`; use
/// [controller] to start or clear it programmatically, for example after an
/// async operation resolves. Changing [type] while or after the mark is
/// drawn resets and replays the animation with the new mark.
///
/// Accessibility: while drawing, the graphic is excluded from semantics;
/// once complete it exposes [semanticLabel] ('Success' for a check, 'Error'
/// for a cross, by default). Under reduced motion the full mark renders
/// instantly and [onCompleted] still fires.
///
/// When [enabled] is `false` the widget renders the complete mark statically:
/// nothing animates, controller commands are ignored, and [onCompleted] is
/// not called.
class AnimatedCheck extends StatefulWidget {
  /// Creates an animated check or cross.
  ///
  /// [size] and [strokeWidth] must be positive.
  const AnimatedCheck({
    super.key,
    this.type = AnimatedCheckType.check,
    this.size = 48.0,
    this.color,
    this.strokeWidth = 4.0,
    this.showCircle = true,
    this.circleColor,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.autoPlay = true,
    this.controller,
    this.onCompleted,
    this.semanticLabel,
    this.enabled = true,
  }) : assert(size > 0.0, 'size must be positive'),
       assert(strokeWidth > 0.0, 'strokeWidth must be positive');

  /// Which mark to draw. Defaults to [AnimatedCheckType.check].
  final AnimatedCheckType type;

  /// The width and height of the drawing. Defaults to 48.
  final double size;

  /// The stroke color. Defaults to [ColorScheme.primary] for a check and
  /// [ColorScheme.error] for a cross.
  final Color? color;

  /// The stroke thickness. Defaults to 4.
  final double strokeWidth;

  /// Whether an animated circle is drawn around the mark before the mark
  /// itself. Defaults to `true`.
  final bool showCircle;

  /// The circle color. Defaults to [color].
  final Color? circleColor;

  /// Total duration of the animation (circle and mark together). Defaults
  /// to 700 milliseconds.
  final Duration duration;

  /// The curve of the animation. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Whether the animation starts as soon as the widget appears. Defaults
  /// to `true`.
  final bool autoPlay;

  /// Optional controller to play or reset the animation programmatically.
  final AnimatedCheckController? controller;

  /// Called once each time the mark finishes drawing.
  final VoidCallback? onCompleted;

  /// The semantic label exposed once the mark is complete. Defaults to
  /// 'Success' for a check and 'Error' for a cross.
  final String? semanticLabel;

  /// When `false` the complete mark renders statically with no animation
  /// and controller commands are ignored. Defaults to `true`.
  final bool enabled;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;

  /// Guards [AnimatedCheck.onCompleted] so it fires once per play.
  bool _completedNotified = false;

  /// Set in [initState] and consumed on the first [didChangeDependencies],
  /// where [MicroMotion.isReduced] can read the ambient [MediaQuery].
  bool _autoPlayPending = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.addStatusListener(_onStatusChanged);
    widget.controller?.addListener(_onControllerCommand);
    widget.controller?._isComplete = false;
    _autoPlayPending = widget.autoPlay && widget.enabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoPlayPending) {
      _autoPlayPending = false;
      // Deferred one frame: playing here could complete synchronously under
      // reduced motion and fire onCompleted during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _play();
        }
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
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
      widget.controller?._isComplete = _controller.isCompleted;
    }
    if (widget.type != oldWidget.type) {
      // A new mark: reset and replay (the reduced-motion jump happens
      // inside _play). Only replay when a draw had actually started so a
      // never-played, non-autoPlay widget stays blank.
      final bool hadStarted =
          _controller.value > 0.0 || _controller.isAnimating;
      _resetInternal();
      if (hadStarted && widget.enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _play();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerCommand);
    _controller.removeStatusListener(_onStatusChanged);
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.controller?._isComplete = true;
      if (!_completedNotified) {
        _completedNotified = true;
        widget.onCompleted?.call();
      }
    } else {
      widget.controller?._isComplete = false;
    }
  }

  void _onControllerCommand() {
    final AnimatedCheckController controller = widget.controller!;
    final _CheckCommand? command = controller._pending;
    controller._pending = null;
    if (command == null || !mounted || !widget.enabled) {
      return;
    }
    switch (command) {
      case _CheckCommand.play:
        _play();
      case _CheckCommand.reset:
        _resetInternal();
    }
  }

  void _play() {
    if (!mounted) {
      return;
    }
    _completedNotified = false;
    widget.controller?._isComplete = false;
    _controller.stop();
    if (MicroMotion.isReduced(context)) {
      if (_controller.value == 1.0) {
        // Setting the value would not change the status, so notify by hand.
        _onStatusChanged(AnimationStatus.completed);
      } else {
        _controller.value = 1.0;
      }
      return;
    }
    _controller.forward(from: 0.0);
  }

  void _resetInternal() {
    _completedNotified = false;
    widget.controller?._isComplete = false;
    _controller
      ..stop()
      ..value = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color =
        widget.color ??
        (widget.type == AnimatedCheckType.check
            ? scheme.primary
            : scheme.error);
    final Color circleColor = widget.circleColor ?? color;
    final String semanticLabel =
        widget.semanticLabel ??
        (widget.type == AnimatedCheckType.check ? 'Success' : 'Error');

    final Widget graphic = SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AnimatedCheckPainter(
            progress: widget.enabled
                ? _animation
                : const AlwaysStoppedAnimation<double>(1.0),
            type: widget.type,
            color: color,
            circleColor: circleColor,
            strokeWidth: widget.strokeWidth,
            showCircle: widget.showCircle,
          ),
        ),
      ),
    );

    if (!widget.enabled) {
      return Semantics(label: semanticLabel, child: graphic);
    }

    // The semantics wrapper listens to the controller so the label appears
    // exactly when the mark completes, without calling setState per frame:
    // the expensive subtree is the prebuilt [graphic] child.
    return AnimatedBuilder(
      animation: _controller,
      child: graphic,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isCompleted) {
          return Semantics(label: semanticLabel, child: child);
        }
        return ExcludeSemantics(child: child);
      },
    );
  }
}

/// Paints the circle and mark of an [AnimatedCheck], revealing the stroke
/// with [ui.PathMetric.extractPath].
class _AnimatedCheckPainter extends CustomPainter {
  _AnimatedCheckPainter({
    required this.progress,
    required this.type,
    required this.color,
    required this.circleColor,
    required this.strokeWidth,
    required this.showCircle,
  }) : super(repaint: progress);

  /// The animation driving the reveal; also the repaint listenable.
  final Animation<double> progress;

  final AnimatedCheckType type;
  final Color color;
  final Color circleColor;
  final double strokeWidth;
  final bool showCircle;

  /// Fraction of the animation used by the circle when [showCircle] is on.
  static const double _circlePhase = 0.55;

  // Paths are cached per size; the painter itself is recreated whenever a
  // field that shapes them ([type], [strokeWidth]) changes.
  Size? _cachedSize;
  ui.PathMetric? _circleMetric;
  List<ui.PathMetric> _markMetrics = <ui.PathMetric>[];
  double _markLength = 0.0;

  void _ensurePaths(Size size) {
    if (_cachedSize == size) {
      return;
    }
    _cachedSize = size;

    final double inset = strokeWidth / 2;
    final Path circle = Path()
      ..addArc(
        Rect.fromLTWH(
          inset,
          inset,
          math.max(0.0, size.width - strokeWidth),
          math.max(0.0, size.height - strokeWidth),
        ),
        -math.pi / 2,
        math.pi * 2,
      );
    _circleMetric = circle.computeMetrics().first;

    final double w = size.width;
    final double h = size.height;
    final Path mark = Path();
    if (type == AnimatedCheckType.check) {
      mark
        ..moveTo(0.28 * w, 0.53 * h)
        ..lineTo(0.44 * w, 0.67 * h)
        ..lineTo(0.72 * w, 0.37 * h);
    } else {
      mark
        ..moveTo(0.34 * w, 0.34 * h)
        ..lineTo(0.66 * w, 0.66 * h)
        ..moveTo(0.66 * w, 0.34 * h)
        ..lineTo(0.34 * w, 0.66 * h);
    }
    _markMetrics = mark.computeMetrics().toList();
    _markLength = _markMetrics.fold<double>(
      0.0,
      (double sum, ui.PathMetric metric) => sum + metric.length,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ensurePaths(size);
    final double t = progress.value.clamp(0.0, 1.0);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (showCircle) {
      final double circleT = (t / _circlePhase).clamp(0.0, 1.0);
      final ui.PathMetric? metric = _circleMetric;
      if (circleT > 0.0 && metric != null) {
        stroke.color = circleColor;
        canvas.drawPath(
          metric.extractPath(0.0, metric.length * circleT),
          stroke,
        );
      }
    }

    final double markT = showCircle
        ? ((t - _circlePhase) / (1.0 - _circlePhase)).clamp(0.0, 1.0)
        : t;
    if (markT > 0.0 && _markLength > 0.0) {
      stroke.color = color;
      // Reveal the mark's subpaths one after another (a cross has two).
      double remaining = _markLength * markT;
      for (final ui.PathMetric metric in _markMetrics) {
        final double segment = math.min(metric.length, remaining);
        if (segment > 0.0) {
          canvas.drawPath(metric.extractPath(0.0, segment), stroke);
        }
        remaining -= segment;
        if (remaining <= 0.0) {
          break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AnimatedCheckPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.circleColor != circleColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showCircle != showCircle;
  }
}
