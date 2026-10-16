import 'dart:async';

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The entrance animation played by [StaggeredItem] and [StaggeredList].
enum StaggerEffect {
  /// Fade in while sliding up from below the resting position.
  fadeSlideUp,

  /// Fade in while sliding down from above the resting position.
  fadeSlideDown,

  /// Fade in while sliding from the start side (left in LTR, right in RTL).
  fadeSlideStart,

  /// Fade in while sliding from the end side (right in LTR, left in RTL).
  fadeSlideEnd,

  /// Fade in without any movement.
  fade,

  /// Fade in while scaling up from slightly smaller than the resting size.
  scale,
}

/// A single item of a staggered entrance, usable inside any list or column.
///
/// The item starts invisible and plays its entrance ([StaggerEffect]) after
/// a delay of `index * staggerDelay`, so consecutive indices appear one
/// after another:
///
/// ```dart
/// Column(
///   children: [
///     for (var i = 0; i < titles.length; i++)
///       StaggeredItem(index: i, child: ListTile(title: Text(titles[i]))),
///   ],
/// )
/// ```
///
/// Each item owns one [AnimationController] started by a [Timer] that is
/// cancelled on dispose. This is one controller per item, which is fine in
/// practice because lazy lists only ever mount the visible items; see
/// [StaggeredList] for a ready-made list.
///
/// Because the entrance runs once per [State], an item that merely rebuilds
/// does not replay. Provide [maxDelay] to cap the start delay for items
/// mounted late (for example when they scroll into view), so deep indices
/// do not wait many seconds for their slot.
///
/// Under reduced motion, or when [enabled] is false, the child renders in
/// place instantly. The animation is decorative only and adds no semantics
/// beyond the child's own.
class StaggeredItem extends StatefulWidget {
  /// Creates one item of a staggered entrance.
  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.itemDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.curve = Curves.easeOutCubic,
    this.effect = StaggerEffect.fadeSlideUp,
    this.slideOffset = 24.0,
    this.maxDelay,
    this.enabled = true,
  }) : assert(index >= 0, 'index must not be negative'),
       assert(slideOffset >= 0, 'slideOffset must not be negative');

  /// The widget below this widget in the tree.
  final Widget child;

  /// Position of this item in the stagger sequence. The entrance starts
  /// after `index * staggerDelay`.
  final int index;

  /// Length of this item's entrance animation. Defaults to 400 milliseconds.
  final Duration itemDuration;

  /// Delay between the entrances of consecutive indices. Defaults to 60
  /// milliseconds.
  final Duration staggerDelay;

  /// Curve of the entrance. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Which entrance animation to play. Defaults to
  /// [StaggerEffect.fadeSlideUp].
  final StaggerEffect effect;

  /// Distance in logical pixels covered by the slide effects. Defaults
  /// to 24.
  final double slideOffset;

  /// Optional upper bound for the start delay. Useful for items mounted
  /// after the initial entrance (lazy lists), so `index * staggerDelay`
  /// cannot grow into a multi-second wait.
  final Duration? maxDelay;

  /// When false the child renders in place with no animation.
  final bool enabled;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;
  Timer? _timer;
  bool _scheduled = false;

  /// Scale used by [StaggerEffect.scale] at the start of the entrance.
  static const double _scaleBegin = 0.9;

  Duration get _delay {
    final Duration natural = widget.staggerDelay * widget.index;
    final Duration? cap = widget.maxDelay;
    if (cap != null && natural > cap) {
      return cap;
    }
    return natural;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.itemDuration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    if (!widget.enabled || MicroMotion.isReduced(context)) {
      _controller.value = 1.0;
      return;
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final Duration delay = _delay;
    if (delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _timer = Timer(delay, () {
      _timer = null;
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(StaggeredItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemDuration != oldWidget.itemDuration) {
      _controller.duration = widget.itemDuration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (!widget.enabled && oldWidget.enabled) {
      // Show the child instantly and stop any pending entrance.
      _timer?.cancel();
      _timer = null;
      _controller.value = 1.0;
      return;
    }
    // Reschedule a still-pending entrance when its timing inputs change.
    if (_timer != null &&
        (widget.index != oldWidget.index ||
            widget.staggerDelay != oldWidget.staggerDelay ||
            widget.maxDelay != oldWidget.maxDelay)) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset _beginOffset(TextDirection direction) {
    final double offset = widget.slideOffset;
    switch (widget.effect) {
      case StaggerEffect.fadeSlideUp:
        return Offset(0, offset);
      case StaggerEffect.fadeSlideDown:
        return Offset(0, -offset);
      case StaggerEffect.fadeSlideStart:
        return Offset(direction == TextDirection.ltr ? -offset : offset, 0);
      case StaggerEffect.fadeSlideEnd:
        return Offset(direction == TextDirection.ltr ? offset : -offset, 0);
      case StaggerEffect.fade:
      case StaggerEffect.scale:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (widget.effect == StaggerEffect.scale) {
      child = ScaleTransition(
        scale: _animation.drive(Tween<double>(begin: _scaleBegin, end: 1.0)),
        child: child,
      );
    } else if (widget.effect != StaggerEffect.fade) {
      final Offset begin = _beginOffset(Directionality.of(context));
      child = AnimatedBuilder(
        animation: _animation,
        // The subtree is static; only the translation changes per frame.
        child: child,
        builder: (BuildContext context, Widget? child) {
          final double remaining = 1.0 - _animation.value;
          return Transform.translate(offset: begin * remaining, child: child);
        },
      );
    }

    return FadeTransition(opacity: _animation, child: child);
  }
}

/// A scrollable list whose children animate in one after another with a
/// classic staggered entrance (fade plus slide by default).
///
/// ```dart
/// StaggeredList(
///   children: const [
///     ListTile(title: Text('One')),
///     ListTile(title: Text('Two')),
///     ListTile(title: Text('Three')),
///   ],
/// )
/// ```
///
/// Use [StaggeredList.builder] for long or infinite lists; it builds items
/// lazily like [ListView.builder]. Items that enter the viewport after the
/// initial entrance still play their animation, but their start delay is
/// capped at `3 * staggerDelay` so deep indices do not wait seconds for
/// their slot.
///
/// Each visible item owns one animation controller (see [StaggeredItem]);
/// off-screen items in a builder list do not exist and cost nothing.
///
/// When [animateOnlyOnce] is true (the default) rebuilds never replay the
/// entrance. When false, providing a different [children] list instance (or
/// a different `itemCount` for the builder variant) remounts the items and
/// replays the whole entrance.
///
/// Under reduced motion, or when [enabled] is false, the children render in
/// place instantly. The animation is decorative only and adds no semantics
/// beyond the children's own.
class StaggeredList extends StatefulWidget {
  /// Creates a staggered list from an explicit list of children.
  const StaggeredList({
    super.key,
    required List<Widget> this.children,
    this.itemDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.curve = Curves.easeOutCubic,
    this.effect = StaggerEffect.fadeSlideUp,
    this.slideOffset = 24.0,
    this.animateOnlyOnce = true,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.enabled = true,
  }) : assert(slideOffset >= 0, 'slideOffset must not be negative'),
       itemBuilder = null,
       itemCount = null;

  /// Creates a staggered list that builds items lazily, like
  /// [ListView.builder].
  const StaggeredList.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    this.itemDuration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.curve = Curves.easeOutCubic,
    this.effect = StaggerEffect.fadeSlideUp,
    this.slideOffset = 24.0,
    this.animateOnlyOnce = true,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.enabled = true,
  }) : assert(itemCount >= 0, 'itemCount must not be negative'),
       assert(slideOffset >= 0, 'slideOffset must not be negative'),
       children = null;

  /// The items of the list. Null when [StaggeredList.builder] is used.
  final List<Widget>? children;

  /// Builds the item at the given index. Null for the default constructor.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of items built by [itemBuilder]. Null for the default
  /// constructor.
  final int? itemCount;

  /// Length of each item's entrance animation. Defaults to 400
  /// milliseconds.
  final Duration itemDuration;

  /// Delay between the entrances of consecutive items. Defaults to 60
  /// milliseconds.
  final Duration staggerDelay;

  /// Curve of each entrance. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Which entrance animation to play. Defaults to
  /// [StaggerEffect.fadeSlideUp].
  final StaggerEffect effect;

  /// Distance in logical pixels covered by the slide effects. Defaults
  /// to 24.
  final double slideOffset;

  /// When true (the default) rebuilds never replay the entrance. When
  /// false, a new [children] instance or a changed [itemCount] replays it.
  final bool animateOnlyOnce;

  /// Optional scroll controller for the underlying [ListView].
  final ScrollController? controller;

  /// Optional padding around the list content.
  final EdgeInsetsGeometry? padding;

  /// Whether the list sizes itself to its content. Defaults to false.
  final bool shrinkWrap;

  /// Optional scroll physics for the underlying [ListView].
  final ScrollPhysics? physics;

  /// Scroll axis of the list. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// When false the children render in place with no animation.
  final bool enabled;

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList> {
  /// Bumped to remount all items when a replay is requested.
  int _generation = 0;

  /// Whether the frame that mounted the list has completed. Items built
  /// afterwards entered the viewport late and get a capped start delay.
  bool _initialFrameDone = false;

  /// Late-mounted items wait at most this many stagger slots.
  static const int _lateDelayCapSlots = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Read lazily by the item builder; no rebuild needed.
      _initialFrameDone = true;
    });
  }

  @override
  void didUpdateWidget(StaggeredList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateOnlyOnce) {
      return;
    }
    final bool childrenReplaced =
        widget.children != null &&
        !identical(widget.children, oldWidget.children);
    final bool countChanged =
        widget.itemCount != null && widget.itemCount != oldWidget.itemCount;
    if (childrenReplaced || countChanged) {
      setState(() {
        _generation++;
        _initialFrameDone = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initialFrameDone = true;
      });
    }
  }

  Widget _buildItem(BuildContext context, int index, Widget child) {
    return StaggeredItem(
      key: ValueKey<String>('staggered-item-$_generation-$index'),
      index: index,
      itemDuration: widget.itemDuration,
      staggerDelay: widget.staggerDelay,
      curve: widget.curve,
      effect: widget.effect,
      slideOffset: widget.slideOffset,
      maxDelay: _initialFrameDone
          ? widget.staggerDelay * _lateDelayCapSlots
          : null,
      enabled: widget.enabled,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget>? children = widget.children;
    if (children != null) {
      return ListView(
        controller: widget.controller,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        scrollDirection: widget.scrollDirection,
        children: <Widget>[
          for (int i = 0; i < children.length; i++)
            _buildItem(context, i, children[i]),
        ],
      );
    }
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      itemCount: widget.itemCount,
      itemBuilder: (BuildContext context, int index) {
        return _buildItem(context, index, widget.itemBuilder!(context, index));
      },
    );
  }
}
