import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Scroll physics that let content overscroll past its edges with a
/// configurable resistance, then spring back into place.
///
/// [ElasticScrollPhysics] is the engine behind [ElasticScroll],
/// [ElasticListView] and [ElasticGridView], and can also be applied directly
/// to any scrollable:
///
/// ```dart
/// ListView(
///   physics: const ElasticScrollPhysics(elasticity: 0.5),
///   children: items,
/// )
/// ```
///
/// * [elasticity] controls how far a drag past the edge moves the content.
/// * [stiffness] and [damping] shape the spring that pulls the content back.
class ElasticScrollPhysics extends ScrollPhysics {
  /// Creates elastic scroll physics.
  ///
  /// [elasticity] must be in `(0, 1]`, [stiffness] must be positive and
  /// [damping] must be positive.
  const ElasticScrollPhysics({
    super.parent,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
  })  : assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// How easily the content moves past the edge while dragging.
  ///
  /// `1.0` feels loose (content follows the finger far past the edge),
  /// values near `0.0` feel stiff. Defaults to `0.3`.
  final double elasticity;

  /// Stiffness of the spring that returns the content to the edge.
  ///
  /// Higher values snap back faster. Defaults to `100.0`.
  final double stiffness;

  /// Damping ratio of the return spring.
  ///
  /// `1.0` is critically damped (no bounce), values below `1.0` overshoot
  /// and oscillate slightly. Defaults to `0.8`.
  final double damping;

  @override
  ElasticScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ElasticScrollPhysics(
      parent: buildParent(ancestor),
      elasticity: elasticity,
      stiffness: stiffness,
      damping: damping,
    );
  }

  /// The resistance applied while dragging out of range.
  ///
  /// [overscrollFraction] is the current overscroll distance divided by the
  /// viewport dimension. The returned factor multiplies the user's drag
  /// delta, so it shrinks as the overscroll grows.
  double frictionFactor(double overscrollFraction) =>
      elasticity * math.pow(1 - overscrollFraction, 2);

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: stiffness,
        ratio: damping,
      );

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);

    if (!position.outOfRange) {
      return offset;
    }

    final double overscrollPastStart =
        math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd =
        math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast =
        math.max(overscrollPastStart, overscrollPastEnd);
    final bool easing = (overscrollPastStart > 0.0 && offset < 0.0) ||
        (overscrollPastEnd > 0.0 && offset > 0.0);

    final double friction = easing
        // Apply less resistance when easing the overscroll.
        ? frictionFactor(
            (overscrollPast - offset.abs()) / position.viewportDimension)
        : frictionFactor(overscrollPast / position.viewportDimension);
    final double direction = offset.sign;
    return direction * _applyFriction(overscrollPast, offset.abs(), friction);
  }

  static double _applyFriction(
      double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) {
        return absDelta * gamma;
      }
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) => 0.0;

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return BouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }
}

/// A thin wrapper that scrolls its [child] with [ElasticScrollPhysics].
///
/// The child is placed inside a [SingleChildScrollView]; the elastic effect
/// comes entirely from the physics, so there is no extra transform and no
/// rebuild per scroll frame.
///
/// ```dart
/// ElasticScroll(
///   child: Column(children: items),
/// )
/// ```
///
/// When the platform requests reduced motion the bounce is disabled and the
/// scroll view clamps at its edges.
class ElasticScroll extends StatelessWidget {
  /// Creates an elastic scroll wrapper.
  const ElasticScroll({
    super.key,
    required this.child,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.reverse = false,
    this.padding,
    this.enabled = true,
  })  : assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// The content to scroll.
  final Widget child;

  /// See [ElasticScrollPhysics.elasticity]. Defaults to `0.3`.
  final double elasticity;

  /// See [ElasticScrollPhysics.stiffness]. Defaults to `100.0`.
  final double stiffness;

  /// See [ElasticScrollPhysics.damping]. Defaults to `0.8`.
  final double damping;

  /// The axis along which the content scrolls. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Optional external scroll controller. The caller keeps ownership.
  final ScrollController? controller;

  /// Whether the scroll view reads in the reverse direction.
  final bool reverse;

  /// Padding around the content.
  final EdgeInsetsGeometry? padding;

  /// When `false` the elastic physics are not applied and the platform
  /// default scrolling behavior is used.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      controller: controller,
      reverse: reverse,
      padding: padding,
      physics: _elasticPhysicsFor(
        context,
        enabled: enabled,
        elasticity: elasticity,
        stiffness: stiffness,
        damping: damping,
      ),
      child: child,
    );
  }
}

/// Returns the effective physics for the elastic widgets.
///
/// Falls back to the ambient default when disabled, and to
/// [ClampingScrollPhysics] under reduced motion so the content never bounces.
ScrollPhysics? _elasticPhysicsFor(
  BuildContext context, {
  required bool enabled,
  required double elasticity,
  required double stiffness,
  required double damping,
}) {
  if (!enabled) {
    return null;
  }
  if (MicroMotion.isReduced(context)) {
    return const ClampingScrollPhysics();
  }
  return ElasticScrollPhysics(
    elasticity: elasticity,
    stiffness: stiffness,
    damping: damping,
  );
}

/// A [ListView] preconfigured with [ElasticScrollPhysics].
///
/// ```dart
/// ElasticListView.builder(
///   itemCount: 40,
///   itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
/// )
/// ```
class ElasticListView extends StatelessWidget {
  /// Creates an elastic list view from an explicit list of [children].
  const ElasticListView({
    super.key,
    required List<Widget> this.children,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.reverse = false,
    this.padding,
    this.enabled = true,
  })  : itemBuilder = null,
        itemCount = null,
        assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// Creates an elastic list view that builds items lazily.
  const ElasticListView.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.reverse = false,
    this.padding,
    this.enabled = true,
  })  : children = null,
        assert(itemCount >= 0, 'itemCount must be non-negative'),
        assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// The items of the list. `null` when using [ElasticListView.builder].
  final List<Widget>? children;

  /// Lazily builds each item. `null` when using the default constructor.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of items for [ElasticListView.builder].
  final int? itemCount;

  /// See [ElasticScrollPhysics.elasticity]. Defaults to `0.3`.
  final double elasticity;

  /// See [ElasticScrollPhysics.stiffness]. Defaults to `100.0`.
  final double stiffness;

  /// See [ElasticScrollPhysics.damping]. Defaults to `0.8`.
  final double damping;

  /// The axis along which the list scrolls. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Optional external scroll controller. The caller keeps ownership.
  final ScrollController? controller;

  /// Whether the list sizes itself to its children. Defaults to `false`.
  final bool shrinkWrap;

  /// Whether the list reads in the reverse direction.
  final bool reverse;

  /// Padding around the items.
  final EdgeInsetsGeometry? padding;

  /// When `false` the elastic physics are not applied.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ScrollPhysics? physics = _elasticPhysicsFor(
      context,
      enabled: enabled,
      elasticity: elasticity,
      stiffness: stiffness,
      damping: damping,
    );
    if (itemBuilder != null) {
      return ListView.builder(
        scrollDirection: scrollDirection,
        controller: controller,
        shrinkWrap: shrinkWrap,
        reverse: reverse,
        padding: padding,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: itemBuilder!,
      );
    }
    return ListView(
      scrollDirection: scrollDirection,
      controller: controller,
      shrinkWrap: shrinkWrap,
      reverse: reverse,
      padding: padding,
      physics: physics,
      children: children!,
    );
  }
}

/// A [GridView] preconfigured with [ElasticScrollPhysics].
///
/// ```dart
/// ElasticGridView(
///   crossAxisCount: 2,
///   children: tiles,
/// )
/// ```
class ElasticGridView extends StatelessWidget {
  /// Creates an elastic grid from an explicit list of [children].
  const ElasticGridView({
    super.key,
    required List<Widget> this.children,
    required this.crossAxisCount,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
    this.crossAxisSpacing = 0.0,
    this.mainAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.reverse = false,
    this.padding,
    this.enabled = true,
  })  : itemBuilder = null,
        itemCount = null,
        assert(crossAxisCount > 0, 'crossAxisCount must be positive'),
        assert(childAspectRatio > 0, 'childAspectRatio must be positive'),
        assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// Creates an elastic grid that builds tiles lazily.
  const ElasticGridView.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    required this.crossAxisCount,
    this.elasticity = 0.3,
    this.stiffness = 100.0,
    this.damping = 0.8,
    this.crossAxisSpacing = 0.0,
    this.mainAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.reverse = false,
    this.padding,
    this.enabled = true,
  })  : children = null,
        assert(itemCount >= 0, 'itemCount must be non-negative'),
        assert(crossAxisCount > 0, 'crossAxisCount must be positive'),
        assert(childAspectRatio > 0, 'childAspectRatio must be positive'),
        assert(elasticity > 0.0 && elasticity <= 1.0,
            'elasticity must be in (0, 1]'),
        assert(stiffness > 0.0, 'stiffness must be positive'),
        assert(damping > 0.0, 'damping must be positive');

  /// The tiles of the grid. `null` when using [ElasticGridView.builder].
  final List<Widget>? children;

  /// Lazily builds each tile. `null` when using the default constructor.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of tiles for [ElasticGridView.builder].
  final int? itemCount;

  /// Number of tiles on the cross axis.
  final int crossAxisCount;

  /// See [ElasticScrollPhysics.elasticity]. Defaults to `0.3`.
  final double elasticity;

  /// See [ElasticScrollPhysics.stiffness]. Defaults to `100.0`.
  final double stiffness;

  /// See [ElasticScrollPhysics.damping]. Defaults to `0.8`.
  final double damping;

  /// Spacing between tiles on the cross axis.
  final double crossAxisSpacing;

  /// Spacing between tiles on the main axis.
  final double mainAxisSpacing;

  /// The ratio of each tile's cross-axis to main-axis extent.
  final double childAspectRatio;

  /// The axis along which the grid scrolls. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Optional external scroll controller. The caller keeps ownership.
  final ScrollController? controller;

  /// Whether the grid sizes itself to its children. Defaults to `false`.
  final bool shrinkWrap;

  /// Whether the grid reads in the reverse direction.
  final bool reverse;

  /// Padding around the tiles.
  final EdgeInsetsGeometry? padding;

  /// When `false` the elastic physics are not applied.
  final bool enabled;

  SliverGridDelegate get _gridDelegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      );

  @override
  Widget build(BuildContext context) {
    final ScrollPhysics? physics = _elasticPhysicsFor(
      context,
      enabled: enabled,
      elasticity: elasticity,
      stiffness: stiffness,
      damping: damping,
    );
    if (itemBuilder != null) {
      return GridView.builder(
        gridDelegate: _gridDelegate,
        scrollDirection: scrollDirection,
        controller: controller,
        shrinkWrap: shrinkWrap,
        reverse: reverse,
        padding: padding,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: itemBuilder!,
      );
    }
    return GridView(
      gridDelegate: _gridDelegate,
      scrollDirection: scrollDirection,
      controller: controller,
      shrinkWrap: shrinkWrap,
      reverse: reverse,
      padding: padding,
      physics: physics,
      children: children!,
    );
  }
}
