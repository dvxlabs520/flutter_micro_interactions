import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Builds the accessibility value announced by a [DepthCarousel], for
/// example "Item 2 of 5". [index] is zero based.
typedef DepthCarouselSemanticValueBuilder =
    String Function(int index, int count);

/// Programmatic control for a [DepthCarousel].
///
/// ```dart
/// final controller = DepthCarouselController();
/// // ...
/// DepthCarousel(controller: controller, children: cards);
/// // later:
/// controller.next();
/// controller.animateTo(3);
/// ```
///
/// The controller notifies its listeners whenever [page] changes, which
/// happens every frame while the rail moves, so it can drive effects that
/// follow the carousel (a background color, a caption). Commands sent
/// while no carousel is attached are ignored. Dispose the controller
/// yourself when it is no longer needed; the carousel never disposes it.
class DepthCarouselController extends ChangeNotifier {
  _DepthCarouselState? _state;
  double _page = 0;
  int _index = 0;

  /// Whether a [DepthCarousel] is currently attached.
  bool get hasClients => _state != null;

  /// The fractional position of the rail: 2.0 means the third card is in
  /// front, 2.5 means the rail is halfway between the third and fourth
  /// cards. With [DepthCarousel.loop] the value is wrapped into
  /// `[0, itemCount)`.
  double get page => _page;

  /// The index of the card currently in front (the card nearest to the
  /// center, so it changes halfway through a transition).
  int get index => _index;

  /// Moves the rail to the card at [index] with the carousel's spring.
  ///
  /// With [DepthCarousel.loop] the shortest way around is taken. The
  /// returned future completes when the motion ends or is interrupted.
  Future<void> animateTo(int index) {
    return _state?._animateToIndex(index) ?? Future<void>.value();
  }

  /// Moves the rail to the next card. Repeated calls during a transition
  /// queue up, so pressing twice quickly moves two cards.
  Future<void> next() => _state?._step(1) ?? Future<void>.value();

  /// Moves the rail to the previous card. Repeated calls during a
  /// transition queue up.
  Future<void> previous() => _state?._step(-1) ?? Future<void>.value();

  /// Moves the rail to the card at [index] immediately, without motion.
  void jumpTo(int index) => _state?._jumpToIndex(index);

  void _update(double page, int index) {
    if (page == _page && index == _index) return;
    _page = page;
    _index = index;
    notifyListeners();
  }
}

/// Cards arranged on a 3D rail that recedes into depth.
///
/// The active card sits in front and in the center. Its neighbors are
/// offset to the sides, pushed back along the depth axis so that
/// perspective makes them smaller, turned slightly away from the viewer
/// and progressively dimmed, so the cards read as a ring seen from the
/// front.
///
/// ```dart
/// DepthCarousel(
///   onIndexChanged: (int index) => debugPrint('Now showing $index'),
///   children: <Widget>[
///     for (final Color color in colors)
///       DecoratedBox(
///         decoration: BoxDecoration(
///           color: color,
///           borderRadius: BorderRadius.circular(24),
///         ),
///       ),
///   ],
/// )
/// ```
///
/// Cards can also be built lazily with [DepthCarousel.builder]. Only the
/// cards within [maxVisible] steps of the front (plus one fading in or
/// out) are built.
///
/// Interaction: drag or swipe along [axis] and the rail follows the finger;
/// on release it keeps the fling momentum and settles on the nearest card
/// with a spring. Tapping a side card brings it to the front (taps inside a
/// side card never reach its content; only the front card is interactive).
/// Mouse wheels and horizontal trackpad scrolling step through the cards.
/// When focused, the arrow keys along [axis] move to the previous or next
/// card. With [autoPlay] the rail advances every [interval] and pauses
/// while it is hovered, dragged or focused.
///
/// Accessibility: the carousel is a single semantics node with increase and
/// decrease actions and a value such as "Item 2 of 5" (see
/// [semanticValueBuilder]). The front card and its direct neighbors keep
/// their own semantics; cards two or more steps back are excluded from the
/// semantics tree because they are mostly hidden.
///
/// Reduced motion: transitions jump straight to their target without the
/// spring and [autoPlay] is turned off, because an automatically moving
/// rail is exactly the kind of motion the setting asks to avoid. Dragging
/// still follows the finger. With [enabled] set to `false` the rail renders
/// at its current card and ignores all input.
class DepthCarousel extends StatefulWidget {
  /// Creates a carousel from an explicit list of [children].
  const DepthCarousel({
    super.key,
    required List<Widget> this.children,
    this.itemExtent,
    this.spacing = 0.55,
    this.depth = 150,
    this.maxVisible = 2,
    this.initialIndex = 0,
    this.controller,
    this.onIndexChanged,
    this.axis = Axis.horizontal,
    this.loop = false,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 3),
    this.enabled = true,
    this.perspective = 0.0012,
    this.rotation = 12,
    this.depthFade = 0.25,
    this.fadeColor,
    this.depthBlur = 0,
    this.spring,
    this.semanticLabel,
    this.semanticValueBuilder,
  }) : itemBuilder = null,
       itemCount = children.length,
       assert(spacing >= 0, 'spacing must not be negative'),
       assert(depth >= 0, 'depth must not be negative'),
       assert(maxVisible >= 0, 'maxVisible must not be negative'),
       assert(initialIndex >= 0, 'initialIndex must not be negative'),
       assert(perspective >= 0, 'perspective must not be negative'),
       assert(depthFade >= 0 && depthFade <= 1, 'depthFade must be in [0, 1]'),
       assert(depthBlur >= 0, 'depthBlur must not be negative');

  /// Creates a carousel whose cards are built on demand by [itemBuilder].
  const DepthCarousel.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required this.itemCount,
    this.itemExtent,
    this.spacing = 0.55,
    this.depth = 150,
    this.maxVisible = 2,
    this.initialIndex = 0,
    this.controller,
    this.onIndexChanged,
    this.axis = Axis.horizontal,
    this.loop = false,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 3),
    this.enabled = true,
    this.perspective = 0.0012,
    this.rotation = 12,
    this.depthFade = 0.25,
    this.fadeColor,
    this.depthBlur = 0,
    this.spring,
    this.semanticLabel,
    this.semanticValueBuilder,
  }) : children = null,
       assert(itemCount >= 0, 'itemCount must not be negative'),
       assert(spacing >= 0, 'spacing must not be negative'),
       assert(depth >= 0, 'depth must not be negative'),
       assert(maxVisible >= 0, 'maxVisible must not be negative'),
       assert(initialIndex >= 0, 'initialIndex must not be negative'),
       assert(perspective >= 0, 'perspective must not be negative'),
       assert(depthFade >= 0 && depthFade <= 1, 'depthFade must be in [0, 1]'),
       assert(depthBlur >= 0, 'depthBlur must not be negative');

  /// The cards, when created with the default constructor.
  final List<Widget>? children;

  /// Builds the card at an index, when created with
  /// [DepthCarousel.builder]. Only visible cards are built.
  final IndexedWidgetBuilder? itemBuilder;

  /// The number of cards.
  final int itemCount;

  /// Size of every card. When null, cards are 260 by 340, scaled down to
  /// fit about 62 percent of the available width (or height for a vertical
  /// [axis]) while keeping that aspect ratio.
  final Size? itemExtent;

  /// Distance between two neighboring cards along [axis], as a fraction of
  /// the card width (or height for a vertical [axis]), before perspective.
  /// Defaults to 0.55, so neighbors tuck partly behind the front card.
  final double spacing;

  /// How far back, in logical pixels, each step away from the front pushes
  /// a card along the depth axis. Combined with [perspective] this sets how
  /// quickly cards shrink. Defaults to 150.
  final double depth;

  /// Number of cards shown on each side of the front card. One more card
  /// fades in or out at the edge while the rail moves. Defaults to 2.
  final int maxVisible;

  /// The card shown in front at first. Defaults to 0.
  final int initialIndex;

  /// Optional controller to read the position and move the rail.
  final DepthCarouselController? controller;

  /// Called with the new front card index whenever it changes, including
  /// halfway through a drag or transition (like [PageView.onPageChanged]).
  final ValueChanged<int>? onIndexChanged;

  /// Direction of the rail. Defaults to [Axis.horizontal]. A horizontal
  /// rail follows the ambient [Directionality].
  final Axis axis;

  /// Whether the rail wraps around infinitely. Defaults to `false`.
  final bool loop;

  /// Whether the rail advances by itself every [interval]. Turned off under
  /// reduced motion. Defaults to `false`.
  final bool autoPlay;

  /// Time between two automatic advances. Defaults to 3 seconds.
  final Duration interval;

  /// When `false` the rail stays on its current card and ignores drags,
  /// taps, keys and the wheel. Defaults to `true`.
  final bool enabled;

  /// Strength of the perspective projection. Larger values exaggerate
  /// depth; 0 gives a flat projection in which [depth] has no visible
  /// effect. Defaults to 0.0012.
  final double perspective;

  /// Rotation, in degrees, added per step away from the front, turning
  /// side cards away from the viewer. Defaults to 12.
  final double rotation;

  /// How much each step away from the front dims a card toward
  /// [fadeColor], in `[0, 1]`. Dimming compounds like fog, so with 0.25 the
  /// first neighbor is dimmed by 25 percent and the second by about 44
  /// percent. Defaults to 0.25; 0 disables dimming.
  final double depthFade;

  /// Color far cards fade toward. Defaults to the theme's
  /// `colorScheme.surface`, so cards recede into the page background.
  final Color? fadeColor;

  /// Gaussian blur sigma added per step away from the front, to imitate a
  /// shallow depth of field. Defaults to 0 (off) because blur is costly;
  /// small values such as 1.5 look best.
  final double depthBlur;

  /// Spring used when the rail settles, when a card is tapped and for
  /// programmatic moves. Defaults to a slightly underdamped spring
  /// (stiffness 170, damping ratio 0.8) that lands with a soft overshoot.
  final SpringDescription? spring;

  /// Optional label announced for the carousel as a whole.
  final String? semanticLabel;

  /// Builds the announced value from the front index and the card count.
  /// Defaults to "Item {index + 1} of {count}".
  final DepthCarouselSemanticValueBuilder? semanticValueBuilder;

  @override
  State<DepthCarousel> createState() => _DepthCarouselState();
}

class _DepthCarouselState extends State<DepthCarousel>
    with SingleTickerProviderStateMixin {
  /// The rail position, in cards. Unbounded so it can loop and overshoot.
  late final AnimationController _page;
  final FocusNode _focusNode = FocusNode(debugLabel: 'DepthCarousel');

  Timer? _autoPlayTimer;
  Timer? _wheelTimer;
  double _wheelAccumulator = 0;

  bool _reduced = false;
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;
  bool _silent = false;

  /// Where the rail is heading; used to queue up repeated steps.
  double _targetPage = 0;
  int _lastIndex = 0;

  /// Pixels the pointer travels to move the rail by one card.
  double _pixelsPerPage = 1;

  /// Built cards for the current build, so the per-frame rail rebuild
  /// reuses widget instances instead of calling the item builder again.
  final Map<int, Widget> _itemCache = <int, Widget>{};

  static final SpringDescription _defaultSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 170, ratio: 0.8);

  static const Tolerance _tolerance = Tolerance(
    distance: 0.0005,
    velocity: 0.005,
  );

  /// Drag coefficient of the friction used to project a fling.
  static const double _flingFriction = 0.0025;

  /// Fling speed, in cards per second, above which a release always moves
  /// at least one card.
  static const double _minFlingVelocity = 0.9;

  /// Largest spring start velocity, in cards per second.
  static const double _maxSpringVelocity = 9;

  /// Wheel travel, in logical pixels, for one card.
  static const double _wheelStep = 40;

  int get _count => widget.itemCount;

  bool get _interactive => widget.enabled && _count > 0;

  @override
  void initState() {
    super.initState();
    final int initial = _count == 0
        ? 0
        : widget.initialIndex.clamp(0, _count - 1);
    _page = AnimationController.unbounded(
      vsync: this,
      value: initial.toDouble(),
    )..addListener(_handlePageTick);
    _targetPage = initial.toDouble();
    _lastIndex = initial;
    widget.controller?._state = this;
    widget.controller?._update(_wrappedPage, initial);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MicroMotion.isReduced(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (_reduced && _page.isAnimating) _snapToTarget();
    }
    _scheduleAutoPlay();
  }

  @override
  void didUpdateWidget(DepthCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
    _silent = true;
    try {
      if (_count == 0) {
        _page.stop();
        _page.value = 0;
        _targetPage = 0;
      } else if (!widget.loop) {
        final double max = (_count - 1).toDouble();
        if (oldWidget.loop || _page.value < 0 || _page.value > max) {
          // Leaving loop mode, or the list shrank: land on a real card.
          final double page = oldWidget.loop
              ? _wrap(_page.value.round()).toDouble()
              : _page.value.clamp(0.0, max).roundToDouble();
          _page.stop();
          _page.value = page;
          _targetPage = page;
        }
      }
      if (!widget.enabled && oldWidget.enabled) _snapToTarget();
    } finally {
      _silent = false;
    }
    widget.controller?._update(_wrappedPage, _currentIndex);
    if (_currentIndex != _lastIndex) {
      // Report the change after this frame, never during build.
      _lastIndex = _currentIndex;
      final int index = _lastIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onIndexChanged?.call(index);
      });
    }
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.interval != oldWidget.interval ||
        widget.enabled != oldWidget.enabled ||
        widget.itemCount != oldWidget.itemCount) {
      _scheduleAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _wheelTimer?.cancel();
    if (widget.controller?._state == this) widget.controller!._state = null;
    _page.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Position helpers ---------------------------------------------------------

  int _wrap(int index) =>
      _count == 0 ? 0 : ((index % _count) + _count) % _count;

  int get _currentIndex {
    if (_count == 0) return 0;
    final int rounded = _page.value.round();
    return widget.loop ? _wrap(rounded) : rounded.clamp(0, _count - 1);
  }

  double get _wrappedPage {
    if (_count == 0) return 0;
    if (!widget.loop) return _page.value;
    final double n = _count.toDouble();
    return ((_page.value % n) + n) % n;
  }

  void _handlePageTick() {
    if (_silent) return;
    final int index = _currentIndex;
    widget.controller?._update(_wrappedPage, index);
    if (index != _lastIndex) {
      _lastIndex = index;
      widget.onIndexChanged?.call(index);
    }
  }

  double get _restingPage =>
      _page.isAnimating ? _targetPage : _page.value.roundToDouble();

  /// Virtual page for [index], taking the shortest way around when looping.
  double _pageForIndex(int index) {
    if (_count == 0) return 0;
    if (!widget.loop) return index.clamp(0, _count - 1).toDouble();
    final int base = _restingPage.round();
    int delta = _wrap(index) - _wrap(base);
    if (delta > _count / 2) delta -= _count;
    if (delta < -_count / 2) delta += _count;
    return (base + delta).toDouble();
  }

  // Motion ---------------------------------------------------------------------

  Future<void> _animateToPage(double target, {double velocity = 0}) {
    _targetPage = target;
    _autoPlayTimer?.cancel();
    if (_reduced || !widget.enabled) {
      _page.stop();
      _page.value = target;
      _scheduleAutoPlay();
      return Future<void>.value();
    }
    final SpringSimulation simulation = SpringSimulation(
      widget.spring ?? _defaultSpring,
      _page.value,
      target,
      velocity.clamp(-_maxSpringVelocity, _maxSpringVelocity),
      tolerance: _tolerance,
    );
    final Completer<void> done = Completer<void>();
    final TickerFuture ticker = _page.animateWith(simulation);
    ticker.then((_) {
      if (!mounted) return;
      // The spring stops within tolerance; land exactly on the card.
      _page.value = target;
      _scheduleAutoPlay();
    });
    ticker.whenCompleteOrCancel(() {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _snapToTarget() {
    _page.stop();
    if (_count == 0) return;
    double target = _targetPage;
    if (!widget.loop) target = target.clamp(0.0, (_count - 1).toDouble());
    if ((_page.value - target).abs() > 0.5) {
      target = _page.value.roundToDouble();
    }
    _targetPage = target;
    _page.value = target;
  }

  Future<void> _animateToIndex(int index) {
    if (!_interactive) return Future<void>.value();
    return _animateToPage(_pageForIndex(index), velocity: _page.velocityOrZero);
  }

  Future<void> _step(int direction) {
    if (!_interactive) return Future<void>.value();
    double target = _restingPage + direction;
    if (!widget.loop) {
      target = target.clamp(0.0, (_count - 1).toDouble());
    }
    if (target == _page.value && !_page.isAnimating) {
      return Future<void>.value();
    }
    return _animateToPage(target, velocity: _page.velocityOrZero);
  }

  void _jumpToIndex(int index) {
    if (_count == 0) return;
    _page.stop();
    final double target = _pageForIndex(index);
    _targetPage = target;
    _page.value = target;
    _scheduleAutoPlay();
  }

  /// Settles on a card after a drag, honoring the fling [velocity] in
  /// cards per second.
  void _settle(double velocity) {
    if (_count == 0) return;
    final double page = _page.value;
    // Where friction would carry the rail, then snap to a card there.
    final double projected = FrictionSimulation(
      _flingFriction,
      page,
      velocity,
    ).finalX;
    final double maxJump = (widget.maxVisible + 1).toDouble();
    int target = projected.clamp(page - maxJump, page + maxJump).round();
    if (velocity.abs() > _minFlingVelocity) {
      final int oneStep = velocity > 0 ? page.floor() + 1 : page.ceil() - 1;
      target = velocity > 0
          ? math.max(target, oneStep)
          : math.min(target, oneStep);
    }
    if (!widget.loop) target = target.clamp(0, _count - 1);
    _animateToPage(target.toDouble(), velocity: velocity);
  }

  // Auto play ------------------------------------------------------------------

  bool get _autoPlayActive =>
      widget.autoPlay &&
      _interactive &&
      _count > 1 &&
      !_reduced &&
      !_hovered &&
      !_dragging &&
      !_focused;

  void _scheduleAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (!_autoPlayActive || _page.isAnimating) return;
    _autoPlayTimer = Timer(widget.interval, _autoAdvance);
  }

  void _autoAdvance() {
    _autoPlayTimer = null;
    if (!mounted || !_autoPlayActive) return;
    if (!widget.loop && _currentIndex >= _count - 1) {
      _animateToPage(0);
    } else {
      _step(1);
    }
  }

  // Input ----------------------------------------------------------------------

  /// +1 when moving the pointer toward the axis end moves the rail back.
  double get _directionSign {
    if (widget.axis == Axis.vertical) return 1;
    return Directionality.maybeOf(context) == TextDirection.rtl ? -1 : 1;
  }

  void _handleDragDown(DragDownDetails details) {
    if (!_interactive) return;
    _page.stop();
    _autoPlayTimer?.cancel();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_interactive) return;
    _dragging = true;
    _page.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_interactive || !_dragging) return;
    final double delta = details.primaryDelta ?? 0;
    double pages = -delta / _pixelsPerPage * _directionSign;
    if (!widget.loop) {
      final double value = _page.value;
      final double max = (_count - 1).toDouble();
      final double over = value < 0
          ? -value
          : value > max
          ? value - max
          : 0;
      final bool pushingOut =
          (value <= 0 && pages < 0) || (value >= max && pages > 0);
      if (pushingOut) pages *= 0.45 / (1 + over * 4);
    }
    _page.value += pages;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_interactive) return;
    _dragging = false;
    final double velocity =
        -(details.primaryVelocity ?? 0) / _pixelsPerPage * _directionSign;
    _settle(velocity);
  }

  void _handleDragCancel() {
    if (!_interactive) return;
    _dragging = false;
    // A tap on a side card may already have started a transition.
    if (_page.isAnimating) return;
    if (_page.value != _page.value.roundToDouble()) {
      _settle(0);
    } else {
      _scheduleAutoPlay();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_interactive || event is! PointerScrollEvent) return;
    final Offset scroll = event.scrollDelta;
    double delta;
    if (widget.axis == Axis.horizontal) {
      delta = scroll.dx;
      if (delta == 0 && HardwareKeyboard.instance.isShiftPressed) {
        delta = scroll.dy;
      }
      delta *= _directionSign;
    } else {
      delta = scroll.dy;
    }
    // Leave unrelated scrolling (such as vertical page scrolling over a
    // horizontal rail) to the enclosing scrollable.
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _wheelAccumulator += delta;
      while (_wheelAccumulator.abs() >= _wheelStep) {
        final int direction = _wheelAccumulator > 0 ? 1 : -1;
        _wheelAccumulator -= direction * _wheelStep;
        // Do not run away more than a couple of cards ahead.
        if ((_restingPage - _page.value).abs() < widget.maxVisible + 1) {
          _step(direction);
        }
      }
      _wheelTimer?.cancel();
      _wheelTimer = Timer(const Duration(milliseconds: 200), () {
        _wheelAccumulator = 0;
      });
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_interactive || event is KeyUpEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    final bool rtl = _directionSign < 0;
    int direction = 0;
    if (widget.axis == Axis.horizontal) {
      if (key == LogicalKeyboardKey.arrowRight) direction = rtl ? -1 : 1;
      if (key == LogicalKeyboardKey.arrowLeft) direction = rtl ? 1 : -1;
    } else {
      if (key == LogicalKeyboardKey.arrowDown) direction = 1;
      if (key == LogicalKeyboardKey.arrowUp) direction = -1;
    }
    if (direction == 0) return KeyEventResult.ignored;
    _step(direction);
    return KeyEventResult.handled;
  }

  void _handleFocusChange(bool focused) {
    _focused = focused;
    _scheduleAutoPlay();
  }

  void _setHovered(bool hovered) {
    _hovered = hovered;
    if (hovered) {
      _autoPlayTimer?.cancel();
    } else {
      _scheduleAutoPlay();
    }
  }

  // Layout and painting --------------------------------------------------------

  Size _resolveItemSize(BoxConstraints constraints) {
    final Size? explicit = widget.itemExtent;
    if (explicit != null) return explicit;
    const double baseWidth = 260;
    const double baseHeight = 340;
    final bool horizontal = widget.axis == Axis.horizontal;
    double width = baseWidth;
    if (constraints.hasBoundedWidth) {
      width = math.min(width, constraints.maxWidth * (horizontal ? 0.62 : 0.9));
    }
    double height = width * baseHeight / baseWidth;
    if (constraints.hasBoundedHeight) {
      final double maxHeight = constraints.maxHeight * (horizontal ? 1 : 0.62);
      if (height > maxHeight) {
        height = maxHeight;
        width = height * baseWidth / baseHeight;
      }
    }
    return Size(width, height);
  }

  Widget _item(int index) {
    final List<Widget>? children = widget.children;
    if (children != null) return children[index];
    return _itemCache.putIfAbsent(
      index,
      () => widget.itemBuilder!(context, index),
    );
  }

  /// Projected offset of a card [steps] away from the front, in pixels.
  double _projectedOffset(double steps, double stepExtent) {
    final double w = 1 + widget.perspective * widget.depth * steps.abs();
    return steps * stepExtent / w;
  }

  List<Widget> _buildCards(Size itemSize, Color fadeColor) {
    final int count = _count;
    if (count == 0) return const <Widget>[];
    final double page = _page.value;
    final double reach = widget.maxVisible + 1.0;
    final int first = (page - reach).floor() + 1;
    final int last = (page + reach).ceil() - 1;
    final bool horizontal = widget.axis == Axis.horizontal;
    final double mainExtent = horizontal ? itemSize.width : itemSize.height;
    final double stepExtent = mainExtent * widget.spacing;
    final double sign = _directionSign;
    final double radiansPerStep = widget.rotation * math.pi / 180;
    final bool fade = widget.depthFade > 0;
    final bool blur = widget.depthBlur > 0;

    final List<_CardSlot> slots = <_CardSlot>[];
    for (int i = first; i <= last; i++) {
      if (!widget.loop && (i < 0 || i >= count)) continue;
      final double d = i - page;
      if (d.abs() >= reach) continue;
      slots.add(_CardSlot(i, d));
    }
    // Farthest first, so the nearest card paints on top.
    slots.sort((_CardSlot a, _CardSlot b) => b.distance.compareTo(a.distance));

    return <Widget>[
      for (final _CardSlot slot in slots)
        _buildCard(
          slot: slot,
          itemSize: itemSize,
          horizontal: horizontal,
          stepExtent: stepExtent,
          sign: sign,
          radiansPerStep: radiansPerStep,
          fade: fade,
          blur: blur,
          fadeColor: fadeColor,
        ),
    ];
  }

  Widget _buildCard({
    required _CardSlot slot,
    required Size itemSize,
    required bool horizontal,
    required double stepExtent,
    required double sign,
    required double radiansPerStep,
    required bool fade,
    required bool blur,
    required Color fadeColor,
  }) {
    final double d = slot.offset;
    final double a = d.abs();
    final double maxVisible = widget.maxVisible.toDouble();
    // The physical position is set in world space; the perspective entry
    // then shrinks and pulls far cards toward the center by itself.
    final double along = d * stepExtent * sign;
    final double z = a * widget.depth;
    final double angle =
        d.clamp(-maxVisible - 1, maxVisible + 1) * radiansPerStep;
    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..multiply(
        horizontal
            ? Matrix4.translationValues(along, 0, z)
            : Matrix4.translationValues(0, along, z),
      )
      ..multiply(
        // Turn each side card so its outer edge recedes, as on a ring.
        horizontal
            ? Matrix4.rotationY(-angle * sign)
            : Matrix4.rotationX(angle),
      );

    final double edgeOpacity = a <= maxVisible
        ? 1.0
        : (1 - (a - maxVisible)).clamp(0.0, 1.0);
    final bool front = a < 0.5;

    Widget card = RepaintBoundary(
      child: SizedBox.fromSize(size: itemSize, child: _item(_itemIndex(slot))),
    );
    if (blur) {
      final double sigma = widget.depthBlur * a;
      card = ImageFiltered(
        enabled: sigma > 0.05,
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: card,
      );
    }
    if (fade) {
      final double k = 1 - math.pow(1 - widget.depthFade, a).toDouble();
      card = ColorFiltered(colorFilter: _dimFilter(k, fadeColor), child: card);
    }
    return Transform(
      key: ValueKey<int>(slot.virtualIndex),
      alignment: Alignment.center,
      transform: transform,
      child: Opacity(
        opacity: edgeOpacity,
        child: ExcludeSemantics(
          excluding: a >= 1.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: front || !widget.enabled
                ? null
                : () => _animateToPage(slot.virtualIndex.toDouble()),
            child: IgnorePointer(ignoring: !front, child: card),
          ),
        ),
      ),
    );
  }

  int _itemIndex(_CardSlot slot) =>
      widget.loop ? _wrap(slot.virtualIndex) : slot.virtualIndex;

  /// A color matrix that mixes a card toward [color] by [k], keeping its
  /// alpha so rounded corners stay transparent.
  static ColorFilter _dimFilter(double k, Color color) {
    final double keep = 1 - k;
    return ColorFilter.matrix(<double>[
      keep, 0, 0, 0, color.r * 255 * k, //
      0, keep, 0, 0, color.g * 255 * k, //
      0, 0, keep, 0, color.b * 255 * k, //
      0, 0, 0, 1, 0, //
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _itemCache.clear();
    final Color fadeColor =
        widget.fadeColor ?? Theme.of(context).colorScheme.surface;
    final bool interactive = _interactive;
    final bool horizontal = widget.axis == Axis.horizontal;

    final Widget rail = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size itemSize = _resolveItemSize(constraints);
        final double mainExtent = horizontal ? itemSize.width : itemSize.height;
        _pixelsPerPage = math.max(
          1,
          _projectedOffset(1, mainExtent * widget.spacing),
        );
        final double spread =
            mainExtent * (1 + 2 * widget.spacing * widget.maxVisible);
        final Size size = constraints.constrain(
          horizontal
              ? Size(
                  constraints.hasBoundedWidth ? constraints.maxWidth : spread,
                  itemSize.height,
                )
              : Size(
                  itemSize.width,
                  constraints.hasBoundedHeight ? constraints.maxHeight : spread,
                ),
        );
        return SizedBox.fromSize(
          size: size,
          child: AnimatedBuilder(
            animation: _page,
            builder: (BuildContext context, Widget? _) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: _buildCards(itemSize, fadeColor),
              );
            },
          ),
        );
      },
    );

    return AnimatedBuilder(
      animation: _page,
      builder: (BuildContext context, Widget? child) {
        final bool canIncrease =
            interactive && (widget.loop || _currentIndex < _count - 1);
        final bool canDecrease =
            interactive && (widget.loop || _currentIndex > 0);
        return Semantics(
          container: true,
          label: widget.semanticLabel,
          value: _count == 0 ? null : _semanticValueFor(_currentIndex),
          increasedValue: canIncrease
              ? _semanticValueFor(_currentIndex + 1)
              : null,
          decreasedValue: canDecrease
              ? _semanticValueFor(_currentIndex - 1)
              : null,
          onIncrease: canIncrease ? () => _step(1) : null,
          onDecrease: canDecrease ? () => _step(-1) : null,
          child: child,
        );
      },
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: interactive,
        onKeyEvent: _handleKey,
        onFocusChange: _handleFocusChange,
        child: MouseRegion(
          opaque: false,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: interactive && horizontal
                  ? _handleDragDown
                  : null,
              onHorizontalDragStart: interactive && horizontal
                  ? _handleDragStart
                  : null,
              onHorizontalDragUpdate: interactive && horizontal
                  ? _handleDragUpdate
                  : null,
              onHorizontalDragEnd: interactive && horizontal
                  ? _handleDragEnd
                  : null,
              onHorizontalDragCancel: interactive && horizontal
                  ? _handleDragCancel
                  : null,
              onVerticalDragDown: interactive && !horizontal
                  ? _handleDragDown
                  : null,
              onVerticalDragStart: interactive && !horizontal
                  ? _handleDragStart
                  : null,
              onVerticalDragUpdate: interactive && !horizontal
                  ? _handleDragUpdate
                  : null,
              onVerticalDragEnd: interactive && !horizontal
                  ? _handleDragEnd
                  : null,
              onVerticalDragCancel: interactive && !horizontal
                  ? _handleDragCancel
                  : null,
              child: rail,
            ),
          ),
        ),
      ),
    );
  }

  String _semanticValueFor(int index) {
    final int wrapped = widget.loop ? _wrap(index) : index;
    final DepthCarouselSemanticValueBuilder? builder =
        widget.semanticValueBuilder;
    if (builder != null) return builder(wrapped, _count);
    return 'Item ${wrapped + 1} of $_count';
  }
}

/// A card position on the rail for one frame.
class _CardSlot {
  _CardSlot(this.virtualIndex, this.offset);

  /// Index on the (possibly looping) rail.
  final int virtualIndex;

  /// Signed distance from the front, in cards.
  final double offset;

  /// Unsigned distance from the front, in cards.
  double get distance => offset.abs();
}

extension on AnimationController {
  /// The current velocity, or 0 when idle.
  double get velocityOrZero => isAnimating ? velocity : 0;
}
