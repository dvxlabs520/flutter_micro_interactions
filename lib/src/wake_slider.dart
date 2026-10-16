import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A slider drawn as a row of thin vertical bars, with no thumb.
///
/// ```dart
/// WakeSlider(
///   value: volume,
///   onChanged: (double v) => setState(() => volume = v),
/// )
/// ```
///
/// Bars before the value are filled with [activeColor]; the position of
/// the value is marked by the tallest bar, with its neighbours tapering
/// down. Dragging quickly raises a "wake": bars behind the handle rise in
/// proportion to the drag speed and then settle back with a damped
/// spring, like the water behind a boat. Tapping the track jumps to that
/// point, and the jump itself leaves a wake. With [divisions] the value
/// snaps to evenly spaced stops and the handle glides between them.
///
/// The slider is controlled: it always shows [value] and reports new
/// values through [onChanged]. When [onChanged] is null or [enabled] is
/// false it renders dimmed and ignores input.
///
/// Accessibility: exposed as a slider with its formatted value and the
/// values it would take when increased or decreased; screen readers can
/// adjust it with their increase and decrease gestures. When focused the
/// arrow keys step the value (left and right follow the reading
/// direction), Page Up and Page Down take larger steps, and Home and End
/// jump to [min] and [max].
///
/// Reduced motion: the handle moves directly to the new value and no wake
/// is raised. Callbacks keep working as usual.
class WakeSlider extends StatefulWidget {
  /// Creates a wake slider.
  const WakeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.bars = 32,
    this.height = 40,
    this.barWidth,
    this.gap = 3,
    this.activeColor,
    this.inactiveColor,
    this.wakeStrength = 1.0,
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
       assert(bars >= 2, 'bars must be at least 2'),
       assert(height > 0, 'height must be positive'),
       assert(barWidth == null || barWidth > 0, 'barWidth must be positive'),
       assert(gap >= 0, 'gap must not be negative'),
       assert(wakeStrength >= 0, 'wakeStrength must not be negative');

  /// The current value. Must be between [min] and [max].
  final double value;

  /// Called with the new value while the user drags, taps, uses the
  /// keyboard or an assistive technology. When null the slider renders
  /// disabled.
  final ValueChanged<double>? onChanged;

  /// Called with the current value when the user starts changing it.
  final ValueChanged<double>? onChangeStart;

  /// Called with the final value when the user stops changing it.
  final ValueChanged<double>? onChangeEnd;

  /// The smallest selectable value. Defaults to 0.
  final double min;

  /// The largest selectable value. Defaults to 1.
  final double max;

  /// Number of discrete intervals between [min] and [max]. When null the
  /// slider is continuous.
  final int? divisions;

  /// Number of bars in the track. Defaults to 32.
  final int bars;

  /// Height of the track; the tallest bar is this tall. Defaults to 40.
  final double height;

  /// Width of each bar. When null the bars share the available width;
  /// when set, the slider takes exactly the width the bars need.
  final double? barWidth;

  /// Horizontal gap between two bars. Defaults to 3.
  final double gap;

  /// Color of the bars before the value. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? activeColor;

  /// Color of the bars after the value. Defaults to the theme's
  /// `colorScheme.onSurface` at 18 percent alpha.
  final Color? inactiveColor;

  /// Multiplier for the wake height. 0 disables the wake. Defaults to 1.
  final double wakeStrength;

  /// When false the slider renders dimmed and ignores input, exactly as
  /// if [onChanged] were null.
  final bool enabled;

  /// Whether a selection haptic tick plays each time the value moves to
  /// another division. Only used with [divisions]. Defaults to false.
  final bool enableHaptics;

  /// Optional focus node for keyboard control.
  final FocusNode? focusNode;

  /// Whether the slider requests focus when first built. Defaults to false.
  final bool autofocus;

  /// Optional semantic label announced for the slider.
  final String? semanticLabel;

  /// Formats a value for assistive technology. Defaults to the position
  /// as a whole percentage of the range, for example `40%`.
  final String Function(double value)? semanticFormatterCallback;

  @override
  State<WakeSlider> createState() => _WakeSliderState();
}

/// Mutable animation state shared by the slider and its painter.
class _WakeField extends ChangeNotifier {
  _WakeField(int bars)
    : wake = Float64List(bars),
      wakeVelocity = Float64List(bars);

  /// Displayed handle position as a fraction of the track.
  double position = 0.0;

  /// Displacement of each bar caused by the wake, roughly 0 to 1.
  Float64List wake;

  /// Velocity of each bar's wake displacement.
  Float64List wakeVelocity;

  /// The highest wake displacement of any bar.
  double get peak {
    double result = 0.0;
    for (final double w in wake) {
      result = math.max(result, w);
    }
    return result;
  }

  void resize(int bars) {
    wake = Float64List(bars);
    wakeVelocity = Float64List(bars);
  }

  void notify() => notifyListeners();
}

class _WakeStepIntent extends Intent {
  const _WakeStepIntent(this.steps);

  final int steps;
}

class _WakeEdgeIntent extends Intent {
  const _WakeEdgeIntent({required this.toMax});

  final bool toMax;
}

class _WakeSliderState extends State<WakeSlider>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final _WakeField _field;
  Duration _lastTick = Duration.zero;

  /// Target handle position, a fraction of the track.
  double _target = 0.0;

  /// Velocity of the displayed handle, in fractions per second.
  double _velocity = 0.0;

  /// Raw fraction under the finger while dragging, before snapping.
  double _dragFraction = 0.0;
  bool _dragging = false;

  /// Whether the handle tracks the finger exactly (continuous drags).
  bool _attached = false;

  /// Remaining distance between the display and the finger while attached.
  double _catchUp = 0.0;
  bool _reducedMotion = false;
  bool _focusHighlight = false;
  bool _hovering = false;

  /// Track width from the last layout, used to map gestures.
  double _trackWidth = 0.0;
  double _resolvedBarWidth = 0.0;

  /// Spring stiffness while following a drag, and otherwise.
  static const double _dragStiffness = 1400.0;
  static const double _glideStiffness = 240.0;

  /// Stiffness and damping of each bar's wake spring.
  static const double _wakeStiffness = 120.0;
  static const double _wakeDamping = 9.0;

  /// Handle speed, in bars per second, that raises a full wake.
  static const double _fullWakeSpeed = 45.0;

  /// Opacity of the slider when disabled.
  static const double _disabledOpacity = 0.45;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  double get _range => widget.max - widget.min;

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
    _field = _WakeField(widget.bars);
    _target = _fractionOf(widget.value);
    _field.position = _target;
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) _settleNow();
  }

  @override
  void didUpdateWidget(WakeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bars != oldWidget.bars) {
      _field.resize(widget.bars);
    }
    if (widget.value != oldWidget.value ||
        widget.min != oldWidget.min ||
        widget.max != oldWidget.max) {
      _setTarget(_fractionOf(widget.value));
    }
    if (!_interactive && _dragging) {
      _dragging = false;
    }
    if (!_interactive) {
      _focusHighlight = false;
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
      return;
    }
    _ensureTicking();
  }

  void _ensureTicking() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// Jumps every animated value to rest.
  void _settleNow() {
    if (_ticker.isActive) _ticker.stop();
    _field.position = _target;
    _velocity = 0.0;
    _field.wake.fillRange(0, _field.wake.length, 0.0);
    _field.wakeVelocity.fillRange(0, _field.wakeVelocity.length, 0.0);
    _field.notify();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Long frames (hitches, or big test pumps) advance the full time; the
    // sub steps below keep the integration stable.
    dt = math.min(dt, 0.5);

    // Handle: damped spring towards the target, integrated in sub steps.
    final double before = _field.position;
    final double stiffness = _dragging ? _dragStiffness : _glideStiffness;
    final double damping = 2 * math.sqrt(stiffness) * (_dragging ? 1.0 : 0.9);
    final int subSteps = (dt / (1 / 240)).ceil();
    final double h = dt / subSteps;
    double position = _field.position;
    if (_dragging && widget.divisions == null) {
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

    // Wake: bars behind a fast-moving handle are pulled up, then each bar
    // springs back to rest on its own.
    final int bars = widget.bars;
    final Float64List wake = _field.wake;
    final Float64List wakeVelocity = _field.wakeVelocity;
    final double moved = position - before;
    final double speed = moved.abs() * (bars - 1) / dt;
    if (widget.wakeStrength > 0 && speed > 1.0) {
      final double amplitude =
          math.min(1.0, speed / _fullWakeSpeed) * widget.wakeStrength;
      final double trail = 1.2 + math.min(speed * 0.04, bars * 0.15);
      final double head = position.clamp(0.0, 1.0) * (bars - 1);
      final double direction = moved.sign;
      final double rise = 1 - math.exp(-dt * 60);
      final double taper = 1 - math.exp(-dt * 10);
      for (int i = 0; i < bars; i++) {
        final double behind = (head - i) * direction;
        if (behind <= 0.6) continue;
        // Rises over the first bar behind the handle, then trails off.
        final double b = behind - 0.6;
        final double target = math.min(
          1.0,
          amplitude * 1.35 * (1 - math.exp(-b / 0.9)) * math.exp(-b / trail),
        );
        if (target > wake[i]) {
          wake[i] += (target - wake[i]) * rise;
          wakeVelocity[i] = math.max(wakeVelocity[i], 0.0);
        } else {
          // Far behind a moving handle the wake tapers off, so it keeps a
          // trailing shape instead of a flat plateau.
          wake[i] += (target - wake[i]) * taper;
        }
      }
    }
    bool wakeAtRest = true;
    for (int i = 0; i < bars; i++) {
      double w = wake[i];
      double v = wakeVelocity[i];
      for (int s = 0; s < subSteps; s++) {
        v += (-_wakeStiffness * w - _wakeDamping * v) * h;
        w += v * h;
      }
      wake[i] = w;
      wakeVelocity[i] = v;
      if (w.abs() > 1e-3 || v.abs() > 1e-2) wakeAtRest = false;
    }

    final bool handleAtRest =
        !_dragging &&
        (position - _target).abs() < 1e-4 &&
        _velocity.abs() < 1e-3;
    if (handleAtRest && wakeAtRest) {
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

  /// Applies a one-shot change (keyboard, assistive technology).
  void _adjust(double value) {
    if (!_interactive) return;
    final double snapped = _snap(value);
    if (snapped == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    _emit(snapped);
    widget.onChangeEnd?.call(snapped);
  }

  double get _stepSize {
    final int? divisions = widget.divisions;
    return divisions != null ? _range / divisions : _range * 0.05;
  }

  double _stepped(int steps) =>
      _snap(widget.value + steps * _stepSize).clamp(widget.min, widget.max);

  // Gestures -----------------------------------------------------------

  double _fractionAt(Offset local) {
    final double usable = _trackWidth - _resolvedBarWidth;
    if (usable <= 0) return 0.0;
    double fraction = (local.dx - _resolvedBarWidth / 2) / usable;
    if (Directionality.of(context) == TextDirection.rtl) {
      fraction = 1 - fraction;
    }
    return fraction.clamp(0.0, 1.0).toDouble();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_interactive) return;
    _adjust(widget.min + _fractionAt(details.localPosition) * _range);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_interactive) return;
    _dragging = true;
    _attached = false;
    _dragFraction = _fractionAt(details.localPosition);
    widget.onChangeStart?.call(widget.value);
    _emit(widget.min + _dragFraction * _range);
    if (!_reducedMotion) _ensureTicking();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_interactive || !_dragging) return;
    final double usable = _trackWidth - _resolvedBarWidth;
    if (usable <= 0) return;
    double delta = details.delta.dx / usable;
    if (Directionality.of(context) == TextDirection.rtl) delta = -delta;
    _dragFraction = (_dragFraction + delta).clamp(0.0, 1.0).toDouble();
    _emit(widget.min + _dragFraction * _range);
  }

  void _handleDragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    _dragging = false;
    if (_attached) {
      // Come to rest exactly where the finger left, without overshoot.
      _attached = false;
      _velocity = 0.0;
    }
    widget.onChangeEnd?.call(widget.value);
    if (!_reducedMotion) _ensureTicking();
  }

  String _format(double value) {
    final String Function(double)? formatter = widget.semanticFormatterCallback;
    if (formatter != null) return formatter(value);
    return '${(_fractionOf(value) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool interactive = _interactive;
    final Color activeColor = widget.activeColor ?? colorScheme.primary;
    final Color inactiveColor =
        widget.inactiveColor ?? colorScheme.onSurface.withValues(alpha: 0.18);
    final TextDirection textDirection = Directionality.of(context);
    final bool rtl = textDirection == TextDirection.rtl;

    Widget track = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int bars = widget.bars;
        final double? fixedBarWidth = widget.barWidth;
        double width;
        double barWidth;
        if (fixedBarWidth != null) {
          barWidth = fixedBarWidth;
          width = bars * barWidth + (bars - 1) * widget.gap;
        } else {
          width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : bars * 4.0 + (bars - 1) * widget.gap;
          barWidth = math.max(1.0, (width - (bars - 1) * widget.gap) / bars);
        }
        width = constraints.constrainWidth(width);
        _trackWidth = width;
        _resolvedBarWidth = barWidth;
        return SizedBox(
          width: width,
          height: widget.height,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WakePainter(
                field: _field,
                barWidth: barWidth,
                gap: widget.gap,
                activeColor: activeColor,
                inactiveColor: _hoverAdjusted(inactiveColor),
                focusColor: activeColor.withValues(alpha: 0.45),
                focused: _focusHighlight,
                mirrored: rtl,
              ),
            ),
          ),
        );
      },
    );

    if (!interactive) {
      return Semantics(
        slider: true,
        enabled: false,
        label: widget.semanticLabel,
        value: _format(widget.value),
        child: Opacity(opacity: _disabledOpacity, child: track),
      );
    }

    final LogicalKeyboardKey increaseKey = rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final LogicalKeyboardKey decreaseKey = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;

    track = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragEnd,
      child: track,
    );

    final int pageSteps = widget.divisions != null
        ? math.max(1, (widget.divisions! / 5).round())
        : 4;

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
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool value) {
          if (value != _focusHighlight) {
            setState(() => _focusHighlight = value);
          }
        },
        onShowHoverHighlight: (bool value) {
          if (value != _hovering) setState(() => _hovering = value);
        },
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(increaseKey): const _WakeStepIntent(1),
          SingleActivator(decreaseKey): const _WakeStepIntent(-1),
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const _WakeStepIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _WakeStepIntent(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): _WakeStepIntent(
            pageSteps,
          ),
          const SingleActivator(LogicalKeyboardKey.pageDown): _WakeStepIntent(
            -pageSteps,
          ),
          const SingleActivator(LogicalKeyboardKey.home): const _WakeEdgeIntent(
            toMax: false,
          ),
          const SingleActivator(LogicalKeyboardKey.end): const _WakeEdgeIntent(
            toMax: true,
          ),
        },
        actions: <Type, Action<Intent>>{
          _WakeStepIntent: CallbackAction<_WakeStepIntent>(
            onInvoke: (_WakeStepIntent intent) {
              _adjust(_stepped(intent.steps));
              return null;
            },
          ),
          _WakeEdgeIntent: CallbackAction<_WakeEdgeIntent>(
            onInvoke: (_WakeEdgeIntent intent) {
              _adjust(intent.toMax ? widget.max : widget.min);
              return null;
            },
          ),
        },
        child: track,
      ),
    );
  }

  /// Slightly brightens the inactive bars while a mouse hovers the track.
  Color _hoverAdjusted(Color color) {
    if (!_hovering) return color;
    return color.withValues(alpha: math.min(1.0, color.a * 1.4));
  }
}

class _WakePainter extends CustomPainter {
  _WakePainter({
    required this.field,
    required this.barWidth,
    required this.gap,
    required this.activeColor,
    required this.inactiveColor,
    required this.focusColor,
    required this.focused,
    required this.mirrored,
  }) : super(repaint: field);

  final _WakeField field;
  final double barWidth;
  final double gap;
  final Color activeColor;
  final Color inactiveColor;
  final Color focusColor;
  final bool focused;
  final bool mirrored;

  /// Resting height of a bar, as a fraction of the track height.
  static const double _restHeight = 0.32;

  /// Extra height the wake can add on top of the resting height.
  static const double _wakeHeight = 0.56;

  /// Width, in bars, of the bump around the handle.
  static const double _bumpSigma = 0.95;

  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final int bars = field.wake.length;
    if (bars < 2) return;
    if (mirrored) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final double pitch = bars > 1 ? (size.width - barWidth) / (bars - 1) : 0.0;
    final double head = field.position.clamp(0.0, 1.0) * (bars - 1);
    final double centerY = size.height / 2;
    final double minHeight = math.min(barWidth, size.height);
    final Radius radius = Radius.circular(barWidth / 2);
    const double twoSigmaSq = 2 * _bumpSigma * _bumpSigma;

    for (int i = 0; i < bars; i++) {
      final double d = i - head;
      final double bump = math.exp(-(d * d) / twoSigmaSq);
      final double fraction =
          _restHeight +
          (1 - _restHeight) * bump +
          _wakeHeight * field.wake[i] * (1 - bump);
      final double barHeight = (fraction * size.height)
          .clamp(minHeight, size.height)
          .toDouble();
      // A bar is fully lit by the time it becomes the tallest one.
      final double coverage = (2 * (head - i + 1)).clamp(0.0, 1.0).toDouble();
      _paint.color = Color.lerp(inactiveColor, activeColor, coverage)!;
      final double left = i * pitch;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          centerY - barHeight / 2,
          left + barWidth,
          centerY + barHeight / 2,
          radius,
        ),
        _paint,
      );
    }

    if (mirrored) canvas.restore();

    if (focused) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = focusColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).inflate(4),
          const Radius.circular(8),
        ),
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(_WakePainter oldDelegate) =>
      oldDelegate.field != field ||
      oldDelegate.barWidth != barWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.focusColor != focusColor ||
      oldDelegate.focused != focused ||
      oldDelegate.mirrored != mirrored;
}
