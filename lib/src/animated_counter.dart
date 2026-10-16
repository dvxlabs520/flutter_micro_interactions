import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// How an [AnimatedCounter] animates between values.
enum CounterAnimationMode {
  /// Tweens numerically from the old value to the new one, rendering the
  /// formatted intermediate value each frame (classic count-up/count-down).
  count,

  /// Each character that changed slides vertically to the new one, like a
  /// mechanical odometer. Digits slide up when the value increases and down
  /// when it decreases. Columns are aligned by place value: when the number
  /// gains a digit the new leading column rolls in, when it loses one the
  /// column rolls out, and the width animates between the two.
  slideDigits,
}

/// A text widget that animates changes of a numeric value.
///
/// Useful for statistics, prices, like counts and dashboard tiles. Give it a
/// new [value] and it animates from the previous one; no controller is
/// needed.
///
/// ```dart
/// AnimatedCounter(
///   value: likeCount,
///   duration: const Duration(milliseconds: 400),
///   style: Theme.of(context).textTheme.headlineMedium,
/// )
/// ```
///
/// Two animation styles are available through [mode]:
///
/// * [CounterAnimationMode.count] tweens the number itself and renders the
///   formatted intermediate value each frame.
/// * [CounterAnimationMode.slideDigits] keeps the number fixed and slides
///   each changed character vertically to its new value (odometer style).
///   Digits use tabular figures so the layout does not jump, columns are
///   aligned by place value (units stay units), added or removed leading
///   digits roll in or out while the width animates, and each column is
///   clipped to exactly one line (a forced strut) so neighbouring digits
///   never peek through. Numbers always read left to right, also in
///   right-to-left locales.
///
/// Rapid successive value changes retarget smoothly from the current
/// animated value.
///
/// Formatting: pass a [formatter] for full control, or use the built-in
/// conveniences [fractionDigits], [thousandsSeparator], [prefix] and
/// [suffix] (ignored when [formatter] is set):
///
/// ```dart
/// AnimatedCounter(
///   value: balance,
///   fractionDigits: 2,
///   thousandsSeparator: ',',
///   prefix: r'$',
/// ) // renders $1,234.50
/// ```
///
/// In [CounterAnimationMode.slideDigits] the prefix, the suffix and the
/// thousands separators are static: they never roll, only the digits do (a
/// separator that appears or disappears with a new digit group fades and
/// resizes instead).
///
/// Accessibility: the widget always exposes the final target value as its
/// semantics label, never a mid-animation value. [semanticLabel] overrides
/// the default formatted label.
///
/// Reduced motion (or [enabled] set to `false`): the text jumps instantly
/// to the new value.
class AnimatedCounter extends StatefulWidget {
  /// Creates an animated counter.
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.style,
    this.formatter,
    this.mode = CounterAnimationMode.count,
    this.semanticLabel,
    this.enabled = true,
    this.fractionDigits,
    this.prefix,
    this.suffix,
    this.thousandsSeparator,
  }) : assert(
         fractionDigits == null ||
             (fractionDigits >= 0 && fractionDigits <= 20),
         'fractionDigits must be between 0 and 20',
       );

  /// The value to display. Changing it triggers the animation.
  final num value;

  /// Duration of the animation. Defaults to 500 milliseconds.
  final Duration duration;

  /// Curve of the animation. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Text style of the rendered value. Falls back to the ambient
  /// [DefaultTextStyle].
  final TextStyle? style;

  /// Converts a value to the string that is rendered.
  ///
  /// The default formats integers with [num.toString] and doubles with the
  /// same number of decimal places as [value], then applies
  /// [fractionDigits], [thousandsSeparator], [prefix] and [suffix]. When a
  /// formatter is given, those four parameters are ignored.
  final String Function(num value)? formatter;

  /// How value changes are animated. Defaults to
  /// [CounterAnimationMode.count].
  final CounterAnimationMode mode;

  /// Semantics label exposed to assistive technology. Defaults to the
  /// formatted target value.
  final String? semanticLabel;

  /// When `false`, value changes are applied instantly without animation.
  final bool enabled;

  /// The exact number of decimal places to render, between 0 and 20.
  ///
  /// When null (the default), integers render without decimals and doubles
  /// with the same number of decimal places as [value]. Ignored when
  /// [formatter] is set.
  final int? fractionDigits;

  /// Text rendered before the number, for example a currency symbol such
  /// as `r'$'`. Static in [CounterAnimationMode.slideDigits]. Ignored when
  /// [formatter] is set.
  final String? prefix;

  /// Text rendered after the number, for example `'%'` or `' pts'`. Static
  /// in [CounterAnimationMode.slideDigits]. Ignored when [formatter] is
  /// set.
  final String? suffix;

  /// Inserted between every group of three integer digits, for example
  /// `','` renders `1234567` as `1,234,567`. When null (the default) no
  /// grouping is applied. Separators are static in
  /// [CounterAnimationMode.slideDigits]. Ignored when [formatter] is set.
  final String? thousandsSeparator;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;
  late Tween<double> _tween;

  /// The value [CounterAnimationMode.slideDigits] rolls away from.
  late num _fromValue;

  /// Whether the last value change was an increase (drives the slide
  /// direction in [CounterAnimationMode.slideDigits]).
  bool _increasing = true;

  /// Glyph advance widths for [CounterAnimationMode.slideDigits], measured
  /// with [_metricsStyle] and [_metricsScaler]. Cleared when either changes.
  final Map<String, double> _glyphWidths = <String, double>{};
  double _lineHeight = 0.0;
  TextStyle? _metricsStyle;
  TextScaler? _metricsScaler;
  Locale? _metricsLocale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _tween = Tween<double>(
      begin: widget.value.toDouble(),
      end: widget.value.toDouble(),
    );
    _controller.value = 1.0;
    _fromValue = widget.value;
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.value != oldWidget.value) {
      // Roll away from what is mostly on screen: the previous target, or
      // the value before it when the previous roll had barely started.
      if (!_controller.isAnimating || _animation.value >= 0.5) {
        _fromValue = oldWidget.value;
      }
      if (widget.value != _fromValue) {
        _increasing = widget.value > _fromValue;
      }
      // Retarget from the current animated value so rapid changes stay
      // smooth instead of restarting from the previous target.
      final double current = _tween.evaluate(_animation);
      _tween = Tween<double>(begin: current, end: widget.value.toDouble());
      if (!widget.enabled || MicroMotion.isReduced(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Formats [value] with [AnimatedCounter.formatter] or the default rule,
  /// including the prefix and suffix.
  String _format(num value) {
    final _CounterParts parts = _parts(value);
    return '${parts.prefix}${parts.body}${parts.suffix}';
  }

  /// Splits the formatted [value] into a static prefix, a body and a static
  /// suffix. [_CounterParts.staticMask] marks the body characters that are
  /// thousands separators.
  _CounterParts _parts(num value) {
    final String Function(num)? formatter = widget.formatter;
    if (formatter != null) {
      final String text = formatter(value);
      return _CounterParts('', text, List<bool>.filled(text.length, false), '');
    }
    final String raw;
    final int? fractionDigits = widget.fractionDigits;
    if (fractionDigits != null) {
      raw = value.toDouble().toStringAsFixed(fractionDigits);
    } else if (widget.value is int) {
      raw = value.round().toString();
    } else {
      final String target = widget.value.toString();
      final int dot = target.indexOf('.');
      final int decimals = dot == -1 ? 0 : target.length - dot - 1;
      raw = value.toDouble().toStringAsFixed(decimals);
    }

    final String? separator = widget.thousandsSeparator;
    final String body;
    final List<bool> staticMask;
    if (separator == null || separator.isEmpty) {
      body = raw;
      staticMask = List<bool>.filled(raw.length, false);
    } else {
      final StringBuffer buffer = StringBuffer();
      staticMask = <bool>[];
      // Group only the integer digits, after any leading sign.
      int start = 0;
      while (start < raw.length && !_isDigit(raw.codeUnitAt(start))) {
        start++;
      }
      int end = start;
      while (end < raw.length && _isDigit(raw.codeUnitAt(end))) {
        end++;
      }
      for (int i = 0; i < raw.length; i++) {
        if (i > start && i < end && (end - i) % 3 == 0) {
          buffer.write(separator);
          staticMask.addAll(List<bool>.filled(separator.length, true));
        }
        buffer.write(raw[i]);
        staticMask.add(false);
      }
      body = buffer.toString();
    }
    return _CounterParts(
      widget.prefix ?? '',
      body,
      staticMask,
      widget.suffix ?? '',
    );
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  Widget _buildCount(TextStyle? style) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return Text(_format(_tween.evaluate(_animation)), style: style);
      },
    );
  }

  /// Measures glyphs for [CounterAnimationMode.slideDigits], reusing the
  /// cache while the style, text scaler and locale are unchanged.
  void _updateMetrics(TextStyle style, TextScaler scaler, Locale? locale) {
    if (style == _metricsStyle &&
        scaler == _metricsScaler &&
        locale == _metricsLocale) {
      return;
    }
    _metricsStyle = style;
    _metricsScaler = scaler;
    _metricsLocale = locale;
    _glyphWidths.clear();
    final TextPainter painter = _painter('0');
    _lineHeight = painter.height;
    painter.dispose();
  }

  TextPainter _painter(String text) {
    final TextStyle style = _metricsStyle!;
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: _metricsScaler!,
      locale: _metricsLocale,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      maxLines: 1,
    )..layout();
  }

  double _glyphWidth(String glyph) {
    return _glyphWidths.putIfAbsent(glyph, () {
      final TextPainter painter = _painter(glyph);
      final double width = painter.width;
      painter.dispose();
      return width;
    });
  }

  Widget _glyph(String text, TextStyle style, StrutStyle strut) {
    return Text(
      text,
      style: style,
      strutStyle: strut,
      textScaler: _metricsScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
    );
  }

  Widget _buildSlideDigits(BuildContext context, TextStyle? style) {
    // Tabular figures keep every digit the same width so the layout does
    // not jump while characters slide. A forced strut makes every glyph
    // box exactly one line tall, so the clip below hides the neighbouring
    // characters completely.
    final TextStyle effectiveStyle = DefaultTextStyle.of(context).style
        .merge(style)
        .copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    _updateMetrics(
      effectiveStyle,
      MediaQuery.textScalerOf(context),
      Localizations.maybeLocaleOf(context),
    );
    final StrutStyle strut = StrutStyle.fromTextStyle(
      effectiveStyle,
      forceStrutHeight: true,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        final _CounterParts to = _parts(widget.value);
        final _CounterParts from = _parts(_fromValue);
        final bool settled =
            !_controller.isAnimating || _fromValue == widget.value;
        final double t = settled ? 1.0 : _animation.value;
        final double height = _lineHeight;
        final double direction = _increasing ? 1.0 : -1.0;
        final int columns = settled
            ? to.body.length
            : (to.body.length > from.body.length
                  ? to.body.length
                  : from.body.length);

        final List<Widget> children = <Widget>[];
        if (to.prefix.isNotEmpty) {
          children.add(_glyph(to.prefix, effectiveStyle, strut));
        }
        // Columns are aligned by place value from the right, so units stay
        // units and a new leading digit rolls in at the left.
        for (int k = columns - 1; k >= 0; k--) {
          final int toIndex = to.body.length - 1 - k;
          final int fromIndex = from.body.length - 1 - k;
          final String? next = toIndex >= 0 ? to.body[toIndex] : null;
          final String? previous = settled
              ? next
              : (fromIndex >= 0 ? from.body[fromIndex] : null);
          if (previous == next) {
            children.add(
              SizedBox(
                width: _glyphWidth(next!),
                height: height,
                child: _glyph(next, effectiveStyle, strut),
              ),
            );
            continue;
          }
          final bool fade =
              (toIndex >= 0 && to.staticMask[toIndex]) ||
              (fromIndex >= 0 && from.staticMask[fromIndex]);
          final double previousWidth = previous == null
              ? 0.0
              : _glyphWidth(previous);
          final double nextWidth = next == null ? 0.0 : _glyphWidth(next);
          final double width = lerpDouble(previousWidth, nextWidth, t)!;
          final List<Widget> layers = <Widget>[];
          if (previous != null) {
            Widget outgoing = _glyph(previous, effectiveStyle, strut);
            if (fade) {
              outgoing = Opacity(opacity: 1.0 - t, child: outgoing);
            }
            layers.add(
              Positioned(
                left: (width - previousWidth) / 2,
                top: fade ? 0.0 : -direction * t * height,
                width: previousWidth,
                height: height,
                child: outgoing,
              ),
            );
          }
          if (next != null) {
            Widget incoming = _glyph(next, effectiveStyle, strut);
            if (fade) {
              incoming = Opacity(opacity: t, child: incoming);
            }
            layers.add(
              Positioned(
                left: (width - nextWidth) / 2,
                top: fade ? 0.0 : direction * (1.0 - t) * height,
                width: nextWidth,
                height: height,
                child: incoming,
              ),
            );
          }
          children.add(
            SizedBox(
              width: width,
              height: height,
              // Clip to the exact line box: only the rolling glyphs show.
              child: Stack(clipBehavior: Clip.hardEdge, children: layers),
            ),
          );
        }
        if (to.suffix.isNotEmpty) {
          children.add(_glyph(to.suffix, effectiveStyle, strut));
        }
        // Numbers read left to right even in right-to-left locales.
        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: children,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (widget.mode) {
      CounterAnimationMode.count => _buildCount(widget.style),
      CounterAnimationMode.slideDigits => _buildSlideDigits(
        context,
        widget.style,
      ),
    };
    // Always expose the final target value, never a mid-animation value.
    return Semantics(
      label: widget.semanticLabel ?? _format(widget.value),
      container: true,
      child: ExcludeSemantics(child: content),
    );
  }
}

/// The formatted pieces of a counter value.
class _CounterParts {
  const _CounterParts(this.prefix, this.body, this.staticMask, this.suffix);

  /// Static text before the number.
  final String prefix;

  /// The number itself, including any thousands separators.
  final String body;

  /// One entry per [body] code unit; `true` for separator characters that
  /// must not roll.
  final List<bool> staticMask;

  /// Static text after the number.
  final String suffix;
}
