import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A like button whose heart collapses to a dot, changes color, then
/// pulses back out with a ring burst and a few particles.
///
/// ```dart
/// PulseHeart(
///   liked: isLiked,
///   count: likeCount,
///   onChanged: (bool liked) => setState(() {
///     isLiked = liked;
///     likeCount += liked ? 1 : -1;
///   }),
/// )
/// ```
///
/// The widget is controlled: tapping it calls [onChanged] with the
/// opposite of [liked], and the parent rebuilds it with the new value.
/// Every change of [liked] is animated, including changes that do not
/// come from a tap (for example a value loaded from a server).
///
/// Liking plays three short steps: the outline heart shrinks to a dot,
/// the dot takes [likedColor], and a filled heart pulses back out past
/// its resting size before settling. A ring and a few small particles
/// burst around it when [burst] is true. Unliking plays a quick shrink
/// and returns to the outline. When [count] is given and [showCount] is
/// true, the number rolls vertically to its new value: up when it grows,
/// down when it shrinks.
///
/// Accessibility: the widget is a single toggle button with
/// [semanticLabel] as its label, the like state as its toggled state and
/// the count as its value. It can be focused and activated with Enter or
/// Space, shows a focus ring when focused with the keyboard, and keeps a
/// touch target of at least 48 by 48 pixels.
///
/// When [onChanged] is null or [enabled] is false the button is dimmed
/// and ignores input. Under reduced motion the heart and the count change
/// instantly with no burst, and the button still works.
class PulseHeart extends StatefulWidget {
  /// Creates a pulse heart like button.
  const PulseHeart({
    super.key,
    required this.liked,
    required this.onChanged,
    this.count,
    this.size = 28.0,
    this.likedColor,
    this.color,
    this.showCount = true,
    this.countStyle,
    this.burst = true,
    this.duration = const Duration(milliseconds: 700),
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel = 'Like',
  }) : assert(size > 0.0, 'size must be positive'),
       assert(count == null || count >= 0, 'count must not be negative');

  /// Whether the heart is currently liked (filled).
  final bool liked;

  /// Called with the requested new state when the button is activated.
  /// When null the button renders disabled.
  final ValueChanged<bool>? onChanged;

  /// Optional number rendered next to the heart, for example the number
  /// of likes. The parent owns it and updates it together with [liked].
  final int? count;

  /// Size of the heart in logical pixels. Defaults to 28. The touch target
  /// is never smaller than 48 by 48 pixels.
  final double size;

  /// Fill color of the liked heart, the ring and the particles. Defaults
  /// to a red tuned for the current theme brightness.
  final Color? likedColor;

  /// Color of the outline heart when not liked. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant`.
  final Color? color;

  /// Whether [count] is rendered. Defaults to true. Has no effect when
  /// [count] is null.
  final bool showCount;

  /// Text style of the count. Defaults to the theme's `labelLarge` style
  /// colored like the heart.
  final TextStyle? countStyle;

  /// Whether liking plays the ring burst and particles. Defaults to true.
  final bool burst;

  /// Length of the like animation. The unlike animation and the count
  /// roll use a fraction of it. Defaults to 700 milliseconds.
  final Duration duration;

  /// Whether a light haptic impact is played when the button is
  /// activated. Defaults to true.
  final bool enableHaptics;

  /// When false the button renders dimmed and ignores input, exactly as if
  /// [onChanged] were null.
  final bool enabled;

  /// Label announced by assistive technology. Defaults to `'Like'`.
  final String semanticLabel;

  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

/// Which animation the heart controller is currently playing.
enum _HeartPhase { idle, liking, unliking }

class _PulseHeartState extends State<PulseHeart> with TickerProviderStateMixin {
  late final AnimationController _heart;
  late final AnimationController _press;
  late final Animation<double> _pressScale;
  _HeartPhase _phase = _HeartPhase.idle;
  bool _focused = false;
  bool _reducedMotion = false;

  /// The count currently rendered. While liking, a new count waits until
  /// the heart pulses back out so the number lands with the pulse.
  int? _shownCount;

  /// A count waiting for the pulse, or null.
  int? _pendingCount;

  /// Point of the like animation at which a pending count is shown.
  static const double _countReveal = 0.3;

  /// Share of [PulseHeart.duration] used by the unlike animation.
  static const double _unlikeFactor = 0.4;

  /// Ratio between the painted square and the heart size, so the burst
  /// fits inside the widget bounds.
  static const double _canvasFactor = 1.8;

  /// How far the count is pulled into the heart canvas, as a fraction of
  /// the heart size.
  static const double _countPull = 0.1;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _shownCount = widget.count;
    _heart = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onHeartStatus)
      ..addListener(_onHeartTick);
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pressScale = _press.drive(
      Tween<double>(
        begin: 1.0,
        end: 0.86,
      ).chain(CurveTween(curve: Curves.easeOut)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _stopAll();
    }
  }

  @override
  void didUpdateWidget(PulseHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked != oldWidget.liked) {
      _play(widget.liked);
    }
    if (widget.count != oldWidget.count) {
      if (_phase == _HeartPhase.liking && _heart.value < _countReveal) {
        _pendingCount = widget.count;
      } else {
        _pendingCount = null;
        _shownCount = widget.count;
      }
    }
    if (widget.duration != oldWidget.duration && _phase == _HeartPhase.idle) {
      _heart.duration = widget.duration;
    }
    final bool wasInteractive =
        oldWidget.enabled && oldWidget.onChanged != null;
    if (wasInteractive && !_interactive) {
      _press.value = 0.0;
    }
  }

  @override
  void dispose() {
    _heart.removeStatusListener(_onHeartStatus);
    _heart.removeListener(_onHeartTick);
    _heart.dispose();
    _press.dispose();
    super.dispose();
  }

  /// Shows a pending count once the like animation reaches the pulse.
  void _onHeartTick() {
    if (_pendingCount != null && _heart.value >= _countReveal) {
      _flushCount();
    }
  }

  void _flushCount() {
    if (_pendingCount == null) return;
    setState(() {
      _shownCount = _pendingCount;
      _pendingCount = null;
    });
  }

  void _stopAll() {
    if (_pendingCount != null) {
      _shownCount = _pendingCount;
      _pendingCount = null;
    }
    _heart.stop();
    _heart.value = 0.0;
    _press.stop();
    _press.value = 0.0;
    _phase = _HeartPhase.idle;
  }

  void _onHeartStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _phase = _HeartPhase.idle;
        if (_pendingCount != null) {
          _shownCount = _pendingCount;
          _pendingCount = null;
        }
      });
      _heart.value = 0.0;
    }
  }

  /// Plays the like or unlike animation toward [liked]. Only called from
  /// [didUpdateWidget].
  void _play(bool liked) {
    if (_reducedMotion || !widget.enabled) {
      _stopAll();
      return;
    }
    // Called from didUpdateWidget, so a rebuild is already scheduled.
    _phase = liked ? _HeartPhase.liking : _HeartPhase.unliking;
    _heart.duration = liked ? widget.duration : widget.duration * _unlikeFactor;
    _heart.forward(from: 0.0);
  }

  void _activate() {
    if (!_interactive) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onChanged?.call(!widget.liked);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_interactive || _reducedMotion) return;
    _press.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_interactive) return;
    _activate();
    if (!_reducedMotion) {
      _press.reverse();
    }
  }

  void _handleTapCancel() {
    if (!_reducedMotion) {
      _press.reverse();
    }
  }

  static Color _defaultLikedColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFFF5C7A)
      : const Color(0xFFE5294D);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color likedColor =
        widget.likedColor ?? _defaultLikedColor(scheme.brightness);
    final Color outlineColor = widget.color ?? scheme.onSurfaceVariant;
    final bool interactive = _interactive;
    final double canvas = widget.size * _canvasFactor;

    Widget heart = SizedBox.square(
      dimension: canvas,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PulseHeartPainter(
            progress: _heart,
            phase: _phase,
            liked: widget.liked,
            heartSize: widget.size,
            likedColor: likedColor,
            outlineColor: outlineColor,
            burst: widget.burst,
          ),
        ),
      ),
    );
    heart = ScaleTransition(scale: _pressScale, child: heart);

    final int? count = widget.count;
    final bool showCount = count != null && widget.showCount;
    Widget content = heart;
    if (showCount) {
      final TextStyle style = (theme.textTheme.labelLarge ?? const TextStyle())
          .copyWith(
            color: widget.liked && _pendingCount == null
                ? likedColor
                : outlineColor,
            fontWeight: FontWeight.w600,
          )
          .merge(widget.countStyle)
          .copyWith(
            height: 1.0,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          );
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          heart,
          // The heart canvas leaves room for the burst around the glyph,
          // so pull the count slightly toward it.
          Transform.translate(
            offset: Offset(-widget.size * _countPull, 0.0),
            child: _RollingCount(
              style: style,
              value: _shownCount ?? count,
              duration: widget.duration * 0.5,
              animate: widget.enabled && !_reducedMotion,
            ),
          ),
          SizedBox(width: widget.size * (0.12 - _countPull).clamp(0.0, 1.0)),
        ],
      );
    }

    content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
      child: Center(widthFactor: 1.0, heightFactor: 1.0, child: content),
    );

    content = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: _focused
              ? BorderSide(color: scheme.primary, width: 2.0)
              : BorderSide.none,
        ),
      ),
      child: ExcludeSemantics(child: content),
    );

    // The structure stays the same when the button is enabled or disabled
    // so running animations keep their state.
    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      toggled: widget.liked,
      label: widget.semanticLabel,
      value: showCount ? '$count' : null,
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
          onTapDown: interactive ? _handleTapDown : null,
          onTapUp: interactive ? _handleTapUp : null,
          onTapCancel: interactive ? _handleTapCancel : null,
          child: Opacity(opacity: interactive ? 1.0 : 0.5, child: content),
        ),
      ),
    );
  }
}

/// Paints the heart, the dot, the ring burst and the particles.
class _PulseHeartPainter extends CustomPainter {
  _PulseHeartPainter({
    required this.progress,
    required this.phase,
    required this.liked,
    required this.heartSize,
    required this.likedColor,
    required this.outlineColor,
    required this.burst,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final _HeartPhase phase;
  final bool liked;
  final double heartSize;
  final Color likedColor;
  final Color outlineColor;
  final bool burst;

  /// Number of particles in the burst.
  static const int _particleCount = 7;

  /// Shared paint object reused across paints.
  final Paint _paint = Paint()..isAntiAlias = true;

  /// The heart outline, built once per painter.
  late final Path _path = _heartPath(heartSize);

  /// The heart outline for a square of side [s] centered on the origin.
  static Path _heartPath(double s) {
    final double u = s / 24.0;
    // Designed on a 24 unit grid with the shape centered at (12, 12).
    Offset p(double x, double y) => Offset((x - 12.0) * u, (y - 12.0) * u);
    final Offset tip = p(12.0, 20.8);
    final Offset l1 = p(7.6, 17.6);
    final Offset l2 = p(2.4, 13.6);
    final Offset left = p(2.4, 8.7);
    final Offset l3 = p(2.4, 5.6);
    final Offset l4 = p(4.8, 3.3);
    final Offset topLeft = p(7.6, 3.3);
    final Offset l5 = p(9.5, 3.3);
    final Offset l6 = p(11.1, 4.4);
    final Offset notch = p(12.0, 6.0);
    final Path path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(l1.dx, l1.dy, l2.dx, l2.dy, left.dx, left.dy)
      ..cubicTo(l3.dx, l3.dy, l4.dx, l4.dy, topLeft.dx, topLeft.dy)
      ..cubicTo(l5.dx, l5.dy, l6.dx, l6.dy, notch.dx, notch.dy)
      ..cubicTo(-l6.dx, l6.dy, -l5.dx, l5.dy, -topLeft.dx, topLeft.dy)
      ..cubicTo(-l4.dx, l4.dy, -l3.dx, l3.dy, -left.dx, left.dy)
      ..cubicTo(-l2.dx, l2.dy, -l1.dx, l1.dy, tip.dx, tip.dy)
      ..close();
    return path;
  }

  /// Maps [t] into the [begin]..[end] interval, clamped to 0..1.
  static double _interval(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  void _drawHeart(
    Canvas canvas,
    Offset center,
    double scale,
    Color color, {
    required bool filled,
  }) {
    if (scale <= 0.001) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    _paint
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = heartSize / 12.0 / scale.clamp(0.6, 2.0)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path, _paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double t = progress.value;
    switch (phase) {
      case _HeartPhase.idle:
        _drawHeart(
          canvas,
          center,
          1.0,
          liked ? likedColor : outlineColor,
          filled: liked,
        );
      case _HeartPhase.unliking:
        // Filled heart shrinks, then the outline grows back.
        if (t < 0.45) {
          final double a = Curves.easeIn.transform(_interval(t, 0.0, 0.45));
          _drawHeart(
            canvas,
            center,
            1.0 - 0.3 * a,
            likedColor.withValues(alpha: likedColor.a * (1.0 - 0.6 * a)),
            filled: true,
          );
        } else {
          final double b = Curves.easeOutBack.transform(
            _interval(t, 0.45, 1.0),
          );
          _drawHeart(
            canvas,
            center,
            0.7 + 0.3 * b,
            outlineColor,
            filled: false,
          );
        }
      case _HeartPhase.liking:
        _paintLiking(canvas, center, t);
    }
  }

  void _paintLiking(Canvas canvas, Offset center, double t) {
    // Step 1: the outline collapses toward the center.
    final double collapse = Curves.easeInCubic.transform(
      _interval(t, 0.0, 0.18),
    );
    if (collapse < 1.0) {
      _drawHeart(canvas, center, 1.0 - collapse, outlineColor, filled: false);
    }

    // Step 2: a dot appears and takes the liked color.
    if (t > 0.1 && t < 0.36) {
      final double grow = Curves.easeOut.transform(_interval(t, 0.1, 0.2));
      final double fade = 1.0 - _interval(t, 0.3, 0.36);
      final Color dotColor = Color.lerp(
        outlineColor,
        likedColor,
        Curves.easeInOut.transform(_interval(t, 0.16, 0.28)),
      )!;
      _paint
        ..style = PaintingStyle.fill
        ..color = dotColor.withValues(alpha: dotColor.a * fade);
      canvas.drawCircle(center, heartSize * 0.12 * grow, _paint);
    }

    // Ring burst: a filled disc that expands and hollows out.
    if (burst && t > 0.28 && t < 0.78) {
      final double c = _interval(t, 0.28, 0.78);
      final double radius =
          heartSize * (0.25 + 0.5 * Curves.easeOutCubic.transform(c));
      final double width = radius * math.pow(1.0 - c, 2.2).toDouble();
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = likedColor.withValues(alpha: likedColor.a * (0.6 - 0.3 * c));
      canvas.drawCircle(center, radius - width / 2.0, _paint);
    }

    // Particles: two dots per spoke drift outward and shrink.
    if (burst && t > 0.4) {
      final double d = _interval(t, 0.4, 1.0);
      final double travel = Curves.easeOutCubic.transform(d);
      final double shrink = 1.0 - Curves.easeIn.transform(d);
      final Color light = Color.lerp(likedColor, const Color(0xFFFFFFFF), 0.4)!;
      _paint.style = PaintingStyle.fill;
      for (int i = 0; i < _particleCount; i++) {
        final double angle =
            -math.pi / 2.0 + i * 2.0 * math.pi / _particleCount;
        final double distance = heartSize * (0.55 + 0.27 * travel);
        _paint.color = likedColor;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * distance,
          heartSize * 0.06 * shrink,
          _paint,
        );
        final double companion = angle + 0.32;
        _paint.color = light;
        canvas.drawCircle(
          center +
              Offset(math.cos(companion), math.sin(companion)) *
                  (distance * 0.86),
          heartSize * 0.04 * shrink,
          _paint,
        );
      }
    }

    // Step 3: the filled heart pulses out past its size and settles.
    if (t > 0.28) {
      final double b = _interval(t, 0.28, 1.0);
      final double wobble =
          math.exp(-3.0 * b) * (1.0 - b) * math.cos(3.0 * math.pi * b);
      final double scale = 1.0 - 0.8 * wobble;
      _drawHeart(canvas, center, scale, likedColor, filled: true);
    }
  }

  @override
  bool shouldRepaint(_PulseHeartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.liked != liked ||
      oldDelegate.heartSize != heartSize ||
      oldDelegate.likedColor != likedColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.burst != burst;
}

/// A number that rolls vertically to its new value: the old value leaves
/// upward while the new one enters from below when it grows, and the
/// opposite when it shrinks.
class _RollingCount extends StatefulWidget {
  const _RollingCount({
    required this.value,
    required this.style,
    required this.duration,
    required this.animate,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final bool animate;

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  bool _increasing = true;

  @override
  void didUpdateWidget(_RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _increasing = widget.value > oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = widget.animate ? widget.duration : Duration.zero;
    final double enterFrom = _increasing ? 1.0 : -1.0;
    final ValueKey<int> currentKey = ValueKey<int>(widget.value);
    final Widget switcher = AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[...previous, if (current != null) current],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool incoming = child.key == currentKey;
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.0, incoming ? enterFrom : -enterFrom),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text('${widget.value}', key: currentKey, style: widget.style),
    );
    // AnimatedSize asserts with a zero duration, so it is skipped then.
    return ClipRect(
      child: duration == Duration.zero
          ? switcher
          : AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.centerStart,
              child: switcher,
            ),
    );
  }
}
