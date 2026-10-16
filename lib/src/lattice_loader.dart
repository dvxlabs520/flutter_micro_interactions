import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// A compact agent status row: a small grid of cells that brighten in a
/// diagonal wave, a label such as 'Generating' and a live stopwatch.
///
/// ```dart
/// const LatticeLoader(label: 'Generating')
/// ```
///
/// The lattice has [columns] by [rows] rounded cells of [cellSize] with a
/// [gap] between them. A brightness wave travels diagonally across it, from
/// the top start corner to the bottom end corner: each cell's opacity and
/// scale follow a sine of the time minus its diagonal position, so the
/// light appears to roll across the grid. [waveSpeed] sets how many waves
/// pass per second.
///
/// The stopwatch ('00:07', or '1:02:03' past an hour) starts when the
/// widget appears, or when [active] turns `true`, and ticks once per
/// second. When [active] is `false` the wave stops, the cells dim and the
/// stopwatch freezes, which suits a 'Generated in 00:07' summary. Pass
/// [elapsed] to display your own value instead of the measured one.
///
/// Accessibility: the row is announced as one node, the label (or
/// [semanticLabel], 'Working' by default) followed by the elapsed time in
/// words. The lattice itself is decorative.
///
/// Under reduced motion, or when [enabled] is `false`, the lattice shows a
/// still diagonal gradient and schedules no frames; the stopwatch still
/// counts.
class LatticeLoader extends StatefulWidget {
  /// Creates a lattice loader.
  ///
  /// [columns] and [rows] must be positive, [cellSize] and [waveSpeed]
  /// must be positive and [gap] must not be negative.
  const LatticeLoader({
    super.key,
    this.label,
    this.showTimer = true,
    this.columns = 4,
    this.rows = 3,
    this.cellSize = 4.0,
    this.gap = 2.0,
    this.color,
    this.waveSpeed = 0.9,
    this.labelStyle,
    this.timerStyle,
    this.elapsed,
    this.active = true,
    this.semanticLabel,
    this.enabled = true,
  }) : assert(columns > 0, 'columns must be positive'),
       assert(rows > 0, 'rows must be positive'),
       assert(cellSize > 0.0, 'cellSize must be positive'),
       assert(gap >= 0.0, 'gap must not be negative'),
       assert(waveSpeed > 0.0, 'waveSpeed must be positive');

  /// Optional text shown after the lattice, for example 'Generating'.
  final String? label;

  /// Whether the stopwatch is shown after the label. Defaults to `true`.
  final bool showTimer;

  /// Number of cell columns. Defaults to 4.
  final int columns;

  /// Number of cell rows. Defaults to 3.
  final int rows;

  /// Side of one cell, in logical pixels. Defaults to 4.
  final double cellSize;

  /// Space between two cells. Defaults to 2.
  final double gap;

  /// The color of the cells. Defaults to [ColorScheme.primary].
  final Color? color;

  /// Number of waves crossing the lattice per second. Defaults to 0.9.
  final double waveSpeed;

  /// The style of the label. Defaults to the theme's `labelLarge` colored
  /// with [ColorScheme.onSurface].
  final TextStyle? labelStyle;

  /// The style of the stopwatch. Defaults to the label style colored with
  /// [ColorScheme.onSurfaceVariant], with tabular figures.
  final TextStyle? timerStyle;

  /// An elapsed time to display instead of the internally measured one.
  ///
  /// When non-null no internal timer runs; rebuild with a new value to
  /// update the display.
  final Duration? elapsed;

  /// Whether the work is in progress. When `false` the wave stops, the
  /// cells dim and the stopwatch freezes. Turning it back to `true` starts
  /// a new measurement from zero. Defaults to `true`.
  final bool active;

  /// Replaces the label in the announcement for assistive technology.
  /// Defaults to [label], or 'Working' when there is no label.
  final String? semanticLabel;

  /// When `false` the lattice is still (no wave, no frames) but the
  /// stopwatch still counts. Defaults to `true`.
  final bool enabled;

  /// Formats [elapsed] as a stopwatch: '00:07', '12:30', or '1:02:03'
  /// from one hour on.
  static String formatElapsed(Duration elapsed) {
    final int total = elapsed.inSeconds;
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  State<LatticeLoader> createState() => _LatticeLoaderState();
}

class _LatticeLoaderState extends State<LatticeLoader>
    with SingleTickerProviderStateMixin {
  /// Wave phase of the still frame shown when nothing animates.
  static const double _stillPhase = 0.3;

  late final AnimationController _wave;
  late final ValueNotifier<Duration> _elapsed;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _clock;
  int _ticks = 0;
  bool _reduced = false;

  bool get _animate => widget.enabled && !_reduced && widget.active;

  bool get _clockShouldRun => widget.active && widget.elapsed == null;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(vsync: this, duration: _period);
    _elapsed = ValueNotifier<Duration>(widget.elapsed ?? Duration.zero);
    if (_clockShouldRun) {
      _startClock();
    }
  }

  Duration get _period =>
      Duration(microseconds: (1e6 / widget.waveSpeed).round());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _syncWave();
  }

  @override
  void didUpdateWidget(LatticeLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waveSpeed != oldWidget.waveSpeed) {
      final double value = _wave.value;
      _wave.duration = _period;
      if (_wave.isAnimating) {
        // Restart the loop from the same phase so the new speed applies.
        _wave
          ..value = value
          ..repeat();
      }
    }
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        // A new run: measure from zero again.
        _stopClock();
        _ticks = 0;
        _stopwatch.reset();
        if (_clockShouldRun) {
          _startClock();
        }
      } else {
        _stopClock();
      }
    } else if (widget.elapsed != oldWidget.elapsed) {
      if (_clockShouldRun && _clock == null) {
        _startClock();
      } else if (!_clockShouldRun) {
        _stopClock();
      }
    }
    _syncWave();
    _publish();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopwatch.stop();
    _wave.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _syncWave() {
    if (_animate) {
      if (!_wave.isAnimating) {
        _wave.repeat();
      }
    } else if (_wave.isAnimating) {
      _wave.stop();
    }
  }

  void _startClock() {
    _clock?.cancel();
    _stopwatch.start();
    // Timer.tick counts elapsed periods even when events are delayed, and
    // advances with fake time in tests where the Stopwatch does not.
    final int base = _ticks;
    _clock = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        return;
      }
      _ticks = base + timer.tick;
      _publish();
    });
    _publish();
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
    _stopwatch.stop();
  }

  Duration get _measured {
    final Duration ticked = Duration(seconds: _ticks);
    final Duration watched = _stopwatch.elapsed;
    return watched > ticked ? watched : ticked;
  }

  void _publish() {
    _elapsed.value = widget.elapsed ?? _measured;
  }

  static String _spoken(Duration elapsed) {
    final int total = elapsed.inSeconds;
    final int minutes = total ~/ 60;
    final int seconds = total % 60;
    final String s = seconds == 1 ? '1 second' : '$seconds seconds';
    if (minutes == 0) {
      return s;
    }
    return '${minutes == 1 ? '1 minute' : '$minutes minutes'} $s';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle labelStyle =
        widget.labelStyle ??
        theme.textTheme.labelLarge?.copyWith(color: scheme.onSurface) ??
        TextStyle(fontSize: 14.0, color: scheme.onSurface);
    final TextStyle timerStyle =
        (widget.timerStyle ??
                labelStyle.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ))
            .copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            );

    final double width =
        widget.columns * widget.cellSize + (widget.columns - 1) * widget.gap;
    final double height =
        widget.rows * widget.cellSize + (widget.rows - 1) * widget.gap;

    final Widget lattice = RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _LatticePainter(
          wave: _wave,
          animated: _animate,
          stillPhase: _stillPhase,
          dimmed: !widget.active,
          columns: widget.columns,
          rows: widget.rows,
          cellSize: widget.cellSize,
          gap: widget.gap,
          color: widget.color ?? scheme.primary,
          textDirection: Directionality.of(context),
        ),
      ),
    );

    final String? label = widget.label;
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        lattice,
        if (label != null && label.isNotEmpty) ...<Widget>[
          const SizedBox(width: 10.0),
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (widget.showTimer) ...<Widget>[
          SizedBox(width: label != null && label.isNotEmpty ? 8.0 : 10.0),
          ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (BuildContext context, Duration value, Widget? child) {
              return Text(
                LatticeLoader.formatElapsed(value),
                style: timerStyle,
                maxLines: 1,
              );
            },
          ),
        ],
      ],
    );

    final String name = widget.semanticLabel ?? label ?? 'Working';
    if (!widget.showTimer) {
      return Semantics(
        container: true,
        label: name,
        child: ExcludeSemantics(child: row),
      );
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: _elapsed,
      child: ExcludeSemantics(child: row),
      builder: (BuildContext context, Duration value, Widget? child) {
        return Semantics(
          container: true,
          label: '$name, ${_spoken(value)}',
          child: child,
        );
      },
    );
  }
}

/// Paints the lattice cells, each brightened by a diagonal sine wave.
class _LatticePainter extends CustomPainter {
  _LatticePainter({
    required this.wave,
    required this.animated,
    required this.stillPhase,
    required this.dimmed,
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.gap,
    required this.color,
    required this.textDirection,
  }) : super(repaint: wave);

  /// Wave position, one full cycle from 0 to 1.
  final Animation<double> wave;

  /// Whether [wave] drives the cells; otherwise [stillPhase] is used.
  final bool animated;
  final double stillPhase;

  /// Whether the cells are drawn dim and flat (work finished).
  final bool dimmed;
  final int columns;
  final int rows;
  final double cellSize;
  final double gap;
  final Color color;
  final TextDirection textDirection;

  /// Opacity of a cell at the bottom of the wave.
  static const double _minOpacity = 0.16;

  /// Scale of a cell at the bottom of the wave.
  static const double _minScale = 0.62;

  /// Fraction of a wave cycle between two neighbouring diagonals.
  static const double _diagonalStep = 0.11;

  /// Opacity of every cell when dimmed.
  static const double _dimOpacity = 0.28;

  final Paint _paint = Paint();

  /// The brightness, in `[0, 1]`, of the cell at [column], [row] for the
  /// wave position [phase].
  double intensity(int column, int row, double phase) {
    final double x = (phase - (column + row) * _diagonalStep) * 2 * math.pi;
    final double s = 0.5 + 0.5 * math.sin(x);
    // Squaring sharpens the crest so the light reads as a travelling band.
    return s * s;
  }

  /// The wave position currently painted.
  double get phase => animated ? wave.value : stillPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final double p = phase;
    final bool rtl = textDirection == TextDirection.rtl;
    final double radius = cellSize * 0.32;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final double i = dimmed ? 0.0 : intensity(c, r, p);
        final double opacity = dimmed
            ? _dimOpacity
            : _minOpacity + (1.0 - _minOpacity) * i;
        final double scale = dimmed ? 0.8 : _minScale + (1.0 - _minScale) * i;
        final int column = rtl ? columns - 1 - c : c;
        final double cx = column * (cellSize + gap) + cellSize / 2;
        final double cy = r * (cellSize + gap) + cellSize / 2;
        final double side = cellSize * scale;
        _paint.color = color.withValues(alpha: color.a * opacity);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: side, height: side),
            Radius.circular(radius * scale),
          ),
          _paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter oldDelegate) {
    return oldDelegate.wave != wave ||
        oldDelegate.animated != animated ||
        oldDelegate.stillPhase != stillPhase ||
        oldDelegate.dimmed != dimmed ||
        oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color ||
        oldDelegate.textDirection != textDirection;
  }
}
