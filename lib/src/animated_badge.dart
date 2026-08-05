import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'utils/motion.dart';

/// A count badge attached to a corner of a child that animates when the
/// count changes.
///
/// Typical uses are a cart icon or a notification bell. The badge scales in
/// from nothing when it first appears, scales out when the count drops to
/// zero (unless [showZero] is `true`), and does a quick bounce whenever the
/// count changes while it is visible. The count text itself swaps with a
/// small fade and slide.
///
/// ```dart
/// AnimatedBadge(
///   count: cartItems,
///   child: const Icon(Icons.shopping_cart),
/// )
/// ```
///
/// The badge is drawn in a non-clipping [Stack] overflowing the corner of
/// [child] given by [alignment], so it never affects the child's layout.
///
/// Accessibility: the badge is merged with the child and reports
/// [semanticLabel] (default: `'<count> items'`). With [announceChanges] set
/// to `true`, count changes are also announced politely to assistive
/// technology.
///
/// Reduced motion (or [enabled] set to `false`): the badge appears,
/// disappears and updates instantly.
class AnimatedBadge extends StatefulWidget {
  /// Creates an animated badge around [child].
  const AnimatedBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.badgeSize = 18.0,
    this.alignment = AlignmentDirectional.topEnd,
    this.offset = Offset.zero,
    this.showZero = false,
    this.maxCount,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.elasticOut,
    this.textStyle,
    this.semanticLabel,
    this.announceChanges = false,
    this.enabled = true,
  })  : assert(count >= 0, 'count must not be negative'),
        assert(badgeSize > 0, 'badgeSize must be positive'),
        assert(maxCount == null || maxCount > 0,
            'maxCount must be positive when provided');

  /// The widget the badge is attached to.
  final Widget child;

  /// The number shown inside the badge. Changing it triggers the animation.
  final int count;

  /// Background color of the badge. Defaults to `colorScheme.error`.
  final Color? badgeColor;

  /// Color of the count text. Defaults to `colorScheme.onError`.
  final Color? textColor;

  /// Diameter of the badge circle (it widens for multi-digit counts).
  /// Defaults to 18.
  final double badgeSize;

  /// Corner of [child] the badge is attached to. Defaults to
  /// [AlignmentDirectional.topEnd].
  final AlignmentGeometry alignment;

  /// Extra offset applied to the badge position. Defaults to [Offset.zero].
  final Offset offset;

  /// Whether the badge stays visible showing `0` when [count] is zero.
  /// Defaults to `false`.
  final bool showZero;

  /// Counts above this render as `'<maxCount>+'` (for example 99 renders
  /// counts of 100 and up as `99+`). `null` shows the exact count.
  final int? maxCount;

  /// Duration of the appear, disappear and bounce animations. Defaults to
  /// 300 milliseconds.
  final Duration duration;

  /// Curve of the scale animations. Defaults to [Curves.elasticOut].
  final Curve curve;

  /// Style of the count text. Merged over a theme-aware default.
  final TextStyle? textStyle;

  /// Semantics label for the badge. Defaults to `'<count> items'`.
  final String? semanticLabel;

  /// Whether count changes are announced politely to assistive technology.
  /// Off by default to avoid announcement spam.
  final bool announceChanges;

  /// When `false`, the badge appears, disappears and updates instantly.
  final bool enabled;

  @override
  State<AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<AnimatedBadge>
    with TickerProviderStateMixin {
  // Two controllers are justified here: visibility (appear/disappear) and
  // bounce (count changed while visible) are independent animations that
  // can overlap, e.g. a count change arriving while the badge scales in.
  late final AnimationController _visibility;
  late final AnimationController _bounce;
  late CurvedAnimation _visibilityScale;
  late Animation<double> _bounceScale;

  bool get _visible => widget.count > 0 || widget.showZero;

  @override
  void initState() {
    super.initState();
    _visibility = AnimationController(
      duration: widget.duration,
      vsync: this,
      value: _visible ? 1.0 : 0.0,
    );
    _bounce = AnimationController(duration: widget.duration, vsync: this);
    _visibilityScale = CurvedAnimation(
      parent: _visibility,
      curve: widget.curve,
      reverseCurve: Curves.easeIn,
    );
    _bounceScale = _createBounceScale();
  }

  Animation<double> _createBounceScale() {
    return TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: widget.curve)),
        weight: 60,
      ),
    ]).animate(_bounce);
  }

  @override
  void didUpdateWidget(AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _visibility.duration = widget.duration;
      _bounce.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _visibilityScale.dispose();
      _visibilityScale = CurvedAnimation(
        parent: _visibility,
        curve: widget.curve,
        reverseCurve: Curves.easeIn,
      );
      _bounceScale = _createBounceScale();
    }

    final bool wasVisible = oldWidget.count > 0 || oldWidget.showZero;
    final bool countChanged = widget.count != oldWidget.count;
    if (!countChanged && _visible == wasVisible) {
      return;
    }

    if (countChanged && widget.announceChanges) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _label,
        Directionality.of(context),
      );
    }

    final bool instant = !widget.enabled || MicroMotion.isReduced(context);
    if (_visible != wasVisible) {
      if (instant) {
        _bounce.value = 0.0;
        _visibility.value = _visible ? 1.0 : 0.0;
      } else if (_visible) {
        _visibility.forward();
      } else {
        _visibility.reverse();
      }
    } else if (countChanged && _visible && !instant) {
      // Quick bounce while the badge stays visible.
      _bounce.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _visibilityScale.dispose();
    _visibility.dispose();
    _bounce.dispose();
    super.dispose();
  }

  String get _displayText {
    final int? max = widget.maxCount;
    if (max != null && widget.count > max) {
      return '$max+';
    }
    return '${widget.count}';
  }

  String get _label => widget.semanticLabel ?? '${widget.count} items';

  Widget _buildBadge(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = _displayText;
    final TextStyle style = TextStyle(
      color: widget.textColor ?? scheme.onError,
      fontSize: widget.badgeSize * 0.6,
      fontWeight: FontWeight.bold,
      height: 1.0,
    ).merge(widget.textStyle);
    final Duration swapDuration = !widget.enabled
        ? Duration.zero
        : MicroMotion.effectiveDuration(
            context, const Duration(milliseconds: 150));

    return Container(
      constraints: BoxConstraints(minWidth: widget.badgeSize),
      height: widget.badgeSize,
      padding: EdgeInsets.symmetric(
        horizontal: text.length > 1 ? widget.badgeSize * 0.25 : 0,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.badgeColor ?? scheme.error,
        borderRadius: BorderRadius.circular(widget.badgeSize / 2),
      ),
      child: AnimatedSwitcher(
        duration: swapDuration,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Small fade plus slide for the count text swap.
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(text, key: ValueKey<String>(text), style: style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Alignment resolved =
        widget.alignment.resolve(Directionality.of(context));
    Widget badge = ScaleTransition(
      scale: _visibilityScale,
      child: ScaleTransition(
        scale: _bounceScale,
        child: _buildBadge(context),
      ),
    );
    badge = Semantics(
      label: _visible ? _label : null,
      child: ExcludeSemantics(child: badge),
    );

    return MergeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: Align(
              alignment: resolved,
              child: Transform.translate(
                offset: widget.offset,
                // Shift the badge half of its size past the corner so it
                // overflows the child without affecting layout.
                child: FractionalTranslation(
                  translation: Offset(resolved.x * 0.5, resolved.y * 0.5),
                  child: badge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
