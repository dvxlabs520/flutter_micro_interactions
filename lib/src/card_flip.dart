import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Programmatic control for a [CardFlip] widget.
///
/// ```dart
/// final controller = CardFlipController();
/// // ...
/// CardFlip(
///   controller: controller,
///   front: const FrontFace(),
///   back: const BackFace(),
/// );
/// // later:
/// controller.flip();
/// ```
///
/// [isFront] reflects the face the attached card is currently showing.
/// Dispose the controller yourself when it is no longer needed.
class CardFlipController extends ChangeNotifier {
  _FlipCommand? _pending;
  bool _isFront = true;

  /// Whether the attached card is currently showing its front face.
  bool get isFront => _isFront;

  /// Flips the card to its other face.
  void flip() {
    _pending = _FlipCommand.toggle;
    notifyListeners();
  }

  /// Shows the front face (no-op when already showing it).
  void showFront() {
    _pending = _FlipCommand.front;
    notifyListeners();
  }

  /// Shows the back face (no-op when already showing it).
  void showBack() {
    _pending = _FlipCommand.back;
    notifyListeners();
  }
}

enum _FlipCommand { toggle, front, back }

/// A card with a front and a back face joined by a 3D flip animation.
///
/// ```dart
/// CardFlip(
///   front: const FrontFace(),
///   back: const BackFace(),
/// )
/// ```
///
/// Like Flutter's [Switch], the widget supports controlled and uncontrolled
/// use:
///
/// * Uncontrolled ([isFlipped] is null): tapping toggles the card itself and
///   [onFlip] reports the new state.
/// * Controlled ([isFlipped] is non-null): the widget always shows the face
///   the parent dictates. Tapping only calls [onFlip] with the desired new
///   value; the parent decides whether to rebuild with it.
///
/// Additional control is available through [controller]. Rapid taps stay in
/// sync because the visible face is derived from the animation controller's
/// status, not from a separately toggled flag.
///
/// The hidden face is excluded from semantics and pointer events. The card
/// announces "showing front" or "showing back" to assistive technology.
///
/// Under reduced motion the faces swap instantly without rotation.
class CardFlip extends StatefulWidget {
  /// Creates a card flip widget.
  const CardFlip({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
    this.isFlipped,
    this.onFlip,
    this.controller,
    this.flipOnTap = true,
    this.direction = Axis.horizontal,
    this.perspective = 0.001,
    this.enabled = true,
  }) : assert(perspective >= 0, 'perspective must not be negative');

  /// The face shown initially.
  final Widget front;

  /// The face shown after a flip.
  final Widget back;

  /// Duration of the flip. Defaults to 500 milliseconds.
  final Duration duration;

  /// Curve of the flip. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// When non-null the widget is controlled: `true` shows [back], `false`
  /// shows [front], and taps only report through [onFlip].
  final bool? isFlipped;

  /// Called with the new flipped state (`true` = back visible). In
  /// controlled mode this is a request; the parent applies it by rebuilding
  /// with a new [isFlipped].
  final ValueChanged<bool>? onFlip;

  /// Optional controller for programmatic flips.
  final CardFlipController? controller;

  /// Whether tapping the card flips it. Defaults to `true`.
  final bool flipOnTap;

  /// Axis of the rotation: [Axis.horizontal] rotates around the vertical
  /// axis (left-right flip), [Axis.vertical] around the horizontal axis
  /// (top-bottom flip). Defaults to [Axis.horizontal].
  final Axis direction;

  /// Amount of 3D perspective applied during the flip. Defaults to 0.001.
  final double perspective;

  /// When `false`, taps and controller commands are ignored.
  final bool enabled;

  @override
  State<CardFlip> createState() => _CardFlipState();
}

class _CardFlipState extends State<CardFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;

  bool get _controlled => widget.isFlipped != null;

  /// Whether the flip is heading to (or resting at) the back face. Derived
  /// from the animation controller status so rapid taps cannot desync.
  bool get _targetIsBack =>
      _controller.status == AnimationStatus.forward ||
      _controller.status == AnimationStatus.completed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (widget.isFlipped == true) {
      _controller.value = 1.0;
    }
    _controller.addStatusListener(_onStatusChanged);
    widget.controller?.addListener(_onControllerCommand);
    widget.controller?._isFront = !_targetIsBack;
  }

  @override
  void didUpdateWidget(CardFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerCommand);
      widget.controller?.addListener(_onControllerCommand);
      widget.controller?._isFront = !_targetIsBack;
    }
    // Sync with the parent-provided value in controlled mode.
    if (widget.isFlipped != null && widget.isFlipped != oldWidget.isFlipped) {
      _animateTo(widget.isFlipped!);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerCommand);
    _controller.removeStatusListener(_onStatusChanged);
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    widget.controller?._isFront = !_targetIsBack;
  }

  void _onControllerCommand() {
    final CardFlipController controller = widget.controller!;
    final _FlipCommand? command = controller._pending;
    controller._pending = null;
    if (command == null || !widget.enabled) {
      return;
    }
    switch (command) {
      case _FlipCommand.toggle:
        _requestFlip(!_targetIsBack);
      case _FlipCommand.front:
        _requestFlip(false);
      case _FlipCommand.back:
        _requestFlip(true);
    }
  }

  /// Routes a flip request depending on controlled/uncontrolled mode.
  void _requestFlip(bool toBack) {
    if (_controlled) {
      // Controlled: only report; the parent decides.
      if (toBack != widget.isFlipped) {
        widget.onFlip?.call(toBack);
      }
      return;
    }
    if (toBack == _targetIsBack) {
      return;
    }
    _animateTo(toBack);
    widget.onFlip?.call(toBack);
  }

  void _animateTo(bool toBack) {
    if (MicroMotion.isReduced(context)) {
      // Instant swap without rotation under reduced motion.
      _controller.value = toBack ? 1.0 : 0.0;
      return;
    }
    if (toBack) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleTap() {
    if (!widget.enabled || !widget.flipOnTap) {
      return;
    }
    if (_controlled) {
      widget.onFlip?.call(!widget.isFlipped!);
    } else {
      _requestFlip(!_targetIsBack);
    }
  }

  Matrix4 _flipTransform(double angle) {
    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, widget.perspective);
    if (widget.direction == Axis.horizontal) {
      transform.rotateY(angle);
    } else {
      transform.rotateX(angle);
    }
    return transform;
  }

  @override
  Widget build(BuildContext context) {
    // Both faces are built once per build (not per animation frame) and
    // passed into the AnimatedBuilder closure as prebuilt children. The
    // back face carries a constant half-turn so it reads correctly when the
    // outer rotation passes 90 degrees.
    final Widget frontFace = widget.front;
    final Widget backFace = Transform(
      transform: widget.direction == Axis.horizontal
          ? (Matrix4.identity()..rotateY(math.pi))
          : (Matrix4.identity()..rotateX(math.pi)),
      alignment: Alignment.center,
      child: widget.back,
    );

    final Widget card = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double value = _animation.value;
        final bool showFront = value < 0.5;
        return Semantics(
          label: showFront ? 'Showing front' : 'Showing back',
          child: Transform(
            transform: _flipTransform(math.pi * value),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _FaceVisibility(visible: showFront, child: frontFace),
                _FaceVisibility(visible: !showFront, child: backFace),
              ],
            ),
          ),
        );
      },
    );

    if (!widget.flipOnTap) {
      return card;
    }
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        onTap: _handleTap,
        child: card,
      ),
    );
  }
}

/// Shows or hides one card face, removing the hidden face from semantics
/// and pointer events without rebuilding it.
class _FaceVisibility extends StatelessWidget {
  const _FaceVisibility({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: Opacity(
          opacity: visible ? 1.0 : 0.0,
          child: child,
        ),
      ),
    );
  }
}
