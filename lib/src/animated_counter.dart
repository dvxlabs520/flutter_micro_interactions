import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// How an [AnimatedCounter] animates between values.
enum CounterAnimationMode {
  /// Tweens numerically from the old value to the new one, rendering the
  /// formatted intermediate value each frame (classic count-up/count-down).
  count,

  /// Each character that changed slides vertically to the new one, like a
  /// mechanical odometer. Digits slide up when the value increases and down
  /// when it decreases.
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
///   Digits use tabular figures so the layout does not jump.
///
/// Rapid successive value changes retarget smoothly from the current
/// animated value.
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
  });

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
  /// same number of decimal places as [value].
  final String Function(num value)? formatter;

  /// How value changes are animated. Defaults to
  /// [CounterAnimationMode.count].
  final CounterAnimationMode mode;

  /// Semantics label exposed to assistive technology. Defaults to the
  /// formatted target value.
  final String? semanticLabel;

  /// When `false`, value changes are applied instantly without animation.
  final bool enabled;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _animation;
  late Tween<double> _tween;

  /// Rendered width (in characters) for [CounterAnimationMode.slideDigits],
  /// so the string can be padded when the previous value was longer.
  int _padWidth = 0;

  /// Whether the last value change was an increase (drives the slide
  /// direction in [CounterAnimationMode.slideDigits]).
  bool _increasing = true;

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
    _padWidth = _format(widget.value).length;
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
      _increasing = widget.value > oldWidget.value;
      _padWidth = math.max(
        _format(oldWidget.value).length,
        _format(widget.value).length,
      );
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

  /// Formats [value] with [AnimatedCounter.formatter] or the default rule:
  /// integers as-is, doubles with the same decimal places as the target
  /// value.
  String _format(num value) {
    final String Function(num)? formatter = widget.formatter;
    if (formatter != null) {
      return formatter(value);
    }
    if (widget.value is int) {
      return value.round().toString();
    }
    final String target = widget.value.toString();
    final int dot = target.indexOf('.');
    final int decimals = dot == -1 ? 0 : target.length - dot - 1;
    return value.toDouble().toStringAsFixed(decimals);
  }

  Widget _buildCount(TextStyle? style) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return Text(_format(_tween.evaluate(_animation)), style: style);
      },
    );
  }

  Widget _buildSlideDigits(BuildContext context, TextStyle? style) {
    // Tabular figures keep every digit the same width so the layout does
    // not jump while characters slide.
    final TextStyle digitStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final String text =
        _format(widget.value).padLeft(_padWidth);
    final Duration duration = !widget.enabled
        ? Duration.zero
        : MicroMotion.effectiveDuration(context, widget.duration);
    final double enterFrom = _increasing ? 1.0 : -1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < text.length; i++)
          ClipRect(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: widget.curve,
              switchOutCurve: widget.curve,
              transitionBuilder: (Widget child, Animation<double> animation) {
                // The incoming character carries the key of the current
                // text; the outgoing one exits toward the opposite side.
                final bool incoming =
                    child.key == ValueKey<String>('$i-${text[i]}');
                final Tween<Offset> slide = Tween<Offset>(
                  begin: Offset(0, incoming ? enterFrom : -enterFrom),
                  end: Offset.zero,
                );
                return SlideTransition(
                  position: slide.animate(animation),
                  child: child,
                );
              },
              child: Text(
                text[i],
                key: ValueKey<String>('$i-${text[i]}'),
                style: digitStyle,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (widget.mode) {
      CounterAnimationMode.count => _buildCount(widget.style),
      CounterAnimationMode.slideDigits =>
        _buildSlideDigits(context, widget.style),
    };
    // Always expose the final target value, never a mid-animation value.
    return Semantics(
      label: widget.semanticLabel ?? _format(widget.value),
      container: true,
      child: ExcludeSemantics(child: content),
    );
  }
}
