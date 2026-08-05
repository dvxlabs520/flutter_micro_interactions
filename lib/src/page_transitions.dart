import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The transition styles supported by [MicroPageRoute].
enum MicroTransitionType {
  /// Fades the new page in.
  fade,

  /// Slides the new page in from the trailing (right) edge.
  slideRight,

  /// Slides the new page in from the leading (left) edge.
  slideLeft,

  /// Slides the new page in from the top edge.
  slideTop,

  /// Slides the new page in from the bottom edge.
  slideBottom,

  /// Scales the new page up from a point.
  scale,

  /// Rotates the new page in while fading.
  rotate,

  /// Grows the new page from zero height.
  size,

  /// Flips the new page in with a 3D rotation around the vertical axis.
  flip,

  /// Sharpens the new page from a blurred state while fading it in.
  blur,
}

/// A [PageRoute] with a configurable micro transition.
///
/// ```dart
/// Navigator.of(context).push(
///   MicroPageRoute(
///     child: const DetailPage(),
///     type: MicroTransitionType.fade,
///   ),
/// );
/// ```
///
/// The [curve] applies to every transition type. Transition types that can
/// reveal the previous page during the animation (fade, scale, rotate, flip,
/// blur) report [opaque] as `false` so the outgoing page stays visible
/// behind them.
///
/// Under reduced motion every transition falls back to a plain fade.
class MicroPageRoute<T> extends PageRoute<T> {
  /// Creates a page route with a micro transition.
  MicroPageRoute({
    required this.child,
    this.type = MicroTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.alignment,
    this.curve = Curves.easeInOut,
    this.maintainState = true,
    super.fullscreenDialog,
    super.settings,
  })  : assert(duration >= Duration.zero, 'duration must not be negative'),
        assert(reverseDuration >= Duration.zero,
            'reverseDuration must not be negative');

  /// The page to show.
  final Widget child;

  /// The transition style. Defaults to [MicroTransitionType.fade].
  final MicroTransitionType type;

  /// Duration of the forward transition. Defaults to 300 milliseconds.
  final Duration duration;

  /// Duration of the reverse transition. Defaults to 300 milliseconds.
  final Duration reverseDuration;

  /// Alignment for scale, rotate and size transitions.
  /// Defaults to [Alignment.center].
  final Alignment? alignment;

  /// Curve applied to every transition type.
  /// Defaults to [Curves.easeInOut].
  final Curve curve;

  @override
  final bool maintainState;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque {
    switch (type) {
      case MicroTransitionType.fade:
      case MicroTransitionType.scale:
      case MicroTransitionType.rotate:
      case MicroTransitionType.flip:
      case MicroTransitionType.blur:
        return false;
      case MicroTransitionType.slideRight:
      case MicroTransitionType.slideLeft:
      case MicroTransitionType.slideTop:
      case MicroTransitionType.slideBottom:
      case MicroTransitionType.size:
        return true;
    }
  }

  // Tweens are static so buildTransitions does not allocate them per frame.
  static final Tween<Offset> _slideRightTween =
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  static final Tween<Offset> _slideLeftTween =
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
  static final Tween<Offset> _slideTopTween =
      Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero);
  static final Tween<Offset> _slideBottomTween =
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);
  static final Tween<double> _quarterTurnTween =
      Tween<double>(begin: -0.25, end: 0.0);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MicroMotion.isReduced(context)) {
      // Reduced motion: a plain fade for every transition type.
      return FadeTransition(opacity: animation, child: child);
    }

    final Animation<double> curved =
        CurvedAnimation(parent: animation, curve: curve);

    switch (type) {
      case MicroTransitionType.fade:
        return FadeTransition(opacity: curved, child: child);
      case MicroTransitionType.slideRight:
        return SlideTransition(
          position: _slideRightTween.animate(curved),
          child: child,
        );
      case MicroTransitionType.slideLeft:
        return SlideTransition(
          position: _slideLeftTween.animate(curved),
          child: child,
        );
      case MicroTransitionType.slideTop:
        return SlideTransition(
          position: _slideTopTween.animate(curved),
          child: child,
        );
      case MicroTransitionType.slideBottom:
        return SlideTransition(
          position: _slideBottomTween.animate(curved),
          child: child,
        );
      case MicroTransitionType.scale:
        return ScaleTransition(
          scale: curved,
          alignment: alignment ?? Alignment.center,
          child: child,
        );
      case MicroTransitionType.rotate:
        return FadeTransition(
          opacity: curved,
          child: RotationTransition(
            turns: _quarterTurnTween.animate(curved),
            alignment: alignment ?? Alignment.center,
            child: child,
          ),
        );
      case MicroTransitionType.size:
        return Align(
          alignment: alignment ?? Alignment.center,
          child: SizeTransition(sizeFactor: curved, child: child),
        );
      case MicroTransitionType.flip:
        return AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) {
            final double t = curved.value;
            if (t < 0.5) {
              // First half: the incoming page is still facing away.
              return const SizedBox.shrink();
            }
            // Second half: rotate from 90 degrees to 0 with perspective.
            final double angle = (1.0 - (t - 0.5) * 2.0) * (math.pi / 2);
            final Matrix4 transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle);
            return Transform(
              transform: transform,
              alignment: alignment ?? Alignment.center,
              child: child,
            );
          },
        );
      case MicroTransitionType.blur:
        return FadeTransition(
          opacity: curved,
          child: AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final double sigma = (1.0 - curved.value) * 8.0;
              if (sigma <= 0.01) {
                return child!;
              }
              return ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: ui.TileMode.decal,
                ),
                child: child,
              );
            },
          ),
        );
    }
  }
}

/// Static navigation helpers that push pages with a [MicroPageRoute].
///
/// ```dart
/// MicroNavigator.push(
///   context,
///   const DetailPage(),
///   type: MicroTransitionType.slideRight,
/// );
/// ```
abstract final class MicroNavigator {
  /// Pushes [page] with a [MicroPageRoute] of the given [type].
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    MicroTransitionType type = MicroTransitionType.fade,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    Alignment? alignment,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return Navigator.of(context).push<T>(
      MicroPageRoute<T>(
        child: page,
        type: type,
        duration: duration,
        reverseDuration: reverseDuration,
        curve: curve,
        alignment: alignment,
        fullscreenDialog: fullscreenDialog,
        maintainState: maintainState,
      ),
    );
  }

  /// Replaces the current route with [page] using a [MicroPageRoute].
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    MicroTransitionType type = MicroTransitionType.fade,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    Alignment? alignment,
    bool fullscreenDialog = false,
    bool maintainState = true,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MicroPageRoute<T>(
        child: page,
        type: type,
        duration: duration,
        reverseDuration: reverseDuration,
        curve: curve,
        alignment: alignment,
        fullscreenDialog: fullscreenDialog,
        maintainState: maintainState,
      ),
      result: result,
    );
  }

  /// Pushes [page] with a [MicroPageRoute] and removes previous routes until
  /// [predicate] returns `true`.
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget page,
    RoutePredicate predicate, {
    MicroTransitionType type = MicroTransitionType.fade,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    Alignment? alignment,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MicroPageRoute<T>(
        child: page,
        type: type,
        duration: duration,
        reverseDuration: reverseDuration,
        curve: curve,
        alignment: alignment,
        fullscreenDialog: fullscreenDialog,
        maintainState: maintainState,
      ),
      predicate,
    );
  }
}
