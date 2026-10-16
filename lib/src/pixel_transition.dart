import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// Programmatic control for a [PixelTransition] widget.
///
/// ```dart
/// final controller = PixelTransitionController();
/// // ...
/// PixelTransition(
///   controller: controller,
///   trigger: PixelTransitionTrigger.manual,
///   firstChild: const CoverImage(),
///   secondChild: const Details(),
/// );
/// // later:
/// controller.toggle();
/// ```
///
/// [isShowingSecond] reflects the side the attached widget is showing or
/// heading to. Dispose the controller yourself when it is no longer needed.
class PixelTransitionController extends ChangeNotifier {
  _PixelCommand? _pending;

  /// Reported back by the attached widget.
  bool _isShowingSecond = false;

  /// Whether the attached [PixelTransition] is showing, or transitioning
  /// to, its second child.
  bool get isShowingSecond => _isShowingSecond;

  /// Transitions to the second child (no-op when already there).
  void showSecond() => _send(_PixelCommand.second);

  /// Transitions to the first child (no-op when already there).
  void showFirst() => _send(_PixelCommand.first);

  /// Transitions to the other child.
  void toggle() => _send(_PixelCommand.toggle);

  void _send(_PixelCommand command) {
    _pending = command;
    notifyListeners();
  }
}

enum _PixelCommand { first, second, toggle }

/// What starts a [PixelTransition].
enum PixelTransitionTrigger {
  /// A mouse entering shows the second child and leaving shows the first
  /// one again. Touch devices, which cannot hover, toggle on tap instead.
  hover,

  /// Every tap or click toggles between the two children.
  tap,

  /// No built-in gesture; only `showSecond` and the controller change the
  /// visible child.
  manual,
}

/// A retro pixel dissolve between two children.
///
/// ```dart
/// PixelTransition(
///   gridSize: 12,
///   firstChild: Image.asset('assets/cat.jpg', width: 240, height: 240),
///   secondChild: const SizedBox(
///     width: 240,
///     height: 240,
///     child: Center(child: Text('Meow!')),
///   ),
/// )
/// ```
///
/// A grid of [gridSize] by [gridSize] solid cells in [pixelColor] appears
/// cell by cell, in random order, until it covers [firstChild]. Under full
/// coverage the content swaps to [secondChild], then the cells disappear in
/// a new random order to reveal it. The cover and the reveal each take half
/// of [duration]. Going back runs the same dissolve in the other direction.
/// Changing direction mid-transition retraces the cells already drawn, so
/// rapid toggles never jump.
///
/// Both children are laid out on top of each other, centered, and the
/// widget takes the size of the larger one. Both stay mounted, so their
/// state survives transitions. The whole widget is clipped to
/// [borderRadius].
///
/// What starts a transition depends on [trigger]: hover by default (with a
/// tap fallback on touch devices), tap, or manual. Like a [Switch], the
/// widget can be uncontrolled or controlled:
///
/// * Uncontrolled ([showSecond] is null): gestures and [controller]
///   commands transition the widget themselves and [onChanged] reports the
///   new side.
/// * Controlled ([showSecond] is non-null): the widget always transitions
///   to the side the parent dictates. Gestures and controller commands only
///   call [onChanged] with the requested side.
///
/// Only the child currently on screen is visible to assistive technology
/// and receives pointer events; the hidden child is excluded from both. The
/// cells are decorative and add no semantics. With a tap trigger the widget
/// exposes a tap action, so screen reader users can switch sides too.
///
/// Under reduced motion, or when [enabled] is `false`, sides swap
/// instantly without cells. When [enabled] is `false` gestures and
/// controller commands are ignored, while a new [showSecond] value still
/// applies.
class PixelTransition extends StatefulWidget {
  /// Creates a pixel dissolve between [firstChild] and [secondChild].
  const PixelTransition({
    super.key,
    required this.firstChild,
    required this.secondChild,
    this.gridSize = 12,
    this.pixelColor,
    this.duration = const Duration(milliseconds: 600),
    this.trigger = PixelTransitionTrigger.hover,
    this.showSecond,
    this.onChanged,
    this.controller,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.seed,
    this.enabled = true,
  }) : assert(
         gridSize >= 1 && gridSize <= 100,
         'gridSize must be between 1 and 100',
       );

  /// The child shown at rest, before any transition.
  final Widget firstChild;

  /// The child revealed by the transition.
  final Widget secondChild;

  /// Number of cells along each side of the grid, so the grid has
  /// `gridSize * gridSize` cells. Cells stretch to the widget's aspect
  /// ratio. Must be between 1 and 100. Defaults to 12.
  final int gridSize;

  /// Color of the cells. Defaults to the theme's `colorScheme.primary`.
  final Color? pixelColor;

  /// Total length of one transition: half to cover, half to reveal.
  /// Defaults to 600 milliseconds.
  final Duration duration;

  /// What starts a transition. Defaults to [PixelTransitionTrigger.hover].
  final PixelTransitionTrigger trigger;

  /// When non-null the widget is controlled: `true` shows [secondChild],
  /// `false` shows [firstChild], and gestures only report through
  /// [onChanged].
  final bool? showSecond;

  /// Called with the requested side (`true` = [secondChild]) whenever a
  /// gesture or controller command asks for the other side. In controlled
  /// mode this is a request; the parent applies it by rebuilding with a new
  /// [showSecond]. The visual swap happens later, under full coverage.
  final ValueChanged<bool>? onChanged;

  /// Optional controller for programmatic transitions.
  final PixelTransitionController? controller;

  /// Corner rounding used to clip both children and the cells. Defaults to
  /// a 12 pixel circular radius.
  final BorderRadius borderRadius;

  /// Seed for the random cell order. Set it for a reproducible sequence,
  /// for example in tests. Defaults to null, which picks a new random
  /// order every time.
  final int? seed;

  /// When `false` sides swap instantly and gestures and controller
  /// commands are ignored. Defaults to `true`.
  final bool enabled;

  @override
  State<PixelTransition> createState() => _PixelTransitionState();
}

class _PixelTransitionState extends State<PixelTransition>
    with SingleTickerProviderStateMixin {
  /// Progress of the current transition from [_from] to [_to]: 0 shows
  /// [_from] uncovered, 0.5 is full coverage, 1 shows [_to] uncovered.
  late final AnimationController _progress;

  /// Side the current transition starts from (`true` = second child).
  bool _from = false;

  /// Side the current transition goes to.
  bool _to = false;

  /// Side whose content is currently on screen.
  bool _displayed = false;

  /// Cell orders of the current transition.
  _PixelPlan _plan = _PixelPlan.empty;

  late math.Random _random;
  bool _reduced = false;
  bool _hovered = false;

  /// Device kind of the tap in progress, read in [_handleTap].
  PointerDeviceKind? _tapKind;

  bool get _controlled => widget.showSecond != null;

  /// Side the widget is showing or heading to.
  bool get _target {
    final AnimationStatus status = _progress.status;
    return status == AnimationStatus.forward ||
            status == AnimationStatus.completed
        ? _to
        : _from;
  }

  bool get _animate => widget.enabled && !_reduced;

  @override
  void initState() {
    super.initState();
    _random = math.Random(widget.seed);
    _from = _to = _displayed = widget.showSecond ?? false;
    _progress = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_handleTick)
      ..addStatusListener(_handleStatus);
    widget.controller?.addListener(_handleControllerCommand);
    widget.controller?._isShowingSecond = _target;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced) _settle();
  }

  @override
  void didUpdateWidget(PixelTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _progress.duration = widget.duration;
      if (_progress.isAnimating) {
        // Continue the running transition at the new speed.
        if (_progress.status == AnimationStatus.reverse) {
          _progress.reverse();
        } else {
          _progress.forward();
        }
      }
    }
    if (widget.seed != oldWidget.seed) {
      _random = math.Random(widget.seed);
    }
    if (widget.gridSize != oldWidget.gridSize && _plan != _PixelPlan.empty) {
      _plan = _PixelPlan.shuffled(widget.gridSize, _random);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerCommand);
      widget.controller?.addListener(_handleControllerCommand);
      widget.controller?._isShowingSecond = _target;
    }
    if (!widget.enabled && oldWidget.enabled) {
      _hovered = false;
      _settle();
    }
    if (widget.trigger != oldWidget.trigger) _hovered = false;
    if (widget.showSecond != null && widget.showSecond != _target) {
      _transitionTo(widget.showSecond!);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerCommand);
    _progress
      ..removeListener(_handleTick)
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  /// Rebuilds only when the content under the cells swaps.
  void _handleTick() {
    final bool displayed = _progress.value >= 0.5 ? _to : _from;
    if (displayed != _displayed) {
      setState(() => _displayed = displayed);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Make the reached side the new resting side so the next transition
      // starts from 0 with a fresh cell order. Nothing is covered at
      // either end, so this is invisible.
      _from = _to;
      _progress.value = 0.0;
    } else if (status == AnimationStatus.dismissed) {
      _to = _from;
    }
    widget.controller?._isShowingSecond = _target;
  }

  /// Jumps to the target side with no cells, stopping any transition.
  void _settle() {
    final bool target = _target;
    _progress.stop();
    _from = _to = target;
    _progress.value = 0.0;
    if (_displayed != target) {
      if (mounted) {
        setState(() => _displayed = target);
      } else {
        _displayed = target;
      }
    }
    widget.controller?._isShowingSecond = target;
  }

  /// Animates (or jumps) toward [second], retracing when the widget is
  /// heading the other way.
  void _transitionTo(bool second) {
    if (second == _target) return;
    if (!_animate) {
      _progress.stop();
      _from = _to = second;
      _progress.value = 0.0;
      setState(() => _displayed = second);
      widget.controller?._isShowingSecond = second;
      return;
    }
    if (_progress.isAnimating) {
      // Retrace the cells already drawn.
      if (_progress.status == AnimationStatus.forward) {
        _progress.reverse();
      } else {
        _progress.forward();
      }
    } else {
      setState(() {
        _to = second;
        _plan = _PixelPlan.shuffled(widget.gridSize, _random);
      });
      _progress.forward(from: 0.0);
    }
    widget.controller?._isShowingSecond = second;
  }

  /// Handles a request from a gesture or the controller.
  void _request(bool second) {
    if (!widget.enabled) return;
    if (_controlled) {
      if (second != widget.showSecond) widget.onChanged?.call(second);
      return;
    }
    if (second == _target) return;
    _transitionTo(second);
    widget.onChanged?.call(second);
  }

  void _handleControllerCommand() {
    final PixelTransitionController controller = widget.controller!;
    final _PixelCommand? command = controller._pending;
    controller._pending = null;
    if (command == null || !mounted) return;
    final bool current = _controlled ? widget.showSecond! : _target;
    switch (command) {
      case _PixelCommand.first:
        _request(false);
      case _PixelCommand.second:
        _request(true);
      case _PixelCommand.toggle:
        _request(!current);
    }
  }

  void _handleEnter(PointerEnterEvent event) {
    _hovered = true;
    _request(true);
  }

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _request(false);
  }

  void _handleTapDown(TapDownDetails details) {
    _tapKind = details.kind;
  }

  void _handleTap() {
    final PointerDeviceKind? kind = _tapKind;
    _tapKind = null;
    if (widget.trigger == PixelTransitionTrigger.hover &&
        (kind == PointerDeviceKind.mouse || _hovered)) {
      // A hovering pointer already drives the transition.
      return;
    }
    _request(!(_controlled ? widget.showSecond! : _target));
  }

  Widget _side(bool second, Widget child) {
    final bool visible = _displayed == second;
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: Opacity(opacity: visible ? 1.0 : 0.0, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color pixelColor =
        widget.pixelColor ?? Theme.of(context).colorScheme.primary;

    Widget result = ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _side(false, widget.firstChild),
          _side(true, widget.secondChild),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PixelPainter(
                      progress: _progress,
                      plan: _plan,
                      color: pixelColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // The gesture wrappers stay in place for every trigger so changing it
    // keeps the children's state; inactive callbacks are null.
    final bool enabled = widget.enabled;
    final bool hover =
        enabled && widget.trigger == PixelTransitionTrigger.hover;
    final bool tap = enabled && widget.trigger != PixelTransitionTrigger.manual;
    result = GestureDetector(
      behavior: tap ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      onTapDown: tap ? _handleTapDown : null,
      onTap: tap ? _handleTap : null,
      child: result,
    );
    return MouseRegion(
      opaque: false,
      onEnter: hover ? _handleEnter : null,
      onExit: hover ? _handleExit : null,
      child: result,
    );
  }
}

/// Random cell orders for one transition.
class _PixelPlan {
  const _PixelPlan(this.gridSize, this.coverOrder, this.revealOrder);

  /// Builds fresh random orders for a [gridSize] by [gridSize] grid.
  factory _PixelPlan.shuffled(int gridSize, math.Random random) {
    return _PixelPlan(
      gridSize,
      _shuffledCells(gridSize * gridSize, random),
      _shuffledCells(gridSize * gridSize, random),
    );
  }

  /// A plan with no cells, used before the first transition.
  static final _PixelPlan empty = _PixelPlan(0, Uint16List(0), Uint16List(0));

  /// Cells per side.
  final int gridSize;

  /// Cell indices in the order they appear while covering.
  final Uint16List coverOrder;

  /// Cell indices in the order they disappear while revealing.
  final Uint16List revealOrder;

  static Uint16List _shuffledCells(int count, math.Random random) {
    final Uint16List cells = Uint16List(count);
    for (int i = 0; i < count; i++) {
      cells[i] = i;
    }
    // Fisher-Yates shuffle.
    for (int i = count - 1; i > 0; i--) {
      final int j = random.nextInt(i + 1);
      final int swap = cells[i];
      cells[i] = cells[j];
      cells[j] = swap;
    }
    return cells;
  }
}

/// Paints the cells that cover the content at the given progress.
class _PixelPainter extends CustomPainter {
  _PixelPainter({
    required this.progress,
    required this.plan,
    required this.color,
  }) : super(repaint: progress);

  /// Transition progress: cells appear from 0 to 0.5 and disappear from
  /// 0.5 to 1.
  final Animation<double> progress;

  /// Cell orders of the current transition.
  final _PixelPlan plan;

  /// Cell color.
  final Color color;

  /// Number of cells drawn at [t], and the order they come from.
  static (int start, int end, bool covering) visibleRange(
    double t,
    int cellCount,
  ) {
    if (t <= 0.0 || t >= 1.0 || cellCount == 0) return (0, 0, true);
    if (t < 0.5) {
      // Covering: the first `count` cells of the cover order are drawn.
      final int count = (t * 2 * cellCount).ceil().clamp(0, cellCount);
      return (0, count, true);
    }
    // Revealing: the first `removed` cells of the reveal order are gone.
    final int removed = ((t - 0.5) * 2 * cellCount).floor().clamp(0, cellCount);
    return (removed, cellCount, false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int gridSize = plan.gridSize;
    final int cellCount = gridSize * gridSize;
    final (int start, int end, bool covering) = visibleRange(
      progress.value,
      cellCount,
    );
    if (start >= end || size.isEmpty) return;

    // Anti-aliasing off so neighbouring cells share edges without seams.
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    if (end - start == cellCount) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    final Uint16List order = covering ? plan.coverOrder : plan.revealOrder;
    final double cellWidth = size.width / gridSize;
    final double cellHeight = size.height / gridSize;
    for (int i = start; i < end; i++) {
      final int cell = order[i];
      final int column = cell % gridSize;
      final int row = cell ~/ gridSize;
      canvas.drawRect(
        Rect.fromLTRB(
          column * cellWidth,
          row * cellHeight,
          (column + 1) * cellWidth,
          (row + 1) * cellHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.plan != plan ||
        oldDelegate.color != color;
  }
}
