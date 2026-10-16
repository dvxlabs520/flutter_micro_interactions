import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A checkbox row where one spring fills the box, draws the tick and
/// strikes through the label, in that order.
///
/// ```dart
/// SpringCheckbox(
///   value: _done,
///   onChanged: (bool? value) => setState(() => _done = value!),
///   label: const Text('Water the plants'),
/// )
/// ```
///
/// A single [SpringSimulation] drives three phases. First the box fills,
/// scaling in from its center with a small overshoot; then the tick draws
/// its stroke; then a strike-through line is drawn across the [label]
/// (left to right, or right to left in right-to-left text) while the label
/// dims. Unchecking plays the same spring backwards, so the strike retracts
/// first and the fill empties last. Because one spring is shared, a toggle
/// in the middle of an animation reverses smoothly from the current state.
///
/// With [tristate] the value can also be null, shown as a filled box with a
/// dash and no strike-through; the tick and dash morph into each other.
/// Tapping cycles false, true, null, like the Material [Checkbox].
///
/// The checkbox is controlled: tapping calls [onChanged] with the next
/// value, and the animation only plays when the parent rebuilds it with
/// the new [value]. Tapping the label toggles it too.
///
/// Accessibility: the row is exposed as one checked, unchecked or mixed
/// control whose label is [semanticLabel] or the [label]'s own text. It is
/// keyboard focusable with a visible focus ring around the box, and Enter
/// or Space toggles it. The box has a tap target of at least 48 by 48.
///
/// When [onChanged] is null or [enabled] is false the checkbox renders in a
/// dimmed disabled style and ignores input. Under reduced motion every
/// change is instant. The strike-through is drawn across the vertical
/// middle of the label, so it suits single-line labels best.
class SpringCheckbox extends StatefulWidget {
  /// Creates a spring checkbox.
  const SpringCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.tristate = false,
    this.strikeThrough = true,
    this.size = 22.0,
    this.activeColor,
    this.checkColor,
    this.borderColor,
    this.borderRadius = 6.0,
    this.labelStyle,
    this.strikeColor,
    this.dimmedLabelOpacity = 0.55,
    this.spring = const SpringDescription(
      mass: 1.0,
      stiffness: 120.0,
      damping: 15.5,
    ),
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(
         tristate || value != null,
         'value may only be null when tristate',
       ),
       assert(size > 0.0, 'size must be positive'),
       assert(borderRadius >= 0.0, 'borderRadius must not be negative'),
       assert(
         dimmedLabelOpacity >= 0.0 && dimmedLabelOpacity <= 1.0,
         'dimmedLabelOpacity must be between 0 and 1',
       );

  /// Whether the checkbox is checked. May be null only when [tristate] is
  /// true, which shows a dash.
  final bool? value;

  /// Called with the next value when the user toggles the checkbox. When
  /// null the checkbox renders disabled.
  final ValueChanged<bool?>? onChanged;

  /// Optional label shown after the box, typically a [Text]. Tapping it
  /// toggles the checkbox.
  final Widget? label;

  /// Whether the value can be null (indeterminate). Defaults to false.
  final bool tristate;

  /// Whether a checked label is struck through and dimmed. Defaults to
  /// true.
  final bool strikeThrough;

  /// Side length of the box. Defaults to 22.
  final double size;

  /// Fill color of the checked box. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? activeColor;

  /// Color of the tick and dash. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? checkColor;

  /// Outline color of the unchecked box. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant`.
  final Color? borderColor;

  /// Corner radius of the box. Defaults to 6.
  final double borderRadius;

  /// Text style of the label. Defaults to the theme's
  /// `textTheme.bodyLarge` in `colorScheme.onSurface`.
  final TextStyle? labelStyle;

  /// Color of the strike-through line. Defaults to the label color.
  final Color? strikeColor;

  /// Opacity of a struck-through label. Defaults to 0.55.
  final double dimmedLabelOpacity;

  /// The spring that drives the whole sequence. Defaults to a mass of 1,
  /// stiffness of 120 and damping of 15.5, a lightly underdamped spring.
  final SpringDescription spring;

  /// Whether a selection click haptic is triggered when the user toggles
  /// the checkbox. Defaults to true.
  final bool enableHaptics;

  /// When false the checkbox renders disabled, exactly as if [onChanged]
  /// were null.
  final bool enabled;

  /// Optional label announced by assistive technology instead of the
  /// semantics of [label].
  final String? semanticLabel;

  @override
  State<SpringCheckbox> createState() => _SpringCheckboxState();
}

/// Progress points of the shared spring. The fill, mark and strike phases
/// overlap slightly so the sequence reads as one gesture.
abstract final class _Phases {
  static const double fillEnd = 0.4;
  static const double markStart = 0.3;
  static const double markEnd = 0.66;
  static const double strikeStart = 0.75;

  /// Resting progress of the indeterminate state: filled, dash drawn, no
  /// strike. It sits between the mark and strike phases so a small spring
  /// overshoot never starts the strike.
  static const double mixed = 0.7;

  static double fill(double t) => (t / fillEnd).clamp(0.0, 1.0);

  static double mark(double t) =>
      ((t - markStart) / (markEnd - markStart)).clamp(0.0, 1.0);

  static double strike(double t) =>
      ((t - strikeStart) / (1.0 - strikeStart)).clamp(0.0, 1.0);
}

class _SpringCheckboxState extends State<SpringCheckbox>
    with TickerProviderStateMixin {
  /// Shared progress: 0 unchecked, [_Phases.mixed] indeterminate, 1
  /// checked. Overshoots while the spring settles.
  late final AnimationController _progress;

  /// Morph between the tick (0) and the dash (1).
  late final AnimationController _dash;

  late Animation<double> _labelOpacity;
  bool _reducedMotion = false;
  bool _focused = false;

  static const double _minTapTarget = 48.0;
  static const double _disabledOpacity = 0.38;

  static const Tolerance _tolerance = Tolerance(
    distance: 0.0005,
    velocity: 0.01,
  );

  bool get _interactive => widget.enabled && widget.onChanged != null;

  static double _targetFor(bool? value) {
    if (value == null) return _Phases.mixed;
    return value ? 1.0 : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _progress = AnimationController.unbounded(
      vsync: this,
      value: _targetFor(widget.value),
    )..addStatusListener(_onProgressStatus);
    _dash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: widget.value == null ? 1.0 : 0.0,
    );
    _labelOpacity = _progress.drive(_LabelOpacity(widget.dimmedLabelOpacity));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _progress.value = _targetFor(widget.value);
      _dash.value = widget.value == null ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(SpringCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dimmedLabelOpacity != oldWidget.dimmedLabelOpacity) {
      _labelOpacity = _progress.drive(_LabelOpacity(widget.dimmedLabelOpacity));
    }
    if (widget.value != oldWidget.value) {
      _animateTo(widget.value);
    }
  }

  @override
  void dispose() {
    _progress.removeStatusListener(_onProgressStatus);
    _progress.dispose();
    _dash.dispose();
    super.dispose();
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final double target = _targetFor(widget.value);
    _progress.value = target;
    // Once fully empty, reset the mark to a tick for the next check.
    if (target == 0.0) {
      _dash.value = 0.0;
    }
  }

  void _animateTo(bool? value) {
    final double target = _targetFor(value);
    if (_reducedMotion) {
      _progress.value = target;
      _dash.value = value == null ? 1.0 : 0.0;
      return;
    }
    if (value == null) {
      _dash.forward();
    } else if (value) {
      _dash.reverse();
    }
    _progress.animateWith(
      SpringSimulation(
        widget.spring,
        _progress.value,
        target,
        _progress.velocity,
        tolerance: _tolerance,
      ),
    );
  }

  bool? get _nextValue {
    switch (widget.value) {
      case false:
        return true;
      case true:
        return widget.tristate ? null : false;
      case null:
        return false;
    }
  }

  void _toggle() {
    if (!_interactive) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    widget.onChanged?.call(_nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool interactive = _interactive;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    const double ringMargin = 4.0;

    final Widget box = SizedBox(
      width: math.max(_minTapTarget, widget.size + ringMargin * 2),
      height: math.max(_minTapTarget, widget.size + ringMargin * 2),
      child: Center(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size + ringMargin * 2),
            painter: _SpringBoxPainter(
              progress: _progress,
              dash: _dash,
              boxSize: widget.size,
              margin: ringMargin,
              radius: widget.borderRadius,
              activeColor: widget.activeColor ?? scheme.primary,
              checkColor: widget.checkColor ?? scheme.onPrimary,
              borderColor: widget.borderColor ?? scheme.onSurfaceVariant,
              focusColor: scheme.primary,
              focused: _focused && interactive,
            ),
          ),
        ),
      ),
    );

    Widget row = box;
    if (widget.label != null) {
      final TextStyle labelStyle =
          (theme.textTheme.bodyLarge ?? const TextStyle())
              .copyWith(color: scheme.onSurface)
              .merge(widget.labelStyle);
      Widget label = DefaultTextStyle.merge(
        style: labelStyle,
        child: widget.label!,
      );
      if (widget.strikeThrough) {
        label = FadeTransition(
          opacity: _labelOpacity,
          child: CustomPaint(
            foregroundPainter: _StrikePainter(
              progress: _progress,
              color: widget.strikeColor ?? labelStyle.color ?? scheme.onSurface,
              rtl: rtl,
            ),
            child: label,
          ),
        );
      }
      row = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          box,
          const SizedBox(width: 4),
          Flexible(child: label),
          const SizedBox(width: 8),
        ],
      );
    }

    if (widget.semanticLabel != null) {
      row = ExcludeSemantics(child: row);
    }

    if (!interactive) {
      return MergeSemantics(
        child: Semantics(
          checked: widget.value ?? false,
          mixed: widget.tristate ? widget.value == null : null,
          enabled: false,
          label: widget.semanticLabel,
          child: Opacity(opacity: _disabledOpacity, child: row),
        ),
      );
    }

    return MergeSemantics(
      child: Semantics(
        checked: widget.value ?? false,
        mixed: widget.tristate ? widget.value == null : null,
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
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _toggle,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Maps the shared progress to the label opacity during the strike phase.
class _LabelOpacity extends Animatable<double> {
  const _LabelOpacity(this.dimmed);

  final double dimmed;

  @override
  double transform(double t) => 1.0 - (1.0 - dimmed) * _Phases.strike(t);
}

class _SpringBoxPainter extends CustomPainter {
  _SpringBoxPainter({
    required this.progress,
    required this.dash,
    required this.boxSize,
    required this.margin,
    required this.radius,
    required this.activeColor,
    required this.checkColor,
    required this.borderColor,
    required this.focusColor,
    required this.focused,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, dash]));

  final Animation<double> progress;
  final Animation<double> dash;
  final double boxSize;
  final double margin;
  final double radius;
  final Color activeColor;
  final Color checkColor;
  final Color borderColor;
  final Color focusColor;
  final bool focused;

  /// Tick polyline in unit box coordinates.
  static const List<Offset> _tick = <Offset>[
    Offset(0.27, 0.52),
    Offset(0.43, 0.68),
    Offset(0.74, 0.35),
  ];

  /// Dash polyline in unit box coordinates (same point count as the tick).
  static const List<Offset> _dash = <Offset>[
    Offset(0.27, 0.5),
    Offset(0.5, 0.5),
    Offset(0.73, 0.5),
  ];

  static const double _borderWidth = 2.0;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double fill = _Phases.fill(t);
    final double mark = _Phases.mark(t);
    final Rect box = Offset(margin, margin) & Size.square(boxSize);
    final RRect boxRRect = RRect.fromRectAndRadius(
      box,
      Radius.circular(radius),
    );

    // Unchecked outline, fading out as the fill takes over.
    if (fill < 1.0) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth
        ..strokeCap = StrokeCap.butt
        ..color = Color.lerp(borderColor, activeColor, fill)!;
      canvas.drawRRect(boxRRect.deflate(_borderWidth / 2), _paint);
    }

    // Fill scaling in from the center with a small overshoot.
    if (fill > 0.0) {
      final double scale = Curves.easeOutBack.transform(fill);
      canvas.save();
      canvas.translate(box.center.dx, box.center.dy);
      canvas.scale(scale);
      canvas.translate(-box.center.dx, -box.center.dy);
      _paint
        ..style = PaintingStyle.fill
        ..color = activeColor;
      canvas.drawRRect(boxRRect, _paint);
      canvas.restore();
    }

    // The tick or dash, drawn progressively along its polyline.
    if (mark > 0.0) {
      final double d = dash.value;
      final List<Offset> points = <Offset>[
        for (int i = 0; i < _tick.length; i++)
          box.topLeft + Offset.lerp(_tick[i], _dash[i], d)! * boxSize,
      ];
      final double first = (points[1] - points[0]).distance;
      final double second = (points[2] - points[1]).distance;
      final double drawn = (first + second) * mark;
      final Path path = Path()..moveTo(points[0].dx, points[0].dy);
      if (drawn <= first) {
        final Offset end = Offset.lerp(points[0], points[1], drawn / first)!;
        path.lineTo(end.dx, end.dy);
      } else {
        path.lineTo(points[1].dx, points[1].dy);
        final Offset end = Offset.lerp(
          points[1],
          points[2],
          (drawn - first) / second,
        )!;
        path.lineTo(end.dx, end.dy);
      }
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, boxSize * 0.11)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = checkColor;
      canvas.drawPath(path, _paint);
    }

    if (focused) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.butt
        ..color = focusColor;
      canvas.drawRRect(boxRRect.inflate(margin - 1.0), _paint);
    }
  }

  @override
  bool shouldRepaint(_SpringBoxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dash != dash ||
        oldDelegate.boxSize != boxSize ||
        oldDelegate.margin != margin ||
        oldDelegate.radius != radius ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.checkColor != checkColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.focusColor != focusColor ||
        oldDelegate.focused != focused;
  }
}

/// Draws the strike-through line over the label.
class _StrikePainter extends CustomPainter {
  _StrikePainter({
    required this.progress,
    required this.color,
    required this.rtl,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final bool rtl;

  final Paint _paint = Paint()
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double strike = _Phases.strike(progress.value);
    if (strike <= 0.0) return;
    final double y = size.height / 2;
    final double length = size.width * strike;
    _paint.color = color;
    if (rtl) {
      canvas.drawLine(
        Offset(size.width, y),
        Offset(size.width - length, y),
        _paint,
      );
    } else {
      canvas.drawLine(Offset(0.0, y), Offset(length, y), _paint);
    }
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.rtl != rtl;
  }
}
