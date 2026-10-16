import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Shape of the particles emitted by a [SuccessBurst].
enum ParticleShape {
  /// A random mix of circles and rectangles.
  mixed,

  /// Circles only.
  circle,

  /// Rectangles only.
  rectangle,
}

/// Programmatic control for a [SuccessBurst] widget.
///
/// ```dart
/// final controller = SuccessBurstController();
/// // ...
/// SuccessBurst(
///   controller: controller,
///   child: const Icon(Icons.check_circle, size: 48),
/// );
/// // later:
/// controller.burst();
/// ```
///
/// Calling [burst] repeatedly in quick succession is allowed; each call
/// launches its own batch of particles. Dispose the controller yourself
/// when it is no longer needed.
class SuccessBurstController extends ChangeNotifier {
  /// Launches one burst of particles from the attached [SuccessBurst].
  void burst() => notifyListeners();
}

/// A one-shot particle burst for success confirmations.
///
/// Small colored circles and rectangles are launched radially from the
/// center of [child], drift outward with a light gravity pull and fade out
/// over the second half of [duration]. Typical use is around a checkmark
/// or a completed action.
///
/// ```dart
/// final controller = SuccessBurstController();
/// SuccessBurst(
///   controller: controller,
///   child: const Icon(Icons.check_circle, size: 48),
/// );
/// // when the action succeeds:
/// controller.burst();
/// ```
///
/// Bursts intentionally overflow the child's bounds: the particle layer is
/// not clipped, so particles fly beyond the widget. Leave some room around
/// the widget or place it above surrounding content.
///
/// The particle layer is purely decorative: it never receives pointer
/// events and is excluded from the semantics tree.
///
/// When the platform requests reduced motion no particles are shown, but
/// [onCompleted] still fires (after [Duration.zero]).
class SuccessBurst extends StatefulWidget {
  /// Creates a success burst widget.
  const SuccessBurst({
    super.key,
    required this.child,
    this.controller,
    this.particleCount = 24,
    this.spreadRadius = 80.0,
    this.colors,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.shapes = ParticleShape.mixed,
    this.burstOnTap = false,
    this.onCompleted,
    this.enabled = true,
    this.seed,
  }) : assert(particleCount > 0, 'particleCount must be at least 1'),
       assert(spreadRadius > 0, 'spreadRadius must be positive');

  /// The widget the particles burst from. Rendered unchanged.
  final Widget child;

  /// Optional controller to trigger bursts programmatically. The caller
  /// owns and disposes it.
  final SuccessBurstController? controller;

  /// Number of particles per burst. Defaults to 24.
  final int particleCount;

  /// Base distance particles travel from the center. Each particle varies
  /// its own distance around this value. Defaults to 80.
  final double spreadRadius;

  /// Particle colors, picked randomly per particle. Defaults to the
  /// theme's `colorScheme.primary`, `secondary` and `tertiary`. Must not
  /// be empty when provided.
  final List<Color>? colors;

  /// Duration of one burst. Defaults to 700 milliseconds.
  final Duration duration;

  /// Curve of the outward motion. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Shape of the particles. Defaults to [ParticleShape.mixed].
  final ParticleShape shapes;

  /// Whether tapping the child also triggers a burst. Defaults to `false`.
  final bool burstOnTap;

  /// Called once per burst when its particles have finished. Under reduced
  /// motion it fires after [Duration.zero] instead.
  final VoidCallback? onCompleted;

  /// When `false`, controller calls and taps are ignored and the child
  /// renders normally.
  final bool enabled;

  /// Optional seed for the random generator so particle layouts are
  /// deterministic, mainly for tests.
  final int? seed;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

/// Precomputed random parameters of one particle.
class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isCircle,
    required this.rotation,
    required this.rotationSpeed,
    required this.gravity,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isCircle;
  final double rotation;
  final double rotationSpeed;
  final double gravity;
}

/// One burst in flight: its own progress plus its frozen particle set.
class _BurstBatch {
  _BurstBatch({required this.controller, required this.particles});

  final AnimationController controller;
  final List<_Particle> particles;

  void dispose() => controller.dispose();
}

class _SuccessBurstState extends State<SuccessBurst>
    with TickerProviderStateMixin {
  // One short-lived controller per burst is intentional: bursts triggered
  // in quick succession each need their own progress, like the concurrent
  // ripples in RippleEffect. Batches are removed and disposed as soon as
  // their animation completes.
  final List<_BurstBatch> _batches = <_BurstBatch>[];
  late math.Random _random;

  @override
  void initState() {
    super.initState();
    _random = math.Random(widget.seed);
    widget.controller?.addListener(_handleBurstRequested);
  }

  @override
  void didUpdateWidget(SuccessBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleBurstRequested);
      widget.controller?.addListener(_handleBurstRequested);
    }
    if (widget.seed != oldWidget.seed) {
      _random = math.Random(widget.seed);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleBurstRequested);
    for (final _BurstBatch batch in _batches) {
      batch.dispose();
    }
    _batches.clear();
    super.dispose();
  }

  void _handleBurstRequested() {
    if (!mounted) return;
    _burst();
  }

  void _burst() {
    if (!widget.enabled) return;
    assert(
      widget.colors == null || widget.colors!.isNotEmpty,
      'colors must not be empty when provided',
    );
    if (MicroMotion.isReduced(context)) {
      // No particles, but the completion callback still fires.
      Future<void>.delayed(Duration.zero).then((_) {
        if (!mounted) return;
        widget.onCompleted?.call();
      });
      return;
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors =
        widget.colors ??
        <Color>[scheme.primary, scheme.secondary, scheme.tertiary];

    final List<_Particle> particles = List<_Particle>.generate(
      widget.particleCount,
      (int i) {
        final double baseAngle = i * 2 * math.pi / widget.particleCount;
        final bool isCircle = switch (widget.shapes) {
          ParticleShape.circle => true,
          ParticleShape.rectangle => false,
          ParticleShape.mixed => _random.nextBool(),
        };
        return _Particle(
          angle: baseAngle + (_random.nextDouble() - 0.5) * 0.6,
          speed: 0.6 + _random.nextDouble() * 0.4,
          size: 3.0 + _random.nextDouble() * 4.0,
          color: colors[_random.nextInt(colors.length)],
          isCircle: isCircle,
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 4 * math.pi,
          gravity: 0.2 + _random.nextDouble() * 0.5,
        );
      },
    );

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final _BurstBatch batch = _BurstBatch(
      controller: controller,
      particles: particles,
    );
    controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      if (!mounted) return;
      setState(() {
        _batches.remove(batch);
      });
      batch.dispose();
      widget.onCompleted?.call();
    });
    setState(() {
      _batches.add(batch);
    });
    controller.forward();
  }

  void _handleTap() {
    if (!widget.enabled || !widget.burstOnTap) return;
    _burst();
  }

  @override
  Widget build(BuildContext context) {
    // Clip.none: bursts intentionally overflow the child's bounds.
    Widget result = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        if (_batches.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BurstPainter(
                      batches: _batches,
                      spreadRadius: widget.spreadRadius,
                      curve: widget.curve,
                      repaint: Listenable.merge(<Listenable>[
                        for (final _BurstBatch b in _batches) b.controller,
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.burstOnTap && widget.enabled) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: result,
      );
    }
    return result;
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.batches,
    required this.spreadRadius,
    required this.curve,
    super.repaint,
  });

  final List<_BurstBatch> batches;
  final double spreadRadius;
  final Curve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);

    for (final _BurstBatch batch in batches) {
      final double t = batch.controller.value;
      final double eased = curve.transform(t);
      // Fade out over the second half of the burst.
      final double opacity = t < 0.5
          ? 1.0
          : (1.0 - (t - 0.5) * 2).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      for (final _Particle particle in batch.particles) {
        final double distance = spreadRadius * particle.speed * eased;
        final Offset position =
            center +
            Offset(
              math.cos(particle.angle) * distance,
              math.sin(particle.angle) * distance +
                  particle.gravity * spreadRadius * t * t,
            );
        final Paint paint = Paint()
          ..color = particle.color.withValues(alpha: particle.color.a * opacity)
          ..style = PaintingStyle.fill;

        if (particle.isCircle) {
          canvas.drawCircle(position, particle.size / 2, paint);
        } else {
          canvas.save();
          canvas.translate(position.dx, position.dy);
          canvas.rotate(particle.rotation + particle.rotationSpeed * t);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.6,
            ),
            paint,
          );
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return oldDelegate.batches != batches ||
        oldDelegate.spreadRadius != spreadRadius ||
        oldDelegate.curve != curve;
  }
}
