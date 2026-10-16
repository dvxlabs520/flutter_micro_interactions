import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// The built-in orbit shapes of [OrbitItems].
enum OrbitShape {
  /// A circle. Its radius is [OrbitItems.radiusX] when set.
  circle,

  /// An ellipse with radii [OrbitItems.radiusX] and [OrbitItems.radiusY].
  ellipse,
}

/// Widgets, typically avatars or images, that orbit evenly spaced along a
/// closed path around an optional [center] widget.
///
/// ```dart
/// SizedBox.square(
///   dimension: 320,
///   child: OrbitItems(
///     shape: OrbitShape.ellipse,
///     depth: true,
///     showPath: true,
///     center: const FlutterLogo(size: 64),
///     children: const <Widget>[
///       CircleAvatar(child: Text('A')),
///       CircleAvatar(child: Text('B')),
///       CircleAvatar(child: Text('C')),
///       CircleAvatar(child: Text('D')),
///     ],
///   ),
/// )
/// ```
///
/// The items keep equal distances measured along the path (arc length),
/// so they stay evenly spaced on ellipses and custom paths too, and one
/// full revolution takes [duration]. The first item starts at the top of
/// the built-in shapes, or at the start of a custom [path].
///
/// The orbit fills the available space and is centered in it. Without
/// explicit radii, the shape is sized so the items stay inside the box.
/// In an unbounded direction it uses its radii (120 by default) plus the
/// item size. Give it a [SizedBox] for a predictable layout.
///
/// Movement only repaints: the items are never rebuilt or laid out per
/// frame, and each item is its own repaint boundary. A single ticker drives
/// the orbit with the real frame time. Hovering with a mouse pauses the
/// orbit when [pauseOnHover] is true; the stop and the restart ease over
/// [speedChangeDuration].
///
/// With [depth] the orbit gets a simple 3D feel: items lower on the path
/// are treated as closer, painted on top and at full size, while items
/// higher up shrink to 80 percent and dim slightly. The [center] is painted
/// between the back and the front items.
///
/// Accessibility: [center] and the items keep their own semantics and
/// stay tappable; taps follow the moving items. The orbit line is
/// decorative. Under reduced motion, or when [enabled] is false, the items
/// rest at their evenly spaced starting positions and nothing moves.
class OrbitItems extends StatefulWidget {
  /// Creates an orbit of [children] around an optional [center].
  const OrbitItems({
    super.key,
    required this.children,
    this.center,
    this.shape = OrbitShape.circle,
    this.path,
    this.radiusX,
    this.radiusY,
    this.duration = const Duration(seconds: 12),
    this.clockwise = true,
    this.rotateItems = false,
    this.showPath = false,
    this.pathColor,
    this.pathWidth = 1.0,
    this.itemSize,
    this.pauseOnHover = true,
    this.depth = false,
    this.speedChangeDuration = const Duration(milliseconds: 400),
    this.enabled = true,
  }) : assert(radiusX == null || radiusX >= 0, 'radiusX must not be negative'),
       assert(radiusY == null || radiusY >= 0, 'radiusY must not be negative'),
       assert(pathWidth >= 0, 'pathWidth must not be negative');

  /// The orbiting widgets, typically avatars or images.
  final List<Widget> children;

  /// Optional widget painted at the center of the orbit.
  final Widget? center;

  /// The built-in shape of the orbit. Ignored when [path] is set. Defaults
  /// to [OrbitShape.circle].
  final OrbitShape shape;

  /// Optional custom closed path, in the local coordinates of this widget.
  /// Items move along it in the path's own direction when [clockwise] is
  /// true, and against it when false. Overrides [shape].
  final Path? path;

  /// Horizontal radius, or the radius of a circle. Defaults to the largest
  /// radius that keeps the items inside the box.
  final double? radiusX;

  /// Vertical radius of an ellipse. Ignored for circles. Defaults to the
  /// smaller of the space available and half of the horizontal radius.
  final double? radiusY;

  /// Time for one full revolution. Defaults to 12 seconds. A zero or
  /// negative duration keeps the items still.
  final Duration duration;

  /// Whether the built-in shapes turn clockwise. Defaults to true.
  final bool clockwise;

  /// When true each item rotates to follow the direction of travel. When
  /// false (the default) items stay upright.
  final bool rotateItems;

  /// Whether to draw the orbit line. Defaults to false.
  final bool showPath;

  /// Color of the orbit line. Defaults to the theme's
  /// `colorScheme.outlineVariant`.
  final Color? pathColor;

  /// Stroke width of the orbit line. Defaults to 1.
  final double pathWidth;

  /// When set, every item is laid out at exactly this size. When null
  /// (the default) items size themselves.
  final Size? itemSize;

  /// Whether hovering with a mouse pauses the orbit. Defaults to true.
  final bool pauseOnHover;

  /// Whether items higher on the path shrink and dim, giving a 3D feel,
  /// and are painted behind lower items and the [center]. Most effective
  /// with [OrbitShape.ellipse]. Defaults to false.
  final bool depth;

  /// How long pausing and resuming take to ease in. Defaults to 400
  /// milliseconds. [Duration.zero] stops and starts instantly.
  final Duration speedChangeDuration;

  /// When false the items rest at their starting positions. Defaults to
  /// true.
  final bool enabled;

  @override
  State<OrbitItems> createState() => _OrbitItemsState();
}

class _OrbitItemsState extends State<OrbitItems>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Orbit progress in revolutions, always in [0, 1).
  final ValueNotifier<double> _phase = ValueNotifier<double>(0.0);
  final _SpeedRamp _ramp = _SpeedRamp();
  Duration _lastElapsed = Duration.zero;
  bool _hovered = false;
  bool _reducedMotion = false;
  bool _wasAnimating = false;

  bool get _animating =>
      widget.enabled && !_reducedMotion && widget.children.isNotEmpty;

  /// Speed multiplier requested right now: 1 is full speed.
  double get _targetSpeed =>
      !_animating || (_hovered && widget.pauseOnHover) ? 0.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(OrbitItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_animating) {
      _wasAnimating = false;
      _hovered = false;
      _ramp.snap(0.0);
      _phase.value = 0.0;
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (!_wasAnimating) {
      _wasAnimating = true;
      _ramp.snap(_targetSpeed);
    } else {
      _ramp.retarget(
        _targetSpeed,
        widget.speedChangeDuration.inMicroseconds /
            Duration.microsecondsPerSecond,
      );
    }
    final bool moving = !(_ramp.isSettled && _ramp.current == 0.0);
    if (moving && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final double dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    final double distance = _ramp.advance(dt);
    final int period = widget.duration.inMicroseconds;
    if (distance != 0.0 && period > 0) {
      final double revolutions =
          distance / (period / Duration.microsecondsPerSecond);
      final double sign = widget.clockwise ? 1.0 : -1.0;
      _phase.value = (_phase.value + sign * revolutions) % 1.0;
    }
    if (_ramp.isSettled && _ramp.current == 0.0) {
      _ticker.stop();
    }
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final Color pathColor =
        widget.pathColor ?? Theme.of(context).colorScheme.outlineVariant;
    final Widget? center = widget.center;
    final Widget orbit = _Orbit(
      phase: _phase,
      hasCenter: center != null,
      shape: widget.shape,
      path: widget.path,
      radiusX: widget.radiusX,
      radiusY: widget.radiusY,
      rotateItems: widget.rotateItems,
      depth: widget.depth,
      pathColor: widget.showPath ? pathColor : null,
      pathWidth: widget.pathWidth,
      itemSize: widget.itemSize,
      children: <Widget>[
        if (center != null)
          RepaintBoundary(
            key: const ValueKey<_CenterSlot>(_CenterSlot()),
            child: center,
          ),
        for (final Widget child in widget.children)
          RepaintBoundary(child: child),
      ],
    );
    // Always present so toggling options never rebuilds the children.
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _setHovered(true),
      onExit: (PointerExitEvent event) => _setHovered(false),
      child: orbit,
    );
  }
}

/// Key payload that keeps the center child distinct from the items.
class _CenterSlot {
  const _CenterSlot();
}

/// Eases a speed value toward a target over a fixed time with
/// [Curves.easeInOut], and integrates the distance travelled.
class _SpeedRamp {
  double current = 0.0;
  double _from = 0.0;
  double _to = 0.0;
  double _elapsed = 0.0;
  double _duration = 0.0;

  bool get isSettled => _elapsed >= _duration;

  void snap(double value) {
    current = value;
    _from = value;
    _to = value;
    _elapsed = 0.0;
    _duration = 0.0;
  }

  void retarget(double value, double seconds) {
    if (value == _to) return;
    if (seconds <= 0.0) {
      snap(value);
      return;
    }
    _from = current;
    _to = value;
    _elapsed = 0.0;
    _duration = seconds;
  }

  double advance(double dt) {
    if (dt <= 0.0) return 0.0;
    final double before = current;
    if (!isSettled) {
      _elapsed = math.min(_elapsed + dt, _duration);
      final double t = Curves.easeInOut.transform(_elapsed / _duration);
      current = _from + (_to - _from) * t;
    } else {
      current = _to;
    }
    return (before + current) * 0.5 * dt;
  }
}

class _Orbit extends MultiChildRenderObjectWidget {
  const _Orbit({
    required this.phase,
    required this.hasCenter,
    required this.shape,
    required this.path,
    required this.radiusX,
    required this.radiusY,
    required this.rotateItems,
    required this.depth,
    required this.pathColor,
    required this.pathWidth,
    required this.itemSize,
    required super.children,
  });

  final ValueListenable<double> phase;
  final bool hasCenter;
  final OrbitShape shape;
  final Path? path;
  final double? radiusX;
  final double? radiusY;
  final bool rotateItems;
  final bool depth;
  final Color? pathColor;
  final double pathWidth;
  final Size? itemSize;

  @override
  _RenderOrbit createRenderObject(BuildContext context) {
    final _RenderOrbit renderObject = _RenderOrbit(phase);
    updateRenderObject(context, renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderOrbit renderObject) {
    renderObject
      ..phase = phase
      ..hasCenter = hasCenter
      ..shape = shape
      ..path = path
      ..radiusX = radiusX
      ..radiusY = radiusY
      ..rotateItems = rotateItems
      ..depth = depth
      ..pathColor = pathColor
      ..pathWidth = pathWidth
      ..itemSize = itemSize;
  }
}

class _OrbitParentData extends ContainerBoxParentData<RenderBox> {
  /// Transform used for the last paint, also used for hit testing.
  Matrix4? transform;
}

/// Samples a closed curve by arc-length fraction.
abstract class _OrbitSampler {
  /// Writes the point at arc-length fraction [u] in [0, 1) to [x], [y] and
  /// the direction of travel to [angle].
  void sample(double u);

  double x = 0.0;
  double y = 0.0;
  double angle = 0.0;

  /// Vertical extent of the curve, used for depth.
  double get top;
  double get bottom;

  void paint(Canvas canvas, Offset offset, Paint paint);
}

/// An ellipse starting at the top and turning clockwise on screen. Equal
/// arc-length steps come from a cumulative length table.
class _EllipseSampler extends _OrbitSampler {
  _EllipseSampler(this.cx, this.cy, this.rx, this.ry) {
    if (rx != ry) {
      final Float64List lengths = Float64List(_steps + 1);
      double previousX = cx + rx * math.cos(_start);
      double previousY = cy + ry * math.sin(_start);
      for (int i = 1; i <= _steps; i++) {
        final double theta = _start + 2 * math.pi * i / _steps;
        final double px = cx + rx * math.cos(theta);
        final double py = cy + ry * math.sin(theta);
        final double dx = px - previousX;
        final double dy = py - previousY;
        lengths[i] = lengths[i - 1] + math.sqrt(dx * dx + dy * dy);
        previousX = px;
        previousY = py;
      }
      _lengths = lengths;
    }
  }

  static const int _steps = 512;
  static const double _start = -math.pi / 2;

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  Float64List? _lengths;

  /// Maps an arc-length fraction to the ellipse parameter angle.
  double _theta(double u) {
    final Float64List? lengths = _lengths;
    if (lengths == null || lengths[_steps] <= 0.0) {
      return _start + 2 * math.pi * u;
    }
    final double target = u * lengths[_steps];
    int low = 0;
    int high = _steps;
    while (high - low > 1) {
      final int mid = (low + high) >> 1;
      if (lengths[mid] <= target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final double span = lengths[high] - lengths[low];
    final double f = span > 0.0 ? (target - lengths[low]) / span : 0.0;
    return _start + 2 * math.pi * (low + f) / _steps;
  }

  @override
  void sample(double u) {
    final double theta = _theta(u);
    final double c = math.cos(theta);
    final double s = math.sin(theta);
    x = cx + rx * c;
    y = cy + ry * s;
    angle = math.atan2(ry * c, -rx * s);
  }

  @override
  double get top => cy - ry;

  @override
  double get bottom => cy + ry;

  @override
  void paint(Canvas canvas, Offset offset, Paint paint) {
    if (rx == ry) {
      canvas.drawCircle(offset + Offset(cx, cy), rx, paint);
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: offset + Offset(cx, cy),
        width: rx * 2,
        height: ry * 2,
      ),
      paint,
    );
  }
}

/// A custom path, sampled with [ui.PathMetric]s across all its contours.
class _PathSampler extends _OrbitSampler {
  _PathSampler(this.path)
    : _metrics = path.computeMetrics().toList(growable: false),
      _bounds = path.getBounds() {
    double total = 0.0;
    for (final ui.PathMetric metric in _metrics) {
      total += metric.length;
    }
    _total = total;
  }

  final Path path;
  final List<ui.PathMetric> _metrics;
  final Rect _bounds;
  late final double _total;

  @override
  void sample(double u) {
    if (_total <= 0.0) {
      x = _bounds.center.dx;
      y = _bounds.center.dy;
      angle = 0.0;
      return;
    }
    double distance = u * _total;
    for (final ui.PathMetric metric in _metrics) {
      if (distance <= metric.length || identical(metric, _metrics.last)) {
        final ui.Tangent? tangent = metric.getTangentForOffset(
          distance.clamp(0.0, metric.length),
        );
        if (tangent != null) {
          x = tangent.position.dx;
          y = tangent.position.dy;
          // Tangent angles are counter-clockwise with y up; convert to
          // screen rotation.
          angle = -tangent.angle;
        }
        return;
      }
      distance -= metric.length;
    }
  }

  @override
  double get top => _bounds.top;

  @override
  double get bottom => _bounds.bottom;

  @override
  void paint(Canvas canvas, Offset offset, Paint paint) {
    canvas.drawPath(path.shift(offset), paint);
  }
}

/// Lays out the center and items once, then places the items along the
/// orbit at paint time from [phase].
class _RenderOrbit extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OrbitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OrbitParentData> {
  /// Creates the render object; every other setting is applied through its
  /// setters by [_Orbit.updateRenderObject].
  _RenderOrbit(this._phase);

  /// Radius used in an unbounded direction when none is given.
  static const double _fallbackRadius = 120.0;

  /// Scale and opacity of the item farthest back when [depth] is on.
  static const double _backScale = 0.8;
  static const double _backOpacity = 0.7;

  ValueListenable<double> _phase;
  set phase(ValueListenable<double> value) {
    if (value == _phase) return;
    if (attached) _phase.removeListener(markNeedsPaint);
    _phase = value;
    if (attached) _phase.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool _hasCenter = false;
  set hasCenter(bool value) {
    if (value == _hasCenter) return;
    _hasCenter = value;
    markNeedsLayout();
  }

  OrbitShape _shape = OrbitShape.circle;
  set shape(OrbitShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsLayout();
  }

  Path? _path;
  set path(Path? value) {
    if (value == _path) return;
    _path = value;
    markNeedsLayout();
  }

  double? _radiusX;
  set radiusX(double? value) {
    if (value == _radiusX) return;
    _radiusX = value;
    markNeedsLayout();
  }

  double? _radiusY;
  set radiusY(double? value) {
    if (value == _radiusY) return;
    _radiusY = value;
    markNeedsLayout();
  }

  bool _rotateItems = false;
  set rotateItems(bool value) {
    if (value == _rotateItems) return;
    _rotateItems = value;
    markNeedsPaint();
  }

  bool _depth = false;
  set depth(bool value) {
    if (value == _depth) return;
    _depth = value;
    markNeedsPaint();
  }

  Color? _pathColor;
  set pathColor(Color? value) {
    if (value == _pathColor) return;
    _pathColor = value;
    markNeedsPaint();
  }

  double _pathWidth = 1.0;
  set pathWidth(double value) {
    if (value == _pathWidth) return;
    _pathWidth = value;
    markNeedsPaint();
  }

  Size? _itemSize;
  set itemSize(Size? value) {
    if (value == _itemSize) return;
    _itemSize = value;
    markNeedsLayout();
  }

  _OrbitSampler? _sampler;
  final Paint _pathPaint = Paint()..style = PaintingStyle.stroke;

  /// Reusable per-frame buffers, one entry per item.
  final List<RenderBox> _items = <RenderBox>[];
  Float64List _depths = Float64List(0);
  List<int> _order = <int>[];

  /// Child render boxes in their last paint order, for hit testing.
  final List<RenderBox> _paintOrder = <RenderBox>[];

  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OrbitParentData) {
      child.parentData = _OrbitParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _phase.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _phase.removeListener(markNeedsPaint);
    super.detach();
  }

  RenderBox? get _center => _hasCenter ? firstChild : null;

  @override
  void performLayout() {
    final Size? itemSize = _itemSize;
    final BoxConstraints loose = constraints.loosen();
    final BoxConstraints itemConstraints = itemSize != null
        ? BoxConstraints.tight(itemSize)
        : loose;
    _items.clear();
    double itemWidth = 0.0;
    double itemHeight = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      if (child == _center) {
        child.layout(loose, parentUsesSize: true);
      } else {
        child.layout(itemConstraints, parentUsesSize: true);
        _items.add(child);
        itemWidth = math.max(itemWidth, child.size.width);
        itemHeight = math.max(itemHeight, child.size.height);
      }
      child = childAfter(child);
    }

    final Path? path = _path;
    final bool circle = _shape == OrbitShape.circle;
    final double fallbackRx = _radiusX ?? _fallbackRadius;
    final double fallbackRy = circle
        ? fallbackRx
        : (_radiusY ?? fallbackRx * 0.5);
    final Rect? pathBounds = path?.getBounds();
    final double width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : (pathBounds != null
              ? pathBounds.right + itemWidth / 2
              : fallbackRx * 2 + itemWidth);
    final double height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : (pathBounds != null
              ? pathBounds.bottom + itemHeight / 2
              : fallbackRy * 2 + itemHeight);
    size = constraints.constrain(Size(width, height));

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double roomX = math.max(0.0, (size.width - itemWidth) / 2);
    final double roomY = math.max(0.0, (size.height - itemHeight) / 2);
    if (path != null) {
      _sampler = _PathSampler(path);
    } else if (circle) {
      final double r = _radiusX ?? math.min(roomX, roomY);
      _sampler = _EllipseSampler(centerX, centerY, r, r);
    } else {
      final double rx = _radiusX ?? roomX;
      final double ry = _radiusY ?? math.min(roomY, rx * 0.5);
      _sampler = _EllipseSampler(centerX, centerY, rx, ry);
    }

    final RenderBox? center = _center;
    if (center != null) {
      (center.parentData! as _OrbitParentData).offset = Offset(
        centerX - center.size.width / 2,
        centerY - center.size.height / 2,
      );
    }
    if (_depths.length != _items.length) {
      _depths = Float64List(_items.length);
      _order = List<int>.generate(_items.length, (int i) => i);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final _OrbitSampler? sampler = _sampler;
    if (sampler == null) return;
    final Color? pathColor = _pathColor;
    if (pathColor != null && _pathWidth > 0) {
      _pathPaint
        ..color = pathColor
        ..strokeWidth = _pathWidth;
      sampler.paint(context.canvas, offset, _pathPaint);
    }

    final int count = _items.length;
    final double phase = _phase.value;
    final double top = sampler.top;
    final double span = sampler.bottom - top;
    for (int i = 0; i < count; i++) {
      final RenderBox item = _items[i];
      final double u = (i / count + phase) % 1.0;
      sampler.sample(u);
      // 0 at the back (top of the path), 1 at the front (bottom).
      final double z = span > 0.0 ? ((sampler.y - top) / span) : 0.5;
      _depths[i] = z;
      final double scale = _depth ? _backScale + (1.0 - _backScale) * z : 1.0;
      final Size itemSize = item.size;
      final Matrix4 transform = Matrix4.translationValues(
        sampler.x,
        sampler.y,
        0.0,
      );
      if (_rotateItems) transform.rotateZ(sampler.angle);
      if (scale != 1.0) transform.scaleByDouble(scale, scale, 1.0, 1.0);
      transform.translateByDouble(
        -itemSize.width / 2,
        -itemSize.height / 2,
        0.0,
        1.0,
      );
      (item.parentData! as _OrbitParentData).transform = transform;
    }

    _paintOrder.clear();
    if (_depth) {
      for (int i = 0; i < count; i++) {
        _order[i] = i;
      }
      _order.sort((int a, int b) => _depths[a].compareTo(_depths[b]));
    }
    final RenderBox? center = _center;
    bool centerPainted = false;
    for (int k = 0; k < count; k++) {
      final int i = _depth ? _order[k] : k;
      if (center != null && !centerPainted && (!_depth || _depths[i] >= 0.5)) {
        _paintCenter(context, offset, center);
        centerPainted = true;
      }
      _paintItem(context, offset, _items[i], _depths[i]);
    }
    if (center != null && !centerPainted) {
      _paintCenter(context, offset, center);
    }
  }

  void _paintCenter(PaintingContext context, Offset offset, RenderBox center) {
    _paintOrder.add(center);
    context.paintChild(
      center,
      offset + (center.parentData! as _OrbitParentData).offset,
    );
  }

  void _paintItem(
    PaintingContext context,
    Offset offset,
    RenderBox item,
    double z,
  ) {
    _paintOrder.add(item);
    final Matrix4 transform = (item.parentData! as _OrbitParentData).transform!;
    void painter(PaintingContext context, Offset offset) {
      context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (PaintingContext context, Offset offset) =>
            context.paintChild(item, offset),
      );
    }

    final double opacity = _depth
        ? _backOpacity + (1.0 - _backOpacity) * z
        : 1.0;
    if (opacity < 1.0) {
      context.pushOpacity(
        offset,
        ui.Color.getAlphaFromOpacity(opacity),
        painter,
      );
    } else {
      painter(context, offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final _OrbitParentData parentData = child.parentData! as _OrbitParentData;
    final Matrix4? childTransform = parentData.transform;
    if (child != _center && childTransform != null) {
      transform.multiply(childTransform);
    } else {
      super.applyPaintTransform(child, transform);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (int i = _paintOrder.length - 1; i >= 0; i--) {
      final RenderBox child = _paintOrder[i];
      if (child.parent != this) continue;
      final _OrbitParentData parentData = child.parentData! as _OrbitParentData;
      final Matrix4? transform = parentData.transform;
      final bool hit;
      if (child == _center || transform == null) {
        hit = result.addWithPaintOffset(
          offset: parentData.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) =>
              child.hitTest(result, position: transformed),
        );
      } else {
        hit = result.addWithPaintTransform(
          transform: transform,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) =>
              child.hitTest(result, position: transformed),
        );
      }
      if (hit) return true;
    }
    return false;
  }
}
