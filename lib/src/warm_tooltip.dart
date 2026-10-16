import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Coordinates the [WarmTooltip]s below it so that they share one bubble
/// and open instantly once the group is "warm".
///
/// ```dart
/// WarmTooltipGroup(
///   child: Row(
///     children: <Widget>[
///       WarmTooltip(
///         message: 'Bold',
///         child: IconButton(icon: const Icon(Icons.format_bold), onPressed: _bold),
///       ),
///       WarmTooltip(
///         message: 'Italic',
///         child: IconButton(icon: const Icon(Icons.format_italic), onPressed: _italic),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// The first tooltip shown in a group waits [warmDelay] after the pointer
/// enters its child. While the group is warm (a tooltip is visible, or one
/// closed less than [cooldown] ago) hovering a sibling shows its tooltip
/// at once: instead of fading out and in again, the single bubble of the
/// group glides from the previous position and size to the new one while
/// the old text cross-fades into the new text. After [cooldown] without a
/// visible tooltip the group is cold again and the next tooltip waits
/// [warmDelay] once more.
///
/// The bubble renders in the app's [Overlay] (via [OverlayPortal]); an
/// [Overlay] ancestor is required and [MaterialApp] provides one. Escape
/// hides a visible tooltip.
///
/// Under reduced motion the bubble appears, moves and disappears without
/// any fade or glide; the delays still apply because they are about
/// intent, not motion.
class WarmTooltipGroup extends StatelessWidget {
  /// Creates a group of coordinated tooltips.
  const WarmTooltipGroup({
    super.key,
    required this.child,
    this.warmDelay = const Duration(milliseconds: 500),
    this.cooldown = const Duration(milliseconds: 300),
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
  });

  /// The subtree that contains the [WarmTooltip]s of this group.
  final Widget child;

  /// How long the pointer must rest on a child before the first tooltip of
  /// a cold group appears. Defaults to 500 milliseconds.
  final Duration warmDelay;

  /// How long the group stays warm after its last tooltip closed.
  /// Defaults to 300 milliseconds.
  final Duration cooldown;

  /// Length of the glide between two anchors. The fade in and out takes
  /// about half of it. Defaults to 240 milliseconds.
  final Duration duration;

  /// Curve of the glide between two anchors. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return _WarmTooltipHost(
      warmDelay: warmDelay,
      cooldown: cooldown,
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}

/// A tooltip that shows [message] in a bubble above (or below) [child] on
/// hover or long press, and glides between siblings inside a
/// [WarmTooltipGroup].
///
/// ```dart
/// WarmTooltip(
///   message: 'Share',
///   child: IconButton(icon: const Icon(Icons.share), onPressed: _share),
/// )
/// ```
///
/// With a mouse or stylus the tooltip appears after a delay while the
/// pointer rests on [child] and hides when it leaves. On touch, a long
/// press shows the tooltip right away and it hides [showDuration] after
/// the finger lifts, like a regular tooltip.
///
/// Inside a [WarmTooltipGroup] the delay and the shared, gliding bubble
/// come from the group. Without a group the tooltip waits [waitDuration]
/// and uses its own bubble with the same look.
///
/// The bubble is placed above [child] unless [preferBelow] is true, and
/// flips to the other side when there is no room. It is horizontally
/// centered on [child] and kept on screen.
///
/// [child] receives [message] as its semantics tooltip unless
/// [excludeFromSemantics] is true; the bubble itself is decorative and
/// excluded from semantics. Under reduced motion the bubble appears
/// without fade or glide.
class WarmTooltip extends StatelessWidget {
  /// Creates a warm tooltip.
  const WarmTooltip({
    super.key,
    required this.message,
    required this.child,
    this.preferBelow = false,
    this.verticalOffset = 8.0,
    this.waitDuration = const Duration(milliseconds: 500),
    this.showDuration = const Duration(milliseconds: 1500),
    this.textStyle,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.maxWidth = 280.0,
    this.enabled = true,
    this.excludeFromSemantics = false,
  }) : assert(verticalOffset >= 0, 'verticalOffset must not be negative'),
       assert(maxWidth > 0, 'maxWidth must be positive');

  /// The text shown in the bubble.
  final String message;

  /// The widget the tooltip describes.
  final Widget child;

  /// Whether the bubble goes below [child] by default. Defaults to
  /// `false` (above).
  final bool preferBelow;

  /// Gap between [child] and the bubble. Defaults to 8.
  final double verticalOffset;

  /// Hover delay before showing when the tooltip is not inside a
  /// [WarmTooltipGroup]. Inside a group, [WarmTooltipGroup.warmDelay] is
  /// used instead. Defaults to 500 milliseconds.
  final Duration waitDuration;

  /// How long the bubble stays after a long press ends on touch. Defaults
  /// to 1500 milliseconds.
  final Duration showDuration;

  /// Text style of the message. Defaults to the theme's
  /// `textTheme.bodySmall` in `colorScheme.onInverseSurface`.
  final TextStyle? textStyle;

  /// Background of the bubble. Defaults to the theme's
  /// `colorScheme.inverseSurface`.
  final Color? backgroundColor;

  /// Padding around the message inside the bubble. Defaults to 10
  /// horizontal by 6 vertical.
  final EdgeInsets padding;

  /// Corner radius of the bubble. Defaults to 8.
  final BorderRadius borderRadius;

  /// Maximum width of the bubble; longer messages wrap. Defaults to 280.
  final double maxWidth;

  /// When false no bubble is shown. The semantics tooltip remains.
  /// Defaults to `true`.
  final bool enabled;

  /// Whether to leave [message] out of the semantics of [child]. Defaults
  /// to `false`.
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final Widget anchor = _WarmTooltipAnchor(config: this);
    if (_WarmTooltipScope.maybeOf(context) != null) return anchor;
    return _WarmTooltipHost(
      warmDelay: waitDuration,
      cooldown: Duration.zero,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: anchor,
    );
  }
}

/// Makes the nearest host available to its anchors.
class _WarmTooltipScope extends InheritedWidget {
  const _WarmTooltipScope({required this.host, required super.child});

  final _WarmTooltipHostState host;

  static _WarmTooltipHostState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WarmTooltipScope>()?.host;

  @override
  bool updateShouldNotify(_WarmTooltipScope oldWidget) =>
      oldWidget.host != host;
}

/// Owns the shared bubble, its animations and the warm and cool timers.
class _WarmTooltipHost extends StatefulWidget {
  const _WarmTooltipHost({
    required this.warmDelay,
    required this.cooldown,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final Duration warmDelay;
  final Duration cooldown;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_WarmTooltipHost> createState() => _WarmTooltipHostState();
}

/// Visual configuration of the bubble, captured from the active anchor.
class _BubbleLook {
  const _BubbleLook({
    required this.style,
    required this.background,
    required this.padding,
    required this.borderRadius,
    required this.textWidth,
    required this.textHeight,
  });

  final TextStyle style;
  final Color background;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double textWidth;
  final double textHeight;
}

class _WarmTooltipHostState extends State<_WarmTooltipHost>
    with TickerProviderStateMixin {
  /// Minimum distance between the bubble and the overlay edges.
  static const double _margin = 8.0;

  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _fade;
  late final AnimationController _move;
  late CurvedAnimation _moveCurve;
  late final CurvedAnimation _fadeCurve;

  Timer? _showTimer;
  Timer? _cooldownTimer;
  Timer? _dismissTimer;
  _WarmTooltipAnchorState? _pending;
  _WarmTooltipAnchorState? _hovered;
  _WarmTooltipAnchorState? _active;
  bool _visible = false;
  bool _touchShown = false;
  bool _keyHandlerAdded = false;
  bool _reducedMotion = false;

  Rect _fromRect = Rect.zero;
  Rect _toRect = Rect.zero;
  bool _placedBelow = false;
  String _message = '';
  String? _fromMessage;
  _BubbleLook? _look;
  _BubbleLook? _fromLook;

  /// Whether a sibling would show instantly right now.
  bool get isWarm => _visible || (_cooldownTimer?.isActive ?? false);

  /// Whether the bubble is currently shown (fading in or fully visible).
  bool get isVisible => _visible;

  /// The bubble rect at the current point of the glide.
  Rect get _currentRect =>
      Rect.lerp(_fromRect, _toRect, _moveCurve.value.clamp(0.0, 1.0))!;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: _fadeDuration,
      reverseDuration: _fadeDuration,
    );
    _fade.addStatusListener(_handleFadeStatus);
    _fadeCurve = CurvedAnimation(
      parent: _fade,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _move = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0;
    _moveCurve = CurvedAnimation(parent: _move, curve: widget.curve);
  }

  Duration get _fadeDuration =>
      Duration(microseconds: math.max(1, widget.duration.inMicroseconds ~/ 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
  }

  @override
  void didUpdateWidget(_WarmTooltipHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _move.duration = widget.duration;
      _fade.duration = _fadeDuration;
      _fade.reverseDuration = _fadeDuration;
    }
    if (widget.curve != oldWidget.curve) {
      _moveCurve.dispose();
      _moveCurve = CurvedAnimation(parent: _move, curve: widget.curve);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _cooldownTimer?.cancel();
    _dismissTimer?.cancel();
    _removeKeyHandler();
    _fade.removeStatusListener(_handleFadeStatus);
    _fadeCurve.dispose();
    _moveCurve.dispose();
    _fade.dispose();
    _move.dispose();
    super.dispose();
  }

  void _handleFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      if (_portal.isShowing) _portal.hide();
      _fromMessage = null;
      _fromLook = null;
    }
  }

  // ---------------------------------------------------------------------
  // Anchor events.

  void enter(_WarmTooltipAnchorState anchor) {
    _hovered = anchor;
    _dismissTimer?.cancel();
    if (!anchor.widget.config.enabled) return;
    if (_active == anchor && _visible) return;
    if (isWarm) {
      _cancelShowTimer();
      _show(anchor);
      return;
    }
    _cancelShowTimer();
    _pending = anchor;
    _showTimer = Timer(widget.warmDelay, () {
      _showTimer = null;
      _pending = null;
      if (mounted && _hovered == anchor && anchor.mounted) {
        _show(anchor);
      }
    });
  }

  void exit(_WarmTooltipAnchorState anchor) {
    if (_hovered == anchor) _hovered = null;
    if (_pending == anchor) _cancelShowTimer();
    if (_active == anchor && !_touchShown) _hide();
  }

  void longPressStart(_WarmTooltipAnchorState anchor) {
    if (!anchor.widget.config.enabled) return;
    _cancelShowTimer();
    _dismissTimer?.cancel();
    _touchShown = true;
    _show(anchor);
  }

  void longPressEnd(_WarmTooltipAnchorState anchor) {
    if (_active != anchor) return;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(anchor.widget.config.showDuration, () {
      _dismissTimer = null;
      if (mounted && _active == anchor) _hide();
    });
  }

  /// Called when an anchor is disposed or moves to another host.
  void detach(_WarmTooltipAnchorState anchor) {
    if (_hovered == anchor) _hovered = null;
    if (_pending == anchor) _cancelShowTimer();
    if (_active == anchor) {
      _active = null;
      _dismissTimer?.cancel();
      // The tree is locked while anchors unmount; hide after this frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _active == null && _visible) _hide();
      });
    }
  }

  void _cancelShowTimer() {
    _showTimer?.cancel();
    _showTimer = null;
    _pending = null;
  }

  // ---------------------------------------------------------------------
  // Showing and hiding.

  void _show(_WarmTooltipAnchorState anchor) {
    if (!mounted || !anchor.mounted) return;
    final _Placement? placement = _place(anchor);
    if (placement == null) return;
    final bool wasShowing = _fade.value > 0.0 && _look != null;
    final bool glide = isWarm && _look != null && !_reducedMotion;

    if (glide) {
      _fromRect = _currentRect;
      if (wasShowing && _message != anchor.widget.config.message) {
        _fromMessage = _message;
        _fromLook = _look;
      } else {
        _fromMessage = null;
        _fromLook = null;
      }
    } else {
      _fromRect = placement.rect;
      _fromMessage = null;
      _fromLook = null;
    }
    _toRect = placement.rect;
    _placedBelow = placement.below;
    _look = placement.look;
    _message = anchor.widget.config.message;
    _active = anchor;
    _visible = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;

    setState(() {});
    if (!_portal.isShowing) _portal.show();
    if (_reducedMotion) {
      _move.value = 1.0;
      _fade.value = 1.0;
    } else {
      if (_fromRect == _toRect && _fromMessage == null) {
        _move.value = 1.0;
      } else {
        _move.forward(from: 0.0);
      }
      _fade.forward();
    }
    _addKeyHandler();
  }

  void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _touchShown = false;
    if (!_visible) return;
    _visible = false;
    _active = null;
    _removeKeyHandler();
    if (widget.cooldown > Duration.zero) {
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(widget.cooldown, () => _cooldownTimer = null);
    }
    if (!mounted) return;
    if (_reducedMotion) {
      _fade.value = 0.0;
      _move.value = 1.0;
      if (_portal.isShowing) _portal.hide();
    } else {
      _fade.reverse();
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _visible &&
        mounted) {
      _hide();
      return true;
    }
    return false;
  }

  void _addKeyHandler() {
    if (_keyHandlerAdded) return;
    _keyHandlerAdded = true;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  void _removeKeyHandler() {
    if (!_keyHandlerAdded) return;
    _keyHandlerAdded = false;
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }

  /// Measures the message and finds the bubble rect for [anchor] in the
  /// overlay's coordinate space.
  _Placement? _place(_WarmTooltipAnchorState anchor) {
    final RenderBox? overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final RenderObject? target = anchor.context.findRenderObject();
    if (overlay == null ||
        !overlay.hasSize ||
        target is! RenderBox ||
        !target.hasSize ||
        !target.attached) {
      return null;
    }
    final WarmTooltip config = anchor.widget.config;
    final ThemeData theme = Theme.of(anchor.context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle style =
        config.textStyle ??
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          color: scheme.onInverseSurface,
        );
    final TextScaler scaler = MediaQuery.textScalerOf(anchor.context);
    final TextDirection direction = Directionality.of(anchor.context);

    final double maxText = math.max(
      0.0,
      math.min(config.maxWidth, overlay.size.width - _margin * 2) -
          config.padding.horizontal,
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(text: config.message, style: style),
      textDirection: direction,
      textScaler: scaler,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxText);
    final double textWidth = painter.width.ceilToDouble();
    final double textHeight = painter.height.ceilToDouble();
    painter.dispose();

    final Size bubble = Size(
      textWidth + config.padding.horizontal,
      textHeight + config.padding.vertical,
    );
    final Offset origin = target.localToGlobal(Offset.zero, ancestor: overlay);
    final Rect anchorRect = origin & target.size;
    final double aboveTop =
        anchorRect.top - config.verticalOffset - bubble.height;
    final double belowTop = anchorRect.bottom + config.verticalOffset;
    final bool fitsAbove = aboveTop >= _margin;
    final bool fitsBelow =
        belowTop + bubble.height <= overlay.size.height - _margin;
    final bool below = config.preferBelow
        ? (fitsBelow || !fitsAbove)
        : (!fitsAbove && fitsBelow);
    final double maxLeft = math.max(
      _margin,
      overlay.size.width - _margin - bubble.width,
    );
    final double left = (anchorRect.center.dx - bubble.width / 2).clamp(
      _margin,
      maxLeft,
    );
    return _Placement(
      rect: Offset(left, below ? belowTop : aboveTop) & bubble,
      below: below,
      look: _BubbleLook(
        style: style,
        background: config.backgroundColor ?? scheme.inverseSurface,
        padding: config.padding,
        borderRadius: config.borderRadius,
        textWidth: textWidth,
        textHeight: textHeight,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Building.

  Widget _buildText(String message, _BubbleLook look) {
    return OverflowBox(
      minWidth: look.textWidth,
      maxWidth: look.textWidth,
      minHeight: look.textHeight,
      maxHeight: look.textHeight,
      child: Text(message, style: look.style, textAlign: TextAlign.center),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final _BubbleLook? look = _look;
    if (look == null) return const SizedBox.shrink();
    final String? fromMessage = _fromMessage;
    final _BubbleLook? fromLook = _fromLook;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_fade, _move]),
          builder: (BuildContext context, Widget? _) {
            final double t = _moveCurve.value.clamp(0.0, 1.0);
            final double fade = _fadeCurve.value.clamp(0.0, 1.0);
            final Rect rect = _currentRect;
            final Color background = fromLook == null
                ? look.background
                : Color.lerp(fromLook.background, look.background, t)!;
            final BorderRadius radius = fromLook == null
                ? look.borderRadius
                : BorderRadius.lerp(
                    fromLook.borderRadius,
                    look.borderRadius,
                    t,
                  )!;
            final Widget content = Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (fromMessage != null && fromLook != null && t < 1.0)
                  Opacity(
                    opacity: (1.0 - t * 1.6).clamp(0.0, 1.0),
                    child: _buildText(fromMessage, fromLook),
                  ),
                Opacity(
                  opacity: fromMessage == null
                      ? 1.0
                      : ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                  child: _buildText(_message, look),
                ),
              ],
            );
            return Stack(
              children: <Widget>[
                Positioned.fromRect(
                  rect: rect,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * fade,
                      alignment: _placedBelow
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: radius,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(borderRadius: radius, child: content),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildBubble,
      child: _WarmTooltipScope(host: this, child: widget.child),
    );
  }
}

/// Where a bubble goes and how it looks.
class _Placement {
  const _Placement({
    required this.rect,
    required this.below,
    required this.look,
  });

  final Rect rect;
  final bool below;
  final _BubbleLook look;
}

/// Listens to hover and long press on the tooltip's child and reports to
/// the nearest host.
class _WarmTooltipAnchor extends StatefulWidget {
  const _WarmTooltipAnchor({required this.config});

  final WarmTooltip config;

  @override
  State<_WarmTooltipAnchor> createState() => _WarmTooltipAnchorState();
}

class _WarmTooltipAnchorState extends State<_WarmTooltipAnchor> {
  _WarmTooltipHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _WarmTooltipHostState? host = _WarmTooltipScope.maybeOf(context);
    if (host != _host) {
      _host?.detach(this);
      _host = host;
    }
  }

  @override
  void didUpdateWidget(_WarmTooltipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.config.enabled && oldWidget.config.enabled) {
      final _WarmTooltipHostState? host = _host;
      if (host != null) {
        host.detach(this);
      }
    }
  }

  @override
  void dispose() {
    _host?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WarmTooltip config = widget.config;
    Widget result = MouseRegion(
      opaque: false,
      onEnter: (PointerEnterEvent event) {
        if (event.kind == PointerDeviceKind.touch) return;
        _host?.enter(this);
      },
      onExit: (PointerExitEvent event) {
        if (event.kind == PointerDeviceKind.touch) return;
        _host?.exit(this);
      },
      child: GestureDetector(
        excludeFromSemantics: true,
        onLongPressStart: config.enabled
            ? (LongPressStartDetails _) => _host?.longPressStart(this)
            : null,
        onLongPressEnd: config.enabled
            ? (LongPressEndDetails _) => _host?.longPressEnd(this)
            : null,
        child: config.child,
      ),
    );
    if (!config.excludeFromSemantics) {
      result = Semantics(tooltip: config.message, child: result);
    }
    return result;
  }
}
