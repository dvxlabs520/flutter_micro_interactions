import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// The outline shape of a [LiquidProgress] indicator.
enum LiquidProgressShape {
  /// A circle of diameter [LiquidProgress.size].
  circle,

  /// A rounded rectangle of [LiquidProgress.width] by
  /// [LiquidProgress.height], rounded by [LiquidProgress.borderRadius].
  rectangle,
}

/// A progress indicator filled with an animated liquid wave.
///
/// The fill level tracks [value] with an implicit animation that retargets
/// smoothly from the current animated level on every change, while two
/// phase-shifted sine waves scroll horizontally to make the surface look
/// liquid.
///
/// ```dart
/// LiquidProgress(
///   value: downloadProgress,
///   showPercentage: true,
/// )
/// ```
///
/// The percentage label stays legible over both the liquid and the
/// background: it is rendered twice, once in a color contrasting with the
/// background and once in a color contrasting with the liquid, with the
/// second copy clipped to the liquid area.
///
/// Accessibility: exposed as `Semantics(label, value: '<percent> percent')`
/// using the target [value], never a mid-animation level. The painted
/// internals are excluded from the semantics tree.
///
/// Reduced motion (or [animateWave] false): the wave stops scrolling and
/// renders as a static line; reduced motion (or [enabled] false) also makes
/// value changes jump instantly.
class LiquidProgress extends StatefulWidget {
  /// Creates a liquid progress indicator.
  const LiquidProgress({
    super.key,
    required this.value,
    this.shape = LiquidProgressShape.circle,
    this.size = 96.0,
    this.width,
    this.height,
    this.borderRadius,
    this.liquidColor,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 2.0,
    this.waveAmplitude = 6.0,
    this.waveDuration = const Duration(seconds: 2),
    this.valueDuration = const Duration(milliseconds: 600),
    this.valueCurve = Curves.easeOutCubic,
    this.center,
    this.showPercentage = false,
    this.percentageStyle,
    this.animateWave = true,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(value >= 0.0 && value <= 1.0, 'value must be within 0..1'),
       assert(size > 0.0, 'size must be positive'),
       assert(borderWidth >= 0.0, 'borderWidth must not be negative'),
       assert(waveAmplitude >= 0.0, 'waveAmplitude must not be negative');

  /// The progress, from 0.0 (empty) to 1.0 (full). Changing it animates
  /// the fill level to the new target.
  final double value;

  /// The outline shape. Defaults to [LiquidProgressShape.circle].
  final LiquidProgressShape shape;

  /// Diameter of the circle shape. Defaults to 96.0.
  final double size;

  /// Width of the rectangle shape. Defaults to 160.0.
  final double? width;

  /// Height of the rectangle shape. Defaults to 72.0.
  final double? height;

  /// Corner rounding of the rectangle shape. Defaults to a circular
  /// radius of 12. Ignored for [LiquidProgressShape.circle].
  final BorderRadius? borderRadius;

  /// Color of the liquid. Defaults to the theme's `colorScheme.primary`.
  final Color? liquidColor;

  /// Color behind the liquid. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? backgroundColor;

  /// Color of the outline. Defaults to the effective [liquidColor].
  final Color? borderColor;

  /// Stroke width of the outline. Zero hides it. Defaults to 2.0.
  final double borderWidth;

  /// Peak height of the main wave in logical pixels. The wave flattens
  /// automatically near empty and full so the liquid never overflows the
  /// shape. Defaults to 6.0.
  final double waveAmplitude;

  /// Duration of one full horizontal wave cycle. Defaults to 2 seconds.
  final Duration waveDuration;

  /// Duration of the fill-level animation between values. Defaults to
  /// 600 milliseconds.
  final Duration valueDuration;

  /// Curve of the fill-level animation. Defaults to [Curves.easeOutCubic].
  final Curve valueCurve;

  /// Optional overlay content centered on the indicator, for example a
  /// custom label. When null and [showPercentage] is true, a percentage
  /// label is rendered instead.
  final Widget? center;

  /// Whether to render a percentage label when [center] is null.
  /// Defaults to false.
  final bool showPercentage;

  /// Base style of the percentage label. The label is auto-contrasted:
  /// its color over the liquid is derived from the liquid color, and the
  /// style's own color (or a background-contrasting default) is used over
  /// the background.
  final TextStyle? percentageStyle;

  /// Whether the wave scrolls horizontally. When false the surface is a
  /// static line. Defaults to true.
  final bool animateWave;

  /// When false the wave stops and value changes apply instantly.
  final bool enabled;

  /// Semantics label. Defaults to 'Progress'.
  final String? semanticLabel;

  @override
  State<LiquidProgress> createState() => _LiquidProgressState();
}

class _LiquidProgressState extends State<LiquidProgress>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _levelController;
  late CurvedAnimation _levelCurve;
  late Tween<double> _levelTween;
  late Animation<double> _level;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: widget.waveDuration,
    );
    _levelController = AnimationController(
      vsync: this,
      duration: widget.valueDuration,
    );
    _levelCurve = CurvedAnimation(
      parent: _levelController,
      curve: widget.valueCurve,
    );
    _levelTween = Tween<double>(begin: widget.value, end: widget.value);
    _level = _levelCurve.drive(_levelTween);
    _levelController.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (_reduced && _levelController.isAnimating) {
      _levelController.value = 1.0;
    }
    _syncWave();
  }

  @override
  void didUpdateWidget(LiquidProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waveDuration != oldWidget.waveDuration) {
      _waveController.duration = widget.waveDuration;
      if (_waveController.isAnimating) {
        _waveController
          ..stop()
          ..repeat();
      }
    }
    if (widget.valueDuration != oldWidget.valueDuration) {
      _levelController.duration = widget.valueDuration;
    }
    if (widget.valueCurve != oldWidget.valueCurve) {
      _levelCurve.dispose();
      _levelCurve = CurvedAnimation(
        parent: _levelController,
        curve: widget.valueCurve,
      );
      _level = _levelCurve.drive(_levelTween);
    }
    if (widget.value != oldWidget.value) {
      // Retarget from the current animated level so rapid changes stay
      // smooth instead of restarting from the previous target.
      final double current = _levelTween.evaluate(_levelCurve);
      _levelTween = Tween<double>(begin: current, end: widget.value);
      _level = _levelCurve.drive(_levelTween);
      if (!widget.enabled || _reduced) {
        _levelController.value = 1.0;
      } else {
        _levelController.forward(from: 0.0);
      }
    }
    if (widget.animateWave != oldWidget.animateWave ||
        widget.enabled != oldWidget.enabled) {
      if (!widget.enabled && _levelController.isAnimating) {
        _levelController.value = 1.0;
      }
      _syncWave();
    }
  }

  @override
  void dispose() {
    _levelCurve.dispose();
    _levelController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  /// Starts or stops the horizontal wave scroll. Never loops under
  /// reduced motion, when [LiquidProgress.animateWave] is false, or when
  /// the widget is disabled.
  void _syncWave() {
    final bool animate = widget.animateWave && widget.enabled && !_reduced;
    if (animate) {
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
      _waveController.value = 0.0;
    }
  }

  /// Black or white, whichever contrasts with [background].
  static Color _contrastOn(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Widget? _buildOverlay(
    BuildContext context,
    Color liquidColor,
    Color backgroundColor,
  ) {
    if (widget.center != null) {
      return Center(child: widget.center);
    }
    if (!widget.showPercentage) return null;
    final String label = '${(widget.value * 100).round()}%';
    final TextStyle base =
        widget.percentageStyle ??
        Theme.of(context).textTheme.titleMedium ??
        const TextStyle();
    final TextStyle overBackground = base.color != null
        ? base
        : base.copyWith(color: _contrastOn(backgroundColor));
    final TextStyle overLiquid = base.copyWith(color: _contrastOn(liquidColor));
    // Classic two-layer technique: the base label contrasts with the
    // background; a second copy, clipped to the liquid area, contrasts
    // with the liquid. Together the text is legible at any fill level.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(child: Text(label, style: overBackground)),
        ClipPath(
          clipper: _LiquidClipper(
            level: _level,
            phase: _waveController,
            amplitude: widget.waveAmplitude,
            shape: widget.shape,
            borderRadius: _effectiveBorderRadius,
          ),
          child: Center(child: Text(label, style: overLiquid)),
        ),
      ],
    );
  }

  BorderRadius get _effectiveBorderRadius =>
      widget.borderRadius ?? const BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color liquidColor = widget.liquidColor ?? scheme.primary;
    final Color backgroundColor =
        widget.backgroundColor ?? scheme.surfaceContainerHighest;
    final Color borderColor = widget.borderColor ?? liquidColor;
    final bool isCircle = widget.shape == LiquidProgressShape.circle;
    final double width = isCircle ? widget.size : (widget.width ?? 160.0);
    final double height = isCircle ? widget.size : (widget.height ?? 72.0);
    final Widget? overlay = _buildOverlay(
      context,
      liquidColor,
      backgroundColor,
    );

    // The semantics value always reports the target value, never a
    // mid-animation level; the painter is excluded entirely.
    return Semantics(
      label: widget.semanticLabel ?? 'Progress',
      value: '${(widget.value * 100).round()} percent',
      container: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CustomPaint(
                  painter: _LiquidProgressPainter(
                    level: _level,
                    phase: _waveController,
                    liquidColor: liquidColor,
                    backgroundColor: backgroundColor,
                    borderColor: borderColor,
                    borderWidth: widget.borderWidth,
                    amplitude: widget.waveAmplitude,
                    shape: widget.shape,
                    borderRadius: _effectiveBorderRadius,
                  ),
                ),
                if (overlay != null) overlay,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the outline path of the indicator for [size].
Path _shapePath(
  Size size,
  LiquidProgressShape shape,
  BorderRadius borderRadius,
) {
  final Rect rect = Offset.zero & size;
  return switch (shape) {
    LiquidProgressShape.circle => Path()..addOval(rect),
    LiquidProgressShape.rectangle =>
      Path()..addRRect(borderRadius.toRRect(rect)),
  };
}

/// Builds the liquid surface path for the given fill [level] (0..1) and
/// horizontal wave [phase] (0..1 of one cycle).
///
/// The sine completes a whole number of cycles across the width
/// (`2 * pi * n`), so the wave tiles seamlessly while it scrolls. The
/// amplitude is clamped to the space above and below the surface line so
/// the liquid never pokes outside the shape at levels near 0 or 1.
Path _liquidPath(
  Size size,
  double level,
  double phase,
  double amplitude, {
  double phaseShift = 0.0,
}) {
  final double clamped = level.clamp(0.0, 1.0);
  if (clamped <= 0.0) return Path();
  final double w = size.width;
  final double h = size.height;
  final double surfaceY = h * (1.0 - clamped);
  final double amp = math
      .min(amplitude, math.min(surfaceY, h - surfaceY))
      .clamp(0.0, h);
  final int cycles = math.max(1, (w / 80.0).round());
  final int samples = cycles * 24;
  double waveY(double x) =>
      surfaceY +
      amp * math.sin(2 * math.pi * (cycles * x / w + phase + phaseShift));
  final Path path = Path()..moveTo(0, waveY(0));
  for (int i = 1; i <= samples; i++) {
    final double x = w * i / samples;
    path.lineTo(x, waveY(x));
  }
  path
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  return path;
}

class _LiquidProgressPainter extends CustomPainter {
  _LiquidProgressPainter({
    required this.level,
    required this.phase,
    required this.liquidColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.amplitude,
    required this.shape,
    required this.borderRadius,
  }) : super(repaint: Listenable.merge(<Listenable>[level, phase]));

  final Animation<double> level;
  final Animation<double> phase;
  final Color liquidColor;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double amplitude;
  final LiquidProgressShape shape;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outline = _shapePath(size, shape, borderRadius);
    canvas.save();
    canvas.clipPath(outline);
    canvas.drawPath(outline, Paint()..color = backgroundColor);

    final double currentLevel = level.value.clamp(0.0, 1.0);
    if (currentLevel > 0.0) {
      // Secondary wave: slightly smaller, phase-shifted, translucent.
      canvas.drawPath(
        _liquidPath(
          size,
          currentLevel,
          phase.value,
          amplitude * 0.8,
          phaseShift: 0.25,
        ),
        Paint()..color = liquidColor.withValues(alpha: liquidColor.a * 0.4),
      );
      canvas.drawPath(
        _liquidPath(size, currentLevel, phase.value, amplitude),
        Paint()..color = liquidColor,
      );
    }
    canvas.restore();

    if (borderWidth > 0.0) {
      final Rect inset = (Offset.zero & size).deflate(borderWidth / 2);
      final Path borderPath = switch (shape) {
        LiquidProgressShape.circle => Path()..addOval(inset),
        LiquidProgressShape.rectangle =>
          Path()..addRRect(
            borderRadius.toRRect(Offset.zero & size).deflate(borderWidth / 2),
          ),
      };
      canvas.drawPath(
        borderPath,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidProgressPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.shape != shape ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// Clips its child to the liquid area, intersected with the outline
/// shape. Used for the contrasting copy of the percentage label.
class _LiquidClipper extends CustomClipper<Path> {
  _LiquidClipper({
    required this.level,
    required this.phase,
    required this.amplitude,
    required this.shape,
    required this.borderRadius,
  }) : super(reclip: Listenable.merge(<Listenable>[level, phase]));

  final Animation<double> level;
  final Animation<double> phase;
  final double amplitude;
  final LiquidProgressShape shape;
  final BorderRadius borderRadius;

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.intersect,
      _shapePath(size, shape, borderRadius),
      _liquidPath(size, level.value, phase.value, amplitude),
    );
  }

  @override
  bool shouldReclip(covariant _LiquidClipper oldClipper) {
    return oldClipper.level != level ||
        oldClipper.phase != phase ||
        oldClipper.amplitude != amplitude ||
        oldClipper.shape != shape ||
        oldClipper.borderRadius != borderRadius;
  }
}
