import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Builds the content shown in the middle of a [CometDial].
typedef CometDialCenterBuilder =
    Widget Function(BuildContext context, double value);

/// A circular dial with a ring of tick marks that you turn by angle and
/// can flick so it keeps spinning.
///
/// ```dart
/// CometDial(
///   value: temperature,
///   onChanged: (double v) => setState(() => temperature = v),
/// )
/// ```
///
/// Drag around the dial to turn it: the value follows the angle you sweep
/// around the center, not the straight-line distance, so it works like a
/// physical knob. Releasing with speed keeps the dial turning and slowing
/// down under friction. The lit head marks the value and drags a comet
/// streak behind it, a fading arc that grows longer the faster the dial
/// moves; ticks before the head are lit. The range covers [sweepAngle]
/// starting at [startAngle], leaving a gap (at the bottom by default)
/// that the value never wraps across. With [divisions] the value snaps to
/// evenly spaced stops.
///
/// The dial is controlled: it always shows [value] and reports new values
/// through [onChanged]. When [onChanged] is null or [enabled] is false it
/// renders dimmed and ignores input.
///
/// Accessibility: exposed as a slider with its formatted value and the
/// values it would take when increased or decreased; screen readers can
/// adjust it with their increase and decrease gestures. When focused the
/// arrow keys step the value, Page Up and Page Down take larger steps and
/// Home and End jump to [min] and [max]. The center content is decorative
/// for assistive technology because the value is already announced.
///
/// Reduced motion: the head moves directly to the new value, there is no
/// comet streak and flicks stop where the finger leaves.
class CometDial extends StatefulWidget {
  /// Creates a comet dial.
  const CometDial({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 100.0,
    this.divisions,
    this.ticks = 60,
    this.size = 200,
    this.sweepAngle = 300 * math.pi / 180,
    this.startAngle,
    this.activeColor,
    this.inactiveColor,
    this.cometColor,
    this.centerBuilder,
    this.friction = 0.03,
    this.enabled = true,
    this.enableHaptics = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.semanticFormatterCallback,
  }) : assert(min < max, 'min must be less than max'),
       assert(
         value >= min && value <= max,
         'value must be between min and max',
       ),
       assert(
         divisions == null || divisions > 0,
         'divisions must be null or positive',
       ),
       assert(ticks >= 2, 'ticks must be at least 2'),
       assert(size > 0, 'size must be positive'),
       assert(
         sweepAngle > 0 && sweepAngle <= 2 * math.pi,
         'sweepAngle must be in (0, 2 * pi]',
       ),
       assert(
         friction > 0 && friction < 1,
         'friction must be between 0 and 1 (exclusive)',
       );

  /// The current value. Must be between [min] and [max].
  final double value;

  /// Called with the new value while the user turns the dial, while it
  /// coasts after a flick, and on keyboard or assistive technology
  /// changes. When null the dial renders disabled.
  final ValueChanged<double>? onChanged;

  /// Called with the current value when the user starts turning the dial.
  final ValueChanged<double>? onChangeStart;

  /// Called with the final value once the dial comes to rest, after any
  /// flick has finished coasting.
  final ValueChanged<double>? onChangeEnd;

  /// The smallest selectable value. Defaults to 0.
  final double min;

  /// The largest selectable value. Defaults to 100.
  final double max;

  /// Number of discrete intervals between [min] and [max]. When null the
  /// dial is continuous.
  final int? divisions;

  /// Number of tick marks around the ring. Defaults to 60.
  final int ticks;

  /// Width and height of the dial. Defaults to 200.
  final double size;

  /// Angle covered by the range, in radians. Defaults to 300 degrees,
  /// which leaves a 60 degree gap.
  final double sweepAngle;

  /// Angle where [min] sits, in radians, measured clockwise from the
  /// positive x axis (3 o'clock). When null the gap is centered at the
  /// bottom of the dial.
  final double? startAngle;

  /// Color of the lit ticks and the head. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? activeColor;

  /// Color of the unlit ticks and the track. Defaults to the theme's
  /// `colorScheme.onSurface` at 16 percent alpha.
  final Color? inactiveColor;

  /// Color of the comet streak. Defaults to [activeColor].
  final Color? cometColor;

  /// Builds the content in the middle of the dial. Defaults to the value
  /// formatted by [semanticFormatterCallback], or rounded to a whole
  /// number, in the theme's `headlineMedium` style.
  final CometDialCenterBuilder? centerBuilder;

  /// Friction applied to a flick, as the fraction of speed left after one
  /// second. Smaller values stop the dial sooner. Defaults to 0.03.
  final double friction;

  /// When false the dial renders dimmed and ignores input, exactly as if
  /// [onChanged] were null.
  final bool enabled;

  /// Whether a selection haptic tick plays each time the value moves to
  /// another division. Only used with [divisions]. Defaults to false.
  final bool enableHaptics;

  /// Optional focus node for keyboard control.
  final FocusNode? focusNode;

  /// Whether the dial requests focus when first built. Defaults to false.
  final bool autofocus;

  /// Optional semantic label announced for the dial.
  final String? semanticLabel;

  /// Formats a value for display in the center and for assistive
  /// technology. Defaults to the value rounded to a whole number.
  final String Function(double value)? semanticFormatterCallback;

  @override
  State<CometDial> createState() => _CometDialState();
}

/// Mutable animation state shared by the dial and its painter.
class _CometField extends ChangeNotifier {
  /// Displayed head position as a fraction of the range.
  double position = 0.0;

  /// Length of the comet streak as a fraction of the sweep.
  double trail = 0.0;

  /// Direction of travel: 1 for increasing values, -1 for decreasing.
  double direction = 1.0;

  void notify() => notifyListeners();
}

class _CometStepIntent extends Intent {
  const _CometStepIntent(this.steps);

  final int steps;
}

class _CometEdgeIntent extends Intent {
  const _CometEdgeIntent({required this.toMax});

  final bool toMax;
}

class _CometDialState extends State<CometDial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _CometField _field = _CometField();
  Duration _lastTick = Duration.zero;

  /// Target head position, a fraction of the range.
  double _target = 0.0;

  /// Velocity of the displayed head, in fractions per second.
  double _velocity = 0.0;

  /// Unsnapped dial position while dragging or coasting.
  double _rawFraction = 0.0;

  /// Pointer angle at the previous drag update.
  double _lastAngle = 0.0;
  bool _dragging = false;

  /// Whether the head tracks the finger or flick exactly.
  bool _attached = false;

  /// Remaining distance between the display and the finger while attached.
  double _catchUp = 0.0;

  FrictionSimulation? _flick;
  Duration _flickStart = Duration.zero;

  bool _reducedMotion = false;
  bool _focusHighlight = false;

  static const double _followStiffness = 900.0;
  static const double _glideStiffness = 200.0;

  /// Longest comet streak, as a fraction of the sweep.
  static const double _maxTrail = 0.42;

  /// Streak length gained per unit of speed (fractions per second).
  static const double _trailPerSpeed = 0.14;

  /// Slowest flick, in fractions per second, that still coasts.
  static const double _minFlickSpeed = 0.15;

  /// Fastest flick, in fractions per second.
  static const double _maxFlickSpeed = 4.0;

  static const double _disabledOpacity = 0.45;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  double get _range => widget.max - widget.min;

  double get _startAngle =>
      widget.startAngle ?? math.pi / 2 + (2 * math.pi - widget.sweepAngle) / 2;

  double _fractionOf(double value) =>
      ((value - widget.min) / _range).clamp(0.0, 1.0).toDouble();

  double _snap(double value) {
    final double clamped = value.clamp(widget.min, widget.max).toDouble();
    final int? divisions = widget.divisions;
    if (divisions == null) return clamped;
    final double unit = _range / divisions;
    return widget.min + ((clamped - widget.min) / unit).round() * unit;
  }

  @override
  void initState() {
    super.initState();
    _target = _fractionOf(widget.value);
    _field.position = _target;
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      // Never call back into the parent from here: this runs during build.
      _flick = null;
      _settleNow();
    }
  }

  @override
  void didUpdateWidget(CometDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.min != oldWidget.min ||
        widget.max != oldWidget.max) {
      _setTarget(_fractionOf(widget.value));
    }
    if (!_interactive) {
      _dragging = false;
      _focusHighlight = false;
      _flick = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _field.dispose();
    super.dispose();
  }

  void _setTarget(double fraction) {
    _target = fraction;
    if (_reducedMotion) {
      _settleNow();
    } else {
      _ensureTicking();
    }
  }

  void _ensureTicking() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _settleNow() {
    if (_ticker.isActive) _ticker.stop();
    _field.position = _target;
    _field.trail = 0.0;
    _velocity = 0.0;
    _field.notify();
  }

  void _onTick(Duration elapsed) {
    final FrictionSimulation? flick = _flick;
    if (flick != null) {
      final double t = (elapsed - _flickStart).inMicroseconds / 1e6;
      final double x = flick.x(t);
      final bool hitEdge = x <= 0.0 || x >= 1.0;
      _rawFraction = x.clamp(0.0, 1.0).toDouble();
      _emit(widget.min + _rawFraction * _range);
      if (hitEdge || flick.isDone(t)) {
        _endFlick(notify: true);
      }
    }

    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Long frames (hitches, or big test pumps) advance the full time; the
    // sub steps below keep the integration stable.
    dt = math.min(dt, 0.5);

    final bool following = _dragging || _flick != null;
    final double stiffness = following ? _followStiffness : _glideStiffness;
    final double damping = 2 * math.sqrt(stiffness) * (following ? 1.0 : 0.82);
    final int subSteps = (dt / (1 / 240)).ceil();
    final double h = dt / subSteps;
    double position = _field.position;
    if (following && widget.divisions == null) {
      // Continuous values under the finger are tracked exactly; any gap
      // left by the first touch closes quickly instead of jumping.
      if (!_attached) {
        _attached = true;
        _catchUp = position - _target;
      }
      _catchUp *= math.exp(-dt * 22);
      final double next = _target + _catchUp;
      _velocity = (next - position) / dt;
      position = next;
    } else {
      for (int s = 0; s < subSteps; s++) {
        final double accel =
            -stiffness * (position - _target) - damping * _velocity;
        _velocity += accel * h;
        position += _velocity * h;
      }
    }
    _field.position = position;

    // The comet stretches quickly with speed and shrinks a little slower.
    final double speed = _velocity.abs();
    if (speed > 0.02) _field.direction = _velocity.sign;
    final double trailTarget = math.min(_maxTrail, speed * _trailPerSpeed);
    final double rate = trailTarget > _field.trail ? 30.0 : 7.0;
    _field.trail += (trailTarget - _field.trail) * (1 - math.exp(-dt * rate));

    final bool atRest =
        !following &&
        (position - _target).abs() < 1e-4 &&
        _velocity.abs() < 1e-3 &&
        _field.trail < 1e-3;
    if (atRest) {
      _settleNow();
      return;
    }
    _field.notify();
  }

  // Value changes ------------------------------------------------------

  void _emit(double value) {
    final double snapped = _snap(value);
    if (snapped == widget.value) return;
    if (widget.enableHaptics && widget.divisions != null) {
      HapticFeedback.selectionClick();
    }
    widget.onChanged?.call(snapped);
  }

  void _adjust(double value) {
    if (!_interactive) return;
    _endFlick(notify: true);
    final double snapped = _snap(value);
    if (snapped == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    _emit(snapped);
    widget.onChangeEnd?.call(snapped);
  }

  /// Stops exact tracking so the head rests where the motion ended.
  void _detach() {
    if (!_attached) return;
    _attached = false;
    _velocity = 0.0;
  }

  void _endFlick({required bool notify}) {
    if (_flick == null) return;
    _flick = null;
    _detach();
    if (notify && mounted) {
      // The last coasting value may not have been rebuilt into the widget
      // yet, so report what was emitted.
      widget.onChangeEnd?.call(_snap(widget.min + _rawFraction * _range));
    }
  }

  double get _stepSize {
    final int? divisions = widget.divisions;
    return divisions != null ? _range / divisions : _range / 100;
  }

  double _stepped(int steps) =>
      _snap(widget.value + steps * _stepSize).clamp(widget.min, widget.max);

  // Gestures -----------------------------------------------------------

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  void _handlePanStart(DragStartDetails details) {
    if (!_interactive) return;
    final bool wasCoasting = _flick != null;
    _flick = null;
    _dragging = true;
    _attached = false;
    _rawFraction = _fractionOf(widget.value);
    final Offset r = details.localPosition - _center;
    _lastAngle = math.atan2(r.dy, r.dx);
    if (!wasCoasting) widget.onChangeStart?.call(widget.value);
    if (!_reducedMotion) _ensureTicking();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_interactive || !_dragging) return;
    final Offset r = details.localPosition - _center;
    final double angle = math.atan2(r.dy, r.dx);
    double delta = angle - _lastAngle;
    _lastAngle = angle;
    // Near the center the angle is unstable; ignore those moves.
    if (r.distance < widget.size * 0.06) return;
    // Take the short way around so crossing the 180 degree seam is smooth.
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _rawFraction = (_rawFraction + delta / widget.sweepAngle)
        .clamp(0.0, 1.0)
        .toDouble();
    _emit(widget.min + _rawFraction * _range);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final Offset r = details.localPosition - _center;
    final Offset v = details.velocity.pixelsPerSecond;
    final double radiusSq = r.distanceSquared;
    double fractionVelocity = 0.0;
    if (radiusSq > 1.0) {
      // Angular velocity from the tangential part of the release velocity.
      final double omega = (r.dx * v.dy - r.dy * v.dx) / radiusSq;
      fractionVelocity = (omega / widget.sweepAngle)
          .clamp(-_maxFlickSpeed, _maxFlickSpeed)
          .toDouble();
    }
    final bool atEdge =
        (_rawFraction <= 0.0 && fractionVelocity < 0) ||
        (_rawFraction >= 1.0 && fractionVelocity > 0);
    if (_reducedMotion ||
        fractionVelocity.abs() < _minFlickSpeed ||
        atEdge ||
        !_interactive) {
      _detach();
      widget.onChangeEnd?.call(widget.value);
      if (!_reducedMotion) _ensureTicking();
      return;
    }
    _flick = FrictionSimulation(
      widget.friction,
      _rawFraction,
      fractionVelocity,
      tolerance: const Tolerance(distance: 1e-4, velocity: 0.02),
    );
    _flickStart = _ticker.isActive ? _lastTick : Duration.zero;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _handlePanCancel() {
    if (!_dragging) return;
    _dragging = false;
    _detach();
    widget.onChangeEnd?.call(widget.value);
    if (!_reducedMotion) _ensureTicking();
  }

  String _format(double value) {
    final String Function(double)? formatter = widget.semanticFormatterCallback;
    if (formatter != null) return formatter(value);
    return value.round().toString();
  }

  Widget _buildCenter(BuildContext context) {
    final CometDialCenterBuilder? builder = widget.centerBuilder;
    if (builder != null) return builder(context, widget.value);
    final ThemeData theme = Theme.of(context);
    final TextStyle style =
        (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    return Text(_format(widget.value), style: style);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool interactive = _interactive;
    final Color activeColor = widget.activeColor ?? colorScheme.primary;
    final Color inactiveColor =
        widget.inactiveColor ?? colorScheme.onSurface.withValues(alpha: 0.16);
    final Color cometColor = widget.cometColor ?? activeColor;

    Widget dial = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CometPainter(
                  field: _field,
                  ticks: widget.ticks,
                  startAngle: _startAngle,
                  sweepAngle: widget.sweepAngle,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  cometColor: cometColor,
                  focusColor: activeColor.withValues(alpha: 0.45),
                  focused: _focusHighlight,
                ),
              ),
            ),
          ),
          ExcludeSemantics(child: _buildCenter(context)),
        ],
      ),
    );

    if (!interactive) {
      return Semantics(
        slider: true,
        enabled: false,
        label: widget.semanticLabel,
        value: _format(widget.value),
        child: Opacity(opacity: _disabledOpacity, child: dial),
      );
    }

    dial = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,
      child: dial,
    );

    final int pageSteps = widget.divisions != null
        ? math.max(1, (widget.divisions! / 10).round())
        : 10;

    return Semantics(
      slider: true,
      enabled: true,
      label: widget.semanticLabel,
      value: _format(widget.value),
      increasedValue: _format(_stepped(1)),
      decreasedValue: _format(_stepped(-1)),
      onIncrease: () => _adjust(_stepped(1)),
      onDecrease: () => _adjust(_stepped(-1)),
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.grab,
        onShowFocusHighlight: (bool value) {
          if (value != _focusHighlight) {
            setState(() => _focusHighlight = value);
          }
        },
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const _CometStepIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const _CometStepIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const _CometStepIntent(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _CometStepIntent(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): _CometStepIntent(
            pageSteps,
          ),
          const SingleActivator(LogicalKeyboardKey.pageDown): _CometStepIntent(
            -pageSteps,
          ),
          const SingleActivator(LogicalKeyboardKey.home):
              const _CometEdgeIntent(toMax: false),
          const SingleActivator(LogicalKeyboardKey.end): const _CometEdgeIntent(
            toMax: true,
          ),
        },
        actions: <Type, Action<Intent>>{
          _CometStepIntent: CallbackAction<_CometStepIntent>(
            onInvoke: (_CometStepIntent intent) {
              _adjust(_stepped(intent.steps));
              return null;
            },
          ),
          _CometEdgeIntent: CallbackAction<_CometEdgeIntent>(
            onInvoke: (_CometEdgeIntent intent) {
              _adjust(intent.toMax ? widget.max : widget.min);
              return null;
            },
          ),
        },
        child: dial,
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  _CometPainter({
    required this.field,
    required this.ticks,
    required this.startAngle,
    required this.sweepAngle,
    required this.activeColor,
    required this.inactiveColor,
    required this.cometColor,
    required this.focusColor,
    required this.focused,
  }) : super(repaint: field);

  final _CometField field;
  final int ticks;
  final double startAngle;
  final double sweepAngle;
  final Color activeColor;
  final Color inactiveColor;
  final Color cometColor;
  final Color focusColor;
  final bool focused;

  final Paint _tickPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fillPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final Offset center = size.center(Offset.zero);
    final double outer = side / 2 - side * 0.03;
    final double tickLength = math.max(6.0, side * 0.055);
    final double tickInner = outer - tickLength;
    final double trackRadius = tickInner - math.max(6.0, side * 0.06);
    final double trackWidth = math.max(2.0, side * 0.014);
    final double head = field.position.clamp(0.0, 1.0).toDouble();
    final double trail = field.trail;
    final double direction = field.direction;
    final double headAngle = startAngle + head * sweepAngle;

    // Tick ring. Ticks inside the comet glow brighter and reach outwards.
    _tickPaint.strokeWidth = math.max(1.5, side * 0.011);
    for (int i = 0; i < ticks; i++) {
      final double f = i / (ticks - 1);
      final double angle = startAngle + f * sweepAngle;
      final bool lit = f <= head + 1e-6;
      double glow = 0.0;
      if (trail > 1e-3) {
        final double behind = (head - f) * direction;
        if (behind >= 0 && behind <= trail) {
          glow = 1 - behind / trail;
        }
      }
      final double closeness = math.max(
        0.0,
        1 - ((f - head).abs() * (ticks - 1)) / 1.5,
      );
      final Color base = lit
          ? activeColor.withValues(alpha: activeColor.a * 0.72)
          : inactiveColor;
      Color color = Color.lerp(base, cometColor, glow)!;
      color = Color.lerp(color, activeColor, closeness)!;
      _tickPaint.color = color;
      final double extra = tickLength * 0.45 * math.max(glow, closeness);
      final double c = math.cos(angle);
      final double s = math.sin(angle);
      canvas.drawLine(
        center + Offset(c, s) * tickInner,
        center + Offset(c, s) * (outer + extra * 0.4),
        _tickPaint,
      );
    }

    final Rect trackRect = Rect.fromCircle(center: center, radius: trackRadius);

    // Track and the lit part of it.
    _arcPaint
      ..shader = null
      ..strokeWidth = trackWidth
      ..color = inactiveColor;
    canvas.drawArc(trackRect, startAngle, sweepAngle, false, _arcPaint);
    if (head > 0) {
      _arcPaint.color = activeColor.withValues(alpha: activeColor.a * 0.35);
      canvas.drawArc(
        trackRect,
        startAngle,
        head * sweepAngle,
        false,
        _arcPaint,
      );
    }

    // Comet streak: an arc fading from the head back along the path.
    final double trailAngle = trail * sweepAngle;
    if (trailAngle > 0.01) {
      final double tailFraction = (head - trail * direction)
          .clamp(0.0, 1.0)
          .toDouble();
      final double tailAngle = startAngle + tailFraction * sweepAngle;
      final double span = (headAngle - tailAngle).abs();
      if (span > 0.005) {
        final double from = math.min(tailAngle, headAngle);
        final double stop = (span / (2 * math.pi)).clamp(0.0, 1.0).toDouble();
        final bool forward = direction > 0;
        // Transparent everywhere outside the streak, so the blurred glow
        // never picks up color from the gradient's wrap-around seam.
        final double after = math.min(1.0, stop + 0.002);
        final Color clear = cometColor.withValues(alpha: 0);
        final Shader shader = SweepGradient(
          colors: forward
              ? <Color>[clear, cometColor, clear, clear]
              : <Color>[cometColor, clear, clear],
          stops: forward
              ? <double>[0.0, stop, after, 1.0]
              : <double>[0.0, stop, 1.0],
          transform: GradientRotation(from),
        ).createShader(trackRect);
        // Butt caps: a round cap would poke past the transparent tail.
        _arcPaint
          ..strokeCap = StrokeCap.butt
          ..shader = shader
          ..strokeWidth = trackWidth * 5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, trackWidth * 2.2);
        canvas.drawArc(trackRect, from, span, false, _arcPaint);
        _arcPaint
          ..maskFilter = null
          ..strokeWidth = trackWidth * 2.4;
        canvas.drawArc(trackRect, from, span, false, _arcPaint);
        _arcPaint.strokeCap = StrokeCap.round;
        _arcPaint.shader = null;
      }
    }

    // Head: a soft glow, a solid core and a small highlight.
    final Offset headCenter =
        center + Offset(math.cos(headAngle), math.sin(headAngle)) * trackRadius;
    final double headRadius = trackWidth * 2.4;
    final double energy = (trail / 0.42).clamp(0.0, 1.0).toDouble();
    _fillPaint
      ..color = cometColor.withValues(alpha: 0.28 + 0.3 * energy)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, headRadius * 1.2);
    canvas.drawCircle(
      headCenter,
      headRadius * (1.5 + 0.5 * energy),
      _fillPaint,
    );
    _fillPaint
      ..maskFilter = null
      ..color = activeColor;
    canvas.drawCircle(headCenter, headRadius, _fillPaint);
    _fillPaint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(headCenter, headRadius * 0.38, _fillPaint);

    if (focused) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = focusColor;
      canvas.drawCircle(center, side / 2 - 1, ring);
    }
  }

  @override
  bool shouldRepaint(_CometPainter oldDelegate) =>
      oldDelegate.field != field ||
      oldDelegate.ticks != ticks ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.cometColor != cometColor ||
      oldDelegate.focusColor != focusColor ||
      oldDelegate.focused != focused;
}
