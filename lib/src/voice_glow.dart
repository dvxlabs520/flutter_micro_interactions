// VoiceGlow is a Flutter port of "Voice" (https://libraries.dev)
// by Jakub Antalik, released under the MIT license.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// What a [VoiceGlow] is currently showing.
enum VoiceGlowState {
  /// Nobody is speaking: the glow breathes softly on its own and still
  /// reacts to [VoiceGlow.level].
  idle,

  /// The user is speaking: the glow rises and blooms with
  /// [VoiceGlow.level].
  listening,

  /// The reply is being worked out: the lobes gather into one compact beam
  /// that sweeps from side to side.
  processing,

  /// The glow fades out completely and stops animating.
  off,
}

/// Built-in color sets for a [VoiceGlow].
enum VoiceGlowPalette {
  /// Pink, blue, violet, green, orange and teal. Uses a lighter, warmer set
  /// of colors on light backgrounds.
  colorful,

  /// Blues, cyans and violets.
  ocean,

  /// Oranges, ambers, pinks and reds.
  sunset,

  /// Neutral greys, light on dark backgrounds and dark on light ones.
  mono,
}

/// A sound-reactive glow that rises from the bottom edge of its child.
///
/// ```dart
/// VoiceGlow(
///   level: micLevel, // 0..1, computed from your own audio stack
///   state: VoiceGlowState.listening,
///   borderRadius: const BorderRadius.all(Radius.circular(28)),
///   child: const MyChatInput(),
/// )
/// ```
///
/// Seven soft colored lobes sit at the bottom center of [child]. While
/// [state] is [VoiceGlowState.listening] they rise and bloom with [level]
/// and drift slowly sideways. In [VoiceGlowState.processing] they gather
/// into one compact beam that sweeps left and right, and in
/// [VoiceGlowState.idle] the glow breathes gently. [VoiceGlowState.off]
/// fades the glow out and stops the ticker.
///
/// The glow is drawn in three layers over [child]: a thin light ring
/// along the rounded border, a soft inner light, and a blurred bloom. An
/// optional glowing line runs along the bottom edge ([showBand]). The
/// colors drift slowly in hue.
///
/// This widget does not access the microphone. Compute a loudness value
/// between 0 and 1 from your own audio code and pass it as [level], or
/// push it through [levelListenable] to update every frame without
/// rebuilding the parent. The value is smoothed internally, so raw
/// readings are fine.
///
/// The glow is decorative: it ignores pointers and adds no semantics, and
/// the child's own semantics are untouched. Under reduced motion the
/// breathing, sideways drift, beam sweep and hue drift stop, but the glow
/// still follows [level]. With [enabled] set to `false` a static idle
/// frame is shown.
class VoiceGlow extends StatefulWidget {
  /// Creates a voice glow around [child].
  const VoiceGlow({
    super.key,
    required this.child,
    this.level = 0.0,
    this.levelListenable,
    this.state = VoiceGlowState.listening,
    this.palette = VoiceGlowPalette.colorful,
    this.colors,
    this.brightness,
    this.reach = 1.2,
    this.spread = 1.05,
    this.strength = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.showBand = true,
    this.clip = true,
    this.enabled = true,
  }) : assert(level >= 0 && level <= 1, 'level must be between 0 and 1'),
       assert(
         colors == null || (colors.length >= 1 && colors.length <= 7),
         'colors must contain between 1 and 7 colors',
       ),
       assert(reach >= 0, 'reach must not be negative'),
       assert(spread >= 0, 'spread must not be negative'),
       assert(strength >= 0, 'strength must not be negative');

  /// The widget the glow is drawn on, typically a chat input, a recording
  /// pill or a whole screen. It should paint its own background.
  final Widget child;

  /// Current voice loudness between 0 (silence) and 1 (loud). Ignored when
  /// [levelListenable] is set. Defaults to 0.
  final double level;

  /// Optional source of the voice loudness, read every frame. Use it to
  /// feed fast-changing audio levels without rebuilding the parent. Values
  /// outside 0..1 are clamped. Takes precedence over [level].
  final ValueListenable<double>? levelListenable;

  /// What the glow shows. Defaults to [VoiceGlowState.listening].
  final VoiceGlowState state;

  /// Built-in color set. Ignored when [colors] is set. Defaults to
  /// [VoiceGlowPalette.colorful].
  final VoiceGlowPalette palette;

  /// Custom lobe colors, from the center lobe outwards in pairs (center,
  /// inner pair, outer pair, far pair). Up to seven colors; shorter lists
  /// repeat.
  final List<Color>? colors;

  /// Whether the glow is tuned for a dark or a light background. Defaults
  /// to the ambient [ThemeData.brightness].
  final Brightness? brightness;

  /// How high the glow rises with the voice. Defaults to 1.2.
  final double reach;

  /// How wide the glow spreads with the voice. Defaults to 1.05.
  final double spread;

  /// Overall opacity multiplier. Defaults to 1.
  final double strength;

  /// Corner rounding of the child, used for the light ring and the clip.
  /// Defaults to a 24 pixel circular radius.
  final BorderRadius borderRadius;

  /// Whether a thin glowing line is drawn along the bottom edge. Defaults
  /// to `true`.
  final bool showBand;

  /// Whether the glow is clipped to the child's rounded rectangle. When
  /// `false` the bloom may spill outside the child. Defaults to `true`.
  final bool clip;

  /// When `false` the glow never animates and shows a static idle frame.
  /// Defaults to `true`.
  final bool enabled;

  @override
  State<VoiceGlow> createState() => _VoiceGlowWidgetState();
}

/// Per-frame values shared between the state (which advances them) and
/// the painter (which draws them).
class _VoiceGlowFrame extends ChangeNotifier {
  /// Smoothed voice level, 0..1.
  double smoothed = 0.0;

  /// Level after idle breathing is mixed in, 0..1.
  double effective = 0.0;

  /// Low frequency band lift, 0..1.
  double low = 0.0;

  /// Mid frequency band lift, 0..1.
  double mid = 0.0;

  /// High frequency band lift, 0..1.
  double high = 0.0;

  /// How much the idle breathing applies, 0..1.
  double idleMix = 0.0;

  /// How much the processing beam applies, 0..1.
  double processing = 0.0;

  /// Beam position from -1 (left) to 1 (right).
  double beamU = 0.0;

  /// Sideways flow offset in reference pixels, 0..252.
  double phase = 0.0;

  /// Linear visibility, 0 (off) to 1 (fully shown).
  double fade = 0.0;

  /// Current hue rotation in degrees.
  double hueDegrees = 0.0;

  void markChanged() => notifyListeners();
}

class _VoiceGlowWidgetState extends State<VoiceGlow>
    with SingleTickerProviderStateMixin {
  // Envelope time constants, in seconds.
  static const double _attack = 0.325;
  static const double _release = 0.86;
  static const double _mixTau = 0.35;
  static const double _maxDt = 0.05;
  static const double _fadeOutSeconds = 0.5;
  static const double _fadeInSeconds = 0.6;
  static const double _idleAmount = 0.23;
  static const double _breathSeconds = 5.2;
  static const double _sweepSeconds = 2.4;
  static const double _flowSpeed = 48.0;
  static const double _flowWrap = 252.0;

  final _VoiceGlowFrame _frame = _VoiceGlowFrame();
  late final Ticker _ticker;
  bool _reducedMotion = false;
  Duration _lastElapsed = Duration.zero;

  /// Seconds since the ticker started, accumulated across restarts.
  double _time = 0.0;

  /// Seconds into the beam sweep cycle.
  double _beamClock = 0.0;

  bool get _animates => widget.enabled && !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.levelListenable?.addListener(_handleLevelChanged);
    if (widget.state == VoiceGlowState.processing) {
      _beamClock = _sweepSeconds / 2;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(VoiceGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.levelListenable != oldWidget.levelListenable) {
      oldWidget.levelListenable?.removeListener(_handleLevelChanged);
      widget.levelListenable?.addListener(_handleLevelChanged);
    }
    if (widget.state == VoiceGlowState.processing &&
        oldWidget.state != VoiceGlowState.processing &&
        _frame.processing < 0.05) {
      // Start the sweep from the center, heading right.
      _beamClock = _sweepSeconds / 2;
    }
    _sync();
  }

  @override
  void dispose() {
    widget.levelListenable?.removeListener(_handleLevelChanged);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  double get _targetLevel {
    final double raw = widget.levelListenable?.value ?? widget.level;
    return raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0);
  }

  void _handleLevelChanged() {
    if (!mounted) return;
    _sync();
  }

  /// Starts or stops the ticker, or paints a static frame, to match the
  /// current configuration.
  void _sync() {
    if (!_animates) {
      if (_ticker.isActive) _ticker.stop();
      _applyStaticFrame();
      return;
    }
    final bool hidden =
        widget.state == VoiceGlowState.off && _frame.fade <= 0.0;
    if (hidden) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  /// Settles every value at its target without any motion.
  void _applyStaticFrame() {
    final _VoiceGlowFrame f = _frame;
    final VoiceGlowState state = widget.enabled
        ? widget.state
        : VoiceGlowState.idle;
    final double level = widget.enabled ? _targetLevel : 0.0;
    final bool off = widget.state == VoiceGlowState.off;
    f.fade = off ? 0.0 : 1.0;
    f.idleMix = state == VoiceGlowState.idle ? 1.0 : 0.0;
    f.processing = state == VoiceGlowState.processing ? 1.0 : 0.0;
    f.smoothed = _levelTarget(state, level);
    f.beamU = 0.0;
    f.phase = 0.0;
    f.hueDegrees = 0.0;
    // Frozen breathing sits at its midpoint.
    _updateEffective(breath: 0.5, time: 0.0, oscillate: false);
    f.markChanged();
  }

  double _levelTarget(VoiceGlowState state, double level) {
    switch (state) {
      case VoiceGlowState.off:
        return 0.0;
      case VoiceGlowState.processing:
        return 0.45 + 0.35 * level;
      case VoiceGlowState.idle:
      case VoiceGlowState.listening:
        return level;
    }
  }

  void _updateEffective({
    required double breath,
    required double time,
    required bool oscillate,
  }) {
    final _VoiceGlowFrame f = _frame;
    final double s = f.smoothed;
    final double e = (s + (1 - s) * _idleAmount * breath * f.idleMix).clamp(
      0.0,
      1.0,
    );
    f.effective = e;
    f.low = e;
    if (oscillate) {
      f.mid = e * (0.72 + 0.28 * math.sin(9.1 * time));
      f.high = e * (0.6 + 0.4 * math.sin(13.7 * time + 2));
    } else {
      f.mid = e * 0.72;
      f.high = e * 0.6;
    }
  }

  static double _approach(double value, double target, double dt, double tau) {
    return value + (target - value) * (1 - math.exp(-dt / tau));
  }

  void _onTick(Duration elapsed) {
    final double dt = math.min(
      _maxDt,
      math.max(0.0, (elapsed - _lastElapsed).inMicroseconds / 1e6),
    );
    _lastElapsed = elapsed;
    _time += dt;
    final _VoiceGlowFrame f = _frame;
    final VoiceGlowState state = widget.state;
    final bool dark = _brightness == Brightness.dark;

    final double target = _levelTarget(state, _targetLevel);
    f.smoothed = _approach(
      f.smoothed,
      target,
      dt,
      target > f.smoothed ? _attack : _release,
    );
    f.idleMix = _approach(
      f.idleMix,
      state == VoiceGlowState.idle ? 1.0 : 0.0,
      dt,
      _mixTau,
    );
    f.processing = _approach(
      f.processing,
      state == VoiceGlowState.processing ? 1.0 : 0.0,
      dt,
      _mixTau,
    );
    if (state == VoiceGlowState.off) {
      f.fade = math.max(0.0, f.fade - dt / _fadeOutSeconds);
    } else {
      f.fade = math.min(1.0, f.fade + dt / _fadeInSeconds);
    }

    final double breath =
        0.5 + 0.5 * math.sin(2 * math.pi * _time / _breathSeconds);
    _updateEffective(breath: breath, time: _time, oscillate: true);

    f.phase =
        (f.phase + _flowSpeed * f.effective * dt * (1 - f.processing)) %
        _flowWrap;

    if (f.processing > 0.001) {
      _beamClock = (_beamClock + dt) % (_sweepSeconds * 2);
      final double u = _beamClock / (_sweepSeconds * 2);
      // Triangle wave 0..1..0, eased at the turns.
      final double tri = u < 0.5 ? u * 2 : 2 - u * 2;
      final double eased = 0.5 - 0.5 * math.cos(math.pi * tri);
      f.beamU = eased * 2 - 1;
    }

    final double hueRange = dark ? 24.0 : 40.0;
    final double huePeriod = dark ? 12.0 : 8.5;
    f.hueDegrees = hueRange * math.sin(2 * math.pi * _time / huePeriod);

    f.markChanged();

    if (state == VoiceGlowState.off && f.fade <= 0.0) {
      _ticker.stop();
    }
  }

  Brightness get _brightness =>
      widget.brightness ?? Theme.of(context).brightness;

  List<Color> _lobeColors(Brightness brightness) {
    final List<Color>? custom = widget.colors;
    final List<Color> source = (custom != null && custom.isNotEmpty)
        ? custom
        : _paletteColors(widget.palette, brightness);
    return List<Color>.generate(7, (int i) => source[i % source.length]);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = _brightness;
    Widget glow = CustomPaint(
      painter: _VoiceGlowPainter(
        frame: _frame,
        colors: _lobeColors(brightness),
        dark: brightness == Brightness.dark,
        mono: widget.colors == null && widget.palette == VoiceGlowPalette.mono,
        reach: widget.reach,
        spread: widget.spread,
        strength: widget.strength,
        borderRadius: widget.borderRadius,
        showBand: widget.showBand,
        clip: widget.clip,
      ),
    );
    if (widget.clip) {
      glow = ClipRRect(borderRadius: widget.borderRadius, child: glow);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(child: RepaintBoundary(child: glow)),
          ),
        ),
      ],
    );
  }
}

List<Color> _paletteColors(VoiceGlowPalette palette, Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  switch (palette) {
    case VoiceGlowPalette.colorful:
      return dark ? _colorfulDark : _colorfulLight;
    case VoiceGlowPalette.ocean:
      return _ocean;
    case VoiceGlowPalette.sunset:
      return _sunset;
    case VoiceGlowPalette.mono:
      return dark ? _monoDark : _monoLight;
  }
}

const List<Color> _colorfulDark = <Color>[
  Color.fromARGB(255, 255, 70, 120),
  Color.fromARGB(255, 60, 190, 255),
  Color.fromARGB(255, 175, 70, 255),
  Color.fromARGB(255, 60, 220, 130),
  Color.fromARGB(255, 255, 150, 40),
  Color.fromARGB(255, 90, 100, 255),
  Color.fromARGB(255, 40, 200, 190),
];

const List<Color> _colorfulLight = <Color>[
  Color.fromARGB(255, 255, 201, 21),
  Color.fromARGB(255, 126, 196, 255),
  Color.fromARGB(255, 180, 40, 230),
  Color.fromARGB(255, 235, 100, 160),
  Color.fromARGB(255, 255, 176, 122),
  Color.fromARGB(255, 154, 160, 255),
  Color.fromARGB(255, 127, 217, 238),
];

const List<Color> _ocean = <Color>[
  Color.fromARGB(255, 80, 140, 255),
  Color.fromARGB(255, 40, 200, 230),
  Color.fromARGB(255, 120, 90, 255),
  Color.fromARGB(255, 30, 170, 210),
  Color.fromARGB(255, 160, 80, 240),
  Color.fromARGB(255, 60, 110, 255),
  Color.fromARGB(255, 40, 190, 180),
];

const List<Color> _sunset = <Color>[
  Color.fromARGB(255, 255, 110, 60),
  Color.fromARGB(255, 255, 180, 40),
  Color.fromARGB(255, 255, 60, 90),
  Color.fromARGB(255, 255, 210, 80),
  Color.fromARGB(255, 240, 70, 140),
  Color.fromARGB(255, 255, 140, 50),
  Color.fromARGB(255, 230, 50, 110),
];

const List<Color> _monoDark = <Color>[
  Color.fromARGB(255, 240, 240, 245),
  Color.fromARGB(255, 205, 205, 212),
  Color.fromARGB(255, 175, 175, 182),
  Color.fromARGB(255, 220, 220, 226),
  Color.fromARGB(255, 160, 160, 168),
  Color.fromARGB(255, 190, 190, 198),
  Color.fromARGB(255, 140, 140, 148),
];

const List<Color> _monoLight = <Color>[
  Color.fromARGB(255, 40, 40, 46),
  Color.fromARGB(255, 70, 70, 78),
  Color.fromARGB(255, 95, 95, 104),
  Color.fromARGB(255, 60, 60, 68),
  Color.fromARGB(255, 110, 110, 120),
  Color.fromARGB(255, 80, 80, 90),
  Color.fromARGB(255, 125, 125, 135),
];

/// Static description of one lobe at rest, in reference pixels.
class _Lobe {
  const _Lobe(this.x, this.rx, this.ry, this.band);

  final double x;
  final double rx;
  final double ry;

  /// 0 = low, 1 = mid, 2 = high.
  final int band;
}

// Index order matches the palette order: center, then pairs outwards.
const List<_Lobe> _lobes = <_Lobe>[
  _Lobe(0, 74, 46, 0),
  _Lobe(-36, 54, 40, 1),
  _Lobe(36, 54, 40, 1),
  _Lobe(-72, 48, 32, 2),
  _Lobe(72, 48, 32, 2),
  _Lobe(-108, 42, 26, 1),
  _Lobe(108, 42, 26, 1),
];

// Drawing order: far lobes first, center lobe on top.
const List<int> _drawOrder = <int>[5, 6, 3, 4, 1, 2, 0];

class _VoiceGlowPainter extends CustomPainter {
  _VoiceGlowPainter({
    required this.frame,
    required this.colors,
    required this.dark,
    required this.mono,
    required this.reach,
    required this.spread,
    required this.strength,
    required this.borderRadius,
    required this.showBand,
    required this.clip,
  }) : _lobePaints = List<Paint>.generate(
         colors.length,
         (int i) => Paint()..shader = _unitRadial(colors[i]),
       ),
       _corePaint = Paint()
         ..shader = dark
             ? ui.Gradient.radial(
                 Offset.zero,
                 1,
                 const <Color>[
                   Color.fromRGBO(255, 255, 255, 0.45),
                   Color.fromRGBO(255, 255, 255, 0.14),
                   Color.fromRGBO(255, 255, 255, 0),
                 ],
                 const <double>[0, 0.3, 0.65],
               )
             : ui.Gradient.radial(
                 Offset.zero,
                 1,
                 const <Color>[
                   Color.fromRGBO(0, 0, 0, 0.55),
                   Color.fromRGBO(0, 0, 0, 0.22),
                   Color.fromRGBO(0, 0, 0, 0),
                 ],
                 const <double>[0, 0.35, 0.7],
               ),
       super(repaint: frame);

  /// Animated values, advanced by the widget state every frame.
  final _VoiceGlowFrame frame;

  /// Seven lobe colors, center first.
  final List<Color> colors;

  /// Whether the glow is tuned for a dark background.
  final bool dark;

  /// Whether the mono palette is used (drawn dimmer).
  final bool mono;

  /// How high the glow rises with the voice.
  final double reach;

  /// How wide the glow spreads with the voice.
  final double spread;

  /// Overall opacity multiplier.
  final double strength;

  /// Corner rounding of the host.
  final BorderRadius borderRadius;

  /// Whether the bottom line is drawn.
  final bool showBand;

  /// Whether the glow is clipped to the host.
  final bool clip;

  final List<Paint> _lobePaints;
  final Paint _corePaint;

  /// Lobe geometry for the current frame: x, rx, ry per lobe.
  final Float64List _geometry = Float64List(_lobes.length * 3);

  static ui.Gradient _unitRadial(Color color) {
    return ui.Gradient.radial(
      Offset.zero,
      1,
      <Color>[color, color.withValues(alpha: 0)],
      const <double>[0, 0.75],
    );
  }

  /// Elliptical radial gradient centered at [center] with radii [rx], [ry],
  /// clamped so pixels outside it take the last color.
  static ui.Gradient _ellipseShader(
    Offset center,
    double rx,
    double ry,
    List<Color> colors,
    List<double> stops,
  ) {
    final Float64List matrix = Float64List(16)
      ..[0] = rx
      ..[5] = ry
      ..[10] = 1
      ..[12] = center.dx
      ..[13] = center.dy
      ..[15] = 1;
    return ui.Gradient.radial(
      Offset.zero,
      1,
      colors,
      stops,
      TileMode.clamp,
      matrix,
    );
  }

  /// Combined saturation and hue rotation color matrix.
  static List<double> _colorMatrix(double hueDegrees, double saturation) {
    final double s = saturation;
    final List<double> sat = <double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, //
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, //
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, //
    ];
    final double a = hueDegrees * math.pi / 180;
    final double c = math.cos(a);
    final double n = math.sin(a);
    final List<double> hue = <double>[
      0.213 + c * 0.787 - n * 0.213,
      0.715 - c * 0.715 - n * 0.715,
      0.072 - c * 0.072 + n * 0.928,
      0.213 - c * 0.213 + n * 0.143,
      0.715 + c * 0.285 + n * 0.140,
      0.072 - c * 0.072 - n * 0.283,
      0.213 - c * 0.213 - n * 0.787,
      0.715 - c * 0.715 + n * 0.715,
      0.072 + c * 0.928 + n * 0.072,
    ];
    final List<double> out = List<double>.filled(20, 0);
    for (int r = 0; r < 3; r++) {
      for (int col = 0; col < 3; col++) {
        double sum = 0;
        for (int k = 0; k < 3; k++) {
          sum += hue[r * 3 + k] * sat[k * 3 + col];
        }
        out[r * 5 + col] = sum;
      }
    }
    out[18] = 1;
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _VoiceGlowFrame f = frame;
    if (f.fade <= 0.0 || size.isEmpty) return;

    final double sx = (size.width / 350).clamp(0.5, 3.0);
    final double e = f.effective;
    final double h = 0.5 + reach * e;
    final double w = 0.85 + spread * e;
    final double presence = 0.15 + 0.85 * e;
    final double fade = Curves.easeInOut.transform(f.fade.clamp(0.0, 1.0));
    final double base = fade * presence * strength * (mono ? 0.6 : 1.0);
    if (base <= 0.0) return;

    final double centerX = size.width / 2;
    final double bottomY = size.height + 2;
    final double p = f.processing.clamp(0.0, 1.0);
    final double beamPx = f.beamU * math.max(0.0, size.width / 2 - 60 * sx);
    final double focusX = centerX + beamPx * p;

    _layoutLobes(sx, w, h, p, beamPx / sx);

    final Rect bounds = (Offset.zero & size).inflate(clip ? 0 : 60);
    final ColorFilter filter = ColorFilter.matrix(
      _colorMatrix(f.hueDegrees, dark ? 1.2 : 1.6),
    );
    final BlendMode blend = dark ? BlendMode.plus : BlendMode.srcOver;

    final double rangeRx = 170 * 0.75 * w * sx;
    final double rangeRy = 64 * h + 60 * e;
    final Paint rangeMask = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = _ellipseShader(
        Offset(focusX, size.height),
        rangeRx,
        rangeRy,
        const <Color>[Color(0xFFFFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
        const <double>[0, 0.45, 1],
      );
    final RRect host = borderRadius.toRRect(Offset.zero & size);

    // 1. Thin light ring along the border.
    final double strokeOpacity = base * 1.0;
    if (strokeOpacity > 0.002) {
      canvas.saveLayer(bounds, _layerPaint(strokeOpacity, filter, blend));
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRRect(host)
          ..addRRect(host.deflate(1.0)),
      );
      _drawLobes(canvas, centerX, bottomY, 1.0, 1.0);
      _drawUnit(
        canvas,
        Offset(focusX, bottomY),
        30 * w * sx * (dark ? 1 : 40 / 30),
        30 * h,
        _corePaint,
      );
      canvas.drawRect(bounds, rangeMask);
      canvas.restore();
    }

    // 2. Soft inner light.
    final double innerOpacity = base * (dark ? 0.47 : 0.85) * 0.46;
    if (innerOpacity > 0.002) {
      canvas.saveLayer(bounds, _layerPaint(innerOpacity, filter, blend));
      _drawLobes(canvas, centerX, bottomY, 0.9, 0.9);
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
      canvas.drawRect(bounds, Paint()..shader = rangeMask.shader);
      canvas.drawRRect(
        host,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28
          ..color = const Color(0xCCFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.restore();
      canvas.restore();
    }

    // 3. Blurred bloom.
    final double bloomOpacity = base * (dark ? 0.89 * 0.9 : 0.5 * 0.7);
    if (bloomOpacity > 0.002) {
      canvas.saveLayer(
        bounds.inflate(20),
        _layerPaint(bloomOpacity, filter, blend)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      );
      _drawLobes(canvas, centerX, bottomY, 1.15, 1.5);
      canvas.drawRect(
        bounds.inflate(20),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _ellipseShader(
            Offset(focusX, size.height),
            200 * sx,
            130,
            const <Color>[
              Color(0xFFFFFFFF),
              Color(0x80FFFFFF),
              Color(0x00FFFFFF),
            ],
            const <double>[0, 0.35, 1],
          ),
      );
      canvas.restore();
    }

    // 4. Optional glowing line along the bottom edge.
    if (showBand) {
      _drawBand(canvas, size, focusX, rangeRx, e, base, blend);
    }
  }

  Paint _layerPaint(double opacity, ColorFilter filter, BlendMode blend) {
    return Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
      ..colorFilter = filter
      ..blendMode = blend;
  }

  void _layoutLobes(double sx, double w, double h, double p, double beamRef) {
    final _VoiceGlowFrame f = frame;
    for (int i = 0; i < _lobes.length; i++) {
      final _Lobe lobe = _lobes[i];
      final double lift = lobe.band == 0
          ? f.low
          : lobe.band == 1
          ? f.mid
          : f.high;
      final double amp = 0.6 + 0.7 * lift.clamp(0.0, 1.0);
      // Sideways flow, wrapped into +-126 so lobes re-enter on the far side.
      final double flowX = ((lobe.x + f.phase + 126) % 252) - 126;
      final double edge = math.max(0.0, 1 - (flowX / 130) * (flowX / 130));
      // Processing: lobes gather around the beam.
      final double beamX = beamRef + lobe.x * 0.22;
      final double beamAmp = i == 0 ? 0.95 : 0.7;
      final double x = ui.lerpDouble(flowX, beamX, p)!;
      final double envelope = ui.lerpDouble(edge * amp, beamAmp, p)!;
      final double widthFactor = ui.lerpDouble(1.0, i == 0 ? 1.1 : 0.6, p)!;
      _geometry[i * 3] = x * sx;
      _geometry[i * 3 + 1] = lobe.rx * 0.65 * w * sx * widthFactor;
      _geometry[i * 3 + 2] = lobe.ry * 1.25 * h * envelope;
    }
  }

  void _drawLobes(
    Canvas canvas,
    double centerX,
    double bottomY,
    double sxScale,
    double syScale,
  ) {
    for (final int i in _drawOrder) {
      final double rx = _geometry[i * 3 + 1] * sxScale;
      final double ry = _geometry[i * 3 + 2] * syScale;
      _drawUnit(
        canvas,
        Offset(centerX + _geometry[i * 3], bottomY),
        rx,
        ry,
        _lobePaints[i],
      );
    }
  }

  void _drawUnit(Canvas canvas, Offset center, double rx, double ry, Paint p) {
    if (rx < 0.5 || ry < 0.5) return;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(rx, ry)
      ..drawCircle(Offset.zero, 1, p)
      ..restore();
  }

  void _drawBand(
    Canvas canvas,
    Size size,
    double focusX,
    double rangeRx,
    double e,
    double base,
    BlendMode blend,
  ) {
    final double opacity = base * (dark ? 0.55 : 0.4);
    if (opacity <= 0.002) return;
    final double halfLength = math.min(rangeRx * 0.85, size.width / 2);
    final double thickness = 14 * (1 + 0.35 * e) * (0.35 + 0.65 * e);
    final double y = size.height - 1.5;

    canvas.saveLayer(
      (Offset.zero & size).inflate(20),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
        ..blendMode = blend,
    );
    final Path pink = _lensPath(focusX, y - 1.5, halfLength, thickness * 0.4);
    final Path blue = _lensPath(focusX, y + 1.5, halfLength, thickness * 0.4);
    canvas.drawPath(
      pink,
      Paint()
        ..color = const Color.fromARGB(255, 255, 110, 200)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      blue,
      Paint()
        ..color = const Color.fromARGB(255, 80, 150, 255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      _lensPath(focusX, y, halfLength * 0.9, thickness * 0.14),
      Paint()
        ..color = dark ? const Color(0xFFFFFFFF) : const Color(0xFF6A5CFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.restore();
  }

  /// Bell curve that is 1 at the center and 0 at both ends.
  static double _bell(double u) {
    const double power = 1.75;
    const double s = 0.87;
    final double floor = math.exp(-math.pow(1 / s, power));
    final double v = math.exp(-math.pow(u.abs() / s, power));
    return ((v - floor) / (1 - floor)).clamp(0.0, 1.0);
  }

  static Path _lensPath(double cx, double cy, double half, double thickness) {
    const int samples = 24;
    final Path path = Path()..moveTo(cx - half, cy);
    for (int i = 1; i <= samples; i++) {
      final double u = -1 + 2 * i / samples;
      path.lineTo(cx + u * half, cy - thickness / 2 * _bell(u));
    }
    for (int i = samples - 1; i >= 1; i--) {
      final double u = -1 + 2 * i / samples;
      path.lineTo(cx + u * half, cy + thickness / 2 * _bell(u));
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _VoiceGlowPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        !listEquals(oldDelegate.colors, colors) ||
        oldDelegate.dark != dark ||
        oldDelegate.mono != mono ||
        oldDelegate.reach != reach ||
        oldDelegate.spread != spread ||
        oldDelegate.strength != strength ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.showBand != showBand ||
        oldDelegate.clip != clip;
  }
}
