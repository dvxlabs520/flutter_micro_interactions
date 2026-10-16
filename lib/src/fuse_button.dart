import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Where the burning fuse of a [FuseButton] runs.
enum FuseTrack {
  /// The fuse runs around the whole border, starting and ending at the
  /// top center. The burning tip travels clockwise (counterclockwise in
  /// right-to-left layouts).
  border,

  /// The fuse is a straight line along the bottom edge that burns from the
  /// end side toward the start side.
  bottom,
}

/// An action button that switches to a "done" state with an Undo option
/// while a thin fuse burns down, and only commits the action when the fuse
/// runs out.
///
/// ```dart
/// FuseButton(
///   onPressed: () => setState(() => hidden = true),
///   onUndo: () => setState(() => hidden = false),
///   onCommit: () => repository.delete(item),
///   doneChild: const Text('Deleted'),
///   child: const Text('Delete'),
/// )
/// ```
///
/// Think "Delete" turning into "Deleted · Undo". Pressing the button calls
/// [onPressed] right away (use it for an optimistic update) and starts the
/// undo window. During [undoWindow] the button shows [doneChild] next to
/// [undoLabel], and a fuse with a glowing spark at its tip burns along
/// [track]. Pressing the button again during the window undoes the action:
/// the button returns to its original state and [onUndo] is called. When
/// the fuse burns out, [onCommit] is called and the button settles into a
/// final done state showing [doneChild], or returns to its original state
/// when [resetAfterCommit] is true. The button width animates smoothly
/// between states.
///
/// With [pauseOnHover] (the default), the fuse stops burning while a mouse
/// pointer hovers the button, and resumes when it leaves. After a mouse
/// click the pointer is usually still over the button, so the fuse starts
/// burning once the pointer moves away.
///
/// If the widget is removed from the tree during the undo window, neither
/// [onCommit] nor [onUndo] is called. Commit the action yourself in that
/// case if it must not be lost.
///
/// Accessibility: the button is exposed as a button whose label is the
/// visible content. While the undo window is open it is a live region, so
/// screen readers announce the done state and the Undo option, and
/// activating it undoes the action. It can be focused and activated with
/// Enter or Space; Escape also undoes during the window. Keyboard focus
/// shows a ring, and the button is at least 48 pixels tall.
///
/// When [onPressed] is null or [enabled] is false the button renders
/// dimmed and ignores input. Under reduced motion, state changes are
/// instant and the fuse is drawn as a thin static bar that shrinks without
/// the moving spark and glow; the undo window and the callbacks work the
/// same way.
class FuseButton extends StatefulWidget {
  /// Creates a fuse button.
  const FuseButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.onCommit,
    this.onUndo,
    this.undoWindow = const Duration(seconds: 5),
    this.doneChild,
    this.undoLabel,
    this.resetAfterCommit = false,
    this.track = FuseTrack.border,
    this.backgroundColor,
    this.foregroundColor,
    this.doneBackgroundColor,
    this.doneForegroundColor,
    this.fuseColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
    this.pauseOnHover = true,
    this.enableHaptics = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(
         undoWindow > Duration.zero,
         'undoWindow must be longer than zero',
       );

  /// The content of the button in its original state, typically a [Text].
  final Widget child;

  /// Called right away when the button is pressed, before the undo window
  /// starts. When null the button renders disabled.
  final VoidCallback? onPressed;

  /// Called once when the fuse burns out without an undo.
  final VoidCallback onCommit;

  /// Called when the action is undone during the undo window.
  final VoidCallback? onUndo;

  /// How long the user can undo the action. Defaults to 5 seconds.
  final Duration undoWindow;

  /// Content shown once the button was pressed, for example
  /// `Text('Deleted')`. Defaults to a `Text('Done')`.
  final Widget? doneChild;

  /// The Undo affordance shown next to [doneChild] during the undo window.
  /// Defaults to an undo icon followed by `Text('Undo')`.
  final Widget? undoLabel;

  /// When true the button returns to its original state after committing
  /// instead of staying in the final done state. Defaults to false.
  final bool resetAfterCommit;

  /// Where the fuse runs. Defaults to [FuseTrack.border].
  final FuseTrack track;

  /// Background color in the original state. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? backgroundColor;

  /// Text and icon color in the original state. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? foregroundColor;

  /// Background color in the done states. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? doneBackgroundColor;

  /// Text and icon color in the done states. Defaults to the theme's
  /// `colorScheme.onSurface`.
  final Color? doneForegroundColor;

  /// Color of the fuse and its spark. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? fuseColor;

  /// Corner radius of the button. When null (the default) the button is a
  /// stadium (fully rounded ends).
  final BorderRadius? borderRadius;

  /// Padding around the content. Defaults to 20 horizontal by 12
  /// vertical.
  final EdgeInsetsGeometry padding;

  /// Length of the state change animations (width, colors, content).
  /// Defaults to 320 milliseconds.
  final Duration duration;

  /// Curve of the state change animations. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// Whether the fuse stops burning while a mouse pointer hovers the
  /// button. Defaults to true.
  final bool pauseOnHover;

  /// Whether haptic feedback is played on press and on undo. Defaults to
  /// true.
  final bool enableHaptics;

  /// When false the button renders dimmed and ignores input, exactly as if
  /// [onPressed] were null. A running undo window keeps burning.
  final bool enabled;

  /// Optional semantic label announced for the button in its original
  /// state, replacing the label taken from [child].
  final String? semanticLabel;

  @override
  State<FuseButton> createState() => _FuseButtonState();
}

/// The three states of a [FuseButton].
enum _FuseState { idle, pending, done }

class _FuseButtonState extends State<FuseButton> with TickerProviderStateMixin {
  /// Remaining part of the undo window, from 1 (full) down to 0.
  late final AnimationController _fuse;
  late final AnimationController _press;
  late final Animation<double> _pressScale;
  _FuseState _state = _FuseState.idle;
  bool _hovered = false;
  bool _focused = false;
  bool _reducedMotion = false;

  bool get _interactive =>
      widget.enabled && widget.onPressed != null && _state != _FuseState.done;

  bool get _paused => widget.pauseOnHover && _hovered;

  @override
  void initState() {
    super.initState();
    _fuse = AnimationController(
      vsync: this,
      duration: widget.undoWindow,
      value: 1.0,
    )..addStatusListener(_onFuseStatus);
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pressScale = _press.drive(
      Tween<double>(
        begin: 1.0,
        end: 0.97,
      ).chain(CurveTween(curve: Curves.easeOut)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _press.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(FuseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.undoWindow != oldWidget.undoWindow) {
      _fuse.duration = widget.undoWindow;
      if (_fuse.isAnimating) {
        // Restart from the current fraction so the new window applies.
        _fuse.reverse(from: _fuse.value);
      }
    }
    if (widget.pauseOnHover != oldWidget.pauseOnHover) {
      _syncFuse();
    }
    if (!_interactive) {
      _press.value = 0.0;
    }
  }

  @override
  void dispose() {
    _fuse.removeStatusListener(_onFuseStatus);
    _fuse.dispose();
    _press.dispose();
    super.dispose();
  }

  /// Runs or pauses the fuse to match the hover state.
  void _syncFuse() {
    if (_state != _FuseState.pending) return;
    if (_paused) {
      _fuse.stop();
    } else if (!_fuse.isAnimating && _fuse.value > 0.0) {
      _fuse.reverse();
    }
  }

  void _onFuseStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _state == _FuseState.pending) {
      _commit();
    }
  }

  void _commit() {
    if (!mounted) return;
    setState(() {
      _state = widget.resetAfterCommit ? _FuseState.idle : _FuseState.done;
    });
    _fuse.value = 1.0;
    widget.onCommit();
  }

  void _start() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
    if (!mounted) return;
    setState(() => _state = _FuseState.pending);
    _fuse.value = 1.0;
    _syncFuse();
  }

  void _undo() {
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    _fuse.stop();
    _fuse.value = 1.0;
    setState(() => _state = _FuseState.idle);
    widget.onUndo?.call();
  }

  void _activate() {
    if (!_interactive) return;
    if (_state == _FuseState.idle) {
      _start();
    } else if (_state == _FuseState.pending) {
      _undo();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_interactive || _reducedMotion) return;
    _press.forward();
  }

  void _handleTapUp(TapUpDetails details) {
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

  void _handleHover(bool hovered) {
    if (hovered == _hovered) return;
    _hovered = hovered;
    _syncFuse();
  }

  ShapeBorder _shape({BorderSide side = BorderSide.none}) {
    final BorderRadius? radius = widget.borderRadius;
    return radius == null
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(borderRadius: radius, side: side);
  }

  Widget _content(Color foreground) {
    final Widget body;
    switch (_state) {
      case _FuseState.idle:
        body = widget.child;
      case _FuseState.done:
        body = widget.doneChild ?? const Text('Done');
      case _FuseState.pending:
        body = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            widget.doneChild ?? const Text('Done'),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: SizedBox(
                width: 1,
                height: 16,
                child: ColoredBox(color: foreground.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(width: 10),
            DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w700),
              child:
                  widget.undoLabel ??
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.undo_rounded, size: 18),
                      SizedBox(width: 4),
                      Text('Undo'),
                    ],
                  ),
            ),
          ],
        );
    }
    // The key sits on the outermost widget so AnimatedSwitcher sees a new
    // child for every state.
    return KeyedSubtree(
      key: ValueKey<_FuseState>(_state),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 18),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool idle = _state == _FuseState.idle;
    final Color background = idle
        ? widget.backgroundColor ?? scheme.primary
        : widget.doneBackgroundColor ?? scheme.surfaceContainerHighest;
    final Color foreground = idle
        ? widget.foregroundColor ?? scheme.onPrimary
        : widget.doneForegroundColor ?? scheme.onSurface;
    final Color fuseColor = widget.fuseColor ?? scheme.primary;
    final Duration duration = _reducedMotion ? Duration.zero : widget.duration;
    final ValueKey<_FuseState> currentKey = ValueKey<_FuseState>(_state);

    final Widget switcher = AnimatedSwitcher(
      duration: duration,
      // The new content fades in once the width has mostly caught up,
      // and the old content fades out quickly, so clipping during the
      // resize is barely visible.
      switchInCurve: Interval(0.3, 1.0, curve: widget.curve),
      switchOutCurve: Interval(0.5, 1.0, curve: widget.curve),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.center,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool incoming = child.key == currentKey;
        return ExcludeSemantics(
          excluding: !incoming,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.0, incoming ? 0.35 : -0.35),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: _content(foreground),
    );

    // AnimatedSize asserts with a zero duration, so it is skipped then.
    Widget label = duration == Duration.zero
        ? switcher
        : AnimatedSize(
            duration: duration,
            curve: widget.curve,
            child: switcher,
          );

    label = DefaultTextStyle.merge(
      style: theme.textTheme.labelLarge,
      child: Padding(padding: widget.padding, child: label),
    );

    Widget surface = AnimatedContainer(
      duration: duration,
      curve: widget.curve,
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 64.0),
      decoration: ShapeDecoration(color: background, shape: _shape()),
      child: Center(widthFactor: 1.0, heightFactor: 1.0, child: label),
    );

    // The Stack is always present so the surface keeps its animation
    // state when the fuse layer comes and goes.
    surface = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        surface,
        if (_state == _FuseState.pending)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _FusePainter(
                      remaining: _fuse,
                      color: fuseColor,
                      track: widget.track,
                      borderRadius: widget.borderRadius,
                      spark: !_reducedMotion,
                      window: widget.undoWindow,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    surface = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: _shape(
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
      child: surface,
    );

    surface = ScaleTransition(scale: _pressScale, child: surface);

    final bool interactive = _interactive;
    final bool pending = _state == _FuseState.pending;
    final bool dimmed = !interactive && _state != _FuseState.done;

    // The widget structure stays the same in every state so the width and
    // color animations survive state changes.
    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      liveRegion: pending,
      label: idle ? widget.semanticLabel : null,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: FocusableActionDetector(
          enabled: interactive,
          mouseCursor: interactive
              ? SystemMouseCursors.click
              : MouseCursor.defer,
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
            if (pending)
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _undo();
                  return null;
                },
              ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: interactive ? _handleTapDown : null,
            onTapUp: interactive ? _handleTapUp : null,
            onTapCancel: interactive ? _handleTapCancel : null,
            child: Opacity(
              opacity: dimmed ? 0.5 : 1.0,
              child: ExcludeSemantics(
                excluding: idle && widget.semanticLabel != null,
                child: surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the fuse: a faint full track, the unburnt remainder and, unless
/// reduced, a glowing spark with a few embers at the burning tip.
class _FusePainter extends CustomPainter {
  _FusePainter({
    required this.remaining,
    required this.color,
    required this.track,
    required this.borderRadius,
    required this.spark,
    required this.window,
    required this.textDirection,
  }) : super(repaint: remaining);

  final Animation<double> remaining;
  final Color color;
  final FuseTrack track;
  final BorderRadius? borderRadius;
  final bool spark;
  final Duration window;
  final TextDirection textDirection;

  /// Stroke width of the fuse.
  static const double _stroke = 2.0;

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = _stroke;

  Size? _cachedSize;
  ui.PathMetric? _metric;

  /// The fuse path for [size], starting at the burning start point.
  ui.PathMetric _metricFor(Size size) {
    final ui.PathMetric? cached = _metric;
    if (cached != null && _cachedSize == size) {
      return cached;
    }
    final Path path = Path();
    if (track == FuseTrack.bottom) {
      final double inset = math.min(size.height / 2.0, size.width / 4.0);
      final double y = size.height - _stroke * 1.5;
      // Burns from the end side toward the start side.
      path
        ..moveTo(size.width - inset, y)
        ..lineTo(inset, y);
    } else {
      const double half = _stroke / 2.0 + 1.0;
      final Rect rect = (Offset.zero & size).deflate(half);
      final double r = math
          .min(
            borderRadius == null
                ? rect.height / 2.0
                : borderRadius!.topRight.x - half,
            math.min(rect.width, rect.height) / 2.0,
          )
          .clamp(0.0, double.infinity);
      final Radius radius = Radius.circular(r);
      path
        ..moveTo(rect.center.dx, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r), radius: radius)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: radius)
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: radius)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.left + r, rect.top), radius: radius)
        ..lineTo(rect.center.dx, rect.top);
    }
    final ui.PathMetric metric = path.computeMetrics().first;
    _cachedSize = size;
    _metric = metric;
    return metric;
  }

  /// A stable pseudo random number in 0..1 for [seed].
  static double _hash(int seed) {
    final double x = math.sin(seed * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double left = remaining.value.clamp(0.0, 1.0);
    canvas.save();
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0.0);
      canvas.scale(-1.0, 1.0);
    }
    final ui.PathMetric metric = _metricFor(size);
    final double length = metric.length;
    final double tipAt = (1.0 - left) * length;

    _paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: color.a * 0.18);
    canvas.drawPath(metric.extractPath(0.0, length), _paint);

    if (left > 0.0) {
      _paint.color = color;
      canvas.drawPath(metric.extractPath(tipAt, length), _paint);
    }

    if (spark && left > 0.0 && left < 1.0) {
      final ui.Tangent? tangent = metric.getTangentForOffset(tipAt);
      if (tangent != null) {
        _paintSpark(canvas, tangent.position);
      }
    }
    canvas.restore();
  }

  void _paintSpark(Canvas canvas, Offset tip) {
    final double seconds =
        (1.0 - remaining.value) * window.inMicroseconds / 1e6;
    final double flicker = 1.0 + 0.18 * math.sin(seconds * 47.0);
    final double glow = 7.0 * flicker;
    const Color hot = Color(0xFFFFFFFF);
    _paint
      ..style = PaintingStyle.fill
      ..color = color
      ..shader = ui.Gradient.radial(
        tip,
        glow,
        <Color>[
          hot.withValues(alpha: 0.95),
          color.withValues(alpha: 0.75),
          color.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.3, 1.0],
      );
    canvas.drawCircle(tip, glow, _paint);
    _paint.shader = null;

    // Embers: short lived dots thrown out from the tip.
    const int embers = 3;
    const double rate = 7.0;
    for (int i = 0; i < embers; i++) {
      final double cycle = seconds * rate + i / embers;
      final int seed = cycle.floor() * embers + i;
      final double life = cycle - cycle.floorToDouble();
      final double angle = _hash(seed) * 2.0 * math.pi;
      final double distance = 2.0 + life * (5.0 + 4.0 * _hash(seed + 7));
      _paint.color = Color.lerp(
        hot,
        color,
        life,
      )!.withValues(alpha: (1.0 - life) * 0.9);
      canvas.drawCircle(
        tip + Offset(math.cos(angle), math.sin(angle)) * distance,
        1.1 * (1.0 - life * 0.5),
        _paint,
      );
    }
    _paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(_FusePainter oldDelegate) =>
      oldDelegate.remaining != remaining ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.spark != spark ||
      oldDelegate.window != window ||
      oldDelegate.textDirection != textDirection;
}
