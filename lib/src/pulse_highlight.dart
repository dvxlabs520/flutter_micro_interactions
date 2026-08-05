import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Programmatic control for a [PulseHighlight] widget.
///
/// ```dart
/// final controller = PulseHighlightController();
/// // ...
/// PulseHighlight(
///   controller: controller,
///   autoPlay: false,
///   child: const Icon(Icons.star),
/// );
/// // later:
/// controller.start();
/// controller.stop();
/// ```
///
/// [isPulsing] reflects whether the attached widget is currently pulsing;
/// it also turns `false` when the widget stops itself, for example after
/// reaching `maxPulseCount` or on a dismissing tap. Dispose the controller
/// yourself when it is no longer needed.
class PulseHighlightController extends ChangeNotifier {
  bool _isPulsing = false;

  /// Whether the attached [PulseHighlight] is currently pulsing.
  bool get isPulsing => _isPulsing;

  /// Starts (or restarts) the pulse animation.
  void start() {
    if (_isPulsing) return;
    _isPulsing = true;
    notifyListeners();
  }

  /// Stops the pulse animation.
  void stop() {
    if (!_isPulsing) return;
    _isPulsing = false;
    notifyListeners();
  }
}

/// Expanding pulse rings around a child to draw the user's attention.
///
/// Rings expand from the child's bounds outward to the child size times
/// [maxRadiusFactor] while fading, staggered by [ringCount]. Typical use
/// is onboarding hints or highlighting new features.
///
/// ```dart
/// PulseHighlight(
///   maxPulseCount: 5,
///   child: IconButton(
///     icon: const Icon(Icons.notifications),
///     onPressed: _openInbox,
///   ),
/// )
/// ```
///
/// The rings intentionally overflow the child's bounds: the ring layer is
/// not clipped, so leave some room around the widget.
///
/// The child renders above the rings and keeps its own semantics; the ring
/// layer is decorative and excluded from the semantics tree.
///
/// When the platform requests reduced motion the widget never pulses and
/// renders the child only.
class PulseHighlight extends StatefulWidget {
  /// Creates a pulse highlight widget.
  const PulseHighlight({
    super.key,
    required this.child,
    this.controller,
    this.pulseColor,
    this.maxRadiusFactor = 1.6,
    this.ringCount = 2,
    this.duration = const Duration(milliseconds: 1500),
    this.curve = Curves.easeOut,
    this.autoPlay = true,
    this.maxPulseCount,
    this.stopOnTap = true,
    this.onPulseComplete,
    this.enabled = true,
    this.shape = BoxShape.circle,
    this.borderRadius,
  })  : assert(maxRadiusFactor >= 1.0, 'maxRadiusFactor must be at least 1.0'),
        assert(ringCount > 0, 'ringCount must be at least 1'),
        assert(maxPulseCount == null || maxPulseCount > 0,
            'maxPulseCount must be at least 1 when provided');

  /// The widget the rings pulse around. Rendered above the rings.
  final Widget child;

  /// Optional controller to start and stop the pulses. The caller owns
  /// and disposes it.
  final PulseHighlightController? controller;

  /// Color of the rings. Defaults to the theme's `colorScheme.primary`.
  final Color? pulseColor;

  /// How far the rings grow, as a multiple of the child's size. Defaults
  /// to 1.6. Must be at least 1.0.
  final double maxRadiusFactor;

  /// Number of staggered rings per pulse cycle. Defaults to 2.
  final int ringCount;

  /// Duration of one pulse cycle. Defaults to 1500 milliseconds.
  final Duration duration;

  /// Curve of the ring expansion. Defaults to [Curves.easeOut].
  final Curve curve;

  /// Whether pulsing starts on its own. Ignored when the platform requests
  /// reduced motion. Defaults to `true`.
  final bool autoPlay;

  /// Number of pulse cycles before the widget stops itself. When null the
  /// widget pulses until stopped. Defaults to null.
  final int? maxPulseCount;

  /// Whether tapping the widget stops the pulses. The tap also reaches the
  /// child, so its own gestures keep working. Defaults to `true`.
  final bool stopOnTap;

  /// Called at the end of every completed pulse cycle.
  final VoidCallback? onPulseComplete;

  /// When `false`, the widget never pulses and the child renders normally.
  final bool enabled;

  /// Shape of the rings. Defaults to [BoxShape.circle]. For
  /// [BoxShape.rectangle] the corners can be rounded with [borderRadius].
  final BoxShape shape;

  /// Corner rounding of rectangular rings. Ignored for [BoxShape.circle].
  final BorderRadius? borderRadius;

  @override
  State<PulseHighlight> createState() => _PulseHighlightState();
}

class _PulseHighlightState extends State<PulseHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  bool _shouldPlay = false;
  int _completedPulses = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: widget.duration);
    _animation.addStatusListener(_handleCycleStatus);
    _shouldPlay = widget.autoPlay || (widget.controller?.isPulsing ?? false);
    widget.controller?.addListener(_handleControllerChanged);
    widget.controller?._isPulsing = _shouldPlay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(PulseHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _animation.duration = widget.duration;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      widget.controller?._isPulsing = _shouldPlay;
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _shouldPlay = widget.autoPlay;
      _completedPulses = 0;
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _animation.removeStatusListener(_handleCycleStatus);
    _animation.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {
      _shouldPlay = widget.controller!.isPulsing;
      if (_shouldPlay) {
        _completedPulses = 0;
      }
    });
    _syncPlayback();
  }

  void _handleCycleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    _completedPulses++;
    widget.onPulseComplete?.call();
    if (!mounted) return;
    if (widget.maxPulseCount != null &&
        _completedPulses >= widget.maxPulseCount!) {
      _stopPulsing();
    } else if (_shouldPlay && widget.enabled) {
      _animation.forward(from: 0.0);
    }
  }

  void _stopPulsing() {
    setState(() {
      _shouldPlay = false;
    });
    widget.controller?._isPulsing = false;
    _syncPlayback();
  }

  void _syncPlayback() {
    final bool reduced = MicroMotion.isReduced(context);
    final bool play = _shouldPlay && widget.enabled && !reduced;
    if (play) {
      if (!_animation.isAnimating) {
        _animation.forward(from: 0.0);
      }
    } else {
      if (_animation.isAnimating) {
        _animation.stop();
      }
      _animation.value = 0.0;
    }
    widget.controller?._isPulsing = play;
  }

  void _handleTap() {
    if (!widget.stopOnTap || !_shouldPlay) return;
    _stopPulsing();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MicroMotion.isReduced(context);
    final bool showRings = _shouldPlay && widget.enabled && !reduced;
    if (!widget.enabled || reduced) {
      return widget.child;
    }
    final Color color =
        widget.pulseColor ?? Theme.of(context).colorScheme.primary;

    // Clip.none: rings intentionally overflow the child's bounds. The
    // child is last so it renders above the rings.
    Widget result = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (showRings)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PulsePainter(
                      animation: _animation,
                      color: color,
                      maxRadiusFactor: widget.maxRadiusFactor,
                      ringCount: widget.ringCount,
                      curve: widget.curve,
                      shape: widget.shape,
                      borderRadius: widget.borderRadius,
                    ),
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
    if (widget.stopOnTap) {
      // Translucent so the child's own gestures still receive the tap.
      result = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _handleTap,
        child: result,
      );
    }
    return result;
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.animation,
    required this.color,
    required this.maxRadiusFactor,
    required this.ringCount,
    required this.curve,
    required this.shape,
    required this.borderRadius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double maxRadiusFactor;
  final int ringCount;
  final Curve curve;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double growth = (maxRadiusFactor - 1.0) * (size.shortestSide / 2);

    for (int i = 0; i < ringCount; i++) {
      final double t = (animation.value + i / ringCount) % 1.0;
      final double eased = curve.transform(t);
      final double opacity = ((1.0 - eased) * 0.5).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final Paint paint = Paint()
        ..color = color.withValues(alpha: color.a * opacity)
        ..style = PaintingStyle.fill;

      if (shape == BoxShape.circle) {
        final double radius = size.shortestSide / 2 + growth * eased;
        canvas.drawCircle(size.center(Offset.zero), radius, paint);
      } else {
        final Rect rect = (Offset.zero & size).inflate(growth * eased);
        final RRect rrect =
            (borderRadius ?? BorderRadius.zero).toRRect(rect);
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.color != color ||
        oldDelegate.maxRadiusFactor != maxRadiusFactor ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.curve != curve ||
        oldDelegate.shape != shape ||
        oldDelegate.borderRadius != borderRadius;
  }
}
