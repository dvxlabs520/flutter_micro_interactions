import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Shape of the sparks drawn by a [ClickSpark].
enum ClickSparkShape {
  /// Short lines that radiate from the tap point and shrink as they
  /// travel.
  lines,

  /// Small dots that fly outward and shrink as they travel.
  dots,
}

/// Bursts small sparks out of every tap point on its child.
///
/// Each tap on the child launches [sparkCount] sparks that radiate from
/// the exact point that was tapped, travel [sparkRadius] pixels outward
/// and shrink away over [duration]. Rapid taps produce overlapping bursts.
///
/// ```dart
/// ClickSpark(
///   sparkColor: Colors.amber,
///   child: ElevatedButton(
///     onPressed: () {},
///     child: const Text('Click me'),
///   ),
/// )
/// ```
///
/// A tap is a pointer that goes down and comes back up without moving
/// further than the platform's tap slop, so scrolls and drags that start
/// on the child do not spark. Pointer events are only observed, never
/// consumed: buttons and gestures inside the child keep working.
///
/// The sparks are painted in an overlay that ignores pointers, adds no
/// semantics and is not clipped, so sparks near the edges fly outside the
/// child's bounds. An ancestor that clips (for example a [Card] with a
/// clip behavior) still clips them.
///
/// When the platform requests reduced motion, or when [enabled] is
/// `false`, no sparks are drawn and no frames are scheduled.
class ClickSpark extends StatefulWidget {
  /// Creates a spark effect for taps on [child].
  const ClickSpark({
    super.key,
    required this.child,
    this.sparkColor,
    this.sparkCount = 8,
    this.sparkSize = 10.0,
    this.sparkRadius = 15.0,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOut,
    this.shape = ClickSparkShape.lines,
    this.extraScale = 1.0,
    this.strokeWidth = 2.0,
    this.enabled = true,
  }) : assert(sparkCount > 0, 'sparkCount must be at least 1'),
       assert(sparkSize > 0, 'sparkSize must be positive'),
       assert(sparkRadius >= 0, 'sparkRadius must not be negative'),
       assert(extraScale > 0, 'extraScale must be positive'),
       assert(strokeWidth > 0, 'strokeWidth must be positive');

  /// The widget whose taps produce sparks.
  final Widget child;

  /// Color of the sparks. Defaults to the theme's `colorScheme.primary`.
  final Color? sparkColor;

  /// Number of sparks per burst, spread evenly around the tap point.
  /// Defaults to 8.
  final int sparkCount;

  /// Starting size of each spark: the length of a line, or the diameter of
  /// a dot is derived from it. Defaults to 10.
  final double sparkSize;

  /// Distance each spark travels from the tap point. Defaults to 15.
  final double sparkRadius;

  /// Lifetime of one burst. Defaults to 400 milliseconds.
  final Duration duration;

  /// Curve of the outward motion. Defaults to [Curves.easeOut].
  final Curve curve;

  /// Shape of the sparks. Defaults to [ClickSparkShape.lines].
  final ClickSparkShape shape;

  /// Multiplier applied to both [sparkSize] and [sparkRadius]. Defaults
  /// to 1.
  final double extraScale;

  /// Stroke thickness of line sparks. Defaults to 2.
  final double strokeWidth;

  /// When `false` taps produce no sparks. The child still works normally.
  /// Defaults to `true`.
  final bool enabled;

  @override
  State<ClickSpark> createState() => _ClickSparkState();
}

/// One burst in flight.
class _SparkBurst {
  _SparkBurst(this.origin, this.start);

  /// Tap point in local coordinates.
  final Offset origin;

  /// Ticker time at which the burst started.
  final Duration start;
}

/// Shared mutable state between the widget and its painter.
class _SparkField extends ChangeNotifier {
  final List<_SparkBurst> bursts = <_SparkBurst>[];
  Duration now = Duration.zero;

  void changed() => notifyListeners();
}

class _ClickSparkState extends State<ClickSpark>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _SparkField _field = _SparkField();

  /// Down positions of pointers that may still become taps.
  final Map<int, Offset> _downPositions = <int, Offset>{};

  /// Ticker time when the current ticker run started, relative to which
  /// burst start times are stored.
  Duration _elapsed = Duration.zero;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced) _clear();
  }

  @override
  void didUpdateWidget(ClickSpark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) _clear();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _field.dispose();
    super.dispose();
  }

  void _clear() {
    _downPositions.clear();
    if (_ticker.isActive) _ticker.stop();
    _elapsed = Duration.zero;
    _field.now = Duration.zero;
    if (_field.bursts.isNotEmpty) {
      _field.bursts.clear();
      _field.changed();
    }
  }

  void _handleTick(Duration elapsed) {
    _elapsed = elapsed;
    _field.now = elapsed;
    final Duration duration = widget.duration;
    _field.bursts.removeWhere(
      (_SparkBurst burst) => elapsed - burst.start >= duration,
    );
    _field.changed();
    if (_field.bursts.isEmpty) {
      _ticker.stop();
      _elapsed = Duration.zero;
      _field.now = Duration.zero;
    }
  }

  void _spark(Offset origin) {
    if (!widget.enabled || _reduced || widget.duration == Duration.zero) {
      return;
    }
    if (!_ticker.isActive) {
      _elapsed = Duration.zero;
      _field.now = Duration.zero;
      _ticker.start();
    }
    _field.bursts.add(_SparkBurst(origin, _elapsed));
    _field.changed();
  }

  void _handleDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    _downPositions[event.pointer] = event.localPosition;
  }

  void _handleMove(PointerMoveEvent event) {
    final Offset? down = _downPositions[event.pointer];
    if (down == null) return;
    final double slop = computeHitSlop(
      event.kind,
      MediaQuery.maybeGestureSettingsOf(context),
    );
    if ((event.localPosition - down).distance > slop) {
      _downPositions.remove(event.pointer);
    }
  }

  void _handleUp(PointerUpEvent event) {
    if (_downPositions.remove(event.pointer) == null) return;
    _spark(event.localPosition);
  }

  void _handleCancel(PointerCancelEvent event) {
    _downPositions.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    final bool on = widget.enabled && !_reduced;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: on ? _handleDown : null,
      onPointerMove: on ? _handleMove : null,
      onPointerUp: on ? _handleUp : null,
      onPointerCancel: on ? _handleCancel : null,
      child: Stack(
        fit: StackFit.passthrough,
        // Clip.none: sparks intentionally overflow the child's bounds.
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SparkPainter(
                      field: _field,
                      color:
                          widget.sparkColor ??
                          Theme.of(context).colorScheme.primary,
                      count: widget.sparkCount,
                      size: widget.sparkSize * widget.extraScale,
                      radius: widget.sparkRadius * widget.extraScale,
                      duration: widget.duration,
                      curve: widget.curve,
                      shape: widget.shape,
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.field,
    required this.color,
    required this.count,
    required this.size,
    required this.radius,
    required this.duration,
    required this.curve,
    required this.shape,
    required this.strokeWidth,
  }) : super(repaint: field);

  /// Active bursts and the current ticker time.
  final _SparkField field;

  /// Spark color.
  final Color color;

  /// Sparks per burst.
  final int count;

  /// Starting spark size, already scaled.
  final double size;

  /// Travel distance, already scaled.
  final double radius;

  /// Burst lifetime.
  final Duration duration;

  /// Curve of the outward motion.
  final Curve curve;

  /// Spark shape.
  final ClickSparkShape shape;

  /// Line thickness.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (field.bursts.isEmpty) return;
    final int total = duration.inMicroseconds;
    if (total <= 0) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = shape == ClickSparkShape.lines
          ? PaintingStyle.stroke
          : PaintingStyle.fill;

    for (final _SparkBurst burst in field.bursts) {
      final double t = ((field.now - burst.start).inMicroseconds / total).clamp(
        0.0,
        1.0,
      );
      if (t >= 1.0) continue;
      final double eased = curve.transform(t);
      final double distance = eased * radius;
      final double length = size * (1 - eased);
      if (length <= 0) continue;

      for (int i = 0; i < count; i++) {
        final double angle = 2 * math.pi * i / count;
        final double dx = math.cos(angle);
        final double dy = math.sin(angle);
        final Offset from = burst.origin + Offset(dx, dy) * distance;
        if (shape == ClickSparkShape.lines) {
          final Offset to = burst.origin + Offset(dx, dy) * (distance + length);
          canvas.drawLine(from, to, paint);
        } else {
          canvas.drawCircle(
            from + Offset(dx, dy) * (length / 2),
            length / 4,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.field != field ||
        oldDelegate.color != color ||
        oldDelegate.count != count ||
        oldDelegate.size != size ||
        oldDelegate.radius != radius ||
        oldDelegate.duration != duration ||
        oldDelegate.curve != curve ||
        oldDelegate.shape != shape ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
