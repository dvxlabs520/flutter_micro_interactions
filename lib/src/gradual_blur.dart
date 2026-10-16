import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The edge of a region toward which a [GradualBlur] grows stronger.
enum GradualBlurEdge {
  /// The blur is strongest at the top edge and fades out downward.
  top,

  /// The blur is strongest at the bottom edge and fades out upward.
  bottom,

  /// The blur is strongest at the left edge and fades out to the right.
  left,

  /// The blur is strongest at the right edge and fades out to the left.
  right,
}

/// A progressive blur that grows stronger toward one edge of a region.
///
/// Use it to soften content that scrolls under a header, a footer, a
/// floating toolbar or the end of a carousel:
///
/// ```dart
/// GradualBlur(
///   edge: GradualBlurEdge.bottom,
///   extent: 120,
///   fadeColor: Theme.of(context).colorScheme.surface,
///   child: ListView(children: items),
/// )
/// ```
///
/// With a [child], the blur band is stacked over the chosen edge of the
/// child and the child keeps its own layout constraints. Use
/// [GradualBlur.overlay] to get just the band, for example as a
/// [Positioned] child of your own [Stack]:
///
/// ```dart
/// Stack(
///   children: [
///     content,
///     const Positioned(
///       left: 0,
///       right: 0,
///       bottom: 0,
///       child: GradualBlur.overlay(extent: 96),
///     ),
///   ],
/// )
/// ```
///
/// The band is made of [layers] overlapping blur layers. Each one blurs
/// what is painted behind it with a larger sigma than the previous one,
/// following [curve], up to `strength * GradualBlur.maxSigma` at the edge.
/// Every layer fades in through a soft alpha ramp, so neighbouring blur
/// levels cross-fade and the band shows no visible steps. An optional
/// [fadeColor] paints a gradient on top that reaches the solid color at
/// the edge.
///
/// Performance: each layer is a [BackdropFilter], one of the more
/// expensive effects in Flutter. Its cost grows with the blurred area,
/// the sigma and the number of layers; layers overlap in pairs, so the
/// total blurred area is about twice the band. All layers of one band share a single
/// backdrop read through [BackdropFilter.backdropGroupKey], which keeps
/// the overhead low on Impeller. Keep [layers] small (4 to 8), keep the
/// band as short as the design allows, and avoid many bands on one
/// screen. Content that repaints every frame under the band (for example
/// a running animation) makes the blur run every frame too.
///
/// The blur is decorative: it never receives pointer events and adds no
/// semantics. It is static, so reduced motion does not affect it.
class GradualBlur extends StatefulWidget {
  /// Creates a progressive blur stacked over one edge of [child].
  const GradualBlur({
    super.key,
    required Widget this.child,
    this.edge = GradualBlurEdge.bottom,
    this.extent = 96.0,
    this.strength = 1.0,
    this.layers = 6,
    this.curve = GradualBlur.exponential,
    this.fadeColor,
    this.enabled = true,
  }) : assert(extent >= 0, 'extent must not be negative'),
       assert(strength >= 0, 'strength must not be negative'),
       assert(layers >= 1, 'layers must be at least 1');

  /// Creates only the blur band, without a child.
  ///
  /// The band is [extent] thick along the blur direction and fills the
  /// incoming constraints across it, so it needs a bounded cross-axis
  /// size. Place it yourself, usually with a [Positioned] inside a
  /// [Stack] above the content to blur.
  const GradualBlur.overlay({
    super.key,
    this.edge = GradualBlurEdge.bottom,
    this.extent = 96.0,
    this.strength = 1.0,
    this.layers = 6,
    this.curve = GradualBlur.exponential,
    this.fadeColor,
    this.enabled = true,
  }) : assert(extent >= 0, 'extent must not be negative'),
       assert(strength >= 0, 'strength must not be negative'),
       assert(layers >= 1, 'layers must be at least 1'),
       child = null;

  /// The blur sigma reached at the edge when [strength] is 1.
  static const double maxSigma = 12.0;

  /// The default [curve]: an exponential ramp, so the blur stays light
  /// for most of the band and builds up quickly near the edge.
  static const Curve exponential = _ExponentialCurve();

  /// The content under the blur. Null for [GradualBlur.overlay].
  final Widget? child;

  /// The edge where the blur is strongest. Defaults to
  /// [GradualBlurEdge.bottom].
  final GradualBlurEdge edge;

  /// Thickness of the blurred band in logical pixels: its height for
  /// [GradualBlurEdge.top] and [GradualBlurEdge.bottom], its width for
  /// [GradualBlurEdge.left] and [GradualBlurEdge.right]. Defaults to 96.
  final double extent;

  /// Multiplier for the blur at the edge. 1.0 (the default) reaches a
  /// sigma of [maxSigma]; 0 disables the blur.
  final double strength;

  /// Number of blur layers in the band. More layers give a smoother ramp
  /// but cost more. Defaults to 6.
  final int layers;

  /// How the blur sigma grows from the inner side of the band (t = 0) to
  /// the edge (t = 1). Defaults to [GradualBlur.exponential]; use
  /// [Curves.linear] for an even ramp or [Curves.easeIn] for a softer
  /// one.
  final Curve curve;

  /// Optional color painted as a gradient over the band, transparent on
  /// the inner side and solid at the edge. Usually the background color
  /// of the surface behind the band. Null (the default) paints no color.
  final Color? fadeColor;

  /// When false, no blur and no fade color are painted; the child renders
  /// on its own. Defaults to true.
  final bool enabled;

  @override
  State<GradualBlur> createState() => _GradualBlurState();
}

class _GradualBlurState extends State<GradualBlur> {
  /// Shared by every layer of this band so the engine snapshots the
  /// backdrop once. Each layer then blurs that same snapshot, and the
  /// alpha ramps cross-fade the results.
  final BackdropKey _backdropKey = BackdropKey();

  /// Number of stops of the [GradualBlur.fadeColor] gradient.
  static const int _fadeStops = 6;

  bool get _horizontal =>
      widget.edge == GradualBlurEdge.left ||
      widget.edge == GradualBlurEdge.right;

  /// Alignment of the edge where the blur is strongest.
  Alignment get _edgeAlignment => switch (widget.edge) {
    GradualBlurEdge.top => Alignment.topCenter,
    GradualBlurEdge.bottom => Alignment.bottomCenter,
    GradualBlurEdge.left => Alignment.centerLeft,
    GradualBlurEdge.right => Alignment.centerRight,
  };

  /// Sigma reached by layer [index], counted from the inner side.
  double _sigmaFor(int index) {
    final double t = (index + 1) / widget.layers;
    final double fraction = widget.curve.transform(t).clamp(0.0, 1.0);
    return GradualBlur.maxSigma * widget.strength * fraction;
  }

  /// Positions a layer that starts [start] pixels from the inner side of
  /// the band and is [length] pixels long, measured toward the edge.
  Widget _place(double start, double length, Widget child) {
    final double fromEdge = widget.extent - start - length;
    return switch (widget.edge) {
      GradualBlurEdge.bottom => Positioned(
        left: 0,
        right: 0,
        top: start,
        height: length,
        child: child,
      ),
      GradualBlurEdge.top => Positioned(
        left: 0,
        right: 0,
        top: fromEdge,
        height: length,
        child: child,
      ),
      GradualBlurEdge.right => Positioned(
        top: 0,
        bottom: 0,
        left: start,
        width: length,
        child: child,
      ),
      GradualBlurEdge.left => Positioned(
        top: 0,
        bottom: 0,
        left: fromEdge,
        width: length,
        child: child,
      ),
    };
  }

  /// Builds the blur layers. Layer `i` covers two segments: it fades in
  /// over the first, where it cross-fades with layer `i - 1`, and stays
  /// opaque over the second, where layer `i + 1` fades in above it.
  List<Widget> _buildLayers() {
    final int count = widget.layers;
    final double segment = widget.extent / count;
    final List<Widget> layers = <Widget>[];
    for (int i = 0; i < count; i++) {
      final double sigma = _sigmaFor(i);
      if (sigma <= 0.0) {
        continue;
      }
      final double start = segment * i;
      final double length = math.min(segment * 2, widget.extent - start);
      layers.add(
        _place(
          start,
          length,
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.mirror,
              ),
              backdropGroupKey: _backdropKey,
              // Painted inside the filter layer: masks the blurred
              // backdrop with an alpha ramp before it is composited.
              child: CustomPaint(
                size: Size.infinite,
                painter: _RampMaskPainter(
                  edge: _edgeAlignment,
                  rampEnd: segment / length,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return layers;
  }

  Widget? _buildFade() {
    final Color? color = widget.fadeColor;
    if (color == null) {
      return null;
    }
    final double alpha = color.a;
    final List<Color> colors = <Color>[];
    final List<double> stops = <double>[];
    for (int i = 0; i < _fadeStops; i++) {
      final double t = i / (_fadeStops - 1);
      // Ease in so the color starts imperceptibly and settles at the edge.
      stops.add(t);
      colors.add(color.withValues(alpha: alpha * t * t));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: -_edgeAlignment,
          end: _edgeAlignment,
          colors: colors,
          stops: stops,
        ),
      ),
    );
  }

  Widget _sized(Widget? child) {
    return _horizontal
        ? SizedBox(width: widget.extent, height: double.infinity, child: child)
        : SizedBox(width: double.infinity, height: widget.extent, child: child);
  }

  Widget _buildBand() {
    final Widget? fade = _buildFade();
    return _sized(
      IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              ..._buildLayers(),
              if (fade != null) Positioned.fill(child: fade),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? child = widget.child;
    final bool paintsSomething =
        widget.enabled &&
        widget.extent > 0 &&
        (widget.strength > 0 || widget.fadeColor != null);

    if (child == null) {
      return paintsSomething ? _buildBand() : _sized(null);
    }

    return Stack(
      // Keep the child's own constraints; the band only overlays it.
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        if (paintsSomething)
          switch (widget.edge) {
            GradualBlurEdge.top => Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _buildBand(),
            ),
            GradualBlurEdge.bottom => Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBand(),
            ),
            GradualBlurEdge.left => Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: _buildBand(),
            ),
            GradualBlurEdge.right => Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: _buildBand(),
            ),
          },
      ],
    );
  }
}

/// Multiplies the blurred backdrop of a layer by an alpha ramp: 0 on the
/// inner side, 1 from [rampEnd] (a fraction of the layer) to the edge.
class _RampMaskPainter extends CustomPainter {
  const _RampMaskPainter({required this.edge, required this.rampEnd});

  /// Alignment of the edge where the layer is fully opaque.
  final Alignment edge;

  /// Fraction of the layer, from its inner side, covered by the ramp.
  final double rampEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = LinearGradient(
        begin: -edge,
        end: edge,
        colors: const <Color>[
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
        ],
        stops: <double>[0.0, rampEnd.clamp(0.0, 1.0), 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RampMaskPainter oldDelegate) {
    return oldDelegate.edge != edge || oldDelegate.rampEnd != rampEnd;
  }
}

/// `(2^(4t) - 1) / 15`: an exponential ramp normalized to 0..1.
class _ExponentialCurve extends Curve {
  const _ExponentialCurve();

  @override
  double transformInternal(double t) {
    return (math.pow(2.0, 4.0 * t) - 1.0) / 15.0;
  }
}
