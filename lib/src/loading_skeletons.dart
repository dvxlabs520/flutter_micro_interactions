import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// A scope that shares a single shimmer animation between every skeleton
/// below it.
///
/// Wrapping a screen (or a list of skeletons) in a [SkeletonScope] makes all
/// descendant [LoadingSkeleton] widgets reuse one ticker instead of creating
/// one [AnimationController] each, and keeps their shimmer bands in sync.
///
/// ```dart
/// SkeletonScope(
///   child: Column(
///     children: [
///       CardSkeleton(),
///       ListItemSkeleton(),
///     ],
///   ),
/// )
/// ```
///
/// When no scope is present, each [LoadingSkeleton] falls back to its own
/// controller. Under reduced motion the scope does not animate at all.
class SkeletonScope extends StatefulWidget {
  /// Creates a shimmer scope.
  const SkeletonScope({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// The subtree whose skeletons share this scope's shimmer animation.
  final Widget child;

  /// Duration of one shimmer sweep. Defaults to 1500 milliseconds.
  ///
  /// A change applies immediately, even while the shimmer is running.
  final Duration duration;

  /// The shared shimmer animation of the nearest enclosing [SkeletonScope],
  /// or `null` when there is none.
  ///
  /// The animation runs from 0.0 to 1.0 repeatedly.
  static Animation<double>? maybeAnimationOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonScopeInherited>()
        ?.animation;
  }

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(SkeletonScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        // A running repeat keeps the period it started with; restart it
        // from the current value so the new duration applies right away.
        _controller.repeat();
      }
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (MicroMotion.isReduced(context)) {
      _controller.stop();
      _controller.value = 0.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScopeInherited(animation: _controller, child: widget.child);
  }
}

class _SkeletonScopeInherited extends InheritedWidget {
  const _SkeletonScopeInherited({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonScopeInherited oldWidget) =>
      animation != oldWidget.animation;
}

/// A rectangular placeholder with an animated shimmer highlight.
///
/// This is the basic building block used by [TextSkeleton], [CardSkeleton],
/// [ListItemSkeleton] and [GridItemSkeleton].
///
/// ```dart
/// LoadingSkeleton(
///   width: 120,
///   height: 16,
///   borderRadius: BorderRadius.all(Radius.circular(4)),
/// )
/// ```
///
/// Colors default to values derived from the current [ColorScheme] so the
/// skeleton works in light and dark themes. When an enclosing [SkeletonScope]
/// exists its shared animation is reused; otherwise the widget drives its own
/// controller. Under reduced motion the shimmer is static.
///
/// The skeleton is excluded from semantics and announced as a single
/// "Loading" node.
class LoadingSkeleton extends StatefulWidget {
  /// Creates a loading skeleton.
  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
    this.child,
  });

  /// Width of the skeleton. Defaults to [double.infinity].
  final double width;

  /// Height of the skeleton. Defaults to 20.
  final double height;

  /// Corner radius of the skeleton. Defaults to a 4 pixel circular radius.
  final BorderRadiusGeometry borderRadius;

  /// Base color of the skeleton.
  ///
  /// Defaults to `colorScheme.surfaceContainerHighest`.
  final Color? baseColor;

  /// Highlight color of the shimmer band.
  ///
  /// Defaults to `colorScheme.onSurface` at 8% opacity blended over the base
  /// color, which stays visible in both light and dark themes.
  final Color? highlightColor;

  /// Duration of one shimmer sweep when this skeleton drives its own
  /// animation (no [SkeletonScope] present). Defaults to 1500 milliseconds.
  final Duration duration;

  /// Whether the skeleton effect is shown. When `false` and [child] is
  /// non-null the child renders normally; when `false` without a child the
  /// static base rectangle is drawn without shimmer.
  final bool enabled;

  /// Optional content drawn on top of the skeleton rectangle.
  final Widget? child;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownController;
  Animation<double>? _scopeAnimation;

  Animation<double> get _animation => _scopeAnimation ?? _ownController!;

  bool get _shouldAnimate => widget.enabled && !MicroMotion.isReduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeAnimation = SkeletonScope.maybeAnimationOf(context);
    _syncOwnController();
  }

  @override
  void didUpdateWidget(LoadingSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      final AnimationController? own = _ownController;
      if (own != null) {
        own.duration = widget.duration;
        if (own.isAnimating) {
          // Restart the running repeat so the new period applies now.
          own.repeat();
        }
      }
    }
    _syncOwnController();
  }

  /// Creates, starts, stops or discards the local controller depending on
  /// whether a scope animation is available and animation is wanted.
  void _syncOwnController() {
    if (_scopeAnimation != null || !_shouldAnimate) {
      _ownController?.stop();
      return;
    }
    _ownController ??= AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _ownController!.duration = widget.duration;
    if (!_ownController!.isAnimating) {
      _ownController!.repeat();
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && widget.child != null) {
      return widget.child!;
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base = widget.baseColor ?? scheme.surfaceContainerHighest;
    final Color highlight =
        widget.highlightColor ??
        Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.08), base);

    final Widget skeleton;
    if (!_shouldAnimate) {
      // Static placeholder: no shimmer loop under reduced motion or when
      // disabled without a child.
      skeleton = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: base,
        ),
        child: widget.child,
      );
    } else {
      // One DecoratedBox is rebuilt per frame; the gradient itself is the
      // only per-frame allocation (three colors and stops). The static child
      // subtree is passed through AnimatedBuilder.child and never rebuilt.
      skeleton = AnimatedBuilder(
        animation: _animation,
        child: widget.child,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: _shimmerGradient(base, highlight, _animation.value),
            ),
            child: child,
          );
        },
      );
    }

    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(child: skeleton),
    );
  }

  /// Builds the shimmer gradient for animation value [t] in `[0, 1]`.
  ///
  /// The highlight band travels from before the leading edge to past the
  /// trailing edge. Stops are clamped into `[0, 1]` and kept non-decreasing
  /// so the gradient never pops at the loop edges. Directional alignments
  /// make the sweep follow the ambient text direction (RTL aware).
  static LinearGradient _shimmerGradient(
    Color base,
    Color highlight,
    double t,
  ) {
    // Map t from [0, 1] to a band center travelling from -0.3 to 1.3 so the
    // highlight fully enters and exits the box.
    final double center = -0.3 + t * 1.6;
    final double start = (center - 0.3).clamp(0.0, 1.0);
    final double mid = center.clamp(start, 1.0);
    final double end = (center + 0.3).clamp(mid, 1.0);
    return LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      stops: [start, mid, end],
      colors: [base, highlight, base],
    );
  }
}

/// A skeleton made of one or more text-like lines.
///
/// The last line is drawn at [lastLineWidth] of the available width, aligned
/// to the reading start edge (RTL aware).
///
/// ```dart
/// TextSkeleton(lines: 3)
/// ```
class TextSkeleton extends StatelessWidget {
  /// Creates a text skeleton.
  const TextSkeleton({
    super.key,
    this.lines = 1,
    this.lineHeight = 16.0,
    this.lineSpacing = 8.0,
    this.lastLineWidth = 0.7,
    this.enabled = true,
  }) : assert(lines > 0, 'lines must be at least 1'),
       assert(lineHeight > 0, 'lineHeight must be positive'),
       assert(lineSpacing >= 0, 'lineSpacing must not be negative'),
       assert(
         lastLineWidth > 0 && lastLineWidth <= 1,
         'lastLineWidth must be in (0, 1]',
       );

  /// Number of lines. Defaults to 1.
  final int lines;

  /// Height of each line. Defaults to 16.
  final double lineHeight;

  /// Vertical gap between lines. Defaults to 8.
  final double lineSpacing;

  /// Width of the last line as a fraction of the available width, in
  /// `(0, 1]`. Defaults to 0.7.
  final double lastLineWidth;

  /// Whether the shimmer effect is shown.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final bool isLastLine = index == lines - 1;
        Widget line = LoadingSkeleton(
          width: double.infinity,
          height: lineHeight,
          enabled: enabled,
        );
        if (isLastLine && lastLineWidth < 1.0) {
          line = Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: lastLineWidth,
              child: line,
            ),
          );
        }
        return Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: isLastLine ? 0 : lineSpacing,
          ),
          child: line,
        );
      }),
    );
  }
}

/// A skeleton shaped like a card with an optional image area, a title and a
/// subtitle block.
///
/// ```dart
/// CardSkeleton(imageHeight: 140)
/// ```
class CardSkeleton extends StatelessWidget {
  /// Creates a card skeleton.
  const CardSkeleton({
    super.key,
    this.hasImage = true,
    this.imageHeight = 120.0,
    this.titleLines = 1,
    this.subtitleLines = 2,
    this.padding = const EdgeInsets.all(16.0),
    this.enabled = true,
  }) : assert(imageHeight > 0, 'imageHeight must be positive'),
       assert(titleLines > 0, 'titleLines must be at least 1'),
       assert(subtitleLines >= 0, 'subtitleLines must not be negative');

  /// Whether an image placeholder is shown at the top. Defaults to `true`.
  final bool hasImage;

  /// Height of the image placeholder. Defaults to 120.
  final double imageHeight;

  /// Number of title lines. Defaults to 1.
  final int titleLines;

  /// Number of subtitle lines. Defaults to 2.
  final int subtitleLines;

  /// Padding around the text content. Defaults to 16 on all sides.
  final EdgeInsetsGeometry padding;

  /// Whether the shimmer effect is shown.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            LoadingSkeleton(
              width: double.infinity,
              height: imageHeight,
              borderRadius: BorderRadius.zero,
              enabled: enabled,
            ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextSkeleton(
                  lines: titleLines,
                  lineHeight: 20.0,
                  enabled: enabled,
                ),
                const SizedBox(height: 12),
                if (subtitleLines > 0)
                  TextSkeleton(
                    lines: subtitleLines,
                    lineHeight: 14.0,
                    lastLineWidth: 0.6,
                    enabled: enabled,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton shaped like a list tile: optional leading avatar, title and
/// subtitle lines, and an optional trailing box.
///
/// ```dart
/// ListItemSkeleton(hasTrailing: true)
/// ```
class ListItemSkeleton extends StatelessWidget {
  /// Creates a list item skeleton.
  const ListItemSkeleton({
    super.key,
    this.hasAvatar = true,
    this.avatarSize = 40.0,
    this.titleLines = 1,
    this.subtitleLines = 1,
    this.hasTrailing = false,
    this.padding = const EdgeInsets.all(16.0),
    this.enabled = true,
  }) : assert(avatarSize > 0, 'avatarSize must be positive'),
       assert(titleLines > 0, 'titleLines must be at least 1'),
       assert(subtitleLines >= 0, 'subtitleLines must not be negative');

  /// Whether a circular avatar placeholder is shown. Defaults to `true`.
  final bool hasAvatar;

  /// Diameter of the avatar placeholder. Defaults to 40.
  final double avatarSize;

  /// Number of title lines. Defaults to 1.
  final int titleLines;

  /// Number of subtitle lines. Defaults to 1. Use 0 to hide the subtitle.
  final int subtitleLines;

  /// Whether a small trailing box is shown. Defaults to `false`.
  final bool hasTrailing;

  /// Padding around the content. Defaults to 16 on all sides.
  final EdgeInsetsGeometry padding;

  /// Whether the shimmer effect is shown.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (hasAvatar) ...[
            LoadingSkeleton(
              width: avatarSize,
              height: avatarSize,
              borderRadius: BorderRadius.all(Radius.circular(avatarSize / 2)),
              enabled: enabled,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextSkeleton(
                  lines: titleLines,
                  lineHeight: 16.0,
                  enabled: enabled,
                ),
                if (subtitleLines > 0) ...[
                  const SizedBox(height: 8),
                  TextSkeleton(
                    lines: subtitleLines,
                    lineHeight: 12.0,
                    lastLineWidth: 0.8,
                    enabled: enabled,
                  ),
                ],
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 16),
            LoadingSkeleton(width: 24, height: 24, enabled: enabled),
          ],
        ],
      ),
    );
  }
}

/// A skeleton shaped like a grid tile: an image area with title and subtitle
/// lines below it.
///
/// ```dart
/// GridItemSkeleton(imageAspectRatio: 4 / 3)
/// ```
class GridItemSkeleton extends StatelessWidget {
  /// Creates a grid item skeleton.
  const GridItemSkeleton({
    super.key,
    this.imageAspectRatio = 1.0,
    this.titleLines = 1,
    this.subtitleLines = 1,
    this.padding = const EdgeInsets.all(8.0),
    this.enabled = true,
  }) : assert(imageAspectRatio > 0, 'imageAspectRatio must be positive'),
       assert(titleLines > 0, 'titleLines must be at least 1'),
       assert(subtitleLines >= 0, 'subtitleLines must not be negative');

  /// Aspect ratio of the image placeholder. Defaults to 1 (square).
  final double imageAspectRatio;

  /// Number of title lines. Defaults to 1.
  final int titleLines;

  /// Number of subtitle lines. Defaults to 1. Use 0 to hide the subtitle.
  final int subtitleLines;

  /// Padding around the content. Defaults to 8 on all sides.
  final EdgeInsetsGeometry padding;

  /// Whether the shimmer effect is shown.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: imageAspectRatio,
            child: LoadingSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              enabled: enabled,
            ),
          ),
          const SizedBox(height: 8),
          TextSkeleton(lines: titleLines, lineHeight: 14.0, enabled: enabled),
          if (subtitleLines > 0) ...[
            const SizedBox(height: 4),
            TextSkeleton(
              lines: subtitleLines,
              lineHeight: 12.0,
              enabled: enabled,
            ),
          ],
        ],
      ),
    );
  }
}

/// Cross-fades between a skeleton and the real content.
///
/// ```dart
/// SkeletonLoader(
///   loading: isLoading,
///   skeleton: const CardSkeleton(),
///   child: MyCard(data: data),
/// )
/// ```
///
/// Under reduced motion the switch is instant.
class SkeletonLoader extends StatelessWidget {
  /// Creates a skeleton loader.
  const SkeletonLoader({
    super.key,
    required this.loading,
    required this.child,
    required this.skeleton,
    this.switchDuration = const Duration(milliseconds: 300),
    this.switchInCurve = Curves.easeIn,
    this.switchOutCurve = Curves.easeOut,
  });

  /// Whether the skeleton is shown instead of [child].
  final bool loading;

  /// The real content.
  final Widget child;

  /// The placeholder shown while [loading] is `true`.
  final Widget skeleton;

  /// Duration of the cross-fade. Defaults to 300 milliseconds.
  final Duration switchDuration;

  /// Curve of the incoming widget's fade. Defaults to [Curves.easeIn].
  final Curve switchInCurve;

  /// Curve of the outgoing widget's fade. Defaults to [Curves.easeOut].
  final Curve switchOutCurve;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MicroMotion.effectiveDuration(context, switchDuration),
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      child: loading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
