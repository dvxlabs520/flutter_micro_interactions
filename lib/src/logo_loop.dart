import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// The direction in which a [LogoLoop] scrolls its content.
enum LogoLoopDirection {
  /// Content moves toward the visual left edge. This is the visual left,
  /// even in right-to-left layouts.
  left,

  /// Content moves toward the visual right edge. This is the visual right,
  /// even in right-to-left layouts.
  right,

  /// Content moves toward the top edge.
  up,

  /// Content moves toward the bottom edge.
  down,
}

/// A seamless, infinitely scrolling strip of widgets, such as partner logos,
/// technology badges, chips or short text.
///
/// ```dart
/// LogoLoop(
///   speed: 60,
///   gap: 40,
///   hoverSpeed: 15,
///   children: const <Widget>[
///     FlutterLogo(size: 40),
///     Icon(Icons.cloud, size: 40),
///     Text('Acme'),
///   ],
/// )
/// ```
///
/// The [children] are laid out once in a row (or a column for
/// [LogoLoopDirection.up] and [LogoLoopDirection.down]) with [gap] after every item. That run is repeated just enough
/// times to cover the visible area plus one more run, and the copies are
/// shifted by an offset that wraps around the run length, so the loop has
/// no visible seam or jump. Every copy is its own repaint boundary and the
/// offset is applied at paint time only: scrolling never rebuilds or lays
/// out the children. Movement is driven by a ticker with the real frame
/// time, so [speed] is the same at 60, 90 or 120 frames per second.
///
/// The loop fills the available main-axis space. When the main axis is
/// unbounded (for example inside a horizontal [Row] without [Expanded]) it
/// is as long as one run. Its cross-axis size is the size of the tallest
/// (or widest) child.
///
/// Hovering with a mouse pauses the loop when [pauseOnHover] is true, or
/// slows it to [hoverSpeed] when that is set. Every speed change (hover,
/// a new [speed], a pause) eases over [speedChangeDuration] instead of
/// snapping. With [scaleOnHover] the item under the mouse grows to
/// [hoverScale].
///
/// Children must not use [GlobalKey]s, because each child appears several
/// times in the tree.
///
/// Accessibility: assistive technology sees the children exactly once; the
/// repeated copies are excluded from semantics. Under reduced motion, or
/// when [enabled] is false, nothing scrolls automatically: a single run is
/// shown from the start edge inside a [SingleChildScrollView], so the user
/// can still scroll to items that do not fit. No edge fade is applied in
/// that static state.
class LogoLoop extends StatefulWidget {
  /// Creates a seamless looping strip of [children].
  const LogoLoop({
    super.key,
    required this.children,
    this.speed = 60.0,
    this.direction = LogoLoopDirection.left,
    this.gap = 32.0,
    this.pauseOnHover = true,
    this.hoverSpeed,
    this.speedChangeDuration = const Duration(milliseconds: 400),
    this.fadeOut = true,
    this.fadeExtent = 48.0,
    this.scaleOnHover = false,
    this.hoverScale = 1.1,
    this.enabled = true,
  }) : assert(
         speed < double.infinity && speed > double.negativeInfinity,
         'speed must be finite',
       ),
       assert(gap >= 0, 'gap must not be negative'),
       assert(
         hoverSpeed == null ||
             (hoverSpeed < double.infinity &&
                 hoverSpeed > double.negativeInfinity),
         'hoverSpeed must be finite',
       ),
       assert(fadeExtent >= 0, 'fadeExtent must not be negative'),
       assert(hoverScale > 0, 'hoverScale must be positive');

  /// The widgets to loop, in order. Typically logos, icons, chips or short
  /// [Text]s. They must not use [GlobalKey]s.
  final List<Widget> children;

  /// Scrolling speed in logical pixels per second, along [direction].
  /// A negative value scrolls the opposite way. Defaults to 60.
  final double speed;

  /// The direction the content moves in. Defaults to
  /// [LogoLoopDirection.left]. [LogoLoopDirection.left] and
  /// [LogoLoopDirection.right] are visual directions and do not flip in
  /// right-to-left layouts; only the order of the children does.
  final LogoLoopDirection direction;

  /// Space in logical pixels after every child, including the last one so
  /// the repeat keeps an even rhythm. Defaults to 32.
  final double gap;

  /// Whether hovering with a mouse pauses the loop. Ignored when
  /// [hoverSpeed] is set. Defaults to true.
  final bool pauseOnHover;

  /// Speed, in logical pixels per second along [direction], used while a
  /// mouse hovers the loop. When set it replaces the full pause of
  /// [pauseOnHover]. Defaults to null.
  final double? hoverSpeed;

  /// How long a speed change takes to ease in, for example when the mouse
  /// enters or leaves or when [speed] changes. Defaults to 400
  /// milliseconds. [Duration.zero] switches speed instantly.
  final Duration speedChangeDuration;

  /// Whether the two ends of the strip fade to transparent. Defaults to
  /// true.
  final bool fadeOut;

  /// Length of the edge fade in logical pixels, at each end. Defaults to
  /// 48. Capped to half of the visible length.
  final double fadeExtent;

  /// Whether the single item under the mouse scales up to [hoverScale].
  /// Defaults to false.
  final bool scaleOnHover;

  /// Scale of an item under the mouse when [scaleOnHover] is true.
  /// Defaults to 1.1.
  final double hoverScale;

  /// When false the loop does not move and renders the static layout
  /// described in the class documentation. Defaults to true.
  final bool enabled;

  @override
  State<LogoLoop> createState() => _LogoLoopState();
}

class _LogoLoopState extends State<LogoLoop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _shift = ValueNotifier<double>(0.0);
  final _SpeedRamp _ramp = _SpeedRamp();
  Duration _lastElapsed = Duration.zero;
  double _runExtent = 0.0;
  bool _hovered = false;
  bool _reducedMotion = false;
  bool _rtl = false;

  /// Whether the previous [_sync] ran in the moving state.
  bool _wasAnimating = false;

  /// Whether the loop is allowed to move at all.
  bool get _animating =>
      widget.enabled && !_reducedMotion && widget.children.isNotEmpty;

  bool get _horizontal =>
      widget.direction == LogoLoopDirection.left ||
      widget.direction == LogoLoopDirection.right;

  /// Speed requested right now, along [LogoLoop.direction].
  double get _targetSpeed {
    if (!_animating) return 0.0;
    if (_hovered) {
      return widget.hoverSpeed ?? (widget.pauseOnHover ? 0.0 : widget.speed);
    }
    return widget.speed;
  }

  /// Converts a speed along [LogoLoop.direction] into the sign of the
  /// track offset, which runs from the start edge of the layout.
  double get _directionSign {
    double sign;
    switch (widget.direction) {
      case LogoLoopDirection.left:
      case LogoLoopDirection.up:
        sign = 1.0;
      case LogoLoopDirection.right:
      case LogoLoopDirection.down:
        sign = -1.0;
    }
    // In right-to-left layouts the track is anchored to the right edge, so
    // moving visually left means the offset shrinks.
    if (_horizontal && _rtl) sign = -sign;
    return sign;
  }

  double get _rampSeconds =>
      widget.speedChangeDuration.inMicroseconds /
      Duration.microsecondsPerSecond;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    _sync();
  }

  @override
  void didUpdateWidget(LogoLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction &&
        _horizontal !=
            (oldWidget.direction == LogoLoopDirection.left ||
                oldWidget.direction == LogoLoopDirection.right)) {
      _shift.value = 0.0;
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shift.dispose();
    super.dispose();
  }

  /// Retargets the speed ramp and starts or stops the ticker to match.
  void _sync() {
    if (!_animating) {
      _wasAnimating = false;
      _hovered = false;
      _ramp.snap(0.0);
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (!_wasAnimating) {
      // First start, or back from a static state: begin at full speed.
      _wasAnimating = true;
      _ramp.snap(_targetSpeed);
    } else {
      _ramp.retarget(_targetSpeed, _rampSeconds);
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
    final double run = _runExtent;
    if (distance != 0.0 && run > 0.0) {
      // Dart's % always returns a value in [0, run) for a positive run.
      _shift.value = (_shift.value + _directionSign * distance) % run;
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

  void _handleRunExtent(double extent) {
    _runExtent = extent;
  }

  /// One run of children with a trailing gap after each item.
  Widget _buildRun({required bool interactive}) {
    final List<Widget> items = <Widget>[];
    final double gap = widget.gap;
    for (final Widget child in widget.children) {
      items.add(
        interactive && widget.scaleOnHover
            ? _LoopItem(scale: widget.hoverScale, child: child)
            : child,
      );
      if (gap > 0) {
        items.add(_horizontal ? SizedBox(width: gap) : SizedBox(height: gap));
      }
    }
    return Flex(
      direction: _horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items,
    );
  }

  Widget _buildTrack(BuildContext context, int copies) {
    final Widget run = _buildRun(interactive: true);
    final Widget excludedRun = ExcludeSemantics(child: run);
    return _LoopTrack(
      axis: _horizontal ? Axis.horizontal : Axis.vertical,
      anchorEnd: _horizontal && _rtl,
      shift: _shift,
      onRunExtent: _handleRunExtent,
      children: <Widget>[
        for (int i = 0; i < copies; i++)
          RepaintBoundary(
            key: ValueKey<int>(i),
            child: i == 0 ? run : excludedRun,
          ),
      ],
    );
  }

  Widget _buildStatic() {
    final Axis axis = _horizontal ? Axis.horizontal : Axis.vertical;
    final Widget run = _buildRun(interactive: false);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = axis == Axis.horizontal
            ? constraints.hasBoundedWidth
            : constraints.hasBoundedHeight;
        if (!bounded) return run;
        return SingleChildScrollView(scrollDirection: axis, child: run);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reducedMotion || widget.children.isEmpty) {
      return _buildStatic();
    }
    Widget loop = _LoopBuilder(builder: _buildTrack);
    if (widget.fadeOut && widget.fadeExtent > 0) {
      final bool horizontal = _horizontal;
      final double fadeExtent = widget.fadeExtent;
      loop = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) {
          final double length = horizontal ? bounds.width : bounds.height;
          final double stop = length > 0
              ? math.min(fadeExtent / length, 0.5)
              : 0.0;
          return LinearGradient(
            begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
            end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
            colors: const <Color>[
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: <double>[0.0, stop, 1.0 - stop, 1.0],
          ).createShader(bounds);
        },
        child: loop,
      );
    }
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _setHovered(true),
      onExit: (PointerExitEvent event) => _setHovered(false),
      child: loop,
    );
  }
}

/// Eases a speed value toward a target over a fixed time with
/// [Curves.easeInOut], and integrates the distance travelled.
class _SpeedRamp {
  double current = 0.0;
  double _from = 0.0;
  double _to = 0.0;
  double _elapsed = 0.0;
  double _duration = 0.0;

  double get target => _to;

  bool get isSettled => _elapsed >= _duration;

  /// Jumps to [value] immediately.
  void snap(double value) {
    current = value;
    _from = value;
    _to = value;
    _elapsed = 0.0;
    _duration = 0.0;
  }

  /// Starts easing from the current speed to [value] over [seconds].
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

  /// Advances time by [dt] seconds and returns the distance covered,
  /// using the average speed over the step.
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

/// One loop item that scales up while the mouse is over it.
class _LoopItem extends StatefulWidget {
  const _LoopItem({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  State<_LoopItem> createState() => _LoopItemState();
}

class _LoopItemState extends State<_LoopItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
      onExit: (PointerExitEvent event) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Builds the track during layout with exactly as many copies of the run
/// as the current size needs, so the loop is complete on every frame,
/// including the first one and during resizes.
class _LoopBuilder extends AbstractLayoutBuilder<int> {
  const _LoopBuilder({required this.builder});

  @override
  final Widget Function(BuildContext context, int copies) builder;

  @override
  _RenderLoopBuilder createRenderObject(BuildContext context) =>
      _RenderLoopBuilder();
}

class _RenderLoopBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<int, RenderBox> {
  /// Number of copies the builder is asked for. Two covers the common case
  /// of a run at least as long as the viewport.
  int _copies = 2;

  @override
  int get layoutInfo => _copies;

  @override
  void performLayout() {
    runLayoutCallback();
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    if (child is _RenderLoopTrack && child.requiredCopies != _copies) {
      _copies = child.requiredCopies;
      runLayoutCallback();
      this.child!.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(this.child!.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }
}

class _LoopTrack extends MultiChildRenderObjectWidget {
  const _LoopTrack({
    required this.axis,
    required this.anchorEnd,
    required this.shift,
    required this.onRunExtent,
    required super.children,
  });

  final Axis axis;
  final bool anchorEnd;
  final ValueListenable<double> shift;
  final ValueChanged<double> onRunExtent;

  @override
  _RenderLoopTrack createRenderObject(BuildContext context) {
    return _RenderLoopTrack(shift, onRunExtent)
      ..axis = axis
      ..anchorEnd = anchorEnd;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderLoopTrack renderObject) {
    renderObject
      ..axis = axis
      ..anchorEnd = anchorEnd
      ..shift = shift
      ..onRunExtent = onRunExtent;
  }
}

class _LoopTrackParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out identical copies of one run and paints them shifted by
/// [shift] modulo the run length. Only paint depends on [shift].
class _RenderLoopTrack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LoopTrackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LoopTrackParentData> {
  _RenderLoopTrack(this._shift, this.onRunExtent);

  /// Upper bound on copies, guarding against tiny runs in huge viewports.
  static const int _maxCopies = 200;

  ValueChanged<double> onRunExtent;

  Axis get axis => _axis;
  Axis _axis = Axis.horizontal;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  /// Whether copies start at the end edge (right-to-left layouts).
  bool get anchorEnd => _anchorEnd;
  bool _anchorEnd = false;
  set anchorEnd(bool value) {
    if (value == _anchorEnd) return;
    _anchorEnd = value;
    markNeedsPaint();
  }

  ValueListenable<double> get shift => _shift;
  ValueListenable<double> _shift;
  set shift(ValueListenable<double> value) {
    if (value == _shift) return;
    if (attached) _shift.removeListener(markNeedsPaint);
    _shift = value;
    if (attached) _shift.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _runExtent = 0.0;

  /// How many copies cover the viewport for any shift value.
  int requiredCopies = 1;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LoopTrackParentData) {
      child.parentData = _LoopTrackParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shift.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _shift.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  bool get _horizontal => _axis == Axis.horizontal;

  @override
  void performLayout() {
    final BoxConstraints childConstraints = _horizontal
        ? BoxConstraints(maxHeight: constraints.maxHeight)
        : BoxConstraints(maxWidth: constraints.maxWidth);
    double run = 0.0;
    double cross = 0.0;
    RenderBox? child = firstChild;
    bool first = true;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final Size childSize = child.size;
      if (first) {
        run = _horizontal ? childSize.width : childSize.height;
        first = false;
      }
      cross = math.max(cross, _horizontal ? childSize.height : childSize.width);
      child = childAfter(child);
    }
    final double main =
        (_horizontal
            ? constraints.hasBoundedWidth
            : constraints.hasBoundedHeight)
        ? (_horizontal ? constraints.maxWidth : constraints.maxHeight)
        : run;
    size = constraints.constrain(
      _horizontal ? Size(main, cross) : Size(cross, main),
    );
    final double viewport = _horizontal ? size.width : size.height;
    _runExtent = run;
    requiredCopies = run > 0.0
        ? math.min((viewport / run).ceil() + 1, _maxCopies)
        : 1;
    onRunExtent(run);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) return;
    // Clip along the main axis only, so items scaled on hover can grow past
    // the cross-axis edges.
    final Rect clip = _horizontal
        ? Rect.fromLTRB(0, -size.height, size.width, size.height * 2)
        : Rect.fromLTRB(-size.width, 0, size.width * 2, size.height);
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      _paintCopies,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintCopies(PaintingContext context, Offset offset) {
    final double run = _runExtent;
    final double viewport = _horizontal ? size.width : size.height;
    final double crossSize = _horizontal ? size.height : size.width;
    final double s = run > 0.0 ? _shift.value % run : 0.0;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _LoopTrackParentData parentData =
          child.parentData! as _LoopTrackParentData;
      final Size childSize = child.size;
      final double childMain = _horizontal ? childSize.width : childSize.height;
      final double childCross = _horizontal
          ? childSize.height
          : childSize.width;
      // Position measured from the start edge of the layout.
      final double fromStart = index * run - s;
      final double main = _anchorEnd
          ? viewport - fromStart - childMain
          : fromStart;
      final double crossPos = (crossSize - childCross) / 2;
      parentData.offset = _horizontal
          ? Offset(main, crossPos)
          : Offset(crossPos, main);
      if (fromStart < viewport && fromStart + childMain > 0.0) {
        context.paintChild(child, offset + parentData.offset);
      }
      index++;
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
