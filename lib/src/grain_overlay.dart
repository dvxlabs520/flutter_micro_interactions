import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'utils/motion.dart';

/// Paints an animated film grain over its child.
///
/// A subtle noise texture gives flat surfaces, gradients and hero images
/// an analog, printed feel:
///
/// ```dart
/// GrainOverlay(
///   opacity: 0.1,
///   child: Image.asset('assets/hero.jpg', fit: BoxFit.cover),
/// )
/// ```
///
/// The grain is cheap to run. A small noise tile is generated once and
/// shared by every [GrainOverlay] in the app. It is painted as a repeated
/// image shader, and animating it only moves the shader to another random
/// offset every [refreshInterval] (12 times per second by default, like
/// film). No per-pixel work happens per frame, the grain sits in its own
/// repaint boundary so the child never repaints because of it, and the
/// overlay only schedules frames at the refresh rate, not every vsync.
///
/// The grain blends with [blendMode], [BlendMode.overlay] by default,
/// which darkens dark areas and lightens light ones like real grain. If
/// the result looks wrong on a platform or over a very dark or very light
/// child, use [BlendMode.srcOver] (a plain translucent layer) or
/// [BlendMode.softLight].
///
/// The overlay ignores pointer events and adds no semantics, so taps and
/// screen readers reach the child as if the grain were not there.
///
/// Under reduced motion, or when [animated] is false, the grain is static
/// and no refresh timer runs. When [enabled] is false no grain is painted.
class GrainOverlay extends StatefulWidget {
  /// Creates a film grain overlay over [child].
  const GrainOverlay({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.grainSize = 1.0,
    this.refreshInterval = const Duration(microseconds: 83333),
    this.blendMode = BlendMode.overlay,
    this.monochrome = true,
    this.animated = true,
    this.enabled = true,
  }) : assert(opacity >= 0 && opacity <= 1, 'opacity must be between 0 and 1'),
       assert(grainSize > 0, 'grainSize must be greater than 0');

  /// The widget painted under the grain.
  final Widget child;

  /// Strength of the grain, from 0 (invisible) to 1. Defaults to 0.08.
  final double opacity;

  /// Size of one grain dot in logical pixels. Defaults to 1.
  final double grainSize;

  /// How often the grain changes while animated. Defaults to 1/12 of a
  /// second. A zero or negative interval keeps the grain static.
  final Duration refreshInterval;

  /// How the grain blends with the child. Defaults to
  /// [BlendMode.overlay].
  final BlendMode blendMode;

  /// Whether the grain is gray (true, the default) or colored.
  final bool monochrome;

  /// Whether the grain changes over time. Defaults to true. Reduced motion
  /// always shows static grain.
  final bool animated;

  /// When false no grain is painted and no timer runs. Defaults to true.
  final bool enabled;

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  /// Number of pre-built shader offsets cycled through while animating.
  static const int _frameCount = 8;

  final math.Random _random = math.Random();
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  _GrainTile? _tile;
  List<ui.ImageShader> _shaders = const <ui.ImageShader>[];
  Timer? _timer;
  bool _reduced = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _syncTile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncTimer();
  }

  @override
  void didUpdateWidget(GrainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.monochrome != oldWidget.monochrome) {
      _syncTile();
    } else if (widget.grainSize != oldWidget.grainSize) {
      _rebuildShaders();
    }
    if (widget.refreshInterval != oldWidget.refreshInterval) {
      _timer?.cancel();
      _timer = null;
    }
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeShaders();
    _tile?.release();
    _tile = null;
    _frame.dispose();
    super.dispose();
  }

  /// Acquires (or releases) the shared noise tile to match the widget.
  void _syncTile() {
    final _GrainTile? current = _tile;
    if (!widget.enabled) {
      if (current != null) {
        _disposeShaders();
        current.release();
        _tile = null;
      }
      return;
    }
    if (current != null && current.monochrome == widget.monochrome) {
      return;
    }
    _disposeShaders();
    current?.release();
    _tile = _GrainTile.acquire(monochrome: widget.monochrome);
    _rebuildShaders();
  }

  void _rebuildShaders() {
    _disposeShaders();
    final _GrainTile? tile = _tile;
    if (tile == null) {
      return;
    }
    final double scale = widget.grainSize;
    final double size = _GrainTile.size.toDouble();
    // A fixed seed keeps the static (reduced motion) grain stable.
    final math.Random offsets = math.Random(7);
    _shaders = <ui.ImageShader>[
      for (int i = 0; i < _frameCount; i++)
        ui.ImageShader(
          tile.image,
          TileMode.repeated,
          TileMode.repeated,
          Float64List.fromList(<double>[
            scale, 0, 0, 0, //
            0, scale, 0, 0, //
            0, 0, 1, 0, //
            i == 0 ? 0 : offsets.nextDouble() * size * scale,
            i == 0 ? 0 : offsets.nextDouble() * size * scale,
            0,
            1,
          ]),
          filterQuality: FilterQuality.none,
        ),
    ];
  }

  void _disposeShaders() {
    for (final ui.ImageShader shader in _shaders) {
      shader.dispose();
    }
    _shaders = const <ui.ImageShader>[];
  }

  void _syncTimer() {
    final bool run =
        _tile != null &&
        widget.animated &&
        !_reduced &&
        _tickerEnabled &&
        widget.refreshInterval > Duration.zero;
    if (!run) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(widget.refreshInterval, (Timer _) {
      if (!mounted) {
        return;
      }
      // Jump to a different random frame; a repeat would look like a skip.
      final int next =
          (_frame.value + 1 + _random.nextInt(_frameCount - 1)) % _frameCount;
      _frame.value = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _GrainTile? tile = _tile;
    final bool showGrain =
        tile != null && _shaders.isNotEmpty && widget.opacity > 0;
    // The Stack is kept even without grain so toggling [enabled] or
    // fading [opacity] to 0 never remounts the child.
    return Stack(
      // Keep the child's own constraints; the grain only overlays it.
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        if (showGrain)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                // Grain repaints never repaint the child.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GrainPainter(
                      image: tile.image,
                      shaders: _shaders,
                      frame: _frame,
                      opacity: widget.opacity,
                      blendMode: widget.blendMode,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.image,
    required this.shaders,
    required this.frame,
    required this.opacity,
    required this.blendMode,
  }) : super(repaint: frame);

  /// The shared noise tile, kept for inspection and repaint checks.
  final ui.Image image;

  /// One pre-built shader per grain frame.
  final List<ui.ImageShader> shaders;

  /// Index of the shader to paint.
  final ValueListenable<int> frame;

  /// Strength of the grain.
  final double opacity;

  /// How the grain blends with what is below.
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (shaders.isEmpty) {
      return;
    }
    final Paint paint = Paint()
      // The paint's alpha scales the shader's output.
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..blendMode = blendMode
      ..shader = shaders[frame.value % shaders.length];
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) {
    return oldDelegate.image != image ||
        !identical(oldDelegate.shaders, shaders) ||
        oldDelegate.frame != frame ||
        oldDelegate.opacity != opacity ||
        oldDelegate.blendMode != blendMode;
  }
}

/// A shared, reference-counted noise tile.
///
/// The tile is generated synchronously with [ui.Picture.toImageSync], which
/// works on every platform including the web and tests, so the grain is
/// ready on the first frame. It is disposed when the last user releases it.
class _GrainTile {
  _GrainTile._(this.monochrome, this.image);

  /// Width and height of the tile in pixels.
  static const int size = 128;

  /// Number of brightness levels per channel.
  static const int _levels = 24;

  static final Map<bool, _GrainTile> _cache = <bool, _GrainTile>{};

  /// Whether the tile is gray or colored.
  final bool monochrome;

  /// The noise image.
  final ui.Image image;

  int _refs = 0;

  static _GrainTile acquire({required bool monochrome}) {
    final _GrainTile tile = _cache.putIfAbsent(
      monochrome,
      () => _GrainTile._(monochrome, _generate(monochrome)),
    );
    tile._refs++;
    return tile;
  }

  void release() {
    _refs--;
    if (_refs <= 0) {
      _cache.remove(monochrome);
      image.dispose();
    }
  }

  /// Draws [size] x [size] random pixels. Pixels are grouped by level so
  /// the whole tile takes a few dozen point batches instead of one draw
  /// per pixel. Values follow a triangular distribution centered on mid
  /// gray, which reads as softer, more natural grain than flat noise and
  /// stays neutral under [BlendMode.overlay].
  static ui.Image _generate(bool monochrome) {
    final math.Random random = math.Random(1337);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Rect bounds = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final Canvas canvas = Canvas(recorder, bounds);
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF000000));

    final List<int> channels = monochrome ? <int>[0] : <int>[0, 1, 2];
    for (final int channel in channels) {
      final List<List<double>> buckets = List<List<double>>.generate(
        _levels,
        (int _) => <double>[],
      );
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final double v = (random.nextDouble() + random.nextDouble()) / 2;
          final int level = math.min(_levels - 1, (v * _levels).floor());
          buckets[level]
            ..add(x + 0.5)
            ..add(y + 0.5);
        }
      }
      for (int level = 0; level < _levels; level++) {
        final List<double> points = buckets[level];
        if (points.isEmpty) {
          continue;
        }
        final int value = (level / (_levels - 1) * 255).round();
        final Color color = monochrome
            ? Color.fromARGB(255, value, value, value)
            : Color.fromARGB(
                255,
                channel == 0 ? value : 0,
                channel == 1 ? value : 0,
                channel == 2 ? value : 0,
              );
        final Paint paint = Paint()
          ..color = color
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false
          // Channels are drawn separately and added together.
          ..blendMode = monochrome ? BlendMode.srcOver : BlendMode.plus;
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.fromList(points),
          paint,
        );
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }
}
