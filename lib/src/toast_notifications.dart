import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'utils/motion.dart';

/// Semantic style of a toast, controlling its default colors and icon.
enum ToastType {
  /// A confirmation message. Green background, light foreground.
  success,

  /// An error message. Uses `colorScheme.error` colors.
  error,

  /// A neutral message. Uses `colorScheme.inverseSurface` colors, like
  /// [SnackBar].
  info,

  /// A warning message. Orange background with a dark foreground for
  /// contrast.
  warning,
}

/// Where a toast is placed on screen.
enum ToastPosition {
  /// Below the top safe area.
  top,

  /// Above the bottom safe area.
  bottom,

  /// Vertically centered.
  center,
}

/// Overlay based toast notifications.
///
/// Toasts are inserted into the root [Overlay], animate in and out, dismiss
/// themselves after [ToastNotification.show]'s `duration`, and can be closed
/// early with the close button, by tapping (when `dismissOnTap` is `true`),
/// by swiping (when `swipeToDismiss` is `true`, the default) or through the
/// optional action button.
///
/// ```dart
/// ToastNotification.show(
///   context: context,
///   message: 'Profile saved',
///   type: ToastType.success,
/// );
/// ```
///
/// Or with the [BuildContext] extension:
///
/// ```dart
/// context.showToast(message: 'Profile saved', type: ToastType.success);
/// ```
///
/// Swipe to dismiss: a toast can be dragged horizontally, or vertically
/// towards the screen edge it is attached to ([ToastPosition.top] upwards,
/// [ToastPosition.bottom] downwards; center toasts only swipe
/// horizontally). Releasing past 40% of the toast's extent, or flinging
/// fast enough, sends it off screen; otherwise it springs back.
///
/// Countdown: with `showProgress` a thin "fuse" bar along the bottom edge
/// shrinks over the remaining time. With `pauseOnHover` (the default),
/// hovering the toast with a mouse or pressing it pauses the countdown and
/// the fuse, and both resume where they left off once the pointer leaves
/// or lifts.
///
/// ```dart
/// context.showToast(
///   message: 'Message archived',
///   showProgress: true,
///   duration: const Duration(seconds: 5),
/// );
/// ```
///
/// Stacking: multiple simultaneous toasts at the same [ToastPosition] stack
/// with a fixed vertical offset per toast; the oldest toast sits closest to
/// the screen edge and remaining toasts slide back into place when one is
/// dismissed.
///
/// Accessibility: the message is announced through
/// [SemanticsService.sendAnnouncement], the toast content is a live region,
/// and the close button has a semantic label. When `swipeToDismiss` is
/// `true` the toast also exposes the semantic dismiss action, so assistive
/// technology can close it without the gesture.
///
/// Reduced motion: toasts appear and disappear instantly (no slide or fade
/// animation), a swipe past the threshold removes the toast immediately,
/// and the progress fuse is not shown (the countdown still runs and still
/// pauses on hover or press).
abstract final class ToastNotification {
  /// Shows a toast above the current route.
  ///
  /// [message] is the text to display. [duration] is how long the toast
  /// stays visible before dismissing itself; pass [Duration.zero] to keep it
  /// on screen until the user dismisses it.
  ///
  /// Visual overrides ([backgroundColor], [foregroundColor], [icon],
  /// [textStyle], [borderRadius], [padding], [elevation]) fall back to
  /// theme-aware defaults derived from [type].
  ///
  /// [actionLabel] and [onAction] add a text button; pressing it runs
  /// [onAction] and dismisses the toast. [dismissOnTap] dismisses the toast
  /// when its body is tapped. [showCloseButton] controls the trailing close
  /// button. [onDismiss] runs once when the toast leaves the screen, no
  /// matter how it was dismissed.
  ///
  /// [swipeToDismiss] (default `true`) lets the user swipe the toast away
  /// horizontally, or vertically towards its screen edge, with
  /// velocity-aware flings. [showProgress] (default `false`) draws a thin
  /// fuse bar along the bottom edge that shrinks over the remaining
  /// [duration]; it has no effect when [duration] is [Duration.zero].
  /// [pauseOnHover] (default `true`) pauses the countdown, and the fuse,
  /// while a mouse hovers the toast or a pointer is pressed on it.
  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 250),
    Color? backgroundColor,
    Color? foregroundColor,
    IconData? icon,
    TextStyle? textStyle,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    double elevation = 4.0,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissOnTap = false,
    bool showCloseButton = true,
    VoidCallback? onDismiss,
    bool swipeToDismiss = true,
    bool showProgress = false,
    bool pauseOnHover = true,
  }) {
    assert(duration >= Duration.zero, 'duration must not be negative');
    assert(
      animationDuration >= Duration.zero,
      'animationDuration must not be negative',
    );
    assert(elevation >= 0, 'elevation must not be negative');

    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    final _ActiveToast active = _ActiveToast(position: position);
    active.entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        active: active,
        message: message,
        type: type,
        position: position,
        duration: duration,
        animationDuration: animationDuration,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        icon: icon,
        textStyle: textStyle,
        borderRadius: borderRadius,
        padding: padding,
        elevation: elevation,
        actionLabel: actionLabel,
        onAction: onAction,
        dismissOnTap: dismissOnTap,
        showCloseButton: showCloseButton,
        onDismiss: onDismiss,
        swipeToDismiss: swipeToDismiss,
        showProgress: showProgress,
        pauseOnHover: pauseOnHover,
      ),
    );
    _ToastManager.add(active, overlay);
  }
}

/// Convenience access to [ToastNotification.show] from a [BuildContext].
///
/// ```dart
/// context.showToast(message: 'Copied to clipboard');
/// ```
extension ToastContext on BuildContext {
  /// Shows a toast above the current route.
  ///
  /// See [ToastNotification.show] for the meaning of each parameter.
  void showToast({
    required String message,
    ToastType type = ToastType.info,
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 250),
    Color? backgroundColor,
    Color? foregroundColor,
    IconData? icon,
    TextStyle? textStyle,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    double elevation = 4.0,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissOnTap = false,
    bool showCloseButton = true,
    VoidCallback? onDismiss,
    bool swipeToDismiss = true,
    bool showProgress = false,
    bool pauseOnHover = true,
  }) {
    ToastNotification.show(
      context: this,
      message: message,
      type: type,
      position: position,
      duration: duration,
      animationDuration: animationDuration,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      icon: icon,
      textStyle: textStyle,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      actionLabel: actionLabel,
      onAction: onAction,
      dismissOnTap: dismissOnTap,
      showCloseButton: showCloseButton,
      onDismiss: onDismiss,
      swipeToDismiss: swipeToDismiss,
      showProgress: showProgress,
      pauseOnHover: pauseOnHover,
    );
  }
}

/// Bookkeeping for one toast currently on screen.
class _ActiveToast {
  _ActiveToast({required this.position});

  final ToastPosition position;
  late final OverlayEntry entry;
  bool removed = false;
}

/// Static registry of on-screen toasts, responsible for stacking offsets and
/// safe removal.
abstract final class _ToastManager {
  static final List<_ActiveToast> _active = <_ActiveToast>[];

  /// Vertical space reserved for each stacked toast.
  static const double slotExtent = 64.0;

  static void add(_ActiveToast toast, OverlayState overlay) {
    _active.add(toast);
    overlay.insert(toast.entry);
    _rebuildPosition(toast.position);
  }

  /// Removes [toast] exactly once, guarding against double removal and
  /// unmounted entries, then repositions the remaining toasts.
  static void remove(_ActiveToast toast) {
    if (toast.removed) {
      return;
    }
    toast.removed = true;
    _active.remove(toast);
    if (toast.entry.mounted) {
      toast.entry.remove();
    }
    _rebuildPosition(toast.position);
  }

  /// Zero-based stacking slot of [toast] among toasts at the same position.
  static int slotOf(_ActiveToast toast) {
    int slot = 0;
    for (final _ActiveToast other in _active) {
      if (identical(other, toast)) {
        return slot;
      }
      if (other.position == toast.position) {
        slot++;
      }
    }
    return slot;
  }

  static void _rebuildPosition(ToastPosition position) {
    for (final _ActiveToast toast in _active) {
      if (toast.position == position && toast.entry.mounted) {
        toast.entry.markNeedsBuild();
      }
    }
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.active,
    required this.message,
    required this.type,
    required this.position,
    required this.duration,
    required this.animationDuration,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.textStyle,
    required this.borderRadius,
    required this.padding,
    required this.elevation,
    required this.actionLabel,
    required this.onAction,
    required this.dismissOnTap,
    required this.showCloseButton,
    required this.onDismiss,
    required this.swipeToDismiss,
    required this.showProgress,
    required this.pauseOnHover,
  });

  final _ActiveToast active;
  final String message;
  final ToastType type;
  final ToastPosition position;
  final Duration duration;
  final Duration animationDuration;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final TextStyle? textStyle;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dismissOnTap;
  final bool showCloseButton;
  final VoidCallback? onDismiss;
  final bool swipeToDismiss;
  final bool showProgress;
  final bool pauseOnHover;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  /// Swipe offset along [_swipeAxis], in logical pixels. Unbounded so it
  /// can hold any drag distance.
  late final AnimationController _swipe;
  Axis _swipeAxis = Axis.horizontal;

  /// The toast's extent along [_swipeAxis], measured when a swipe starts
  /// (sizes cannot be read during build).
  double _swipeExtent = 0.0;

  /// Drives the progress fuse and doubles as the countdown when the fuse is
  /// shown. Null when there is no fuse.
  AnimationController? _fuse;

  /// Countdown used when there is no fuse: a one-shot timer plus a
  /// stopwatch measuring the time already spent, so a pause can resume
  /// with the remaining time.
  Timer? _dismissTimer;
  final Stopwatch _elapsed = Stopwatch();

  bool _dismissing = false;
  bool _started = false;

  /// Whether a swipe release is animating the toast off screen.
  bool _flinging = false;

  /// Whether a swipe gesture is in progress. The recognizer for the other
  /// axis reports a cancel when it loses the gesture arena; this flag lets
  /// that cancel be ignored.
  bool _swiping = false;
  bool _hovered = false;
  int _pressedPointers = 0;
  bool _paused = false;

  /// Velocity (logical pixels per second) above which a release dismisses
  /// regardless of the distance travelled.
  static const double _flingVelocity = 700.0;

  /// Fraction of the toast's extent that a release must pass to dismiss.
  static const double _dismissThreshold = 0.4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _fade = curved;
    final Offset slideBegin = switch (widget.position) {
      ToastPosition.top => const Offset(0, -0.5),
      ToastPosition.bottom => const Offset(0, 0.5),
      ToastPosition.center => Offset.zero,
    };
    _slide = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(curved);
    _swipe = AnimationController.unbounded(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // Reduced motion: appear instantly, no slide or fade.
      _controller.duration = MicroMotion.effectiveDuration(
        context,
        widget.animationDuration,
      );
      _controller.forward();
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _elapsed.stop();
    _fuse?.dispose();
    _swipe.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.duration <= Duration.zero) {
      return;
    }
    if (widget.showProgress && !MicroMotion.isReduced(context)) {
      _fuse = AnimationController(duration: widget.duration, vsync: this)
        ..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            _dismiss();
          }
        })
        ..forward();
    } else {
      _elapsed.start();
      _dismissTimer = Timer(widget.duration, _dismiss);
    }
  }

  void _pauseCountdown() {
    if (_fuse != null) {
      _fuse!.stop();
      return;
    }
    if (_dismissTimer != null) {
      _elapsed.stop();
      _dismissTimer!.cancel();
      _dismissTimer = null;
    }
  }

  void _resumeCountdown() {
    if (_dismissing || _flinging || widget.duration <= Duration.zero) {
      return;
    }
    if (_fuse != null) {
      _fuse!.forward();
      return;
    }
    final Duration remaining = widget.duration - _elapsed.elapsed;
    if (remaining <= Duration.zero) {
      _dismiss();
      return;
    }
    _elapsed.start();
    _dismissTimer?.cancel();
    _dismissTimer = Timer(remaining, _dismiss);
  }

  /// Pauses or resumes the countdown according to hover and press state.
  void _updatePause() {
    final bool paused =
        widget.pauseOnHover && (_hovered || _pressedPointers > 0);
    if (paused == _paused || _dismissing) {
      return;
    }
    _paused = paused;
    if (paused) {
      _pauseCountdown();
    } else {
      _resumeCountdown();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pressedPointers++;
    _updatePause();
  }

  void _handlePointerUp(PointerEvent event) {
    if (_pressedPointers > 0) {
      _pressedPointers--;
    }
    _updatePause();
  }

  /// Removes the toast. When [animate] is `false` the exit animation is
  /// skipped (used after a swipe already moved the toast off screen).
  Future<void> _dismiss({bool animate = true}) async {
    if (_dismissing) {
      return;
    }
    _dismissing = true;
    _dismissTimer?.cancel();
    _elapsed.stop();
    _fuse?.stop();
    if (mounted && animate) {
      _controller.duration = MicroMotion.effectiveDuration(
        context,
        widget.animationDuration,
      );
      await _controller.reverse();
    }
    _ToastManager.remove(widget.active);
    widget.onDismiss?.call();
  }

  void _handleSwipeStart(Axis axis) {
    if (_dismissing || _flinging) {
      return;
    }
    _swiping = true;
    _swipeAxis = axis;
    final Size size = context.size ?? Size.zero;
    _swipeExtent = axis == Axis.horizontal ? size.width : size.height;
    _swipe.stop();
  }

  void _handleSwipeUpdate(double delta) {
    if (_dismissing || _flinging || !_swiping) {
      return;
    }
    double next = _swipe.value + delta;
    if (_swipeAxis == Axis.vertical) {
      // Vertical swipes only travel away from the toast's screen edge.
      next = widget.position == ToastPosition.top
          ? math.min(0.0, next)
          : math.max(0.0, next);
    }
    _swipe.value = next;
  }

  void _handleSwipeEnd(double velocity) {
    if (_dismissing || _flinging || !_swiping) {
      return;
    }
    _swiping = false;
    final double offset = _swipe.value;
    final double extent = _swipeExtent;
    double direction = 0.0;
    if (velocity.abs() >= _flingVelocity &&
        (offset == 0.0 || velocity.sign == offset.sign)) {
      direction = velocity.sign;
    } else if (extent > 0.0 && offset.abs() >= extent * _dismissThreshold) {
      direction = offset.sign;
    }
    if (_swipeAxis == Axis.vertical && direction != 0.0) {
      final double allowed = widget.position == ToastPosition.top ? -1.0 : 1.0;
      if (direction != allowed) {
        direction = 0.0;
      }
    }

    final bool reduced = MicroMotion.isReduced(context);
    if (direction == 0.0) {
      if (reduced) {
        _swipe.value = 0.0;
      } else {
        _swipe.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (reduced) {
      _dismiss(animate: false);
      return;
    }
    // Leave the lane fully; the extra margin covers the screen padding.
    final double target = direction * (extent + 48.0);
    final double distance = (target - offset).abs();
    final double speed = math.max(velocity.abs(), 1000.0);
    final int millis = (distance / speed * 1000).round().clamp(80, 250).toInt();
    _flinging = true;
    _dismissTimer?.cancel();
    _fuse?.stop();
    _swipe
        .animateTo(
          target,
          duration: Duration(milliseconds: millis),
          curve: Curves.easeOut,
        )
        .whenCompleteOrCancel(() {
          if (mounted) {
            _dismiss(animate: false);
          }
        });
  }

  void _handleAction() {
    widget.onAction?.call();
    _dismiss();
  }

  (Color, Color) _defaultColors(ColorScheme scheme) {
    switch (widget.type) {
      case ToastType.success:
        return (Colors.green.shade700, Colors.white);
      case ToastType.error:
        return (scheme.error, scheme.onError);
      case ToastType.warning:
        // Dark foreground for contrast on the orange background.
        return (Colors.orange.shade600, Colors.black87);
      case ToastType.info:
        return (scheme.inverseSurface, scheme.onInverseSurface);
    }
  }

  IconData _defaultIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_outline;
      case ToastType.error:
        return Icons.error_outline;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color defaultBg, Color defaultFg) = _defaultColors(scheme);
    final Color background = widget.backgroundColor ?? defaultBg;
    final Color foreground = widget.foregroundColor ?? defaultFg;

    Widget content = Padding(
      padding: widget.padding,
      child: Row(
        children: [
          Icon(widget.icon ?? _defaultIcon(), color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.message,
              style:
                  widget.textStyle ??
                  TextStyle(color: foreground, fontSize: 14),
            ),
          ),
          if (widget.actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _handleAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(widget.actionLabel!),
            ),
          ],
          if (widget.showCloseButton) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, color: foreground, size: 20),
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
            ),
          ],
        ],
      ),
    );

    final AnimationController? fuse = _fuse;
    if (fuse != null) {
      content = Stack(
        children: <Widget>[
          content,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _FusePainter(
                  progress: fuse,
                  color: foreground.withValues(alpha: 0.6),
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget toast = Material(
      color: background,
      elevation: widget.elevation,
      borderRadius: widget.borderRadius,
      // Clip only when the fuse needs to follow the rounded corners, so the
      // default rendering is unchanged.
      clipBehavior: fuse != null ? Clip.antiAlias : Clip.none,
      child: content,
    );

    toast = Semantics(
      liveRegion: true,
      container: true,
      onDismiss: widget.swipeToDismiss ? _dismiss : null,
      child: toast,
    );

    if (widget.dismissOnTap) {
      toast = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: toast,
      );
    }

    if (widget.swipeToDismiss) {
      final bool vertical = widget.position != ToastPosition.center;
      toast = GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) =>
            _handleSwipeStart(Axis.horizontal),
        onHorizontalDragUpdate: (DragUpdateDetails details) =>
            _handleSwipeUpdate(details.delta.dx),
        onHorizontalDragEnd: (DragEndDetails details) =>
            _handleSwipeEnd(details.velocity.pixelsPerSecond.dx),
        onHorizontalDragCancel: () => _handleSwipeEnd(0.0),
        onVerticalDragStart: vertical
            ? (DragStartDetails details) => _handleSwipeStart(Axis.vertical)
            : null,
        onVerticalDragUpdate: vertical
            ? (DragUpdateDetails details) =>
                  _handleSwipeUpdate(details.delta.dy)
            : null,
        onVerticalDragEnd: vertical
            ? (DragEndDetails details) =>
                  _handleSwipeEnd(details.velocity.pixelsPerSecond.dy)
            : null,
        onVerticalDragCancel: vertical ? () => _handleSwipeEnd(0.0) : null,
        child: toast,
      );
      toast = AnimatedBuilder(
        animation: _swipe,
        child: toast,
        builder: (BuildContext context, Widget? child) {
          // Keep the same widget structure at rest so the gesture detector
          // below is never re-created mid-gesture.
          final double offset = _swipe.value;
          final double extent = _swipeExtent;
          final double opacity = extent > 0.0
              ? (1.0 - offset.abs() / extent).clamp(0.0, 1.0)
              : 1.0;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: _swipeAxis == Axis.horizontal
                  ? Offset(offset, 0.0)
                  : Offset(0.0, offset),
              child: child,
            ),
          );
        },
      );
    }

    if (widget.pauseOnHover) {
      toast = Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        child: MouseRegion(
          onEnter: (PointerEnterEvent event) {
            _hovered = true;
            _updatePause();
          },
          onExit: (PointerExitEvent event) {
            _hovered = false;
            _updatePause();
          },
          child: toast,
        ),
      );
    }

    toast = FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: toast),
    );

    final double stackOffset =
        _ToastManager.slotOf(widget.active) * _ToastManager.slotExtent;
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);
    final Duration moveDuration = MicroMotion.effectiveDuration(
      context,
      const Duration(milliseconds: 200),
    );

    switch (widget.position) {
      case ToastPosition.top:
        return AnimatedPositioned(
          duration: moveDuration,
          curve: Curves.easeOut,
          top: safeArea.top + 16 + stackOffset,
          left: 20,
          right: 20,
          child: toast,
        );
      case ToastPosition.bottom:
        return AnimatedPositioned(
          duration: moveDuration,
          curve: Curves.easeOut,
          bottom: safeArea.bottom + 16 + stackOffset,
          left: 20,
          right: 20,
          child: toast,
        );
      case ToastPosition.center:
        final double screenHeight = MediaQuery.sizeOf(context).height;
        return AnimatedPositioned(
          duration: moveDuration,
          curve: Curves.easeOut,
          top: screenHeight / 2 - _ToastManager.slotExtent / 2 + stackOffset,
          left: 20,
          right: 20,
          child: toast,
        );
    }
  }
}

/// Paints the countdown fuse: a bar anchored at the start edge whose length
/// is the remaining fraction of the toast's duration.
class _FusePainter extends CustomPainter {
  _FusePainter({
    required this.progress,
    required this.color,
    required this.textDirection,
  }) : super(repaint: progress);

  /// Elapsed fraction of the duration, from 0 to 1.
  final Animation<double> progress;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * (1.0 - progress.value);
    if (width <= 0.0) {
      return;
    }
    final double left = textDirection == TextDirection.rtl
        ? size.width - width
        : 0.0;
    canvas.drawRect(
      Rect.fromLTWH(left, 0.0, width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FusePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection;
}
