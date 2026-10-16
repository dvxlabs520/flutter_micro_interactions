import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'utils/motion.dart';

/// The entrance played by [RevealOnScroll] when its child scrolls into
/// view. Every effect also fades from [RevealOnScroll.initialOpacity] to
/// fully opaque.
enum RevealEffect {
  /// Fade in without any movement.
  fade,

  /// Move up into place, starting [RevealOnScroll.distance] below it.
  slideUp,

  /// Move down into place, starting [RevealOnScroll.distance] above it.
  slideDown,

  /// Move left into place, starting [RevealOnScroll.distance] to its
  /// right.
  slideLeft,

  /// Move right into place, starting [RevealOnScroll.distance] to its
  /// left.
  slideRight,

  /// Grow into place from [RevealOnScroll.initialScale].
  scale,

  /// Come into focus from a Gaussian blur of
  /// [RevealOnScroll.blurSigma].
  blur,

  /// Swing upright in 3D, starting tilted back about 25 degrees around
  /// its horizontal axis, with perspective.
  tilt,
}

/// Animates its child in the first time it scrolls into view.
///
/// Wrap any widget inside a scrollable (a [ListView], a
/// [SingleChildScrollView], a sliver in a [CustomScrollView], a
/// horizontal list or a [PageView]) and it plays a short entrance when
/// enough of it becomes visible:
///
/// ```dart
/// ListView.builder(
///   itemCount: posts.length,
///   itemBuilder: (context, i) => RevealOnScroll(
///     effect: RevealEffect.slideUp,
///     child: PostCard(post: posts[i]),
///   ),
/// )
/// ```
///
/// For a staggered row of items that enter together, give each one a
/// growing [delay], for example `Duration(milliseconds: 80 * i)`.
///
/// Visibility is measured without plugins: the widget listens to the
/// scroll position of every enclosing [Scrollable] and, at most once per
/// frame, intersects its own bounds with each scrollable's viewport. It
/// also re-checks after its first layout, on rebuilds and when the screen
/// size changes. The entrance starts once the visible fraction reaches
/// [threshold]. For children taller (or wider) than the viewport, the
/// fraction is measured against the viewport instead, so they still
/// reveal. Without an enclosing scrollable the child reveals right after
/// it mounts.
///
/// With [once] set to true (the default) the widget stops listening after
/// the reveal. With [once] false, the child resets when it has completely
/// left the viewport, so the entrance plays again each time it enters.
/// Lazy lists dispose items that scroll far away; when such an item is
/// built again it is a new widget and reveals again. To reveal an item
/// only once per session, remember it in [onRevealed] and pass
/// `enabled: false` next time.
///
/// The entrance only changes opacity, transform and filters; the child is
/// laid out at its final size from the start, so scrolling never jumps.
/// While hidden the child is not painted, but it keeps its semantics and
/// can still be reached by screen readers.
///
/// Under reduced motion, or when [enabled] is false, the child is shown
/// immediately with no animation; [onRevealed] still fires when the child
/// scrolls into view.
class RevealOnScroll extends StatefulWidget {
  /// Creates a widget that reveals [child] when it scrolls into view.
  const RevealOnScroll({
    super.key,
    required this.child,
    this.effect = RevealEffect.slideUp,
    this.distance = 40.0,
    this.threshold = 0.15,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.once = true,
    this.initialOpacity = 0.0,
    this.initialScale = 0.9,
    this.blurSigma = 8.0,
    this.enabled = true,
    this.onRevealed,
  }) : assert(distance >= 0, 'distance must not be negative'),
       assert(
         threshold >= 0 && threshold <= 1,
         'threshold must be between 0 and 1',
       ),
       assert(
         initialOpacity >= 0 && initialOpacity <= 1,
         'initialOpacity must be between 0 and 1',
       ),
       assert(initialScale >= 0, 'initialScale must not be negative'),
       assert(blurSigma >= 0, 'blurSigma must not be negative');

  /// The widget to reveal.
  final Widget child;

  /// Which entrance to play. Defaults to [RevealEffect.slideUp].
  final RevealEffect effect;

  /// Distance in logical pixels covered by the slide effects. Defaults
  /// to 40.
  final double distance;

  /// Fraction of the child (0 to 1) that must be visible to start the
  /// entrance. 0 means any visible pixel. Defaults to 0.15.
  final double threshold;

  /// Length of the entrance. Defaults to 600 milliseconds.
  final Duration duration;

  /// Wait between the child becoming visible and the entrance starting.
  /// Defaults to [Duration.zero].
  final Duration delay;

  /// Curve of the entrance. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// When true (the default) the entrance plays only the first time the
  /// child becomes visible. When false it replays every time the child
  /// enters the viewport again after leaving it completely.
  final bool once;

  /// Opacity of the child before the entrance (0 to 1). Defaults to 0.
  final double initialOpacity;

  /// Starting scale of [RevealEffect.scale]. Defaults to 0.9.
  final double initialScale;

  /// Starting blur sigma of [RevealEffect.blur]. Defaults to 8.
  final double blurSigma;

  /// When false the child is shown immediately with no animation.
  /// Defaults to true.
  final bool enabled;

  /// Called each time the child has been revealed: when the entrance
  /// completes, or as soon as the child is visible under reduced motion
  /// or when [enabled] is false.
  final VoidCallback? onRevealed;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _curved;
  late Animation<double> _opacity;

  /// Enclosing scrollables, nearest first, and the positions listened to.
  List<ScrollableState> _scrollables = const <ScrollableState>[];
  List<ScrollPosition> _positions = const <ScrollPosition>[];

  Timer? _delayTimer;

  /// Latest visibility verdict.
  bool _visible = false;

  /// True once the reveal is final ([RevealOnScroll.once]); the widget
  /// then stops listening to scrolling.
  bool _settled = false;

  /// Whether the child is shown without animation (reduced motion or
  /// disabled). Null until the first dependency check.
  bool? _static;

  bool _checkScheduled = false;

  /// Whether [RevealOnScroll.onRevealed] should fire when the running
  /// entrance completes.
  bool _notifyOnComplete = false;

  /// Perspective strength of [RevealEffect.tilt].
  static const double _perspective = 0.0015;

  /// Starting angle of [RevealEffect.tilt]: about 25 degrees, top edge
  /// leaning away from the viewer.
  static const double _tiltAngle = -25 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_handleStatus);
    _createAnimations();
  }

  void _createAnimations() {
    _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = _curved.drive(
      Tween<double>(begin: widget.initialOpacity, end: 1.0),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depend on the screen size so a resize re-runs the visibility check.
    MediaQuery.maybeSizeOf(context);
    _updateMode();
    _syncScrollables();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(RevealOnScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve ||
        widget.initialOpacity != oldWidget.initialOpacity) {
      _curved.dispose();
      _createAnimations();
    }
    if (widget.enabled != oldWidget.enabled) {
      _updateMode();
    }
    if (widget.delay != oldWidget.delay && _delayTimer != null) {
      _startEntrance();
    }
    if (widget.once != oldWidget.once) {
      _settled = widget.once && _visible;
      _syncScrollables();
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _detach();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Switches between animated and static presentation.
  void _updateMode() {
    final bool isStatic = !widget.enabled || MicroMotion.isReduced(context);
    if (isStatic == _static) {
      return;
    }
    _static = isStatic;
    if (isStatic) {
      _delayTimer?.cancel();
      _delayTimer = null;
      // Completing a running entrance still reports the reveal.
      _controller.value = 1.0;
    } else if (!_visible) {
      _controller.value = 0.0;
    }
  }

  // Scroll tracking -------------------------------------------------------

  void _syncScrollables() {
    if (_settled) {
      _detach();
      return;
    }
    final List<ScrollableState> next = <ScrollableState>[];
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      next.add(scrollable);
      // Outer scrollables clip too (a carousel inside a vertical page).
      // No dependency is needed on them: only scroll offsets matter.
      scrollable = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
    }
    final List<ScrollPosition> positions = <ScrollPosition>[
      for (final ScrollableState s in next) s.position,
    ];
    _scrollables = next;
    if (_samePositions(positions)) {
      return;
    }
    _detach();
    _positions = positions;
    for (final ScrollPosition position in _positions) {
      position.addListener(_scheduleCheck);
    }
  }

  bool _samePositions(List<ScrollPosition> other) {
    if (other.length != _positions.length) {
      return false;
    }
    for (int i = 0; i < other.length; i++) {
      if (!identical(other[i], _positions[i])) {
        return false;
      }
    }
    return true;
  }

  void _detach() {
    for (final ScrollPosition position in _positions) {
      position.removeListener(_scheduleCheck);
    }
    _positions = const <ScrollPosition>[];
    if (_settled) {
      _scrollables = const <ScrollableState>[];
    }
  }

  /// Coalesces scroll notifications into one check after the next layout.
  void _scheduleCheck() {
    if (_checkScheduled || _settled) {
      return;
    }
    _checkScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _checkScheduled = false;
      if (mounted) {
        _check();
      }
    }, debugLabel: 'RevealOnScroll.check');
  }

  void _check() {
    if (_settled) {
      return;
    }
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return;
    }
    _setVisible(_isVisible(box));
  }

  bool _isVisible(RenderBox box) {
    if (_scrollables.isEmpty) {
      return true;
    }
    // Measured on this widget's own render box, which sits outside the
    // entrance transforms, so the reveal itself never affects the result.
    final Rect bounds = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    Rect region = Rect.largest;
    for (final ScrollableState scrollable in _scrollables) {
      final RenderObject? viewport = scrollable.context.findRenderObject();
      if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
        continue;
      }
      region = region.intersect(
        MatrixUtils.transformRect(
          viewport.getTransformTo(null),
          Offset.zero & viewport.size,
        ),
      );
    }
    if (region.width <= 0 || region.height <= 0) {
      return false;
    }
    if (bounds.width <= 0 || bounds.height <= 0) {
      // A zero-sized child is visible when its position is.
      return region.inflate(0.5).contains(bounds.topLeft);
    }
    final Rect overlap = bounds.intersect(region);
    if (overlap.width <= 0 || overlap.height <= 0) {
      return false;
    }
    final double overlapArea = overlap.width * overlap.height;
    final double reference = math.min(
      bounds.width * bounds.height,
      region.width * region.height,
    );
    final double fraction = overlapArea / reference;
    if (_visible) {
      // Already revealed: only a complete exit resets it.
      return true;
    }
    return fraction >= widget.threshold;
  }

  // Reveal ----------------------------------------------------------------

  void _setVisible(bool visible) {
    if (visible == _visible) {
      return;
    }
    _visible = visible;
    if (visible) {
      if (widget.once) {
        _settled = true;
        _detach();
      }
      if (_static ?? false) {
        _controller.value = 1.0;
        widget.onRevealed?.call();
      } else {
        _startEntrance();
      }
    } else {
      // Off screen now, so the reset is invisible and costs no frames.
      _delayTimer?.cancel();
      _delayTimer = null;
      _notifyOnComplete = false;
      if (!(_static ?? false)) {
        _controller.value = 0.0;
      }
    }
  }

  void _startEntrance() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _notifyOnComplete = true;
    if (widget.delay <= Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      _delayTimer = null;
      if (mounted) {
        _controller.forward();
      }
    });
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _notifyOnComplete) {
      _notifyOnComplete = false;
      if (_visible) {
        widget.onRevealed?.call();
      }
    }
  }

  // Build -----------------------------------------------------------------

  Matrix4? _transformFor(double t) {
    final double remaining = 1.0 - t;
    if (remaining == 0.0) {
      return null;
    }
    final double d = widget.distance * remaining;
    switch (widget.effect) {
      case RevealEffect.fade:
      case RevealEffect.blur:
        return null;
      case RevealEffect.slideUp:
        return Matrix4.translationValues(0, d, 0);
      case RevealEffect.slideDown:
        return Matrix4.translationValues(0, -d, 0);
      case RevealEffect.slideLeft:
        return Matrix4.translationValues(d, 0, 0);
      case RevealEffect.slideRight:
        return Matrix4.translationValues(-d, 0, 0);
      case RevealEffect.scale:
        final double s = ui.lerpDouble(widget.initialScale, 1.0, t)!;
        return Matrix4.diagonal3Values(s, s, 1.0);
      case RevealEffect.tilt:
        return Matrix4.identity()
          ..setEntry(3, 2, _perspective)
          ..rotateX(_tiltAngle * remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      // Hidden children stay reachable by screen readers.
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: _curved,
        child: widget.child,
        builder: (BuildContext context, Widget? child) {
          final double t = _curved.value;
          final double sigma = widget.effect == RevealEffect.blur
              ? math.max(0.0, widget.blurSigma * (1.0 - t))
              : 0.0;
          // A stable tree shape keeps the child's state when the effect
          // or the progress changes; identity transforms and disabled
          // filters cost nothing.
          return Transform(
            transform: _transformFor(t) ?? Matrix4.identity(),
            alignment: Alignment.center,
            child: ImageFiltered(
              enabled: sigma > 0.0,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
