import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// The distortion a [MorphSlider] uses while it morphs from one image to
/// the next.
enum MorphEffect {
  /// The outgoing image is pushed along the slide direction and smeared by
  /// a flowing liquid noise field while it melts into the incoming image,
  /// which un-warps into place behind an organic, melting front.
  melt,

  /// Water-like rings travel out from the origin (the center, or the point
  /// where a drag started). The incoming image is revealed inside the
  /// expanding ring while both images refract through the waves.
  ripple,

  /// The outgoing image winds into a vortex around the origin while the
  /// incoming image unwinds out of it along spiral arms.
  swirl,
}

/// Programmatic control for a [MorphSlider].
///
/// ```dart
/// final MorphSliderController slides = MorphSliderController();
/// // ...
/// MorphSlider(controller: slides, images: images);
/// // later:
/// slides.next();
/// slides.animateTo(3);
/// slides.jumpTo(0);
/// ```
///
/// The controller notifies its listeners whenever [index] changes. The
/// caller owns and disposes it. Navigation calls made while no slider is
/// attached only update [index] (without animating), so the attached
/// slider starts there.
class MorphSliderController extends ChangeNotifier {
  /// Creates a controller whose slider starts at [initialIndex].
  MorphSliderController({int initialIndex = 0})
    : assert(initialIndex >= 0, 'initialIndex must not be negative'),
      _index = initialIndex;

  int _index;
  _MorphSliderState? _state;

  /// Index of the image shown (or being morphed to) by the attached
  /// slider.
  int get index => _index;

  /// Whether the attached slider is currently morphing between two images,
  /// including while the user drags.
  bool get isAnimating => _state?._isTransitioning ?? false;

  /// Morphs to the next image. At the last image this wraps to the first
  /// when `loop` is true and does nothing otherwise.
  void next() => _state?._step(1);

  /// Morphs to the previous image. At the first image this wraps to the
  /// last when `loop` is true and does nothing otherwise.
  void previous() => _state?._step(-1);

  /// Morphs to the image at [index].
  ///
  /// The transition direction follows the index order: a higher index
  /// slides forward, a lower one slides back.
  void animateTo(int index) {
    assert(index >= 0, 'index must not be negative');
    final _MorphSliderState? state = _state;
    if (state == null) {
      _setIndex(index);
    } else {
      state._animateTo(index);
    }
  }

  /// Shows the image at [index] immediately, without a transition.
  void jumpTo(int index) {
    assert(index >= 0, 'index must not be negative');
    final _MorphSliderState? state = _state;
    if (state == null) {
      _setIndex(index);
    } else {
      state._jumpTo(index);
    }
  }

  void _setIndex(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }
}

/// Builds a widget layered over the image at [index], for example a
/// caption. See [MorphSlider.overlayBuilder].
typedef MorphSliderOverlayBuilder =
    Widget Function(BuildContext context, int index);

/// An image slider that melts from one image into the next with a GPU
/// displacement transition.
///
/// ```dart
/// MorphSlider(
///   images: const <ImageProvider>[
///     AssetImage('assets/coast.jpg'),
///     AssetImage('assets/forest.jpg'),
///     AssetImage('assets/city.jpg'),
///   ],
///   effect: MorphEffect.melt,
///   autoPlay: true,
///   overlayBuilder: (BuildContext context, int index) => Align(
///     alignment: Alignment.bottomLeft,
///     child: Padding(
///       padding: const EdgeInsets.all(20),
///       child: Text('Slide ${index + 1}'),
///     ),
///   ),
/// )
/// ```
///
/// One image is shown at a time, scaled to cover the slider inside a
/// rounded rectangle. Moving to another image runs a fragment shader that
/// warps the outgoing image with a flowing displacement field while it
/// dissolves into the incoming image, which un-warps into place. Pick the
/// look with [effect] and its strength with [intensity].
///
/// Navigation:
///
/// * Swipe horizontally. The drag scrubs the transition live; on release
///   it completes (past halfway or on a fling) or springs back.
/// * The arrow buttons ([showArrows]), the left and right arrow keys while
///   the slider has focus, and optionally taps on the left or right half
///   ([tapToNavigate]).
/// * The dots indicator ([showIndicators]); each dot jumps to its image.
/// * [autoPlay] advances every [interval]. It pauses while the pointer
///   hovers the slider and while the user drags.
/// * A [MorphSliderController] for [MorphSliderController.next],
///   [MorphSliderController.previous], [MorphSliderController.animateTo]
///   and [MorphSliderController.jumpTo].
///
/// The shader ships with this package and loads on first use (see
/// [precacheShader]). Until it is ready, when it cannot load on the current
/// platform or renderer, or when [enabled] is false, transitions fall back
/// to a clean crossfade with a slight scale.
///
/// Images are resolved from their [ImageProvider]s; the current image and
/// its neighbors are preloaded. A placeholder in the theme's
/// `surfaceContainerHighest` color shows while an image loads, with an
/// icon if it fails.
///
/// Accessibility: the image area is a single semantics node labelled with
/// [semanticLabels] (or "Image n of total") that supports increase and
/// decrease actions. Arrows and dots are labelled buttons.
///
/// Reduced motion: transitions swap images instantly, drags no longer
/// scrub, and [autoPlay] is off. Navigation and [onIndexChanged] keep
/// working.
class MorphSlider extends StatefulWidget {
  /// Creates a morphing image slider over [images].
  const MorphSlider({
    super.key,
    required this.images,
    this.effect = MorphEffect.melt,
    this.intensity = 0.7,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeInOutCubic,
    this.controller,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.loop = true,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 5),
    this.showIndicators = true,
    this.showArrows = true,
    this.tapToNavigate = false,
    this.enableDrag = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.aspectRatio,
    this.overlayBuilder,
    this.semanticLabels,
    this.placeholderColor,
    this.enabled = true,
  }) : assert(
         intensity >= 0 && intensity <= 1,
         'intensity must be between 0 and 1',
       ),
       assert(initialIndex >= 0, 'initialIndex must not be negative'),
       assert(
         aspectRatio == null || aspectRatio > 0,
         'aspectRatio must be positive',
       );

  /// The images to show, in order. Must not be empty.
  final List<ImageProvider> images;

  /// The distortion used between images. Defaults to [MorphEffect.melt].
  final MorphEffect effect;

  /// Strength of the distortion, from 0 (an almost plain dissolve) to 1.
  /// Defaults to 0.7.
  final double intensity;

  /// Length of a programmatic transition (arrows, keys, dots, autoplay,
  /// controller). Defaults to 1100 milliseconds.
  final Duration duration;

  /// Easing of a programmatic transition. Drag releases use a spring
  /// instead. Defaults to [Curves.easeInOutCubic].
  final Curve curve;

  /// Optional controller for programmatic navigation. When given, its
  /// [MorphSliderController.index] is the starting image and
  /// [initialIndex] is ignored. The caller owns and disposes it.
  final MorphSliderController? controller;

  /// Index of the first image shown when no [controller] is given.
  /// Defaults to 0.
  final int initialIndex;

  /// Called with the new index each time navigation commits to another
  /// image: when a programmatic transition starts, or when a drag is
  /// released past the threshold.
  final ValueChanged<int>? onIndexChanged;

  /// Whether navigation wraps from the last image to the first and back.
  /// Defaults to `true`.
  final bool loop;

  /// Whether the slider advances on its own every [interval]. Pauses while
  /// hovered or dragged; off under reduced motion and when [enabled] is
  /// false. Without [loop], it stops at the last image. Defaults to
  /// `false`.
  final bool autoPlay;

  /// Time an image stays on screen during [autoPlay], counted from the end
  /// of the previous transition. Defaults to 5 seconds.
  final Duration interval;

  /// Whether to show the animated dots indicator at the bottom. Defaults
  /// to `true`.
  final bool showIndicators;

  /// Whether to show previous and next arrow buttons. Defaults to `true`.
  final bool showArrows;

  /// Whether a tap on the left or right half of the slider goes to the
  /// previous or next image. Taps claimed by widgets from [overlayBuilder]
  /// are not affected. Defaults to `false`.
  final bool tapToNavigate;

  /// Whether horizontal swipes scrub between images. Defaults to `true`.
  final bool enableDrag;

  /// Corner rounding of the slider. Defaults to a 20 pixel circular
  /// radius.
  final BorderRadius borderRadius;

  /// Width to height ratio of the slider. When null the slider fills the
  /// incoming constraints, and uses 16:9 when the height is unbounded.
  final double? aspectRatio;

  /// Builds a widget layered over each image, such as a caption. During a
  /// transition the outgoing overlay fades out and the incoming one fades
  /// in.
  final MorphSliderOverlayBuilder? overlayBuilder;

  /// Accessibility labels for the images, one per entry of [images].
  /// Defaults to "Image n of total".
  final List<String>? semanticLabels;

  /// Fill shown while an image loads or after it fails. Defaults to the
  /// theme's `colorScheme.surfaceContainerHighest`.
  final Color? placeholderColor;

  /// When `false` the morph shader and [autoPlay] are off and transitions
  /// use a plain crossfade. Navigation keeps working. Defaults to `true`.
  final bool enabled;

  /// Forces the crossfade fallback even when the shader is available.
  /// Only for tests.
  @visibleForTesting
  static bool debugForceFallback = false;

  static const String _packageShaderKey =
      'packages/flutter_micro_interactions/shaders/morph_slider.frag';
  static const String _localShaderKey = 'shaders/morph_slider.frag';

  static Future<ui.FragmentProgram?>? _programFuture;
  static ui.FragmentProgram? _program;

  /// Loads and caches the morph shader so the first transition does not
  /// wait for it.
  ///
  /// Completes with `true` when the shader is ready and `false` when it
  /// cannot be used on this platform or renderer, in which case sliders
  /// use the crossfade fallback. Safe to call more than once.
  static Future<bool> precacheShader() async {
    return await _loadProgram() != null;
  }

  static Future<ui.FragmentProgram?> _loadProgram() {
    // Load in the root zone so the shared future does not depend on the
    // zone of whichever widget asked first (for example a fake-async test).
    return _programFuture ??= Zone.root.run<Future<ui.FragmentProgram?>>(
      () async {
        // The package key works in apps that depend on this package; the
        // local key works when the package itself is the root (its tests).
        for (final String key in <String>[_packageShaderKey, _localShaderKey]) {
          try {
            final ui.FragmentProgram program =
                await ui.FragmentProgram.fromAsset(key);
            _program = program;
            return program;
          } catch (_) {
            // Try the next key, then fall back to the crossfade.
          }
        }
        return null;
      },
    );
  }

  @override
  State<MorphSlider> createState() => _MorphSliderState();
}

/// One resolved (or resolving) image.
class _MorphImage {
  _MorphImage(this.provider);

  final ImageProvider provider;
  ImageStream? stream;
  ImageStreamListener? listener;
  ImageInfo? info;
  bool failed = false;

  ui.Image? get image => info?.image;

  void dispose() {
    final ImageStreamListener? l = listener;
    if (l != null) stream?.removeListener(l);
    listener = null;
    stream = null;
    info?.dispose();
    info = null;
  }
}

class _MorphSliderState extends State<MorphSlider>
    with SingleTickerProviderStateMixin {
  static const Offset _center = Offset(0.5, 0.5);
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 90,
    ratio: 1,
  );

  /// Visual progress of the current transition, 0 (from) to 1 (to).
  late final AnimationController _progress;
  late final Animation<double> _overlayOut;
  late final Animation<double> _overlayIn;
  final FocusNode _focusNode = FocusNode(debugLabel: 'MorphSlider');
  final Map<int, _MorphImage> _images = <int, _MorphImage>{};

  ui.FragmentShader? _shader;
  ImageConfiguration _imageConfig = ImageConfiguration.empty;

  /// Committed index, reported to the controller and [onIndexChanged].
  int _index = 0;

  /// Indices currently painted; equal when idle.
  int _from = 0;
  int _to = 0;

  /// +1 when moving forward, -1 when moving back.
  int _direction = 1;
  Offset _origin = _center;
  double _seed = 0;
  int _transitionCount = 0;
  int _generation = 0;

  bool _reduced = false;
  bool _hovering = false;
  bool _focused = false;
  bool _dragging = false;
  double _dragDx = 0;
  Offset _dragOrigin = _center;
  Timer? _autoTimer;

  bool get _isTransitioning => _from != _to;
  int get _count => widget.images.length;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this);
    _overlayOut = ReverseAnimation(
      _progress.drive(CurveTween(curve: const Interval(0, 0.5))),
    );
    _overlayIn = _progress.drive(
      CurveTween(curve: const Interval(0.45, 1, curve: Curves.easeOut)),
    );
    final MorphSliderController? controller = widget.controller;
    final int start = controller?.index ?? widget.initialIndex;
    _index = _clampIndex(start);
    _from = _to = _index;
    if (controller != null) {
      controller._state = this;
      controller._index = _index;
    }
    _initShader();
  }

  void _initShader() {
    final ui.FragmentProgram? ready = MorphSlider._program;
    if (ready != null) {
      _shader = ready.fragmentShader();
      return;
    }
    MorphSlider._loadProgram().then((ui.FragmentProgram? program) {
      if (!mounted || program == null || _shader != null) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    final ImageConfiguration config = createLocalImageConfiguration(context);
    if (config != _imageConfig) {
      _imageConfig = config;
      _disposeImages();
    }
    if (_reduced && _isTransitioning && !_dragging) {
      _finishTransition();
    }
    _syncImages();
    _scheduleAutoPlay(restart: false);
  }

  @override
  void didUpdateWidget(MorphSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.images.isNotEmpty, 'MorphSlider.images must not be empty');
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
      widget.controller?._index = _index;
    }
    if (!listEquals(widget.images, oldWidget.images)) {
      _images.removeWhere((int i, _MorphImage entry) {
        final bool stale =
            i >= widget.images.length || widget.images[i] != entry.provider;
        if (stale) entry.dispose();
        return stale;
      });
      if (_from >= _count || _to >= _count || _index >= _count) {
        _progress.stop();
        _generation++;
        _progress.value = 0;
        _dragging = false;
        _index = _clampIndex(_index);
        _from = _to = _index;
        // Notify after the frame; callbacks must not run during build.
        final int committed = _index;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _index != committed) return;
          widget.controller?._setIndex(committed);
          widget.onIndexChanged?.call(committed);
        });
      }
    }
    _syncImages();
    _scheduleAutoPlay(
      restart:
          widget.autoPlay != oldWidget.autoPlay ||
          widget.interval != oldWidget.interval ||
          widget.enabled != oldWidget.enabled,
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    if (widget.controller?._state == this) widget.controller!._state = null;
    _disposeImages();
    _shader?.dispose();
    _progress.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------

  int _clampIndex(int i) => i.clamp(0, math.max(0, _count - 1));

  int? _neighbor(int from, int step) {
    final int target = from + step;
    if (target >= 0 && target < _count) return target;
    if (!widget.loop || _count < 2) return null;
    return target % _count;
  }

  /// Keeps the painted images and the neighbors of the current one
  /// resolved, and releases the rest.
  void _syncImages() {
    if (_count == 0) return;
    final Set<int> wanted = <int>{_from, _to, _index};
    for (final int i in <int>[_from, _index]) {
      final int? prev = _neighbor(i, -1);
      final int? next = _neighbor(i, 1);
      if (prev != null) wanted.add(prev);
      if (next != null) wanted.add(next);
    }
    _images.removeWhere((int i, _MorphImage entry) {
      final bool drop = !wanted.contains(i);
      if (drop) entry.dispose();
      return drop;
    });
    for (final int i in wanted) {
      if (!_images.containsKey(i)) _resolve(i);
    }
  }

  void _resolve(int i) {
    final _MorphImage entry = _MorphImage(widget.images[i]);
    _images[i] = entry;
    final ImageStream stream = entry.provider.resolve(_imageConfig);
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted || _images[i] != entry) {
          info.dispose();
          return;
        }
        entry.info?.dispose();
        entry.info = info;
        entry.failed = false;
        if (!synchronousCall) setState(() {});
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted || _images[i] != entry) return;
        entry.failed = true;
        setState(() {});
      },
    );
    entry.stream = stream;
    entry.listener = listener;
    stream.addListener(listener);
  }

  void _disposeImages() {
    for (final _MorphImage entry in _images.values) {
      entry.dispose();
    }
    _images.clear();
  }

  // ---------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------

  bool get _useShader =>
      widget.enabled && !MorphSlider.debugForceFallback && _shader != null;

  void _commitIndex(int value) {
    if (_index == value) return;
    _index = value;
    widget.controller?._setIndex(value);
    widget.onIndexChanged?.call(value);
  }

  /// Ends the current transition at its target without animating.
  void _finishTransition() {
    _progress.stop();
    _generation++;
    _from = _to;
    _progress.value = 0;
  }

  void _step(int step, {Offset? origin}) {
    if (!mounted || _dragging) return;
    final int? target = _neighbor(_index, step);
    if (target == null) return;
    _startTransition(target, step, origin: origin);
  }

  void _animateTo(int index) {
    if (!mounted || _dragging) return;
    final int target = _clampIndex(index);
    if (target == _index) return;
    _startTransition(target, target > _index ? 1 : -1);
  }

  void _jumpTo(int index) {
    if (!mounted) return;
    final int target = _clampIndex(index);
    _dragging = false;
    _progress.stop();
    _generation++;
    _progress.value = 0;
    _from = _to = target;
    _commitIndex(target);
    _syncImages();
    setState(() {});
    _scheduleAutoPlay();
  }

  void _startTransition(int target, int direction, {Offset? origin}) {
    if (_isTransitioning) _finishTransition();
    if (target == _from) return;
    _autoTimer?.cancel();
    _to = target;
    _direction = direction;
    _origin = origin ?? _center;
    _seed = _nextSeed();
    _commitIndex(target);
    if (_reduced) {
      _from = _to;
      _syncImages();
      setState(() {});
      _scheduleAutoPlay();
      return;
    }
    _syncImages();
    setState(() {});
    final int generation = ++_generation;
    _progress.value = 0;
    _progress.animateTo(1, duration: widget.duration, curve: widget.curve).then(
      (_) {
        if (mounted && generation == _generation) _settle();
      },
    );
  }

  double _nextSeed() {
    _transitionCount++;
    return (_transitionCount * 7.31) % 97.0;
  }

  /// Called when a transition reaches its target.
  void _settle() {
    _generation++;
    _from = _to;
    _progress.value = 0;
    _syncImages();
    setState(() {});
    _scheduleAutoPlay();
  }

  /// Called when a drag is released short of the threshold.
  void _revert() {
    _generation++;
    _to = _from;
    _progress.value = 0;
    _syncImages();
    setState(() {});
    _scheduleAutoPlay();
  }

  // ---------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------

  Offset _normalized(Offset local) {
    final Size? size = context.size;
    if (size == null || size.isEmpty) return _center;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _autoTimer?.cancel();
    _dragOrigin = _normalized(details.localPosition);
    _dragDx = 0;
    if (_isTransitioning) {
      if (!_reduced && _to == _neighbor(_from, _direction)) {
        // Catch the running transition and keep scrubbing it from where it
        // is, so grabbing mid-morph never jumps.
        _progress.stop();
        _generation++;
        final double width = math.max(1, context.size?.width ?? 1);
        _dragDx = -_direction * _progress.value * width * 0.85;
        _dragOrigin = _origin;
      } else {
        _finishTransition();
      }
    }
    _dragging = true;
    setState(() {});
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragDx += details.primaryDelta ?? details.delta.dx;
    final int step = _dragDx < 0 ? 1 : -1;
    final int? target = _dragDx == 0 ? null : _neighbor(_from, step);
    final int newTo = target ?? _from;
    if (newTo != _to) {
      _to = newTo;
      _direction = step;
      _origin = _dragOrigin;
      _seed = _nextSeed();
      _syncImages();
      setState(() {});
    }
    if (_reduced || !_isTransitioning) {
      _progress.value = 0;
      return;
    }
    final double width = context.size?.width ?? 1;
    _progress.value = (_dragDx.abs() / math.max(1, width * 0.85)).clamp(
      0.0,
      1.0,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (!_isTransitioning) {
      setState(() {});
      _scheduleAutoPlay();
      return;
    }
    final double width = math.max(1, context.size?.width ?? 1);
    final double velocity = details.primaryVelocity ?? 0;
    // Progress units per second, positive toward completing.
    final double progressVelocity = -velocity * _direction / width;
    final bool commit;
    if (_reduced) {
      commit = _dragDx.abs() > width * 0.2 || progressVelocity > 1.2;
    } else {
      commit =
          (_progress.value > 0.5 && progressVelocity > -1.2) ||
          progressVelocity > 1.2;
    }
    if (!commit) _commitIndex(_from);
    if (commit) {
      _commitIndex(_to);
      if (_reduced) {
        _settle();
        return;
      }
    } else if (_reduced) {
      _revert();
      return;
    }
    final double target = commit ? 1 : 0;
    final int generation = ++_generation;
    _progress
        .animateWith(
          SpringSimulation(
            _spring,
            _progress.value,
            target,
            progressVelocity.clamp(-8.0, 8.0),
          ),
        )
        .then((_) {
          if (!mounted || generation != _generation) return;
          commit ? _settle() : _revert();
        });
  }

  void _handleDragCancel() {
    if (!_dragging) return;
    _handleDragEnd(DragEndDetails(primaryVelocity: 0));
  }

  void _handleTapUp(TapUpDetails details) {
    final Size? size = context.size;
    if (size == null) return;
    final Offset origin = _normalized(details.localPosition);
    _step(details.localPosition.dx < size.width / 2 ? -1 : 1, origin: origin);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------
  // Autoplay
  // ---------------------------------------------------------------------

  bool get _autoPlayActive =>
      widget.autoPlay &&
      widget.enabled &&
      !_reduced &&
      !_hovering &&
      !_dragging &&
      _count > 1;

  /// Starts the autoplay countdown. With [restart] false a countdown that
  /// is already running is kept, so unrelated rebuilds do not delay it.
  void _scheduleAutoPlay({bool restart = true}) {
    final bool active =
        _autoPlayActive && !_isTransitioning && _neighbor(_index, 1) != null;
    if (!active) {
      _autoTimer?.cancel();
      _autoTimer = null;
      return;
    }
    if (!restart && _autoTimer != null) return;
    _autoTimer?.cancel();
    _autoTimer = Timer(widget.interval, _handleAutoTick);
  }

  void _handleAutoTick() {
    _autoTimer = null;
    if (!mounted || !_autoPlayActive) return;
    _step(1);
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    _scheduleAutoPlay();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  String _labelFor(int i) {
    final List<String>? labels = widget.semanticLabels;
    if (labels != null && i < labels.length) return labels[i];
    return 'Image ${i + 1} of $_count';
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.images.isNotEmpty, 'MorphSlider.images must not be empty');
    assert(
      widget.semanticLabels == null ||
          widget.semanticLabels!.length == widget.images.length,
      'semanticLabels must have one entry per image',
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color placeholder =
        widget.placeholderColor ?? scheme.surfaceContainerHighest;
    final _MorphImage? fromEntry = _images[_from];
    final _MorphImage? toEntry = _images[_to];
    final bool currentFailed =
        (_images[_index]?.failed ?? false) && !_isTransitioning;
    final MaterialLocalizations? l10n = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    final int? prev = _neighbor(_index, -1);
    final int? next = _neighbor(_index, 1);

    Widget slider = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          container: true,
          image: true,
          label: _labelFor(_index),
          value: '${_index + 1} / $_count',
          increasedValue: next == null ? null : '${next + 1} / $_count',
          decreasedValue: prev == null ? null : '${prev + 1} / $_count',
          onIncrease: next == null ? null : () => _step(1),
          onDecrease: prev == null ? null : () => _step(-1),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MorphPainter(
                progress: _progress,
                from: fromEntry?.image,
                to: _isTransitioning ? toEntry?.image : null,
                transitioning: _isTransitioning,
                shader: _useShader ? _shader : null,
                effect: widget.effect,
                intensity: widget.intensity,
                direction: _direction,
                origin: _origin,
                seed: _seed,
                placeholder: placeholder,
              ),
            ),
          ),
        ),
        if (currentFailed)
          ExcludeSemantics(
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
                size: 32,
              ),
            ),
          ),
        if (widget.overlayBuilder != null) _buildOverlays(context),
        if (widget.showArrows && _count > 1) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _MorphArrow(
              icon: Icons.chevron_left_rounded,
              label: l10n?.previousPageTooltip ?? 'Previous',
              onPressed: prev == null ? null : () => _step(-1),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _MorphArrow(
              icon: Icons.chevron_right_rounded,
              label: l10n?.nextPageTooltip ?? 'Next',
              onPressed: next == null ? null : () => _step(1),
            ),
          ),
        ],
        if (widget.showIndicators && _count > 1)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MorphIndicators(
                count: _count,
                progress: _progress,
                from: _from,
                to: _to,
                index: _index,
                labelFor: _labelFor,
                onSelect: _animateTo,
              ),
            ),
          ),
      ],
    );

    slider = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.enableDrag && _count > 1
          ? _handleDragStart
          : null,
      onHorizontalDragUpdate: widget.enableDrag && _count > 1
          ? _handleDragUpdate
          : null,
      onHorizontalDragEnd: widget.enableDrag && _count > 1
          ? _handleDragEnd
          : null,
      onHorizontalDragCancel: widget.enableDrag && _count > 1
          ? _handleDragCancel
          : null,
      onTapUp: widget.tapToNavigate && _count > 1 ? _handleTapUp : null,
      child: slider,
    );

    final bool showFocus =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    slider = ClipRRect(
      borderRadius: widget.borderRadius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: showFocus
              ? Border.all(color: scheme.primary, width: 3)
              : null,
        ),
        child: slider,
      ),
    );

    slider = MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        child: slider,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? ratio =
            widget.aspectRatio ??
            (constraints.hasBoundedHeight ? null : 16 / 9);
        if (ratio == null) return slider;
        return AspectRatio(aspectRatio: ratio, child: slider);
      },
    );
  }

  Widget _buildOverlays(BuildContext context) {
    final MorphSliderOverlayBuilder builder = widget.overlayBuilder!;
    if (!_isTransitioning) {
      return KeyedSubtree(
        key: ValueKey<int>(_from),
        child: builder(context, _from),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<int>(_from),
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: _overlayOut,
                child: builder(context, _from),
              ),
            ),
          ),
        ),
        KeyedSubtree(
          key: ValueKey<int>(_to),
          child: FadeTransition(
            opacity: _overlayIn,
            child: builder(context, _to),
          ),
        ),
      ],
    );
  }
}

/// Round translucent arrow button over the image.
class _MorphArrow extends StatelessWidget {
  const _MorphArrow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !enabled,
          child: Semantics(
            button: true,
            enabled: enabled,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: Colors.black.withValues(alpha: 0.32),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dots that track the transition progress: the active dot stretches into
/// a pill and hands its width to the next dot as the morph advances.
class _MorphIndicators extends StatelessWidget {
  const _MorphIndicators({
    required this.count,
    required this.progress,
    required this.from,
    required this.to,
    required this.index,
    required this.labelFor,
    required this.onSelect,
  });

  final int count;
  final Animation<double> progress;
  final int from;
  final int to;
  final int index;
  final String Function(int index) labelFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AnimatedBuilder(
          animation: progress,
          builder: (BuildContext context, Widget? child) {
            final double p = from == to ? 0 : progress.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  _dot(i, i == from ? 1 - p : (i == to ? p : 0)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(int i, double active) {
    final double t = Curves.easeInOut.transform(active.clamp(0.0, 1.0));
    return Semantics(
      button: true,
      selected: i == index,
      label: labelFor(i),
      onTap: () => onSelect(i),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          child: Container(
            key: ValueKey<int>(i),
            width: ui.lerpDouble(6, 22, t),
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: ui.lerpDouble(0.5, 1, t)!),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the current image, or the morph between two images.
class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.progress,
    required this.from,
    required this.to,
    required this.transitioning,
    required this.shader,
    required this.effect,
    required this.intensity,
    required this.direction,
    required this.origin,
    required this.seed,
    required this.placeholder,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final ui.Image? from;
  final ui.Image? to;
  final bool transitioning;
  final ui.FragmentShader? shader;
  final MorphEffect effect;
  final double intensity;
  final int direction;
  final Offset origin;
  final double seed;
  final Color placeholder;

  /// Whether a transition paints with the morph shader (read by tests).
  bool get usesShader => shader != null;

  /// Whether the last paint used the morph shader (read by tests).
  bool debugLastPaintUsedShader = false;

  static final Paint _imagePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;
  static final Paint _fillPaint = Paint();
  static final Paint _shaderPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    debugLastPaintUsedShader = false;
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final double p = transitioning ? progress.value.clamp(0.0, 1.0) : 0.0;
    final ui.FragmentShader? morph = shader;
    final ui.Image? a = from;
    final ui.Image? b = to;
    if (p <= 0) {
      _paintCover(canvas, rect, a, 1, 1);
      return;
    }
    if (p >= 1) {
      _paintCover(canvas, rect, b, 1, 1);
      return;
    }
    if (morph != null && a != null && b != null) {
      final double dx = direction > 0 ? -1.0 : 1.0;
      morph
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, p)
        ..setFloat(3, intensity)
        ..setFloat(4, effect.index.toDouble())
        ..setFloat(5, dx)
        ..setFloat(6, 0)
        ..setFloat(7, origin.dx)
        ..setFloat(8, origin.dy)
        ..setFloat(9, seed + p * 1.6)
        ..setFloat(10, a.width.toDouble())
        ..setFloat(11, a.height.toDouble())
        ..setFloat(12, b.width.toDouble())
        ..setFloat(13, b.height.toDouble())
        ..setImageSampler(0, a, filterQuality: FilterQuality.low)
        ..setImageSampler(1, b, filterQuality: FilterQuality.low);
      _shaderPaint.shader = morph;
      canvas.drawRect(rect, _shaderPaint);
      _shaderPaint.shader = null;
      debugLastPaintUsedShader = true;
      return;
    }
    // Fallback: crossfade with a slight scale settle.
    final double eased = Curves.easeInOut.transform(p);
    _paintCover(canvas, rect, a, 1 + 0.04 * eased, 1);
    _paintCover(canvas, rect, b, 1.04 - 0.04 * eased, eased);
  }

  void _paintCover(
    Canvas canvas,
    Rect rect,
    ui.Image? image,
    double scale,
    double opacity,
  ) {
    if (opacity <= 0) return;
    if (image == null) {
      _fillPaint.color = placeholder.withValues(alpha: placeholder.a * opacity);
      canvas.drawRect(rect, _fillPaint);
      return;
    }
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final FittedSizes fitted = applyBoxFit(BoxFit.cover, imageSize, rect.size);
    final Rect src = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );
    final Rect dst = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );
    _imagePaint.color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.drawImageRect(image, src, dst, _imagePaint);
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.transitioning != transitioning ||
        oldDelegate.shader != shader ||
        oldDelegate.effect != effect ||
        oldDelegate.intensity != intensity ||
        oldDelegate.direction != direction ||
        oldDelegate.origin != origin ||
        oldDelegate.seed != seed ||
        oldDelegate.placeholder != placeholder;
  }
}
