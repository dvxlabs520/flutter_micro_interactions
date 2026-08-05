import 'dart:async';

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
/// early with the close button, by tapping (when `dismissOnTap` is `true`)
/// or through the optional action button.
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
/// Stacking: multiple simultaneous toasts at the same [ToastPosition] stack
/// with a fixed vertical offset per toast; the oldest toast sits closest to
/// the screen edge and remaining toasts slide back into place when one is
/// dismissed.
///
/// Accessibility: the message is announced through
/// [SemanticsService.sendAnnouncement], the toast content is a live region,
/// and the close button has a semantic label.
///
/// Reduced motion: toasts appear and disappear instantly (no slide or fade
/// animation).
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
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    double elevation = 4.0,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissOnTap = false,
    bool showCloseButton = true,
    VoidCallback? onDismiss,
  }) {
    assert(duration >= Duration.zero, 'duration must not be negative');
    assert(animationDuration >= Duration.zero,
        'animationDuration must not be negative');
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
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    double elevation = 4.0,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissOnTap = false,
    bool showCloseButton = true,
    VoidCallback? onDismiss,
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

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;
  bool _dismissing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    final CurvedAnimation curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curved;
    final Offset slideBegin = switch (widget.position) {
      ToastPosition.top => const Offset(0, -0.5),
      ToastPosition.bottom => const Offset(0, 0.5),
      ToastPosition.center => Offset.zero,
    };
    _slide = Tween<Offset>(begin: slideBegin, end: Offset.zero)
        .animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // Reduced motion: appear instantly, no slide or fade.
      _controller.duration =
          MicroMotion.effectiveDuration(context, widget.animationDuration);
      _controller.forward();
      if (widget.duration > Duration.zero) {
        _dismissTimer = Timer(widget.duration, _dismiss);
      }
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) {
      return;
    }
    _dismissing = true;
    _dismissTimer?.cancel();
    if (mounted) {
      _controller.duration =
          MicroMotion.effectiveDuration(context, widget.animationDuration);
      await _controller.reverse();
    }
    _ToastManager.remove(widget.active);
    widget.onDismiss?.call();
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

    Widget toast = Material(
      color: background,
      elevation: widget.elevation,
      borderRadius: widget.borderRadius,
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            Icon(widget.icon ?? _defaultIcon(), color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: widget.textStyle ??
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
      ),
    );

    toast = Semantics(
      liveRegion: true,
      container: true,
      child: toast,
    );

    if (widget.dismissOnTap) {
      toast = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: toast,
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
        context, const Duration(milliseconds: 200));

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
