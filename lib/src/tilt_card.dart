import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Tilts its child in 3D toward the pointer, with an optional glare.
///
/// While a mouse pointer is over the child, the child rotates around its
/// center so that the side under the pointer moves away from the viewer,
/// scales up slightly to [scaleOnHover] and shows a soft glare band that
/// follows the pointer. When the pointer leaves, the child springs back to
/// rest over [resetDuration].
///
/// ```dart
/// TiltCard(
///   maxTilt: 12,
///   child: Card(
///     child: Image.asset('assets/cover.jpg', width: 240),
///   ),
/// )
/// ```
///
/// On touch devices the child tilts while the finger is pressed and
/// dragged over it, and springs back when the finger lifts. Device motion
/// sensors (gyroscope) are not used.
///
/// The pointer position is read outside the transform, so the tilt never
/// feeds back into itself. Pointer events are observed without being
/// consumed, so buttons and gestures inside the child keep working. The
/// glare is decorative, ignores pointers and adds no semantics.
///
/// Under reduced motion, or when [enabled] is `false`, the child renders
/// flat without tilt, scale or glare.
class TiltCard extends StatefulWidget {
  /// Creates a tilting card around [child].
  const TiltCard({
    super.key,
    required this.child,
    this.maxTilt = 12.0,
    this.scaleOnHover = 1.03,
    this.perspective = 0.0015,
    this.glare = true,
    this.glareColor = const Color(0xFFFFFFFF),
    this.glareOpacity = 0.25,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.enterDuration = const Duration(milliseconds: 150),
    this.resetDuration = const Duration(milliseconds: 400),
    this.resetCurve = Curves.easeOutBack,
    this.enabled = true,
  }) : assert(
         maxTilt >= 0 && maxTilt <= 90,
         'maxTilt must be between 0 and 90 degrees',
       ),
       assert(scaleOnHover > 0, 'scaleOnHover must be positive'),
       assert(perspective >= 0, 'perspective must not be negative'),
       assert(
         glareOpacity >= 0 && glareOpacity <= 1,
         'glareOpacity must be in [0, 1]',
       );

  /// The widget that tilts.
  final Widget child;

  /// Maximum rotation, in degrees, reached when the pointer is at an edge.
  /// Defaults to 12.
  final double maxTilt;

  /// Scale applied while the pointer is over the child. 1 disables the
  /// scale. Defaults to 1.03.
  final double scaleOnHover;

  /// Strength of the perspective effect, written into the transform
  /// matrix. Larger values exaggerate depth; 0 gives a flat projection.
  /// Defaults to 0.0015.
  final double perspective;

  /// Whether to paint a glare band that follows the pointer. Defaults to
  /// `true`.
  final bool glare;

  /// Color of the glare band. Defaults to white.
  final Color glareColor;

  /// Peak opacity of the glare band, in `[0, 1]`. Defaults to 0.25.
  final double glareOpacity;

  /// Corner rounding used to clip the glare so it matches the child's
  /// shape. Defaults to a 16 pixel circular radius.
  final BorderRadius borderRadius;

  /// Time to reach full tilt and scale after the pointer enters. Defaults
  /// to 150 milliseconds.
  final Duration enterDuration;

  /// Time to return to rest after the pointer leaves. Defaults to 400
  /// milliseconds.
  final Duration resetDuration;

  /// Curve of the return to rest. Defaults to [Curves.easeOutBack], which
  /// overshoots slightly for a spring-like settle.
  final Curve resetCurve;

  /// When `false` the child renders flat and pointer events are ignored.
  /// Defaults to `true`.
  final bool enabled;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  /// Tilt intensity. Unbounded below 0 and above 1 so spring curves can
  /// overshoot.
  late final AnimationController _intensity;

  /// Pointer position normalized to `[-1, 1]` on both axes.
  final ValueNotifier<Offset> _pointer = ValueNotifier<Offset>(Offset.zero);

  bool _hovered = false;
  final Set<int> _pressedPointers = <int>{};
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _intensity = AnimationController(
      vsync: this,
      lowerBound: -1.0,
      upperBound: 2.0,
      value: 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced) _reset();
  }

  @override
  void didUpdateWidget(TiltCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) _reset();
  }

  @override
  void dispose() {
    _intensity.dispose();
    _pointer.dispose();
    super.dispose();
  }

  bool get _listening => widget.enabled && !_reduced;

  void _reset() {
    _hovered = false;
    _pressedPointers.clear();
    _intensity.stop();
    _intensity.value = 0.0;
  }

  void _setPointer(Offset local) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;
    final Size size = object.size;
    if (size.isEmpty) return;
    _pointer.value = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _updateActive() {
    if (_hovered || _pressedPointers.isNotEmpty) {
      _intensity.animateTo(
        1.0,
        duration: widget.enterDuration,
        curve: Curves.easeOut,
      );
    } else {
      _intensity.animateTo(
        0.0,
        duration: widget.resetDuration,
        curve: widget.resetCurve,
      );
    }
  }

  void _handleEnter(PointerEnterEvent event) {
    _setPointer(event.localPosition);
    _hovered = true;
    _updateActive();
  }

  void _handleHover(PointerHoverEvent event) {
    _setPointer(event.localPosition);
  }

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _updateActive();
  }

  void _handleDown(PointerDownEvent event) {
    _setPointer(event.localPosition);
    if (event.kind == PointerDeviceKind.mouse) return;
    _pressedPointers.add(event.pointer);
    _updateActive();
  }

  void _handleMove(PointerMoveEvent event) {
    _setPointer(event.localPosition);
  }

  void _handleUp(PointerEvent event) {
    if (_pressedPointers.remove(event.pointer)) _updateActive();
  }

  Matrix4 _transformFor(Offset pointer, double intensity) {
    final double maxRadians = widget.maxTilt * math.pi / 180;
    final double scale = 1 + (widget.scaleOnHover - 1) * intensity;
    // Flutter projects +z away from the viewer, so these signs push the
    // side under the pointer back.
    return Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..rotateX(pointer.dy * maxRadians * intensity)
      ..rotateY(-pointer.dx * maxRadians * intensity)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    // The tree shape stays the same whether or not the effect is active,
    // so toggling [TiltCard.enabled] or reduced motion keeps the child's
    // state.
    final bool listening = _listening;
    final bool showGlare = listening && widget.glare && widget.glareOpacity > 0;

    return MouseRegion(
      opaque: false,
      onEnter: listening ? _handleEnter : null,
      onHover: listening ? _handleHover : null,
      onExit: listening ? _handleExit : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: listening ? _handleDown : null,
        onPointerMove: listening ? _handleMove : null,
        onPointerUp: listening ? _handleUp : null,
        onPointerCancel: listening ? _handleUp : null,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_intensity, _pointer]),
          builder: (BuildContext context, Widget? child) {
            final double t = _intensity.value;
            return Transform(
              alignment: Alignment.center,
              transform: t == 0.0
                  ? Matrix4.identity()
                  : _transformFor(_pointer.value, t),
              child: child,
            );
          },
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                widget.child,
                if (showGlare)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: widget.borderRadius,
                          child: CustomPaint(
                            painter: _GlarePainter(
                              pointer: _pointer,
                              intensity: _intensity,
                              color: widget.glareColor,
                              opacity: widget.glareOpacity,
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
      ),
    );
  }
}

/// Paints a diagonal glare band through the pointer position.
class _GlarePainter extends CustomPainter {
  _GlarePainter({
    required this.pointer,
    required this.intensity,
    required this.color,
    required this.opacity,
  }) : super(repaint: Listenable.merge(<Listenable>[pointer, intensity]));

  /// Pointer position normalized to `[-1, 1]`.
  final ValueListenable<Offset> pointer;

  /// Tilt intensity; the glare fades with it.
  final Animation<double> intensity;

  /// Glare color.
  final Color color;

  /// Peak glare opacity.
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = intensity.value.clamp(0.0, 1.0);
    if (t <= 0 || size.isEmpty) return;
    final Offset p = pointer.value;
    final Offset center = Offset(
      (p.dx + 1) / 2 * size.width,
      (p.dy + 1) / 2 * size.height,
    );
    // The band runs diagonally and turns slightly as the pointer moves
    // across, so both its position and its angle follow the pointer.
    final double angle = math.pi / 4 + p.dx * math.pi / 12;
    final double half = math.max(size.width, size.height) * 0.35;
    final Offset axis = Offset(math.cos(angle), math.sin(angle)) * half;
    final Color peak = color.withValues(alpha: color.a * opacity * t);
    final Color clear = peak.withValues(alpha: 0);
    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(
        center - axis,
        center + axis,
        <Color>[clear, peak, clear],
        const <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlarePainter oldDelegate) {
    return oldDelegate.pointer != pointer ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity;
  }
}
