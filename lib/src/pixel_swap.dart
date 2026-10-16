import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'utils/motion.dart';

/// What makes a [PixelSwap] change its visible child.
enum PixelSwapTrigger {
  /// A mouse entering shows the second child and leaving hides it again.
  /// On touch screens, which cannot hover, a tap toggles instead.
  hover,

  /// Any tap (mouse or touch) toggles between the children.
  tap,

  /// Only [PixelSwap.showSecond] and a [PixelSwapController] change the
  /// visible child.
  manual,
}

/// Programmatic control for a [PixelSwap].
///
/// ```dart
/// final controller = PixelSwapController();
/// // ...
/// PixelSwap(
///   controller: controller,
///   trigger: PixelSwapTrigger.manual,
///   first: const Text('Before'),
///   second: const Text('After'),
/// );
/// // later, starting the wave at a point in the widget's local space:
/// controller.show(origin: const Offset(24, 24));
/// controller.hide();
/// ```
///
/// [isShowingSecond] reflects the current target, including changes made
/// by hover or tap. The caller owns the controller and disposes it.
class PixelSwapController extends ChangeNotifier {
  bool _showing = false;
  Offset? _origin;

  /// Whether the attached [PixelSwap] shows (or is building towards) its
  /// second child.
  bool get isShowingSecond => _showing;

  /// Builds the second child in, with a wave starting at [origin] (local
  /// coordinates of the widget) or at the center when null.
  void show({Offset? origin}) {
    if (_showing) return;
    _showing = true;
    _origin = origin;
    notifyListeners();
  }

  /// Hides the second child again, with a wave starting at [origin] or at
  /// the center when null.
  void hide({Offset? origin}) {
    if (!_showing) return;
    _showing = false;
    _origin = origin;
    notifyListeners();
  }

  /// Shows the second child when hidden, hides it when shown.
  void toggle({Offset? origin}) {
    _showing = !_showing;
    _origin = origin;
    notifyListeners();
  }
}

/// A damped spring that overshoots to about 1.16 and settles at 1. Used as
/// the default [PixelSwap.curve].
class _PixelSpringCurve extends Curve {
  const _PixelSpringCurve();

  // Damping ratio 0.5 gives one clear overshoot and a tiny rebound;
  // zeta * omega = 7 means the motion has settled by t = 1.
  static const double _zeta = 0.5;
  static const double _omega = 14.0;

  @override
  double transformInternal(double t) {
    final double wd = _omega * math.sqrt(1 - _zeta * _zeta);
    final double decay = math.exp(-_zeta * _omega * t);
    return 1 -
        decay * (math.cos(wd * t) + (_zeta * _omega / wd) * math.sin(wd * t));
  }
}

const Curve _kPixelSpring = _PixelSpringCurve();

/// Swaps between two children pixel by pixel: the second child builds in
/// as a grid of square cells that pop in with a springy scale, in a wave
/// that travels outward from where the pointer entered.
///
/// ```dart
/// PixelSwap(
///   first: Image.asset('assets/product.jpg', fit: BoxFit.cover),
///   second: Container(
///     color: Theme.of(context).colorScheme.primaryContainer,
///     alignment: Alignment.center,
///     child: const Text('Add to cart'),
///   ),
/// )
/// ```
///
/// The widget takes the size of [first]; [second] is stretched over it
/// and painted on top through one clip made of all visible cells. With
/// [PixelSwapTrigger.hover] (the default) a mouse entering starts the wave
/// at the entry point and leaving plays the reverse wave from the exit
/// point; on touch screens a tap toggles from the tap point. Each cell
/// starts when the wave front (which crosses the widget in [duration])
/// reaches it, plus a little seeded jitter, and then pops in over
/// [cellDuration] with [curve], a spring that overshoots slightly. Hiding
/// shrinks the cells with a short anticipation. Reversing mid-wave is
/// seamless: cells keep their current scale and turn around.
///
/// [gridSize] sets how many cells span the shorter side. A [gap] above 0
/// leaves seams between the cells during the transition, for a mosaic
/// look; once the wave settles the second child is painted whole.
///
/// Accessibility: only the visible child is exposed to assistive
/// technology, can take focus and receives pointer input; the swap happens
/// halfway through the wave.
///
/// Reduced motion and `enabled: false`: the children swap instantly.
/// When [enabled] is false hover and tap are ignored, while [showSecond]
/// and the controller still work.
class PixelSwap extends StatefulWidget {
  /// Creates a pixel swap between [first] and [second].
  const PixelSwap({
    super.key,
    required this.first,
    required this.second,
    this.gridSize = 14,
    this.duration = const Duration(milliseconds: 700),
    this.cellDuration = const Duration(milliseconds: 320),
    this.curve = _kPixelSpring,
    this.trigger = PixelSwapTrigger.hover,
    this.controller,
    this.showSecond = false,
    this.gap = 0.0,
    this.borderRadius,
    this.seed = 0,
    this.onChanged,
    this.enabled = true,
  }) : assert(gridSize >= 1, 'gridSize must be at least 1'),
       assert(gap >= 0, 'gap must not be negative');

  /// The child shown at rest. It sets the size of the widget.
  final Widget first;

  /// The child revealed by the pixel wave, stretched to the size of
  /// [first].
  final Widget second;

  /// Number of cells across the shorter side. Defaults to 14.
  final int gridSize;

  /// Time for the wave front to travel from its origin to the farthest
  /// cell. Defaults to 700 milliseconds.
  final Duration duration;

  /// Time each cell takes to pop in or out. Defaults to 320 milliseconds.
  final Duration cellDuration;

  /// Scale curve of each cell when showing [second]. Defaults to a damped
  /// spring that overshoots to about 1.16 before settling.
  final Curve curve;

  /// What changes the visible child. Defaults to
  /// [PixelSwapTrigger.hover].
  final PixelSwapTrigger trigger;

  /// Optional controller to show, hide or toggle [second]. The caller owns
  /// and disposes it.
  final PixelSwapController? controller;

  /// Declarative visibility of [second]. Changing it plays the wave from
  /// the center. Defaults to false.
  final bool showSecond;

  /// Space in logical pixels between cells during the transition.
  /// Defaults to 0.
  final double gap;

  /// Optional corner rounding that clips both children.
  final BorderRadius? borderRadius;

  /// Seed of the per-cell timing jitter, so a given widget always plays
  /// the same wave. Defaults to 0.
  final int seed;

  /// Called with the new state when hover, tap or the controller changes
  /// the visible child. Not called for [showSecond] updates.
  final ValueChanged<bool>? onChanged;

  /// When false hover and tap are ignored and changes are instant.
  /// Defaults to true.
  final bool enabled;

  @override
  State<PixelSwap> createState() => _PixelSwapState();
}

class _PixelSwapState extends State<PixelSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  late final _PixelWave _engine;
  bool _showing = false;
  bool _secondVisible = false;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _showing =
        widget.showSecond || (widget.controller?.isShowingSecond ?? false);
    _secondVisible = _showing;
    _engine = _PixelWave(
      gridSize: widget.gridSize,
      durationMs: _ms(widget.duration),
      cellMs: _ms(widget.cellDuration),
      curve: widget.curve,
      seed: widget.seed,
      target: _showing,
    );
    _wave = AnimationController(
      vsync: this,
      duration: widget.duration + widget.cellDuration,
      value: 1.0,
    )..addListener(_handleTick);
    widget.controller?._showing = _showing;
    widget.controller?.addListener(_handleControllerChanged);
  }

  static double _ms(Duration d) => d.inMicroseconds / 1000.0;

  bool get _instant => _reduced || !widget.enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced) _finish();
  }

  @override
  void didUpdateWidget(PixelSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration ||
        widget.cellDuration != oldWidget.cellDuration) {
      final double progressMs = _engine.elapsed;
      _engine
        ..durationMs = _ms(widget.duration)
        ..cellMs = _ms(widget.cellDuration)
        ..invalidateDelays();
      _wave.duration = widget.duration + widget.cellDuration;
      final double total = _engine.totalMs;
      if (_wave.isAnimating) {
        _wave.forward(from: (progressMs / total).clamp(0.0, 1.0));
      }
    }
    if (widget.curve != oldWidget.curve) _engine.curve = widget.curve;
    if (widget.gridSize != oldWidget.gridSize ||
        widget.seed != oldWidget.seed) {
      _engine
        ..gridSize = widget.gridSize
        ..seed = widget.seed
        ..invalidateGrid();
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      widget.controller?._showing = _showing;
    }
    if (widget.showSecond != oldWidget.showSecond) {
      _setShowing(widget.showSecond, null, notify: false);
    }
    if (!widget.enabled) _finish();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _wave.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _finish() {
    if (_wave.isAnimating) _wave.stop();
    _wave.value = 1.0;
    _handleTick();
  }

  void _handleTick() {
    _engine.elapsed = _wave.value * _engine.totalMs;
    final bool visible = _showing ? _wave.value >= 0.5 : _wave.value < 0.5;
    if (visible != _secondVisible && mounted) {
      setState(() => _secondVisible = visible);
    }
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final PixelSwapController controller = widget.controller!;
    _setShowing(controller._showing, controller._origin);
  }

  void _setShowing(bool show, Offset? origin, {bool notify = true}) {
    widget.controller?._showing = show;
    if (show == _showing) return;
    _showing = show;
    _engine.retarget(show, origin);
    if (_instant) {
      _finish();
    } else {
      _wave.forward(from: 0.0);
    }
    if (notify) widget.onChanged?.call(show);
  }

  void _handleEnter(PointerEnterEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    _setShowing(true, event.localPosition);
  }

  void _handleExit(PointerExitEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    _setShowing(false, event.localPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.trigger == PixelSwapTrigger.hover &&
        details.kind != PointerDeviceKind.touch) {
      return;
    }
    _setShowing(!_showing, details.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final bool second = _secondVisible;
    Widget result = Stack(
      children: <Widget>[
        ExcludeSemantics(
          excluding: second,
          child: ExcludeFocus(
            excluding: second,
            child: IgnorePointer(ignoring: second, child: widget.first),
          ),
        ),
        Positioned.fill(
          child: _PixelClip(
            wave: _engine,
            gap: widget.gap,
            child: ExcludeSemantics(
              excluding: !second,
              child: ExcludeFocus(
                excluding: !second,
                child: IgnorePointer(ignoring: !second, child: widget.second),
              ),
            ),
          ),
        ),
      ],
    );
    if (widget.borderRadius != null) {
      result = ClipRRect(borderRadius: widget.borderRadius!, child: result);
    }

    final bool on = widget.enabled;
    final bool hover = on && widget.trigger == PixelSwapTrigger.hover;
    final bool tap = on && widget.trigger != PixelSwapTrigger.manual;
    return MouseRegion(
      opaque: false,
      onEnter: hover ? _handleEnter : null,
      onExit: hover ? _handleExit : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: tap ? _handleTapUp : null,
        child: result,
      ),
    );
  }
}

/// Per-cell timing of the current wave. Notifies when the elapsed time
/// changes so the clip repaints.
class _PixelWave extends ChangeNotifier {
  _PixelWave({
    required this.gridSize,
    required this.durationMs,
    required this.cellMs,
    required this.curve,
    required this.seed,
    required this.target,
  });

  int gridSize;
  double durationMs;
  double cellMs;
  Curve curve;
  int seed;

  /// Whether the wave builds the second child in (true) or out (false).
  bool target;

  /// Wave origin in local coordinates; null means the center.
  Offset? origin;

  /// Share of [durationMs] used for random jitter instead of distance.
  static const double _jitterShare = 0.18;

  /// Hiding: a tiny anticipation swell, then a smooth shrink.
  static const Curve _hideCurve = Cubic(0.4, -0.3, 0.4, 1.0);

  double _elapsed = double.infinity;

  Size _size = Size.zero;
  bool _gridValid = false;
  bool _delaysValid = false;

  /// Number of cells across.
  int cols = 0;

  /// Number of cells down.
  int rows = 0;

  /// Side of one cell.
  double cell = 0;

  /// Top-left corner of the grid, which is centered on the widget.
  Offset gridOrigin = Offset.zero;

  Float32List _from = Float32List(0);
  Float32List _delay = Float32List(0);
  Float32List _jitter = Float32List(0);

  /// Total wave time: travel plus one cell animation.
  double get totalMs => durationMs + cellMs;

  /// Milliseconds since the current wave started.
  double get elapsed => _elapsed;
  set elapsed(double value) {
    if (value == _elapsed) return;
    _elapsed = value;
    notifyListeners();
  }

  /// Whether every cell has reached the target.
  bool get isSettled => _elapsed >= totalMs - 0.001;

  void invalidateGrid() {
    _gridValid = false;
    notifyListeners();
  }

  void invalidateDelays() {
    _delaysValid = false;
    notifyListeners();
  }

  /// Builds the grid for [size] when needed.
  void layout(Size size) {
    if (!_gridValid || size != _size) {
      _size = size;
      _gridValid = true;
      final double shortest = size.shortestSide;
      if (shortest <= 0) {
        cols = 0;
        rows = 0;
        return;
      }
      cell = shortest / gridSize;
      cols = math.max(1, (size.width / cell - 1e-6).ceil());
      rows = math.max(1, (size.height / cell - 1e-6).ceil());
      gridOrigin = Offset(
        (size.width - cols * cell) / 2,
        (size.height - rows * cell) / 2,
      );
      final int count = cols * rows;
      _from = Float32List(count)..fillRange(0, count, target ? 0.0 : 1.0);
      _delay = Float32List(count);
      final math.Random random = math.Random(seed);
      _jitter = Float32List(count);
      for (int i = 0; i < count; i++) {
        _jitter[i] = random.nextDouble();
      }
      _delaysValid = false;
    }
    if (!_delaysValid) _computeDelays();
  }

  void _computeDelays() {
    _delaysValid = true;
    final int count = cols * rows;
    if (count == 0) return;
    final Offset o = origin ?? _size.center(Offset.zero);
    final Float64List distance = Float64List(count);
    double maxDistance = 0;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < cols; i++) {
        final Offset c = cellCenter(i, j);
        final double d = (c - o).distance;
        distance[j * cols + i] = d;
        if (d > maxDistance) maxDistance = d;
      }
    }
    final double travel = durationMs * (1 - _jitterShare);
    final double jitter = durationMs * _jitterShare;
    for (int i = 0; i < count; i++) {
      final double from = _from[i];
      final bool moving = from > 0.001 && (from - 1).abs() > 0.001;
      _delay[i] = moving
          ? 0.0
          : (maxDistance > 0 ? distance[i] / maxDistance : 0) * travel +
                _jitter[i] * jitter;
    }
  }

  /// Center of the cell at column [i] and row [j].
  Offset cellCenter(int i, int j) => Offset(
    gridOrigin.dx + (i + 0.5) * cell,
    gridOrigin.dy + (j + 0.5) * cell,
  );

  /// Start delay in milliseconds of the cell at column [i], row [j].
  double delayAt(int i, int j) => _delay[j * cols + i];

  /// Current scale of the cell at index [index]; 0 is hidden, 1 is whole.
  double valueAtIndex(int index) {
    final double from = _from[index];
    final double to = target ? 1.0 : 0.0;
    if (_elapsed == double.infinity) return to;
    final double local = (_elapsed - _delay[index]) / cellMs;
    if (local <= 0) return from;
    if (local >= 1) return to;
    final double c = target
        ? curve.transform(local)
        : _hideCurve.transform(local);
    return from + (to - from) * c;
  }

  /// Fraction of the gap shown around the cell at [index]: cells being
  /// built in close their gap as they settle, so only the wave front
  /// shows the mosaic and the finished image has no seams.
  double gapFactorAtIndex(int index) {
    if (!target) return 1.0;
    if (_elapsed == double.infinity) return 0.0;
    final double local = (_elapsed - _delay[index]) / cellMs;
    return 1.0 - local.clamp(0.0, 1.0);
  }

  /// Current scale of the cell at column [i], row [j].
  double valueAt(int i, int j) => valueAtIndex(j * cols + i);

  /// Starts a new wave towards [show] from [newOrigin], continuing from
  /// each cell's current scale.
  void retarget(bool show, Offset? newOrigin) {
    final int count = _gridValid ? cols * rows : 0;
    for (int i = 0; i < count; i++) {
      _from[i] = valueAtIndex(i).clamp(0.0, 1.5);
    }
    if (!_gridValid) _from.fillRange(0, _from.length, show ? 0.0 : 1.0);
    target = show;
    origin = newOrigin;
    _elapsed = 0;
    _delaysValid = false;
    if (_gridValid) _computeDelays();
    notifyListeners();
  }
}

/// Paints its child through a clip made of the visible cells of a
/// [_PixelWave].
class _PixelClip extends SingleChildRenderObjectWidget {
  const _PixelClip({required this.wave, required this.gap, super.child});

  final _PixelWave wave;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPixelClip(wave, gap);

  @override
  void updateRenderObject(BuildContext context, _RenderPixelClip renderObject) {
    renderObject
      ..wave = wave
      ..gap = gap;
  }
}

class _RenderPixelClip extends RenderProxyBox {
  _RenderPixelClip(this._wave, this._gap);

  _PixelWave _wave;

  /// The wave driving the clip.
  _PixelWave get wave => _wave;
  set wave(_PixelWave value) {
    if (identical(value, _wave)) return;
    if (attached) _wave.removeListener(markNeedsPaint);
    _wave = value;
    if (attached) _wave.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _gap;

  /// Space between cells during the transition.
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsPaint();
  }

  final LayerHandle<ClipPathLayer> _clipLayer = LayerHandle<ClipPathLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _wave.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _wave.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    final _PixelWave wave = _wave;
    wave.layout(size);
    if (wave.isSettled) {
      _clipLayer.layer = null;
      if (wave.target) context.paintChild(child, offset);
      return;
    }
    final Rect bounds = Offset.zero & size;
    final double gap = math.min(_gap, wave.cell * 0.5);
    final Path path = Path();
    bool any = false;
    for (int j = 0; j < wave.rows; j++) {
      for (int i = 0; i < wave.cols; i++) {
        final int index = j * wave.cols + i;
        final double v = wave.valueAtIndex(index);
        if (v <= 0.001) continue;
        final Offset c = wave.cellCenter(i, j);
        // Cells overlap by a hair when no gap shows, so no seams appear.
        final double g = gap * wave.gapFactorAtIndex(index);
        final double half = (wave.cell - g) / 2 + (g < 0.5 ? 0.5 - g : 0.0);
        final double h = half * v;
        final Rect cellRect = Rect.fromLTRB(
          c.dx - h,
          c.dy - h,
          c.dx + h,
          c.dy + h,
        ).intersect(bounds);
        if (cellRect.isEmpty) continue;
        path.addRect(cellRect);
        any = true;
      }
    }
    if (!any) {
      _clipLayer.layer = null;
      return;
    }
    _clipLayer.layer = context.pushClipPath(
      needsCompositing,
      offset,
      bounds,
      path,
      super.paint,
      oldLayer: _clipLayer.layer,
    );
  }
}
