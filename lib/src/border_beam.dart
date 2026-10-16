// BorderBeam is a Flutter port of "Border Beam" (https://libraries.dev/beam)
// by Jakub Antalik, released under the MIT license.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// The visual style of a [BorderBeam].
enum BorderBeamStyle {
  /// A soft rainbow arc that rotates around the border. This is the
  /// default. It suits cards and panels; with a pill shaped
  /// `borderRadius` it also suits small buttons and chips.
  beam,

  /// A comet of light that travels left to right along the bottom edge.
  /// It suits text inputs, search bars and composers.
  line,

  /// A multicolor border that breathes in place without rotating.
  pulse,
}

/// The built-in color palettes of a [BorderBeam].
enum BorderBeamPalette {
  /// Pink, blue, green, teal, violet, orange, magenta and purple. This is
  /// the default rainbow look.
  colorful,

  /// Cool blues and violets.
  ocean,

  /// Warm reds, oranges and ambers.
  sunset,

  /// Neutral greys. Layer opacities are halved for every style except
  /// [BorderBeamStyle.line] so the glow stays subtle.
  mono,
}

/// An animated rainbow glow that rides the border of any card, button or
/// input.
///
/// ```dart
/// BorderBeam(
///   active: isStreaming,
///   borderRadius: BorderRadius.circular(16),
///   child: Card(
///     shape: RoundedRectangleBorder(
///       borderRadius: BorderRadius.circular(16),
///     ),
///     child: const Padding(
///       padding: EdgeInsets.all(16),
///       child: Text('Thinking...'),
///     ),
///   ),
/// )
/// ```
///
/// Use it in AI interfaces to show that an agent is working, streaming or
/// thinking. Pick a [style]: [BorderBeamStyle.beam] (a rotating arc, the
/// default), [BorderBeamStyle.line] (a comet along the bottom edge, for
/// inputs) or [BorderBeamStyle.pulse] (a multicolor border that breathes
/// in place).
///
/// The light is built from soft radial color spots ([palette] or
/// [colors]) with a slow hue drift on top, and by default it lives
/// strictly on the border: every layer is clipped to a ring of
/// [borderWidth] (at least 1.5 pixels) just inside the rounded rectangle
/// given by [borderRadius]. Nothing is painted outside the widget's
/// bounds or deeper inside the child. Set [innerGlow] to add the soft
/// inner light of the original Border Beam, which fades about 28 pixels
/// inward from the edges. Give [borderRadius] the same rounding as the
/// child's own shape so the ring lines up with it. The child is never
/// clipped or resized; the effect is painted on top of it.
///
/// Toggle [active] to fade the effect in (600 milliseconds) or out (500
/// milliseconds). The motion keeps running during the fade out, and
/// [onActivated] or [onDeactivated] fire once the fade completes. When
/// the effect is fully faded out no frames are scheduled. The widget
/// starts fully visible when it is first built with [active] set to true.
///
/// All layers are decorative: they ignore pointers and add no semantics,
/// so the child's own semantics and hit testing are untouched.
///
/// Under reduced motion, or when [enabled] is false, the effect renders a
/// static frame (the beam arc rests on the top right corner, the line
/// rests in the middle, the pulse shows its average shape) and
/// no frames are scheduled. Toggling [active] then shows or hides the
/// effect instantly, and the callbacks still fire.
class BorderBeam extends StatefulWidget {
  /// Creates an animated border beam around [child].
  const BorderBeam({
    super.key,
    required this.child,
    this.style = BorderBeamStyle.beam,
    this.palette = BorderBeamPalette.colorful,
    this.colors,
    this.brightness,
    this.active = true,
    this.onActivated,
    this.onDeactivated,
    this.strength = 1.0,
    this.duration,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderWidth = 1.5,
    this.innerGlow = false,
    this.hueRange = 30.0,
    this.staticColors = false,
    this.enabled = true,
  }) : assert(
         strength >= 0 && strength <= 1,
         'strength must be between 0 and 1',
       ),
       assert(borderWidth >= 0, 'borderWidth must not be negative'),
       assert(
         hueRange >= 0 && hueRange <= 180,
         'hueRange must be between 0 and 180 degrees',
       ),
       assert(
         colors == null || colors.length > 0,
         'colors must not be empty; pass null to use the palette',
       );

  /// The widget the beam rides on, typically a card, button or input.
  final Widget child;

  /// The visual style. Defaults to [BorderBeamStyle.beam].
  final BorderBeamStyle style;

  /// The built-in palette used when [colors] is null. Defaults to
  /// [BorderBeamPalette.colorful].
  final BorderBeamPalette palette;

  /// Optional custom colors that replace [palette]. The effect uses nine
  /// color spots; the list is repeated in order to fill them, so one to
  /// nine colors all work.
  final List<Color>? colors;

  /// Selects the dark or light tuning. Dark tuning uses white highlights
  /// for dark surfaces; light tuning uses dark highlights and different
  /// opacities for light surfaces. Defaults to the brightness of the
  /// ambient [Theme].
  final Brightness? brightness;

  /// Whether the effect is shown. Changing it fades the effect in over 600
  /// milliseconds or out over 500 milliseconds. Defaults to true.
  final bool active;

  /// Called when a fade in triggered by [active] becoming true completes.
  final VoidCallback? onActivated;

  /// Called when a fade out triggered by [active] becoming false
  /// completes. No frames are scheduled after that until [active] becomes
  /// true again.
  final VoidCallback? onDeactivated;

  /// Overall intensity from 0 (invisible) to 1 (full). Multiplies the
  /// opacity of every layer. Defaults to 1.
  final double strength;

  /// Length of one motion cycle: one turn of the beam, one pass of the
  /// line, or one breathing cycle of the pulse. Defaults to
  /// [defaultDurationFor] the current [style] when null.
  final Duration? duration;

  /// Rounding of the border the effect follows. Defaults to a 16 pixel
  /// circular radius. Use a large radius such as
  /// `BorderRadius.circular(999)` for pill shaped buttons.
  final BorderRadius borderRadius;

  /// Width of the border ring the light rides on. Defaults to 1.5, a
  /// little thicker than the 1 pixel of the original Border Beam so the
  /// ring reads clearly without the inner glow. When [innerGlow] is false
  /// the ring is never thinner than 1.5 pixels. 0 hides the crisp stroke
  /// and keeps only the soft bloom on the ring.
  final double borderWidth;

  /// When true, adds the soft inner light that fades about 28 pixels
  /// inward from the edges, as in the original Border Beam, and uses its
  /// original opacities. Defaults to false, so the effect stays strictly
  /// on the border ring and the stroke is brightened to compensate.
  final bool innerGlow;

  /// How far, in degrees, the hue drifts back and forth for the beam and
  /// line styles. Ignored by pulse, which cycles through all hues.
  /// Defaults to 30.
  final double hueRange;

  /// When true the colors never drift in hue. Defaults to false.
  final bool staticColors;

  /// When false the effect never animates and renders a static frame, as
  /// under reduced motion. Defaults to true.
  final bool enabled;

  /// The default motion cycle length for [style]: 1960 milliseconds for
  /// [BorderBeamStyle.beam], 3100 milliseconds for [BorderBeamStyle.line]
  /// and 2300 milliseconds for [BorderBeamStyle.pulse].
  static Duration defaultDurationFor(BorderBeamStyle style) {
    return switch (style) {
      BorderBeamStyle.beam => const Duration(milliseconds: 1960),
      BorderBeamStyle.line => const Duration(milliseconds: 3100),
      BorderBeamStyle.pulse => const Duration(milliseconds: 2300),
    };
  }

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam> with TickerProviderStateMixin {
  /// Fade in duration when [BorderBeam.active] becomes true.
  static const Duration _fadeInDuration = Duration(milliseconds: 600);

  /// Fade out duration when [BorderBeam.active] becomes false.
  static const Duration _fadeOutDuration = Duration(milliseconds: 500);

  late final AnimationController _fadeController;
  late final CurvedAnimation _fade;
  late final Ticker _ticker;
  final _BeamClock _clock = _BeamClock();
  Duration _lastElapsed = Duration.zero;

  /// The fade target currently being animated towards, if any.
  double? _fadeTarget;

  /// Cached reduce-motion flag, refreshed in [didChangeDependencies].
  bool _reducedMotion = false;

  bool get _canAnimate => widget.enabled && !_reducedMotion;

  double get _cycleSeconds {
    final Duration d =
        widget.duration ?? BorderBeam.defaultDurationFor(widget.style);
    return math.max(d.inMicroseconds, 1) / Duration.microsecondsPerSecond;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      value: widget.active ? 1.0 : 0.0,
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.ease,
      reverseCurve: Curves.ease.flipped,
    );
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _syncActive();
  }

  @override
  void didUpdateWidget(BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        widget.enabled != oldWidget.enabled) {
      _syncActive();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _fadeController.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final double dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _clock.advance(dt, _cycleSeconds);
  }

  /// Moves the fade towards the state requested by [BorderBeam.active].
  void _syncActive() {
    final bool activate = widget.active;
    final double target = activate ? 1.0 : 0.0;
    if (!_canAnimate) {
      _fadeTarget = null;
      if (_fadeController.isAnimating || _fadeController.value != target) {
        // Setting the value stops any running fade without completing it.
        _fadeController.value = target;
        _notifyAfterFrame(activate);
      }
    } else if (_fadeController.value != target &&
        !(_fadeController.isAnimating && _fadeTarget == target)) {
      _fadeTarget = target;
      final TickerFuture fade = activate
          ? _fadeController.forward()
          : _fadeController.reverse();
      fade.then((_) => _onFadeDone(activate));
    }
    _syncMotion();
  }

  /// Starts the motion ticker while something is visible and stops it
  /// otherwise.
  void _syncMotion() {
    final bool run =
        _canAnimate && (widget.active || _fadeController.value > 0.0);
    if (run && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onFadeDone(bool activated) {
    _fadeTarget = null;
    if (!mounted) return;
    _syncMotion();
    if (widget.active != activated) return;
    if (activated) {
      widget.onActivated?.call();
    } else {
      widget.onDeactivated?.call();
    }
  }

  void _notifyAfterFrame(bool activated) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.active != activated) return;
      if (activated) {
        widget.onActivated?.call();
      } else {
        widget.onDeactivated?.call();
      }
    });
  }

  _BeamLook _look(BuildContext context) {
    final Brightness brightness =
        widget.brightness ?? Theme.of(context).brightness;
    final List<Color>? custom = widget.colors;
    List<Color> cycled(int count, List<Color> fallback) {
      if (custom == null || custom.isEmpty) return fallback;
      return List<Color>.generate(
        count,
        (int i) => custom[i % custom.length],
        growable: false,
      );
    }

    final List<Color> slots = cycled(9, _paletteSlots(widget.palette));
    final bool colorful = widget.palette == BorderBeamPalette.colorful;
    return _BeamLook(
      style: widget.style,
      dark: brightness == Brightness.dark,
      mono: custom == null && widget.palette == BorderBeamPalette.mono,
      slots: slots,
      lineColors: cycled(9, colorful ? _lineColorful : slots),
      streakColors: cycled(7, colorful ? _streakColorful : slots.sublist(0, 7)),
      strength: widget.strength,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      innerGlow: widget.innerGlow,
      hueRange: widget.hueRange,
      staticColors: widget.staticColors,
    );
  }

  Widget _layer(_BeamLook look) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _BorderBeamPainter(
              clock: _clock,
              fade: _fade,
              look: look,
              animate: _canAnimate,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _BeamLook look = _look(context);
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[widget.child, _layer(look)],
    );
  }
}

/// Elapsed motion time shared by the painters of one [BorderBeam].
class _BeamClock extends ChangeNotifier {
  /// Wall clock seconds of motion, used for the hue drift.
  double seconds = 0.0;

  /// Motion time measured in cycles of the widget's duration. Using cycles
  /// keeps the motion continuous when the duration changes.
  double cycles = 0.0;

  void advance(double dt, double cycleSeconds) {
    seconds += dt;
    cycles += dt / cycleSeconds;
    notifyListeners();
  }
}

/// Resolved, immutable visual configuration shared by the painters.
@immutable
class _BeamLook {
  const _BeamLook({
    required this.style,
    required this.dark,
    required this.mono,
    required this.slots,
    required this.lineColors,
    required this.streakColors,
    required this.strength,
    required this.borderRadius,
    required this.borderWidth,
    required this.innerGlow,
    required this.hueRange,
    required this.staticColors,
  });

  final BorderBeamStyle style;
  final bool dark;
  final bool mono;

  /// The nine palette slot colors.
  final List<Color> slots;

  /// The nine comet colors of the line style.
  final List<Color> lineColors;

  /// The seven streak colors of the line style bloom.
  final List<Color> streakColors;
  final double strength;
  final BorderRadius borderRadius;
  final double borderWidth;
  final bool innerGlow;
  final double hueRange;
  final bool staticColors;

  /// Width of the ring every layer is clipped to when [innerGlow] is off.
  double get ringWidth => math.max(borderWidth, 1.5);

  @override
  bool operator ==(Object other) {
    return other is _BeamLook &&
        other.style == style &&
        other.dark == dark &&
        other.mono == mono &&
        listEquals(other.slots, slots) &&
        listEquals(other.lineColors, lineColors) &&
        listEquals(other.streakColors, streakColors) &&
        other.strength == strength &&
        other.borderRadius == borderRadius &&
        other.borderWidth == borderWidth &&
        other.innerGlow == innerGlow &&
        other.hueRange == hueRange &&
        other.staticColors == staticColors;
  }

  @override
  int get hashCode => Object.hash(
    style,
    dark,
    mono,
    Object.hashAll(slots),
    Object.hashAll(lineColors),
    Object.hashAll(streakColors),
    strength,
    borderRadius,
    borderWidth,
    innerGlow,
    hueRange,
    staticColors,
  );
}

// ---------------------------------------------------------------------------
// Palettes and spot layouts. Radii are in pixels for a 350 x 140 box and are
// scaled per axis for other sizes.
// ---------------------------------------------------------------------------

List<Color> _paletteSlots(BorderBeamPalette palette) {
  return switch (palette) {
    BorderBeamPalette.colorful => _colorful,
    BorderBeamPalette.ocean => _ocean,
    BorderBeamPalette.sunset => _sunset,
    BorderBeamPalette.mono => _mono,
  };
}

const List<Color> _colorful = <Color>[
  Color.fromARGB(255, 255, 50, 100),
  Color.fromARGB(255, 40, 140, 255),
  Color.fromARGB(255, 50, 200, 80),
  Color.fromARGB(255, 30, 185, 170),
  Color.fromARGB(255, 100, 70, 255),
  Color.fromARGB(255, 40, 140, 255),
  Color.fromARGB(255, 255, 120, 40),
  Color.fromARGB(255, 240, 50, 180),
  Color.fromARGB(255, 180, 40, 240),
];

const List<Color> _ocean = <Color>[
  Color.fromARGB(255, 100, 80, 220),
  Color.fromARGB(255, 60, 120, 255),
  Color.fromARGB(255, 80, 100, 200),
  Color.fromARGB(255, 50, 140, 220),
  Color.fromARGB(255, 120, 80, 255),
  Color.fromARGB(255, 70, 130, 255),
  Color.fromARGB(255, 140, 100, 240),
  Color.fromARGB(255, 90, 110, 230),
  Color.fromARGB(255, 130, 70, 255),
];

const List<Color> _sunset = <Color>[
  Color.fromARGB(255, 255, 80, 50),
  Color.fromARGB(255, 255, 160, 40),
  Color.fromARGB(255, 255, 120, 60),
  Color.fromARGB(255, 255, 200, 50),
  Color.fromARGB(255, 255, 100, 80),
  Color.fromARGB(255, 255, 180, 60),
  Color.fromARGB(255, 255, 60, 60),
  Color.fromARGB(255, 255, 140, 50),
  Color.fromARGB(255, 255, 90, 70),
];

const List<Color> _mono = <Color>[
  Color.fromARGB(255, 130, 130, 130),
  Color.fromARGB(255, 138, 138, 138),
  Color.fromARGB(255, 145, 145, 145),
  Color.fromARGB(255, 153, 153, 153),
  Color.fromARGB(255, 160, 160, 160),
  Color.fromARGB(255, 168, 168, 168),
  Color.fromARGB(255, 175, 175, 175),
  Color.fromARGB(255, 183, 183, 183),
  Color.fromARGB(255, 190, 190, 190),
];

const List<Color> _lineColorful = <Color>[
  Color.fromARGB(255, 255, 50, 100),
  Color.fromARGB(255, 40, 180, 220),
  Color.fromARGB(255, 50, 200, 80),
  Color.fromARGB(255, 180, 40, 240),
  Color.fromARGB(255, 255, 160, 30),
  Color.fromARGB(255, 100, 70, 255),
  Color.fromARGB(255, 40, 140, 255),
  Color.fromARGB(255, 240, 50, 180),
  Color.fromARGB(255, 30, 185, 170),
];

const List<Color> _streakColorful = <Color>[
  Color.fromARGB(255, 255, 60, 80),
  Color.fromARGB(255, 40, 190, 180),
  Color.fromARGB(255, 100, 70, 255),
  Color.fromARGB(255, 255, 170, 40),
  Color.fromARGB(255, 50, 200, 100),
  Color.fromARGB(255, 200, 50, 240),
  Color.fromARGB(255, 40, 140, 255),
];

/// Quadrants used by the breathing opacity oscillators.
const int _tl = 0;
const int _tr = 1;
const int _bl = 2;
const int _br = 3;

/// A radial color spot positioned relative to a box.
@immutable
class _Spot {
  const _Spot(
    this.slot,
    this.x,
    this.y,
    this.rx,
    this.ry, {
    this.region = 0,
    this.quadrant = _tl,
  });

  /// Index into the palette slots.
  final int slot;

  /// Center as a fraction of the box width and height.
  final double x;
  final double y;

  /// Radii in pixels for a 350 x 140 box.
  final double rx;
  final double ry;

  /// Breathing region (0, 1 or 2).
  final int region;

  /// Breathing quadrant.
  final int quadrant;
}

const List<_Spot> _fieldSpots = <_Spot>[
  _Spot(0, 0.33, -0.074, 70, 40, region: 0, quadrant: _tl),
  _Spot(1, 0.12, -0.05, 60, 35, region: 1, quadrant: _tl),
  _Spot(2, 0.021, 0.683, 40, 70, region: 2, quadrant: _bl),
  _Spot(3, 0.021, 0.683, 20, 35, region: 0, quadrant: _bl),
  _Spot(4, 0.744, 1.0, 180, 32, region: 1, quadrant: _br),
  _Spot(5, 0.55, 1.0, 85, 26, region: 2, quadrant: _br),
  _Spot(6, 0.939, 0.0, 74, 32, region: 0, quadrant: _tr),
  _Spot(7, 1.0, 0.271, 26, 42, region: 1, quadrant: _tr),
  _Spot(8, 1.0, 0.271, 52, 48, region: 2, quadrant: _tr),
];

const List<_Spot> _pulseInnerSpots = <_Spot>[
  _Spot(0, 0.33, -0.074, 65, 35, region: 0, quadrant: _tl),
  _Spot(1, 0.12, -0.05, 55, 30, region: 1, quadrant: _tl),
  _Spot(2, 0.021, 0.683, 35, 65, region: 2, quadrant: _bl),
  _Spot(3, 0.021, 0.683, 15, 30, region: 0, quadrant: _bl),
  _Spot(4, 0.744, 1.0, 173, 28, region: 1, quadrant: _br),
  _Spot(5, 0.55, 1.0, 80, 22, region: 2, quadrant: _br),
  _Spot(6, 0.939, 0.0, 69, 28, region: 0, quadrant: _tr),
  _Spot(7, 1.0, 0.271, 22, 38, region: 1, quadrant: _tr),
  _Spot(8, 1.0, 0.271, 47, 44, region: 2, quadrant: _tr),
];

const List<_Spot> _pulseBloomSpots = <_Spot>[
  _Spot(0, 0.33, -0.074, 84, 48, region: 0, quadrant: _tl),
  _Spot(1, 0.12, -0.05, 72, 42, region: 1, quadrant: _tl),
  _Spot(2, 0.021, 0.683, 48, 84, region: 2, quadrant: _bl),
  _Spot(4, 0.744, 1.0, 216, 38, region: 1, quadrant: _br),
  _Spot(5, 0.55, 1.0, 102, 31, region: 2, quadrant: _br),
  _Spot(6, 0.939, 0.0, 89, 38, region: 0, quadrant: _tr),
  _Spot(8, 1.0, 0.271, 62, 58, region: 2, quadrant: _tr),
];

/// A comet color spot of the line style, offset from the comet center.
@immutable
class _LineSpot {
  const _LineSpot(
    this.rx,
    this.ry,
    this.offset,
    this.dy,
    this.innerRx,
    this.innerRy,
    this.innerAlpha,
  );

  final double rx;
  final double ry;
  final double offset;
  final double dy;
  final double innerRx;
  final double innerRy;
  final double innerAlpha;
}

const List<_LineSpot> _lineSpots = <_LineSpot>[
  _LineSpot(36, 36, 0, 2, 33, 30, 0.52),
  _LineSpot(30, 32, 39, 0, 27, 28, 0.46),
  _LineSpot(33, 28, -36, 2, 30, 24, 0.48),
  _LineSpot(29, 34, -54, 0, 25, 29, 0.42),
  _LineSpot(27, 30, 51, -1, 24, 26, 0.44),
  _LineSpot(36, 24, 21, 1, 31, 20, 0.50),
  _LineSpot(30, 22, -21, 0, 26, 18, 0.40),
  _LineSpot(25, 28, 66, 1, 21, 24, 0.45),
  _LineSpot(23, 30, -66, -1, 18, 26, 0.43),
];

/// A vertical light streak of the line style bloom.
@immutable
class _Streak {
  const _Streak(this.x, this.rx, this.ry, this.dy, this.kind);

  /// Center as a fraction of the box width.
  final double x;
  final double rx;
  final double ry;
  final double dy;

  /// Height modulator: 0 spike, 1 spike2, 2 (2 - spike), 3 (2 - spike2).
  final int kind;
}

const List<_Streak> _streaks = <_Streak>[
  _Streak(0.08, 0.8, 92, -2, 0),
  _Streak(0.22, 10, 35, -3, 1),
  _Streak(0.36, 2, 72, -4, 2),
  _Streak(0.50, 14, 28, -2, 1),
  _Streak(0.64, 1.2, 85, -3, 3),
  _Streak(0.78, 7, 45, -4, 0),
  _Streak(0.92, 0.6, 60, -2, 2),
];

const List<double> _lineTimes = <double>[
  0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, //
];
const List<double> _lineX = <double>[
  0.06, 0.15, 0.25, 0.35, 0.44, 0.50, 0.56, 0.65, 0.75, 0.85, 0.94, //
];
const List<double> _lineW = <double>[
  0.5, 0.8, 1.1, 1.3, 1.45, 1.5, 1.45, 1.3, 1.1, 0.8, 0.5, //
];
const List<double> _breatheTimes = <double>[0.0, 0.25, 0.55, 0.80, 1.0];
const List<double> _breatheValues = <double>[0.8, 1.25, 0.85, 1.3, 0.8];
const List<double> _quarterTimes = <double>[0.0, 0.25, 0.5, 0.75, 1.0];
const List<double> _spikeValues = <double>[0.8, 1.3, 0.9, 1.4, 0.8];
const List<double> _spike2Values = <double>[1.2, 0.7, 1.4, 0.8, 1.2];

// Conic gradient stops, in turns measured clockwise from 12 o'clock.
const List<double> _hotspotStops = <double>[
  0.0, 0.54, 0.57, 0.60, 0.63, 0.66, 0.69, 0.72, 0.75, 0.78, 1.0, //
];
const List<double> _hotspotDark = <double>[
  0, 0, 0.1, 0.3, 0.6, 0.75, 0.6, 0.3, 0.1, 0, 0, //
];
const List<double> _hotspotLight = <double>[
  0, 0, 0.08, 0.2, 0.4, 0.55, 0.4, 0.2, 0.08, 0, 0, //
];
const List<double> _maskStops = <double>[
  0.0, 0.30, 0.36, 0.44, 0.52, 0.80, 0.86, 0.92, 0.95, 1.0, //
];
const List<double> _maskStopsCompact = <double>[
  0.0, 0.22, 0.28, 0.36, 0.46, 0.82, 0.88, 0.94, 0.97, 1.0, //
];
const List<double> _maskAlphas = <double>[
  0, 0, 0.1, 0.35, 1, 1, 0.35, 0.1, 0, 0, //
];
const List<double> _maskAlphasCompact = <double>[
  0, 0, 0.12, 0.4, 1, 1, 0.4, 0.12, 0, 0, //
];
const List<double> _spikeStops = <double>[
  0.0, 0.58, 0.62, 0.65, 0.67, 0.69, 0.70, 0.705, 0.715, 0.73, 0.75, //
  0.78, 0.82, 1.0,
];
const List<double> _spikeAlphas = <double>[
  0, 0, 0.03, 0.08, 0.2, 0.45, 0.85, 0.85, 0.45, 0.2, 0.08, 0.03, 0, 0, //
];

/// Opacity presets of the three layers of a style, plus color tuning.
@immutable
class _Preset {
  const _Preset(
    this.stroke,
    this.inner,
    this.bloom, {
    this.saturation = 1.0,
    this.brightness = 1.0,
  });

  final double stroke;
  final double inner;
  final double bloom;
  final double saturation;
  final double brightness;
}

/// Tuning of the breathing oscillators of the pulse style.
@immutable
class _Breathing {
  const _Breathing(
    this.sp,
    this.dr,
    this.op,
    this.gh,
    this.bs,
    this.ss,
    this.ghs,
  );

  /// Size swing.
  final double sp;

  /// Drift distance in pixels.
  final double dr;

  /// Opacity swing.
  final double op;

  /// Global height swing.
  final double gh;

  /// Base period of the drift and opacity oscillators, in seconds.
  final double bs;

  /// Base period of the size oscillators, in seconds.
  final double ss;

  /// Period of the global height oscillator, in seconds.
  final double ghs;
}

const _Breathing _pulseDark = _Breathing(0.28, 33, 0.48, 0.34, 1.9, 2.6, 2.4);
const _Breathing _pulseLight = _Breathing(0.28, 40, 0.45, 0.22, 2.6, 4.6, 5.5);

/// Reference cycle length, in seconds, the breathing periods are tuned for.
const double _breathReference = 2.3;

class _BorderBeamPainter extends CustomPainter {
  _BorderBeamPainter({
    required this.clock,
    required this.fade,
    required this.look,
    required this.animate,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, fade]));

  /// Shared motion time.
  final _BeamClock clock;

  /// Fade in and out progress, 0 to 1.
  final Animation<double> fade;

  /// Resolved visual configuration.
  final _BeamLook look;

  /// When false a static frame is painted.
  final bool animate;

  /// Beam arc angle at rest, in turns: puts the arc on the top right.
  static const double staticBeamTurns = 0.465;

  // Scratch state reused across frames to limit allocations.
  final Paint _fill = Paint();
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;
  final Float64List _bw = Float64List(3);
  final Float64List _bh = Float64List(3);
  final Float64List _bx = Float64List(3);
  final Float64List _by = Float64List(3);
  final Float64List _bop = Float64List(4);
  double _gh = 1.0;

  /// The current beam angle in turns (0 to 1), measured clockwise.
  double get beamTurns =>
      animate ? clock.cycles - clock.cycles.floorToDouble() : staticBeamTurns;

  /// The current progress of the line comet within its cycle (0 to 1).
  double get lineProgress =>
      animate ? clock.cycles - clock.cycles.floorToDouble() : 0.5;

  /// The current fade value, 0 to 1.
  double get fadeValue => fade.value;

  @override
  void paint(Canvas canvas, Size size) {
    final double f = fade.value;
    if (f <= 0.0 || size.isEmpty) return;
    switch (look.style) {
      case BorderBeamStyle.beam:
        _paintBeam(canvas, size, f);
      case BorderBeamStyle.line:
        _paintLine(canvas, size, f);
      case BorderBeamStyle.pulse:
        _paintPulse(canvas, size, f);
    }
  }

  // -------------------------------------------------------------------------
  // Shared helpers
  // -------------------------------------------------------------------------

  double _opacity(double fadeValue, double preset, {bool halve = false}) {
    final double mono = halve && look.mono ? 0.5 : 1.0;
    return (fadeValue * preset * look.strength * mono).clamp(0.0, 1.0);
  }

  /// Whether the hue filter is off: [BorderBeam.staticColors], or the mono
  /// palette, which forces static colors.
  bool get _colorsStatic => look.staticColors || look.mono;

  /// Hue that ping-pongs between -hueRange and +hueRange over 12 seconds.
  double _driftHue() {
    if (!animate || _colorsStatic || look.hueRange == 0) return 0.0;
    final double p = (clock.seconds / 12.0) % 1.0;
    final double r = look.hueRange;
    if (p < 0.5) {
      return -r + 2 * r * Curves.easeInOut.transform(p * 2);
    }
    return r - 2 * r * Curves.easeInOut.transform((p - 0.5) * 2);
  }

  /// Hue that turns continuously through all colors over [period] seconds.
  double _spinHue(double period) {
    if (!animate || _colorsStatic) return 0.0;
    return ((clock.seconds / period) % 1.0) * 360.0;
  }

  /// A layer paint applying the CSS filter chain
  /// `hue-rotate() saturate() brightness()` and an opacity.
  Paint _layerPaint(
    double opacity,
    double hueDegrees,
    double saturation,
    double brightness, {
    double blur = 0.0,
  }) {
    final Paint paint = Paint()
      ..colorFilter = ColorFilter.matrix(
        _colorMatrix(hueDegrees, saturation, brightness, opacity),
      );
    if (blur > 0) {
      paint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    }
    return paint;
  }

  static List<double> _colorMatrix(
    double hueDegrees,
    double saturation,
    double brightness,
    double opacity,
  ) {
    final double a = hueDegrees * math.pi / 180.0;
    final double c = math.cos(a);
    final double s = math.sin(a);
    // W3C hue-rotate matrix.
    final List<double> h = <double>[
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
    ];
    // W3C saturate matrix.
    final double v = saturation;
    final List<double> st = <double>[
      0.213 + 0.787 * v,
      0.715 - 0.715 * v,
      0.072 - 0.072 * v,
      0.213 - 0.213 * v,
      0.715 + 0.285 * v,
      0.072 - 0.072 * v,
      0.213 - 0.213 * v,
      0.715 - 0.715 * v,
      0.072 + 0.928 * v,
    ];
    final List<double> m = List<double>.filled(20, 0.0);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        double sum = 0.0;
        for (int k = 0; k < 3; k++) {
          sum += st[i * 3 + k] * h[k * 3 + j];
        }
        m[i * 5 + j] = brightness * sum;
      }
    }
    m[18] = opacity;
    return m;
  }

  /// Fills an elliptical radial gradient centered at [center]. The gradient
  /// runs from the first color at the center to the last at the edge. The
  /// draw covers [cover], or just the ellipse bounds when null.
  void _ellipse(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    List<Color> colors, {
    List<double>? stops,
    BlendMode blendMode = BlendMode.srcOver,
    Rect? cover,
  }) {
    if (rx <= 0.01 || ry <= 0.01) {
      if (cover != null && blendMode == BlendMode.dstIn) {
        canvas.drawRect(cover, Paint()..blendMode = BlendMode.clear);
      }
      return;
    }
    _matrix
      ..[0] = rx
      ..[5] = ry
      ..[12] = center.dx
      ..[13] = center.dy;
    _fill
      ..blendMode = blendMode
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        colors,
        stops,
        TileMode.clamp,
        _matrix,
      );
    canvas.drawRect(
      cover ?? Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      _fill,
    );
  }

  /// A solid-to-transparent spot of [color] at [alpha].
  void _spot(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0) return;
    _ellipse(canvas, center, rx, ry, <Color>[
      color.withValues(alpha: color.a * alpha.clamp(0.0, 1.0)),
      color.withValues(alpha: 0.0),
    ]);
  }

  /// A conic gradient shader rotated by [turns], measured clockwise from 12
  /// o'clock like a CSS `conic-gradient(from ...)`.
  static Shader _conic(
    Rect rect,
    double turns,
    Color color,
    List<double> stops,
    List<double> alphas,
  ) {
    return SweepGradient(
      colors: <Color>[
        for (final double a in alphas) color.withValues(alpha: a),
      ],
      stops: stops,
      transform: GradientRotation(turns * 2 * math.pi - math.pi / 2),
    ).createShader(rect);
  }

  /// A path covering only the border ring.
  static Path _ring(RRect outer, RRect inner) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
  }

  /// Keeps a band along the inside edges that fades linearly to
  /// transparent 28 pixels inward; everything deeper inside is erased. The
  /// mask is the union of a vertical and a horizontal edge gradient.
  static void _edgeBand(Canvas canvas, Rect box) {
    canvas.saveLayer(box, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawRect(
      box,
      Paint()..shader = _bandShader(box.topCenter, box.bottomCenter),
    );
    canvas.drawRect(
      box,
      Paint()..shader = _bandShader(box.centerLeft, box.centerRight),
    );
    canvas.restore();
  }

  static Shader _bandShader(Offset from, Offset to) {
    const double band = 28.0;
    final double length = (to - from).distance;
    final double a = math.min(band / length, 1.0);
    final double b = math.max(a, 1.0 - band / length);
    return ui.Gradient.linear(
      from,
      to,
      const <Color>[
        Colors.white,
        Color(0x00FFFFFF),
        Color(0x00FFFFFF),
        Colors.white,
      ],
      <double>[0.0, a, b, 1.0],
    );
  }

  /// The filter of the stroke and inner layers of the beam and line
  /// styles: hue drift, brightness and saturation, or nothing at all when
  /// the colors are static.
  Paint _driftPaint(double opacity, double hue, double saturation) {
    return _colorsStatic
        ? _layerPaint(opacity, 0.0, 1.0, 1.0)
        : _layerPaint(
            opacity,
            hue,
            saturation,
            // Without the inner glow, light surfaces keep full color depth
            // instead of being washed out to pastels.
            look.innerGlow || look.dark ? _beamBrightness : 1.0,
          );
  }

  /// Brightness filter of the beam and line styles.
  static const double _beamBrightness = 1.3;

  /// An inset box shadow like CSS `box-shadow: inset 0 0 blur spread`.
  static void _insetShadow(
    Canvas canvas,
    RRect outer,
    double blur,
    double spread,
    Color color,
  ) {
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer.outerRect.inflate(blur * 2 + 4))
      ..addRRect(outer.deflate(spread));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
  }

  static double _keyframes(
    List<double> times,
    List<double> values,
    double p, {
    bool ease = false,
  }) {
    for (int i = 0; i < times.length - 1; i++) {
      if (p <= times[i + 1]) {
        double t = (p - times[i]) / (times[i + 1] - times[i]);
        t = t.clamp(0.0, 1.0);
        if (ease) t = Curves.easeInOut.transform(t);
        return values[i] + (values[i + 1] - values[i]) * t;
      }
    }
    return values.last;
  }

  static double _fract(double v) => v - v.floorToDouble();

  /// Per-axis scale of the spot radii relative to the 350 x 140 reference.
  static double _scaleX(Size size) => (size.width / 350.0).clamp(0.5, 2.5);
  static double _scaleY(Size size) => (size.height / 140.0).clamp(0.5, 2.5);

  RRect _outer(Rect box) => look.borderRadius.toRRect(box).scaleRadii();

  /// Inner edge of the stroke ring: [BorderBeam.borderWidth] inside
  /// [outer], or the wider border-only band when the inner glow is off.
  RRect _strokeInner(RRect outer) =>
      outer.deflate(look.innerGlow ? look.borderWidth : look.ringWidth);

  /// Clips the canvas to the widget's rounded rectangle and, unless the
  /// inner glow is on, further to the border ring band so no layer can
  /// paint deeper inside.
  void _clipToEffect(Canvas canvas, RRect outer) {
    canvas.clipRRect(outer);
    if (!look.innerGlow) {
      canvas.clipPath(_ring(outer, outer.deflate(look.ringWidth)));
    }
  }

  /// Opacity multiplier of the stroke when the inner glow is off. The
  /// original look relies on the inner glow for visibility, so the stroke
  /// is strengthened to keep the ring readable on its own: 2.5 times on
  /// dark surfaces and 5 times on light ones, where the original light
  /// opacities are very low. The result is clamped to 1.
  double get _strokeBoost => look.innerGlow ? 1.0 : (look.dark ? 2.5 : 5.0);

  /// Opacity multiplier of the bloom when the inner glow is off.
  double get _bloomBoost => look.innerGlow ? 1.0 : 1.6;

  // -------------------------------------------------------------------------
  // Beam: a rotating arc.
  // -------------------------------------------------------------------------

  void _paintBeam(Canvas canvas, Size size, double f) {
    final Rect box = Offset.zero & size;
    final RRect outer = _outer(box);
    final RRect inner = _strokeInner(outer);
    final bool dark = look.dark;
    final bool compact = size.shortestSide < 60;
    final _Preset preset = compact
        ? (dark
              ? const _Preset(0.46, 0.24, 0.38)
              : const _Preset(0.12, 0.30, 0.16))
        : (dark
              ? const _Preset(0.26, 0.42, 0.24)
              : const _Preset(0.12, 0.26, 0.34));
    final double turns = beamTurns;
    final double hue = _driftHue();
    final double sat = dark ? 1.2 : 1.5;
    final double kx = _scaleX(size);
    final double ky = _scaleY(size);
    final Color ink = dark ? Colors.white : Colors.black;
    final List<double> maskStops = compact ? _maskStopsCompact : _maskStops;
    final List<double> maskAlphas = compact ? _maskAlphasCompact : _maskAlphas;

    canvas.save();
    _clipToEffect(canvas, outer);

    // Inner glow along the edges, under the rotating mask.
    final double innerOpacity = _opacity(f, preset.inner, halve: true);
    if (look.innerGlow && innerOpacity > 0) {
      canvas.saveLayer(box, _driftPaint(innerOpacity, hue, sat));
      for (final _Spot s in _fieldSpots) {
        _spot(
          canvas,
          Offset(s.x * size.width, s.y * size.height),
          s.rx * kx * 0.9,
          s.ry * ky * 0.9,
          look.slots[s.slot],
          look.mono ? 0.225 : 0.45,
        );
      }
      _insetShadow(
        canvas,
        outer,
        compact ? 5.0 : 9.0,
        1.0,
        dark
            ? Colors.white.withValues(alpha: 0.27)
            : Colors.black.withValues(alpha: 0.14),
      );
      canvas.drawRect(
        box,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _conic(box, turns, Colors.white, maskStops, maskAlphas),
      );
      _edgeBand(canvas, box);
      canvas.restore();
    }

    // Crisp stroke on the border ring with a bright hotspot.
    final double strokeOpacity = _opacity(
      f,
      preset.stroke * _strokeBoost,
      halve: true,
    );
    if (strokeOpacity > 0 && look.borderWidth > 0) {
      canvas.saveLayer(box, _driftPaint(strokeOpacity, hue, sat));
      canvas.clipPath(_ring(outer, inner));
      for (final _Spot s in _fieldSpots) {
        _spot(
          canvas,
          Offset(s.x * size.width, s.y * size.height),
          s.rx * kx,
          s.ry * ky,
          look.slots[s.slot],
          1.0,
        );
      }
      canvas.drawRect(
        box,
        Paint()
          ..shader = _conic(
            box,
            turns,
            ink,
            _hotspotStops,
            dark ? _hotspotDark : _hotspotLight,
          ),
      );
      canvas.drawRect(
        box,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _conic(box, turns, Colors.white, maskStops, maskAlphas),
      );
      canvas.restore();
    }

    // Bloom: a narrow blurred spike on the ring.
    final double bloomOpacity = _opacity(
      f,
      preset.bloom * _bloomBoost,
      halve: true,
    );
    if (bloomOpacity > 0) {
      final double peak = dark ? 1.0 : 0.6 / 0.85;
      canvas.saveLayer(
        box,
        _layerPaint(bloomOpacity, 0.0, sat, _beamBrightness),
      );
      canvas.clipPath(
        _ring(outer, outer.deflate(math.max(look.borderWidth, 1.0))),
      );
      final Rect spread = box.inflate(24);
      canvas.saveLayer(
        spread,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      );
      canvas.drawRect(
        spread,
        Paint()
          ..shader = _conic(box, turns, ink, _spikeStops, <double>[
            for (final double a in _spikeAlphas) a * peak,
          ]),
      );
      canvas.restore();
      canvas.restore();
    }

    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Line: a comet along the bottom edge.
  // -------------------------------------------------------------------------

  void _paintLine(Canvas canvas, Size size, double f) {
    final Rect box = Offset.zero & size;
    final RRect outer = _outer(box);
    final RRect inner = _strokeInner(outer);
    final bool dark = look.dark;
    final _Preset preset = dark
        ? const _Preset(1.0, 0.7, 0.8)
        : const _Preset(0.16, 0.32, 0.30);
    final double sat = dark ? 1.2 : 1.5;
    final double hue = _driftHue();
    final double kx = (size.width / 350.0).clamp(0.5, 2.0);
    final double width = size.width;
    final double bottom = size.height;

    final double p = lineProgress;
    final double t = animate ? clock.cycles : 0.0;
    final double x = _keyframes(_lineTimes, _lineX, p) * width;
    final double w = _keyframes(_lineTimes, _lineW, p);
    final double edge = animate ? _edgeFade(p) : 1.0;
    final double h = animate
        ? _keyframes(_breatheTimes, _breatheValues, _fract(t / 1.3), ease: true)
        : 1.0;
    final double spike = animate
        ? _keyframes(_quarterTimes, _spikeValues, _fract(t / 1.33), ease: true)
        : 1.0;
    final double spike2 = animate
        ? _keyframes(_quarterTimes, _spike2Values, _fract(t / 1.7), ease: true)
        : 1.0;
    if (edge <= 0) return;

    final Offset anchor = Offset(x, bottom);
    final List<Color> maskColors = <Color>[
      Colors.white,
      Colors.white.withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.0),
    ];
    const List<double> maskStops = <double>[0.0, 0.45, 1.0];

    canvas.save();
    _clipToEffect(canvas, outer);

    // Inner glow.
    final double innerOpacity = _opacity(f, preset.inner * edge);
    if (look.innerGlow && innerOpacity > 0) {
      canvas.saveLayer(box, _driftPaint(innerOpacity, hue, sat));
      for (int i = 0; i < _lineSpots.length; i++) {
        final _LineSpot s = _lineSpots[i];
        _spot(
          canvas,
          Offset(x + s.offset * kx, bottom + s.dy),
          s.innerRx * w * kx,
          s.innerRy * h,
          look.lineColors[i],
          s.innerAlpha,
        );
      }
      _insetShadow(
        canvas,
        outer,
        9.0,
        1.0,
        dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
      );
      _ellipse(
        canvas,
        anchor,
        78 * w * kx,
        60 * h,
        maskColors,
        stops: maskStops,
        blendMode: BlendMode.dstIn,
        cover: box,
      );
      _edgeBand(canvas, box);
      canvas.restore();
    }

    // Stroke on the ring.
    final double strokeOpacity = _opacity(
      f,
      preset.stroke * _strokeBoost * edge,
    );
    if (strokeOpacity > 0 && look.borderWidth > 0) {
      canvas.saveLayer(box, _driftPaint(strokeOpacity, hue, sat));
      canvas.clipPath(_ring(outer, inner));
      for (int i = 0; i < _lineSpots.length; i++) {
        final _LineSpot s = _lineSpots[i];
        _spot(
          canvas,
          Offset(x + s.offset * kx, bottom + s.dy),
          s.rx * w * kx,
          s.ry * h,
          look.lineColors[i],
          1.0,
        );
      }
      if (dark) {
        _ellipse(
          canvas,
          Offset(x, bottom + 2),
          24 * w * kx,
          28 * h,
          <Color>[
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.30, 0.65],
        );
      } else {
        _ellipse(
          canvas,
          Offset(x, bottom + 2),
          35 * w * kx,
          28 * h,
          <Color>[
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.35, 0.70],
        );
      }
      _ellipse(
        canvas,
        anchor,
        78 * w * kx,
        60 * h,
        maskColors,
        stops: maskStops,
        blendMode: BlendMode.dstIn,
        cover: box,
      );
      canvas.restore();
    }

    // Bloom: streaks, a hot dot and an ambient glow, blurred.
    final double bloomOpacity = _opacity(f, preset.bloom * _bloomBoost * edge);
    if (bloomOpacity > 0) {
      canvas.saveLayer(
        box,
        _layerPaint(bloomOpacity, 0.0, sat, _beamBrightness),
      );
      final Rect spread = box.inflate(24);
      canvas.saveLayer(
        spread,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      );
      for (int i = 0; i < _streaks.length; i++) {
        final _Streak s = _streaks[i];
        final double m = switch (s.kind) {
          0 => spike,
          1 => spike2,
          2 => 2 - spike,
          _ => 2 - spike2,
        };
        _spot(
          canvas,
          Offset(s.x * width, bottom + s.dy),
          s.rx * kx,
          s.ry * m * h,
          look.streakColors[i],
          1.0,
        );
      }
      _ellipse(
        canvas,
        Offset(x, bottom + 1),
        21 * spike,
        15 * spike2,
        <Color>[
          Colors.white,
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.2, 0.5, 1.0],
      );
      if (dark) {
        _ellipse(
          canvas,
          anchor,
          42 * w * kx,
          40 * h,
          <Color>[
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.25, 0.55, 0.80],
        );
      } else {
        _ellipse(
          canvas,
          anchor,
          50 * w * kx,
          32 * h,
          <Color>[
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.03),
            Colors.black.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.30, 0.60, 1.0],
        );
      }
      canvas.restore();
      _ellipse(
        canvas,
        anchor,
        84 * w * kx,
        110 * h,
        <Color>[Colors.white, Colors.white.withValues(alpha: 0.0)],
        blendMode: BlendMode.dstIn,
        cover: box,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  /// Fade of the comet near the ends of its run.
  static double _edgeFade(double p) {
    if (p < 0.125) return 0.0;
    if (p < 0.325) return (p - 0.125) / 0.2;
    if (p <= 0.675) return 1.0;
    if (p < 0.875) return 1.0 - (p - 0.675) / 0.2;
    return 0.0;
  }

  // -------------------------------------------------------------------------
  // Pulse: breathing spots.
  // -------------------------------------------------------------------------

  /// Updates the breathing oscillators for the current time.
  void _breathe(_Breathing b) {
    final double t = clock.cycles * _breathReference;
    double osc(double a, double z, double period, [double delay = 0]) {
      if (!animate) return (a + z) / 2;
      return a +
          (z - a) * (1 - math.cos(2 * math.pi * (t - delay) / period)) / 2;
    }

    final double sp = b.sp;
    final double dr = b.dr;
    _bw[0] = osc(1 - sp, 1 + 1.1 * sp, 0.9 * b.ss);
    _bh[0] = osc(1 + 0.9 * sp, 1 - 0.85 * sp, 1.26 * b.ss);
    _bx[0] = osc(-dr, 0.9 * dr, 1.6 * b.bs);
    _by[0] = osc(0.55 * dr, -0.7 * dr, 1.6 * b.bs);
    _bw[1] = osc(1 + sp, 1 - 0.85 * sp, 1.1 * b.ss);
    _bh[1] = osc(1 - 0.8 * sp, 1 + 1.05 * sp, 0.81 * b.ss);
    _bx[1] = osc(0.8 * dr, -0.9 * dr, 1.88 * b.bs);
    _by[1] = osc(-dr, 0.65 * dr, 1.88 * b.bs);
    _bw[2] = osc(1 - 0.6 * sp, 1 + 1.15 * sp, 0.98 * b.ss);
    _bh[2] = osc(1 + 0.75 * sp, 1 - sp, 1.4 * b.ss);
    _bx[2] = osc(-0.6 * dr, dr, 1.45 * b.bs);
    _by[2] = osc(-0.85 * dr, 0.45 * dr, 1.45 * b.bs);
    _gh = osc(1 - b.gh, 1 + b.gh, b.ghs);
    _bop[_tl] = osc(1 - b.op, 1, b.bs);
    _bop[_tr] = osc(1 - b.op, 1, 1.32 * b.bs, 0.28 * b.bs);
    _bop[_bl] = osc(1 - b.op, 1, 0.84 * b.bs, 0.55 * b.bs);
    _bop[_br] = osc(1 - b.op, 1, 1.58 * b.bs, 0.83 * b.bs);
  }

  /// Draws [spots] in [rect] with the current breathing applied.
  void _breathingSpots(
    Canvas canvas,
    Rect rect,
    List<_Spot> spots,
    double kx,
    double ky, {
    double alpha = 1.0,
    bool breatheAlpha = true,
  }) {
    for (final _Spot s in spots) {
      final int r = s.region;
      _spot(
        canvas,
        Offset(
          rect.left + s.x * rect.width + _bx[r] * kx,
          rect.top + s.y * rect.height + _by[r] * ky,
        ),
        s.rx * kx * _bw[r],
        s.ry * ky * _bh[r] * _gh,
        look.slots[s.slot],
        alpha * (breatheAlpha ? _bop[s.quadrant] : 1.0),
      );
    }
  }

  void _paintPulse(Canvas canvas, Size size, double f) {
    final Rect box = Offset.zero & size;
    final RRect outer = _outer(box);
    final RRect inner = _strokeInner(outer);
    final bool dark = look.dark;
    final _Preset preset = dark
        ? const _Preset(1.0, 0.44, 0.66, saturation: 1.2, brightness: 0.75)
        : const _Preset(0.32, 0.40, 0.80, saturation: 0.75, brightness: 1.3);
    final _Breathing breathing = dark ? _pulseDark : _pulseLight;
    final double hue = _spinHue(16.0);
    final double kx = _scaleX(size);
    final double ky = _scaleY(size);
    _breathe(breathing);

    canvas.save();
    _clipToEffect(canvas, outer);

    final double innerOpacity = _opacity(f, preset.inner, halve: true);
    if (look.innerGlow && innerOpacity > 0) {
      canvas.saveLayer(
        box,
        _layerPaint(innerOpacity, hue, preset.saturation, preset.brightness),
      );
      _breathingSpots(canvas, box, _pulseInnerSpots, kx, ky);
      final Color accent = dark ? Colors.white : Colors.black;
      final double accentAlpha = dark ? 0.18 : 0.08;
      final List<(Offset, int)> corners = <(Offset, int)>[
        (box.topLeft, _tl),
        (box.topRight, _tr),
        (box.bottomLeft, _bl),
        (box.bottomRight, _br),
      ];
      for (final (Offset corner, int q) in corners) {
        _spot(canvas, corner, 60 * kx, 60 * ky, accent, accentAlpha * _bop[q]);
      }
      _edgeBand(canvas, box);
      canvas.restore();
    }

    final double strokeOpacity = _opacity(
      f,
      preset.stroke * _strokeBoost,
      halve: true,
    );
    if (strokeOpacity > 0 && look.borderWidth > 0) {
      canvas.saveLayer(
        box,
        _layerPaint(strokeOpacity, hue, preset.saturation, preset.brightness),
      );
      canvas.clipPath(_ring(outer, inner));
      _breathingSpots(canvas, box, _fieldSpots, kx, ky);
      canvas.restore();
    }

    final double bloomOpacity = _opacity(
      f,
      preset.bloom * _bloomBoost,
      halve: true,
    );
    if (bloomOpacity > 0) {
      canvas.saveLayer(
        box,
        _layerPaint(bloomOpacity, hue, preset.saturation, preset.brightness),
      );
      canvas.clipPath(
        _ring(outer, outer.deflate(math.max(look.borderWidth, 1.0))),
      );
      final Rect spread = box.inflate(24);
      canvas.saveLayer(
        spread,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      );
      _breathingSpots(
        canvas,
        box,
        _pulseBloomSpots,
        kx,
        ky,
        alpha: 1 - breathing.op / 2,
        breatheAlpha: false,
      );
      canvas.restore();
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) {
    return oldDelegate.clock != clock ||
        oldDelegate.fade != fade ||
        oldDelegate.look != look ||
        oldDelegate.animate != animate;
  }
}
