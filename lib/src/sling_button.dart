import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A round send button you pull back like a slingshot and release to
/// fire.
///
/// ```dart
/// SlingButton(
///   onFired: () => controller.sendMessage(),
///   child: const Icon(Icons.send_rounded),
/// )
/// ```
///
/// Drag the button away from its resting place in any direction (or only
/// along [axis]). Two elastic bands stretch from anchor points at the
/// resting place to the button; they get thicker and change to
/// [bandColor] as the tension grows, and the button squashes and tilts
/// slightly. The pull meets more resistance the further it goes and never
/// exceeds [maxPull] pixels.
///
/// Releasing past [threshold] (a fraction of [maxPull]) fires: [onFired]
/// is called immediately, the child (typically the icon) launches in the
/// opposite direction along a short arc and fades out, the button springs
/// back to its place, and the child pops back in. Releasing before the
/// threshold springs back without firing.
///
/// A simple tap also fires when [fireOnTap] is true (the default), with a
/// small recoil and a short launch toward the end side (right in
/// left-to-right layouts), so the widget works as a regular send button.
///
/// The stretch and the flight are painted outside the widget's own
/// bounds: give it about [maxPull] pixels of free space around it and
/// avoid clipping ancestors. Inside a scrollable, drags along the scroll
/// axis are usually won by the scrollable; constrain the pull with [axis]
/// in that case.
///
/// With [enableHaptics], pulling plays ticks that get stronger as the
/// tension rises (a light impact when crossing the threshold) and firing
/// plays a heavy impact.
///
/// Accessibility: the widget is a button labeled [semanticLabel], at least
/// 48 by 48 pixels. Activating it from assistive technology or with Enter
/// or Space when focused fires it, and keyboard focus shows a ring.
///
/// When [enabled] is false the button is dimmed and ignores input. Under
/// reduced motion the button still follows the finger while pulling, but
/// releasing or tapping returns it to its place instantly with no flight;
/// [onFired] works the same way.
class SlingButton extends StatefulWidget {
  /// Creates a sling button.
  const SlingButton({
    super.key,
    required this.child,
    required this.onFired,
    this.maxPull = 80.0,
    this.threshold = 0.5,
    this.axis,
    this.fireOnTap = true,
    this.size = 56.0,
    this.backgroundColor,
    this.foregroundColor,
    this.bandColor,
    this.duration = const Duration(milliseconds: 750),
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel = 'Send',
  }) : assert(maxPull > 0.0, 'maxPull must be positive'),
       assert(
         threshold > 0.0 && threshold <= 1.0,
         'threshold must be greater than 0 and at most 1',
       ),
       assert(size > 0.0, 'size must be positive');

  /// The content of the button, typically an [Icon]. It is the part that
  /// launches when the button fires.
  final Widget child;

  /// Called when the button fires: on release past [threshold], on tap
  /// when [fireOnTap] is true, and on keyboard or assistive activation.
  final VoidCallback onFired;

  /// The longest distance in logical pixels the button can be pulled.
  /// Defaults to 80.
  final double maxPull;

  /// Fraction of [maxPull] the pull must reach for a release to fire.
  /// Defaults to 0.5.
  final double threshold;

  /// When set, the pull is constrained to this axis. When null (the
  /// default) the button can be pulled in any direction.
  final Axis? axis;

  /// Whether a simple tap fires the button. Defaults to true.
  final bool fireOnTap;

  /// Diameter of the round button. Defaults to 56. The touch target is
  /// never smaller than 48 by 48 pixels.
  final double size;

  /// Background color of the button. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? backgroundColor;

  /// Icon and text color of the child. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? foregroundColor;

  /// Color of the elastic bands once the pull reaches the threshold.
  /// Defaults to [backgroundColor]. Below the threshold the bands use the
  /// theme's `colorScheme.outline`.
  final Color? bandColor;

  /// Length of the launch and spring back animation. Defaults to 750
  /// milliseconds.
  final Duration duration;

  /// Whether haptic feedback is played while pulling and when firing.
  /// Defaults to true.
  final bool enableHaptics;

  /// When false the button renders dimmed and ignores input.
  final bool enabled;

  /// Label announced by assistive technology. Defaults to `'Send'`.
  final String semanticLabel;

  @override
  State<SlingButton> createState() => _SlingButtonState();
}

class _SlingButtonState extends State<SlingButton>
    with SingleTickerProviderStateMixin {
  /// Drives the launch and the spring back after a release or a tap.
  late final AnimationController _flight;

  /// The resisted pull offset while dragging, relative to the resting
  /// place.
  final ValueNotifier<Offset> _pull = ValueNotifier<Offset>(Offset.zero);

  /// The raw drag offset before resistance.
  Offset _raw = Offset.zero;
  bool _dragging = false;
  bool _focused = false;
  bool _reducedMotion = false;

  /// Number of haptic steps passed during the current pull.
  int _hapticLevel = 0;

  /// Disk offset at the start of the current flight.
  Offset _flightFrom = Offset.zero;

  /// Unit direction the child flies in during the current flight.
  Offset _flightDirection = Offset.zero;

  /// Flight distance factor: 0 for a plain spring back, up to 1 for a
  /// full launch.
  double _flightPower = 0.0;

  /// Pull fractions at which haptic ticks play, before the threshold is
  /// merged in.
  static const List<double> _tickSteps = <double>[0.25, 0.75, 0.95];

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _flight.stop();
      _flight.value = 0.0;
      _flightPower = 0.0;
      _flightFrom = Offset.zero;
    }
  }

  @override
  void didUpdateWidget(SlingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _flight.duration = widget.duration;
    }
    if (!widget.enabled && oldWidget.enabled) {
      _dragging = false;
      _raw = Offset.zero;
      _pull.value = Offset.zero;
    } else if (widget.axis != oldWidget.axis ||
        widget.maxPull != oldWidget.maxPull) {
      _pull.value = _resist(_raw);
    }
  }

  @override
  void dispose() {
    _flight.dispose();
    _pull.dispose();
    super.dispose();
  }

  /// Constrains [raw] to [SlingButton.axis] and applies the elastic
  /// resistance, so the result never exceeds [SlingButton.maxPull].
  Offset _resist(Offset raw) {
    final Axis? axis = widget.axis;
    final Offset constrained = switch (axis) {
      Axis.horizontal => Offset(raw.dx, 0.0),
      Axis.vertical => Offset(0.0, raw.dy),
      null => raw,
    };
    final double distance = constrained.distance;
    if (distance == 0.0) return Offset.zero;
    final double max = widget.maxPull;
    final double resisted = max * (1.0 - math.exp(-distance / max));
    return constrained * (resisted / distance);
  }

  double get _ratio => (_pull.value.distance / widget.maxPull).clamp(0.0, 1.0);

  List<double> get _steps {
    final List<double> steps = <double>{
      ..._tickSteps,
      widget.threshold,
    }.toList()..sort();
    return steps;
  }

  void _playTick(double step) {
    if (!widget.enableHaptics) return;
    if (step < widget.threshold) {
      HapticFeedback.selectionClick();
    } else if (step == widget.threshold) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _flight.stop();
    _flight.value = 0.0;
    _flightPower = 0.0;
    _flightFrom = Offset.zero;
    _raw = Offset.zero;
    _hapticLevel = 0;
    _pull.value = Offset.zero;
    setState(() => _dragging = true);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _raw += details.delta;
    _pull.value = _resist(_raw);
    final double ratio = _ratio;
    final List<double> steps = _steps;
    int level = 0;
    while (level < steps.length && ratio >= steps[level]) {
      level++;
    }
    if (level > _hapticLevel) {
      _playTick(steps[level - 1]);
    }
    _hapticLevel = level;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_dragging) return;
    final Offset pull = _pull.value;
    final bool tap = _raw.distance < kTouchSlop;
    _dragging = false;
    _raw = Offset.zero;
    _pull.value = Offset.zero;
    if (tap) {
      if (widget.fireOnTap) {
        _fireFromTap();
      } else {
        _release(pull, fire: false);
      }
    } else {
      _release(pull, fire: pull.distance >= widget.threshold * widget.maxPull);
    }
    setState(() {});
  }

  void _handlePanCancel() {
    if (!_dragging) return;
    final Offset pull = _pull.value;
    _dragging = false;
    _raw = Offset.zero;
    _pull.value = Offset.zero;
    _release(pull, fire: false);
    setState(() {});
  }

  /// Fires from a tap, a keyboard activation or an accessibility action.
  void _fireFromTap() {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Offset direction = Offset(rtl ? -1.0 : 1.0, -0.25);
    final Offset unit = direction / direction.distance;
    _fire();
    _startFlight(from: -unit * 6.0, direction: unit, power: 0.55);
  }

  void _fire() {
    if (widget.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    widget.onFired();
  }

  /// Ends a pull at [pull], firing when [fire] is true.
  void _release(Offset pull, {required bool fire}) {
    if (fire) {
      _fire();
      _startFlight(
        from: pull,
        direction: -pull / pull.distance,
        power: 0.5 + 0.5 * (pull.distance / widget.maxPull).clamp(0.0, 1.0),
      );
    } else {
      _startFlight(from: pull, direction: Offset.zero, power: 0.0);
    }
  }

  void _startFlight({
    required Offset from,
    required Offset direction,
    required double power,
  }) {
    if (!mounted) return;
    if (_reducedMotion) {
      _flight.value = 0.0;
      _flightFrom = Offset.zero;
      _flightPower = 0.0;
      return;
    }
    _flightFrom = from;
    _flightDirection = direction;
    _flightPower = power;
    _flight.forward(from: 0.0);
  }

  void _activate() {
    if (!widget.enabled) return;
    _fireFromTap();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = widget.backgroundColor ?? scheme.primary;
    final Color foreground = widget.foregroundColor ?? scheme.onPrimary;
    final Color bandColor = widget.bandColor ?? background;
    final bool enabled = widget.enabled;
    final double box = math.max(widget.size, 48.0);
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    final Widget disk = DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: CircleBorder(
          side: _focused
              ? BorderSide(color: scheme.primary, width: 2.0, strokeAlign: 3.0)
              : BorderSide.none,
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 8.0,
            offset: const Offset(0.0, 3.0),
          ),
        ],
      ),
      child: SizedBox.square(dimension: widget.size),
    );

    final Widget icon = ExcludeSemantics(child: widget.child);

    final Listenable motion = Listenable.merge(<Listenable>[_flight, _pull]);

    Widget content = SizedBox.square(
      dimension: box,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BandPainter(
                  pull: _pull,
                  maxPull: widget.maxPull,
                  threshold: widget.threshold,
                  buttonSize: widget.size,
                  slackColor: scheme.outline,
                  tenseColor: bandColor,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: motion,
            builder: (BuildContext context, Widget? child) {
              final _SlingFrame frame = _frame(rtl);
              return Transform.translate(
                offset: frame.diskOffset,
                child: Transform.rotate(
                  angle: frame.rotation,
                  child: Transform.scale(
                    scaleX: frame.scaleX,
                    scaleY: frame.scaleY,
                    child: child,
                  ),
                ),
              );
            },
            child: disk,
          ),
          AnimatedBuilder(
            animation: motion,
            builder: (BuildContext context, Widget? child) {
              final _SlingFrame frame = _frame(rtl);
              // Once the child leaves the button it takes the button color
              // so it stays visible against the surface.
              final Color color = Color.lerp(
                foreground,
                background,
                frame.iconTint,
              )!;
              return Transform.translate(
                offset: frame.diskOffset + frame.iconOffset,
                child: Transform.rotate(
                  angle: frame.rotation,
                  child: Transform.scale(
                    scale: frame.iconScale,
                    child: Opacity(
                      opacity: frame.iconOpacity,
                      child: IconTheme.merge(
                        data: IconThemeData(
                          color: color,
                          size: widget.size * 0.42,
                        ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: color),
                          child: child!,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: icon,
          ),
        ],
      ),
    );

    content = Opacity(opacity: enabled ? 1.0 : 0.5, child: content);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.grab : MouseCursor.defer,
        onShowFocusHighlight: (bool focused) {
          if (focused != _focused) {
            setState(() => _focused = focused);
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          // Semantics are provided above; the pan recognizer would
          // otherwise expose scroll actions on the button.
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.start,
          onPanStart: enabled ? _handlePanStart : null,
          onPanUpdate: enabled ? _handlePanUpdate : null,
          onPanEnd: enabled ? _handlePanEnd : null,
          onPanCancel: enabled ? _handlePanCancel : null,
          child: content,
        ),
      ),
    );
  }

  /// Computes the transforms of the button and its child for the current
  /// drag or flight.
  _SlingFrame _frame(bool rtl) {
    if (_dragging) {
      final Offset pull = _pull.value;
      final double ratio = _ratio;
      double rotation = 0.0;
      if (pull.distance > 0.0) {
        final Offset aim = -pull / pull.distance;
        // Tilt the front of the button toward the firing direction.
        rotation = 0.35 * ratio * aim.dy * (rtl ? -1.0 : 1.0);
      }
      return _SlingFrame(
        diskOffset: pull,
        rotation: rotation,
        scaleX: 1.0 - 0.08 * ratio,
        scaleY: 1.0 - 0.08 * ratio,
      );
    }
    final double t = _flight.value;
    if (!_flight.isAnimating || t == 0.0) {
      return const _SlingFrame();
    }

    // The button springs back past its place and settles.
    final double spring = math.exp(-6.0 * t) * math.cos(2.4 * math.pi * t);
    final Offset diskOffset = _flightFrom * spring;
    // A brief squash along the motion right after the release.
    final double squash = 0.07 * math.exp(-8.0 * t) * math.sin(math.pi * t * 3);

    if (_flightPower == 0.0) {
      return _SlingFrame(
        diskOffset: diskOffset,
        scaleX: 1.0 + squash,
        scaleY: 1.0 - squash,
      );
    }

    final double distance = widget.maxPull * 2.0 * _flightPower;
    final Offset direction = _flightDirection;
    // Arc perpendicular to the flight, bending upward on screen.
    Offset normal = Offset(-direction.dy, direction.dx);
    if (normal.dy > 0.0 || (normal.dy == 0.0 && normal.dx < 0.0)) {
      normal = -normal;
    }
    Offset iconOffset;
    double iconScale;
    double iconOpacity;
    double iconTint = 0.0;
    if (t < 0.5) {
      final double f = Curves.easeOutCubic.transform(t / 0.5);
      iconTint = (f * 3.0).clamp(0.0, 1.0);
      iconOffset =
          direction * distance * f +
          normal * (distance * 0.22 * math.sin(math.pi * f)) -
          diskOffset;
      iconScale = 1.0 - 0.35 * f;
      iconOpacity =
          1.0 - Curves.easeIn.transform(((t - 0.2) / 0.3).clamp(0, 1));
    } else {
      final double r = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      iconOffset = Offset.zero;
      iconScale = Curves.easeOutBack.transform(r);
      iconOpacity = (r * 2.5).clamp(0.0, 1.0);
    }
    return _SlingFrame(
      diskOffset: diskOffset,
      scaleX: 1.0 + squash,
      scaleY: 1.0 - squash,
      iconOffset: iconOffset,
      iconScale: iconScale,
      iconOpacity: iconOpacity,
      iconTint: iconTint,
    );
  }
}

/// The transforms of a [SlingButton] at one moment.
class _SlingFrame {
  const _SlingFrame({
    this.diskOffset = Offset.zero,
    this.rotation = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.iconOffset = Offset.zero,
    this.iconScale = 1.0,
    this.iconOpacity = 1.0,
    this.iconTint = 0.0,
  });

  final Offset diskOffset;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final Offset iconOffset;
  final double iconScale;
  final double iconOpacity;

  /// How far the child color has moved from the foreground color toward
  /// the button color, from 0 to 1.
  final double iconTint;
}

/// Paints the two elastic bands and their anchor points while pulling.
class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.pull,
    required this.maxPull,
    required this.threshold,
    required this.buttonSize,
    required this.slackColor,
    required this.tenseColor,
  }) : super(repaint: pull);

  final ValueNotifier<Offset> pull;
  final double maxPull;
  final double threshold;
  final double buttonSize;
  final Color slackColor;
  final Color tenseColor;

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset offset = pull.value;
    final double distance = offset.distance;
    if (distance < 0.5) return;
    final double ratio = (distance / maxPull).clamp(0.0, 1.0);
    final double armed = (ratio / threshold).clamp(0.0, 1.0);
    final Offset unit = offset / distance;
    final Offset normal = Offset(-unit.dy, unit.dx);
    final Offset rest = size.center(Offset.zero);
    final Offset button = rest + offset;
    final double half = buttonSize / 2.0;
    // Fade in over the first pixels so the direction never flickers.
    final double visibility = (distance / 10.0).clamp(0.0, 1.0);
    final Color base = ratio >= threshold
        ? tenseColor
        : Color.lerp(slackColor, tenseColor, armed * 0.6)!;
    final Color color = base.withValues(alpha: base.a * visibility);
    final double width = 1.5 + 2.5 * ratio;
    final double sag = (1.0 - ratio) * 10.0;

    // A faint ring marks the resting place the bands are anchored to.
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = slackColor.withValues(alpha: slackColor.a * 0.35 * visibility);
    canvas.drawCircle(rest, half - 0.75, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final double side in const <double>[-1.0, 1.0]) {
      final Offset anchor = rest + normal * (side * (half + 6.0));
      final Offset contact =
          button + normal * (side * half * 0.62) + unit * (half * 0.55);
      final Offset mid = Offset.lerp(anchor, contact, 0.5)!;
      final Offset control = mid + unit * sag;
      final Path band = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..quadraticBezierTo(control.dx, control.dy, contact.dx, contact.dy);
      canvas.drawPath(band, _paint);
    }
    // The pouch wraps around the far side of the button.
    final Offset pouchStart =
        button + normal * (-half * 0.62) + unit * (half * 0.55);
    final Offset pouchEnd =
        button + normal * (half * 0.62) + unit * (half * 0.55);
    final Offset pouchControl = button + unit * (half * 1.55);
    canvas.drawPath(
      Path()
        ..moveTo(pouchStart.dx, pouchStart.dy)
        ..quadraticBezierTo(
          pouchControl.dx,
          pouchControl.dy,
          pouchEnd.dx,
          pouchEnd.dy,
        ),
      _paint,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
    for (final double side in const <double>[-1.0, 1.0]) {
      canvas.drawCircle(
        rest + normal * (side * (half + 6.0)),
        2.0 + width * 0.5,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) =>
      oldDelegate.pull != pull ||
      oldDelegate.maxPull != maxPull ||
      oldDelegate.threshold != threshold ||
      oldDelegate.buttonSize != buttonSize ||
      oldDelegate.slackColor != slackColor ||
      oldDelegate.tenseColor != tenseColor;
}
