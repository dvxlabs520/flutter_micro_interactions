import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A pill shaped notification toggle with a bell that rings when turned
/// on.
///
/// ```dart
/// BellToggle(
///   value: subscribed,
///   onChanged: (bool value) => setState(() => subscribed = value),
/// )
/// ```
///
/// The widget is controlled: tapping it calls [onChanged] with the
/// opposite of [value], and the parent rebuilds it with the new value.
///
/// Turning on rings the bell: it wobbles around its top by up to 18
/// degrees with a quickly decaying swing while the clapper swings behind
/// it. At the same time the label changes from [offLabel] to [onLabel]
/// with a slide and a fade, the pill grows or shrinks smoothly to the new
/// label width, and [activeColor] fills the pill outward from the bell.
/// Turning off draws a slash across the bell with a quick shrink, and the
/// fill retracts into the bell. The bell is drawn with a custom painter,
/// so it does not depend on an icon font.
///
/// Accessibility: the widget is a toggle button. Its label is
/// [semanticLabel] when given, otherwise the current visible label, and
/// its toggled state is [value]. It can be focused and activated with
/// Enter or Space, shows a focus ring when focused with the keyboard, and
/// keeps a touch target at least 48 pixels tall.
///
/// When [onChanged] is null or [enabled] is false the toggle is dimmed
/// and ignores input. Under reduced motion the state changes instantly:
/// no ring, no shrink, no slide; the toggle still works.
class BellToggle extends StatefulWidget {
  /// Creates a bell toggle.
  const BellToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLabel = 'Notifications on',
    this.offLabel = 'Notify me',
    this.height = 40.0,
    this.activeColor,
    this.activeForegroundColor,
    this.inactiveColor,
    this.inactiveForegroundColor,
    this.labelStyle,
    this.duration = const Duration(milliseconds: 420),
    this.ringDuration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeOutCubic,
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(height > 0.0, 'height must be positive');

  /// Whether notifications are on.
  final bool value;

  /// Called with the requested new value when the toggle is activated.
  /// When null the toggle renders disabled.
  final ValueChanged<bool>? onChanged;

  /// Label shown when [value] is true. Defaults to `'Notifications on'`.
  final String onLabel;

  /// Label shown when [value] is false. Defaults to `'Notify me'`.
  final String offLabel;

  /// Height of the pill. Defaults to 40. The touch target is never
  /// shorter than 48 pixels.
  final double height;

  /// Fill color of the pill when on. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? activeColor;

  /// Bell and label color when on. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? activeForegroundColor;

  /// Background color of the pill when off. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? inactiveColor;

  /// Bell and label color when off. Defaults to the theme's
  /// `colorScheme.onSurface`.
  final Color? inactiveForegroundColor;

  /// Text style of the label, merged over the theme's `labelLarge`
  /// style. Its color is replaced by the foreground colors.
  final TextStyle? labelStyle;

  /// Length of the fill, width and label animations. Defaults to 420
  /// milliseconds.
  final Duration duration;

  /// Length of the bell ring after turning on. Defaults to 1000
  /// milliseconds.
  final Duration ringDuration;

  /// Curve of the fill, width and label animations. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// Whether haptic feedback is played when the toggle is activated.
  /// Defaults to true.
  final bool enableHaptics;

  /// When false the toggle renders dimmed and ignores input, exactly as if
  /// [onChanged] were null.
  final bool enabled;

  /// Label announced by assistive technology. Defaults to the visible
  /// label of the current state.
  final String? semanticLabel;

  @override
  State<BellToggle> createState() => _BellToggleState();
}

class _BellToggleState extends State<BellToggle> with TickerProviderStateMixin {
  /// 0 when off, 1 when on.
  late final AnimationController _fill;

  /// Progress of the ring after turning on.
  late final AnimationController _ring;

  /// Progress of the quick shrink after turning off.
  late final AnimationController _shrink;
  late CurvedAnimation _fillCurve;
  bool _focused = false;
  bool _reducedMotion = false;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.value ? 1.0 : 0.0,
    );
    _fillCurve = CurvedAnimation(
      parent: _fill,
      curve: widget.curve,
      // Turning off retracts quickly at first, mirroring the fill.
      reverseCurve: widget.curve.flipped,
    );
    _ring = AnimationController(vsync: this, duration: widget.ringDuration);
    _shrink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _settle();
    }
  }

  @override
  void didUpdateWidget(BellToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _fill.duration = widget.duration;
    }
    if (widget.ringDuration != oldWidget.ringDuration) {
      _ring.duration = widget.ringDuration;
    }
    if (widget.curve != oldWidget.curve) {
      _fillCurve.dispose();
      _fillCurve = CurvedAnimation(
        parent: _fill,
        curve: widget.curve,
        // Turning off retracts quickly at first, mirroring the fill.
        reverseCurve: widget.curve.flipped,
      );
    }
    if (widget.value != oldWidget.value) {
      _play(widget.value);
    }
  }

  @override
  void dispose() {
    _fillCurve.dispose();
    _fill.dispose();
    _ring.dispose();
    _shrink.dispose();
    super.dispose();
  }

  /// Jumps every animation to its resting state.
  void _settle() {
    _fill.stop();
    _fill.value = widget.value ? 1.0 : 0.0;
    _ring.stop();
    _ring.value = 0.0;
    _shrink.stop();
    _shrink.value = 0.0;
  }

  void _play(bool on) {
    if (_reducedMotion || !widget.enabled) {
      _settle();
      return;
    }
    if (on) {
      _shrink.stop();
      _shrink.value = 0.0;
      _fill.forward();
      _ring.forward(from: 0.0).whenCompleteOrCancel(() {
        if (mounted) _ring.value = 0.0;
      });
    } else {
      _ring.stop();
      _ring.value = 0.0;
      _fill.reverse();
      _shrink.forward(from: 0.0).whenCompleteOrCancel(() {
        if (mounted) _shrink.value = 0.0;
      });
    }
  }

  void _activate() {
    if (!_interactive) return;
    if (widget.enableHaptics) {
      if (widget.value) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color activeColor = widget.activeColor ?? scheme.primary;
    final Color activeForeground =
        widget.activeForegroundColor ?? scheme.onPrimary;
    final Color inactiveColor =
        widget.inactiveColor ?? scheme.surfaceContainerHighest;
    final Color inactiveForeground =
        widget.inactiveForegroundColor ?? scheme.onSurface;
    final TextDirection direction = Directionality.of(context);
    final double h = widget.height;
    final Duration duration = _reducedMotion ? Duration.zero : widget.duration;
    final bool interactive = _interactive;
    final String label = widget.value ? widget.onLabel : widget.offLabel;
    final TextStyle baseStyle =
        (theme.textTheme.labelLarge ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.w600)
            .merge(widget.labelStyle);
    final ValueKey<bool> currentKey = ValueKey<bool>(widget.value);
    // On: the new label rises from below. Off: it drops from above.
    final double enterFrom = widget.value ? 1.0 : -1.0;

    // The content is built twice: once in the off colors, and once in the
    // on colors clipped to the fill that grows from the bell, so the bell
    // and the label always contrast with the background under them.
    Widget layer(Color foreground) {
      final Widget switcher = AnimatedSwitcher(
        duration: duration,
        switchInCurve: Interval(0.15, 1.0, curve: widget.curve),
        switchOutCurve: Interval(0.4, 1.0, curve: widget.curve),
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[...previous, if (current != null) current],
        ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool incoming = child.key == currentKey;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.0, incoming ? enterFrom : -enterFrom),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          label,
          key: currentKey,
          maxLines: 1,
          softWrap: false,
          style: baseStyle.copyWith(color: foreground),
        ),
      );
      // AnimatedSize asserts with a zero duration, so it is skipped then.
      final Widget labelSwitcher = ClipRect(
        child: duration == Duration.zero
            ? switcher
            : AnimatedSize(
                duration: duration,
                curve: widget.curve,
                alignment: AlignmentDirectional.centerStart,
                child: switcher,
              ),
      );

      return SizedBox(
        height: h,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(width: h * 0.25),
            SizedBox(
              width: h * 0.5,
              height: h,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BellPainter(
                    fill: _fillCurve,
                    ring: _ring,
                    shrink: _shrink,
                    color: foreground,
                  ),
                ),
              ),
            ),
            SizedBox(width: h * 0.2),
            labelSwitcher,
            SizedBox(width: h * 0.45),
          ],
        ),
      );
    }

    Widget pill = CustomPaint(
      painter: _PillPainter(
        fill: _fillCurve,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        bellCenter: h * 0.5,
        textDirection: direction,
      ),
      child: Stack(
        children: <Widget>[
          layer(inactiveForeground),
          ClipPath(
            clipper: _RevealClipper(
              fill: _fillCurve,
              bellCenter: h * 0.5,
              textDirection: direction,
            ),
            child: layer(activeForeground),
          ),
        ],
      ),
    );

    pill = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: _focused
              ? BorderSide(
                  color: scheme.primary,
                  width: 2.0,
                  // Leaves a 2 pixel gap so the ring shows on any fill.
                  strokeAlign: 3.0,
                )
              : BorderSide.none,
        ),
      ),
      child: pill,
    );

    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 48.0),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: ExcludeSemantics(child: pill),
      ),
    );

    // The structure stays the same when the toggle is enabled or disabled
    // so running animations keep their state.
    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      toggled: widget.value,
      label: widget.semanticLabel ?? label,
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
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
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? _activate : null,
          child: Opacity(opacity: interactive ? 1.0 : 0.5, child: content),
        ),
      ),
    );
  }
}

/// The circle of the fill for progress [t], centered on the bell and
/// reaching the farthest corner of [size] at 1.
Path _revealPath(
  Size size,
  double t,
  double bellCenter,
  TextDirection textDirection,
) {
  final double x = textDirection == TextDirection.rtl
      ? size.width - bellCenter
      : bellCenter;
  final double reach = math.sqrt(
    math.pow(math.max(x, size.width - x), 2) + math.pow(size.height / 2.0, 2),
  );
  return Path()..addOval(
    Rect.fromCircle(center: Offset(x, size.height / 2.0), radius: reach * t),
  );
}

/// Clips the "on" copy of the content to the growing fill.
class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({
    required this.fill,
    required this.bellCenter,
    required this.textDirection,
  }) : super(reclip: fill);

  final Animation<double> fill;
  final double bellCenter;
  final TextDirection textDirection;

  @override
  Path getClip(Size size) =>
      _revealPath(size, fill.value.clamp(0.0, 1.0), bellCenter, textDirection);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.fill != fill ||
      oldClipper.bellCenter != bellCenter ||
      oldClipper.textDirection != textDirection;
}

/// Paints the pill background: the inactive color, with the active color
/// revealed in a circle that grows from the bell.
class _PillPainter extends CustomPainter {
  _PillPainter({
    required this.fill,
    required this.activeColor,
    required this.inactiveColor,
    required this.bellCenter,
    required this.textDirection,
  }) : super(repaint: fill);

  final Animation<double> fill;
  final Color activeColor;
  final Color inactiveColor;

  /// Distance of the bell center from the start edge.
  final double bellCenter;
  final TextDirection textDirection;

  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect pill = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2.0),
    );
    _paint.color = inactiveColor;
    canvas.drawRRect(pill, _paint);
    final double t = fill.value.clamp(0.0, 1.0);
    if (t <= 0.0) return;
    _paint.color = activeColor;
    if (t >= 1.0) {
      canvas.drawRRect(pill, _paint);
      return;
    }
    canvas.save();
    canvas.clipRRect(pill);
    canvas.drawPath(_revealPath(size, t, bellCenter, textDirection), _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PillPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.bellCenter != bellCenter ||
      oldDelegate.textDirection != textDirection;
}

/// Paints the bell: body, knob and a clapper that swings, filled when on
/// and outlined with a slash when off.
class _BellPainter extends CustomPainter {
  _BellPainter({
    required this.fill,
    required this.ring,
    required this.shrink,
    required this.color,
  }) : super(repaint: Listenable.merge(<Listenable>[fill, ring, shrink]));

  final Animation<double> fill;
  final Animation<double> ring;
  final Animation<double> shrink;
  final Color color;

  /// Largest wobble angle of the bell, in radians (18 degrees).
  static const double _maxWobble = 18.0 * math.pi / 180.0;

  /// Largest swing of the clapper relative to the bell, in radians.
  static const double _maxClapper = 26.0 * math.pi / 180.0;

  /// Y of the bell lip on the 24 unit grid.
  static const double _lip = 17.4;

  /// Bell pivot (the knob) on the 24 unit grid.
  static const Offset _pivot = Offset(12.0, 3.4);

  /// Clapper pivot and arm length on the 24 unit grid.
  static const Offset _clapperPivot = Offset(12.0, 14.0);
  static const double _clapperArm = 5.6;

  static final Path _body = _buildBody();

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Path _buildBody() {
    return Path()
      ..moveTo(12.0, 4.6)
      ..cubicTo(8.6, 4.6, 6.4, 7.2, 6.4, 10.6)
      ..lineTo(6.4, 14.2)
      ..cubicTo(6.4, 15.4, 5.6, 16.4, 4.4, 17.0)
      ..lineTo(4.4, _lip)
      ..lineTo(19.6, _lip)
      ..lineTo(19.6, 17.0)
      ..cubicTo(18.4, 16.4, 17.6, 15.4, 17.6, 14.2)
      ..lineTo(17.6, 10.6)
      ..cubicTo(17.6, 7.2, 15.4, 4.6, 12.0, 4.6)
      ..close();
  }

  /// The current wobble angle of the bell in radians, for tests.
  double get bellAngle => _maxWobble * _wobble(ring.value, 0.0);

  /// Decaying wobble shape over the ring progress [t], from -1 to 1.
  static double _wobble(double t, double phase) {
    if (t <= 0.0 || t >= 1.0) return 0.0;
    return math.exp(-3.0 * t) * (1.0 - t) * math.sin(8.0 * math.pi * t - phase);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final double unit = side / 24.0;
    final double on = fill.value.clamp(0.0, 1.0);
    final double r = ring.value;
    final double s = shrink.value;
    final double stroke = 1.9;

    final double bellAngle = _maxWobble * _wobble(r, 0.0);
    final double clapperAngle = -_maxClapper * _wobble(r, 1.1);
    final double pop = r > 0.0 && r < 0.25
        ? 0.1 * math.sin(math.pi * r / 0.25)
        : 0.0;
    final double scale = (1.0 + pop) * (1.0 - 0.22 * math.sin(math.pi * s));

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(unit * scale);
    canvas.translate(-12.0, -12.0);
    // Everything is drawn in a layer so the slash gap can be cut out.
    canvas.saveLayer(const Rect.fromLTRB(-4.0, -4.0, 28.0, 28.0), Paint());

    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.rotate(bellAngle);
    canvas.translate(-_pivot.dx, -_pivot.dy);

    // Clapper, only visible below the lip.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4.0, _lip + stroke / 2.0, 28.0, 28.0));
    final Offset clapper =
        _clapperPivot +
        Offset(math.sin(clapperAngle), math.cos(clapperAngle)) * _clapperArm;
    _paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(clapper, 2.0, _paint);
    canvas.restore();

    // Body: outline always, fill fading in when on.
    if (on > 0.0) {
      _paint
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * on);
      canvas.drawPath(_body, _paint);
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawPath(_body, _paint);

    // Knob.
    _paint.style = PaintingStyle.fill;
    canvas.drawCircle(_pivot, 1.3, _paint);

    // Slash when off, drawn along its length as the bell turns off.
    // The slash disappears early when turning on so no stub lingers.
    final double slash = ((1.0 - on - 0.1) / 0.9).clamp(0.0, 1.0);
    if (slash > 0.0) {
      const Offset from = Offset(3.6, 2.6);
      const Offset to = Offset(20.4, 21.4);
      final Offset end = Offset.lerp(
        from,
        to,
        Curves.easeOut.transform(slash),
      )!;
      // Cut a gap beside the slash so it reads against the body.
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 2.6
        ..blendMode = BlendMode.clear;
      canvas.drawLine(from, end, _paint);
      _paint
        ..blendMode = BlendMode.srcOver
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawLine(from, end, _paint);
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BellPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.ring != ring ||
      oldDelegate.shrink != shrink ||
      oldDelegate.color != color;
}
