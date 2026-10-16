import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The kind of moving gradient painted by a [GradientText].
enum GradientTextType {
  /// A linear gradient that slides along [GradientText.angle] and loops
  /// seamlessly.
  linear,

  /// A conic gradient that rotates around the center of the text.
  sweep,
}

/// Programmatic control for a [GradientText].
///
/// ```dart
/// final GradientTextController gradient = GradientTextController();
/// // ...
/// GradientText(
///   'Premium',
///   controller: gradient,
///   autoPlay: false,
/// );
/// // later:
/// gradient.start();
/// gradient.stop();
/// ```
///
/// The controller keeps the requested playback state ([isPlayRequested])
/// separately from the effective one ([isPlaying]). Under reduced motion
/// or `enabled: false` a request to play is remembered but the gradient
/// stays static until motion is allowed again. When the widget has
/// `autoPlay: true`, attaching it counts as a request to play, so [stop]
/// works right away. The caller owns and disposes the controller.
class GradientTextController extends ChangeNotifier {
  /// The caller's intent, changed by [start] and [stop].
  bool _playRequested = false;

  /// Reported back by the attached widget.
  bool _isPlaying = false;

  /// Whether the attached [GradientText] is currently animating. False
  /// while the widget is static (reduced motion, `enabled: false`) even if
  /// [isPlayRequested] is true. Snapshot value, not a listenable property
  /// of its own.
  bool get isPlaying => _isPlaying;

  /// Whether the animation has been requested to play, by [start] or by
  /// the widget's `autoPlay`, and not stopped since.
  bool get isPlayRequested => _playRequested;

  /// Requests the gradient animation to start (or resume).
  void start() {
    if (_playRequested) return;
    _playRequested = true;
    notifyListeners();
  }

  /// Requests the gradient animation to stop, freezing it at its resting
  /// position.
  void stop() {
    if (!_playRequested) return;
    _playRequested = false;
    notifyListeners();
  }
}

/// Text filled with a moving gradient.
///
/// ```dart
/// GradientText(
///   'Introducing Flow',
///   style: Theme.of(context).textTheme.displaySmall,
/// )
/// ```
///
/// The glyphs are painted with a gradient of [colors] through a
/// [ShaderMask]. With [GradientTextType.linear] the gradient slides along
/// [angle], which follows the ambient [Directionality]; with
/// [GradientTextType.sweep] a conic gradient rotates around the center.
/// One cycle takes [duration]. When the first and last colors differ, the
/// first color is appended internally so the loop has no visible seam.
/// With [pingPong] the gradient moves back and forth instead of looping.
///
/// Use [GradientText.child] to fill any widget, such as an icon, with the
/// same gradient.
///
/// The glyphs are untouched for assistive technology: screen readers read
/// the text normally. Under reduced motion, or when [enabled] is false,
/// the gradient renders statically.
class GradientText extends StatefulWidget {
  /// Creates text filled with an animated gradient.
  const GradientText(
    String this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.colors,
    this.type = GradientTextType.linear,
    this.duration = const Duration(seconds: 3),
    this.curve = Curves.linear,
    this.angle = 0.0,
    this.pingPong = false,
    this.autoPlay = true,
    this.controller,
    this.enabled = true,
  }) : child = null;

  /// Fills an arbitrary [child] with the animated gradient.
  ///
  /// The child should paint opaque pixels where the gradient must show,
  /// for example text or icons. Its own colors are replaced.
  const GradientText.child({
    super.key,
    required Widget this.child,
    this.colors,
    this.type = GradientTextType.linear,
    this.duration = const Duration(seconds: 3),
    this.curve = Curves.linear,
    this.angle = 0.0,
    this.pingPong = false,
    this.autoPlay = true,
    this.controller,
    this.enabled = true,
  }) : text = null,
       style = null,
       textAlign = null,
       maxLines = null,
       overflow = null;

  /// The text to display. Null when using [GradientText.child].
  final String? text;

  /// The widget to fill. Null when using the default constructor.
  final Widget? child;

  /// Style of the text. Its color is replaced by the gradient.
  final TextStyle? style;

  /// How the text is aligned horizontally.
  final TextAlign? textAlign;

  /// Maximum number of lines for the text.
  final int? maxLines;

  /// How visual overflow is handled.
  final TextOverflow? overflow;

  /// Gradient colors. Defaults to the theme's `colorScheme.primary`,
  /// `colorScheme.tertiary` and `colorScheme.secondary`. When the first
  /// and last colors differ, the first color is appended internally so the
  /// gradient loops without a seam.
  final List<Color>? colors;

  /// The kind of gradient. Defaults to [GradientTextType.linear].
  final GradientTextType type;

  /// Length of one cycle: one full slide of the linear gradient or one
  /// full turn of the sweep gradient. Defaults to 3 seconds.
  final Duration duration;

  /// Curve applied to each cycle. Defaults to [Curves.linear].
  final Curve curve;

  /// Direction of the linear gradient, in radians, measured clockwise from
  /// the reading direction. 0 (the default) slides horizontally, left to
  /// right in left-to-right text and right to left in right-to-left text.
  /// Ignored by [GradientTextType.sweep].
  final double angle;

  /// When true the gradient moves forward then back instead of looping in
  /// one direction. Defaults to false.
  final bool pingPong;

  /// Whether the animation starts on its own. Defaults to true.
  final bool autoPlay;

  /// Optional controller to start and stop the animation. The caller owns
  /// and disposes it.
  final GradientTextController? controller;

  /// When false the gradient renders statically.
  final bool enabled;

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _progress;
  bool _shouldPlay = false;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _syncPlayback();
  }

  @override
  void didUpdateWidget(GradientText oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool restart = false;
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      restart = true;
    }
    if (widget.pingPong != oldWidget.pingPong) {
      restart = true;
    }
    if (widget.curve != oldWidget.curve) {
      _progress.dispose();
      _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.controller != oldWidget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _shouldPlay = widget.autoPlay;
    }
    if (restart && _controller.isAnimating) {
      _controller.stop();
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Attaches [controller]. `autoPlay` counts as a play request; an
  /// earlier [GradientTextController.start] is honored as well.
  void _attach(GradientTextController? controller) {
    _shouldPlay = widget.autoPlay || (controller?._playRequested ?? false);
    if (controller == null) return;
    controller._playRequested = _shouldPlay;
    controller.addListener(_handleControllerChanged);
  }

  void _detach(GradientTextController? controller) {
    if (controller == null) return;
    controller.removeListener(_handleControllerChanged);
    controller._isPlaying = false;
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _shouldPlay = widget.controller!._playRequested;
    _syncPlayback();
  }

  void _syncPlayback() {
    final bool play = _shouldPlay && widget.enabled && !_reduced;
    if (play) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: widget.pingPong);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.0;
    }
    widget.controller?._isPlaying = play;
  }

  List<Color> _effectiveColors(ColorScheme scheme) {
    final List<Color>? given = widget.colors;
    if (given == null || given.isEmpty) {
      return <Color>[
        scheme.primary,
        scheme.tertiary,
        scheme.secondary,
        scheme.primary,
      ];
    }
    if (given.length == 1) return <Color>[given.first, given.first];
    if (given.first != given.last) return <Color>[...given, given.first];
    return given;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = _effectiveColors(scheme);
    final List<double> stops = <double>[
      for (int i = 0; i < colors.length; i++) i / (colors.length - 1),
    ];
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    final Widget content =
        widget.child ??
        Text(
          widget.text!,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );

    final _GradientShaderBuilder shaderBuilder = _GradientShaderBuilder(
      type: widget.type,
      colors: colors,
      stops: stops,
      angle: widget.angle,
      rtl: rtl,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progress,
        child: content,
        builder: (BuildContext context, Widget? child) {
          final double t = _progress.value;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect bounds) => shaderBuilder.build(bounds, t),
            child: child,
          );
        },
      ),
    );
  }
}

/// Builds the gradient shader for a given cycle progress.
class _GradientShaderBuilder {
  const _GradientShaderBuilder({
    required this.type,
    required this.colors,
    required this.stops,
    required this.angle,
    required this.rtl,
  });

  final GradientTextType type;

  /// Seamless color list (first equals last).
  final List<Color> colors;

  /// Evenly spaced stops matching [colors].
  final List<double> stops;
  final double angle;
  final bool rtl;

  Shader build(Rect bounds, double t) {
    switch (type) {
      case GradientTextType.linear:
        double dx = math.cos(angle);
        final double dy = math.sin(angle);
        if (rtl) dx = -dx;
        // One full color cycle spans the text along the direction, so a
        // shift of exactly one span is invisible and the loop is seamless.
        final double span = math.max(
          1.0,
          (bounds.width * dx).abs() + (bounds.height * dy).abs(),
        );
        final Offset direction = Offset(dx, dy);
        final Offset shift = direction * (span * t);
        final Offset from = bounds.center - direction * (span / 2) + shift;
        final Offset to = bounds.center + direction * (span / 2) + shift;
        return ui.Gradient.linear(from, to, colors, stops, TileMode.repeated);
      case GradientTextType.sweep:
        final double turn = (rtl ? -t : t) * 2 * math.pi;
        return SweepGradient(
          colors: colors,
          stops: stops,
          transform: GradientRotation(turn),
        ).createShader(bounds);
    }
  }
}
