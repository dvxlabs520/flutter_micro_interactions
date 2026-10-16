// ThinkingOrb is a Flutter port of "Thinking orbs" (https://libraries.dev)
// by Jakub Antalik, released under the MIT license.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// The activity a [ThinkingOrb] depicts.
///
/// Each value selects a different dotted animation and carries a default
/// accessibility [label].
enum ThinkingOrbState {
  /// Particles travel along tilted orbits around a dotted core.
  working('Working...'),

  /// A dotted globe spins while a bright scan line sweeps across it.
  searching('Searching...'),

  /// A dotted sphere turns slabs like a puzzle cube, then undoes them.
  solving('Solving...'),

  /// The rings of a dotted sphere swell in a travelling wave.
  listening('Listening...'),

  /// A wandering web of nodes and links carries small signal packets.
  connecting('Connecting...'),

  /// Three dotted strands braid around a faint sphere.
  weaving('Weaving...'),

  /// A wavy band of dots wraps around a faint sphere.
  composing('Composing...'),

  /// A thick dotted ring breathes with gentle travelling waves.
  thinking('Thinking...'),

  /// A dotted outline morphs from circle to triangle to square.
  shaping('Shaping...');

  const ThinkingOrbState(this.label);

  /// Default accessibility label announced for this state, for example
  /// `Working...`.
  final String label;
}

/// A dotted, monochrome pseudo-3D "thought orb" that replaces a spinner in
/// AI interfaces.
///
/// ```dart
/// ThinkingOrb(
///   state: ThinkingOrbState.searching,
///   size: 48,
/// )
/// ```
///
/// The orb is drawn with filled circles and straight lines only. Depth comes
/// from dot size and ink weight: dots closer to the viewer are larger and
/// darker, dots further away are smaller and lighter. Each
/// [ThinkingOrbState] has its own animation (orbits, a scanning globe, a
/// turning puzzle sphere, a wave, a node web, a braid, a ribbon, a
/// breathing ring and a morphing outline). Changing [state] crossfades
/// between the two animations over [transitionDuration].
///
/// Two tunings exist: orbs of 40 logical pixels or more use a detailed
/// tuning, smaller orbs use a sparser tuning with bolder dots so they stay
/// readable at icon sizes.
///
/// The ink defaults to the theme's `colorScheme.onSurface`, so the orb works
/// on light and dark backgrounds. Lighter ink is produced with transparency,
/// never with blend modes.
///
/// Accessibility: the orb is exposed as a single semantics node labelled
/// with [semanticLabel], or the state's default [ThinkingOrbState.label]
/// when no label is given.
///
/// Reduced motion and `enabled: false`: the orb renders one static frame
/// and schedules no animation frames. State changes then switch instantly.
class ThinkingOrb extends StatefulWidget {
  /// Creates a thinking orb.
  const ThinkingOrb({
    super.key,
    this.state = ThinkingOrbState.working,
    this.size = 64,
    this.speed = 1,
    this.color,
    this.enabled = true,
    this.semanticLabel,
    this.transitionDuration = const Duration(milliseconds: 250),
  }) : assert(size > 0, 'size must be greater than 0'),
       assert(speed >= 0, 'speed must not be negative');

  /// Which animation the orb shows. Defaults to [ThinkingOrbState.working].
  final ThinkingOrbState state;

  /// Width and height of the orb in logical pixels. Defaults to 64. Sizes
  /// below 40 use the compact tuning.
  final double size;

  /// Playback speed multiplier. 1 is the designed tempo, 2 is twice as
  /// fast, 0 freezes the current frame. Defaults to 1.
  final double speed;

  /// Ink color of the dots and lines. Defaults to the theme's
  /// `colorScheme.onSurface`.
  final Color? color;

  /// When false the orb renders a static frame and does not animate.
  /// Defaults to true.
  final bool enabled;

  /// Label announced by assistive technology. Defaults to the current
  /// state's [ThinkingOrbState.label].
  final String? semanticLabel;

  /// Length of the crossfade when [state] changes. Defaults to 250
  /// milliseconds. [Duration.zero] switches instantly.
  final Duration transitionDuration;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

/// Elapsed seconds used for the static frame (reduced motion, disabled).
const double _staticSeconds = 0.6;

class _ThinkingOrbState extends State<ThinkingOrb>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _fade;
  final ValueNotifier<double> _clock = ValueNotifier<double>(_staticSeconds);

  /// Accumulated, speed-scaled seconds.
  double _seconds = _staticSeconds;
  Duration _lastElapsed = Duration.zero;
  ThinkingOrbState? _previous;
  bool _reducedMotion = false;

  bool get _isStatic => !widget.enabled || _reducedMotion;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _fade = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionDuration != oldWidget.transitionDuration) {
      _fade.duration = widget.transitionDuration;
    }
    if (widget.state != oldWidget.state) {
      if (_isStatic || widget.transitionDuration == Duration.zero) {
        _previous = null;
        _fade.value = 1.0;
      } else {
        _previous = oldWidget.state;
        _fade.forward(from: 0.0);
      }
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// Starts or stops the ticker to match the current configuration.
  void _sync() {
    if (_isStatic) {
      if (_ticker.isActive) _ticker.stop();
      if (_fade.isAnimating) _fade.stop();
      _fade.value = 1.0;
      _previous = null;
      _seconds = _staticSeconds;
      _clock.value = _staticSeconds;
      return;
    }
    if (widget.speed > 0) {
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final double dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _seconds += dt * widget.speed;
    _clock.value = _seconds;
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: widget.semanticLabel ?? widget.state.label,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ThinkingOrbPainter(
            clock: _clock,
            fade: _fade,
            state: widget.state,
            previous: _previous,
            color: ink,
            compact: widget.size < 40,
          ),
        ),
      ),
    );
  }
}

class _ThinkingOrbPainter extends CustomPainter {
  _ThinkingOrbPainter({
    required this.clock,
    required this.fade,
    required this.state,
    required this.previous,
    required this.color,
    required this.compact,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, fade]));

  /// Speed-scaled elapsed seconds.
  final ValueListenable<double> clock;

  /// Crossfade progress from [previous] to [state], 1 when settled.
  final Animation<double> fade;

  /// The state being shown.
  final ThinkingOrbState state;

  /// The state fading out, if any.
  final ThinkingOrbState? previous;

  /// Ink color.
  final Color color;

  /// Whether the compact (small size) tuning is used.
  final bool compact;

  /// Reused per-frame buffer shared by every painter (painting is
  /// synchronous, so one buffer is enough).
  static final _OrbBuffer _buffer = _OrbBuffer();

  static final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final double f = fade.value.clamp(0.0, 1.0);
    final ThinkingOrbState? from = previous;
    if (from != null && f < 1.0) {
      _drawScene(canvas, from, s, 1.0 - f);
      _drawScene(canvas, state, s, f);
    } else {
      _drawScene(canvas, state, s, 1.0);
    }
    canvas.restore();
  }

  void _drawScene(Canvas canvas, ThinkingOrbState which, double s, double m) {
    if (m <= 0) return;
    final _OrbScene scene = _OrbScene.of(which, compact);
    final _OrbBuffer buffer = _buffer..clear();
    scene.render(clock.value * scene.speed, s, buffer);
    buffer.paint(canvas, _paint, color, m);
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbPainter oldDelegate) {
    return oldDelegate.clock != clock ||
        oldDelegate.fade != fade ||
        oldDelegate.state != state ||
        oldDelegate.previous != previous ||
        oldDelegate.color != color ||
        oldDelegate.compact != compact;
  }
}

// ---------------------------------------------------------------------------
// Engine helpers
// ---------------------------------------------------------------------------

/// Minimum dot radius after scaling.
const double _rMin = 0.3;

/// Dots fainter than this are skipped.
const double _alphaCutoff = 0.02;

const double _tau = 2 * math.pi;

double _fract(double v) => v - v.floorToDouble();

double _hash(double a, double b) =>
    _fract(math.sin(a * 12.9898 + b * 78.233) * 43758.5453);

double _smooth(double x) => x * x * (3 - 2 * x);

/// Bilinear value noise in [0, 1].
double _noise(double x, double y) {
  final double ix = x.floorToDouble();
  final double iy = y.floorToDouble();
  final double u = _smooth(x - ix);
  final double v = _smooth(y - iy);
  final double a = _hash(ix, iy);
  final double b = _hash(ix + 1, iy);
  final double c = _hash(ix, iy + 1);
  final double d = _hash(ix + 1, iy + 1);
  final double top = a + (b - a) * u;
  final double bottom = c + (d - c) * u;
  return top + (bottom - top) * v;
}

/// Dot radius scale for a canvas of side [s].
double _radiusScale(double s) => math.pow(s / 300, 0.6).toDouble();

/// Unit Fibonacci sphere, packed as x, y, z triples.
Float64List _fibonacci(int n) {
  final Float64List out = Float64List(n * 3);
  final double golden = math.pi * (3 - math.sqrt(5));
  for (int i = 0; i < n; i++) {
    final double y = 1 - 2 * (i + 0.5) / n;
    final double r = math.sqrt(math.max(0.0, 1 - y * y));
    final double a = i * golden;
    out[i * 3] = math.cos(a) * r;
    out[i * 3 + 1] = y;
    out[i * 3 + 2] = math.sin(a) * r;
  }
  return out;
}

/// Latitude rings on a unit sphere, packed as x, y, z triples, with the
/// ring index of every dot.
class _Lattice {
  _Lattice(int rings, int lonDensity) {
    final List<double> pts = <double>[];
    final List<int> ringOf = <int>[];
    final List<double> lons = <double>[];
    for (int j = 0; j < rings; j++) {
      final double lat = rings == 1
          ? 0.0
          : -math.pi / 2 + math.pi * j / (rings - 1);
      final double c = math.cos(lat);
      final int count = math.max(1, (c.abs() * lonDensity).round());
      for (int k = 0; k < count; k++) {
        final double lon = _tau * k / count;
        pts
          ..add(c * math.cos(lon))
          ..add(math.sin(lat))
          ..add(c * math.sin(lon));
        ringOf.add(j);
        lons.add(lon);
      }
    }
    points = Float64List.fromList(pts);
    ring = Int32List.fromList(ringOf);
    lon = Float64List.fromList(lons);
  }

  late final Float64List points;
  late final Int32List ring;
  late final Float64List lon;

  int get length => ring.length;
}

/// Orthographic camera: yaw about the vertical axis, then tilt about the
/// horizontal axis. Results are written to [px], [py], [pz], [depth].
class _Camera {
  double _cYaw = 1, _sYaw = 0, _cTilt = 1, _sTilt = 0;
  double _cx = 0, _cy = 0, _radius = 1;
  double px = 0, py = 0, pz = 0, depth = 0;

  void set(double yaw, double tilt, double center, double radius) {
    _cYaw = math.cos(yaw);
    _sYaw = math.sin(yaw);
    _cTilt = math.cos(tilt);
    _sTilt = math.sin(tilt);
    _cx = center;
    _cy = center;
    _radius = radius;
  }

  void project(double x, double y, double z) {
    final double x1 = x * _cYaw - z * _sYaw;
    final double z1 = x * _sYaw + z * _cYaw;
    final double y1 = y * _cTilt - z1 * _sTilt;
    final double z2 = y * _sTilt + z1 * _cTilt;
    px = _cx + x1;
    py = _cy - y1;
    pz = z2;
    depth = ((z2 / _radius + 1) / 2).clamp(0.0, 1.0);
  }
}

/// Reusable per-frame list of dots and lines.
class _OrbBuffer {
  final List<double> _x = <double>[];
  final List<double> _y = <double>[];
  final List<double> _z = <double>[];
  final List<double> _r = <double>[];
  final List<double> _a = <double>[];
  final List<int> _order = <int>[];
  int _dots = 0;

  final List<double> _lines = <double>[];
  int _lineCount = 0;

  void clear() {
    _dots = 0;
    _lineCount = 0;
  }

  void _put(List<double> list, int i, double v) {
    if (i < list.length) {
      list[i] = v;
    } else {
      list.add(v);
    }
  }

  /// Adds a dot. [ink] 0 is full ink, 1 is background.
  void dot(double x, double y, double z, double r, double alpha, double ink) {
    final double a = alpha * (1 - ink.clamp(0.0, 1.0));
    if (a < _alphaCutoff) return;
    final int i = _dots++;
    _put(_x, i, x);
    _put(_y, i, y);
    _put(_z, i, z);
    _put(_r, i, math.max(_rMin, r));
    _put(_a, i, math.min(1.0, a));
  }

  /// Adds a straight line. [ink] 0 is full ink, 1 is background.
  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    double width,
    double alpha,
    double ink,
  ) {
    final double a = alpha * (1 - ink.clamp(0.0, 1.0));
    if (a < _alphaCutoff) return;
    final int base = _lineCount++ * 6;
    _put(_lines, base, x1);
    _put(_lines, base + 1, y1);
    _put(_lines, base + 2, x2);
    _put(_lines, base + 3, y2);
    _put(_lines, base + 4, width);
    _put(_lines, base + 5, math.min(1.0, a));
  }

  void paint(Canvas canvas, Paint paint, Color color, double opacity) {
    final double baseAlpha = color.a * opacity;
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < _lineCount; i++) {
      final int b = i * 6;
      paint
        ..strokeWidth = _lines[b + 4]
        ..color = color.withValues(alpha: _lines[b + 5] * baseAlpha);
      canvas.drawLine(
        Offset(_lines[b], _lines[b + 1]),
        Offset(_lines[b + 2], _lines[b + 3]),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    if (_order.length > _dots) {
      _order.length = _dots;
    }
    for (int i = 0; i < _dots; i++) {
      _put0(i);
    }
    _order.sort((int a, int b) => _z[a].compareTo(_z[b]));
    for (int k = 0; k < _dots; k++) {
      final int i = _order[k];
      paint.color = color.withValues(alpha: _a[i] * baseAlpha);
      canvas.drawCircle(Offset(_x[i], _y[i]), _r[i], paint);
    }
  }

  void _put0(int i) {
    if (i < _order.length) {
      _order[i] = i;
    } else {
      _order.add(i);
    }
  }
}

// ---------------------------------------------------------------------------
// Scenes
// ---------------------------------------------------------------------------

abstract class _OrbScene {
  _OrbScene(this.speed);

  /// Preset speed: scene time units per elapsed second.
  final double speed;

  /// Writes the frame at scene time [t] for a canvas of side [s].
  void render(double t, double s, _OrbBuffer out);

  static final Map<int, _OrbScene> _cache = <int, _OrbScene>{};

  static _OrbScene of(ThinkingOrbState state, bool compact) {
    final int key = state.index * 2 + (compact ? 1 : 0);
    return _cache[key] ??= _create(state, compact);
  }

  static _OrbScene _create(ThinkingOrbState state, bool compact) {
    switch (state) {
      case ThinkingOrbState.working:
        return _OrbitsScene(compact);
      case ThinkingOrbState.searching:
        return _GlobeScene(compact);
      case ThinkingOrbState.solving:
        return _RubikScene(compact);
      case ThinkingOrbState.listening:
        return _WaveScene(compact);
      case ThinkingOrbState.connecting:
        return _WebScene(compact);
      case ThinkingOrbState.weaving:
        return _BraidScene(compact);
      case ThinkingOrbState.composing:
        return _RibbonScene(compact, faceOn: false);
      case ThinkingOrbState.thinking:
        return _RibbonScene(compact, faceOn: true);
      case ThinkingOrbState.shaping:
        return _MorphScene(compact);
    }
  }
}

/// working: particles on tilted orbits with faint ghost paths.
class _OrbitsScene extends _OrbScene {
  _OrbitsScene(bool compact)
    : orbits = compact ? 3 : 12,
      ghosts = compact ? 10 : 40,
      particles = 3,
      size = compact ? 2.4 : 1.0,
      super(compact ? 3.9 : 1.885) {
    basis = Float64List(orbits * 6);
    radius = Float64List(orbits);
    omega = Float64List(orbits);
    offset = Float64List(orbits);
    for (int i = 0; i < orbits; i++) {
      final double h1 = _hash(i + 1.0, 1.7);
      final double h2 = _hash(i + 1.0, 4.3);
      final double h3 = _hash(i + 1.0, 8.9);
      radius[i] = 0.45 + 0.52 * h1;
      final double az = h1 * _tau;
      final double polar = math.acos(2 * h2 - 1);
      final double nx = math.sin(polar) * math.cos(az);
      final double ny = math.cos(polar);
      final double nz = math.sin(polar) * math.sin(az);
      // u = normalize(helper x n), v = n x u.
      final bool useY = ny.abs() < 0.9;
      final double hx = useY ? 0.0 : 1.0;
      final double hy = useY ? 1.0 : 0.0;
      double ux = hy * nz;
      double uy = -hx * nz;
      double uz = hx * ny - hy * nx;
      final double ul = math.sqrt(ux * ux + uy * uy + uz * uz);
      ux /= ul;
      uy /= ul;
      uz /= ul;
      basis[i * 6] = ux;
      basis[i * 6 + 1] = uy;
      basis[i * 6 + 2] = uz;
      basis[i * 6 + 3] = ny * uz - nz * uy;
      basis[i * 6 + 4] = nz * ux - nx * uz;
      basis[i * 6 + 5] = nx * uy - ny * ux;
      omega[i] = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1);
      offset[i] = h2 * 6;
    }
  }

  final int orbits;
  final int ghosts;
  final int particles;
  final double size;
  late final Float64List basis;
  late final Float64List radius;
  late final Float64List omega;
  late final Float64List offset;
  final _Camera _cam = _Camera();

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.82;
    final double rs = _radiusScale(s) * size;
    _cam.set(0.12 * t, 0.3, s / 2, r);
    for (int i = 0; i < orbits; i++) {
      final int b = i * 6;
      final double ro = r * radius[i];
      for (int k = 0; k < ghosts + particles; k++) {
        final bool ghost = k < ghosts;
        final double a = ghost
            ? _tau * k / ghosts
            : offset[i] + _tau * (k - ghosts) / particles + omega[i] * t;
        final double c = math.cos(a) * ro;
        final double sn = math.sin(a) * ro;
        _cam.project(
          basis[b] * c + basis[b + 3] * sn,
          basis[b + 1] * c + basis[b + 4] * sn,
          basis[b + 2] * c + basis[b + 5] * sn,
        );
        final double d = _cam.depth;
        if (ghost) {
          out.dot(
            _cam.px,
            _cam.py,
            _cam.pz,
            0.9 * rs,
            0.5 * (0.4 + 0.6 * d),
            0.72,
          );
        } else {
          out.dot(
            _cam.px,
            _cam.py,
            _cam.pz,
            (1.2 + 1.6 * d) * rs,
            1.0,
            0.3 - 0.22 * d,
          );
        }
      }
    }
  }
}

/// searching: a dotted globe with a sweeping scan line.
class _GlobeScene extends _OrbScene {
  _GlobeScene(bool compact)
    : lattice = compact ? _Lattice(6, 14) : _Lattice(11, 29),
      size = compact ? 1.75 : 1.15,
      scanMul = compact ? 4.335 : 4.08,
      super(compact ? 2.665 : 2.015);

  final _Lattice lattice;
  final double size;
  final double scanMul;
  static const double dimBase = 0.45;
  final _Camera _cam = _Camera();

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.82;
    final double rs = _radiusScale(s);
    _cam.set(0.5 * t, 0.4 + 0.06 * math.sin(0.35 * t), s / 2, r);
    final double scan = t * (0.5 + 1.2 * scanMul);
    final Float64List p = lattice.points;
    for (int i = 0; i < lattice.length; i++) {
      _cam.project(p[i * 3] * r, p[i * 3 + 1] * r, p[i * 3 + 2] * r);
      double diff = (lattice.lon[i] + 0.5 * t - scan) % _tau;
      if (diff > math.pi) diff -= _tau;
      final double boost =
          math.exp(-diff * diff / 0.18) * math.max(0.0, _cam.pz / r);
      final double d = _cam.depth;
      out.dot(
        _cam.px,
        _cam.py,
        _cam.pz,
        (0.6 * size + 1.7 * size * d + boost) * rs,
        dimBase + (1 - dimBase) * math.min(1.0, boost),
        0.62 - 0.54 * d,
      );
    }
  }
}

/// solving: a dotted sphere turning slabs like a puzzle cube.
class _RubikScene extends _OrbScene {
  _RubikScene(bool compact)
    : lattice = compact ? _Lattice(4, 7) : _Lattice(9, 24),
      size = compact ? 1.9 : 1.05,
      super(compact ? 1.95 : 1.82) {
    final int n = lattice.length;
    axis = Int32List(_moves);
    slab = Int32List(_moves);
    dir = Float64List(_moves);
    for (int i = 0; i < _moves; i++) {
      axis[i] = math.min(2, (_hash(i + 1.0, 3.1) * 3).floor());
      slab[i] = math.min(3, (_hash(i + 1.0, 5.7) * 4).floor());
      dir[i] = _hash(i + 1.0, 9.2) > 0.5 ? 1.0 : -1.0;
    }
    snapshots = <Float64List>[Float64List.fromList(lattice.points)];
    for (int m = 0; m < _moves; m++) {
      final Float64List prev = snapshots[m];
      final Float64List next = Float64List.fromList(prev);
      for (int i = 0; i < n; i++) {
        if (_slabOf(prev, i, axis[m]) == slab[m]) {
          _rotate(next, i, axis[m], dir[m] * math.pi / 2);
        }
      }
      snapshots.add(next);
    }
    _work = Float64List(3);
  }

  static const int _moves = 14;
  static const double _slot = 0.42;
  static const double _rest = 1.2;

  final _Lattice lattice;
  final double size;
  late final Int32List axis;
  late final Int32List slab;
  late final Float64List dir;
  late final List<Float64List> snapshots;
  late final Float64List _work;
  final _Camera _cam = _Camera();

  static int _slabOf(Float64List p, int i, int axis) {
    final double c = p[i * 3 + axis];
    if (c < -0.5) return 0;
    if (c < 0) return 1;
    if (c < 0.5) return 2;
    return 3;
  }

  /// Rotates point [i] of [p] about [axis] by [angle]; the axis coordinate
  /// is left untouched so slab membership stays exact.
  static void _rotate(Float64List p, int i, int axis, double angle) {
    final double c = math.cos(angle);
    final double s = math.sin(angle);
    final int b = i * 3;
    final int j = b + (axis + 1) % 3;
    final int k = b + (axis + 2) % 3;
    final double a = p[j];
    final double bb = p[k];
    p[j] = a * c - bb * s;
    p[k] = a * s + bb * c;
  }

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.82;
    final double rs = _radiusScale(s);
    _cam.set(0.55 * t, 0.35 + 0.1 * math.sin(0.9 * t), s / 2, r);

    const double cycle = 2 * _moves * _slot + _rest;
    final double tc = t % cycle;
    final int slot = (tc / _slot).floor();
    Float64List base = snapshots[0];
    int move = -1;
    double angle = 0;
    if (slot < 2 * _moves) {
      final double p = (tc - slot * _slot) / _slot;
      final double q = 1 - math.min(1.0, p / 0.7);
      final double eased = 1 - q * q * q;
      if (slot < _moves) {
        move = slot;
        base = snapshots[slot];
        angle = dir[move] * math.pi / 2 * eased;
      } else {
        move = 2 * _moves - 1 - slot;
        base = snapshots[move + 1];
        angle = -dir[move] * math.pi / 2 * eased;
      }
    }
    final Float64List w = _work;
    for (int i = 0; i < lattice.length; i++) {
      w[0] = base[i * 3];
      w[1] = base[i * 3 + 1];
      w[2] = base[i * 3 + 2];
      bool active = false;
      if (move >= 0 && _slabOf(base, i, axis[move]) == slab[move]) {
        active = true;
        _rotate(w, 0, axis[move], angle);
      }
      _cam.project(w[0] * r, w[1] * r, w[2] * r);
      final double d = _cam.depth;
      final double radius =
          ((0.6 + 1.7 * d) * size + (active ? 0.3 * size : 0)) * rs;
      out.dot(
        _cam.px,
        _cam.py,
        _cam.pz,
        radius,
        1.0,
        0.62 - 0.54 * d - (active ? 0.14 : 0),
      );
    }
  }
}

/// listening: sphere rings swelling in a travelling wave.
class _WaveScene extends _OrbScene {
  _WaveScene(bool compact)
    : lattice = _Lattice(9, compact ? 16 : 23),
      size = compact ? 1.6 : 1.0,
      super(compact ? 3.998 : 4.388) {
    _wave = Float64List(9);
  }

  final _Lattice lattice;
  final double size;
  late final Float64List _wave;
  final _Camera _cam = _Camera();

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.874;
    final double rs = _radiusScale(s) * size;
    _cam.set(0.18 * t, 0.38, s / 2, r);
    for (int ri = 0; ri < _wave.length; ri++) {
      _wave[ri] =
          0.62 * math.sin(2.1 * t - 0.52 * ri) +
          0.38 * math.sin(1.27 * t + 0.83 * ri);
    }
    final Float64List p = lattice.points;
    for (int i = 0; i < lattice.length; i++) {
      final double w = _wave[lattice.ring[i]];
      final double rr = r * (0.88 + 0.105 * w);
      final double crest = math.max(0.0, w);
      _cam.project(p[i * 3] * rr, p[i * 3 + 1] * rr, p[i * 3 + 2] * rr);
      final double d = _cam.depth;
      out.dot(
        _cam.px,
        _cam.py,
        _cam.pz,
        (0.6 + 1.7 * d) * (1 + 0.4 * crest) * rs,
        1.0,
        0.66 - 0.56 * d - 0.1 * crest,
      );
    }
  }
}

/// connecting: a wandering web of nodes with signal packets.
class _WebScene extends _OrbScene {
  _WebScene(bool compact)
    : nodes = compact ? 8 : 41,
      signals = compact ? 1 : 7,
      size = compact ? 1.52 : 0.95,
      super(compact ? 6.63 : 3.315) {
    base = _fibonacci(nodes);
    _pos = Float64List(nodes * 3);
    _sx = Float64List(nodes);
    _sy = Float64List(nodes);
    _sz = Float64List(nodes);
    _sd = Float64List(nodes);
  }

  final int nodes;
  final int signals;
  final double size;
  late final Float64List base;
  late final Float64List _pos;
  late final Float64List _sx;
  late final Float64List _sy;
  late final Float64List _sz;
  late final Float64List _sd;
  final _Camera _cam = _Camera();

  /// Link distance on the unit sphere. Sparser webs use longer links so
  /// every node keeps a few neighbours.
  late final double _link = 0.72 * math.max(1.0, math.sqrt(41 / nodes) * 0.75);

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.8;
    final double rs = _radiusScale(s);
    _cam.set(0.12 * t, 0.32, s / 2, r);
    const List<double> rates = <double>[0.24, 0.21, 0.27];
    for (int i = 0; i < nodes; i++) {
      double x = base[i * 3];
      double y = base[i * 3 + 1];
      double z = base[i * 3 + 2];
      x += 0.3 * (2 * _noise(t * rates[0], i * 7.31 + 1.3) - 1);
      y += 0.3 * (2 * _noise(t * rates[1], i * 7.31 + 23.9) - 1);
      z += 0.3 * (2 * _noise(t * rates[2], i * 7.31 + 47.1) - 1);
      final double l = math.sqrt(x * x + y * y + z * z);
      x /= l;
      y /= l;
      z /= l;
      _pos[i * 3] = x;
      _pos[i * 3 + 1] = y;
      _pos[i * 3 + 2] = z;
      _cam.project(x * r, y * r, z * r);
      _sx[i] = _cam.px;
      _sy[i] = _cam.py;
      _sz[i] = _cam.pz;
      _sd[i] = _cam.depth;
    }
    final double width = math.max(0.6, 0.8 * rs);
    for (int i = 0; i < nodes; i++) {
      for (int j = i + 1; j < nodes; j++) {
        final double dx = _pos[i * 3] - _pos[j * 3];
        final double dy = _pos[i * 3 + 1] - _pos[j * 3 + 1];
        final double dz = _pos[i * 3 + 2] - _pos[j * 3 + 2];
        final double dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (dist >= _link) continue;
        final double avg = (_sd[i] + _sd[j]) / 2;
        out.line(
          _sx[i],
          _sy[i],
          _sx[j],
          _sy[j],
          width,
          (1 - dist / _link) * (0.3 + 0.55 * avg),
          0.42,
        );
      }
    }
    for (int i = 0; i < nodes; i++) {
      final double d = _sd[i];
      final double pulse = 1 + 0.25 * math.sin(1.4 * t + 2.7 * i);
      out.dot(
        _sx[i],
        _sy[i],
        _sz[i],
        (1.4 + 1.8 * d) * size * rs * pulse,
        1.0,
        0.55 - 0.45 * d,
      );
    }
    if (nodes < 2) return;
    for (int k = 0; k < signals; k++) {
      final double phase = 0.55 * t + 7.31 * k;
      final double seg = phase.floorToDouble();
      final double f = phase - seg;
      final int a = math.min(nodes - 1, (_hash(seg, k + 0.5) * nodes).floor());
      int b = math.min(nodes - 1, (_hash(seg + 0.37, k + 2.5) * nodes).floor());
      if (b == a) b = (a + 1) % nodes;
      double x = _pos[a * 3] + (_pos[b * 3] - _pos[a * 3]) * f;
      double y = _pos[a * 3 + 1] + (_pos[b * 3 + 1] - _pos[a * 3 + 1]) * f;
      double z = _pos[a * 3 + 2] + (_pos[b * 3 + 2] - _pos[a * 3 + 2]) * f;
      final double l = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
      x /= l;
      y /= l;
      z /= l;
      _cam.project(x * r, y * r, z * r);
      final double d = _cam.depth;
      out.dot(
        _cam.px,
        _cam.py,
        _cam.pz + 0.01,
        (1.5 * 1.4 * size + 1.8 * size * d) * rs,
        0.5 + 0.5 * d,
        0.05,
      );
    }
  }
}

/// Draws a faint Fibonacci sphere of [ghost] points.
void _ghostSphere(
  Float64List ghost,
  double r,
  double rs,
  _Camera cam,
  _OrbBuffer out,
) {
  for (int i = 0; i < ghost.length ~/ 3; i++) {
    cam.project(ghost[i * 3] * r, ghost[i * 3 + 1] * r, ghost[i * 3 + 2] * r);
    out.dot(cam.px, cam.py, cam.pz, 0.8 * rs, 0.1 + 0.22 * cam.depth, 0.78);
  }
}

/// weaving: three dotted strands braiding around a faint sphere.
class _BraidScene extends _OrbScene {
  _BraidScene(bool compact)
    : perStrand = compact ? 8 : 26,
      ghost = _fibonacci(compact ? 12 : 75),
      size = compact ? 1.36 : 1.0,
      super(compact ? 2.75 : 1.625);

  /// Total twist of a strand from bottom to top, in radians.
  static const double _twist = math.pi;

  final int perStrand;
  final Float64List ghost;
  final double size;
  final _Camera _cam = _Camera();

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.76;
    final double rs = _radiusScale(s) * size;
    _cam.set(0.4 * t, 0.3, s / 2, r);
    _ghostSphere(ghost, r, rs, _cam, out);
    for (int st = 0; st < 3; st++) {
      final double phase = st * _tau / 3;
      for (int i = 0; i < perStrand; i++) {
        final double u = (_fract(i / perStrand + 0.045 * t) * 2 - 1) * 0.96;
        final double angle = u * _twist + phase;
        final double weave =
            1 + 0.075 * math.sin(6 * math.pi * u + 2 * phase + 0.8 * t);
        final double ring = math.sqrt(math.max(0.0, 1 - u * u)) * r * weave;
        _cam.project(
          math.cos(angle) * ring,
          u * r * weave,
          math.sin(angle) * ring,
        );
        final double d = _cam.depth;
        final double endFade = math.min(1.0, (1 - u.abs()) / 0.1);
        out.dot(
          _cam.px,
          _cam.py,
          _cam.pz,
          (1.2 + 1.8 * d) * rs,
          endFade * (0.45 + 0.55 * d),
          0.55 - 0.45 * d,
        );
      }
    }
  }
}

/// composing (a wavy band around a faint sphere) and thinking (the same
/// band seen face-on as a breathing ring).
class _RibbonScene extends _OrbScene {
  _RibbonScene(bool compact, {required this.faceOn})
    : lanes = faceOn ? (compact ? 3 : 11) : (compact ? 6 : 12),
      segs = faceOn ? (compact ? 22 : 48) : (compact ? 22 : 44),
      ghost = faceOn ? Float64List(0) : _fibonacci(compact ? 10 : 38),
      size = faceOn ? (compact ? 1.622 : 0.956) : (compact ? 1.073 : 0.85),
      wobMul = faceOn ? (compact ? 0.565 : 0.368) : 1.0,
      super(faceOn ? (compact ? 3.78 : 3.24) : (compact ? 3.12 : 2.34)) {
    _cos = Float64List(segs);
    _sin = Float64List(segs);
    for (int k = 0; k < segs; k++) {
      _cos[k] = math.cos(_tau * k / segs);
      _sin[k] = math.sin(_tau * k / segs);
    }
  }

  final bool faceOn;
  final int lanes;
  final int segs;
  final Float64List ghost;
  final double size;
  final double wobMul;
  late final Float64List _cos;
  late final Float64List _sin;
  final _Camera _cam = _Camera();

  static const double _bandTilt = 0.55;
  static const double _laneGap = 0.075;

  @override
  void render(double t, double s, _OrbBuffer out) {
    final double r = s / 2 * 0.78;
    final double rs = _radiusScale(s);
    final double half = (lanes - 1) / 2;
    if (faceOn) {
      _renderRing(t, s, r, rs, half, out);
      return;
    }
    _cam.set(0, 0.3, s / 2, r);
    _ghostSphere(ghost, r, rs, _cam, out);
    // Band plane: a great circle tilted sideways by _bandTilt. Its in-plane
    // axes are (cos, sin, 0) and z; n is the plane normal.
    final double e1x = math.cos(_bandTilt), e1y = math.sin(_bandTilt);
    final double nx = -math.sin(_bandTilt), ny = math.cos(_bandTilt);
    for (int w = 0; w < lanes; w++) {
      final double laneOffset = (w - half) * _laneGap;
      final double edge = half == 0 ? 0.0 : (w - half).abs() / half;
      for (int k = 0; k < segs; k++) {
        final double a = _tau * k / segs;
        final double wob =
            0.16 * math.sin(3 * a - 1.7 * t + 0.22 * w) +
            0.07 * math.sin(5 * a + 1.1 * t);
        final double off = laneOffset + wob * wobMul;
        double x = e1x * _cos[k] + nx * off;
        double y = e1y * _cos[k] + ny * off;
        double z = _sin[k];
        final double l = math.sqrt(x * x + y * y + z * z);
        x = x / l * r;
        y = y / l * r;
        z = z / l * r;
        _cam.project(x, y, z);
        final double d = _cam.depth;
        out.dot(
          _cam.px,
          _cam.py,
          _cam.pz,
          (1.1 + 1.7 * d) * size * (1 - 0.25 * edge) * rs,
          0.4 + 0.6 * d,
          0.52 - 0.44 * d + 0.18 * edge,
        );
      }
    }
  }

  /// Face-on ring: lanes lie across the front half of a torus tube, so the
  /// middle lanes are nearest (largest, darkest) and the rim lanes fade.
  void _renderRing(
    double t,
    double s,
    double r,
    double rs,
    double half,
    _OrbBuffer out,
  ) {
    final double base = r / (1 + 0.85 * 0.23 * wobMul);
    final double tube = base * 0.25;
    final double center = base - tube;
    final double c = s / 2;
    for (int w = 0; w < lanes; w++) {
      final double phi = -math.pi / 2 + math.pi * (w + 0.5) / lanes;
      final double lane = center + tube * math.sin(phi);
      final double d = 0.5 + 0.5 * math.cos(phi);
      final double edge = math.sin(phi).abs();
      final double radius = (1.1 + 1.7 * d) * size * (1 - 0.25 * edge) * rs;
      final double ink = 0.52 - 0.44 * d + 0.18 * edge;
      final double alpha = 0.4 + 0.6 * d;
      // Stagger alternate lanes by half a step so the dots interleave.
      final double shift = (w.isOdd ? 0.5 : 0.0) * _tau / segs;
      for (int k = 0; k < segs; k++) {
        final double a = _tau * k / segs + shift;
        final double wob =
            0.16 * math.sin(3 * a - 1.7 * t + 0.22 * w) +
            0.07 * math.sin(5 * a + 1.1 * t);
        final double rho = lane * (1 + wob * wobMul);
        out.dot(
          c + rho * math.cos(a),
          c + rho * math.sin(a),
          tube * math.cos(phi),
          radius,
          alpha,
          ink,
        );
      }
    }
  }
}

/// shaping: a dotted outline morphing circle, triangle, square.
class _MorphScene extends _OrbScene {
  _MorphScene(bool compact)
    : count = compact ? 18 : 24,
      super(compact ? 2.08 : 2.405) {
    shapes = <Float64List>[
      _sampleCircle(),
      _samplePolygon(const <double>[0, -0.26, 0.24, 0.16, -0.24, 0.16]),
      _samplePolygon(const <double>[
        0, -0.2, 0.2, -0.2, 0.2, 0.2, -0.2, 0.2, -0.2, -0.2, //
      ]),
    ];
    _mix = Float64List(_samples * 2);
    _len = Float64List(_samples + 1);
  }

  static const int _samples = 160;
  static const double _hold = 1.4;
  static const double _morph = 0.9;
  static const double _spread = 1.45;

  final int count;
  late final List<Float64List> shapes;
  late final Float64List _mix;
  late final Float64List _len;

  static Float64List _sampleCircle() {
    final Float64List out = Float64List(_samples * 2);
    for (int i = 0; i < _samples; i++) {
      final double a = -math.pi / 2 + _tau * i / _samples;
      out[i * 2] = 0.24 * math.cos(a);
      out[i * 2 + 1] = 0.24 * math.sin(a);
    }
    return out;
  }

  /// Samples a closed polygon (which starts at its first vertex) evenly by
  /// arc length.
  static Float64List _samplePolygon(List<double> v) {
    final int n = v.length ~/ 2;
    final List<double> cum = <double>[0];
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final double dx = v[j * 2] - v[i * 2];
      final double dy = v[j * 2 + 1] - v[i * 2 + 1];
      cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
    }
    final double total = cum.last;
    final Float64List out = Float64List(_samples * 2);
    int edge = 0;
    for (int i = 0; i < _samples; i++) {
      final double at = total * i / _samples;
      while (edge < n - 1 && cum[edge + 1] <= at) {
        edge++;
      }
      final int j = (edge + 1) % n;
      final double f = (at - cum[edge]) / (cum[edge + 1] - cum[edge]);
      out[i * 2] = v[edge * 2] + (v[j * 2] - v[edge * 2]) * f;
      out[i * 2 + 1] = v[edge * 2 + 1] + (v[j * 2 + 1] - v[edge * 2 + 1]) * f;
    }
    return out;
  }

  @override
  void render(double t, double s, _OrbBuffer out) {
    const double step = _hold + _morph;
    final double loop = t % (step * 3);
    final int index = (loop / step).floor() % 3;
    final double local = loop - index * step;
    final Float64List a = shapes[index];
    final Float64List b = shapes[(index + 1) % 3];
    final double m = local <= _hold
        ? 0.0
        : _smooth(((local - _hold) / _morph).clamp(0, 1));
    final double scale = s * _spread * (1 + 0.02 * math.sin(3.1 * t));
    for (int i = 0; i < _samples * 2; i++) {
      _mix[i] = (a[i] + (b[i] - a[i]) * m) * scale;
    }
    _len[0] = 0;
    for (int i = 0; i < _samples; i++) {
      final int j = (i + 1) % _samples;
      final double dx = _mix[j * 2] - _mix[i * 2];
      final double dy = _mix[j * 2 + 1] - _mix[i * 2 + 1];
      _len[i + 1] = _len[i] + math.sqrt(dx * dx + dy * dy);
    }
    final double total = _len[_samples];
    final double radius = math.max(0.35, 0.0105 * 1.35 * _spread * s);
    final double c = s / 2;
    int seg = 0;
    for (int k = 0; k < count; k++) {
      final double at = total * k / count;
      while (seg < _samples - 1 && _len[seg + 1] <= at) {
        seg++;
      }
      final int j = (seg + 1) % _samples;
      final double span = _len[seg + 1] - _len[seg];
      final double f = span <= 0 ? 0.0 : (at - _len[seg]) / span;
      final double x = _mix[seg * 2] + (_mix[j * 2] - _mix[seg * 2]) * f;
      final double y =
          _mix[seg * 2 + 1] + (_mix[j * 2 + 1] - _mix[seg * 2 + 1]) * f;
      out.dot(c + x, c + y, 0, radius, 1.0, 0.1);
    }
  }
}
