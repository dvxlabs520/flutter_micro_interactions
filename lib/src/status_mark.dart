import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The state shown by a [StatusMark] (and by each step of a
/// `ThinkingSteps` trace).
enum MicroStatus {
  /// Nothing has happened yet: a faint dashed ring.
  idle,

  /// Work is in progress: a rotating arc, or a determinate arc when a
  /// progress value is known.
  loading,

  /// The work finished successfully: a full ring with a checkmark.
  success,

  /// The work failed: a full ring with a cross and a small shake.
  error,
}

/// A small status glyph that morphs smoothly between [MicroStatus] states:
/// a faint dashed ring while idle, a spinning (or determinate) arc while
/// loading, a closed ring with a checkmark on success, and a ring with a
/// cross on error.
///
/// ```dart
/// StatusMark(
///   status: isSaving ? MicroStatus.loading : MicroStatus.success,
/// )
/// ```
///
/// Every change of [status] or [progress] animates from whatever is on
/// screen to the new state over [duration], so any state can follow any
/// other. For example, going from loading to success first grows the
/// spinning arc into a full ring, then draws the checkmark stroke in.
/// Going to error draws a cross and gives the glyph a short horizontal
/// shake. When [status] is [MicroStatus.loading] and [progress] is set, the
/// arc is determinate: it starts at the top and animates its sweep to the
/// new value each time [progress] changes.
///
/// Accessibility: the glyph is exposed as a single semantics node labelled
/// with [semanticLabel] or, by default, 'Idle', 'Loading', 'Done' or
/// 'Failed'. A determinate progress is also exposed as a percentage value.
///
/// Under reduced motion the loading arc does not rotate (a static
/// three-quarter arc is shown instead) and every transition jumps straight
/// to its final frame. When [enabled] is `false` the glyph behaves the same
/// way: it always shows the final frame of [status] without animating.
class StatusMark extends StatefulWidget {
  /// Creates a status glyph.
  ///
  /// [size] and [strokeWidth] must be positive, and [progress], when given,
  /// must be in `[0, 1]`.
  const StatusMark({
    super.key,
    this.status = MicroStatus.idle,
    this.progress,
    this.size = 20.0,
    this.strokeWidth = 2.0,
    this.idleColor,
    this.loadingColor,
    this.successColor,
    this.errorColor,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOutCubic,
    this.spinDuration = const Duration(milliseconds: 1000),
    this.semanticLabel,
    this.enabled = true,
  }) : assert(size > 0.0, 'size must be positive'),
       assert(strokeWidth > 0.0, 'strokeWidth must be positive'),
       assert(
         progress == null || (progress >= 0.0 && progress <= 1.0),
         'progress must be null or in [0, 1]',
       );

  /// The state to show. Defaults to [MicroStatus.idle].
  final MicroStatus status;

  /// The known progress of a [MicroStatus.loading] state, in `[0, 1]`.
  ///
  /// When null the loading arc is indeterminate and rotates. Ignored for
  /// other states.
  final double? progress;

  /// The width and height of the glyph. Defaults to 20.
  final double size;

  /// The stroke thickness of the ring and marks. Defaults to 2.
  final double strokeWidth;

  /// The color of the dashed idle ring. Defaults to [ColorScheme.outline].
  final Color? idleColor;

  /// The color of the loading arc. Defaults to [ColorScheme.primary].
  final Color? loadingColor;

  /// The color of the success ring and checkmark. Defaults to a green that
  /// reads well on the current theme brightness (`0xFF2E7D32` on light
  /// themes, `0xFF81C784` on dark themes).
  final Color? successColor;

  /// The color of the error ring and cross. Defaults to
  /// [ColorScheme.error].
  final Color? errorColor;

  /// The length of a transition between two states. Defaults to 350
  /// milliseconds.
  final Duration duration;

  /// The curve applied to each part of a transition. Defaults to
  /// [Curves.easeInOutCubic].
  final Curve curve;

  /// The time of one full rotation of the indeterminate loading arc.
  /// Defaults to 1000 milliseconds. A zero duration disables the rotation.
  final Duration spinDuration;

  /// The semantic label of the glyph. Defaults to 'Idle', 'Loading', 'Done'
  /// or 'Failed' depending on [status].
  final String? semanticLabel;

  /// When `false` the glyph always shows the final frame of [status] with
  /// no rotation and no transitions. Defaults to `true`.
  final bool enabled;

  /// The default semantic label for [status]: 'Idle', 'Loading', 'Done' or
  /// 'Failed'.
  static String defaultLabelFor(MicroStatus status) {
    switch (status) {
      case MicroStatus.idle:
        return 'Idle';
      case MicroStatus.loading:
        return 'Loading';
      case MicroStatus.success:
        return 'Done';
      case MicroStatus.error:
        return 'Failed';
    }
  }

  @override
  State<StatusMark> createState() => _StatusMarkState();
}

class _StatusMarkState extends State<StatusMark> with TickerProviderStateMixin {
  /// Runs one transition from [_from] to [_to], from 0 to 1.
  late final AnimationController _transition;

  /// Rotation of the indeterminate arc, in turns, repeating from 0 to 1.
  late final AnimationController _spin;

  /// Repaint trigger for the painter: either controller ticking.
  late final Listenable _repaint;

  /// The frame on screen when the current transition started.
  late _MarkFrame _from;

  /// The frame the current transition ends on (its color is unused; the
  /// painter receives the live target color instead).
  late _MarkFrame _to;

  /// Whether the target is the rotating indeterminate arc.
  bool _toSpins = false;

  /// Whether the current transition ends with the error shake.
  bool _shake = false;

  bool _reduced = false;
  bool _initialized = false;

  /// The target color from the last build, used to capture the frame on
  /// screen when a new transition starts.
  Color _toColor = const Color(0x00000000);

  /// Sweep of the rotating indeterminate arc, as a fraction of a turn.
  static const double _spinningSweep = 0.28;

  /// Sweep of the static arc shown for an indeterminate loading state under
  /// reduced motion or when disabled.
  static const double _staticSweep = 0.75;

  /// Extra rotation, in turns, the arc keeps travelling while it grows into
  /// a full ring or fades away after spinning.
  static const double _settleTurn = 0.25;

  bool get _animate => widget.enabled && !_reduced;

  bool get _spins =>
      _animate &&
      widget.spinDuration > Duration.zero &&
      widget.status == MicroStatus.loading &&
      widget.progress == null;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _spin = AnimationController(vsync: this, duration: widget.spinDuration);
    _repaint = Listenable.merge(<Listenable>[_transition, _spin]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MicroMotion.isReduced(context);
    if (!_initialized) {
      _initialized = true;
      _reduced = reduced;
      _toColor = _colorFor(widget.status);
      _toSpins = _spins;
      _to = _targetFrame(rotation: 0.0);
      _from = _to.withColor(_toColor);
      if (_toSpins) {
        _spin.repeat();
      }
      return;
    }
    if (reduced != _reduced) {
      _reduced = reduced;
      _retarget();
    }
  }

  @override
  void didUpdateWidget(StatusMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _transition.duration = widget.duration;
    }
    if (widget.spinDuration != oldWidget.spinDuration) {
      _spin.duration = widget.spinDuration;
      if (_spin.isAnimating) {
        if (_spins) {
          // Restart the loop so the new period takes effect.
          _spin.repeat();
        } else {
          _retarget();
        }
      }
    }
    if (widget.status != oldWidget.status ||
        widget.progress != oldWidget.progress ||
        widget.enabled != oldWidget.enabled) {
      _retarget();
    }
  }

  @override
  void dispose() {
    _transition.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Starts a transition from the frame currently on screen to the frame of
  /// the current widget configuration.
  void _retarget() {
    final _MarkFrame current = _MarkFrame.resolve(
      from: _from,
      to: _to,
      toColor: _toColor,
      t: _transition.value,
      spin: _spin.value,
      toSpins: _toSpins,
      curve: widget.curve,
    );
    final bool spins = _spins;
    final double rotation = current.rotation % 1.0;
    _from = current.withRotation(rotation);

    final bool determinate =
        widget.status == MicroStatus.loading && widget.progress != null;
    final double targetRotation;
    if (spins) {
      targetRotation = 0.0;
    } else if (determinate || !_animate) {
      // A determinate arc starts at the top: finish the current turn.
      targetRotation = rotation == 0.0 ? 0.0 : 1.0;
    } else {
      // Keep the arc travelling a little while it grows or fades.
      targetRotation = _toSpins ? rotation + _settleTurn : rotation;
    }
    _to = _targetFrame(rotation: targetRotation);
    _shake = _to.cross >= 1.0 && current.cross < 1.0;
    _toSpins = spins;

    if (spins) {
      if (!_spin.isAnimating) {
        _spin.value = rotation;
        _spin.repeat();
      }
    } else {
      _spin.stop();
    }

    if (_animate) {
      _transition.forward(from: 0.0);
    } else {
      _transition
        ..stop()
        ..value = 1.0;
    }
  }

  _MarkFrame _targetFrame({required double rotation}) {
    switch (widget.status) {
      case MicroStatus.idle:
        return _MarkFrame(
          sweep: 0.0,
          dash: 1.0,
          check: 0.0,
          cross: 0.0,
          rotation: rotation,
          color: _toColor,
        );
      case MicroStatus.loading:
        return _MarkFrame(
          sweep: widget.progress ?? (_spins ? _spinningSweep : _staticSweep),
          dash: 0.0,
          check: 0.0,
          cross: 0.0,
          rotation: rotation,
          color: _toColor,
        );
      case MicroStatus.success:
        return _MarkFrame(
          sweep: 1.0,
          dash: 0.0,
          check: 1.0,
          cross: 0.0,
          rotation: rotation,
          color: _toColor,
        );
      case MicroStatus.error:
        return _MarkFrame(
          sweep: 1.0,
          dash: 0.0,
          check: 0.0,
          cross: 1.0,
          rotation: rotation,
          color: _toColor,
        );
    }
  }

  Color _colorFor(MicroStatus status) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (status) {
      case MicroStatus.idle:
        return widget.idleColor ?? scheme.outline;
      case MicroStatus.loading:
        return widget.loadingColor ?? scheme.primary;
      case MicroStatus.success:
        return widget.successColor ??
            (scheme.brightness == Brightness.dark
                ? const Color(0xFF81C784)
                : const Color(0xFF2E7D32));
      case MicroStatus.error:
        return widget.errorColor ?? scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    _toColor = _colorFor(widget.status);
    final double? progress = widget.status == MicroStatus.loading
        ? widget.progress
        : null;
    return Semantics(
      container: true,
      label: widget.semanticLabel ?? StatusMark.defaultLabelFor(widget.status),
      value: progress == null ? null : '${(progress * 100).round()}%',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _StatusMarkPainter(
              repaint: _repaint,
              transition: _transition,
              spin: _spin,
              from: _from,
              to: _to,
              toColor: _toColor,
              toSpins: _toSpins,
              shake: _shake,
              curve: widget.curve,
              idleColor: _colorFor(MicroStatus.idle),
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// One visual frame of a [StatusMark]: every value the painter needs.
@immutable
class _MarkFrame {
  const _MarkFrame({
    required this.sweep,
    required this.dash,
    required this.check,
    required this.cross,
    required this.rotation,
    required this.color,
  });

  /// Sweep of the solid arc as a fraction of a full turn.
  final double sweep;

  /// Opacity of the dashed idle ring, in `[0, 1]`.
  final double dash;

  /// Drawn fraction of the checkmark stroke.
  final double check;

  /// Drawn fraction of the cross strokes.
  final double cross;

  /// Rotation of the solid arc's start, in turns.
  final double rotation;

  /// Color of the solid arc and the marks.
  final Color color;

  /// Fraction of a transition used by the ring when a mark draws in after
  /// it.
  static const double _ringPhase = 0.6;

  /// Where a mark starts drawing in during a transition.
  static const double _markInStart = 0.5;

  /// Where a mark finishes drawing out during a transition.
  static const double _markOutEnd = 0.45;

  _MarkFrame withColor(Color value) => _MarkFrame(
    sweep: sweep,
    dash: dash,
    check: check,
    cross: cross,
    rotation: rotation,
    color: value,
  );

  _MarkFrame withRotation(double value) => _MarkFrame(
    sweep: sweep,
    dash: dash,
    check: check,
    cross: cross,
    rotation: value,
    color: color,
  );

  static double _segment(double t, double begin, double end, Curve curve) {
    if (t <= begin) {
      return 0.0;
    }
    if (t >= end) {
      return 1.0;
    }
    return curve.transform((t - begin) / (end - begin));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// The frame shown at transition value [t] between [from] and [to].
  ///
  /// The ring (sweep, dash, color, rotation) morphs first; marks draw out
  /// early in the transition and draw in late, so a loading arc closes into
  /// a full ring before a checkmark appears.
  static _MarkFrame resolve({
    required _MarkFrame from,
    required _MarkFrame to,
    required Color toColor,
    required double t,
    required double spin,
    required bool toSpins,
    required Curve curve,
  }) {
    final bool toHasMark = to.check > 0.0 || to.cross > 0.0;
    final double ringT = _segment(t, 0.0, toHasMark ? _ringPhase : 1.0, curve);
    final double markIn = _segment(t, _markInStart, 1.0, curve);
    final double markOut = _segment(t, 0.0, _markOutEnd, curve);
    return _MarkFrame(
      sweep: _lerp(from.sweep, to.sweep, ringT),
      dash: _lerp(from.dash, to.dash, ringT),
      check: _lerp(
        from.check,
        to.check,
        to.check >= from.check ? markIn : markOut,
      ),
      cross: _lerp(
        from.cross,
        to.cross,
        to.cross >= from.cross ? markIn : markOut,
      ),
      rotation: toSpins ? spin : _lerp(from.rotation, to.rotation, ringT),
      color: Color.lerp(from.color, toColor, ringT) ?? toColor,
    );
  }
}

/// Paints a [StatusMark]: dashed idle ring, solid arc, and marks.
class _StatusMarkPainter extends CustomPainter {
  _StatusMarkPainter({
    required Listenable repaint,
    required this.transition,
    required this.spin,
    required this.from,
    required this.to,
    required this.toColor,
    required this.toSpins,
    required this.shake,
    required this.curve,
    required this.idleColor,
    required this.strokeWidth,
  }) : super(repaint: repaint);

  final Animation<double> transition;
  final Animation<double> spin;
  final _MarkFrame from;
  final _MarkFrame to;
  final Color toColor;
  final bool toSpins;
  final bool shake;
  final Curve curve;
  final Color idleColor;
  final double strokeWidth;

  /// Fraction of the transition at which the error shake starts.
  static const double _shakeStart = 0.55;

  /// Number of back-and-forth swings in the error shake.
  static const double _shakeSwings = 3.0;

  /// Shake amplitude as a fraction of the glyph size.
  static const double _shakeAmplitude = 0.1;

  /// Fraction of each dash period that is drawn.
  static const double _dashFill = 0.5;

  /// Opacity of the dashed idle ring at full strength.
  static const double _dashAlpha = 0.8;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Paint _dashPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;

  // Mark paths are cached per size.
  double? _cachedSide;
  List<ui.PathMetric> _checkMetrics = <ui.PathMetric>[];
  List<ui.PathMetric> _crossMetrics = <ui.PathMetric>[];

  void _ensurePaths(double side) {
    if (_cachedSide == side) {
      return;
    }
    _cachedSide = side;
    final Path check = Path()
      ..moveTo(0.29 * side, 0.52 * side)
      ..lineTo(0.44 * side, 0.66 * side)
      ..lineTo(0.71 * side, 0.37 * side);
    final Path cross = Path()
      ..moveTo(0.35 * side, 0.35 * side)
      ..lineTo(0.65 * side, 0.65 * side)
      ..moveTo(0.65 * side, 0.35 * side)
      ..lineTo(0.35 * side, 0.65 * side);
    _checkMetrics = check.computeMetrics().toList();
    _crossMetrics = cross.computeMetrics().toList();
  }

  void _drawPartial(Canvas canvas, List<ui.PathMetric> metrics, double t) {
    if (t <= 0.0) {
      return;
    }
    double total = 0.0;
    for (final ui.PathMetric metric in metrics) {
      total += metric.length;
    }
    // Reveal subpaths one after another (a cross has two).
    double remaining = total * t.clamp(0.0, 1.0);
    for (final ui.PathMetric metric in metrics) {
      final double segment = math.min(metric.length, remaining);
      if (segment > 0.0) {
        canvas.drawPath(metric.extractPath(0.0, segment), _stroke);
      }
      remaining -= segment;
      if (remaining <= 0.0) {
        break;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = transition.value;
    final _MarkFrame frame = _MarkFrame.resolve(
      from: from,
      to: to,
      toColor: toColor,
      t: t,
      spin: spin.value,
      toSpins: toSpins,
      curve: curve,
    );
    final double side = math.min(size.width, size.height);
    if (side <= 0.0) {
      return;
    }
    _ensurePaths(side);

    canvas.save();
    double dx = (size.width - side) / 2;
    if (shake && t > _shakeStart && t < 1.0) {
      final double u = (t - _shakeStart) / (1.0 - _shakeStart);
      dx +=
          math.sin(u * math.pi * 2 * _shakeSwings) *
          (1.0 - u) *
          side *
          _shakeAmplitude;
    }
    canvas.translate(dx, (size.height - side) / 2);

    final double radius = math.max(0.0, (side - strokeWidth) / 2);
    final Rect rect = Rect.fromCircle(
      center: Offset(side / 2, side / 2),
      radius: radius,
    );

    if (frame.dash > 0.001 && radius > 0.0) {
      _dashPaint
        ..strokeWidth = strokeWidth
        ..color = idleColor.withValues(
          alpha: idleColor.a * _dashAlpha * frame.dash.clamp(0.0, 1.0),
        );
      final double circumference = 2 * math.pi * radius;
      final int count = math.max(
        6,
        (circumference / (strokeWidth * 3.5)).floor(),
      );
      final double step = 2 * math.pi / count;
      for (int i = 0; i < count; i++) {
        canvas.drawArc(
          rect,
          -math.pi / 2 + i * step,
          step * _dashFill,
          false,
          _dashPaint,
        );
      }
    }

    _stroke
      ..strokeWidth = strokeWidth
      ..color = frame.color;
    if (frame.sweep > 0.001) {
      if (frame.sweep >= 0.999) {
        canvas.drawCircle(rect.center, radius, _stroke);
      } else {
        canvas.drawArc(
          rect,
          -math.pi / 2 + frame.rotation * 2 * math.pi,
          frame.sweep * 2 * math.pi,
          false,
          _stroke,
        );
      }
    }
    _drawPartial(canvas, _checkMetrics, frame.check);
    _drawPartial(canvas, _crossMetrics, frame.cross);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StatusMarkPainter oldDelegate) {
    return oldDelegate.transition != transition ||
        oldDelegate.spin != spin ||
        oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.toColor != toColor ||
        oldDelegate.toSpins != toSpins ||
        oldDelegate.shake != shake ||
        oldDelegate.curve != curve ||
        oldDelegate.idleColor != idleColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
