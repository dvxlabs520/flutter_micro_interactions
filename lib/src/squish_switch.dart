import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A pill-shaped on/off switch whose thumb behaves like a soft physical
/// object: it stretches with speed and squashes against the end of the
/// track when it arrives.
///
/// ```dart
/// SquishSwitch(
///   value: _wifi,
///   onChanged: (bool value) => setState(() => _wifi = value),
/// )
/// ```
///
/// The thumb is driven by a [SpringSimulation], so its motion is velocity
/// aware: while it travels it grows wider and slightly flatter in
/// proportion to its speed (the area of the thumb stays the same), and when
/// it overshoots the end of the track it is pressed flat against the wall
/// for a moment before springing back. The track color crossfades between
/// [inactiveColor] and [activeColor] as the thumb travels.
///
/// The thumb can be tapped, dragged or flicked. While dragging it follows
/// the finger through a stiff spring, and pushing past the end of the track
/// squashes it against the wall. On release a fast flick decides the new
/// value by its direction; a slow release decides by position.
///
/// The widget is controlled: it calls [onChanged] with the requested value
/// and only settles in the new state when the parent rebuilds it with the
/// new [value]. If the parent keeps the old value after a drag, the thumb
/// springs back.
///
/// Accessibility: the switch is exposed as a toggled control with an
/// optional [semanticLabel]. It is keyboard focusable with a visible focus
/// ring; Enter or Space toggles it, and the arrow keys move it to the off
/// or on side (respecting the ambient [Directionality]). The tap target is
/// at least 48 by 48 logical pixels.
///
/// When [onChanged] is null or [enabled] is false the switch renders in a
/// dimmed disabled style and ignores input. Under reduced motion state
/// changes are instant, with no stretch or squash.
class SquishSwitch extends StatefulWidget {
  /// Creates a squish switch.
  const SquishSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.size = const Size(52, 32),
    this.stretch = 1.0,
    this.spring = const SpringDescription(
      mass: 1.0,
      stiffness: 520.0,
      damping: 26.0,
    ),
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(stretch >= 0.0, 'stretch must not be negative');

  /// Whether the switch is on.
  final bool value;

  /// Called with the requested new value when the user toggles the switch.
  /// When null the switch renders disabled.
  final ValueChanged<bool>? onChanged;

  /// Track color when the switch is on. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? activeColor;

  /// Track color when the switch is off. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? inactiveColor;

  /// Thumb color in both states. When null the thumb uses the theme's
  /// `colorScheme.outline` when off and `colorScheme.onPrimary` when on,
  /// crossfading while it moves.
  final Color? thumbColor;

  /// Size of the track. Defaults to 52 by 32, like the Material 3 switch.
  /// The width must be greater than the height.
  final Size size;

  /// Intensity of the stretch and squash effect. 0 disables it, 1 is the
  /// default and values above 1 exaggerate it.
  final double stretch;

  /// Spring used when the thumb settles on a side. A lower damping ratio
  /// gives a larger overshoot, and therefore a stronger squash. Defaults to
  /// a mass of 1, stiffness of 520 and damping of 26.
  final SpringDescription spring;

  /// Whether a light haptic impact is triggered when the user toggles the
  /// switch. Defaults to true.
  final bool enableHaptics;

  /// When false the switch renders disabled, exactly as if [onChanged]
  /// were null.
  final bool enabled;

  /// Optional label announced by assistive technology.
  final String? semanticLabel;

  @override
  State<SquishSwitch> createState() => _SquishSwitchState();
}

class _SquishSwitchState extends State<SquishSwitch>
    with TickerProviderStateMixin {
  /// Thumb position: 0 is off, 1 is on. It may briefly leave that range
  /// while the spring overshoots; the overshoot is rendered as a squash.
  late final AnimationController _position;

  /// Pressed state of the thumb, 0 to 1.
  late final AnimationController _press;

  bool _reducedMotion = false;
  bool _focused = false;
  bool _dragging = false;
  double _dragAnchor = 0.0;
  double _dragDelta = 0.0;
  double _target = 0.0;

  /// Space between the track and the outer edge of the painted area, which
  /// leaves room for the focus ring.
  static const double _ringMargin = 4.0;

  /// Minimum size of the interactive area.
  static const double _minTapTarget = 48.0;

  /// Opacity of the whole switch when disabled.
  static const double _disabledOpacity = 0.38;

  /// Fling speed, in logical pixels per second, above which a release is
  /// decided by direction instead of position.
  static const double _flingThreshold = 300.0;

  /// Stiff, nearly critically damped spring that makes the thumb follow the
  /// finger while dragging.
  static const SpringDescription _followSpring = SpringDescription(
    mass: 1.0,
    stiffness: 1800.0,
    damping: 76.0,
  );

  static const Tolerance _tolerance = Tolerance(
    distance: 0.0005,
    velocity: 0.01,
  );

  bool get _interactive => widget.enabled && widget.onChanged != null;

  double get _travel => widget.size.width - widget.size.height;

  @override
  void initState() {
    super.initState();
    _target = widget.value ? 1.0 : 0.0;
    _position = AnimationController.unbounded(vsync: this, value: _target)
      ..addStatusListener(_onPositionStatus);
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      if (!_dragging) {
        _position.value = _target;
      }
      _press.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(SquishSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasInteractive =
        oldWidget.enabled && oldWidget.onChanged != null;
    if (wasInteractive && !_interactive) {
      _dragging = false;
      _press.value = 0.0;
      _settle(widget.value ? 1.0 : 0.0);
      return;
    }
    if (widget.value != oldWidget.value && !_dragging) {
      final double target = widget.value ? 1.0 : 0.0;
      // A drag release may already be heading to this side; keep that
      // motion instead of restarting it.
      if (target != _target || !_position.isAnimating) {
        _settle(target);
      }
    }
  }

  @override
  void dispose() {
    _position.removeStatusListener(_onPositionStatus);
    _position.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onPositionStatus(AnimationStatus status) {
    // Snap exactly onto the target once the spring has come to rest.
    if (status == AnimationStatus.completed && !_dragging) {
      _position.value = _target;
    }
  }

  /// Springs the thumb to [target], continuing from its current velocity
  /// unless [velocity] is given.
  void _settle(double target, {double? velocity}) {
    _target = target;
    if (_reducedMotion) {
      _position.value = target;
      return;
    }
    _position.animateWith(
      SpringSimulation(
        widget.spring,
        _position.value,
        target,
        velocity ?? _position.velocity,
        tolerance: _tolerance,
      ),
    );
  }

  void _requestValue(bool newValue) {
    if (!_interactive || newValue == widget.value) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onChanged?.call(newValue);
  }

  void _toggle() => _requestValue(!widget.value);

  /// +1 when a positive horizontal delta moves the thumb towards "on".
  double get _directionSign =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  void _handlePointerDown(PointerDownEvent event) {
    if (!_interactive || _reducedMotion) return;
    _press.forward();
  }

  void _handlePointerUp(PointerEvent event) {
    if (_reducedMotion) return;
    _press.reverse();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_interactive) return;
    _dragging = true;
    _dragAnchor = _position.value.clamp(0.0, 1.0);
    _dragDelta = 0.0;
  }

  /// Maps a raw drag position to a thumb position, with rubber-band
  /// resistance past either end so the thumb squashes against the wall.
  static double _rubberBand(double raw) {
    const double resistance = 0.3;
    const double maxOvershoot = 0.25;
    if (raw > 1.0) {
      return 1.0 + math.min((raw - 1.0) * resistance, maxOvershoot);
    }
    if (raw < 0.0) {
      return -math.min(-raw * resistance, maxOvershoot);
    }
    return raw;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragDelta += details.delta.dx * _directionSign;
    final double target = _rubberBand(_dragAnchor + _dragDelta / _travel);
    if (_reducedMotion) {
      _position.value = target.clamp(0.0, 1.0);
      return;
    }
    _position.animateWith(
      SpringSimulation(
        _followSpring,
        _position.value,
        target,
        _position.velocity,
        tolerance: _tolerance,
      ),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final double fingerVelocity =
        (details.primaryVelocity ?? 0.0) * _directionSign;
    final double fingerPosition = _dragAnchor + _dragDelta / _travel;
    final bool newValue = fingerVelocity.abs() > _flingThreshold
        ? fingerVelocity > 0.0
        : fingerPosition >= 0.5;
    // Carry the finger's momentum into the settle spring (clamped so a wild
    // flick still reads as a squash, not a glitch).
    final double velocity = (fingerVelocity / _travel).clamp(-40.0, 40.0);
    _settle(newValue ? 1.0 : 0.0, velocity: velocity);
    if (newValue != widget.value) {
      _requestValue(newValue);
      // If the parent does not accept the new value, spring back.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && !_dragging && widget.value != newValue) {
          _settle(widget.value ? 1.0 : 0.0);
        }
      });
    }
  }

  void _handleDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(widget.value ? 1.0 : 0.0);
  }

  void _handleArrow(bool forward) {
    // "forward" is the visual right arrow; map it to on/off by direction.
    final bool on = forward == (_directionSign > 0);
    _requestValue(on);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.size.height > 0.0 && widget.size.width > widget.size.height,
      'size must have a positive height and be wider than it is tall',
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool interactive = _interactive;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Size paintSize = Size(
      widget.size.width + _ringMargin * 2,
      widget.size.height + _ringMargin * 2,
    );

    Widget result = RepaintBoundary(
      child: CustomPaint(
        size: paintSize,
        painter: _SquishSwitchPainter(
          position: _position,
          press: _press,
          trackSize: widget.size,
          margin: _ringMargin,
          activeColor: widget.activeColor ?? scheme.primary,
          inactiveColor: widget.inactiveColor ?? scheme.surfaceContainerHighest,
          outlineColor: scheme.outline,
          offThumbColor: widget.thumbColor ?? scheme.outline,
          onThumbColor: widget.thumbColor ?? scheme.onPrimary,
          focusColor: scheme.primary,
          focused: _focused && interactive,
          rtl: rtl,
          stretch: _reducedMotion ? 0.0 : widget.stretch,
        ),
      ),
    );

    result = SizedBox(
      width: math.max(_minTapTarget, paintSize.width),
      height: math.max(_minTapTarget, paintSize.height),
      child: Center(child: result),
    );

    if (!interactive) {
      return Semantics(
        toggled: widget.value,
        enabled: false,
        label: widget.semanticLabel,
        child: Opacity(opacity: _disabledOpacity, child: result),
      );
    }

    result = Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // Report the drag from the touch-down point so the thumb tracks the
        // finger exactly, including the distance moved before the drag won.
        dragStartBehavior: DragStartBehavior.down,
        onTap: _toggle,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: result,
      ),
    );

    return Semantics(
      toggled: widget.value,
      enabled: true,
      label: widget.semanticLabel,
      onTap: _toggle,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool focused) {
          if (focused != _focused) {
            setState(() => _focused = focused);
          }
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): _SwitchArrowIntent(
            forward: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight): _SwitchArrowIntent(
            forward: true,
          ),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _toggle();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _toggle();
              return null;
            },
          ),
          _SwitchArrowIntent: CallbackAction<_SwitchArrowIntent>(
            onInvoke: (_SwitchArrowIntent intent) {
              _handleArrow(intent.forward);
              return null;
            },
          ),
        },
        child: result,
      ),
    );
  }
}

/// Moves the switch towards the visual left or right side.
class _SwitchArrowIntent extends Intent {
  const _SwitchArrowIntent({required this.forward});

  /// True for the right arrow key.
  final bool forward;
}

class _SquishSwitchPainter extends CustomPainter {
  _SquishSwitchPainter({
    required this.position,
    required this.press,
    required this.trackSize,
    required this.margin,
    required this.activeColor,
    required this.inactiveColor,
    required this.outlineColor,
    required this.offThumbColor,
    required this.onThumbColor,
    required this.focusColor,
    required this.focused,
    required this.rtl,
    required this.stretch,
  }) : super(repaint: Listenable.merge(<Listenable>[position, press]));

  final AnimationController position;
  final Animation<double> press;
  final Size trackSize;
  final double margin;
  final Color activeColor;
  final Color inactiveColor;
  final Color outlineColor;
  final Color offThumbColor;
  final Color onThumbColor;
  final Color focusColor;
  final bool focused;
  final bool rtl;
  final double stretch;

  /// Gap between the thumb and the track edge, as a fraction of height.
  static const double _thumbInsetFactor = 0.125;

  /// How strongly speed turns into horizontal stretch (per pixel/second).
  static const double _stretchPerSpeed = 1.0 / 1100.0;

  /// Upper bound on stretch, as a fraction of the thumb size.
  static const double _maxStretch = 0.45;

  /// How strongly overshoot past the wall turns into compression.
  static const double _squashGain = 1.4;

  /// Upper bound on compression, as a fraction of the thumb size.
  static const double _maxSquash = 0.28;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect track = Offset(margin, margin) & trackSize;
    final double trackRadius = trackSize.height / 2;
    final RRect trackRRect = RRect.fromRectAndRadius(
      track,
      Radius.circular(trackRadius),
    );
    final double raw = position.value;
    final double t = raw.clamp(0.0, 1.0);

    // Track: crossfading fill plus an outline that fades out when on.
    _paint
      ..style = PaintingStyle.fill
      ..color = Color.lerp(inactiveColor, activeColor, t)!;
    canvas.drawRRect(trackRRect, _paint);
    if (t < 1.0) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = outlineColor.withValues(alpha: outlineColor.a * (1.0 - t));
      canvas.drawRRect(trackRRect.deflate(1.0), _paint);
    }

    // Thumb geometry.
    final double inset = trackSize.height * _thumbInsetFactor;
    final double base =
        (trackSize.height - inset * 2) * (1.0 + 0.08 * press.value);
    final double travel = trackSize.width - trackSize.height;
    final double startCenter = track.left + trackSize.height / 2;
    final double endCenter = track.right - trackSize.height / 2;
    final double visual = rtl ? 1.0 - t : t;
    final double center = startCenter + visual * travel;

    final double speed = position.velocity.abs() * travel;
    final double stretchFactor = math.min(
      _maxStretch * stretch,
      stretch * speed * _stretchPerSpeed,
    );
    final double over = raw > 1.0 ? raw - 1.0 : (raw < 0.0 ? -raw : 0.0);
    final double squash = math.min(
      _maxSquash,
      stretch * over * travel * _squashGain / base,
    );
    final double widthScale = (1.0 + stretchFactor) * (1.0 - squash);
    final double width = base * widthScale;
    // Never let a squashed thumb touch the track edge.
    final double height = math.min(base / widthScale, trackSize.height - inset);

    final double lo = startCenter - base / 2;
    final double hi = endCenter + base / 2;
    double left;
    if (over > 0.0) {
      // Pinned flat against the wall it overshot into.
      final bool againstRight = (raw > 1.0) != rtl;
      left = againstRight ? hi - width : lo;
    } else {
      left = center - width / 2;
      left = left.clamp(lo, math.max(lo, hi - width));
    }
    final Rect thumb = Rect.fromLTWH(
      left,
      track.center.dy - height / 2,
      width,
      height,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = Color.lerp(offThumbColor, onThumbColor, t)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        thumb,
        Radius.circular(math.min(width, height) / 2),
      ),
      _paint,
    );

    if (focused) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = focusColor;
      canvas.drawRRect(trackRRect.inflate(margin - 1.0), _paint);
    }
  }

  @override
  bool shouldRepaint(_SquishSwitchPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.press != press ||
        oldDelegate.trackSize != trackSize ||
        oldDelegate.margin != margin ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.offThumbColor != offThumbColor ||
        oldDelegate.onThumbColor != onThumbColor ||
        oldDelegate.focusColor != focusColor ||
        oldDelegate.focused != focused ||
        oldDelegate.rtl != rtl ||
        oldDelegate.stretch != stretch;
  }
}
