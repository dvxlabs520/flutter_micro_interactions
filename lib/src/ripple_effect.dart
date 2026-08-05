import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Paints expanding circular ripples on top of its child when tapped.
///
/// Every tap spawns a new ripple at the tap position, so rapid taps show
/// several concurrent ripples. Ripples are clipped to the widget's bounds,
/// optionally rounded with [borderRadius].
///
/// When the platform requests reduced motion no ripples are painted, but
/// [onTap] still fires.
///
/// ```dart
/// RippleEffect(
///   borderRadius: BorderRadius.circular(12),
///   onTap: () => debugPrint('tap'),
///   child: const SizedBox(width: 200, height: 80),
/// )
/// ```
class RippleEffect extends StatefulWidget {
  /// Creates a ripple effect widget.
  const RippleEffect({
    super.key,
    required this.child,
    this.rippleColor,
    this.duration = const Duration(milliseconds: 800),
    this.rippleCount = 3,
    this.rippleRadius = 100.0,
    this.rippleSpreadDuration = const Duration(milliseconds: 200),
    this.borderRadius,
    this.onTap,
    this.enabled = true,
  })  : assert(rippleCount > 0, 'rippleCount must be at least 1'),
        assert(rippleRadius > 0, 'rippleRadius must be positive');

  /// The widget the ripples are painted over.
  final Widget child;

  /// Color of the ripples. Defaults to the theme's primary color at 30%
  /// opacity.
  final Color? rippleColor;

  /// Total duration of one ripple animation. Defaults to 800 milliseconds.
  final Duration duration;

  /// How many concentric circles each tap produces.
  final int rippleCount;

  /// Maximum radius each circle grows to.
  final double rippleRadius;

  /// Delay between consecutive circles of the same tap.
  final Duration rippleSpreadDuration;

  /// Rounds the clip applied to the ripples. When null the clip is
  /// rectangular.
  final BorderRadius? borderRadius;

  /// Called on tap-up, immediately.
  final VoidCallback? onTap;

  /// Whether taps spawn ripples. When false the child renders unchanged
  /// and [onTap] does not fire.
  final bool enabled;

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEntry {
  _RippleEntry({required this.controller, required this.center});

  final AnimationController controller;
  final Offset center;

  void dispose() => controller.dispose();
}

class _RippleEffectState extends State<RippleEffect>
    with TickerProviderStateMixin {
  // One short-lived controller per active ripple is intentional here:
  // concurrent ripples from rapid taps each need their own progress.
  // Entries are removed and disposed as soon as their animation completes.
  final List<_RippleEntry> _ripples = <_RippleEntry>[];

  @override
  void dispose() {
    for (final _RippleEntry ripple in _ripples) {
      ripple.dispose();
    }
    _ripples.clear();
    super.dispose();
  }

  void _startRipple(TapDownDetails details) {
    if (!widget.enabled || MicroMotion.isReduced(context)) return;
    final AnimationController controller =
        AnimationController(vsync: this, duration: widget.duration);
    final _RippleEntry entry =
        _RippleEntry(controller: controller, center: details.localPosition);
    controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) return;
      setState(() {
        _ripples.remove(entry);
      });
      entry.dispose();
    });
    setState(() {
      _ripples.add(entry);
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final Color color = widget.rippleColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
    return GestureDetector(
      onTapDown: _startRipple,
      onTap: widget.onTap,
      // Opaque so the whole child area is tappable, including transparent
      // regions (for example a plain SizedBox child).
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: Stack(
          children: <Widget>[
            widget.child,
            if (_ripples.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RipplePainter(
                        ripples: _ripples,
                        rippleColor: color,
                        rippleCount: widget.rippleCount,
                        rippleRadius: widget.rippleRadius,
                        rippleSpreadDuration: widget.rippleSpreadDuration,
                        animationDuration: widget.duration,
                        repaint: Listenable.merge(<Listenable>[
                          for (final _RippleEntry r in _ripples) r.controller,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.ripples,
    required this.rippleColor,
    required this.rippleCount,
    required this.rippleRadius,
    required this.rippleSpreadDuration,
    required this.animationDuration,
    super.repaint,
  });

  final List<_RippleEntry> ripples;
  final Color rippleColor;
  final int rippleCount;
  final double rippleRadius;
  final Duration rippleSpreadDuration;
  final Duration animationDuration;

  @override
  void paint(Canvas canvas, Size size) {
    final double spreadRatio = animationDuration.inMilliseconds == 0
        ? 0
        : rippleSpreadDuration.inMilliseconds /
            animationDuration.inMilliseconds;

    for (final _RippleEntry ripple in ripples) {
      final double progress = ripple.controller.value;
      for (int i = 0; i < rippleCount; i++) {
        final double circleProgress =
            (progress - i * spreadRatio).clamp(0.0, 1.0);
        if (circleProgress <= 0) continue;

        final double radius = rippleRadius * circleProgress;
        final double opacity = (1.0 - circleProgress).clamp(0.0, 1.0);

        final Paint paint = Paint()
          ..color = rippleColor.withValues(alpha: rippleColor.a * opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(ripple.center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.ripples != ripples ||
        oldDelegate.rippleColor != rippleColor ||
        oldDelegate.rippleCount != rippleCount ||
        oldDelegate.rippleRadius != rippleRadius ||
        oldDelegate.rippleSpreadDuration != rippleSpreadDuration ||
        oldDelegate.animationDuration != animationDuration;
  }
}

/// A ready-made button surface with the package's [RippleEffect].
///
/// Colors default to the theme's color scheme: [backgroundColor] falls
/// back to `colorScheme.primary` and [rippleColor] to `colorScheme.onPrimary`
/// at 24% opacity. The button is exposed as a button to assistive
/// technology and can be activated with Enter or Space when focused.
///
/// ```dart
/// RippleButton(
///   onTap: _submit,
///   child: const Text('Submit'),
/// )
/// ```
class RippleButton extends StatelessWidget {
  /// Creates a ripple button.
  const RippleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.rippleColor,
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.all(16.0),
    this.enabled = true,
    this.semanticLabel,
  });

  /// The button content.
  final Widget child;

  /// Called on tap or keyboard activation.
  final VoidCallback onTap;

  /// Ripple color. Defaults to `colorScheme.onPrimary` at 24% opacity.
  final Color? rippleColor;

  /// Background color. Defaults to `colorScheme.primary`.
  final Color? backgroundColor;

  /// Corner rounding of the button surface and ripple clip.
  final BorderRadius borderRadius;

  /// Padding around [child].
  final EdgeInsetsGeometry padding;

  /// Whether the button reacts to input.
  final bool enabled;

  /// Optional semantic label announced for the button.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = backgroundColor ?? scheme.primary;
    final Color ripple =
        rippleColor ?? scheme.onPrimary.withValues(alpha: 0.24);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: RippleEffect(
          rippleColor: ripple,
          borderRadius: borderRadius,
          onTap: onTap,
          enabled: enabled,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: borderRadius,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Programmatic control for a [WaterRipple].
///
/// ```dart
/// final _waves = WaterRippleController();
/// // later
/// _waves.start();
/// _waves.stop();
/// ```
class WaterRippleController extends ChangeNotifier {
  bool _playing = false;

  /// Whether the ripple animation is currently requested to play.
  bool get isPlaying => _playing;

  /// Starts the looping wave animation.
  void start() {
    if (_playing) return;
    _playing = true;
    notifyListeners();
  }

  /// Stops the looping wave animation.
  void stop() {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
  }
}

/// Draws looping concentric waves behind its child, like water ripples.
///
/// The waves are purely decorative paint and never appear in the
/// semantics tree.
/// Use [autoPlay] to loop from the start, or drive playback with a
/// [WaterRippleController]. When the platform requests reduced motion the
/// animation never loops and the widget renders static.
///
/// ```dart
/// WaterRipple(
///   controller: _waves,
///   child: const Icon(Icons.mic, size: 48),
/// )
/// ```
class WaterRipple extends StatefulWidget {
  /// Creates a water ripple widget.
  const WaterRipple({
    super.key,
    required this.child,
    this.rippleColor,
    this.waveCount = 5,
    this.duration = const Duration(seconds: 2),
    this.autoPlay = true,
    this.controller,
  }) : assert(waveCount > 0, 'waveCount must be at least 1');

  /// The widget drawn on top of the waves.
  final Widget child;

  /// Color of the waves. Defaults to the theme's primary color.
  final Color? rippleColor;

  /// Number of concurrent wave rings.
  final int waveCount;

  /// Duration of one full wave cycle.
  final Duration duration;

  /// Whether the animation starts playing on its own. Ignored when the
  /// platform requests reduced motion.
  final bool autoPlay;

  /// Optional controller to start and stop the waves. The caller owns
  /// and disposes it.
  final WaterRippleController? controller;

  @override
  State<WaterRipple> createState() => _WaterRippleState();
}

class _WaterRippleState extends State<WaterRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  bool _shouldPlay = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: widget.duration);
    _shouldPlay = widget.controller?.isPlaying ?? widget.autoPlay;
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(WaterRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _animation.duration = widget.duration;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      _shouldPlay = widget.controller?.isPlaying ?? widget.autoPlay;
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _shouldPlay = widget.autoPlay;
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _animation.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _shouldPlay = widget.controller!.isPlaying;
    _syncPlayback();
  }

  void _syncPlayback() {
    final bool reduced = MicroMotion.isReduced(context);
    if (_shouldPlay && !reduced) {
      if (!_animation.isAnimating) {
        _animation.repeat();
      }
    } else {
      if (_animation.isAnimating) {
        _animation.stop();
      }
      if (reduced) {
        _animation.value = 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        widget.rippleColor ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WaterRipplePainter(
          animation: _animation,
          rippleColor: color,
          waveCount: widget.waveCount,
        ),
        child: widget.child,
      ),
    );
  }
}

class _WaterRipplePainter extends CustomPainter {
  _WaterRipplePainter({
    required this.animation,
    required this.rippleColor,
    required this.waveCount,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color rippleColor;
  final int waveCount;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.max(size.width, size.height) * 0.5;
    final double progress = animation.value;

    for (int i = 0; i < waveCount; i++) {
      final double waveProgress = (progress + i / waveCount) % 1.0;
      final double radius = maxRadius * waveProgress;
      final double opacity = (1.0 - waveProgress).clamp(0.0, 0.5);

      final Paint paint = Paint()
        ..color = rippleColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterRipplePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.rippleColor != rippleColor ||
        oldDelegate.waveCount != waveCount;
  }
}
