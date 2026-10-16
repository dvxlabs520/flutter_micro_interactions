import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// A card with a soft spotlight that follows the pointer.
///
/// While the pointer is over the card, a radial spotlight is painted
/// behind the child at the pointer position, and the part of the border
/// nearest the pointer lights up with [borderGlowColor]. The spotlight
/// fades in when the pointer enters and fades out when it leaves.
///
/// ```dart
/// SpotlightCard(
///   child: Column(
///     mainAxisSize: MainAxisSize.min,
///     children: const <Widget>[
///       Text('Pro plan'),
///       Text('Everything in Free, plus more.'),
///     ],
///   ),
/// )
/// ```
///
/// On touch devices the spotlight shows while the finger is pressed and
/// follows it while dragging.
///
/// Pointer events are observed without being consumed, so buttons and
/// other gestures inside the card keep working. The spotlight is purely
/// decorative and adds no semantics; the child's semantics are untouched.
///
/// Under reduced motion the spotlight still follows the pointer, because
/// it is direct manipulation, but it appears and disappears instantly
/// instead of fading. When [enabled] is `false` the card renders without a
/// spotlight.
class SpotlightCard extends StatefulWidget {
  /// Creates a card with a pointer-following spotlight.
  const SpotlightCard({
    super.key,
    required this.child,
    this.spotlightColor,
    this.radius = 200.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderWidth = 1.0,
    this.borderColor,
    this.borderGlowColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(24),
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOut,
    this.enabled = true,
  }) : assert(radius > 0, 'radius must be positive'),
       assert(borderWidth >= 0, 'borderWidth must not be negative');

  /// The content of the card.
  final Widget child;

  /// Color at the center of the spotlight. Defaults to the theme's
  /// `colorScheme.primary` at 25 percent opacity.
  final Color? spotlightColor;

  /// Radius of the spotlight in logical pixels. The border glow uses the
  /// same radius. Defaults to 200.
  final double radius;

  /// Corner rounding of the card. Defaults to a 16 pixel circular radius.
  final BorderRadius borderRadius;

  /// Thickness of the border. 0 hides the border and its glow. Defaults
  /// to 1.
  final double borderWidth;

  /// Resting color of the border. Defaults to the theme's
  /// `colorScheme.outlineVariant`.
  final Color? borderColor;

  /// Color of the border near the pointer. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? borderGlowColor;

  /// Fill of the card. Defaults to the theme's
  /// `colorScheme.surfaceContainer`.
  final Color? backgroundColor;

  /// Space between the border and the child. Defaults to 24 on all sides.
  final EdgeInsetsGeometry padding;

  /// Length of the spotlight fade in and fade out. Defaults to 250
  /// milliseconds.
  final Duration duration;

  /// Curve of the fade. Defaults to [Curves.easeOut].
  final Curve curve;

  /// When `false` the spotlight never shows and the card renders
  /// statically. Defaults to `true`.
  final bool enabled;

  @override
  State<SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<SpotlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late CurvedAnimation _fadeCurve;
  final ValueNotifier<Offset?> _position = ValueNotifier<Offset?>(null);
  bool _hovered = false;
  final Set<int> _pressedPointers = <int>{};

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: widget.duration);
    _fadeCurve = CurvedAnimation(parent: _fade, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MicroMotion.isReduced(context) && _fade.isAnimating) {
      _fade.stop();
      _fade.value = _isActive ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(SpotlightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _fade.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _fadeCurve.dispose();
      _fadeCurve = CurvedAnimation(parent: _fade, curve: widget.curve);
    }
    if (!widget.enabled && oldWidget.enabled) {
      _hovered = false;
      _pressedPointers.clear();
      _fade.stop();
      _fade.value = 0.0;
    }
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _fade.dispose();
    _position.dispose();
    super.dispose();
  }

  bool get _isActive => _hovered || _pressedPointers.isNotEmpty;

  void _updateFade() {
    final bool active = _isActive;
    if (MicroMotion.isReduced(context)) {
      _fade.value = active ? 1.0 : 0.0;
    } else if (active) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  void _handleEnter(PointerEnterEvent event) {
    _position.value = event.localPosition;
    _hovered = true;
    _updateFade();
  }

  void _handleHover(PointerHoverEvent event) {
    _position.value = event.localPosition;
  }

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _updateFade();
  }

  void _handleDown(PointerDownEvent event) {
    _position.value = event.localPosition;
    if (event.kind == PointerDeviceKind.mouse) return;
    _pressedPointers.add(event.pointer);
    _updateFade();
  }

  void _handleMove(PointerMoveEvent event) {
    _position.value = event.localPosition;
  }

  void _handleUp(PointerEvent event) {
    if (_pressedPointers.remove(event.pointer)) {
      _updateFade();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color spotlight =
        widget.spotlightColor ?? scheme.primary.withValues(alpha: 0.25);
    final Color glow = widget.borderGlowColor ?? scheme.primary;

    Widget card = CustomPaint(
      painter: _SpotlightPainter(
        position: _position,
        fade: _fadeCurve,
        spotlightColor: spotlight,
        radius: widget.radius,
        borderRadius: widget.borderRadius,
        backgroundColor: widget.backgroundColor ?? scheme.surfaceContainer,
      ),
      foregroundPainter: _SpotlightBorderPainter(
        position: _position,
        fade: _fadeCurve,
        radius: widget.radius,
        borderRadius: widget.borderRadius,
        borderWidth: widget.borderWidth,
        borderColor: widget.borderColor ?? scheme.outlineVariant,
        glowColor: glow,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    card = RepaintBoundary(child: card);

    // The tree shape stays the same when [SpotlightCard.enabled] changes,
    // so the child keeps its state.
    final bool on = widget.enabled;
    return MouseRegion(
      opaque: false,
      onEnter: on ? _handleEnter : null,
      onHover: on ? _handleHover : null,
      onExit: on ? _handleExit : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: on ? _handleDown : null,
        onPointerMove: on ? _handleMove : null,
        onPointerUp: on ? _handleUp : null,
        onPointerCancel: on ? _handleUp : null,
        child: card,
      ),
    );
  }
}

/// Paints the card fill and the soft spotlight behind the child.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.position,
    required this.fade,
    required this.spotlightColor,
    required this.radius,
    required this.borderRadius,
    required this.backgroundColor,
  }) : super(repaint: Listenable.merge(<Listenable>[position, fade]));

  /// Pointer position in local coordinates, or null before any pointer.
  final ValueListenable<Offset?> position;

  /// Spotlight visibility in `[0, 1]`.
  final Animation<double> fade;

  /// Color at the spotlight center.
  final Color spotlightColor;

  /// Spotlight radius.
  final double radius;

  /// Card corner rounding.
  final BorderRadius borderRadius;

  /// Card fill.
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect shape = borderRadius.toRRect(rect);
    canvas.drawRRect(shape, Paint()..color = backgroundColor);

    final double t = fade.value.clamp(0.0, 1.0);
    final Offset? center = position.value;
    if (t <= 0 || center == null) return;

    final Color inner = spotlightColor.withValues(alpha: spotlightColor.a * t);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[inner, inner.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.fade != fade ||
        oldDelegate.spotlightColor != spotlightColor ||
        oldDelegate.radius != radius ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Paints the border, lit near the pointer, above the child.
class _SpotlightBorderPainter extends CustomPainter {
  _SpotlightBorderPainter({
    required this.position,
    required this.fade,
    required this.radius,
    required this.borderRadius,
    required this.borderWidth,
    required this.borderColor,
    required this.glowColor,
  }) : super(repaint: Listenable.merge(<Listenable>[position, fade]));

  /// Pointer position in local coordinates, or null before any pointer.
  final ValueListenable<Offset?> position;

  /// Glow visibility in `[0, 1]`.
  final Animation<double> fade;

  /// Radius of the lit border section.
  final double radius;

  /// Card corner rounding.
  final BorderRadius borderRadius;

  /// Stroke thickness.
  final double borderWidth;

  /// Resting border color.
  final Color borderColor;

  /// Border color near the pointer.
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (borderWidth <= 0) return;
    final Rect strokeRect = (Offset.zero & size).deflate(borderWidth / 2);
    if (strokeRect.isEmpty) return;
    Radius deflate(Radius r) => Radius.elliptical(
      math.max(0, r.x - borderWidth / 2),
      math.max(0, r.y - borderWidth / 2),
    );
    final RRect stroke = RRect.fromRectAndCorners(
      strokeRect,
      topLeft: deflate(borderRadius.topLeft),
      topRight: deflate(borderRadius.topRight),
      bottomLeft: deflate(borderRadius.bottomLeft),
      bottomRight: deflate(borderRadius.bottomRight),
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = borderColor;
    canvas.drawRRect(stroke, paint);

    final double t = fade.value.clamp(0.0, 1.0);
    final Offset? center = position.value;
    if (t <= 0 || center == null) return;

    final Color inner = glowColor.withValues(alpha: glowColor.a * t);
    paint
      ..color = const Color(0xFF000000)
      ..shader = RadialGradient(
        colors: <Color>[inner, inner.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRRect(stroke, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightBorderPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.fade != fade ||
        oldDelegate.radius != radius ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.glowColor != glowColor;
  }
}
