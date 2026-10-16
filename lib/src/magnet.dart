import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Pulls its child toward the pointer while the pointer is near it.
///
/// When a mouse pointer comes within [padding] pixels of the child, the
/// child eases toward the pointer by [strength] times the distance between
/// the pointer and the child's center. When the pointer leaves that area
/// the child springs back to its resting position.
///
/// ```dart
/// Magnet(
///   strength: 0.3,
///   padding: 60,
///   child: FilledButton(
///     onPressed: () {},
///     child: const Text('Get started'),
///   ),
/// )
/// ```
///
/// On touch devices the child follows the finger while it is down and
/// dragging over the area, and springs back when the finger lifts or
/// leaves the area.
///
/// The magnet observes pointer events without taking part in hit testing,
/// so it never blocks taps, drags or hover effects of the child or of
/// nearby widgets. Only the painted position changes; layout is
/// unaffected. The child's hit area moves with it, so a pulled button can
/// be tapped where it is drawn. The attraction area is always measured
/// from the child's resting position.
///
/// The effect is purely visual and adds no semantics. When the platform
/// requests reduced motion, or when [enabled] is `false`, the child never
/// moves.
class Magnet extends StatefulWidget {
  /// Creates a magnet effect around [child].
  const Magnet({
    super.key,
    required this.child,
    this.strength = 0.3,
    this.padding = 60.0,
    this.activeDuration = const Duration(milliseconds: 300),
    this.inactiveDuration = const Duration(milliseconds: 600),
    this.activeCurve = Curves.easeOut,
    this.inactiveCurve = Curves.elasticOut,
    this.enabled = true,
  }) : assert(strength >= 0 && strength <= 1, 'strength must be in [0, 1]'),
       assert(padding >= 0, 'padding must not be negative');

  /// The widget pulled toward the pointer.
  final Widget child;

  /// Fraction of the pointer's offset from the child's center that the
  /// child moves by, in `[0, 1]`. 0 disables the pull and 1 centers the
  /// child under the pointer. Defaults to 0.3.
  final double strength;

  /// Extra distance around the child, in logical pixels, within which the
  /// pointer attracts it. Defaults to 60.
  final double padding;

  /// Time the child takes to ease toward a new pointer position. Defaults
  /// to 300 milliseconds.
  final Duration activeDuration;

  /// Time the child takes to return to rest after the pointer leaves.
  /// Defaults to 600 milliseconds.
  final Duration inactiveDuration;

  /// Curve used while following the pointer. Defaults to
  /// [Curves.easeOut].
  final Curve activeCurve;

  /// Curve used when returning to rest. Defaults to [Curves.elasticOut]
  /// for a spring-like settle.
  final Curve inactiveCurve;

  /// When `false` the child stays at rest and pointer events are ignored.
  /// Defaults to `true`.
  final bool enabled;

  @override
  State<Magnet> createState() => _MagnetState();
}

class _MagnetState extends State<Magnet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Curve _curve = Curves.easeOut;
  bool _active = false;
  bool _routeAdded = false;
  bool _reduced = false;
  int? _viewId;

  /// Touch or stylus pointer currently pulling the child, if any.
  int? _touchPointer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.activeDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _viewId = View.maybeOf(context)?.viewId;
    _sync();
  }

  @override
  void didUpdateWidget(Magnet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _sync();
    }
  }

  @override
  void dispose() {
    _removeRoute();
    _controller.dispose();
    super.dispose();
  }

  /// The current painted offset of the child.
  Offset get _offset =>
      Offset.lerp(_from, _to, _curve.transform(_controller.value))!;

  void _sync() {
    final bool listening = widget.enabled && !_reduced;
    if (listening) {
      if (!_routeAdded) {
        GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
        _routeAdded = true;
      }
    } else {
      _removeRoute();
      _active = false;
      _touchPointer = null;
      _controller.stop();
      _from = Offset.zero;
      _to = Offset.zero;
      _controller.value = 1.0;
    }
  }

  void _removeRoute() {
    if (!_routeAdded) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    _routeAdded = false;
  }

  void _animateTo(Offset target, Duration duration, Curve curve) {
    if (target == _to && _controller.isAnimating) return;
    _from = _offset;
    _to = target;
    _curve = curve;
    _controller.duration = duration;
    _controller.forward(from: 0.0);
  }

  void _follow(Offset target) {
    _active = true;
    _animateTo(target, widget.activeDuration, widget.activeCurve);
  }

  void _release() {
    if (!_active) return;
    _active = false;
    _animateTo(Offset.zero, widget.inactiveDuration, widget.inactiveCurve);
  }

  /// Returns the pull target for a global [position], or null when the
  /// position lies outside the attraction area.
  Offset? _targetFor(Offset position) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    final Offset local = object.globalToLocal(position);
    final Rect area = (Offset.zero & object.size).inflate(widget.padding);
    if (!area.contains(local)) return null;
    return (local - object.size.center(Offset.zero)) * widget.strength;
  }

  void _handlePointer(PointerEvent event) {
    if (!mounted) return;
    if (_viewId != null && event.viewId != _viewId) return;

    if (event is PointerRemovedEvent) {
      _release();
      return;
    }

    if (event.kind == PointerDeviceKind.mouse) {
      if (event is PointerHoverEvent || event is PointerMoveEvent) {
        final Offset? target = _targetFor(event.position);
        if (target != null) {
          _follow(target);
        } else {
          _release();
        }
      }
      return;
    }

    // Touch, stylus and other pointers: follow while down and inside.
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      if (_touchPointer != null && _touchPointer != event.pointer) return;
      final Offset? target = _targetFor(event.position);
      if (target != null) {
        _touchPointer = event.pointer;
        _follow(target);
      } else if (_touchPointer == event.pointer) {
        _touchPointer = null;
        _release();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_touchPointer == event.pointer) {
        _touchPointer = null;
        _release();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(offset: _offset, child: child);
      },
      child: widget.child,
    );
  }
}
