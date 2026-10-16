import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'status_mark.dart';
import 'utils/motion.dart';

/// One step of a [ThinkingSteps] trace.
///
/// ```dart
/// const ThinkingStep(
///   title: 'Searching the docs',
///   detail: '3 pages found',
///   status: MicroStatus.success,
/// )
/// ```
///
/// [MicroStatus.idle] means the step is pending, [MicroStatus.loading]
/// that it is the active step, and [MicroStatus.success] or
/// [MicroStatus.error] that it has finished.
@immutable
class ThinkingStep {
  /// Creates a step with a [title], optional [detail] and a [status].
  const ThinkingStep({
    required this.title,
    this.detail,
    this.status = MicroStatus.idle,
  });

  /// The short description of the step, for example 'Reading files'.
  final String title;

  /// Optional secondary text shown in a muted style below [title].
  final String? detail;

  /// The state of the step. Defaults to [MicroStatus.idle] (pending).
  final MicroStatus status;

  @override
  bool operator ==(Object other) {
    return other is ThinkingStep &&
        other.title == title &&
        other.detail == detail &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(title, detail, status);
}

/// Builds the header of a [ThinkingSteps] from the [elapsed] time and
/// whether the trace [isThinking].
typedef ThinkingHeaderBuilder =
    Widget Function(BuildContext context, Duration elapsed, bool isThinking);

/// An AI reasoning trace: a list of steps with live status marks, the kind
/// of agent progress view chat assistants show while they work.
///
/// ```dart
/// ThinkingSteps(
///   isThinking: !done,
///   steps: const <ThinkingStep>[
///     ThinkingStep(title: 'Reading the question', status: MicroStatus.success),
///     ThinkingStep(title: 'Searching the docs', status: MicroStatus.loading),
///     ThinkingStep(title: 'Writing the answer'),
///   ],
/// )
/// ```
///
/// The header shows a live clock, 'Thinking 12s', that ticks every second
/// while [isThinking] is `true`, then reads 'Thought for 12s' once it turns
/// `false` (see [title], [doneTitle] and [headerBuilder]). The clock is
/// measured internally from the moment [isThinking] becomes `true`; pass
/// [elapsed] to display your own value instead.
///
/// Each step is a row with a [StatusMark] on a vertical connector line, the
/// step title and an optional muted [ThinkingStep.detail]. The connector
/// below a step fills from top to bottom once the step finishes. The title
/// of the active ([MicroStatus.loading]) step has a soft looping shimmer.
/// Steps added to [steps] after the first build fade and grow in.
///
/// When [collapsible] is `true` the header is a button with a rotating
/// chevron that expands or collapses the step list, and with
/// [collapseWhenDone] the list collapses smoothly to the header line when
/// [isThinking] turns `false` (and expands again if it turns back to
/// `true`).
///
/// Accessibility: the header is a focusable button (Enter or Space toggles
/// it) that exposes its expanded state. Each step is announced as its
/// title, its status ('Pending', 'In progress', 'Done' or 'Failed') and its
/// detail. Collapsed steps are hidden from assistive technology.
///
/// Under reduced motion there is no shimmer, and expanding, collapsing,
/// step entrances and connector fills jump to their final state; the clock
/// still ticks. When [enabled] is `false` the trace renders the same static
/// way, and the header can still be toggled.
class ThinkingSteps extends StatefulWidget {
  /// Creates a reasoning trace.
  ///
  /// [markSize] must be positive and [stepSpacing] must not be negative.
  const ThinkingSteps({
    super.key,
    required this.steps,
    this.title = 'Thinking',
    this.doneTitle = 'Thought for',
    this.isThinking = true,
    this.elapsed,
    this.headerBuilder,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.collapseWhenDone = true,
    this.onExpansionChanged,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
    this.markSize = 16.0,
    this.stepSpacing = 12.0,
    this.headerStyle,
    this.titleStyle,
    this.detailStyle,
    this.connectorColor,
    this.connectorFillColor,
    this.shimmerColor,
    this.enabled = true,
  }) : assert(markSize > 0.0, 'markSize must be positive'),
       assert(stepSpacing >= 0.0, 'stepSpacing must not be negative');

  /// The steps to show, in order.
  final List<ThinkingStep> steps;

  /// The header prefix while thinking, followed by the elapsed time, as in
  /// 'Thinking 12s'. Defaults to `'Thinking'`.
  final String title;

  /// The header prefix once done, followed by the elapsed time, as in
  /// 'Thought for 12s'. Defaults to `'Thought for'`.
  final String doneTitle;

  /// Whether the work is still in progress. While `true` the clock ticks.
  /// Defaults to `true`.
  final bool isThinking;

  /// An elapsed time to display instead of the internally measured one.
  ///
  /// When non-null no internal timer runs and the header shows this value;
  /// rebuild with a new value to update it.
  final Duration? elapsed;

  /// Builds a custom header from the elapsed time and [isThinking]. When
  /// null a text such as 'Thinking 12s' or 'Thought for 12s' is shown.
  final ThinkingHeaderBuilder? headerBuilder;

  /// Whether the header toggles the step list. Defaults to `true`. When
  /// `false` the list is always expanded and the header is plain text.
  final bool collapsible;

  /// Whether the list starts expanded when [collapsible] is `true`.
  /// Defaults to `true`.
  final bool initiallyExpanded;

  /// Whether the list collapses when [isThinking] turns `false` and
  /// expands when it turns `true` again. Only applies when [collapsible] is
  /// `true`. Defaults to `true`.
  final bool collapseWhenDone;

  /// Called with the new expanded state whenever the list expands or
  /// collapses, whether by the user or by [collapseWhenDone].
  final ValueChanged<bool>? onExpansionChanged;

  /// The duration of the expand, collapse, step entrance and connector
  /// animations. Defaults to 300 milliseconds.
  final Duration duration;

  /// The curve of the expand, collapse and step entrance animations.
  /// Defaults to [Curves.easeInOutCubic].
  final Curve curve;

  /// The size of each step's [StatusMark]. Defaults to 16.
  final double markSize;

  /// The vertical space between two steps. Defaults to 12.
  final double stepSpacing;

  /// The style of the default header text. Defaults to the theme's
  /// `labelLarge` colored with [ColorScheme.onSurfaceVariant].
  final TextStyle? headerStyle;

  /// The style of step titles. Defaults to the theme's `bodyMedium`, with
  /// pending steps colored with [ColorScheme.onSurfaceVariant].
  final TextStyle? titleStyle;

  /// The style of step details. Defaults to the theme's `bodySmall` colored
  /// with [ColorScheme.onSurfaceVariant].
  final TextStyle? detailStyle;

  /// The color of the connector line between marks. Defaults to
  /// [ColorScheme.outlineVariant].
  final Color? connectorColor;

  /// The color the connector fills with once a step finishes. Defaults to
  /// [ColorScheme.primary].
  final Color? connectorFillColor;

  /// The highlight color of the active step's shimmer. Defaults to the
  /// title color blended towards [ColorScheme.surface].
  final Color? shimmerColor;

  /// When `false` nothing animates (no shimmer, transitions jump), but the
  /// clock still ticks and the header can still be toggled. Defaults to
  /// `true`.
  final bool enabled;

  /// The spoken status of a step: 'Pending', 'In progress', 'Done' or
  /// 'Failed'.
  static String statusLabelFor(MicroStatus status) {
    switch (status) {
      case MicroStatus.idle:
        return 'Pending';
      case MicroStatus.loading:
        return 'In progress';
      case MicroStatus.success:
        return 'Done';
      case MicroStatus.error:
        return 'Failed';
    }
  }

  /// Formats [elapsed] the way the default header does: '12s' under a
  /// minute, '1m 5s' from one minute on.
  static String formatElapsed(Duration elapsed) {
    final int seconds = elapsed.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    }
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }

  @override
  State<ThinkingSteps> createState() => _ThinkingStepsState();
}

class _ThinkingStepsState extends State<ThinkingSteps>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  late CurvedAnimation _expandAnimation;
  late final ValueNotifier<Duration> _elapsed;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  int _ticks = 0;
  bool _expanded = true;
  bool _reduced = false;
  bool _focused = false;

  /// Rows created after the first build animate in.
  bool _builtOnce = false;

  /// Size of the header chevron icon.
  static const double _chevronSize = 20.0;

  /// Gap between the header label and the chevron.
  static const double _chevronGap = 4.0;

  bool get _animate => widget.enabled && !_reduced;

  bool get _clockShouldRun => widget.isThinking && widget.elapsed == null;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.collapsible || widget.initiallyExpanded;
    _expand = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(parent: _expand, curve: widget.curve);
    _elapsed = ValueNotifier<Duration>(widget.elapsed ?? Duration.zero);
    if (_clockShouldRun) {
      _startClock();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (!_animate && _expand.isAnimating) {
      _expand
        ..stop()
        ..value = _expanded ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(ThinkingSteps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _expand.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _expandAnimation.dispose();
      _expandAnimation = CurvedAnimation(parent: _expand, curve: widget.curve);
    }
    if (widget.isThinking != oldWidget.isThinking) {
      if (widget.isThinking) {
        // A new thinking session: measure from zero again.
        _stopClock();
        _ticks = 0;
        _stopwatch.reset();
        if (_clockShouldRun) {
          _startClock();
        }
      } else {
        _stopClock();
      }
      if (widget.collapsible && widget.collapseWhenDone) {
        _setExpanded(widget.isThinking, fromUpdate: true);
      }
    } else if (widget.elapsed != oldWidget.elapsed) {
      if (_clockShouldRun && _ticker == null) {
        _startClock();
      } else if (!_clockShouldRun) {
        _stopClock();
      }
    }
    if (!widget.collapsible && oldWidget.collapsible) {
      _setExpanded(true, fromUpdate: true);
    }
    if (!_animate && _expand.isAnimating) {
      _expand
        ..stop()
        ..value = _expanded ? 1.0 : 0.0;
    }
    _publish();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _expandAnimation.dispose();
    _expand.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _startClock() {
    _ticker?.cancel();
    _stopwatch.start();
    // Timer.tick counts elapsed periods even when events are delayed, and
    // advances with fake time in tests where the Stopwatch does not.
    final int base = _ticks;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        return;
      }
      _ticks = base + timer.tick;
      _publish();
    });
    _publish();
  }

  void _stopClock() {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
    _publish();
  }

  Duration get _measured {
    final Duration ticked = Duration(seconds: _ticks);
    final Duration watched = _stopwatch.elapsed;
    return watched > ticked ? watched : ticked;
  }

  void _publish() {
    _elapsed.value = widget.elapsed ?? _measured;
  }

  /// Expands or collapses the step list.
  ///
  /// With [fromUpdate] (called from [didUpdateWidget]) no `setState` is
  /// needed, and the callback is deferred so a parent may call `setState`
  /// from it.
  void _setExpanded(bool expanded, {bool fromUpdate = false}) {
    if (expanded == _expanded) {
      return;
    }
    if (fromUpdate) {
      _expanded = expanded;
    } else {
      setState(() {
        _expanded = expanded;
      });
    }
    if (_animate) {
      if (expanded) {
        _expand.forward();
      } else {
        _expand.reverse();
      }
    } else {
      _expand
        ..stop()
        ..value = expanded ? 1.0 : 0.0;
    }
    final ValueChanged<bool>? callback = widget.onExpansionChanged;
    if (callback == null) {
      return;
    }
    if (fromUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          callback(expanded);
        }
      });
    } else {
      callback(expanded);
    }
  }

  void _toggle() {
    if (widget.collapsible && mounted) {
      _setExpanded(!_expanded);
    }
  }

  Widget _buildHeaderContent(BuildContext context, ColorScheme scheme) {
    final TextStyle? headerStyle =
        widget.headerStyle ??
        Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    final Widget label = ValueListenableBuilder<Duration>(
      valueListenable: _elapsed,
      builder: (BuildContext context, Duration elapsed, Widget? child) {
        final ThinkingHeaderBuilder? builder = widget.headerBuilder;
        if (builder != null) {
          return builder(context, elapsed, widget.isThinking);
        }
        final String prefix = widget.isThinking
            ? widget.title
            : widget.doneTitle;
        return Text(
          '$prefix ${ThinkingSteps.formatElapsed(elapsed)}',
          style: headerStyle,
        );
      },
    );
    if (!widget.collapsible) {
      return label;
    }
    // A Stack instead of a Row with a Flexible label: it sizes to the label
    // under unbounded width (inside a Row or a horizontal list) and still
    // lets a long label wrap under bounded width.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: _chevronSize + _chevronGap,
          ),
          child: label,
        ),
        PositionedDirectional(
          end: 0.0,
          top: 0.0,
          bottom: 0.0,
          child: Center(
            child: ExcludeSemantics(
              child: RotationTransition(
                turns: _expandAnimation.drive(
                  Tween<double>(begin: 0.0, end: 0.5),
                ),
                child: Icon(
                  Icons.expand_more,
                  size: _chevronSize,
                  color: headerStyle?.color ?? scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: _buildHeaderContent(context, scheme),
    );
    if (!widget.collapsible) {
      return Semantics(header: true, container: true, child: content);
    }
    return Semantics(
      container: true,
      button: true,
      expanded: _expanded,
      onTap: _toggle,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool focused) {
          if (focused != _focused && mounted) {
            setState(() => _focused = focused);
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _toggle();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(6.0)),
              border: Border.all(
                color: _focused ? scheme.primary : const Color(0x00000000),
                width: 2.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle baseTitleStyle =
        widget.titleStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14.0);
    final TextStyle detailStyle =
        widget.detailStyle ??
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant) ??
        TextStyle(fontSize: 12.0, color: scheme.onSurfaceVariant);
    final bool animateNewRows = _builtOnce && _animate;
    _builtOnce = true;

    final List<Widget> rows = <Widget>[
      for (int i = 0; i < widget.steps.length; i++)
        _ThinkingStepRow(
          key: ValueKey<int>(i),
          step: widget.steps[i],
          isLast: i == widget.steps.length - 1,
          animateIn: animateNewRows,
          animate: _animate,
          duration: widget.duration,
          curve: widget.curve,
          markSize: widget.markSize,
          spacing: widget.stepSpacing,
          titleStyle: baseTitleStyle,
          pendingColor: scheme.onSurfaceVariant,
          detailStyle: detailStyle,
          connectorColor: widget.connectorColor ?? scheme.outlineVariant,
          connectorFillColor: widget.connectorFillColor ?? scheme.primary,
          shimmerColor: widget.shimmerColor,
          surfaceColor: scheme.surface,
        ),
    ];

    final Widget content = _RevealFromTop(
      sizeFactor: _expandAnimation,
      child: FadeTransition(
        opacity: _expandAnimation,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          // Start alignment (not stretch) so the list also lays out under
          // unbounded width, sizing to its content.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
        ),
      ),
    );
    // Once fully collapsed the list is taken offstage: hidden from
    // assistive technology and hit testing, with its tickers muted.
    final Widget body = AnimatedBuilder(
      animation: _expand,
      child: content,
      builder: (BuildContext context, Widget? child) {
        final bool collapsed = _expand.isDismissed;
        return Offstage(
          offstage: collapsed,
          child: TickerMode(enabled: !collapsed, child: child!),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildHeader(context, scheme),
        if (widget.steps.isNotEmpty) body,
      ],
    );
  }
}

/// One step row: status mark on the connector, title and detail.
class _ThinkingStepRow extends StatefulWidget {
  const _ThinkingStepRow({
    super.key,
    required this.step,
    required this.isLast,
    required this.animateIn,
    required this.animate,
    required this.duration,
    required this.curve,
    required this.markSize,
    required this.spacing,
    required this.titleStyle,
    required this.pendingColor,
    required this.detailStyle,
    required this.connectorColor,
    required this.connectorFillColor,
    required this.shimmerColor,
    required this.surfaceColor,
  });

  final ThinkingStep step;
  final bool isLast;
  final bool animateIn;
  final bool animate;
  final Duration duration;
  final Curve curve;
  final double markSize;
  final double spacing;
  final TextStyle titleStyle;
  final Color pendingColor;
  final TextStyle detailStyle;
  final Color connectorColor;
  final Color connectorFillColor;
  final Color? shimmerColor;
  final Color surfaceColor;

  @override
  State<_ThinkingStepRow> createState() => _ThinkingStepRowState();
}

class _ThinkingStepRowState extends State<_ThinkingStepRow>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late CurvedAnimation _entranceAnimation;
  late final AnimationController _line;

  /// Gap between a mark and the connector ends.
  static const double _connectorGap = 3.0;

  /// Horizontal gap between a mark and the step text.
  static const double _markGap = 10.0;

  static bool _finished(MicroStatus status) =>
      status == MicroStatus.success || status == MicroStatus.error;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.animateIn && widget.animate ? 0.0 : 1.0,
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entrance,
      curve: widget.curve,
    );
    _line = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _finished(widget.step.status) ? 1.0 : 0.0,
    );
    if (_entrance.value < 1.0) {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(_ThinkingStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _entrance.duration = widget.duration;
      _line.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _entranceAnimation.dispose();
      _entranceAnimation = CurvedAnimation(
        parent: _entrance,
        curve: widget.curve,
      );
    }
    final double lineTarget = _finished(widget.step.status) ? 1.0 : 0.0;
    if (!widget.animate) {
      _entrance
        ..stop()
        ..value = 1.0;
      _line
        ..stop()
        ..value = lineTarget;
    } else if (_line.value != lineTarget) {
      _line.animateTo(lineTarget);
    }
  }

  @override
  void dispose() {
    _entranceAnimation.dispose();
    _entrance.dispose();
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThinkingStep step = widget.step;
    final TextDirection direction = Directionality.of(context);
    final bool pending = step.status == MicroStatus.idle;
    final TextStyle titleStyle = pending
        ? widget.titleStyle.copyWith(color: widget.pendingColor)
        : widget.titleStyle;
    final double fontSize = titleStyle.fontSize ?? 14.0;
    final double lineHeight = fontSize * (titleStyle.height ?? 1.4);
    final double markBox = math.max(widget.markSize, lineHeight);

    final Widget title = step.status == MicroStatus.loading && widget.animate
        ? _ShimmerTitle(
            text: step.title,
            style: titleStyle,
            highlightColor:
                widget.shimmerColor ??
                Color.lerp(
                  titleStyle.color ?? widget.pendingColor,
                  widget.surfaceColor,
                  0.65,
                )!,
          )
        : Text(step.title, style: titleStyle);

    final String? detail = step.detail;
    // The text column is offset by the mark, which is positioned at the
    // start edge. Unlike a Row with an Expanded text column, this lays out
    // under unbounded width too (sizing to the text) while text still wraps
    // at the available width when it is bounded.
    Widget row = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: markBox),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: widget.markSize + _markGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                title,
                if (detail != null && detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2.0),
                  Text(detail, style: widget.detailStyle),
                ],
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: 0.0,
          top: 0.0,
          width: widget.markSize,
          height: markBox,
          child: Center(
            child: StatusMark(
              status: step.status,
              size: widget.markSize,
              strokeWidth: math.max(1.5, widget.markSize / 10),
              enabled: widget.animate,
            ),
          ),
        ),
      ],
    );

    row = Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0.0 : widget.spacing),
      child: row,
    );

    if (!widget.isLast) {
      row = CustomPaint(
        painter: _ConnectorPainter(
          fill: _line,
          x: widget.markSize / 2,
          top: markBox / 2 + widget.markSize / 2 + _connectorGap,
          bottomInset: _connectorGap,
          color: widget.connectorColor,
          fillColor: widget.connectorFillColor,
          textDirection: direction,
        ),
        child: row,
      );
    }

    final String statusLabel = ThinkingSteps.statusLabelFor(step.status);
    row = Semantics(
      container: true,
      label: detail == null || detail.isEmpty
          ? '${step.title}, $statusLabel'
          : '${step.title}, $statusLabel, $detail',
      child: ExcludeSemantics(child: row),
    );

    return _RevealFromTop(
      sizeFactor: _entranceAnimation,
      child: FadeTransition(opacity: _entranceAnimation, child: row),
    );
  }
}

/// Paints the vertical connector below a step's mark, filling it from the
/// top as [fill] grows.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.fill,
    required this.x,
    required this.top,
    required this.bottomInset,
    required this.color,
    required this.fillColor,
    required this.textDirection,
  }) : super(repaint: fill);

  final Animation<double> fill;
  final double x;
  final double top;
  final double bottomInset;
  final Color color;
  final Color fillColor;
  final TextDirection textDirection;

  static const double _width = 1.5;

  final Paint _paint = Paint()
    ..strokeWidth = _width
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double bottom = size.height - bottomInset;
    if (bottom <= top) {
      return;
    }
    final double dx = textDirection == TextDirection.rtl ? size.width - x : x;
    _paint.color = color;
    canvas.drawLine(Offset(dx, top), Offset(dx, bottom), _paint);
    final double t = fill.value.clamp(0.0, 1.0);
    if (t > 0.0) {
      _paint.color = fillColor;
      canvas.drawLine(
        Offset(dx, top),
        Offset(dx, top + (bottom - top) * t),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.x != x ||
        oldDelegate.top != top ||
        oldDelegate.bottomInset != bottomInset ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.textDirection != textDirection;
  }
}

/// The title of the active step with a looping highlight sweep.
class _ShimmerTitle extends StatefulWidget {
  const _ShimmerTitle({
    required this.text,
    required this.style,
    required this.highlightColor,
  });

  final String text;
  final TextStyle style;
  final Color highlightColor;

  @override
  State<_ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<_ShimmerTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Duration _period = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base =
        widget.style.color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    final Widget text = Text(widget.text, style: widget.style);
    // The sweep runs in the reading direction: the transform mirrors the
    // offset when the shader is created with an RTL text direction.
    final TextDirection direction = Directionality.of(context);
    return AnimatedBuilder(
      animation: _controller,
      child: text,
      builder: (BuildContext context, Widget? child) {
        final double shift = _controller.value * 2.0 - 1.0;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: <Color>[base, widget.highlightColor, base],
              stops: const <double>[0.35, 0.5, 0.65],
              transform: _SlideGradientTransform(shift),
            ).createShader(bounds, textDirection: direction);
          },
          child: child,
        );
      },
    );
  }
}

/// Shifts a gradient horizontally by [fraction] of the painted width,
/// mirrored for right-to-left text so the sweep follows the reading
/// direction.
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double sign = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    return Matrix4.translationValues(bounds.width * fraction * sign, 0, 0);
  }
}

/// Clips [child] vertically to [sizeFactor] of its height, anchored at the
/// top, like a top-aligned size transition.
class _RevealFromTop extends AnimatedWidget {
  const _RevealFromTop({
    required Animation<double> sizeFactor,
    required this.child,
  }) : super(listenable: sizeFactor);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> sizeFactor = listenable as Animation<double>;
    return ClipRect(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        heightFactor: math.max(0.0, sizeFactor.value),
        child: child,
      ),
    );
  }
}
