import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A star rating that previews the value under the pointer with a lifting
/// wave and commits with a pop.
///
/// ```dart
/// PeekRating(
///   value: _rating,
///   allowHalf: true,
///   onChanged: (double rating) => setState(() => _rating = rating),
/// )
/// ```
///
/// Hovering (or dragging on touch) previews a rating: the stars up to the
/// pointer fill with [previewColor] and lift in a wave. Each star rises and
/// grows slightly on its own spring, and stars farther from the pointer
/// start later ([waveDelay] per star), so the motion ripples outward from
/// the pointer. Clicking or tapping commits the previewed value through
/// [onChanged]; the committed star pops with an overshoot and emits a small
/// sparkle ring. Moving the pointer away drops the stars back and restores
/// the committed [value].
///
/// With [allowHalf] the left half of each star picks a half value. The
/// widget is controlled: it always paints [value] unless a preview is
/// active, so update [value] from [onChanged].
///
/// The rating is exposed to assistive technology as a slider whose value
/// reads like "3 of 5", with increase and decrease actions. When focused,
/// the arrow keys change the value by one step (half a star with
/// [allowHalf]), Home clears it and End sets the maximum. Keyboard focus
/// shows a ring around the stars.
///
/// [readOnly] shows the value without interaction at full opacity, while
/// `enabled: false` (or a null [onChanged]) renders the stars dimmed and
/// non-interactive. Under reduced motion the preview still recolors the
/// stars, but there is no wave, pop or sparkle.
class PeekRating extends StatefulWidget {
  /// Creates a peek rating.
  const PeekRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.count = 5,
    this.allowHalf = false,
    this.size = 28.0,
    this.spacing = 6.0,
    this.activeColor,
    this.previewColor,
    this.inactiveColor,
    this.waveDelay = const Duration(milliseconds: 35),
    this.duration = const Duration(milliseconds: 560),
    this.readOnly = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(count > 0, 'count must be positive'),
       assert(size > 0, 'size must be positive'),
       assert(spacing >= 0, 'spacing must not be negative'),
       assert(
         value >= 0 && value <= count,
         'value must be between 0 and count',
       );

  /// The committed rating, from 0 to [count].
  final double value;

  /// Called with the new rating when the user commits one. When null the
  /// rating renders disabled.
  final ValueChanged<double>? onChanged;

  /// Number of stars. Defaults to 5.
  final int count;

  /// Whether half stars can be picked. Defaults to `false`.
  final bool allowHalf;

  /// Width and height of one star. Defaults to 28.
  final double size;

  /// Horizontal gap between stars. Defaults to 6.
  final double spacing;

  /// Fill color of committed stars. Defaults to a warm amber tuned for the
  /// theme's brightness, readable on light and dark surfaces.
  final Color? activeColor;

  /// Fill color of previewed stars. Defaults to [activeColor].
  final Color? previewColor;

  /// Fill color of empty stars. Defaults to the theme's
  /// `colorScheme.onSurface` at 16 percent alpha.
  final Color? inactiveColor;

  /// Extra delay per star of distance from the pointer before a star
  /// starts lifting or dropping. Defaults to 35 milliseconds.
  final Duration waveDelay;

  /// Length of the commit pop and sparkle ring. Defaults to 560
  /// milliseconds.
  final Duration duration;

  /// Whether the rating only displays [value]. Read-only ratings render at
  /// full opacity but ignore pointer and keyboard input. Defaults to
  /// `false`.
  final bool readOnly;

  /// When false the stars render dimmed and ignore input, as if
  /// [onChanged] were null. Defaults to `true`.
  final bool enabled;

  /// Optional focus node. The caller owns and disposes it.
  final FocusNode? focusNode;

  /// Whether the rating requests focus when first built. Defaults to
  /// `false`.
  final bool autofocus;

  /// Semantics label of the slider. Defaults to `'Rating'`.
  final String? semanticLabel;

  @override
  State<PeekRating> createState() => _PeekRatingState();
}

/// The light-theme default star color (amber 500).
const Color _amberLight = Color(0xFFF59E0B);

/// The dark-theme default star color (amber 400).
const Color _amberDark = Color(0xFFFBBF24);

/// Spring motion state of one star's lift.
class _StarSpring {
  double value = 0.0;
  double velocity = 0.0;
  double target = 0.0;
  SpringSimulation? simulation;
  Duration simulationStart = Duration.zero;
  double? pendingTarget;
  Duration pendingStart = Duration.zero;

  bool get isActive => simulation != null || pendingTarget != null;
}

class _PeekRatingState extends State<PeekRating> with TickerProviderStateMixin {
  /// Lift of a fully raised star, as a fraction of [PeekRating.size].
  static const double _liftFactor = 0.2;

  /// Extra scale of a fully raised star.
  static const double _liftScale = 0.12;

  /// Padding around the stars, which also holds the focus ring.
  static const double _padding = 4.0;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.55,
  );

  late final Ticker _waveTicker;
  late final AnimationController _popController;
  late final ValueNotifier<int> _waveTick;
  List<_StarSpring> _stars = <_StarSpring>[];
  Duration _elapsed = Duration.zero;
  FocusNode? _ownFocusNode;

  double? _preview;
  int _pointerStar = 0;
  int _popStar = -1;
  bool _reducedMotion = false;
  bool _focusHighlight = false;

  FocusNode get _focusNode => widget.focusNode ?? _ownFocusNode!;

  bool get _interactive =>
      widget.enabled && widget.onChanged != null && !widget.readOnly;

  double get _step => widget.allowHalf ? 0.5 : 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownFocusNode = FocusNode(debugLabel: 'PeekRating');
    }
    _waveTick = ValueNotifier<int>(0);
    _waveTicker = createTicker(_onWaveTick);
    _popController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _syncStarCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) _settleInstantly();
  }

  @override
  void didUpdateWidget(PeekRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (widget.focusNode == null) {
        _ownFocusNode ??= FocusNode(debugLabel: 'PeekRating');
      } else {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
    }
    if (widget.duration != oldWidget.duration) {
      _popController.duration = widget.duration;
    }
    if (widget.count != oldWidget.count) {
      _syncStarCount();
      if (_popStar >= widget.count) _popStar = -1;
    }
    if (!_interactive && _preview != null) {
      _preview = null;
      _retargetWave();
    }
  }

  @override
  void dispose() {
    _waveTicker.dispose();
    _popController.dispose();
    _waveTick.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _syncStarCount() {
    final List<_StarSpring> next = List<_StarSpring>.generate(
      widget.count,
      (int i) => i < _stars.length ? _stars[i] : _StarSpring(),
    );
    _stars = next;
  }

  // ---------------------------------------------------------------------
  // Wave springs.

  void _settleInstantly() {
    if (_waveTicker.isActive) _waveTicker.stop();
    for (final _StarSpring star in _stars) {
      star
        ..value = 0.0
        ..velocity = 0.0
        ..target = 0.0
        ..simulation = null
        ..pendingTarget = null;
    }
    _popController.value = 0.0;
    _popStar = -1;
    _waveTick.value++;
  }

  /// Retargets every star to the current preview, staggered by distance
  /// from the pointer.
  void _retargetWave() {
    if (_reducedMotion) {
      _waveTick.value++;
      return;
    }
    final double? preview = _preview;
    final Duration base = _waveTicker.isActive ? _elapsed : Duration.zero;
    if (!_waveTicker.isActive) _elapsed = Duration.zero;
    bool changed = false;
    for (int i = 0; i < _stars.length; i++) {
      final _StarSpring star = _stars[i];
      final double target = preview != null && i < preview.ceil() ? 1.0 : 0.0;
      final double current = star.pendingTarget ?? star.target;
      if (current == target) continue;
      changed = true;
      final int distance = (i - _pointerStar).abs();
      star
        ..pendingTarget = target
        ..pendingStart = base + widget.waveDelay * distance;
    }
    if (changed && !_waveTicker.isActive) {
      _waveTicker.start();
    }
  }

  void _onWaveTick(Duration elapsed) {
    _elapsed = elapsed;
    bool active = false;
    for (final _StarSpring star in _stars) {
      final double? pending = star.pendingTarget;
      if (pending != null && elapsed >= star.pendingStart) {
        star
          ..simulation = SpringSimulation(
            _spring,
            star.value,
            pending,
            star.velocity,
          )
          ..simulationStart = star.pendingStart
          ..target = pending
          ..pendingTarget = null;
      }
      final SpringSimulation? simulation = star.simulation;
      if (simulation != null) {
        final double t =
            (elapsed - star.simulationStart).inMicroseconds /
            Duration.microsecondsPerSecond;
        if (simulation.isDone(t)) {
          star
            ..value = star.target
            ..velocity = 0.0
            ..simulation = null;
        } else {
          star
            ..value = simulation.x(t)
            ..velocity = simulation.dx(t);
        }
      }
      active = active || star.isActive;
    }
    _waveTick.value++;
    if (!active) _waveTicker.stop();
  }

  // ---------------------------------------------------------------------
  // Input.

  /// Maps a local x position to a rating value.
  double _valueAt(double dx) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double width = _totalWidth;
    // Gesture positions include the padding around the stars.
    final double local = dx - _padding;
    double x = rtl ? width - local : local;
    x = x.clamp(0.0, width - 0.001);
    final double slot = widget.size + widget.spacing;
    final int index = math.min((x / slot).floor(), widget.count - 1);
    final double within = x - index * slot;
    if (widget.allowHalf && within < widget.size / 2) {
      return index + 0.5;
    }
    return index + 1.0;
  }

  double get _totalWidth =>
      widget.count * widget.size + (widget.count - 1) * widget.spacing;

  void _setPreview(double? preview) {
    if (preview != null) {
      _pointerStar = (preview.ceil() - 1).clamp(0, widget.count - 1);
    }
    if (preview == _preview) return;
    setState(() => _preview = preview);
    _retargetWave();
  }

  void _commit(double value) {
    if (!_interactive) return;
    final double clamped = value.clamp(0.0, widget.count.toDouble());
    widget.onChanged?.call(clamped);
    if (_reducedMotion || clamped <= 0) return;
    setState(() => _popStar = clamped.ceil() - 1);
    _popController.forward(from: 0.0);
  }

  void _handleHover(PointerHoverEvent event) {
    if (!_interactive || event.kind == PointerDeviceKind.touch) return;
    _setPreview(_valueAt(event.localPosition.dx));
  }

  void _handleExit(PointerExitEvent event) {
    if (_preview == null) return;
    _setPreview(null);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_interactive) return;
    final double value = _valueAt(details.localPosition.dx);
    _commit(value);
    if (details.kind == PointerDeviceKind.touch) {
      _setPreview(null);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_interactive) return;
    _setPreview(_valueAt(details.localPosition.dx));
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_interactive) return;
    _setPreview(_valueAt(details.localPosition.dx));
  }

  void _handleDragEnd(DragEndDetails details) {
    final double? preview = _preview;
    if (preview != null) _commit(preview);
    _setPreview(null);
  }

  void _handleDragCancel() => _setPreview(null);

  void _increase() =>
      _commit(math.min(widget.count.toDouble(), widget.value + _step));

  void _decrease() => _commit(math.max(0.0, widget.value - _step));

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_interactive) return KeyEventResult.ignored;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final LogicalKeyboardKey key = event.logicalKey;
    final bool forward =
        key == LogicalKeyboardKey.arrowUp ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight);
    final bool backward =
        key == LogicalKeyboardKey.arrowDown ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft);
    if (forward) {
      if (widget.value < widget.count) _increase();
      return KeyEventResult.handled;
    }
    if (backward) {
      if (widget.value > 0) _decrease();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      if (widget.value > 0) _commit(0.0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (widget.value < widget.count) _commit(widget.count.toDouble());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------
  // Building.

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  double _snap(double value) {
    final double step = _step;
    return (value / step).round() * step;
  }

  Widget _buildStar(
    int index,
    double display,
    Color fill,
    Color empty,
    Color sparkle,
  ) {
    final double fraction = (display - index).clamp(0.0, 1.0);
    final double snapped = widget.allowHalf
        ? (fraction >= 1.0 ? 1.0 : (fraction >= 0.5 ? 0.5 : 0.0))
        : (fraction >= 1.0 ? 1.0 : 0.0);
    final _StarSpring spring = _stars[index];
    final double lift = widget.size * _liftFactor;
    final bool popping = index == _popStar;

    final Widget star = CustomPaint(
      size: Size.square(widget.size),
      painter: _StarPainter(
        fill: snapped,
        fillColor: fill,
        emptyColor: empty,
        sparkleColor: sparkle,
        rtl: Directionality.of(context) == TextDirection.rtl,
        pop: popping ? _popController : null,
      ),
    );

    return AnimatedBuilder(
      animation: popping
          ? Listenable.merge(<Listenable>[_waveTick, _popController])
          : _waveTick,
      child: star,
      builder: (BuildContext context, Widget? child) {
        final double v = spring.value;
        double scale = 1.0 + _liftScale * v;
        if (popping) scale *= _popScale(_popController.value);
        return Transform.translate(
          offset: Offset(0.0, -lift * v),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }

  /// Scale multiplier of the pop: a quick swell with overshoot that
  /// settles back to 1.
  static double _popScale(double t) {
    if (t <= 0.0 || t >= 1.0) return 1.0;
    if (t < 0.25) {
      return 1.0 + 0.35 * Curves.easeOut.transform(t / 0.25);
    }
    final double settle = Curves.easeOutBack.transform((t - 0.25) / 0.75);
    return 1.35 - 0.35 * settle;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final Color active =
        widget.activeColor ?? (dark ? _amberDark : _amberLight);
    final Color preview = widget.previewColor ?? active;
    final Color empty =
        widget.inactiveColor ?? scheme.onSurface.withValues(alpha: 0.16);
    final bool interactive = _interactive;
    final double? previewValue = _preview;
    final double display = previewValue ?? widget.value;
    final Color fill = previewValue != null ? preview : active;

    Widget stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < widget.count; i++) ...<Widget>[
          if (i > 0) SizedBox(width: widget.spacing),
          _buildStar(i, display, fill, empty, active),
        ],
      ],
    );

    stars = RepaintBoundary(child: stars);

    if (_focusHighlight) {
      stars = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size / 3),
          border: Border.all(color: scheme.primary, width: 2),
        ),
        child: Padding(padding: const EdgeInsets.all(_padding), child: stars),
      );
    } else {
      stars = Padding(padding: const EdgeInsets.all(_padding), child: stars);
    }

    if (!widget.enabled || (widget.onChanged == null && !widget.readOnly)) {
      stars = Opacity(opacity: 0.5, child: stars);
    }

    if (interactive) {
      stars = MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: _handleHover,
        onExit: _handleExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: _handleDragCancel,
          child: stars,
        ),
      );
    }

    final double value = _snap(widget.value);
    final double step = _step;
    final String count = widget.count.toString();
    return Semantics(
      container: true,
      slider: true,
      enabled: widget.enabled && widget.onChanged != null,
      readOnly: widget.readOnly,
      label: widget.semanticLabel ?? 'Rating',
      value: '${_format(value)} of $count',
      increasedValue: value < widget.count
          ? '${_format(math.min(widget.count.toDouble(), value + step))} of $count'
          : null,
      decreasedValue: value > 0
          ? '${_format(math.max(0.0, value - step))} of $count'
          : null,
      onIncrease: interactive && value < widget.count ? _increase : null,
      onDecrease: interactive && value > 0 ? _decrease : null,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: interactive,
        onKeyEvent: _handleKey,
        onFocusChange: (bool focused) => _updateFocusHighlight(),
        child: ExcludeSemantics(child: stars),
      ),
    );
  }

  void _updateFocusHighlight() {
    final bool show =
        _focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (show != _focusHighlight) setState(() => _focusHighlight = show);
  }
}

/// Paints one star: the empty shape, the (half) fill, and the sparkle ring
/// of a commit pop.
class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.fill,
    required this.fillColor,
    required this.emptyColor,
    required this.sparkleColor,
    required this.rtl,
    required this.pop,
  }) : super(repaint: pop);

  /// Filled fraction: 0, 0.5 or 1.
  final double fill;
  final Color fillColor;
  final Color emptyColor;
  final Color sparkleColor;

  /// Whether a half star fills from the right.
  final bool rtl;
  final Animation<double>? pop;

  static final Map<double, Path> _pathCache = <double, Path>{};

  static Path _starPath(double size) {
    return _pathCache.putIfAbsent(size, () {
      final Path path = Path();
      final double cx = size / 2;
      final double cy = size / 2 + size * 0.03;
      final double outer = size * 0.5;
      final double inner = outer * 0.48;
      // Points with slightly rounded tips via short quadratic joins.
      final List<Offset> points = <Offset>[];
      for (int i = 0; i < 10; i++) {
        final double radius = i.isEven ? outer : inner;
        final double angle = -math.pi / 2 + i * math.pi / 5;
        points.add(
          Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle)),
        );
      }
      const double round = 0.16;
      for (int i = 0; i < points.length; i++) {
        final Offset prev = points[(i - 1 + points.length) % points.length];
        final Offset current = points[i];
        final Offset next = points[(i + 1) % points.length];
        final Offset a = Offset.lerp(current, prev, round)!;
        final Offset b = Offset.lerp(current, next, round)!;
        if (i == 0) {
          path.moveTo(a.dx, a.dy);
        } else {
          path.lineTo(a.dx, a.dy);
        }
        path.quadraticBezierTo(current.dx, current.dy, b.dx, b.dy);
      }
      path.close();
      if (_pathCache.length > 16) _pathCache.clear();
      return path;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Path star = _starPath(s);
    final Paint paint = Paint()..isAntiAlias = true;

    final double t = pop?.value ?? 0.0;
    if (t > 0.0 && t < 1.0) {
      _paintSparkle(canvas, size, t);
    }

    paint.color = emptyColor;
    canvas.drawPath(star, paint);
    if (fill <= 0.0) return;
    paint.color = fillColor;
    if (fill >= 1.0) {
      canvas.drawPath(star, paint);
      return;
    }
    canvas.save();
    canvas.clipRect(
      rtl
          ? Rect.fromLTWH(s * (1 - fill), 0, s * fill, s)
          : Rect.fromLTWH(0, 0, s * fill, s),
    );
    canvas.drawPath(star, paint);
    canvas.restore();
  }

  void _paintSparkle(Canvas canvas, Size size, double t) {
    final Offset center = size.center(Offset.zero);
    final double s = size.shortestSide;
    final double eased = Curves.easeOutCubic.transform(t);
    final double fade = 1.0 - Curves.easeIn.transform(t);
    // Expanding ring.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * fade + 0.5
      ..color = sparkleColor.withValues(alpha: 0.55 * fade);
    canvas.drawCircle(center, s * (0.35 + 0.55 * eased), ring);
    // Small sparks flying outward.
    final Paint spark = Paint()..color = sparkleColor.withValues(alpha: fade);
    const int sparks = 6;
    for (int i = 0; i < sparks; i++) {
      final double angle = -math.pi / 2 + i * 2 * math.pi / sparks;
      final double distance = s * (0.45 + 0.45 * eased);
      final Offset p =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(p, s * 0.05 * fade + 0.5, spark);
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.sparkleColor != sparkleColor ||
      oldDelegate.rtl != rtl ||
      oldDelegate.pop != pop;
}
