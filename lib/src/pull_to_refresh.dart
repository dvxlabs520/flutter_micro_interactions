import 'package:flutter/material.dart';

/// A thin wrapper around [RefreshIndicator] that adds pull-to-refresh to a
/// scrollable [child].
///
/// All styling parameters are passed through unchanged; when a value is not
/// provided the Material theme defaults apply.
///
/// ```dart
/// PullToRefresh(
///   onRefresh: () async => reload(),
///   child: ListView(children: items),
/// )
/// ```
///
/// Use [PullToRefresh.adaptive] to show the platform-appropriate spinner
/// (Cupertino style on iOS and macOS, Material elsewhere).
class PullToRefresh extends StatelessWidget {
  /// Creates a Material pull-to-refresh wrapper.
  const PullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshIndicatorColor,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
  }) : assert(displacement >= 0.0, 'displacement must be non-negative'),
       assert(strokeWidth > 0.0, 'strokeWidth must be positive'),
       _adaptive = false;

  /// Creates a pull-to-refresh wrapper whose indicator matches the platform.
  const PullToRefresh.adaptive({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshIndicatorColor,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
  }) : assert(displacement >= 0.0, 'displacement must be non-negative'),
       assert(strokeWidth > 0.0, 'strokeWidth must be positive'),
       _adaptive = true;

  /// The scrollable content to wrap.
  final Widget child;

  /// Called when the user triggers a refresh. The indicator stays visible
  /// until the returned future completes.
  final Future<void> Function() onRefresh;

  /// Color of the progress indicator. `null` uses the theme default.
  final Color? refreshIndicatorColor;

  /// Background color of the indicator circle. `null` uses the theme default.
  final Color? backgroundColor;

  /// How far from the edge the indicator settles. Defaults to `40.0`.
  final double displacement;

  /// Offset where the indicator starts to appear. Defaults to `0.0`.
  final double edgeOffset;

  /// Stroke width of the progress indicator.
  ///
  /// Defaults to [RefreshProgressIndicator.defaultStrokeWidth].
  final double strokeWidth;

  /// When the indicator may be triggered.
  ///
  /// Defaults to [RefreshIndicatorTriggerMode.onEdge].
  final RefreshIndicatorTriggerMode triggerMode;

  /// Which [ScrollNotification]s the indicator listens to.
  ///
  /// Defaults to [defaultScrollNotificationPredicate] (depth zero only).
  final ScrollNotificationPredicate notificationPredicate;

  /// Semantic label for the indicator. `null` uses the localized default.
  final String? semanticsLabel;

  /// Semantic value for the indicator.
  final String? semanticsValue;

  /// Whether this instance was created with [PullToRefresh.adaptive].
  final bool _adaptive;

  @override
  Widget build(BuildContext context) {
    if (_adaptive) {
      return RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        color: refreshIndicatorColor,
        backgroundColor: backgroundColor,
        displacement: displacement,
        edgeOffset: edgeOffset,
        strokeWidth: strokeWidth,
        triggerMode: triggerMode,
        notificationPredicate: notificationPredicate,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
        child: child,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: refreshIndicatorColor,
      backgroundColor: backgroundColor,
      displacement: displacement,
      edgeOffset: edgeOffset,
      strokeWidth: strokeWidth,
      triggerMode: triggerMode,
      notificationPredicate: notificationPredicate,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      child: child,
    );
  }
}
