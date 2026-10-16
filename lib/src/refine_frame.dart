import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'status_mark.dart';
import 'utils/motion.dart';

/// How a [RefineFrame] reveals each new stage over the previous one.
enum RefineRevealStyle {
  /// A soft-edged circle grows from [RefineFrame.revealOrigin] until it
  /// covers the frame.
  radial,

  /// A soft-edged diagonal front sweeps from the top start corner to the
  /// bottom end corner.
  diagonal,

  /// The new stage fades in over the previous one.
  fade,
}

/// Builds the text of a [RefineFrame] progress pill from the 1-based
/// [step] and the [total] number of stages, for example 'Refining 2/4'.
typedef RefineLabelBuilder = String Function(int step, int total);

/// A media frame for image generation that steps a picture through its
/// refinement stages (noisy, blurry, sharp) without any layout shift.
///
/// ```dart
/// RefineFrame(
///   stage: step, // 0 .. stages.length - 1
///   stages: <Widget>[
///     Image.memory(draft1, fit: BoxFit.cover),
///     Image.memory(draft2, fit: BoxFit.cover),
///     Image.memory(finalImage, fit: BoxFit.cover),
///   ],
/// )
/// ```
///
/// The frame always has the same [aspectRatio] and [borderRadius], so its
/// size never changes between stages. Each stage widget is stretched to
/// fill it; images should use `BoxFit.cover`. When [stage] changes, the
/// new stage "develops" over the previous one during [duration]: it is
/// revealed through an expanding soft-edged mask ([revealStyle]) while a
/// faint band of light rides the reveal front. If [stage] changes again
/// during a reveal, the latest value is revealed right after, so the
/// frame never jumps.
///
/// While [isGenerating] is `true` and the last stage is not yet shown, an
/// overlay adds a subtle animated film grain and a slow scanline, and a
/// progress pill ('Refining 2/4', see [labelBuilder]) sits in the top
/// start corner. Both fade out when the final stage arrives.
///
/// Use [RefineFrame.blurred] to build the stages from a single image: the
/// earlier stages show it blurred, desaturated and grainy, and each stage
/// is sharper than the previous one.
///
/// Accessibility: the frame is one image node labelled with
/// [semanticLabel] ('Image' by default), followed by ', refining step 2 of
/// 4' while generating. The stage widgets themselves are not exposed.
///
/// Under reduced motion, or when [enabled] is `false`, stages switch
/// instantly with no mask and no light band, and the overlay has no grain
/// or scanline; the progress pill is still shown.
class RefineFrame extends StatefulWidget {
  /// Creates a refine frame showing `stages[stage]`.
  ///
  /// [stages] must not be empty, [stage] must be a valid index of
  /// [stages] (checked when the widget is built) and [aspectRatio] must be
  /// positive.
  const RefineFrame({
    super.key,
    required this.stages,
    required this.stage,
    this.isGenerating = true,
    this.aspectRatio = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeInOutCubic,
    this.revealStyle = RefineRevealStyle.radial,
    this.revealOrigin = Alignment.center,
    this.showProgress = true,
    this.showGrain = true,
    this.labelBuilder,
    this.backgroundColor,
    this.semanticLabel,
    this.enabled = true,
  }) : assert(stage >= 0, 'stage must not be negative'),
       assert(aspectRatio > 0.0, 'aspectRatio must be positive');

  /// Builds the stages from a single [image]: [steps] versions that go
  /// from heavily blurred, desaturated and grainy to the sharp original.
  ///
  /// The first stage uses a blur sigma of [maxBlur] and a grain opacity of
  /// [noise]; both decrease with each step and the last stage is the plain
  /// image. [steps] must be at least 2 and [stage] a valid step index.
  RefineFrame.blurred({
    super.key,
    required ImageProvider image,
    required this.stage,
    int steps = 4,
    double maxBlur = 22.0,
    double noise = 0.45,
    BoxFit fit = BoxFit.cover,
    this.isGenerating = true,
    this.aspectRatio = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeInOutCubic,
    this.revealStyle = RefineRevealStyle.radial,
    this.revealOrigin = Alignment.center,
    this.showProgress = true,
    this.showGrain = true,
    this.labelBuilder,
    this.backgroundColor,
    this.semanticLabel,
    this.enabled = true,
  }) : assert(steps >= 2, 'steps must be at least 2'),
       assert(stage >= 0 && stage < steps, 'stage must be in [0, steps)'),
       assert(maxBlur >= 0.0, 'maxBlur must not be negative'),
       assert(noise >= 0.0 && noise <= 1.0, 'noise must be in [0, 1]'),
       assert(aspectRatio > 0.0, 'aspectRatio must be positive'),
       stages = List<Widget>.generate(
         steps,
         (int i) => _BlurredStage(
           image: image,
           fit: fit,
           quality: i / (steps - 1),
           maxBlur: maxBlur,
           noise: noise,
         ),
         growable: false,
       );

  /// The stages, from the roughest to the final image. Each one is
  /// stretched to fill the frame.
  final List<Widget> stages;

  /// The index of the stage to show. Changing it reveals the new stage.
  final int stage;

  /// Whether generation is still running. While `true` and [stage] is not
  /// the last one, the grain overlay and the progress pill are shown.
  /// Defaults to `true`.
  final bool isGenerating;

  /// The width to height ratio of the frame. Defaults to 1.
  ///
  /// The frame takes the available width (or, when only the height is
  /// bounded, the available height) and derives the other side from this
  /// ratio. When neither side is bounded, for example inside an
  /// [UnconstrainedBox], the frame is [fallbackWidth] wide.
  final double aspectRatio;

  /// The corner radius of the frame. Defaults to 16.
  final BorderRadius borderRadius;

  /// The length of one stage reveal. Defaults to 700 milliseconds.
  final Duration duration;

  /// The curve of the reveal. Defaults to [Curves.easeInOutCubic].
  final Curve curve;

  /// How a new stage is revealed. Defaults to [RefineRevealStyle.radial].
  final RefineRevealStyle revealStyle;

  /// The point a [RefineRevealStyle.radial] reveal grows from. Defaults
  /// to [Alignment.center].
  final Alignment revealOrigin;

  /// Whether the progress pill is shown while generating. Defaults to
  /// `true`.
  final bool showProgress;

  /// Whether the animated grain and scanline overlay is shown while
  /// generating. Defaults to `true`.
  final bool showGrain;

  /// Builds the progress pill text. Defaults to 'Refining 2/4'.
  final RefineLabelBuilder? labelBuilder;

  /// The color behind the stages, visible while an image loads. Defaults
  /// to [ColorScheme.surfaceContainerHighest].
  final Color? backgroundColor;

  /// The announced name of the image. Defaults to 'Image'.
  final String? semanticLabel;

  /// When `false` stages switch instantly and the overlay is still.
  /// Defaults to `true`.
  final bool enabled;

  /// The width used when the frame is laid out with neither a bounded
  /// width nor a bounded height, for example inside an [UnconstrainedBox]
  /// or a [Row] in one: 320 logical pixels. The height then follows
  /// [aspectRatio]. Give the frame a width (for example with a [SizedBox])
  /// to choose another size.
  static const double fallbackWidth = 320.0;

  /// The default progress pill text: 'Refining 2/4'.
  static String defaultLabel(int step, int total) => 'Refining $step/$total';

  @override
  State<RefineFrame> createState() => _RefineFrameState();
}

class _RefineFrameState extends State<RefineFrame>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late CurvedAnimation _revealCurve;
  late final AnimationController _overlay;
  late final AnimationController _grain;

  /// Keeps each stage's element (and image state) alive while it moves
  /// from the masked layer to the base layer.
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};

  /// The stage fully shown underneath.
  int _base = 0;

  /// The stage being revealed over [_base], if any.
  int? _incoming;

  /// The latest stage requested during a reveal, revealed next.
  int? _pending;

  bool _reduced = false;

  bool get _animate => widget.enabled && !_reduced;

  bool get _generating =>
      widget.isGenerating && widget.stage < widget.stages.length - 1;

  void _debugCheckStage() {
    assert(widget.stages.isNotEmpty, 'stages must not be empty');
    assert(
      widget.stage < widget.stages.length,
      'stage must be a valid index of stages',
    );
  }

  @override
  void initState() {
    super.initState();
    _debugCheckStage();
    _base = widget.stage;
    _reveal = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onRevealStatus);
    _revealCurve = CurvedAnimation(parent: _reveal, curve: widget.curve);
    _overlay = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: _generating ? 1.0 : 0.0,
    )..addStatusListener(_onOverlayStatus);
    _grain = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(RefineFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckStage();
    if (widget.duration != oldWidget.duration) {
      _reveal.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _revealCurve.dispose();
      _revealCurve = CurvedAnimation(parent: _reveal, curve: widget.curve);
    }
    final int count = widget.stages.length;
    if (_base >= count) {
      _base = count - 1;
    }
    if (_incoming != null && _incoming! >= count) {
      _incoming = null;
      _reveal.value = 0.0;
    }
    if (_pending != null && _pending! >= count) {
      _pending = null;
    }
    _goTo(widget.stage);
    _syncMotion();
  }

  @override
  void dispose() {
    _reveal.removeStatusListener(_onRevealStatus);
    _overlay.removeStatusListener(_onOverlayStatus);
    _revealCurve.dispose();
    _reveal.dispose();
    _overlay.dispose();
    _grain.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) =>
      _keys.putIfAbsent(index, () => GlobalKey(debugLabel: 'stage $index'));

  /// Moves towards [target]: reveals it now, or after the running reveal.
  void _goTo(int target) {
    if (!_animate) {
      _finishNow(target);
      return;
    }
    final int? incoming = _incoming;
    if (incoming == null) {
      if (target != _base) {
        _startReveal(target);
      }
      return;
    }
    _pending = target == incoming ? null : target;
  }

  void _startReveal(int target) {
    _incoming = target;
    _pending = null;
    _reveal.forward(from: 0.0);
  }

  void _finishNow(int target) {
    _reveal.stop();
    _base = target;
    _incoming = null;
    _pending = null;
    _reveal.value = 0.0;
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    final int? incoming = _incoming;
    if (incoming == null) {
      return;
    }
    setState(() {
      _base = incoming;
      _incoming = null;
      final int? pending = _pending;
      _pending = null;
      if (pending != null && pending != _base) {
        _startReveal(pending);
      } else {
        _reveal.value = 0.0;
      }
    });
    _keys.removeWhere(
      (int index, GlobalKey key) => index != _base && index != _incoming,
    );
  }

  void _onOverlayStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _syncMotion();
    }
  }

  /// Fades the overlay to match [_generating] and runs the grain loop only
  /// while the overlay can be seen.
  void _syncMotion() {
    final bool visible = _generating;
    if (!_animate) {
      if (_reveal.isAnimating) {
        _finishNow(widget.stage);
      }
      _overlay
        ..stop()
        ..value = visible ? 1.0 : 0.0;
      _grain.stop();
      return;
    }
    if (visible) {
      _overlay.forward();
    } else {
      _overlay.reverse();
    }
    final bool grainRuns =
        widget.showGrain && (visible || _overlay.value > 0.0);
    if (grainRuns) {
      if (!_grain.isAnimating) {
        _grain.repeat();
      }
    } else {
      _grain.stop();
    }
  }

  Widget _stageLayer(int index) {
    return KeyedSubtree(key: _keyFor(index), child: widget.stages[index]);
  }

  Widget _buildPill(BuildContext context, int step, int total) {
    final ThemeData theme = Theme.of(context);
    final String text = (widget.labelBuilder ?? RefineFrame.defaultLabel)(
      step,
      total,
    );
    final TextStyle style =
        (theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12.0))
            .copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
              fontFeatures: const <ui.FontFeature>[
                ui.FontFeature.tabularFigures(),
              ],
            );
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999.0)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0x66000000)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 5.0, 11.0, 5.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StatusMark(
                  status: MicroStatus.loading,
                  progress: step / total,
                  size: 13.0,
                  strokeWidth: 1.8,
                  loadingColor: const Color(0xFFFFFFFF),
                  enabled: _animate,
                ),
                const SizedBox(width: 6.0),
                Text(text, style: style, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextDirection direction = Directionality.of(context);
    final int total = widget.stages.length;
    final int step = widget.stage + 1;
    final int? incoming = _incoming;

    final List<Widget> layers = <Widget>[
      _stageLayer(_base),
      if (incoming != null) ...<Widget>[
        AnimatedBuilder(
          animation: _revealCurve,
          builder: (BuildContext context, Widget? child) {
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) => _RevealGeometry.maskShader(
                bounds,
                _revealCurve.value,
                widget.revealStyle,
                widget.revealOrigin,
                direction,
              ),
              child: child,
            );
          },
          child: _stageLayer(incoming),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _RevealGlowPainter(
              progress: _revealCurve,
              style: widget.revealStyle,
              origin: widget.revealOrigin,
              textDirection: direction,
            ),
          ),
        ),
      ],
      if (widget.showGrain && _animate)
        IgnorePointer(
          child: FadeTransition(
            opacity: _overlay,
            child: RepaintBoundary(
              child: CustomPaint(painter: _GrainPainter(time: _grain)),
            ),
          ),
        ),
      if (widget.showProgress)
        PositionedDirectional(
          top: 10.0,
          start: 10.0,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _overlay,
              child: ScaleTransition(
                scale: _overlay.drive(Tween<double>(begin: 0.92, end: 1.0)),
                alignment: AlignmentDirectional.topStart.resolve(direction),
                child: _buildPill(context, step, total),
              ),
            ),
          ),
        ),
    ];

    final String name = widget.semanticLabel ?? 'Image';
    return Semantics(
      container: true,
      image: true,
      label: _generating ? '$name, refining step $step of $total' : name,
      child: ExcludeSemantics(
        child: _FallbackWidth(
          width: RefineFrame.fallbackWidth,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: ColoredBox(
                color: widget.backgroundColor ?? scheme.surfaceContainerHighest,
                child: Stack(fit: StackFit.expand, children: layers),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caps the width of its child at [width] when the incoming constraints are
/// unbounded on both axes, so an [AspectRatio] below it always has a side
/// to size from. Bounded constraints pass through untouched.
class _FallbackWidth extends SingleChildRenderObjectWidget {
  const _FallbackWidth({required this.width, required super.child});

  final double width;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFallbackWidth(width);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFallbackWidth renderObject,
  ) {
    renderObject.width = width;
  }
}

class _RenderFallbackWidth extends RenderProxyBox {
  _RenderFallbackWidth(this._width);

  double _width;

  set width(double value) {
    if (value == _width) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  BoxConstraints _adjust(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth || constraints.hasBoundedHeight) {
      return constraints;
    }
    return constraints.copyWith(
      maxWidth: math.max(constraints.minWidth, _width),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    return child.getDryLayout(_adjust(constraints));
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_adjust(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// Geometry shared by the reveal mask and the glow on its front.
abstract final class _RevealGeometry {
  /// Width of the soft mask edge as a fraction of the reveal distance.
  static const double soft = 0.32;

  static const Color _opaque = Color(0xFFFFFFFF);
  static const Color _clear = Color(0x00FFFFFF);

  static Offset origin(Rect bounds, Alignment alignment) =>
      alignment.withinRect(bounds);

  /// Distance from [center] to the farthest corner of [bounds].
  static double reach(Rect bounds, Offset center) {
    double result = 0.0;
    for (final Offset corner in <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      result = math.max(result, (corner - center).distance);
    }
    return result;
  }

  /// The diagonal from the top start corner to the bottom end corner.
  static (Offset, Offset) diagonal(Rect bounds, TextDirection direction) {
    return direction == TextDirection.rtl
        ? (bounds.topRight, bounds.bottomLeft)
        : (bounds.topLeft, bounds.bottomRight);
  }

  static ui.Shader maskShader(
    Rect bounds,
    double t,
    RefineRevealStyle style,
    Alignment alignment,
    TextDirection direction,
  ) {
    final double p = t.clamp(0.0, 1.0);
    switch (style) {
      case RefineRevealStyle.radial:
        final Offset center = origin(bounds, alignment);
        final double full = reach(bounds, center);
        final double edge = full * soft;
        final double radius = math.max(0.001, p * (full + edge));
        return ui.Gradient.radial(
          center,
          radius,
          const <Color>[_opaque, _clear],
          <double>[math.max(0.0, (radius - edge) / radius), 1.0],
        );
      case RefineRevealStyle.diagonal:
        final (Offset a, Offset b) = diagonal(bounds, direction);
        final double front = p * (1.0 + soft);
        return ui.Gradient.linear(
          Offset.lerp(a, b, front - soft)!,
          Offset.lerp(a, b, front)!,
          const <Color>[_opaque, _clear],
        );
      case RefineRevealStyle.fade:
        final Color color = _opaque.withValues(alpha: p);
        return ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, <Color>[
          color,
          color,
        ]);
    }
  }
}

/// Paints a faint band of light on the front of a stage reveal.
class _RevealGlowPainter extends CustomPainter {
  _RevealGlowPainter({
    required this.progress,
    required this.style,
    required this.origin,
    required this.textDirection,
  }) : super(repaint: progress);

  /// The curved reveal progress, from 0 to 1.
  final Animation<double> progress;
  final RefineRevealStyle style;
  final Alignment origin;
  final TextDirection textDirection;

  /// Peak opacity of the light band.
  static const double _peak = 0.18;

  final Paint _paint = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size) {
    final double p = progress.value.clamp(0.0, 1.0);
    final double strength = math.sin(math.pi * p) * _peak;
    if (strength <= 0.001) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    final Color glow = const Color(0xFFFFFFFF).withValues(alpha: strength);
    const Color clear = Color(0x00FFFFFF);
    switch (style) {
      case RefineRevealStyle.radial:
        final Offset center = _RevealGeometry.origin(bounds, origin);
        final double full = _RevealGeometry.reach(bounds, center);
        final double edge = full * _RevealGeometry.soft;
        final double radius = math.max(0.001, p * (full + edge));
        final double inner = math.max(0.0, (radius - edge) / radius);
        final double mid = math.max(0.0, (radius - edge * 0.45) / radius);
        _paint.shader = ui.Gradient.radial(
          center,
          radius,
          <Color>[clear, glow, clear],
          <double>[inner, math.max(inner, mid), 1.0],
        );
      case RefineRevealStyle.diagonal:
        final (Offset a, Offset b) = _RevealGeometry.diagonal(
          bounds,
          textDirection,
        );
        final double front = p * (1.0 + _RevealGeometry.soft);
        _paint.shader = ui.Gradient.linear(
          Offset.lerp(a, b, front - _RevealGeometry.soft)!,
          Offset.lerp(a, b, front)!,
          <Color>[clear, glow, clear],
          const <double>[0.0, 0.55, 1.0],
        );
      case RefineRevealStyle.fade:
        // A diagonal sheen crosses the frame during the fade.
        final (Offset a, Offset b) = _RevealGeometry.diagonal(
          bounds,
          textDirection,
        );
        final double center = -0.25 + p * 1.5;
        _paint.shader = ui.Gradient.linear(
          Offset.lerp(a, b, center - 0.2)!,
          Offset.lerp(a, b, center + 0.2)!,
          <Color>[clear, glow, clear],
          const <double>[0.0, 0.5, 1.0],
        );
    }
    canvas.drawRect(bounds, _paint);
  }

  @override
  bool shouldRepaint(_RevealGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.style != style ||
        oldDelegate.origin != origin ||
        oldDelegate.textDirection != textDirection;
  }
}

/// A deterministic tile of grain specks, shared by the stage noise and the
/// animated overlay.
abstract final class _GrainTile {
  /// Side of the square tile, in logical pixels.
  static const double side = 72.0;

  static const int _count = 260;

  /// Light specks, as x/y pairs for `drawRawPoints`.
  static final Float32List light = _build(11);

  /// Dark specks, as x/y pairs for `drawRawPoints`.
  static final Float32List dark = _build(29);

  static Float32List _build(int seed) {
    final math.Random random = math.Random(seed);
    final Float32List points = Float32List(_count * 2);
    for (int i = 0; i < points.length; i++) {
      points[i] = random.nextDouble() * side;
    }
    return points;
  }

  /// Paints the tile over [size], shifted by [offset], with [paint] whose
  /// color is set per speck set.
  static void paint(
    Canvas canvas,
    Size size,
    Offset offset,
    Paint paint,
    Color lightColor,
    Color darkColor,
  ) {
    final double dx = offset.dx % side;
    final double dy = offset.dy % side;
    for (double y = -dy; y < size.height; y += side) {
      for (double x = -dx; x < size.width; x += side) {
        canvas.save();
        canvas.translate(x, y);
        paint.color = lightColor;
        canvas.drawRawPoints(ui.PointMode.points, light, paint);
        paint.color = darkColor;
        canvas.drawRawPoints(ui.PointMode.points, dark, paint);
        canvas.restore();
      }
    }
  }
}

/// The animated generation overlay: flickering grain and a slow scanline.
class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.time}) : super(repaint: time);

  /// One scanline pass, from 0 to 1, repeating.
  final Animation<double> time;

  /// Grain frames per scanline pass (about twelve per second).
  static const int _frames = 30;

  final Paint _points = Paint()
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;
  final Paint _line = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double t = time.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Grain jumps to a new pseudo-random offset a few times per second,
    // like film grain.
    final int frame = (t * _frames).floor();
    final Offset offset = Offset(
      ((frame * 37) % 71).toDouble(),
      ((frame * 53) % 67).toDouble(),
    );
    _GrainTile.paint(
      canvas,
      size,
      offset,
      _points,
      const Color(0x22FFFFFF),
      const Color(0x1C000000),
    );
    // A soft horizontal scanline drifts down the frame.
    final double band = size.height * 0.22;
    final double y = -band + t * (size.height + band * 2);
    _line.shader = ui.Gradient.linear(
      Offset(0.0, y - band / 2),
      Offset(0.0, y + band / 2),
      const <Color>[Color(0x00FFFFFF), Color(0x17FFFFFF), Color(0x00FFFFFF)],
      const <double>[0.0, 0.5, 1.0],
    );
    canvas.drawRect(Rect.fromLTWH(0.0, y - band / 2, size.width, band), _line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.time != time;
}

/// One generated stage of [RefineFrame.blurred]: the image blurred,
/// desaturated and grainy according to [quality].
class _BlurredStage extends StatelessWidget {
  const _BlurredStage({
    required this.image,
    required this.fit,
    required this.quality,
    required this.maxBlur,
    required this.noise,
  });

  final ImageProvider image;
  final BoxFit fit;

  /// 0 for the roughest stage, 1 for the sharp original.
  final double quality;
  final double maxBlur;
  final double noise;

  static List<double> _saturation(double s) {
    const double r = 0.2126;
    const double g = 0.7152;
    const double b = 0.0722;
    final double i = 1.0 - s;
    return <double>[
      r * i + s, g * i, b * i, 0.0, 0.0, //
      r * i, g * i + s, b * i, 0.0, 0.0, //
      r * i, g * i, b * i + s, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Image(
      image: image,
      fit: fit,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    if (quality >= 1.0) {
      return result;
    }
    final double rough = 1.0 - quality;
    final double sigma = maxBlur * math.pow(rough, 1.6);
    if (sigma > 0.0) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
        child: result,
      );
    }
    result = ColorFiltered(
      colorFilter: ColorFilter.matrix(_saturation(1.0 - 0.7 * rough)),
      child: result,
    );
    final double grain = noise * math.pow(rough, 1.2);
    if (grain <= 0.0) {
      return result;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        result,
        RepaintBoundary(
          child: CustomPaint(painter: _StaticNoisePainter(opacity: grain)),
        ),
      ],
    );
  }
}

/// Still grain for an early [RefineFrame.blurred] stage.
class _StaticNoisePainter extends CustomPainter {
  _StaticNoisePainter({required this.opacity});

  /// Overall strength of the grain, in `[0, 1]`.
  final double opacity;

  final Paint _points = Paint()
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Two passes at different offsets make the grain dense enough.
    for (final Offset offset in const <Offset>[
      Offset.zero,
      Offset(31.0, 17.0),
    ]) {
      _GrainTile.paint(
        canvas,
        size,
        offset,
        _points,
        Color.fromRGBO(255, 255, 255, 0.4 * opacity),
        Color.fromRGBO(0, 0, 0, 0.4 * opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaticNoisePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
