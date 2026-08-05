import 'package:flutter/widgets.dart';

/// Utilities to respect the platform "reduce motion" accessibility setting.
///
/// Every animated widget in this package consults [isReduced] before running
/// decorative or looping animations. When the user has asked the system to
/// reduce motion, animations either render their final state directly or run
/// with [Duration.zero].
abstract final class MicroMotion {
  /// Whether the current platform requests reduced motion.
  ///
  /// Returns `false` when no [MediaQuery] is available.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or [Duration.zero] when reduced motion is requested.
  static Duration effectiveDuration(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
