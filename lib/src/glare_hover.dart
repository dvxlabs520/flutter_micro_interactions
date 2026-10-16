import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Programmatic control for a [GlareHover] widget.
///
/// ```dart
/// final controller = GlareHoverController();
/// // ...
/// GlareHover(
///   controller: controller,
///   child: const ProductCard(),
/// );
/// // later, for example when the card is added to a cart:
/// controller.play();
/// ```
///
/// [isSweeping] reflects whether the attached glare is currently moving.
/// Dispose the controller yourself when it is no longer needed.
class GlareHoverController extends ChangeNotifier {
  /// Incremented by [play] so every attached widget can detect requests.
  int _playRequests = 0;

  /// Reported back by the attached widget.
  bool _isSweeping = false;

  /// Whether the attached [GlareHover] is currently sweeping. Snapshot
  /// value, not a listenable property of its own.
  bool get isSweeping => _isSweeping;

  /// Plays one full sweep across the child, from the start corner to the
  /// opposite corner. The glare then rests off the child.
  ///
  /// Does nothing when the widget is disabled or reduced motion is on.
  /// [GlareHover.playOnce] does not apply to programmatic sweeps.
  void play() {
    _playRequests++;
    notifyListeners();
  }
}

/// A glossy light streak that sweeps once across its child on hover.
///
/// ```dart
/// GlareHover(
///   borderRadius: BorderRadius.circular(16),
///   child: Container(
///     width: 280,
///     height: 180,
///     decoration: BoxDecoration(
///       color: Colors.indigo,
///       borderRadius: BorderRadius.circular(16),
///     ),
///   ),
/// )
/// ```
///
/// When a mouse pointer enters the child, a soft diagonal band of
/// [glareColor] travels once from one corner to the opposite corner over
/// [duration]. When the pointer leaves, the band sweeps back the way it came
/// ([reverseOnExit], the default) or simply disappears. Unlike a periodic
/// shimmer, nothing moves while the pointer rests on the child. Unlike
/// `TiltCard`, the glare does not follow the pointer.
///
/// On touch devices a press plays one full forward sweep. Keyboard focus
/// moving into a focusable widget inside [child] (for example a button)
/// behaves like a hover. Use [controller] to trigger a sweep from code.
///
/// The band is painted above the child as a decorative overlay clipped to
/// [borderRadius]. It ignores pointers and adds no semantics; taps,
/// gestures and semantics of the child are untouched.
///
/// Under reduced motion, or when [enabled] is `false`, no glare is painted
/// and the child renders as is.
class GlareHover extends StatefulWidget {
  /// Creates a glare sweep around [child].
  const GlareHover({
    super.key,
    required this.child,
    this.glareColor = const Color(0xFFFFFFFF),
    this.glareOpacity = 0.35,
    this.glareAngle = -45.0,
    this.glareSize = 2.5,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.reverseOnExit = true,
    this.playOnce = false,
    this.enabled = true,
    this.controller,
  }) : assert(
         glareOpacity >= 0 && glareOpacity <= 1,
         'glareOpacity must be in [0, 1]',
       ),
       assert(glareSize > 0, 'glareSize must be positive');

  /// The widget the glare sweeps across.
  final Widget child;

  /// Color of the glare band. Its own alpha is multiplied by
  /// [glareOpacity]. Defaults to white.
  final Color glareColor;

  /// Peak opacity of the glare band, in `[0, 1]`. Defaults to 0.35.
  final double glareOpacity;

  /// Direction of travel of the forward sweep, in degrees, using the CSS
  /// `linear-gradient` convention: 0 points up and angles grow clockwise
  /// (90 points right). The band itself lies perpendicular to this
  /// direction.
  ///
  /// Defaults to -45, which draws a band running from bottom-left to
  /// top-right that enters at the bottom-right corner and leaves at the
  /// top-left corner, like the React Bits original. Use 135 for a sweep
  /// from the top-left corner to the bottom-right corner.
  final double glareAngle;

  /// Size of the glare gradient relative to the child, as in the React
  /// Bits `glareSize` percentage divided by 100. The visible band is 40
  /// percent of this gradient, so larger values give a wider, softer
  /// band. Must be positive. Defaults to 2.5.
  final double glareSize;

  /// Length of one sweep across the child. Defaults to 650 milliseconds.
  final Duration duration;

  /// Curve of the forward sweep. The sweep back on exit uses the flipped
  /// curve so both directions feel the same. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// Corner rounding of the glare overlay, so it matches the child's
  /// shape. Defaults to a 12 pixel circular radius.
  final BorderRadius borderRadius;

  /// Whether the band sweeps back when the pointer leaves (or focus moves
  /// out). When `false` an unfinished sweep completes and the glare then
  /// rests off the child, matching React Bits' `playOnce` behavior.
  /// Defaults to `true`.
  final bool reverseOnExit;

  /// When `true` only the first hover, press or focus plays the sweep;
  /// later ones do nothing. Programmatic sweeps through [controller] are
  /// not affected. Defaults to `false`, so every hover plays.
  final bool playOnce;

  /// When `false` no glare is painted and all triggers are ignored. The
  /// child still renders and stays interactive. Defaults to `true`.
  final bool enabled;

  /// Optional controller to trigger sweeps from code.
  final GlareHoverController? controller;

  @override
  State<GlareHover> createState() => _GlareHoverState();
}

class _GlareHoverState extends State<GlareHover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;
  late CurvedAnimation _progress;

  /// Whether reduced motion is requested, refreshed in
  /// [didChangeDependencies].
  bool _reduced = false;

  /// Whether a mouse or hovering stylus is over the child.
  bool _hovered = false;

  /// Whether keyboard focus is inside the child.
  bool _focused = false;

  /// Whether the current hover or focus started a sweep, so leaving it
  /// should run the exit behavior.
  bool _engaged = false;

  /// Whether a pointer-driven sweep has played at least once, for
  /// [GlareHover.playOnce].
  bool _hasPlayed = false;

  /// Whether the glare should jump back to its start, invisibly, once the
  /// running forward sweep completes.
  bool _resetWhenDone = false;

  /// Last [GlareHoverController._playRequests] value acted upon.
  int _seenPlayRequests = 0;

  bool get _active => widget.enabled && !_reduced;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_handleStatus);
    _progress = _curved();
    _seenPlayRequests = widget.controller?._playRequests ?? 0;
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced) _reset();
  }

  @override
  void didUpdateWidget(GlareHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _sweep.duration = widget.duration;
      _restartInSameDirection();
    }
    if (widget.curve != oldWidget.curve) {
      _progress.dispose();
      _progress = _curved();
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      oldWidget.controller?._isSweeping = false;
      _seenPlayRequests = widget.controller?._playRequests ?? 0;
      widget.controller?.addListener(_handleControllerChanged);
      widget.controller?._isSweeping = _sweep.isAnimating;
    }
    if (!widget.enabled && oldWidget.enabled) _reset();
    if (widget.playOnce != oldWidget.playOnce) _hasPlayed = false;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    widget.controller?._isSweeping = false;
    _sweep.removeStatusListener(_handleStatus);
    _progress.dispose();
    _sweep.dispose();
    super.dispose();
  }

  CurvedAnimation _curved() => CurvedAnimation(
    parent: _sweep,
    curve: widget.curve,
    reverseCurve: widget.curve.flipped,
  );

  /// Continues a running sweep with a new duration.
  void _restartInSameDirection() {
    if (!_sweep.isAnimating) return;
    if (_sweep.status == AnimationStatus.reverse) {
      _sweep.reverse();
    } else {
      _sweep.forward();
    }
  }

  void _reset() {
    _hovered = false;
    _focused = false;
    _engaged = false;
    _resetWhenDone = false;
    _sweep.stop();
    _sweep.value = 0.0;
    widget.controller?._isSweeping = false;
  }

  void _handleStatus(AnimationStatus status) {
    widget.controller?._isSweeping = status.isAnimating;
    if (status == AnimationStatus.completed && _resetWhenDone) {
      // The band has left the child, so this jump is invisible.
      _resetWhenDone = false;
      _sweep.value = 0.0;
    }
  }

  void _handleControllerChanged() {
    final GlareHoverController controller = widget.controller!;
    if (controller._playRequests == _seenPlayRequests) return;
    _seenPlayRequests = controller._playRequests;
    if (!mounted || !_active) return;
    // A programmatic sweep runs to the far side and then rests off the
    // child, unless a hover keeps it there.
    _resetWhenDone = !_engaged;
    _sweep.forward(from: 0.0);
  }

  /// Starts a pointer- or focus-driven forward sweep. Returns whether a
  /// sweep was started.
  bool _playForward({required bool oneShot}) {
    if (!_active) return false;
    if (widget.playOnce && _hasPlayed) return false;
    _hasPlayed = true;
    _resetWhenDone = oneShot;
    if (_sweep.status == AnimationStatus.reverse) {
      // Turn around from wherever the band is.
      _sweep.forward();
    } else if (!_sweep.isAnimating) {
      _sweep.forward(from: 0.0);
    }
    return true;
  }

  /// Runs the exit behavior after hover and focus have both gone.
  void _playExit() {
    if (!_engaged) return;
    _engaged = false;
    if (!_active) return;
    if (widget.reverseOnExit) {
      _resetWhenDone = false;
      if (_sweep.value > 0.0) _sweep.reverse();
    } else if (_sweep.isAnimating) {
      _resetWhenDone = true;
    } else {
      _sweep.value = 0.0;
    }
  }

  void _handleEngage() {
    if (_engaged) return;
    _engaged = _playForward(oneShot: false);
  }

  void _handleDisengage() {
    if (_hovered || _focused) return;
    _playExit();
  }

  void _handleEnter(PointerEnterEvent event) {
    _hovered = true;
    _handleEngage();
  }

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _handleDisengage();
  }

  void _handleDown(PointerDownEvent event) {
    // Mice (and hovering styluses) already played on enter.
    if (event.kind == PointerDeviceKind.mouse || _hovered || _engaged) {
      return;
    }
    _playForward(oneShot: true);
  }

  void _handleFocusChange(bool focused) {
    if (focused) {
      // Only keyboard navigation counts; a tap on a text field already
      // plays the press sweep.
      if (FocusManager.instance.highlightMode !=
          FocusHighlightMode.traditional) {
        return;
      }
      _focused = true;
      _handleEngage();
    } else if (_focused) {
      _focused = false;
      _handleDisengage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _active;
    // The tree shape above the child stays the same whether or not the
    // effect is active, so toggling [GlareHover.enabled] keeps the child's
    // state.
    return MouseRegion(
      opaque: false,
      onEnter: active ? _handleEnter : null,
      onExit: active ? _handleExit : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: active ? _handleDown : null,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: active ? _handleFocusChange : null,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              widget.child,
              if (active && widget.glareOpacity > 0 && widget.glareColor.a > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GlareSweepPainter(
                            progress: _progress,
                            color: widget.glareColor,
                            opacity: widget.glareOpacity,
                            angle: widget.glareAngle,
                            size: widget.glareSize,
                            borderRadius: widget.borderRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the glare band at the position given by [progress].
///
/// At progress 0 the band sits just outside the trailing corner, at 1 just
/// outside the leading corner, so nothing is visible at either end.
class _GlareSweepPainter extends CustomPainter {
  _GlareSweepPainter({
    required this.progress,
    required this.color,
    required this.opacity,
    required this.angle,
    required this.size,
    required this.borderRadius,
  }) : super(repaint: progress);

  /// Sweep progress, in `[0, 1]`.
  final Animation<double> progress;

  /// Glare color.
  final Color color;

  /// Peak glare opacity.
  final double opacity;

  /// Direction of travel in CSS degrees.
  final double angle;

  /// Gradient size relative to the child.
  final double size;

  /// Clip shape of the overlay.
  final BorderRadius borderRadius;

  /// Fraction of the gradient that holds the visible band, as in React
  /// Bits: transparent at 60 percent, peak at 70, transparent at 100.
  static const double _bandFraction = 0.4;

  /// Peak position inside the band, measured from its trailing edge.
  static const double _peakStop = 0.25;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double t = progress.value;
    if (t <= 0.0 || t >= 1.0 || canvasSize.isEmpty) return;

    final double radians = angle * math.pi / 180;
    // CSS angles: 0 points up, 90 points right.
    final Offset direction = Offset(math.sin(radians), -math.cos(radians));
    // Half the length of the child projected on the direction, which is
    // also half the CSS gradient line of the child box.
    final double halfExtent =
        (canvasSize.width * direction.dx.abs() +
            canvasSize.height * direction.dy.abs()) /
        2;
    final double bandLength = halfExtent * 2 * size * _bandFraction;
    // The band starts fully behind the trailing edge and ends fully past
    // the leading edge.
    final double start = ui.lerpDouble(
      -halfExtent - bandLength,
      halfExtent,
      t,
    )!;
    final Offset center = canvasSize.center(Offset.zero);
    final Offset from = center + direction * start;
    final Offset to = center + direction * (start + bandLength);

    final Color peak = color.withValues(alpha: color.a * opacity);
    final Color clear = peak.withValues(alpha: 0);
    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        from,
        to,
        <Color>[clear, peak, clear],
        const <double>[0.0, _peakStop, 1.0],
      );
    canvas.drawRRect(borderRadius.toRRect(Offset.zero & canvasSize), paint);
  }

  @override
  bool shouldRepaint(covariant _GlareSweepPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.angle != angle ||
        oldDelegate.size != size ||
        oldDelegate.borderRadius != borderRadius;
  }
}
