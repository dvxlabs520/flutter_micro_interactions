import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// The direction in which an [ExpandableFab] fans out its actions.
enum ExpandableFabDirection {
  /// Actions stack vertically above the main button.
  up,

  /// Actions stack vertically below the main button.
  down,

  /// Actions stack horizontally to the left of the main button.
  left,

  /// Actions stack horizontally to the right of the main button.
  right,

  /// Actions fan out on an arc around the main button. The arc is
  /// described by [ExpandableFab.radialStartAngle] and
  /// [ExpandableFab.radialSweepAngle].
  radial,
}

/// One action of an [ExpandableFab].
///
/// ```dart
/// ExpandableFabAction(
///   icon: const Icon(Icons.edit),
///   label: 'Edit',
///   onPressed: _startEditing,
/// )
/// ```
class ExpandableFabAction {
  /// Creates an action for an [ExpandableFab].
  const ExpandableFabAction({
    required this.icon,
    this.onPressed,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// The icon shown on the mini button.
  final Widget icon;

  /// Called when the action is tapped. Fired immediately on tap, before
  /// any closing animation.
  final VoidCallback? onPressed;

  /// Optional text rendered as a small pill next to the mini button. It is
  /// also used as the button's tooltip and semantics label.
  final String? label;

  /// Background color of the mini button. Defaults to the theme's
  /// `colorScheme.secondaryContainer`.
  final Color? backgroundColor;

  /// Foreground (icon) color of the mini button. Defaults to the theme's
  /// `colorScheme.onSecondaryContainer`.
  final Color? foregroundColor;
}

/// Programmatic control for an [ExpandableFab].
///
/// ```dart
/// final controller = ExpandableFabController();
/// // ...
/// ExpandableFab(
///   controller: controller,
///   actions: myActions,
/// );
/// // later:
/// controller.open();
/// controller.close();
/// ```
///
/// [isOpen] reflects whether the attached fab is currently expanded; it
/// also updates when the fab opens or closes itself (taps, tap outside,
/// Escape). Dispose the controller yourself when it is no longer needed.
class ExpandableFabController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the attached [ExpandableFab] is currently expanded.
  bool get isOpen => _isOpen;

  /// Expands the attached fab (no-op when already open).
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Collapses the attached fab (no-op when already closed).
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Expands the fab when closed and collapses it when open.
  void toggle() => _isOpen ? close() : open();
}

/// A floating action button that expands into a set of mini action
/// buttons, linearly or on a radial arc, with a staggered entrance.
///
/// ```dart
/// ExpandableFab(
///   actions: [
///     ExpandableFabAction(
///       icon: const Icon(Icons.edit),
///       label: 'Edit',
///       onPressed: _edit,
///     ),
///     ExpandableFabAction(
///       icon: const Icon(Icons.share),
///       label: 'Share',
///       onPressed: _share,
///     ),
///   ],
/// )
/// ```
///
/// The widget itself is only the 56x56 main button, so it can be used as a
/// regular `floatingActionButton`. The expanded actions render in the app's
/// [Overlay] (via [OverlayPortal]) anchored to the button, so they overflow
/// any parent without affecting layout. An [Overlay] ancestor is required;
/// [MaterialApp] provides one.
///
/// While open, tapping anywhere outside the fab and its actions closes it
/// (see [closeOnTapOutside]), and the Escape key closes it. Scrolling an
/// ancestor does not close the fab, because the overlay cannot observe
/// scroll notifications of the anchor's subtree.
///
/// Labels render as small pills to the left of each mini button and double
/// as tooltips and semantics labels. Under reduced motion the fab opens and
/// closes instantly without stagger.
class ExpandableFab extends StatefulWidget {
  /// Creates an expandable floating action button.
  const ExpandableFab({
    super.key,
    required this.actions,
    this.controller,
    this.direction = ExpandableFabDirection.up,
    this.distance = 72.0,
    this.radialStartAngle = 180.0,
    this.radialSweepAngle = 90.0,
    this.openIcon,
    this.closeIcon,
    this.backgroundColor,
    this.foregroundColor,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 40),
    this.curve = Curves.easeOutBack,
    this.closeOnAction = true,
    this.closeOnTapOutside = true,
    this.onToggle,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(distance > 0, 'distance must be positive');

  /// The actions revealed when the fab expands.
  final List<ExpandableFabAction> actions;

  /// Optional controller to open and close the fab programmatically. The
  /// caller owns and disposes it.
  final ExpandableFabController? controller;

  /// Where the actions fan out. Defaults to [ExpandableFabDirection.up].
  final ExpandableFabDirection direction;

  /// Spacing between consecutive actions for the linear directions, and
  /// the arc radius for [ExpandableFabDirection.radial]. Defaults to 72.
  final double distance;

  /// Start angle of the radial arc, in degrees. Angles are measured
  /// clockwise in screen coordinates from the positive x axis: 0 points
  /// right, 90 down, 180 left and 270 up. The default of 180 combined
  /// with [radialSweepAngle] 90 fans up and to the left, which suits a
  /// fab in the bottom-right corner.
  final double radialStartAngle;

  /// Arc swept by the actions, in degrees, starting at
  /// [radialStartAngle]. Defaults to 90.
  final double radialSweepAngle;

  /// Icon shown while collapsed. Defaults to `Icon(Icons.add)`. It
  /// rotates 45 degrees and cross-fades into [closeIcon] while opening.
  final Widget? openIcon;

  /// Icon shown while expanded. Defaults to `Icon(Icons.close)`.
  final Widget? closeIcon;

  /// Background color of the main button. Defaults to the theme's
  /// `colorScheme.primaryContainer`.
  final Color? backgroundColor;

  /// Foreground (icon) color of the main button. Defaults to the theme's
  /// `colorScheme.onPrimaryContainer`.
  final Color? foregroundColor;

  /// Duration of one item's entrance. The full open animation lasts
  /// `duration + staggerDelay * (actions.length - 1)`. Defaults to 300
  /// milliseconds.
  final Duration duration;

  /// Delay between the entrances of consecutive actions. Defaults to 40
  /// milliseconds.
  final Duration staggerDelay;

  /// Curve of each item's entrance. Defaults to [Curves.easeOutBack].
  final Curve curve;

  /// Whether tapping an action closes the fab. Defaults to `true`.
  final bool closeOnAction;

  /// Whether tapping outside the fab and its actions closes it. Defaults
  /// to `true`.
  final bool closeOnTapOutside;

  /// Called with the new open state whenever the fab opens or closes.
  final ValueChanged<bool>? onToggle;

  /// When `false` the main button is dimmed and cannot open; an open fab
  /// closes when [enabled] turns `false`. Defaults to `true`.
  final bool enabled;

  /// Semantics label of the main button. Defaults to a generic
  /// description including the open state.
  final String? semanticLabel;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  static const double _fabSize = 56.0;
  static const double _miniSize = 40.0;

  /// Extra horizontal room on the label side of the overlay box, so label
  /// pills stay within hit-testable bounds.
  static const double _labelSpace = 200.0;

  /// Headroom multiplier for curves that overshoot (easeOutBack).
  static const double _overshoot = 1.2;

  late final AnimationController _controller;
  late CurvedAnimation _iconAnimation;
  List<CurvedAnimation> _itemAnimations = <CurvedAnimation>[];
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final Object _tapGroupId = Object();
  bool _isOpen = false;
  bool _keyHandlerAdded = false;

  Duration get _totalDuration {
    final int n = widget.actions.length;
    if (n <= 1) return widget.duration;
    return widget.duration + widget.staggerDelay * (n - 1);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _controller.addStatusListener(_handleStatus);
    _iconAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _rebuildItemAnimations();
    widget.controller?.addListener(_handleControllerChanged);
    if (widget.controller?.isOpen ?? false) {
      // The portal cannot be shown during the first build; open right
      // after the first frame instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (widget.controller?.isOpen ?? false)) {
          _open();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ExpandableFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      // Adopt the new controller's state after this frame (the portal
      // cannot be toggled during build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller != null) {
          _handleControllerChanged();
        }
      });
    }
    if (widget.duration != oldWidget.duration ||
        widget.staggerDelay != oldWidget.staggerDelay ||
        widget.curve != oldWidget.curve ||
        widget.actions.length != oldWidget.actions.length) {
      _controller.duration = _totalDuration;
      _rebuildItemAnimations();
    }
    if (!widget.enabled && oldWidget.enabled && _isOpen) {
      // Close after the build phase so onToggle never fires during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen) {
          _close();
        }
      });
    }
  }

  @override
  void dispose() {
    _removeKeyHandler();
    widget.controller?.removeListener(_handleControllerChanged);
    for (final CurvedAnimation animation in _itemAnimations) {
      animation.dispose();
    }
    _iconAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _rebuildItemAnimations() {
    for (final CurvedAnimation animation in _itemAnimations) {
      animation.dispose();
    }
    final int n = widget.actions.length;
    final int totalUs = _totalDuration.inMicroseconds;
    _itemAnimations = List<CurvedAnimation>.generate(n, (int index) {
      double begin = 0.0;
      double end = 1.0;
      if (totalUs > 0) {
        begin = widget.staggerDelay.inMicroseconds * index / totalUs;
        end = (widget.staggerDelay.inMicroseconds * index +
                widget.duration.inMicroseconds) /
            totalUs;
      }
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          begin.clamp(0.0, 1.0),
          end.clamp(0.0, 1.0),
          curve: widget.curve,
        ),
      );
    });
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final ExpandableFabController controller = widget.controller!;
    if (controller.isOpen == _isOpen) return;
    if (controller.isOpen) {
      if (!widget.enabled) {
        // Reject the request; keep the controller truthful.
        controller._isOpen = false;
        return;
      }
      _open();
    } else {
      _close();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _portal.isShowing) {
      _portal.hide();
    }
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isOpen &&
        mounted) {
      _close();
      return true;
    }
    return false;
  }

  void _addKeyHandler() {
    if (_keyHandlerAdded) return;
    _keyHandlerAdded = true;
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  void _removeKeyHandler() {
    if (!_keyHandlerAdded) return;
    _keyHandlerAdded = false;
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    if (_isOpen || !widget.enabled || !mounted) return;
    setState(() {
      _isOpen = true;
    });
    widget.controller?._isOpen = true;
    if (!_portal.isShowing) {
      _portal.show();
    }
    if (MicroMotion.isReduced(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
    _addKeyHandler();
    widget.onToggle?.call(true);
  }

  void _close() {
    if (!_isOpen || !mounted) return;
    setState(() {
      _isOpen = false;
    });
    widget.controller?._isOpen = false;
    if (MicroMotion.isReduced(context)) {
      // Jump to the end; the dismissed status hides the portal.
      _controller.value = 0.0;
      if (_portal.isShowing) {
        _portal.hide();
      }
    } else {
      _controller.reverse();
    }
    _removeKeyHandler();
    widget.onToggle?.call(false);
  }

  double get _maxDistance {
    if (widget.direction == ExpandableFabDirection.radial) {
      return widget.distance;
    }
    return widget.distance * math.max(widget.actions.length, 1);
  }

  Offset _targetOffset(int index) {
    final double d = widget.distance;
    switch (widget.direction) {
      case ExpandableFabDirection.up:
        return Offset(0, -d * (index + 1));
      case ExpandableFabDirection.down:
        return Offset(0, d * (index + 1));
      case ExpandableFabDirection.left:
        return Offset(-d * (index + 1), 0);
      case ExpandableFabDirection.right:
        return Offset(d * (index + 1), 0);
      case ExpandableFabDirection.radial:
        final int n = widget.actions.length;
        final double t = n <= 1 ? 0.5 : index / (n - 1);
        final double deg =
            widget.radialStartAngle + widget.radialSweepAngle * t;
        final double rad = deg * math.pi / 180.0;
        return Offset(math.cos(rad), math.sin(rad)) * d;
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final double half = _maxDistance * _overshoot + _miniSize + 8.0;
    final double width = half * 2 + _labelSpace;
    final double height = half * 2;
    final Offset center = Offset(_labelSpace + half, half);

    // The Overlay lays out its child with tight full-screen constraints;
    // Align loosens them so the action box keeps its computed size, which
    // the Positioned math below relies on.
    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.center,
      followerAnchor: Alignment.topLeft,
      offset: -center,
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: _tapGroupId,
          onTapOutside: widget.closeOnTapOutside
              ? (PointerDownEvent _) => _close()
              : null,
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: FocusTraversalGroup(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    for (int i = 0; i < widget.actions.length; i++)
                      _buildAction(context, i, center, width),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
      BuildContext context, int index, Offset center, double boxWidth) {
    final ExpandableFabAction action = widget.actions[index];
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background =
        action.backgroundColor ?? scheme.secondaryContainer;
    final Color foreground =
        action.foregroundColor ?? scheme.onSecondaryContainer;
    final Offset target = _targetOffset(index);
    final Animation<double> animation = _itemAnimations[index];

    Widget button = Material(
      shape: const CircleBorder(),
      color: background,
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          action.onPressed?.call();
          if (widget.closeOnAction) {
            _close();
          }
        },
        child: SizedBox(
          width: _miniSize,
          height: _miniSize,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: 20),
              child: action.icon,
            ),
          ),
        ),
      ),
    );
    if (action.label != null) {
      button = Tooltip(message: action.label!, child: button);
    }

    Widget item = button;
    final String? label = action.label;
    if (label != null) {
      item = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: Material(
              color: scheme.surfaceContainerHighest,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          button,
        ],
      );
    }

    return AnimatedBuilder(
      animation: animation,
      // The action row is static; only opacity, scale and position change.
      child: item,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value;
        final Offset position = center + target * t;
        return Positioned(
          right: boxWidth - position.dx - _miniSize / 2,
          top: position.dy - _miniSize / 2,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: math.max(t, 0.0),
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(Color foreground) {
    final Widget open = widget.openIcon ?? const Icon(Icons.add);
    final Widget close = widget.closeIcon ?? const Icon(Icons.close);
    return IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: RotationTransition(
        turns: Tween<double>(begin: 0.0, end: 0.125).animate(_iconAnimation),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            FadeTransition(
              opacity: ReverseAnimation(_iconAnimation),
              child: open,
            ),
            FadeTransition(opacity: _iconAnimation, child: close),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = widget.backgroundColor ?? scheme.primaryContainer;
    final Color foreground =
        widget.foregroundColor ?? scheme.onPrimaryContainer;

    Widget fab = Material(
      shape: const CircleBorder(),
      color: background,
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.enabled ? _toggle : null,
        child: SizedBox(
          width: _fabSize,
          height: _fabSize,
          child: Center(child: _buildIcon(foreground)),
        ),
      ),
    );
    fab = Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      expanded: _isOpen,
      label: widget.semanticLabel,
      child: fab,
    );
    if (!widget.enabled) {
      fab = Opacity(opacity: 0.5, child: fab);
    }

    return TapRegion(
      groupId: _tapGroupId,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _buildOverlay,
          child: SizedBox(width: _fabSize, height: _fabSize, child: fab),
        ),
      ),
    );
  }
}
