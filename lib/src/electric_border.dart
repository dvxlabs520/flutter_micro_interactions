import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Crackling strands of electric current that run along the border of any
/// card, button or input.
///
/// ```dart
/// ElectricBorder(
///   color: const Color(0xFF5BC0FF),
///   borderRadius: BorderRadius.circular(16),
///   child: Card(
///     shape: RoundedRectangleBorder(
///       borderRadius: BorderRadius.circular(16),
///     ),
///     child: const Padding(
///       padding: EdgeInsets.all(16),
///       child: Text('Live'),
///     ),
///   ),
/// )
/// ```
///
/// Three jagged strands follow the rounded rectangle given by
/// [borderRadius]. Each one is pushed in and out of the outline by layered
/// noise that keeps changing over time, so the current seems to crawl and
/// flicker. A soft glow sits under a crisp core line, and with [sparks]
/// small sparks jump off the outer edge now and then. [chaos] sets how far
/// the strands stray from the outline and [speed] how fast they change.
///
/// The effect stays on the border: at [chaos] 1 the strands stray at most
/// about 5 logical pixels inwards and 4 outwards, the glow hugs the
/// strands, and nothing is painted more than 10 pixels outside the
/// widget's bounds. Give [borderRadius]
/// the same rounding as the child's own shape so the current lines up with
/// it. The child is never clipped or resized; the effect is painted on top
/// of it.
///
/// Toggle [active] to fade the effect in or out over 300 milliseconds.
/// When it is fully faded out no frames are scheduled.
///
/// The effect is decorative: it ignores pointers and adds no semantics,
/// so the child's own semantics and hit testing are untouched.
///
/// Under reduced motion, or when [enabled] is false, a single frozen frame
/// of the strands is shown without sparks, and no frames are scheduled.
class ElectricBorder extends StatefulWidget {
  /// Creates crackling electric strands around the border of [child].
  const ElectricBorder({
    super.key,
    required this.child,
    this.color,
    this.thickness = 1.5,
    this.chaos = 0.6,
    this.speed = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.sparks = true,
    this.active = true,
    this.enabled = true,
  }) : assert(thickness > 0, 'thickness must be greater than 0'),
       assert(chaos >= 0 && chaos <= 1, 'chaos must be between 0 and 1'),
       assert(speed > 0, 'speed must be greater than 0');

  /// The widget the current runs around, typically a card or button.
  final Widget child;

  /// Color of the current and its glow. Defaults to the
  /// [ColorScheme.primary] of the ambient [Theme], so it matches the app in
  /// light and dark mode. For the classic electric look pass a bright cyan
  /// such as `Color(0xFF5BC0FF)`. On dark themes the core of the main
  /// strand glows towards white.
  final Color? color;

  /// Width of the main strand in logical pixels. Defaults to 1.5. The
  /// other strands are thinner.
  final double thickness;

  /// How far the strands stray from the outline, from 0 (a calm, smooth
  /// line) to 1 (about 5 logical pixels inwards and 4 outwards at most).
  /// Defaults to 0.6.
  final double chaos;

  /// How fast the current changes. 1 is the default pace, 2 is twice as
  /// fast. Must be greater than 0.
  final double speed;

  /// Rounding of the outline the current follows. Defaults to a 16 pixel
  /// circular radius. Use a large radius such as
  /// `BorderRadius.circular(999)` for pill shaped buttons.
  final BorderRadius borderRadius;

  /// Whether small sparks jump off the outer edge from time to time.
  /// Defaults to true.
  final bool sparks;

  /// Whether the effect is shown. Changing it fades the effect in or out
  /// over 300 milliseconds. Defaults to true.
  final bool active;

  /// When false the effect never animates and renders a frozen frame, as
  /// under reduced motion. Defaults to true.
  final bool enabled;

  @override
  State<ElectricBorder> createState() => _ElectricBorderState();
}

class _ElectricBorderState extends State<ElectricBorder>
    with TickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 300);

  late final AnimationController _fadeController;
  late final CurvedAnimation _fade;
  late final Ticker _ticker;
  final _ElectricClock _clock = _ElectricClock();
  Duration _lastElapsed = Duration.zero;

  /// Cached reduce-motion flag, refreshed in [didChangeDependencies].
  bool _reducedMotion = false;

  bool get _canAnimate => widget.enabled && !_reducedMotion;

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(ElectricBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  void _onTick(Duration elapsed) {
    final double dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _clock.advance(dt, widget.speed);
  }

  /// Moves the fade towards the state requested by [ElectricBorder.active].
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
    final _ElectricLook look = _ElectricLook(
      color: widget.color ?? theme.colorScheme.primary,
      dark: theme.brightness == Brightness.dark,
      thickness: widget.thickness,
      chaos: widget.chaos,
      borderRadius: widget.borderRadius,
      sparks: widget.sparks,
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
                  painter: _ElectricPainter(
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
class _ElectricClock extends ChangeNotifier {
  /// Motion time in seconds, already scaled by the speed. Scaling each step
  /// keeps the motion continuous when the speed changes.
  double seconds = 0.0;

  void advance(double dt, double speed) {
    seconds += dt * speed;
    notifyListeners();
  }
}

/// Resolved, immutable configuration for the painter.
@immutable
class _ElectricLook {
  const _ElectricLook({
    required this.color,
    required this.dark,
    required this.thickness,
    required this.chaos,
    required this.borderRadius,
    required this.sparks,
  });

  final Color color;
  final bool dark;
  final double thickness;
  final double chaos;
  final BorderRadius borderRadius;
  final bool sparks;

  @override
  bool operator ==(Object other) =>
      other is _ElectricLook &&
      other.color == color &&
      other.dark == dark &&
      other.thickness == thickness &&
      other.chaos == chaos &&
      other.borderRadius == borderRadius &&
      other.sparks == sparks;

  @override
  int get hashCode =>
      Object.hash(color, dark, thickness, chaos, borderRadius, sparks);
}

/// Sample points and outward normals along the outline for one size.
class _ElectricGeometry {
  _ElectricGeometry(this.size, this.borderRadius, this.thickness) {
    final RRect rrect = borderRadius
        .toRRect(Offset.zero & size)
        .deflate(thickness / 2 + 0.5)
        .scaleRadii();
    final Path outline = Path()..addRRect(rrect);
    final List<ui.PathMetric> metrics = outline.computeMetrics().toList();
    final ui.PathMetric? metric = metrics.isEmpty ? null : metrics.first;
    length = metric?.length ?? 0.0;
    // About one sample every 4 logical pixels.
    count = metric == null ? 0 : math.max(24, (length / 4).round());
    px = Float64List(count);
    py = Float64List(count);
    nx = Float64List(count);
    ny = Float64List(count);
    // Base lattice cells (about 36 pixels each) that fit the perimeter a
    // whole number of times, so the noise wraps seamlessly.
    cells = math.max(3, (length / 36).round());
    for (int i = 0; i < count; i++) {
      final ui.Tangent? t = metric!.getTangentForOffset(length * i / count);
      if (t == null) continue;
      px[i] = t.position.dx;
      py[i] = t.position.dy;
      // Paths built by addRRect run clockwise on screen, so the outward
      // normal is the tangent turned a quarter turn counterclockwise.
      nx[i] = t.vector.dy;
      ny[i] = -t.vector.dx;
    }
  }

  final Size size;
  final BorderRadius borderRadius;
  final double thickness;
  late final double length;
  late final int count;
  late final int cells;
  late final Float64List px;
  late final Float64List py;
  late final Float64List nx;
  late final Float64List ny;

  bool matches(Size s, BorderRadius r, double t) =>
      s == size && r == borderRadius && t == thickness;
}

/// Precomputed lattice values in [-1, 1] for the value noise.
final Float64List _lattice = () {
  final Float64List values = Float64List(256);
  int state = 0x2545F491;
  for (int i = 0; i < 256; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    values[i] = (state / 0x7FFFFFFF) * 2.0 - 1.0;
  }
  return values;
}();

/// A fixed permutation of 0 to 255 used to hash lattice coordinates.
final Uint8List _perm = () {
  final Uint8List p = Uint8List(256);
  for (int i = 0; i < 256; i++) {
    p[i] = i;
  }
  int state = 0x1F123BB5;
  for (int i = 255; i > 0; i--) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    final int j = state % (i + 1);
    final int tmp = p[i];
    p[i] = p[j];
    p[j] = tmp;
  }
  return p;
}();

double _latticeAt(int x, int y, int salt) =>
    _lattice[_perm[(_perm[(x + salt) & 255] + y) & 255]];

/// Smooth 2D value noise in [-1, 1] that repeats every [period] units
/// along x.
double _valueNoise(double x, double y, int period, int salt) {
  final double xf = x.floorToDouble();
  final double yf = y.floorToDouble();
  final double fx = x - xf;
  final double fy = y - yf;
  final int x0 = xf.toInt() % period;
  final int x1 = (x0 + 1) % period;
  final int y0 = yf.toInt();
  final int y1 = y0 + 1;
  final double ux = fx * fx * (3 - 2 * fx);
  final double uy = fy * fy * (3 - 2 * fy);
  final double a = _latticeAt(x0, y0, salt);
  final double b = _latticeAt(x1, y0, salt);
  final double c = _latticeAt(x0, y1, salt);
  final double d = _latticeAt(x1, y1, salt);
  final double top = a + (b - a) * ux;
  final double bottom = c + (d - c) * ux;
  return top + (bottom - top) * uy;
}

/// A cheap, stable pseudo random value in [0, 1) for two integers.
double _electricRandom(int a, int b) {
  final double v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// One strand of current.
class _Strand {
  const _Strand({
    required this.salt,
    required this.amplitude,
    required this.width,
    required this.alpha,
  });

  /// Selects an independent noise field.
  final int salt;

  /// Fraction of the full displacement.
  final double amplitude;

  /// Fraction of the main thickness.
  final double width;

  /// Opacity of the crisp line.
  final double alpha;
}

class _ElectricPainter extends CustomPainter {
  _ElectricPainter({
    required this.clock,
    required this.fade,
    required this.look,
    required this.animate,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, fade]));

  final _ElectricClock clock;
  final Animation<double> fade;
  final _ElectricLook look;
  final bool animate;

  /// Motion time of the frozen frame shown when not animating.
  static const double staticSeconds = 3.7;

  /// Largest displacement from the outline, at chaos 1.
  static const double maxDisplacement = 6.0;

  /// How far, at most, anything is painted outside the bounds.
  static const double maxSpill = 10.0;

  static const List<_Strand> _strands = <_Strand>[
    _Strand(salt: 0, amplitude: 1.0, width: 1.0, alpha: 1.0),
    _Strand(salt: 97, amplitude: 0.85, width: 0.6, alpha: 0.55),
    _Strand(salt: 181, amplitude: 0.7, width: 0.45, alpha: 0.35),
  ];

  static const int _octaves = 5;
  static const int _sparkSlots = 7;

  _ElectricGeometry? _geometry;
  final List<Path> _paths = <Path>[Path(), Path(), Path()];
  final Path _spark = Path();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint();

  /// Main strand offsets of the latest frame, reused by the sparks.
  Float64List _mainOffsets = Float64List(0);

  /// The motion time used for the current frame, in seconds.
  double get seconds => animate ? clock.seconds : staticSeconds;

  /// The current fade value, 0 to 1.
  double get fadeValue => fade.value;

  _ElectricGeometry _geometryFor(Size size) {
    final _ElectricGeometry? cached = _geometry;
    if (cached != null &&
        cached.matches(size, look.borderRadius, look.thickness)) {
      return cached;
    }
    final _ElectricGeometry g = _ElectricGeometry(
      size,
      look.borderRadius,
      look.thickness,
    );
    _mainOffsets = Float64List(g.count);
    return _geometry = g;
  }

  /// Displacement of strand [salt] at sample [i], in [-1, 1].
  double _displacement(_ElectricGeometry g, int i, double t, int salt) {
    double sum = 0.0;
    double amp = 1.0;
    double norm = 0.0;
    int period = g.cells;
    double rate = 1.4;
    for (int o = 0; o < _octaves; o++) {
      final double x = i * period / g.count + t * 0.35;
      sum += amp * _valueNoise(x, t * rate, period, salt + o * 31);
      norm += amp;
      amp *= 0.72;
      period *= 2;
      rate *= 1.8;
    }
    return (sum / norm * 1.8).clamp(-1.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double f = fade.value;
    if (f <= 0.0 || size.isEmpty) return;
    final _ElectricGeometry g = _geometryFor(size);
    final int n = g.count;
    if (n == 0) return;

    final double t = seconds;
    final double reach = maxDisplacement * look.chaos;
    // A gentle flicker of the whole current.
    final double flicker = animate
        ? 0.88 + 0.12 * _valueNoise(t * 9.0, 0.5, 1 << 20, 7)
        : 1.0;
    final double alpha = f * flicker;

    for (int s = 0; s < _strands.length; s++) {
      final _Strand strand = _strands[s];
      final Path path = _paths[s]..reset();
      final double a = reach * strand.amplitude;
      for (int i = 0; i < n; i++) {
        double d = a * _displacement(g, i, t, strand.salt);
        // Stray a little less outwards than inwards, and never the full
        // reach, so the glow keeps hugging the outline.
        d *= d > 0 ? 0.65 : 0.75;
        if (s == 0) _mainOffsets[i] = d;
        final double x = g.px[i] + g.nx[i] * d;
        final double y = g.py[i] + g.ny[i] * d;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    canvas.save();
    canvas.clipRect((Offset.zero & size).inflate(maxSpill));

    final Color color = look.color;
    final double th = look.thickness;
    final Path main = _paths[0];

    // Wide soft glow.
    _stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..strokeWidth = th * 2.5
      ..color = color.withValues(alpha: (look.dark ? 0.7 : 0.45) * alpha);
    canvas.drawPath(main, _stroke);
    // Tight glow close to the core.
    _stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
      ..strokeWidth = th * 1.6
      ..color = color.withValues(alpha: (look.dark ? 0.8 : 0.5) * alpha);
    canvas.drawPath(main, _stroke);
    _stroke.maskFilter = null;

    // Secondary strands.
    for (int s = _strands.length - 1; s >= 1; s--) {
      final _Strand strand = _strands[s];
      _stroke
        ..strokeWidth = math.max(0.6, th * strand.width)
        ..color = color.withValues(alpha: strand.alpha * alpha);
      canvas.drawPath(_paths[s], _stroke);
    }

    // Crisp main strand with a hot core.
    _stroke
      ..strokeWidth = th
      ..color = color.withValues(alpha: alpha);
    canvas.drawPath(main, _stroke);
    if (look.dark) {
      _stroke
        ..strokeWidth = math.max(0.5, th * 0.45)
        ..color = Color.lerp(
          color,
          const Color(0xFFFFFFFF),
          0.8,
        )!.withValues(alpha: 0.85 * alpha);
      canvas.drawPath(main, _stroke);
    }

    if (look.sparks && animate) _paintSparks(canvas, g, t, alpha);
    canvas.restore();
  }

  void _paintSparks(
    Canvas canvas,
    _ElectricGeometry g,
    double t,
    double alpha,
  ) {
    const double life = 0.32;
    final Color hot = look.dark
        ? Color.lerp(look.color, const Color(0xFFFFFFFF), 0.7)!
        : look.color;
    for (int j = 0; j < _sparkSlots; j++) {
      final double period = 0.9 + _electricRandom(j, 3) * 1.1;
      final double local = t / period + _electricRandom(j, 4);
      final int generation = local.floor();
      final double phase = (local - generation) * period;
      if (phase > life) continue;
      final int seed = generation * 53 + j * 977;
      if (_electricRandom(seed, 1) > 0.7) continue;
      final double age = phase / life;

      final int i = (_electricRandom(seed, 2) * g.count).floor() % g.count;
      final double nx = g.nx[i];
      final double ny = g.ny[i];
      // Tangent, a quarter turn clockwise from the outward normal.
      final double tx = -ny;
      final double ty = nx;
      final double startOut = math.max(0.0, _mainOffsets[i]);
      final double room = maxSpill - 3.0 - startOut;
      if (room < 2.0) continue;
      final double reach =
          math.min(room, 4.0 + _electricRandom(seed, 3) * 4.0) *
          (1.0 - (1.0 - age) * (1.0 - age) * (1.0 - age));
      final double lean = (_electricRandom(seed, 4) - 0.5) * 1.2;

      _spark.reset();
      final double ox = g.px[i] + nx * startOut;
      final double oy = g.py[i] + ny * startOut;
      _spark.moveTo(ox, oy);
      double ex = ox;
      double ey = oy;
      for (int k = 1; k <= 3; k++) {
        final double along = reach * k / 3;
        final double jag =
            (k == 3 ? 0.0 : (_electricRandom(seed, 10 + k) - 0.5) * 4.0) +
            lean * along;
        ex = ox + nx * along + tx * jag;
        ey = oy + ny * along + ty * jag;
        _spark.lineTo(ex, ey);
      }
      final double fadeOut = 1.0 - age * age * age;
      _stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..strokeWidth = look.thickness * 1.8
        ..color = look.color.withValues(alpha: 0.8 * fadeOut * alpha);
      canvas.drawPath(_spark, _stroke);
      _stroke
        ..maskFilter = null
        ..strokeWidth = math.max(0.7, look.thickness * 0.6)
        ..color = hot.withValues(alpha: fadeOut * alpha);
      canvas.drawPath(_spark, _stroke);
      _fill.color = hot.withValues(alpha: fadeOut * alpha);
      canvas.drawCircle(
        Offset(ex, ey),
        math.max(0.7, look.thickness * 0.55),
        _fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ElectricPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.animate != animate ||
      oldDelegate.clock != clock ||
      oldDelegate.fade != fade;
}
