import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Programmatic control for a [HalftoneReveal].
///
/// ```dart
/// final controller = HalftoneRevealController();
/// // ...
/// HalftoneReveal(
///   image: const AssetImage('assets/portrait.jpg'),
///   controller: controller,
/// );
/// // later:
/// controller.reveal(); // dots swell outward until the photo shows
/// controller.hide();   // the photo dissolves back into dots
/// ```
///
/// [isRevealed] reflects the requested full reveal state. It is also
/// updated when the widget's `revealed` parameter changes. The caller owns
/// the controller and disposes it.
class HalftoneRevealController extends ChangeNotifier {
  bool _revealed = false;

  /// Whether the attached [HalftoneReveal] shows (or is animating towards)
  /// the full photo.
  bool get isRevealed => _revealed;

  /// Reveals the full photo with an animation that grows from the center.
  void reveal() {
    if (_revealed) return;
    _revealed = true;
    notifyListeners();
  }

  /// Returns to the halftone rendering.
  void hide() {
    if (!_revealed) return;
    _revealed = false;
    notifyListeners();
  }

  /// Reveals the photo when hidden, hides it when revealed.
  void toggle() {
    _revealed = !_revealed;
    notifyListeners();
  }
}

/// An image rendered as a halftone dot print, whose dots swell into the
/// real photo under the pointer.
///
/// ```dart
/// SizedBox(
///   width: 360,
///   height: 240,
///   child: HalftoneReveal(
///     image: const AssetImage('assets/landscape.jpg'),
///     semanticLabel: 'Mountain lake at sunset',
///   ),
/// )
/// ```
///
/// The image is split into a grid of [cellSize] cells. Each cell shows one
/// dot whose radius follows the tone of the image underneath it, drawn in
/// [dotColor] on [backgroundColor], or in the image's own colors when
/// [colored] is true. Dot size follows the contrast against the
/// background: when dots are darker than the background (the usual ink on
/// paper look), darker regions get bigger dots; when dots are lighter
/// (for example in a dark theme), brighter regions get bigger dots. Set
/// [invert] to flip this.
///
/// Hovering with a mouse, or pressing and dragging with a finger, opens a
/// soft circular window of [revealRadius] around the pointer. Inside it the
/// real photo shows; around it a ring of dots (its width set by
/// [softness]) swells and merges into the photo. The window follows the
/// pointer with a little smoothing and heals back into dots over
/// [duration] when the pointer leaves. Set [revealed] (or use a
/// [HalftoneRevealController]) to reveal the whole photo with dots that
/// swell outward from the center.
///
/// Sizing works like [Image]: with tight constraints the widget fills them,
/// otherwise it keeps the image's aspect ratio within the constraints.
/// Nothing but [backgroundColor] is painted while the image loads or when
/// it fails to load. Animated images show their first frame.
///
/// The tone of each cell is sampled once per image, size and [cellSize]
/// (asynchronously, at grid resolution), so painting a frame only draws a
/// cached dot layer plus the dots near the pointer. Tones get a gentle
/// automatic levels pass, so dim or hazy photos still print with clear
/// contrast.
///
/// Accessibility: the widget is exposed as an image with [semanticLabel].
///
/// Reduced motion: the pointer window opens and closes instantly and
/// tracks the pointer without smoothing, because it is direct
/// manipulation; [revealed] changes jump to their final state. When
/// [enabled] is false the widget is a static halftone that ignores the
/// pointer, and [revealed] still applies without animation.
class HalftoneReveal extends StatefulWidget {
  /// Creates a halftone image that reveals the photo under the pointer.
  const HalftoneReveal({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cellSize = 8.0,
    this.dotScale = 1.0,
    this.revealRadius = 120.0,
    this.softness = 0.5,
    this.dotColor,
    this.backgroundColor,
    this.colored = false,
    this.invert = false,
    this.revealed = false,
    this.controller,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.borderRadius,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(cellSize >= 2, 'cellSize must be at least 2 logical pixels'),
       assert(dotScale > 0, 'dotScale must be positive'),
       assert(revealRadius >= 0, 'revealRadius must not be negative'),
       assert(
         softness >= 0 && softness <= 1,
         'softness must be between 0 and 1',
       );

  /// The image to render as halftone.
  final ImageProvider image;

  /// How the image is inscribed into the widget. Defaults to
  /// [BoxFit.cover].
  final BoxFit fit;

  /// How the image is aligned within the widget. Defaults to
  /// [Alignment.center].
  final Alignment alignment;

  /// Side of one halftone cell in logical pixels. Each cell holds one dot.
  /// Defaults to 8.
  final double cellSize;

  /// Multiplier for every dot radius. At 1 (the default) the fullest dots
  /// overlap their neighbours slightly, so the darkest areas read as solid.
  final double dotScale;

  /// Radius of the photo window around the pointer, in logical pixels.
  /// Defaults to 120.
  final double revealRadius;

  /// Width of the transition ring, where dots swell into the photo, as a
  /// fraction of [revealRadius]. 0 gives a hard edge, 1 a fully soft
  /// window. Defaults to 0.5.
  final double softness;

  /// Color of the dots. Defaults to the theme's `colorScheme.onSurface`.
  /// Ignored when [colored] is true.
  final Color? dotColor;

  /// Color behind the dots. Defaults to the theme's
  /// `colorScheme.surface`.
  final Color? backgroundColor;

  /// When true each dot takes the average color of the image under its
  /// cell instead of [dotColor]. Defaults to false.
  final bool colored;

  /// Flips which tones get the biggest dots. Defaults to false.
  final bool invert;

  /// Whether the whole photo is shown. Changing it animates the dots
  /// swelling outward from the center (or back). Defaults to false.
  final bool revealed;

  /// Optional controller to reveal and hide the full photo. The caller
  /// owns and disposes it.
  final HalftoneRevealController? controller;

  /// Duration of the full reveal and of the healing of the pointer window
  /// after the pointer leaves. The window opens in 60 percent of it.
  /// Defaults to 500 milliseconds.
  final Duration duration;

  /// Easing of the reveal and heal animations. Healing uses the flipped
  /// curve so both directions start fast and settle softly. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// Optional corner rounding that clips the widget.
  final BorderRadius? borderRadius;

  /// When false the widget is a static halftone that ignores the pointer.
  /// Defaults to true.
  final bool enabled;

  /// Description of the image for assistive technology.
  final String? semanticLabel;

  @override
  State<HalftoneReveal> createState() => _HalftoneRevealState();
}

/// Radius, as a fraction of the cell side, at which a dot covers its whole
/// cell (slightly more than half the cell diagonal).
const double _kMergeFactor = 0.75;

/// Pointer smoothing speed, in 1/seconds. Higher follows more tightly.
const double _kFollowSpeed = 16.0;

class _HalftoneRevealState extends State<HalftoneReveal>
    with TickerProviderStateMixin {
  late final AnimationController _hover;
  late CurvedAnimation _hoverCurve;
  late final AnimationController _full;
  late CurvedAnimation _fullCurve;
  late final Ticker _follow;
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);
  Offset? _pointerTarget;
  Duration _lastTick = Duration.zero;

  bool _reduced = false;
  bool _revealTarget = false;
  bool _mouseInside = false;
  final Set<int> _touches = <int>{};

  ImageStream? _stream;
  ImageInfo? _imageInfo;
  late final ImageStreamListener _imageListener = ImageStreamListener(
    _handleImage,
    onError: _handleImageError,
  );

  _GridKey? _sampleKey;
  _GridKey? _pendingKey;
  _HalftoneGrid? _grid;
  _HalftoneScene? _scene;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(vsync: this, duration: widget.duration);
    _hoverCurve = _curved(_hover);
    _full = AnimationController(vsync: this, duration: widget.duration);
    _fullCurve = _curved(_full);
    _follow = createTicker(_handleFollowTick);
    _revealTarget = widget.revealed || (widget.controller?.isRevealed ?? false);
    _full.value = _revealTarget ? 1.0 : 0.0;
    widget.controller?._revealed = _revealTarget;
    widget.controller?.addListener(_handleControllerChanged);
  }

  CurvedAnimation _curved(AnimationController parent) => CurvedAnimation(
    parent: parent,
    curve: widget.curve,
    reverseCurve: widget.curve.flipped,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced || !widget.enabled) _settleInstantly();
    _resolveImage();
  }

  @override
  void didUpdateWidget(HalftoneReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _hover.duration = widget.duration;
      _full.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _hoverCurve.dispose();
      _fullCurve.dispose();
      _hoverCurve = _curved(_hover);
      _fullCurve = _curved(_full);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      widget.controller?._revealed = _revealTarget;
    }
    if (widget.revealed != oldWidget.revealed) {
      _setRevealTarget(widget.revealed);
    }
    if (widget.image != oldWidget.image) {
      _resolveImage();
    }
    if (!widget.enabled && oldWidget.enabled) {
      _mouseInside = false;
      _touches.clear();
    }
    if (!widget.enabled) _settleInstantly();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _stream?.removeListener(_imageListener);
    _imageInfo?.dispose();
    _imageInfo = null;
    _disposeScene();
    _follow.dispose();
    _hoverCurve.dispose();
    _fullCurve.dispose();
    _hover.dispose();
    _full.dispose();
    _pointer.dispose();
    super.dispose();
  }

  // Image loading -----------------------------------------------------------

  void _resolveImage() {
    final ImageStream stream = widget.image.resolve(
      createLocalImageConfiguration(context),
    );
    if (_stream?.key != null && _stream?.key == stream.key) return;
    _stream?.removeListener(_imageListener);
    _stream = stream;
    if (_imageInfo != null) {
      _imageInfo!.dispose();
      _imageInfo = null;
      _grid = null;
      _sampleKey = null;
      _disposeScene();
    }
    stream.addListener(_imageListener);
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    if (!mounted || _imageInfo != null) {
      // Only the first frame is used; later frames of animated images and
      // late deliveries after dispose are released right away.
      info.dispose();
      return;
    }
    void apply() => _imageInfo = info;
    if (synchronousCall) {
      apply();
    } else {
      setState(apply);
    }
  }

  void _handleImageError(Object error, StackTrace? stackTrace) {
    // The background stays visible; nothing else to paint.
  }

  // Tone sampling -----------------------------------------------------------

  void _ensureGrid(Size size) {
    final ImageInfo? info = _imageInfo;
    if (info == null || size.isEmpty) return;
    final _GridKey key = _GridKey(
      info.image,
      size,
      widget.cellSize,
      widget.fit,
      widget.alignment,
    );
    if (key == _sampleKey || key == _pendingKey) return;
    _pendingKey = key;
    unawaited(_sample(key));
  }

  Future<void> _sample(_GridKey key) async {
    _HalftoneGrid? grid;
    try {
      grid = await _HalftoneGrid.sample(key);
    } catch (_) {
      grid = null;
    }
    if (!mounted || _pendingKey != key) return;
    _pendingKey = null;
    if (!identical(_imageInfo?.image, key.image)) return;
    if (grid == null) {
      // Remember the failed key so builds do not retry it endlessly.
      _sampleKey = key;
      return;
    }
    setState(() {
      _grid = grid;
      _sampleKey = key;
      _disposeScene();
    });
  }

  void _disposeScene() {
    _scene?.dispose();
    _scene = null;
  }

  _HalftoneScene? _ensureScene(Color dot, Color background) {
    final _HalftoneGrid? grid = _grid;
    final ImageInfo? info = _imageInfo;
    if (grid == null || info == null) return null;
    final _HalftoneScene? current = _scene;
    if (current != null &&
        identical(current.grid, grid) &&
        current.dotColor == dot &&
        current.backgroundColor == background &&
        current.colored == widget.colored &&
        current.invert == widget.invert &&
        current.dotScale == widget.dotScale) {
      return current;
    }
    _scene?.dispose();
    return _scene = _HalftoneScene.build(
      grid: grid,
      image: info.image,
      dotColor: dot,
      backgroundColor: background,
      colored: widget.colored,
      invert: widget.invert,
      dotScale: widget.dotScale,
    );
  }

  // Reveal state ------------------------------------------------------------

  void _handleControllerChanged() {
    if (!mounted) return;
    _setRevealTarget(widget.controller!.isRevealed);
  }

  void _setRevealTarget(bool value) {
    _revealTarget = value;
    widget.controller?._revealed = value;
    if (_reduced || !widget.enabled) {
      _full.value = value ? 1.0 : 0.0;
    } else if (value) {
      _full.forward();
    } else {
      _full.reverse();
    }
  }

  void _settleInstantly() {
    final double full = _revealTarget ? 1.0 : 0.0;
    if (_full.isAnimating || _full.value != full) _full.value = full;
    final double hover = widget.enabled && _pointerActive ? 1.0 : 0.0;
    if (_hover.isAnimating || _hover.value != hover) _hover.value = hover;
    _follow.stop();
    if (_pointerTarget != null) _pointer.value = _pointerTarget;
  }

  // Pointer -----------------------------------------------------------------

  bool get _pointerActive => _mouseInside || _touches.isNotEmpty;

  void _moveTo(Offset position) {
    _pointerTarget = position;
    final Offset? current = _pointer.value;
    if (_reduced || current == null || _hover.value == 0.0) {
      // Snap when there is nothing visible to glide from.
      _follow.stop();
      _pointer.value = position;
      return;
    }
    if (!_follow.isActive) {
      _lastTick = Duration.zero;
      _follow.start();
    }
  }

  void _handleFollowTick(Duration elapsed) {
    final Offset? target = _pointerTarget;
    final Offset? current = _pointer.value;
    if (target == null || current == null) {
      _follow.stop();
      return;
    }
    final double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final double t = 1.0 - math.exp(-_kFollowSpeed * dt.clamp(0.0, 0.1));
    final Offset next = Offset.lerp(current, target, t)!;
    if ((next - target).distanceSquared < 0.04) {
      _pointer.value = target;
      _follow.stop();
    } else {
      _pointer.value = next;
    }
  }

  void _updateActive() {
    final bool active = _pointerActive;
    if (_reduced) {
      _hover.value = active ? 1.0 : 0.0;
    } else if (active) {
      _hover.animateTo(
        1.0,
        duration: widget.duration * 0.6,
        curve: Curves.linear,
      );
    } else {
      _hover.animateBack(0.0, duration: widget.duration);
    }
  }

  void _handleEnter(PointerEnterEvent event) {
    _moveTo(event.localPosition);
    _mouseInside = true;
    _updateActive();
  }

  void _handleHover(PointerHoverEvent event) {
    _moveTo(event.localPosition);
    if (!_mouseInside) {
      _mouseInside = true;
      _updateActive();
    }
  }

  void _handleExit(PointerExitEvent event) {
    _mouseInside = false;
    _updateActive();
  }

  void _handleDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _moveTo(event.localPosition);
    _touches.add(event.pointer);
    _updateActive();
  }

  void _handleMove(PointerMoveEvent event) {
    if (_touches.contains(event.pointer)) _moveTo(event.localPosition);
  }

  void _handleUp(PointerEvent event) {
    if (_touches.remove(event.pointer)) _updateActive();
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color dot = widget.dotColor ?? scheme.onSurface;
    final Color background = widget.backgroundColor ?? scheme.surface;
    final ui.Image? image = _imageInfo?.image;

    Widget result = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size natural = image == null
            ? Size.zero
            : Size(
                image.width / (_imageInfo!.scale),
                image.height / (_imageInfo!.scale),
              );
        final Size size = constraints
            .constrainSizeAndAttemptToPreserveAspectRatio(natural);
        _ensureGrid(size);
        return SizedBox.fromSize(
          size: size,
          child: CustomPaint(
            painter: _HalftonePainter(
              scene: _ensureScene(dot, background),
              pointer: _pointer,
              hover: _hoverCurve,
              full: _fullCurve,
              revealRadius: widget.revealRadius,
              softness: widget.softness,
              dotColor: dot,
              backgroundColor: background,
              colored: widget.colored,
            ),
          ),
        );
      },
    );
    result = RepaintBoundary(child: result);
    if (widget.borderRadius != null) {
      result = ClipRRect(borderRadius: widget.borderRadius!, child: result);
    }

    final bool on = widget.enabled;
    result = MouseRegion(
      opaque: false,
      onEnter: on ? _handleEnter : null,
      onHover: on ? _handleHover : null,
      onExit: on ? _handleExit : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: on ? _handleDown : null,
        onPointerMove: on ? _handleMove : null,
        onPointerUp: on ? _handleUp : null,
        onPointerCancel: on ? _handleUp : null,
        child: result,
      ),
    );
    return Semantics(
      container: widget.semanticLabel != null,
      image: true,
      label: widget.semanticLabel ?? '',
      child: result,
    );
  }
}

/// Identifies one tone sampling: same image, size, cell and fit.
@immutable
class _GridKey {
  const _GridKey(this.image, this.size, this.cell, this.fit, this.alignment);

  final ui.Image image;
  final Size size;
  final double cell;
  final BoxFit fit;
  final Alignment alignment;

  @override
  bool operator ==(Object other) =>
      other is _GridKey &&
      identical(other.image, image) &&
      other.size == size &&
      other.cell == cell &&
      other.fit == fit &&
      other.alignment == alignment;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(image), size, cell, fit, alignment);
}

/// Source and destination rectangles of the fitted image.
({Rect src, Rect dst}) _fitImage(ui.Image image, _GridKey key) {
  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final FittedSizes fitted = applyBoxFit(key.fit, imageSize, key.size);
  return (
    src: key.alignment.inscribe(fitted.source, Offset.zero & imageSize),
    dst: key.alignment.inscribe(fitted.destination, Offset.zero & key.size),
  );
}

/// Per-cell luminance, coverage and color sampled from the fitted image.
class _HalftoneGrid {
  _HalftoneGrid({
    required this.key,
    required this.cols,
    required this.rows,
    required this.origin,
    required this.src,
    required this.dst,
    required this.luminance,
    required this.coverage,
    required this.colors,
  });

  final _GridKey key;

  /// Number of cells across.
  final int cols;

  /// Number of cells down.
  final int rows;

  /// Top-left corner of the grid; the grid is centered on the widget.
  final Offset origin;

  /// Source rectangle in the image.
  final Rect src;

  /// Destination rectangle in the widget.
  final Rect dst;

  /// Relative luminance per cell, 0 (black) to 1 (white).
  final Float32List luminance;

  /// How much of each cell the image covers, 0 to 1.
  final Float32List coverage;

  /// Average opaque ARGB color per cell.
  final Uint32List colors;

  double get cell => key.cell;

  /// Draws the fitted image at one pixel per cell and reads the pixels.
  static Future<_HalftoneGrid?> sample(_GridKey key) async {
    final ui.Image image = key.image;
    final double cell = key.cell;
    final int cols = math.max(1, (key.size.width / cell).ceil());
    final int rows = math.max(1, (key.size.height / cell).ceil());
    final Offset origin = Offset(
      (key.size.width - cols * cell) / 2,
      (key.size.height - rows * cell) / 2,
    );
    final ({Rect src, Rect dst}) fit = _fitImage(image, key);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..scale(1 / cell)
      ..translate(-origin.dx, -origin.dy);
    canvas.drawImageRect(
      image,
      fit.src,
      fit.dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image small;
    try {
      small = await picture.toImage(cols, rows);
    } finally {
      picture.dispose();
    }
    final ByteData? data;
    try {
      data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      small.dispose();
    }
    if (data == null) return null;

    final int count = cols * rows;
    final Float32List luminance = Float32List(count);
    final Float32List coverage = Float32List(count);
    final Uint32List colors = Uint32List(count);
    for (int i = 0; i < count; i++) {
      final int a = data.getUint8(i * 4 + 3);
      if (a == 0) continue;
      // Pixels are premultiplied; recover straight color.
      final double inv = 255.0 / a;
      final int r = (data.getUint8(i * 4) * inv).round().clamp(0, 255);
      final int g = (data.getUint8(i * 4 + 1) * inv).round().clamp(0, 255);
      final int b = (data.getUint8(i * 4 + 2) * inv).round().clamp(0, 255);
      luminance[i] = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      coverage[i] = a / 255.0;
      colors[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
    }
    return _HalftoneGrid(
      key: key,
      cols: cols,
      rows: rows,
      origin: origin,
      src: fit.src,
      dst: fit.dst,
      luminance: luminance,
      coverage: coverage,
      colors: colors,
    );
  }
}

/// Everything the painter needs for one grid and one set of colors: base
/// dot radii, a recorded picture of the resting dots and the photo shader.
class _HalftoneScene {
  _HalftoneScene._({
    required this.grid,
    required this.image,
    required this.dotColor,
    required this.backgroundColor,
    required this.colored,
    required this.invert,
    required this.dotScale,
    required this.radii,
    required this.dots,
    required this.photoShader,
  });

  factory _HalftoneScene.build({
    required _HalftoneGrid grid,
    required ui.Image image,
    required Color dotColor,
    required Color backgroundColor,
    required bool colored,
    required bool invert,
    required double dotScale,
  }) {
    // Dots grow with the tone that contrasts with the background.
    final double bgLum = backgroundColor.computeLuminance();
    final bool lightDots = colored
        ? bgLum < 0.5
        : dotColor.computeLuminance() > bgLum;
    final bool byBrightness = lightDots != invert;

    final double cell = grid.cell;
    final double maxRadius = cell * 0.56 * dotScale;
    final int count = grid.cols * grid.rows;
    final ({double low, double range}) levels = _levels(grid);
    final Float32List radii = Float32List(count);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()
      ..color = dotColor
      ..isAntiAlias = true;
    for (int j = 0; j < grid.rows; j++) {
      final double cy = grid.origin.dy + (j + 0.5) * cell;
      for (int i = 0; i < grid.cols; i++) {
        final int index = j * grid.cols + i;
        final double lum = ((grid.luminance[index] - levels.low) / levels.range)
            .clamp(0.0, 1.0);
        final double tone =
            (byBrightness ? lum : 1.0 - lum) * grid.coverage[index];
        // Radius follows the tone linearly, which keeps mid tones open and
        // gives the print a crisp, contrasty look.
        final double r = maxRadius * tone.clamp(0.0, 1.0);
        radii[index] = r;
        if (r < 0.2) continue;
        if (colored) paint.color = Color(grid.colors[index]);
        canvas.drawCircle(
          Offset(grid.origin.dx + (i + 0.5) * cell, cy),
          r,
          paint,
        );
      }
    }
    final Rect src = grid.src;
    final Rect dst = grid.dst;
    final double sx = dst.width / src.width;
    final double sy = dst.height / src.height;
    final Matrix4 matrix = Matrix4.identity()
      ..translateByDouble(
        dst.left - src.left * sx,
        dst.top - src.top * sy,
        0,
        1,
      )
      ..scaleByDouble(sx, sy, 1, 1);
    return _HalftoneScene._(
      grid: grid,
      image: image,
      dotColor: dotColor,
      backgroundColor: backgroundColor,
      colored: colored,
      invert: invert,
      dotScale: dotScale,
      radii: radii,
      dots: recorder.endRecording(),
      photoShader: ImageShader(
        image,
        TileMode.decal,
        TileMode.decal,
        matrix.storage,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  /// Gentle auto levels: stretches the 2nd to 98th luminance percentile
  /// of the covered cells towards the full range (at most 2x), so dim or
  /// hazy photos still print with clear contrast.
  static ({double low, double range}) _levels(_HalftoneGrid grid) {
    final List<double> values = <double>[
      for (int i = 0; i < grid.luminance.length; i++)
        if (grid.coverage[i] > 0.5) grid.luminance[i],
    ];
    if (values.length < 4) return (low: 0.0, range: 1.0);
    values.sort();
    final double low = values[(values.length * 0.02).floor()];
    final double high = values[(values.length * 0.98).floor()];
    final double range = math.max(high - low, 0.5);
    // Center the window on the measured tones when it had to be widened.
    final double mid = (low + high) / 2;
    final double start = (mid - range / 2).clamp(0.0, 1.0 - range);
    return (low: start, range: range);
  }

  final _HalftoneGrid grid;
  final ui.Image image;
  final Color dotColor;
  final Color backgroundColor;
  final bool colored;
  final bool invert;
  final double dotScale;

  /// Resting dot radius per cell, row by row.
  final Float32List radii;

  /// Recorded resting dots.
  final ui.Picture dots;

  /// Shader painting the fitted photo, used for swelling dots.
  final ImageShader photoShader;

  /// Resting dot radius of the cell at column [col] and row [row].
  double dotRadius(int col, int row) => radii[row * grid.cols + col];

  void dispose() {
    dots.dispose();
    photoShader.dispose();
  }
}

/// One circular reveal: the photo is fully shown inside [inner], dots
/// swell across the ring up to [outer], and [strength] scales the whole
/// effect while the window is very small.
class _Window {
  _Window(this.center, this.inner, this.outer, this.strength)
    : _outer2 = outer * outer,
      // Merged dots lying fully under the opaque photo can be skipped.
      _hidden = strength >= 1 ? inner * 0.999 : -1;

  final Offset center;
  final double inner;
  final double outer;
  final double strength;
  final double _outer2;
  final double _hidden;

  /// Ring position of a cell centered at ([x], [y]): 0 outside, up to 1
  /// at the inner edge, scaled by [strength]. Returns -1 when the cell is
  /// fully covered by the opaque photo and needs no dot.
  double amountAt(double x, double y, double merge) {
    final double dx = x - center.dx;
    final double dy = y - center.dy;
    final double d2 = dx * dx + dy * dy;
    if (d2 >= _outer2) return 0;
    final double d = math.sqrt(d2);
    if (d < _hidden - merge) return -1;
    if (d <= inner) return strength;
    return (outer - d) / (outer - inner) * strength;
  }
}

/// Paints the background, the resting dots, the swelling ring dots and the
/// masked photo for the pointer window and the full reveal.
class _HalftonePainter extends CustomPainter {
  _HalftonePainter({
    required this.scene,
    required this.pointer,
    required this.hover,
    required this.full,
    required this.revealRadius,
    required this.softness,
    required this.dotColor,
    required this.backgroundColor,
    required this.colored,
  }) : super(repaint: Listenable.merge(<Listenable>[pointer, hover, full]));

  /// Sampled grid and caches, or null while loading.
  final _HalftoneScene? scene;

  /// Smoothed pointer position in local coordinates.
  final ValueListenable<Offset?> pointer;

  /// Openness of the pointer window, 0 to 1.
  final Animation<double> hover;

  /// Progress of the full reveal, 0 to 1.
  final Animation<double> full;

  final double revealRadius;
  final double softness;
  final Color dotColor;
  final Color backgroundColor;
  final bool colored;

  final Paint _fill = Paint();
  final Paint _ink = Paint();
  final Paint _photo = Paint()..filterQuality = FilterQuality.medium;
  final Paint _mask = Paint()..blendMode = BlendMode.dstIn;

  static const int _maskSteps = 7;
  final List<double> _maskStops = List<double>.filled(_maskSteps + 1, 0);
  final List<Color> _maskColors = List<Color>.filled(
    _maskSteps + 1,
    const Color(0xFF000000),
  );

  /// Current pointer window center, or null when closed.
  Offset? get revealCenter => hover.value > 0 ? pointer.value : null;

  /// Current outer radius of the pointer window.
  double get revealExtent => revealRadius * hover.value;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.clipRect(bounds);
    canvas.drawRect(bounds, _fill..color = backgroundColor);
    final _HalftoneScene? scene = this.scene;
    if (scene == null) return;
    final _HalftoneGrid grid = scene.grid;

    final double f = full.value;
    if (f >= 1.0) {
      canvas.drawImageRect(scene.image, grid.src, grid.dst, _photo);
      return;
    }
    canvas.drawPicture(scene.dots);

    final double cell = grid.cell;
    _Window? pointerWindow;
    final Offset? p = pointer.value;
    final double h = hover.value;
    if (p != null && h > 0 && revealRadius > 0) {
      final double outer = revealRadius * h;
      // Keep the ring at least a few cells wide so a small window still
      // dissolves through dots instead of showing a hard blob.
      final double ring = softness == 0
          ? 0.0
          : math.min(outer, math.max(softness * outer, cell * 2.5));
      pointerWindow = _Window(p, outer - ring, outer, _fadeIn(h / 0.4));
    }
    _Window? fullWindow;
    if (f > 0) {
      // Grows from the center until the photo covers every corner.
      final Offset c = size.center(Offset.zero);
      final double ring = math.max(
        softness * math.max(revealRadius, cell * 4),
        cell * 2,
      );
      final double outer = (_cornerReach(c, size) + ring) * f;
      fullWindow = _Window(
        c,
        math.max(0, outer - ring),
        outer,
        _fadeIn(f / 0.15),
      );
    }
    if (pointerWindow == null && fullWindow == null) return;

    _paintRingDots(canvas, scene, pointerWindow, fullWindow);
    if (pointerWindow != null) {
      _paintPhoto(canvas, scene, bounds, pointerWindow);
    }
    if (fullWindow != null) _paintPhoto(canvas, scene, bounds, fullWindow);
  }

  /// Smoothstep of [t] clamped to 0..1. Small windows (opening or closing)
  /// fade instead of lingering as a tiny solid patch of photo.
  static double _fadeIn(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static double _cornerReach(Offset c, Size size) {
    final double dx = math.max(c.dx, size.width - c.dx);
    final double dy = math.max(c.dy, size.height - c.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Where across the ring (0 at the outer edge, 1 at the inner edge) the
  /// photo starts and finishes fading in over the swelling dots.
  static const double _photoStart = 0.4;
  static const double _photoEnd = 0.9;

  void _paintRingDots(
    Canvas canvas,
    _HalftoneScene scene,
    _Window? a,
    _Window? b,
  ) {
    final _HalftoneGrid grid = scene.grid;
    final double cell = grid.cell;
    final double merge = cell * _kMergeFactor;

    Rect? area;
    for (final _Window? w in <_Window?>[a, b]) {
      if (w == null) continue;
      final Rect r = Rect.fromCircle(center: w.center, radius: w.outer + cell);
      area = area == null ? r : area.expandToInclude(r);
    }
    if (area == null) return;
    final int i0 = ((area.left - grid.origin.dx) / cell).floor().clamp(
      0,
      grid.cols,
    );
    final int i1 = ((area.right - grid.origin.dx) / cell).ceil().clamp(
      0,
      grid.cols,
    );
    final int j0 = ((area.top - grid.origin.dy) / cell).floor().clamp(
      0,
      grid.rows,
    );
    final int j1 = ((area.bottom - grid.origin.dy) / cell).ceil().clamp(
      0,
      grid.rows,
    );

    _photo.shader = scene.photoShader;
    for (int j = j0; j < j1; j++) {
      final double cy = grid.origin.dy + (j + 0.5) * cell;
      for (int i = i0; i < i1; i++) {
        final double cx = grid.origin.dx + (i + 0.5) * cell;
        final double va = a == null ? 0.0 : a.amountAt(cx, cy, merge);
        if (va < 0) continue;
        final double vb = b == null ? 0.0 : b.amountAt(cx, cy, merge);
        if (vb < 0) continue;
        final double v = math.max(va, vb);
        if (v <= 0) continue;
        final int index = j * grid.cols + i;
        final double base = scene.radii[index];
        // Dots swell quickly at the outer edge and ease into full cells.
        final double rest = 1.0 - v;
        final double grow = 1.0 - rest * rest * rest;
        final double r = base + (merge - base) * grow;
        final Offset c = Offset(cx, cy);
        canvas.drawCircle(c, r, _photo);
        // Ink fades out over the outer part of the ring so swelling dots
        // read as dots first, then as windows into the photo.
        final double ink = 1.0 - _fadeIn(v / 0.5);
        if (ink <= 0.004) continue;
        final Color color = colored ? Color(grid.colors[index]) : dotColor;
        _ink.color = color.withValues(alpha: color.a * ink);
        canvas.drawCircle(c, r, _ink);
      }
    }
    _photo.shader = null;
  }

  void _paintPhoto(
    Canvas canvas,
    _HalftoneScene scene,
    Rect bounds,
    _Window w,
  ) {
    // The photo is opaque inside the ring and fades out with a smoothstep
    // across its middle, covering the last gaps between swelling dots.
    final double ring = w.outer - w.inner;
    final double clear = w.outer - ring * _photoStart;
    if (clear <= 0.5 || w.strength <= 0) return;
    final Rect rect = Rect.fromCircle(
      center: w.center,
      radius: clear,
    ).intersect(bounds);
    if (rect.isEmpty) return;
    for (int k = 0; k < _maskSteps; k++) {
      final double t = k / (_maskSteps - 1);
      final double u = _photoEnd - (_photoEnd - _photoStart) * t;
      final double d = w.outer - ring * u;
      _maskStops[k + 1] = (d / clear).clamp(0.0, 1.0);
      final double alpha = (1.0 - _fadeIn(t)) * w.strength;
      _maskColors[k + 1] = Color.from(alpha: alpha, red: 0, green: 0, blue: 0);
    }
    _maskStops[0] = 0.0;
    _maskColors[0] = Color.from(alpha: w.strength, red: 0, green: 0, blue: 0);
    _mask.shader = ui.Gradient.radial(w.center, clear, _maskColors, _maskStops);
    canvas
      ..save()
      ..clipRect(rect)
      ..saveLayer(rect, Paint());
    canvas.drawImageRect(scene.image, scene.grid.src, scene.grid.dst, _photo);
    canvas.drawRect(rect, _mask);
    canvas
      ..restore()
      ..restore();
    _mask.shader = null;
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.pointer != pointer ||
        oldDelegate.hover != hover ||
        oldDelegate.full != full ||
        oldDelegate.revealRadius != revealRadius ||
        oldDelegate.softness != softness ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.colored != colored;
  }
}
