import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Metal presets for a [ReflectiveCard].
enum ReflectiveCardFinish {
  /// Cool, bright polished steel with strong contrast between bands.
  chrome,

  /// Warm polished gold.
  gold,

  /// Dark anodized metal with soft highlights.
  graphite,

  /// Pearl silver with a rainbow sheen, like a hologram foil. Always shows
  /// the holographic layer, whatever [ReflectiveCard.holographic] says.
  holographic,
}

/// A metal card that tilts toward the pointer and catches the light as it
/// moves, like a chrome ID card turned in the hand.
///
/// ```dart
/// ReflectiveCard(
///   finish: ReflectiveCardFinish.chrome,
///   width: 340,
///   child: const Padding(
///     padding: EdgeInsets.all(20),
///     child: Column(
///       crossAxisAlignment: CrossAxisAlignment.start,
///       children: <Widget>[
///         Text('ACCESS PASS'),
///         Spacer(),
///         Text('Ada Lovelace'),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// The surface is built from several light layers that all respond to the
/// tilt: polished metal bands that slide across the card, a fine brushed
/// texture (generated once and cached), a broad soft light that follows the
/// pointer, a sharp specular streak that sweeps faster than the light, an
/// optional rainbow foil ([holographic]) whose angle and position shift
/// with the tilt, and an optional [reflection] image that drifts the
/// opposite way, like the room reflected in polished metal. The web
/// original reflects the user's webcam; this widget uses an image instead
/// and never accesses a camera.
///
/// The [child] floats on a slightly raised layer: it shifts a few pixels
/// with the tilt ([parallax]) to suggest depth. Default text and icon
/// colors are chosen to read well on the selected [finish]. The drop
/// shadow moves away from the light.
///
/// On a mouse, the card tilts while the pointer is over it. On touch, it
/// tilts while a finger is pressed and dragged over it and springs back
/// when the finger lifts. Tilt follows a spring, so it settles smoothly
/// and overshoots a little on release. Pointer events are observed without
/// being consumed, so buttons inside [child] keep working.
///
/// With [idleAnimation], a slow light sweep (one loop every
/// [idleDuration]) keeps the surface alive when nobody interacts, which
/// matters on touch screens. It fades out while the card is being tilted
/// and pauses entirely while a pointer rests on the card.
///
/// Accessibility: all metal and light layers are decorative and add no
/// semantics; the semantics of [child] are untouched.
///
/// Under reduced motion, or when [enabled] is `false`, the card renders
/// flat with a static sheen: no tilt, no idle sweep and no animation.
class ReflectiveCard extends StatefulWidget {
  /// Creates a reflective metal card.
  const ReflectiveCard({
    super.key,
    this.child,
    this.width,
    this.height,
    this.aspectRatio = 85.6 / 54,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.finish = ReflectiveCardFinish.chrome,
    this.metalColor,
    this.maxTilt = 14,
    this.holographic = false,
    this.reflection,
    this.reflectionOpacity = 0.22,
    this.brushed = true,
    this.elevation = 18,
    this.parallax = 6,
    this.perspective = 0.0012,
    this.idleAnimation = true,
    this.idleDuration = const Duration(seconds: 6),
    this.enabled = true,
  }) : assert(width == null || width > 0, 'width must be positive'),
       assert(height == null || height > 0, 'height must be positive'),
       assert(aspectRatio > 0, 'aspectRatio must be positive'),
       assert(
         maxTilt >= 0 && maxTilt <= 45,
         'maxTilt must be between 0 and 45 degrees',
       ),
       assert(
         reflectionOpacity >= 0 && reflectionOpacity <= 1,
         'reflectionOpacity must be in [0, 1]',
       ),
       assert(elevation >= 0, 'elevation must not be negative'),
       assert(perspective >= 0, 'perspective must not be negative');

  /// Content printed on the card, such as a name and an ID number. It
  /// fills the card; add your own padding.
  final Widget? child;

  /// Width of the card. When null, the card takes the available width (or
  /// 340 when unbounded), or derives it from [height] and [aspectRatio].
  final double? width;

  /// Height of the card. When null it is derived from the width and
  /// [aspectRatio].
  final double? height;

  /// Width divided by height, used when [width] or [height] is missing.
  /// Defaults to the ID-1 card format, 85.6 by 54 millimeters.
  final double aspectRatio;

  /// Corner rounding of the card. Defaults to a 20 pixel circular radius.
  final BorderRadius borderRadius;

  /// Metal preset. Defaults to [ReflectiveCardFinish.chrome].
  final ReflectiveCardFinish finish;

  /// Optional base tint that replaces the color bands of [finish] with
  /// lighter and darker shades of this color, keeping the finish's light
  /// behavior.
  final Color? metalColor;

  /// Maximum rotation, in degrees, reached when the pointer is at an edge.
  /// Defaults to 14.
  final double maxTilt;

  /// Whether to add a rainbow foil sheen. Always on for
  /// [ReflectiveCardFinish.holographic]. Defaults to `false`.
  final bool holographic;

  /// Optional image reflected faintly on the surface. It drifts opposite
  /// to the tilt like a real reflection. Loaded asynchronously; the card
  /// renders without it until it is ready.
  final ImageProvider? reflection;

  /// Strength of the [reflection], in `[0, 1]`. Defaults to 0.22.
  final double reflectionOpacity;

  /// Whether to show a fine brushed-metal texture. Defaults to `true`.
  final bool brushed;

  /// Size of the drop shadow, in logical pixels. 0 removes it. Defaults to
  /// 18.
  final double elevation;

  /// How far, in logical pixels, [child] shifts at full tilt to appear
  /// raised above the surface. Defaults to 6.
  final double parallax;

  /// Strength of the perspective effect. Defaults to 0.0012.
  final double perspective;

  /// Whether a slow light sweep runs while nobody interacts. Defaults to
  /// `true`.
  final bool idleAnimation;

  /// Length of one idle sweep loop. Defaults to 6 seconds.
  final Duration idleDuration;

  /// When `false` the card renders flat with a static sheen and ignores
  /// the pointer. Defaults to `true`.
  final bool enabled;

  @override
  State<ReflectiveCard> createState() => _ReflectiveCardState();
}

/// Current light and tilt of a [ReflectiveCard], shared by its painters.
class _CardMotion extends ChangeNotifier {
  /// Geometric tilt, normalized: x and y in about `[-1, 1]`.
  Offset tilt = Offset.zero;

  /// Light position on the card, normalized: `(-1, -1)` is the top left
  /// corner, `(1, 1)` the bottom right.
  Offset light = _ReflectiveCardState._staticLight;

  /// How engaged the card is, from 0 (idle) to 1 (tilted by a pointer).
  double activity = 0;

  void update(Offset tilt, Offset light, double activity) {
    if (tilt == this.tilt && light == this.light && activity == this.activity) {
      return;
    }
    this.tilt = tilt;
    this.light = light;
    this.activity = activity;
    notifyListeners();
  }
}

class _ReflectiveCardState extends State<ReflectiveCard>
    with TickerProviderStateMixin {
  /// Light position used when nothing moves (reduced motion, disabled).
  static const Offset _staticLight = Offset(-0.35, -0.45);

  /// Spring constants for the tilt, per second squared.
  static const double _stiffness = 210;
  static const double _dampingRatio = 0.72;

  /// Rate of the activity fade, per second.
  static const double _activityRate = 9;

  final _CardMotion _motion = _CardMotion();
  late final Ticker _ticker;
  late final AnimationController _idle;
  final _TextureCache _texture = _TextureCache();

  Duration _lastTick = Duration.zero;
  Offset _tilt = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _target = Offset.zero;
  double _activity = 0;
  double _activityTarget = 0;

  bool _hovered = false;
  final Set<int> _pressedPointers = <int>{};
  bool _reduced = false;

  ImageStream? _imageStream;
  ImageInfo? _reflectionInfo;
  late final ImageStreamListener _imageListener = ImageStreamListener(
    _handleImage,
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _idle = AnimationController(vsync: this, duration: widget.idleDuration)
      ..addListener(_publish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (!_live) _reset();
    _syncIdle();
    _publish();
    _resolveReflection();
  }

  @override
  void didUpdateWidget(ReflectiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.idleDuration != oldWidget.idleDuration) {
      _idle.duration = widget.idleDuration;
      if (_idle.isAnimating) _idle.repeat();
    }
    if (!_live) _reset();
    _syncIdle();
    _publish();
    if (widget.reflection != oldWidget.reflection) _resolveReflection();
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_imageListener);
    _reflectionInfo?.dispose();
    _ticker.dispose();
    _idle.dispose();
    _motion.dispose();
    _texture.dispose();
    super.dispose();
  }

  /// Whether the card reacts to the pointer and animates.
  bool get _live => widget.enabled && !_reduced;

  // Reflection image ---------------------------------------------------------

  void _resolveReflection() {
    final ImageProvider? provider = widget.reflection;
    if (provider == null) {
      _imageStream?.removeListener(_imageListener);
      _imageStream = null;
      if (_reflectionInfo != null) {
        _reflectionInfo!.dispose();
        _reflectionInfo = null;
        if (mounted) setState(() {});
      }
      return;
    }
    final ImageStream stream = provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _imageStream?.key) return;
    _imageStream?.removeListener(_imageListener);
    _imageStream = stream..addListener(_imageListener);
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _reflectionInfo?.dispose();
      _reflectionInfo = info;
    });
  }

  // Motion -------------------------------------------------------------------

  void _reset() {
    _hovered = false;
    _pressedPointers.clear();
    _ticker.stop();
    _tilt = Offset.zero;
    _velocity = Offset.zero;
    _target = Offset.zero;
    _activity = 0;
    _activityTarget = 0;
  }

  bool get _shouldIdle => widget.idleAnimation && _live && _activityTarget == 0;

  void _syncIdle() {
    if (_shouldIdle) {
      if (!_idle.isAnimating) _idle.repeat();
    } else if (!widget.idleAnimation || !_live) {
      _idle.stop();
      _idle.value = 0;
    }
  }

  void _publish() {
    if (!_live) {
      _motion.update(Offset.zero, _staticLight, 0);
      return;
    }
    Offset idleLight = Offset.zero;
    if (widget.idleAnimation) {
      final double theta = _idle.value * 2 * math.pi;
      idleLight = Offset(
        math.sin(theta) * 0.85,
        math.sin(2 * theta) * 0.28 - 0.18,
      );
    }
    final double rest = 1 - _activity.clamp(0.0, 1.0);
    final Offset light = _tilt + idleLight * rest;
    final Offset tilt = _tilt + idleLight * (0.18 * rest);
    _motion.update(tilt, light, _activity);
  }

  void _start() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) dt = 1 / 60;
    dt = math.min(dt, 1 / 30);
    // Semi-implicit Euler on a damped spring, in two sub-steps for
    // stability on slow frames.
    final double damping = 2 * _dampingRatio * math.sqrt(_stiffness);
    for (int i = 0; i < 2; i++) {
      final double h = dt / 2;
      final Offset force = (_target - _tilt) * _stiffness - _velocity * damping;
      _velocity += force * h;
      _tilt += _velocity * h;
    }
    _activity +=
        (_activityTarget - _activity) * (1 - math.exp(-dt * _activityRate));

    final bool settled =
        (_target - _tilt).distance < 0.0005 &&
        _velocity.distance < 0.002 &&
        (_activityTarget - _activity).abs() < 0.002;
    if (settled) {
      _tilt = _target;
      _velocity = Offset.zero;
      _activity = _activityTarget;
      _ticker.stop();
    }
    // While a pointer rests on the card, the idle sweep is invisible.
    if (_activityTarget == 1 && _activity > 0.99 && _idle.isAnimating) {
      _idle.stop();
    }
    _publish();
  }

  void _setTarget(Offset local) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;
    final Size size = object.size;
    if (size.isEmpty) return;
    _target = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _start();
  }

  void _updateActive() {
    final bool active = _hovered || _pressedPointers.isNotEmpty;
    _activityTarget = active ? 1 : 0;
    if (!active) _target = Offset.zero;
    if (_shouldIdle && !_idle.isAnimating) _idle.repeat();
    _start();
  }

  void _handleEnter(PointerEnterEvent event) {
    _hovered = true;
    _setTarget(event.localPosition);
    _updateActive();
  }

  void _handleHover(PointerHoverEvent event) => _setTarget(event.localPosition);

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _updateActive();
  }

  void _handleDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _pressedPointers.add(event.pointer);
    _setTarget(event.localPosition);
    _updateActive();
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.mouse && !_hovered) return;
    _setTarget(event.localPosition);
  }

  void _handleUp(PointerEvent event) {
    if (_pressedPointers.remove(event.pointer)) _updateActive();
  }

  // Build ----------------------------------------------------------------------

  Size _resolveSize(BoxConstraints constraints) {
    final double? w = widget.width;
    final double? h = widget.height;
    if (w != null && h != null) return constraints.constrain(Size(w, h));
    if (w != null) {
      return constraints.constrain(Size(w, w / widget.aspectRatio));
    }
    if (h != null) {
      return constraints.constrain(Size(h * widget.aspectRatio, h));
    }
    double width = constraints.hasBoundedWidth ? constraints.maxWidth : 340;
    double height = width / widget.aspectRatio;
    if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * widget.aspectRatio;
    }
    return constraints.constrain(Size(width, height));
  }

  Matrix4 _transformFor(Offset tilt, double activity) {
    final double maxRadians = widget.maxTilt * math.pi / 180;
    final double scale = 1 + 0.025 * activity.clamp(0.0, 1.2);
    // Flutter projects +z away from the viewer, so these signs push the
    // side under the pointer back.
    return Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..rotateX(tilt.dy * maxRadians)
      ..rotateY(-tilt.dx * maxRadians)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final bool live = _live;
    final _FinishStyle style = _FinishStyle.resolve(
      widget.finish,
      widget.metalColor,
    );
    final bool hologram =
        widget.holographic || widget.finish == ReflectiveCardFinish.holographic;
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;

    Widget content = const SizedBox.expand();
    if (widget.child != null) {
      content = DefaultTextStyle.merge(
        style: TextStyle(color: style.foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: style.foreground),
          child: widget.child!,
        ),
      );
    }

    final Widget surface = ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: _SurfacePainter(
              motion: _motion,
              style: style,
              hologram: hologram,
              brushed: widget.brushed,
              texture: _texture,
              devicePixelRatio: dpr,
              reflection: _reflectionInfo?.image,
              reflectionOpacity: widget.reflectionOpacity,
            ),
          ),
          AnimatedBuilder(
            animation: _motion,
            builder: (BuildContext context, Widget? child) {
              return Transform.translate(
                offset: _motion.tilt * widget.parallax,
                child: child,
              );
            },
            child: RepaintBoundary(child: content),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _RimPainter(
                motion: _motion,
                borderRadius: widget.borderRadius,
                style: style,
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = _resolveSize(constraints);
        return MouseRegion(
          opaque: false,
          onEnter: live ? _handleEnter : null,
          onHover: live ? _handleHover : null,
          onExit: live ? _handleExit : null,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: live ? _handleDown : null,
            onPointerMove: live ? _handleMove : null,
            onPointerUp: live ? _handleUp : null,
            onPointerCancel: live ? _handleUp : null,
            child: SizedBox.fromSize(
              size: size,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (BuildContext context, Widget? child) {
                  // The shadow lives inside the transform so it follows
                  // the card's projected outline instead of sticking out.
                  return Transform(
                    alignment: Alignment.center,
                    transform:
                        _motion.tilt == Offset.zero && _motion.activity == 0
                        ? Matrix4.identity()
                        : _transformFor(_motion.tilt, _motion.activity),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: widget.borderRadius,
                              boxShadow: widget.elevation > 0
                                  ? _shadows(_motion)
                                  : null,
                            ),
                          ),
                        ),
                        child!,
                      ],
                    ),
                  );
                },
                child: RepaintBoundary(child: surface),
              ),
            ),
          ),
        );
      },
    );
  }

  List<BoxShadow> _shadows(_CardMotion motion) {
    final double e = widget.elevation;
    final Offset away = -motion.light * (e * 0.45);
    final double lift = 1 + 0.25 * motion.activity.clamp(0.0, 1.0);
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0x52000000),
        blurRadius: e * 1.6 * lift,
        spreadRadius: -e * 0.2,
        offset: Offset(away.dx, e * 0.6 * lift + away.dy * 0.6),
      ),
      BoxShadow(
        color: const Color(0x24000000),
        blurRadius: e * 0.5,
        offset: Offset(away.dx * 0.15, e * 0.12),
      ),
    ];
  }
}

/// Colors and light strengths of a finish.
class _FinishStyle {
  const _FinishStyle({
    required this.bands,
    required this.specular,
    required this.foreground,
    required this.lightStrength,
    required this.streakStrength,
    required this.textureStrength,
    required this.hologramStrength,
  });

  /// Metal bands, from the top left to the bottom right corner.
  final List<Color> bands;

  /// Color of highlights.
  final Color specular;

  /// Default color for text and icons on the card.
  final Color foreground;

  /// Peak alpha of the broad soft light.
  final double lightStrength;

  /// Peak alpha of the specular streak.
  final double streakStrength;

  /// Alpha multiplier of the brushed texture.
  final double textureStrength;

  /// Alpha of the holographic foil.
  final double hologramStrength;

  static const _FinishStyle chrome = _FinishStyle(
    bands: <Color>[
      Color(0xFF5F6873),
      Color(0xFFC9D0D8),
      Color(0xFF8C96A1),
      Color(0xFFF1F4F7),
      Color(0xFF77818C),
      Color(0xFFB5BDC6),
      Color(0xFF59626C),
    ],
    specular: Color(0xFFFFFFFF),
    foreground: Color(0xFF1E242B),
    lightStrength: 0.42,
    streakStrength: 0.75,
    textureStrength: 1,
    hologramStrength: 0.65,
  );

  static const _FinishStyle gold = _FinishStyle(
    bands: <Color>[
      Color(0xFF6E4D16),
      Color(0xFFE2BC68),
      Color(0xFFA27428),
      Color(0xFFFBE3A0),
      Color(0xFF8A6220),
      Color(0xFFD1A752),
      Color(0xFF654613),
    ],
    specular: Color(0xFFFFF3D2),
    foreground: Color(0xFF3A2708),
    lightStrength: 0.38,
    streakStrength: 0.7,
    textureStrength: 0.9,
    hologramStrength: 0.45,
  );

  static const _FinishStyle graphite = _FinishStyle(
    bands: <Color>[
      Color(0xFF17191D),
      Color(0xFF41464E),
      Color(0xFF24272C),
      Color(0xFF5C626B),
      Color(0xFF1D2025),
      Color(0xFF383C43),
      Color(0xFF131518),
    ],
    specular: Color(0xFFE8EEF6),
    foreground: Color(0xFFE9EDF2),
    lightStrength: 0.3,
    streakStrength: 0.5,
    textureStrength: 1.2,
    hologramStrength: 0.6,
  );

  static const _FinishStyle pearl = _FinishStyle(
    bands: <Color>[
      Color(0xFFA9AFBD),
      Color(0xFFE4E7EF),
      Color(0xFFC2C7D3),
      Color(0xFFF6F7FB),
      Color(0xFFB4BAC8),
      Color(0xFFDADEE8),
      Color(0xFFA2A8B7),
    ],
    specular: Color(0xFFFFFFFF),
    foreground: Color(0xFF232838),
    lightStrength: 0.36,
    streakStrength: 0.65,
    textureStrength: 0.7,
    hologramStrength: 0.85,
  );

  static _FinishStyle resolve(ReflectiveCardFinish finish, Color? tint) {
    final _FinishStyle base = switch (finish) {
      ReflectiveCardFinish.chrome => chrome,
      ReflectiveCardFinish.gold => gold,
      ReflectiveCardFinish.graphite => graphite,
      ReflectiveCardFinish.holographic => pearl,
    };
    if (tint == null) return base;
    final HSLColor hsl = HSLColor.fromColor(tint);
    const List<double> shifts = <double>[
      -0.24,
      0.16,
      -0.08,
      0.3,
      -0.16,
      0.08,
      -0.28,
    ];
    final List<Color> bands = <Color>[
      for (final double shift in shifts)
        hsl.withLightness((hsl.lightness + shift).clamp(0.02, 0.97)).toColor(),
    ];
    final bool dark = hsl.lightness < 0.45;
    return _FinishStyle(
      bands: bands,
      specular: base.specular,
      foreground: dark ? const Color(0xFFF2F4F7) : const Color(0xFF1C2026),
      lightStrength: base.lightStrength,
      streakStrength: base.streakStrength,
      textureStrength: base.textureStrength,
      hologramStrength: base.hologramStrength,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _FinishStyle &&
        listEquals(other.bands, bands) &&
        other.specular == specular &&
        other.foreground == foreground &&
        other.lightStrength == lightStrength &&
        other.streakStrength == streakStrength &&
        other.textureStrength == textureStrength &&
        other.hologramStrength == hologramStrength;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(bands),
    specular,
    foreground,
    lightStrength,
    streakStrength,
    textureStrength,
    hologramStrength,
  );
}

/// Lazily generated brushed-metal texture, cached per size.
class _TextureCache {
  ui.Image? _image;
  Size _size = Size.zero;
  double _scale = 0;

  /// Returns the texture for [size] at [scale], generating it when needed.
  ui.Image imageFor(Size size, double scale) {
    final ui.Image? cached = _image;
    if (cached != null && size == _size && scale == _scale) return cached;
    cached?.dispose();
    final int width = math.max(1, (size.width * scale).ceil());
    final int height = math.max(1, (size.height * scale).ceil());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    // Fixed seed: the same card always gets the same grain.
    final math.Random random = math.Random(7);
    final Paint paint = Paint()..strokeWidth = 1;
    for (int y = 0; y < height; y++) {
      double x = -random.nextDouble() * width * 0.5;
      while (x < width) {
        final double length = width * (0.15 + random.nextDouble() * 0.6);
        final bool light = random.nextBool();
        final double alpha = 0.03 + random.nextDouble() * 0.09;
        paint.color = light
            ? Color.fromRGBO(255, 255, 255, alpha)
            : Color.fromRGBO(0, 0, 0, alpha);
        canvas.drawLine(Offset(x, y + 0.5), Offset(x + length, y + 0.5), paint);
        x += length + random.nextDouble() * width * 0.1;
      }
    }
    // A few long, slightly brighter scratches.
    for (int i = 0; i < height ~/ 18; i++) {
      final double y = random.nextDouble() * height;
      paint
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          0.08 + random.nextDouble() * 0.08,
        )
        ..strokeWidth = 0.7;
      final double start = random.nextDouble() * width * 0.6;
      canvas.drawLine(
        Offset(start, y),
        Offset(start + width * (0.2 + random.nextDouble() * 0.5), y),
        paint,
      );
      paint.strokeWidth = 1;
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(width, height);
    picture.dispose();
    _image = image;
    _size = size;
    _scale = scale;
    return image;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}

/// Paints the metal surface: bands, texture, reflection, foil and light.
class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.motion,
    required this.style,
    required this.hologram,
    required this.brushed,
    required this.texture,
    required this.devicePixelRatio,
    required this.reflection,
    required this.reflectionOpacity,
  }) : super(repaint: motion);

  /// Light and tilt source.
  final _CardMotion motion;

  /// Finish colors.
  final _FinishStyle style;

  /// Whether to paint the rainbow foil.
  final bool hologram;

  /// Whether to paint the brushed texture.
  final bool brushed;

  /// Texture cache owned by the card state.
  final _TextureCache texture;

  /// Device pixel ratio for the texture resolution.
  final double devicePixelRatio;

  /// Optional reflected image.
  final ui.Image? reflection;

  /// Strength of [reflection].
  final double reflectionOpacity;

  static const List<Color> _foil = <Color>[
    Color(0xFFFF6B9A),
    Color(0xFFFFC46B),
    Color(0xFFF4FF7A),
    Color(0xFF7BFFB0),
    Color(0xFF6BD9FF),
    Color(0xFF8B7BFF),
    Color(0xFFE77BFF),
    Color(0xFFFF6B9A),
  ];

  /// The light position in local pixels, for the current frame.
  Offset lightPoint(Size size) {
    final Offset l = motion.light;
    return Offset((l.dx + 1) / 2 * size.width, (l.dy + 1) / 2 * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final Offset l = motion.light;
    final double w = size.width;
    final double h = size.height;
    final double diagonal = math.sqrt(w * w + h * h);

    // 1. Polished bands that slide against the light, like a mirror finish
    // reflecting a bright room.
    final Offset bandShift = Offset(-l.dx * w * 0.32, -l.dy * h * 0.32);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-w * 0.1, -h * 0.1) + bandShift,
          Offset(w * 1.1, h * 1.1) + bandShift,
          style.bands,
          _evenStops(style.bands.length),
          TileMode.mirror,
        ),
    );

    // 2. Brushed grain.
    if (brushed) {
      final ui.Image image = texture.imageFor(
        size,
        devicePixelRatio.clamp(1.0, 3.0),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint()
          ..blendMode = BlendMode.overlay
          ..color = Color.fromRGBO(
            0,
            0,
            0,
            (0.85 * style.textureStrength).clamp(0.0, 1.0),
          )
          ..filterQuality = FilterQuality.medium,
      );
    }

    // 3. Reflection, drifting opposite to the tilt.
    final ui.Image? image = reflection;
    if (image != null && reflectionOpacity > 0) {
      final double coverScale = math.max(
        w * 1.3 / image.width,
        h * 1.3 / image.height,
      );
      final Size drawn = Size(
        image.width * coverScale,
        image.height * coverScale,
      );
      final Offset center =
          rect.center + Offset(-l.dx * w * 0.1, -l.dy * h * 0.1);
      // Brushed metal smears reflections along the grain.
      final ui.ImageFilter blur = ui.ImageFilter.blur(
        sigmaX: w * (brushed ? 0.014 : 0.006),
        sigmaY: w * 0.004,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: center,
          width: drawn.width,
          height: drawn.height,
        ),
        Paint()
          ..blendMode = BlendMode.softLight
          ..color = Color.fromRGBO(0, 0, 0, reflectionOpacity)
          ..imageFilter = blur
          ..colorFilter = const ColorFilter.matrix(<double>[
            0.5, 0.4, 0.1, 0, 0, //
            0.2, 0.7, 0.1, 0, 0, //
            0.2, 0.4, 0.4, 0, 0, //
            0, 0, 0, 1, 0, //
          ])
          ..filterQuality = FilterQuality.medium,
      );
      // A faint direct copy keeps the reflection readable on dark metal.
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: center,
          width: drawn.width,
          height: drawn.height,
        ),
        Paint()
          ..blendMode = BlendMode.screen
          ..color = Color.fromRGBO(0, 0, 0, reflectionOpacity * 0.35)
          ..imageFilter = blur
          ..filterQuality = FilterQuality.medium,
      );
    }

    // 4. Holographic foil: rainbow bands whose angle and phase follow the
    // tilt, strongest near the light.
    if (hologram) {
      final double angle = math.pi / 5 + l.dx * 0.45 - l.dy * 0.2;
      final Offset axis = Offset(math.cos(angle), math.sin(angle));
      final double period = diagonal * 0.55;
      final Offset start =
          rect.center -
          axis * (period / 2) +
          axis * ((l.dx + l.dy) * period * 0.6);
      canvas.saveLayer(rect, Paint()..blendMode = BlendMode.overlay);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            start,
            start + axis * period,
            _foil,
            _evenStops(_foil.length),
            TileMode.mirror,
          ),
      );
      // Mask the foil so it blooms around the light and fades elsewhere.
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            lightPoint(size),
            diagonal * 0.75,
            <Color>[
              Color.fromRGBO(0, 0, 0, style.hologramStrength),
              Color.fromRGBO(0, 0, 0, style.hologramStrength * 0.35),
              Color.fromRGBO(0, 0, 0, style.hologramStrength * 0.15),
            ],
            const <double>[0, 0.55, 1],
          ),
      );
      canvas.restore();
    }

    // 5. Curvature: corners fall off slightly, away from the light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center - Offset(l.dx * w * 0.12, l.dy * h * 0.12),
          diagonal * 0.62,
          const <Color>[
            Color(0x00000000),
            Color(0x00000000),
            Color(0x30000000),
          ],
          const <double>[0, 0.55, 1],
        ),
    );

    // 6. Broad soft light following the light position.
    final Color specular = style.specular;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          lightPoint(size),
          diagonal * 0.7,
          <Color>[
            specular.withValues(alpha: style.lightStrength),
            specular.withValues(alpha: style.lightStrength * 0.35),
            specular.withValues(alpha: 0),
          ],
          const <double>[0, 0.35, 1],
        ),
    );

    // 7. Sharp specular streaks that sweep faster than the light, like a
    // window reflected in the metal.
    final double streakAngle = -math.pi / 3 + l.dx * 0.12;
    final Offset normal = Offset(
      math.cos(streakAngle + math.pi / 2),
      math.sin(streakAngle + math.pi / 2),
    );
    final double travel = (l.dx * 0.8 + l.dy * 0.35) * diagonal * 0.55;
    _streak(
      canvas,
      rect,
      rect.center + normal * travel,
      normal,
      diagonal * 0.2,
      specular,
      style.streakStrength,
    );
    _streak(
      canvas,
      rect,
      rect.center + normal * (travel - diagonal * 0.2),
      normal,
      diagonal * 0.07,
      specular,
      style.streakStrength * 0.5,
    );
  }

  void _streak(
    Canvas canvas,
    Rect rect,
    Offset center,
    Offset normal,
    double halfWidth,
    Color color,
    double strength,
  ) {
    final Color clear = color.withValues(alpha: 0);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.linear(
          center - normal * halfWidth,
          center + normal * halfWidth,
          <Color>[
            clear,
            color.withValues(alpha: strength * 0.12),
            color.withValues(alpha: strength * 0.55),
            color.withValues(alpha: strength),
            color.withValues(alpha: strength * 0.55),
            color.withValues(alpha: strength * 0.12),
            clear,
          ],
          const <double>[0, 0.3, 0.45, 0.5, 0.55, 0.7, 1],
        ),
    );
  }

  static List<double> _evenStops(int count) => <double>[
    for (int i = 0; i < count; i++) i / (count - 1),
  ];

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) {
    return oldDelegate.motion != motion ||
        oldDelegate.style != style ||
        oldDelegate.hologram != hologram ||
        oldDelegate.brushed != brushed ||
        oldDelegate.texture != texture ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.reflection != reflection ||
        oldDelegate.reflectionOpacity != reflectionOpacity;
  }
}

/// Paints a thin beveled rim that is bright on the side facing the light.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.motion,
    required this.borderRadius,
    required this.style,
  }) : super(repaint: motion);

  /// Light source.
  final _CardMotion motion;

  /// Card corners.
  final BorderRadius borderRadius;

  /// Finish colors.
  final _FinishStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final Offset l = motion.light;
    final Offset lightPoint = Offset(
      (l.dx + 1) / 2 * size.width,
      (l.dy + 1) / 2 * size.height,
    );
    final Offset opposite = rect.center * 2 - lightPoint;
    final RRect rrect = borderRadius.toRRect(rect.deflate(0.75));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          lightPoint,
          opposite,
          <Color>[
            style.specular.withValues(alpha: 0.85),
            style.specular.withValues(alpha: 0.15),
            const Color(0x40000000),
          ],
          const <double>[0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _RimPainter oldDelegate) {
    return oldDelegate.motion != motion ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.style != style;
  }
}
