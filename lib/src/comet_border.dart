import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// A twinkling star that travels around the border of any card, button or
/// chip, trailing a fading tail of light and a little stardust.
///
/// ```dart
/// CometBorder(
///   borderRadius: BorderRadius.circular(16),
///   child: Card(
///     shape: RoundedRectangleBorder(
///       borderRadius: BorderRadius.circular(16),
///     ),
///     child: const Padding(
///       padding: EdgeInsets.all(16),
///       child: Text('Featured'),
///     ),
///   ),
/// )
/// ```
///
/// The star follows the exact outline of the rounded rectangle given by
/// [borderRadius] at a constant speed, corners included, and completes one
/// lap every [duration]. Behind it a tail of light covers [tailLength] of
/// the outline and fades towards its end. Tiny specks of stardust drift
/// off the head and fade away. With [showTrack] a faint full outline marks
/// the path. Use [cometCount] to send several evenly spaced comets around
/// the border.
///
/// The effect stays on the border: the stroke sits just inside the
/// widget's bounds and only a soft glow, a few pixels wide, extends past
/// the stroke on either side. Give [borderRadius] the same rounding as the
/// child's own shape so the comet lines up with it. The child is never
/// clipped or resized; the effect is painted on top of it.
///
/// Toggle [active] to fade the effect in or out over 300 milliseconds.
/// When it is fully faded out no frames are scheduled.
///
/// The effect is decorative: it ignores pointers and adds no semantics,
/// so the child's own semantics and hit testing are untouched.
///
/// Under reduced motion, or when [enabled] is false, the comet rests at
/// the top left corner with its tail and the faint track, and no frames
/// are scheduled.
class CometBorder extends StatefulWidget {
  /// Creates a comet that travels around the border of [child].
  const CometBorder({
    super.key,
    required this.child,
    this.color,
    this.tailLength = 0.25,
    this.thickness = 1.5,
    this.duration = const Duration(seconds: 4),
    this.cometCount = 1,
    this.clockwise = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showTrack = true,
    this.twinkle = true,
    this.active = true,
    this.enabled = true,
  }) : assert(
         tailLength > 0 && tailLength <= 1,
         'tailLength must be greater than 0 and at most 1',
       ),
       assert(thickness > 0, 'thickness must be greater than 0'),
       assert(
         cometCount >= 1 && cometCount <= 8,
         'cometCount must be between 1 and 8',
       );

  /// The widget the comet travels around, typically a card or button.
  final Widget child;

  /// Color of the comet, its tail, its stardust and the track. Defaults
  /// to the [ColorScheme.primary] of the ambient [Theme]. On dark themes
  /// the head and the front of the tail glow towards white.
  final Color? color;

  /// Length of the tail as a fraction of the outline's length, from just
  /// above 0 to 1. Defaults to 0.25. With several comets the tail is
  /// shortened so that it never reaches the comet behind it.
  final double tailLength;

  /// Width of the tail stroke in logical pixels. Defaults to 1.5. Values
  /// between 1.5 and 2 suit most cards.
  final double thickness;

  /// Time for one full lap around the border. Must be greater than zero.
  /// Defaults to 4 seconds.
  final Duration duration;

  /// Number of comets, evenly spaced around the border. Defaults to 1.
  final int cometCount;

  /// Whether the comets travel clockwise. Defaults to true.
  final bool clockwise;

  /// Rounding of the outline the comet follows. Defaults to a 16 pixel
  /// circular radius. Use a large radius such as
  /// `BorderRadius.circular(999)` for pill shaped buttons.
  final BorderRadius borderRadius;

  /// Whether a faint full outline is drawn under the comet. Defaults to
  /// true.
  final bool showTrack;

  /// Whether the head twinkles: its star grows, shrinks and turns slowly.
  /// Defaults to true.
  final bool twinkle;

  /// Whether the effect is shown. Changing it fades the effect in or out
  /// over 300 milliseconds. Defaults to true.
  final bool active;

  /// When false the effect never animates and renders a static frame, as
  /// under reduced motion. Defaults to true.
  final bool enabled;

  @override
  State<CometBorder> createState() => _CometBorderState();
}

class _CometBorderState extends State<CometBorder>
    with TickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 300);

  late final AnimationController _fadeController;
  late final CurvedAnimation _fade;
  late final Ticker _ticker;
  final _CometClock _clock = _CometClock();
  Duration _lastElapsed = Duration.zero;

  /// Cached reduce-motion flag, refreshed in [didChangeDependencies].
  bool _reducedMotion = false;

  bool get _canAnimate => widget.enabled && !_reducedMotion;

  double get _lapSeconds =>
      math.max(widget.duration.inMicroseconds, 1) /
      Duration.microsecondsPerSecond;

  @override
  void initState() {
    super.initState();
    _checkDuration();
    _fadeController = AnimationController(
      vsync: this,
      value: widget.active ? 1.0 : 0.0,
      duration: _fadeDuration,
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _syncActive();
  }

  @override
  void didUpdateWidget(CometBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkDuration();
    if (widget.active != oldWidget.active ||
        widget.enabled != oldWidget.enabled) {
      _syncActive();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _fadeController.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _checkDuration() {
    assert(
      widget.duration > Duration.zero,
      'duration must be greater than zero',
    );
  }

  void _onTick(Duration elapsed) {
    final double dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _clock.advance(dt, _lapSeconds);
  }

  /// Moves the fade towards the state requested by [CometBorder.active].
  void _syncActive() {
    final double target = widget.active ? 1.0 : 0.0;
    if (!_canAnimate) {
      if (_fadeController.isAnimating || _fadeController.value != target) {
        _fadeController.value = target;
      }
    } else if (_fadeController.value != target) {
      final TickerFuture fade = widget.active
          ? _fadeController.forward()
          : _fadeController.reverse();
      fade.then((_) {
        if (mounted) _syncMotion();
      });
    }
    _syncMotion();
  }

  /// Runs the motion ticker while something is visible.
  void _syncMotion() {
    final bool run =
        _canAnimate && (widget.active || _fadeController.value > 0.0);
    if (run && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _CometLook look = _CometLook(
      color: widget.color ?? theme.colorScheme.primary,
      dark: theme.brightness == Brightness.dark,
      tailLength: math.min(widget.tailLength, 0.92 / widget.cometCount),
      thickness: widget.thickness,
      lapSeconds: _lapSeconds,
      cometCount: widget.cometCount,
      clockwise: widget.clockwise,
      borderRadius: widget.borderRadius,
      showTrack: widget.showTrack,
      twinkle: widget.twinkle,
    );
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CometPainter(
                    clock: _clock,
                    fade: _fade,
                    look: look,
                    animate: _canAnimate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Elapsed motion time shared with the painter.
class _CometClock extends ChangeNotifier {
  /// Wall clock seconds of motion, used for twinkling and stardust.
  double seconds = 0.0;

  /// Motion time in laps. Counting laps keeps the motion continuous when
  /// the duration changes.
  double laps = 0.0;

  void advance(double dt, double lapSeconds) {
    seconds += dt;
    laps += dt / lapSeconds;
    notifyListeners();
  }
}

/// Resolved, immutable configuration for the painter.
@immutable
class _CometLook {
  const _CometLook({
    required this.color,
    required this.dark,
    required this.tailLength,
    required this.thickness,
    required this.lapSeconds,
    required this.cometCount,
    required this.clockwise,
    required this.borderRadius,
    required this.showTrack,
    required this.twinkle,
  });

  final Color color;
  final bool dark;
  final double tailLength;
  final double thickness;
  final double lapSeconds;
  final int cometCount;
  final bool clockwise;
  final BorderRadius borderRadius;
  final bool showTrack;
  final bool twinkle;

  @override
  bool operator ==(Object other) =>
      other is _CometLook &&
      other.color == color &&
      other.dark == dark &&
      other.tailLength == tailLength &&
      other.thickness == thickness &&
      other.lapSeconds == lapSeconds &&
      other.cometCount == cometCount &&
      other.clockwise == clockwise &&
      other.borderRadius == borderRadius &&
      other.showTrack == showTrack &&
      other.twinkle == twinkle;

  @override
  int get hashCode => Object.hash(
    color,
    dark,
    tailLength,
    thickness,
    lapSeconds,
    cometCount,
    clockwise,
    borderRadius,
    showTrack,
    twinkle,
  );
}

/// Builds a closed rounded rectangle outline that starts where the top
/// edge leaves the top left corner and runs clockwise.
Path _cometOutline(RRect r) {
  final Path path = Path()..moveTo(r.left + r.tlRadiusX, r.top);
  path.lineTo(r.right - r.trRadiusX, r.top);
  if (r.trRadiusX > 0 && r.trRadiusY > 0) {
    path.arcTo(
      Rect.fromLTWH(
        r.right - 2 * r.trRadiusX,
        r.top,
        2 * r.trRadiusX,
        2 * r.trRadiusY,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
    );
  }
  path.lineTo(r.right, r.bottom - r.brRadiusY);
  if (r.brRadiusX > 0 && r.brRadiusY > 0) {
    path.arcTo(
      Rect.fromLTWH(
        r.right - 2 * r.brRadiusX,
        r.bottom - 2 * r.brRadiusY,
        2 * r.brRadiusX,
        2 * r.brRadiusY,
      ),
      0,
      math.pi / 2,
      false,
    );
  }
  path.lineTo(r.left + r.blRadiusX, r.bottom);
  if (r.blRadiusX > 0 && r.blRadiusY > 0) {
    path.arcTo(
      Rect.fromLTWH(
        r.left,
        r.bottom - 2 * r.blRadiusY,
        2 * r.blRadiusX,
        2 * r.blRadiusY,
      ),
      math.pi / 2,
      math.pi / 2,
      false,
    );
  }
  path.lineTo(r.left, r.top + r.tlRadiusY);
  if (r.tlRadiusX > 0 && r.tlRadiusY > 0) {
    path.arcTo(
      Rect.fromLTWH(r.left, r.top, 2 * r.tlRadiusX, 2 * r.tlRadiusY),
      math.pi,
      math.pi / 2,
      false,
    );
  }
  path.close();
  return path;
}

/// Outline geometry for one size, cached by the painter.
class _CometGeometry {
  _CometGeometry(this.size, this.borderRadius, this.thickness) {
    final RRect rrect = borderRadius
        .toRRect(Offset.zero & size)
        .deflate(thickness / 2)
        .scaleRadii();
    outline = _cometOutline(rrect);
    final List<ui.PathMetric> metrics = outline.computeMetrics().toList();
    metric = metrics.isEmpty ? null : metrics.first;
    length = metric?.length ?? 0.0;
    center = size.center(Offset.zero);
  }

  final Size size;
  final BorderRadius borderRadius;
  final double thickness;
  late final Path outline;
  late final ui.PathMetric? metric;
  late final double length;
  late final Offset center;

  bool matches(Size s, BorderRadius r, double t) =>
      s == size && r == borderRadius && t == thickness;
}

/// A cheap, stable pseudo random value in [0, 1) for two integers.
double _cometRandom(int a, int b) {
  final double v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

class _CometPainter extends CustomPainter {
  _CometPainter({
    required this.clock,
    required this.fade,
    required this.look,
    required this.animate,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, fade]));

  final _CometClock clock;
  final Animation<double> fade;
  final _CometLook look;
  final bool animate;

  /// Number of color stops sampled along a tail.
  static const int _tailSamples = 24;

  /// Stardust specks kept alive per comet.
  static const int _dustSlots = 10;

  /// Lifetime of one stardust speck, in seconds.
  static const double _dustLife = 1.1;

  _CometGeometry? _geometry;

  final Paint _trackPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint();
  final Path _star = Path();
  final List<Color> _colors = List<Color>.filled(
    _tailSamples + 2,
    const Color(0x00000000),
  );
  final List<Color> _glowColors = List<Color>.filled(
    _tailSamples + 2,
    const Color(0x00000000),
  );
  final List<double> _stops = List<double>.filled(_tailSamples + 2, 0.0);
  final Float64List _angles = Float64List(_tailSamples);
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  /// Progress of the first comet along its lap, 0 to 1. It is 0 in the
  /// static frame.
  double get headProgress =>
      animate ? clock.laps - clock.laps.floorToDouble() : 0.0;

  /// The current fade value, 0 to 1.
  double get fadeValue => fade.value;

  _CometGeometry _geometryFor(Size size) {
    final _CometGeometry? cached = _geometry;
    if (cached != null &&
        cached.matches(size, look.borderRadius, look.thickness)) {
      return cached;
    }
    return _geometry = _CometGeometry(size, look.borderRadius, look.thickness);
  }

  /// The highlight color the head and the front of the tail lean towards.
  Color get _hot => look.dark
      ? Color.lerp(look.color, const Color(0xFFFFFFFF), 0.85)!
      : look.color;

  @override
  void paint(Canvas canvas, Size size) {
    final double f = fade.value;
    if (f <= 0.0 || size.isEmpty) return;
    final _CometGeometry g = _geometryFor(size);
    final ui.PathMetric? metric = g.metric;
    if (metric == null || g.length <= 0) return;

    if (look.showTrack) {
      _trackPaint
        ..strokeWidth = math.max(1.0, look.thickness * 0.75)
        ..color = look.color.withValues(alpha: (look.dark ? 0.16 : 0.2) * f);
      canvas.drawPath(g.outline, _trackPaint);
    }

    final double t = animate ? clock.seconds : 0.0;
    final double progress = headProgress;
    for (int k = 0; k < look.cometCount; k++) {
      final double lap = progress + k / look.cometCount;
      final double signed = look.clockwise ? lap : -lap;
      final double head = (signed - signed.floorToDouble()) * g.length;
      _paintTail(canvas, g, metric, head, f);
      if (animate) _paintDust(canvas, g, metric, k, f);
      _paintHead(canvas, metric, head, t + k * 1.7, f);
    }
  }

  double _wrap(double d, double length) {
    final double r = d % length;
    return r < 0 ? r + length : r;
  }

  void _paintTail(
    Canvas canvas,
    _CometGeometry g,
    ui.PathMetric metric,
    double head,
    double f,
  ) {
    final double length = g.length;
    final double tail = look.tailLength * length;
    if (tail < 1.0) return;
    // The tail runs from start to end in path order; one of the two ends is
    // the head.
    final double start = look.clockwise ? head - tail : head;
    final double end = look.clockwise ? head : head + tail;

    final Path path;
    if (start < 0) {
      path = metric.extractPath(start + length, length)
        ..extendWithPath(metric.extractPath(0, end), Offset.zero);
    } else if (end > length) {
      path = metric.extractPath(start, length)
        ..extendWithPath(metric.extractPath(0, end - length), Offset.zero);
    } else {
      path = metric.extractPath(start, end);
    }

    // Color along the tail follows the angle seen from the center, which
    // grows steadily along a convex outline. A sweep gradient with a stop
    // per sample then shades the tail by distance along the path.
    final Offset c = g.center;
    final Color hot = _hot;
    double previous = 0.0;
    for (int i = 0; i < _tailSamples; i++) {
      final double s = i / (_tailSamples - 1);
      final ui.Tangent? tangent = metric.getTangentForOffset(
        _wrap(start + s * tail, length),
      );
      final Offset p = tangent?.position ?? c;
      double a = math.atan2(p.dy - c.dy, p.dx - c.dx);
      if (i > 0) {
        while (a < previous - 1e-9) {
          a += 2 * math.pi;
        }
      }
      _angles[i] = a;
      previous = a;

      // u is 0 at the end of the tail and 1 at the head.
      final double u = look.clockwise ? s : 1.0 - s;
      final double core = math.pow(u, 1.7).toDouble();
      final double heat = math.pow(u, 7).toDouble() * 0.8;
      _colors[i + 1] = Color.lerp(
        look.color,
        hot,
        heat,
      )!.withValues(alpha: core * f);
      _glowColors[i + 1] = look.color.withValues(
        alpha: math.pow(u, 1.3).toDouble() * (look.dark ? 0.55 : 0.4) * f,
      );
    }
    final double span = _angles[_tailSamples - 1] - _angles[0];
    final double base = _angles[0] - (2 * math.pi - span) / 2;
    _stops[0] = 0.0;
    for (int i = 0; i < _tailSamples; i++) {
      _stops[i + 1] = ((_angles[i] - base) / (2 * math.pi)).clamp(0.0, 1.0);
    }
    _stops[_tailSamples + 1] = 1.0;
    _colors[0] = _colors[1];
    _colors[_tailSamples + 1] = _colors[_tailSamples];
    _glowColors[0] = _glowColors[1];
    _glowColors[_tailSamples + 1] = _glowColors[_tailSamples];

    final double cs = math.cos(base);
    final double sn = math.sin(base);
    _matrix
      ..[0] = cs
      ..[1] = sn
      ..[4] = -sn
      ..[5] = cs
      ..[12] = c.dx - (cs * c.dx - sn * c.dy)
      ..[13] = c.dy - (sn * c.dx + cs * c.dy);

    _glowPaint
      ..strokeWidth = look.thickness * 3.0
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        1.6 + look.thickness * 0.8,
      )
      ..shader = ui.Gradient.sweep(
        c,
        _glowColors,
        _stops,
        TileMode.clamp,
        0.0,
        2 * math.pi,
        _matrix,
      );
    canvas.drawPath(path, _glowPaint);

    _corePaint
      ..strokeWidth = look.thickness
      ..shader = ui.Gradient.sweep(
        c,
        _colors,
        _stops,
        TileMode.clamp,
        0.0,
        2 * math.pi,
        _matrix,
      );
    canvas.drawPath(path, _corePaint);
  }

  /// Size factor of a head at time [t]: twinkles between about 0.7 and 1.3.
  double _pulse(double t) {
    if (!look.twinkle) return 1.0;
    return 1.0 +
        0.2 * math.sin(t * 2 * math.pi * 1.1) +
        0.1 * math.sin(t * 2 * math.pi * 2.9 + 1.3);
  }

  void _paintHead(
    Canvas canvas,
    ui.PathMetric metric,
    double head,
    double t,
    double f,
  ) {
    final ui.Tangent? tangent = metric.getTangentForOffset(
      _wrap(head, metric.length),
    );
    if (tangent == null) return;
    final Offset p = tangent.position;
    final double pulse = _pulse(t);
    final double th = look.thickness;
    final Color hot = _hot;

    // Soft halo hugging the stroke.
    final double halo = (th * 2.0 + 5.0) * (0.9 + 0.1 * pulse);
    _fill
      ..color = const Color(0xFF000000)
      ..shader = ui.Gradient.radial(
        p,
        halo,
        <Color>[
          look.color.withValues(alpha: (look.dark ? 0.75 : 0.5) * f),
          look.color.withValues(alpha: (look.dark ? 0.3 : 0.2) * f),
          look.color.withValues(alpha: (look.dark ? 0.08 : 0.05) * f),
          look.color.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.3, 0.65, 1.0],
      );
    canvas.drawCircle(p, halo, _fill);

    // Four pointed sparkle: long horizontal and vertical rays, shorter
    // diagonal ones, all tapering to fine points.
    final double ray = (th * 2.0 + 4.5) * pulse;
    final double waist = math.max(0.9, th * 0.6);
    final double turn = look.twinkle ? t * 0.8 : 0.0;
    _star.reset();
    for (int i = 0; i < 16; i++) {
      final double a = turn + i * math.pi / 8;
      final double r = switch (i % 4) {
        0 => i % 8 == 0 ? ray : ray * 0.85,
        2 => ray * 0.42,
        _ => waist,
      };
      final double x = p.dx + math.cos(a) * r;
      final double y = p.dy + math.sin(a) * r;
      if (i == 0) {
        _star.moveTo(x, y);
      } else {
        _star.lineTo(x, y);
      }
    }
    _star.close();
    _fill.shader = ui.Gradient.radial(
      p,
      ray,
      <Color>[
        hot.withValues(alpha: f),
        hot.withValues(alpha: 0.9 * f),
        look.color.withValues(alpha: 0.35 * f),
      ],
      const <double>[0.0, 0.3, 1.0],
    );
    canvas.drawPath(_star, _fill);

    // Bright core.
    _fill
      ..shader = null
      ..color = const Color(0xFFFFFFFF).withValues(alpha: f);
    canvas.drawCircle(p, th * 0.8 * (0.85 + 0.15 * pulse), _fill);
  }

  void _paintDust(
    Canvas canvas,
    _CometGeometry g,
    ui.PathMetric metric,
    int comet,
    double f,
  ) {
    final double length = g.length;
    final double dir = look.clockwise ? 1.0 : -1.0;
    final double seconds = clock.seconds;
    final Color hot = _hot;
    for (int j = 0; j < _dustSlots; j++) {
      final double local = seconds / _dustLife + j / _dustSlots;
      final int generation = local.floor();
      final double age = local - generation;
      final int seed = generation * 131 + j * 17 + comet * 7919;
      if (_cometRandom(seed, 1) > 0.8) continue;

      // Where the head was when this speck was born.
      final double bornLaps =
          clock.laps +
          comet / look.cometCount -
          age * _dustLife / look.lapSeconds;
      final double lap = bornLaps - bornLaps.floorToDouble();
      final double back = 2.0 + _cometRandom(seed, 2) * 10.0;
      final double d = (look.clockwise ? lap : 1.0 - lap) * length - dir * back;
      final ui.Tangent? tangent = metric.getTangentForOffset(_wrap(d, length));
      if (tangent == null) continue;

      final double ease = 1.0 - (1.0 - age) * (1.0 - age);
      final double side = _cometRandom(seed, 3) < 0.5 ? -1.0 : 1.0;
      final double drift = side * (1.0 + _cometRandom(seed, 4) * 4.0) * ease;
      final double trail = -dir * _cometRandom(seed, 5) * 5.0 * ease;
      final Offset v = tangent.vector;
      final Offset normal = Offset(v.dy, -v.dx);
      final Offset p = tangent.position + normal * drift + v * trail;

      final double flicker =
          0.6 + 0.4 * math.sin(seconds * 17.0 + _cometRandom(seed, 6) * 6.3);
      final double alpha = math.pow(1.0 - age, 1.4).toDouble() * flicker * f;
      final double radius =
          (0.45 + _cometRandom(seed, 7) * 0.75) * (1.0 - 0.5 * age);
      _fill
        ..shader = null
        ..color = Color.lerp(
          look.color,
          hot,
          0.5,
        )!.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(p, radius, _fill);
    }
  }

  @override
  bool shouldRepaint(_CometPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.animate != animate ||
      oldDelegate.clock != clock ||
      oldDelegate.fade != fade;
}
