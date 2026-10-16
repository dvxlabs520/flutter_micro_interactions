import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Compact equalizer bars that follow a voice level, for recording pills.
///
/// ```dart
/// VoiceWaveform(
///   level: micLevel, // 0..1, computed from your own audio stack
///   active: isRecording,
/// )
/// ```
///
/// A row of [barCount] rounded vertical bars grows and shrinks with
/// [level]. Each bar moves with its own rhythm and the center bars reach
/// higher than the outer ones, so the row looks alive even with a steady
/// level. Heights are smoothed with a quick attack and a slower release.
/// When the level is close to zero the bars rest at [minHeight] with a
/// gentle ripple ([idleAnimation]). Setting [active] to `false` collapses
/// every bar to [minHeight].
///
/// This widget does not access the microphone. Pass a loudness value
/// between 0 and 1 as [level], or push it through [levelListenable] to
/// update every frame without rebuilding the parent.
///
/// While [active], the bars are announced with [semanticLabel]. Under
/// reduced motion, or with [enabled] set to `false`, the bars show the
/// level directly with no ripple, no per-bar movement and no ticker.
class VoiceWaveform extends StatefulWidget {
  /// Creates a voice waveform.
  const VoiceWaveform({
    super.key,
    this.level = 0.0,
    this.levelListenable,
    this.barCount = 5,
    this.barWidth = 3.0,
    this.spacing = 3.0,
    this.minHeight = 4.0,
    this.maxHeight = 24.0,
    this.color,
    this.active = true,
    this.idleAnimation = true,
    this.enabled = true,
    this.semanticLabel = 'Recording',
  }) : assert(level >= 0 && level <= 1, 'level must be between 0 and 1'),
       assert(barCount > 0, 'barCount must be positive'),
       assert(barWidth > 0, 'barWidth must be positive'),
       assert(spacing >= 0, 'spacing must not be negative'),
       assert(minHeight >= 0, 'minHeight must not be negative'),
       assert(
         maxHeight >= minHeight,
         'maxHeight must not be smaller than minHeight',
       );

  /// Current voice loudness between 0 (silence) and 1 (loud). Ignored when
  /// [levelListenable] is set. Defaults to 0.
  final double level;

  /// Optional source of the voice loudness, read every frame. Values
  /// outside 0..1 are clamped. Takes precedence over [level].
  final ValueListenable<double>? levelListenable;

  /// Number of bars. Defaults to 5.
  final int barCount;

  /// Width of each bar. Defaults to 3.
  final double barWidth;

  /// Horizontal gap between bars. Defaults to 3.
  final double spacing;

  /// Height of a bar at rest. Defaults to 4.
  final double minHeight;

  /// Height of a bar at full level; also the widget's height. Defaults
  /// to 24.
  final double maxHeight;

  /// Bar color. Defaults to the theme's `colorScheme.primary`.
  final Color? color;

  /// Whether recording is in progress. When `false` the bars collapse to
  /// [minHeight] and the semantic label is removed. Defaults to `true`.
  final bool active;

  /// Whether resting bars ripple gently when the level is close to zero.
  /// Defaults to `true`.
  final bool idleAnimation;

  /// When `false` the bars never animate and show the level directly.
  /// Defaults to `true`.
  final bool enabled;

  /// Label announced while [active]. Defaults to `'Recording'`.
  final String semanticLabel;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

/// Current bar heights, shared between the state and the painter.
class _WaveformBars extends ChangeNotifier {
  _WaveformBars(int count, double initial)
    : heights = List<double>.filled(count, initial);

  /// Bar heights in logical pixels.
  List<double> heights;

  void markChanged() => notifyListeners();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  static const double _attack = 0.06;
  static const double _release = 0.16;
  static const double _maxDt = 0.05;
  static const double _rippleAmount = 0.18;
  static const double _ripplePeriod = 1.4;
  static const double _settleEpsilon = 0.05;

  late final _WaveformBars _bars;
  late final Ticker _ticker;
  bool _reducedMotion = false;
  Duration _lastElapsed = Duration.zero;
  double _time = 0.0;

  bool get _animates => widget.enabled && !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _bars = _WaveformBars(widget.barCount, widget.minHeight);
    _ticker = createTicker(_onTick);
    widget.levelListenable?.addListener(_handleLevelChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.levelListenable != oldWidget.levelListenable) {
      oldWidget.levelListenable?.removeListener(_handleLevelChanged);
      widget.levelListenable?.addListener(_handleLevelChanged);
    }
    if (widget.barCount != _bars.heights.length) {
      _bars.heights = List<double>.generate(
        widget.barCount,
        (int i) =>
            i < _bars.heights.length ? _bars.heights[i] : widget.minHeight,
      );
    }
    _sync();
  }

  @override
  void dispose() {
    widget.levelListenable?.removeListener(_handleLevelChanged);
    _ticker.dispose();
    _bars.dispose();
    super.dispose();
  }

  double get _level {
    final double raw = widget.levelListenable?.value ?? widget.level;
    return raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0);
  }

  void _handleLevelChanged() {
    if (!mounted) return;
    _sync();
  }

  /// Envelope that makes center bars taller than outer bars, 0.55..1.
  double _envelope(int index) {
    final int count = widget.barCount;
    if (count == 1) return 1.0;
    final double center = (count - 1) / 2;
    final double d = (index - center).abs() / center;
    return 1.0 - 0.45 * d * d;
  }

  /// Target height of bar [index] at [time] seconds.
  double _target(int index, double time, {required bool animated}) {
    final double min = widget.minHeight;
    final double range = widget.maxHeight - min;
    if (!widget.active) return min;
    final double level = _level;
    double factor = level * _envelope(index);
    if (animated) {
      // Each bar has its own frequency and phase so the row looks alive.
      final double frequency = 5.3 + 2.9 * ((index * 7919) % 5) / 4;
      final double phase = index * 1.7;
      factor *= 0.6 + 0.4 * (0.5 + 0.5 * math.sin(frequency * time + phase));
      if (widget.idleAnimation) {
        // Ripple that fades out as the voice gets louder.
        final double quiet = (1 - level * 4).clamp(0.0, 1.0);
        final double ripple =
            0.5 +
            0.5 * math.sin(2 * math.pi * time / _ripplePeriod - index * 0.9);
        factor += quiet * _rippleAmount * ripple;
      }
    }
    return min + range * factor.clamp(0.0, 1.0);
  }

  /// Starts or stops the ticker, or settles the bars, to match the
  /// current configuration.
  void _sync() {
    if (!_animates) {
      if (_ticker.isActive) _ticker.stop();
      for (int i = 0; i < _bars.heights.length; i++) {
        _bars.heights[i] = _target(i, 0.0, animated: false);
      }
      _bars.markChanged();
      return;
    }
    if (!_ticker.isActive && !_isSettled) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  /// Whether nothing would move if the ticker ran: the bars are at a
  /// constant target and have reached it.
  bool get _isSettled {
    final bool constantTarget =
        !widget.active || (!widget.idleAnimation && _level <= 0.0);
    if (!constantTarget) return false;
    for (int i = 0; i < _bars.heights.length; i++) {
      final double target = _target(i, _time, animated: true);
      if ((_bars.heights[i] - target).abs() > _settleEpsilon) return false;
    }
    return true;
  }

  void _onTick(Duration elapsed) {
    final double dt = math.min(
      _maxDt,
      math.max(0.0, (elapsed - _lastElapsed).inMicroseconds / 1e6),
    );
    _lastElapsed = elapsed;
    _time += dt;
    final List<double> heights = _bars.heights;
    for (int i = 0; i < heights.length; i++) {
      final double target = _target(i, _time, animated: true);
      final double tau = target > heights[i] ? _attack : _release;
      heights[i] += (target - heights[i]) * (1 - math.exp(-dt / tau));
    }
    if (_isSettled) {
      for (int i = 0; i < heights.length; i++) {
        heights[i] = _target(i, _time, animated: true);
      }
      _ticker.stop();
    }
    _bars.markChanged();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? Theme.of(context).colorScheme.primary;
    final int count = widget.barCount;
    final double width = count * widget.barWidth + (count - 1) * widget.spacing;
    Widget bars = RepaintBoundary(
      child: CustomPaint(
        size: Size(width, widget.maxHeight),
        painter: _WaveformPainter(
          bars: _bars,
          color: color,
          barWidth: widget.barWidth,
          spacing: widget.spacing,
        ),
      ),
    );
    if (widget.active) {
      bars = Semantics(
        container: true,
        label: widget.semanticLabel,
        child: ExcludeSemantics(child: bars),
      );
    } else {
      bars = ExcludeSemantics(child: bars);
    }
    return bars;
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.color,
    required this.barWidth,
    required this.spacing,
  }) : super(repaint: bars);

  /// Animated bar heights.
  final _WaveformBars bars;

  /// Bar color.
  final Color color;

  /// Width of each bar.
  final double barWidth;

  /// Gap between bars.
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Radius radius = Radius.circular(barWidth / 2);
    final double centerY = size.height / 2;
    final List<double> heights = bars.heights;
    for (int i = 0; i < heights.length; i++) {
      final double h = math.max(heights[i], barWidth);
      final double left = i * (barWidth + spacing);
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          centerY - h / 2,
          left + barWidth,
          centerY + h / 2,
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.color != color ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.spacing != spacing;
  }
}
