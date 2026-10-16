import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import 'utils/motion.dart';

/// A slide-to-reveal wrapper that exposes tappable actions behind a list
/// item, in the style of mail and messaging apps.
///
/// Dragging the [child] horizontally reveals [leftActions] (drag to the
/// right) or [rightActions] (drag to the left). Each action is a button with
/// an icon and a label; tapping it fires [MicroSwipeAction.onPressed] and
/// closes the row. The row also closes when the user taps outside it or when
/// the enclosing scrollable scrolls.
///
/// ```dart
/// SwipeActions(
///   rightActions: [
///     MicroSwipeAction.delete(context, onPressed: () => remove(item)),
///   ],
///   child: ListTile(title: Text(item.title)),
/// )
/// ```
///
/// With [performsFirstActionOnFullSwipe] enabled, dragging far past the
/// action extent triggers the first action of that side immediately on
/// release.
///
/// Every action with a callback is also exposed as a
/// [CustomSemanticsAction], so assistive technology can trigger it without
/// the gesture. Under reduced motion the reveal still works but snaps
/// instantly instead of animating.
class SwipeActions extends StatefulWidget {
  /// Creates a swipe actions wrapper.
  ///
  /// [actionExtentRatio] is the fraction of the row width occupied by each
  /// action button and must be in `(0, 0.5]`.
  const SwipeActions({
    super.key,
    required this.child,
    this.leftActions = const <MicroSwipeAction>[],
    this.rightActions = const <MicroSwipeAction>[],
    this.actionExtentRatio = 0.25,
    this.performsFirstActionOnFullSwipe = false,
    this.enabled = true,
  }) : assert(
         actionExtentRatio > 0.0 && actionExtentRatio <= 0.5,
         'actionExtentRatio must be in (0, 0.5]',
       );

  /// The content of the row.
  final Widget child;

  /// Actions revealed when dragging the child to the right.
  final List<MicroSwipeAction> leftActions;

  /// Actions revealed when dragging the child to the left.
  final List<MicroSwipeAction> rightActions;

  /// Fraction of the row width used by each revealed action button.
  ///
  /// Defaults to `0.25` (a side with two actions reveals half the row).
  final double actionExtentRatio;

  /// When `true`, dragging past 60% of the row width and releasing triggers
  /// the first action of that side immediately. Defaults to `false`.
  final bool performsFirstActionOnFullSwipe;

  /// When `false` the child renders normally and no gesture is attached.
  final bool enabled;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  /// The horizontal offset of the child in pixels. Positive values reveal
  /// [SwipeActions.leftActions], negative values [SwipeActions.rightActions].
  ///
  /// Initialized eagerly in [initState]: a lazy `late` initializer could be
  /// touched for the first time in [dispose] (when the widget was never
  /// enabled), which would create the ticker on a deactivated element.
  late final AnimationController _offset;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this, value: 0.0);
  }

  ScrollPosition? _parentScrollPosition;
  double _rowWidth = 0.0;

  static const double _fullSwipeFraction = 0.6;
  static const double _flingVelocity = 500.0;
  static const double _openTolerance = 0.5;

  double get _leftExtent => widget.leftActions.isEmpty
      ? 0.0
      : _rowWidth * widget.actionExtentRatio * widget.leftActions.length;

  double get _rightExtent => widget.rightActions.isEmpty
      ? 0.0
      : _rowWidth * widget.actionExtentRatio * widget.rightActions.length;

  bool get _isOpen => _offset.value.abs() > _openTolerance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _parentScrollPosition)) {
      _parentScrollPosition?.removeListener(_handleParentScroll);
      _parentScrollPosition = position;
      _parentScrollPosition?.addListener(_handleParentScroll);
    }
  }

  @override
  void didUpdateWidget(SwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _offset
        ..stop()
        ..value = 0.0;
    } else if (widget.actionExtentRatio != oldWidget.actionExtentRatio ||
        widget.leftActions.length != oldWidget.leftActions.length ||
        widget.rightActions.length != oldWidget.rightActions.length) {
      if (_rowWidth > 0.0 && !_offset.isAnimating) {
        _offset.value = _offset.value.clamp(-_rightExtent, _leftExtent);
      }
    }
  }

  @override
  void dispose() {
    _parentScrollPosition?.removeListener(_handleParentScroll);
    _offset.dispose();
    super.dispose();
  }

  void _handleParentScroll() {
    if (mounted && _isOpen) {
      _close();
    }
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    _offset.stop();
    if (MicroMotion.isReduced(context)) {
      _offset.value = target;
      return;
    }
    final SpringDescription spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 500.0,
      ratio: 1.1,
    );
    _offset.animateWith(
      SpringSimulation(spring, _offset.value, target, velocity),
    );
  }

  void _close() => _animateTo(0.0);

  void _handleDragUpdate(DragUpdateDetails details) {
    final bool fullSwipe = widget.performsFirstActionOnFullSwipe;
    final double upper = widget.leftActions.isEmpty
        ? 0.0
        : (fullSwipe ? _rowWidth : _leftExtent);
    final double lower = widget.rightActions.isEmpty
        ? 0.0
        : -(fullSwipe ? _rowWidth : _rightExtent);
    _offset.stop();
    _offset.value = (_offset.value + details.delta.dx).clamp(lower, upper);
  }

  void _handleDragEnd(DragEndDetails details) {
    final double value = _offset.value;
    final double velocity = details.primaryVelocity ?? 0.0;

    // Full swipe: fire the first action of the revealed side right away.
    if (widget.performsFirstActionOnFullSwipe &&
        value.abs() >= _rowWidth * _fullSwipeFraction) {
      final MicroSwipeAction action = value > 0.0
          ? widget.leftActions.first
          : widget.rightActions.first;
      action.onPressed?.call();
      _close();
      return;
    }

    if (value > 0.0 && _leftExtent > 0.0) {
      final bool open =
          velocity > _flingVelocity ||
          (velocity > -_flingVelocity && value > _leftExtent / 2);
      _animateTo(open ? _leftExtent : 0.0, velocity: velocity);
    } else if (value < 0.0 && _rightExtent > 0.0) {
      final bool open =
          velocity < -_flingVelocity ||
          (velocity < _flingVelocity && value < -_rightExtent / 2);
      _animateTo(open ? -_rightExtent : 0.0, velocity: velocity);
    } else {
      _close();
    }
  }

  void _handleTap() {
    if (_isOpen) {
      _close();
    }
  }

  void _handleTapOutside(PointerDownEvent event) {
    if (_isOpen) {
      _close();
    }
  }

  Widget _buildActionButton(MicroSwipeAction action) {
    final Color foreground =
        action.foregroundColor ??
        (ThemeData.estimateBrightnessForColor(action.backgroundColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black87);
    return Expanded(
      child: Material(
        color: action.backgroundColor,
        child: InkWell(
          onTap: () {
            action.onPressed?.call();
            _close();
          },
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(action.icon, color: foreground, size: 24.0),
                    const SizedBox(height: 4.0),
                    Text(
                      action.label,
                      style: TextStyle(color: foreground, fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required List<MicroSwipeAction> actions,
    required bool leading,
  }) {
    return Positioned(
      top: 0.0,
      bottom: 0.0,
      left: leading ? 0.0 : null,
      right: leading ? null : 0.0,
      child: AnimatedBuilder(
        animation: _offset,
        child: Row(
          children: <Widget>[
            for (final MicroSwipeAction action in actions)
              _buildActionButton(action),
          ],
        ),
        builder: (BuildContext context, Widget? child) {
          final double revealed = leading
              ? _offset.value.clamp(0.0, double.infinity)
              : (-_offset.value).clamp(0.0, double.infinity);
          return SizedBox(width: revealed, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        (widget.leftActions.isEmpty && widget.rightActions.isEmpty)) {
      return widget.child;
    }

    final Map<CustomSemanticsAction, VoidCallback> semanticsActions =
        <CustomSemanticsAction, VoidCallback>{
          for (final MicroSwipeAction action in <MicroSwipeAction>[
            ...widget.leftActions,
            ...widget.rightActions,
          ])
            if (action.onPressed != null)
              CustomSemanticsAction(label: action.label): action.onPressed!,
        };

    return Semantics(
      customSemanticsActions: semanticsActions,
      child: TapRegion(
        onTapOutside: _handleTapOutside,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            _rowWidth = constraints.maxWidth;
            return GestureDetector(
              onTap: _handleTap,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: ClipRect(
                child: Stack(
                  children: <Widget>[
                    if (widget.leftActions.isNotEmpty)
                      _buildActionRow(
                        actions: widget.leftActions,
                        leading: true,
                      ),
                    if (widget.rightActions.isNotEmpty)
                      _buildActionRow(
                        actions: widget.rightActions,
                        leading: false,
                      ),
                    AnimatedBuilder(
                      animation: _offset,
                      child: widget.child,
                      builder: (BuildContext context, Widget? child) {
                        return Transform.translate(
                          offset: Offset(_offset.value, 0.0),
                          child: child,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Describes one revealable action of a [SwipeActions] row.
///
/// ```dart
/// MicroSwipeAction(
///   icon: Icons.archive,
///   label: 'Archive',
///   backgroundColor: Theme.of(context).colorScheme.secondary,
///   onPressed: archive,
/// )
/// ```
///
/// The factory constructors ([MicroSwipeAction.delete],
/// [MicroSwipeAction.archive], [MicroSwipeAction.favorite],
/// [MicroSwipeAction.share]) read their colors from the ambient
/// [ColorScheme]; the delete action uses [ColorScheme.error].
class MicroSwipeAction {
  /// Creates a swipe action.
  const MicroSwipeAction({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    this.foregroundColor,
    this.onPressed,
  });

  /// The icon shown on the action button.
  final IconData icon;

  /// The text shown under the icon. Also used as the label of the action's
  /// [CustomSemanticsAction].
  final String label;

  /// The background color of the action button.
  final Color backgroundColor;

  /// The icon and label color. When `null` a contrasting color is derived
  /// from [backgroundColor].
  final Color? foregroundColor;

  /// Called when the action is triggered (button tap, full swipe, or
  /// semantics action).
  final VoidCallback? onPressed;

  /// A delete action colored with [ColorScheme.error].
  factory MicroSwipeAction.delete(
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MicroSwipeAction(
      icon: Icons.delete,
      label: 'Delete',
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      onPressed: onPressed,
    );
  }

  /// An archive action colored with [ColorScheme.secondary].
  factory MicroSwipeAction.archive(
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MicroSwipeAction(
      icon: Icons.archive,
      label: 'Archive',
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      onPressed: onPressed,
    );
  }

  /// A favorite action colored with [ColorScheme.tertiary].
  factory MicroSwipeAction.favorite(
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MicroSwipeAction(
      icon: Icons.favorite,
      label: 'Favorite',
      backgroundColor: scheme.tertiary,
      foregroundColor: scheme.onTertiary,
      onPressed: onPressed,
    );
  }

  /// A share action colored with [ColorScheme.primary].
  factory MicroSwipeAction.share(
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MicroSwipeAction(
      icon: Icons.share,
      label: 'Share',
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      onPressed: onPressed,
    );
  }
}
