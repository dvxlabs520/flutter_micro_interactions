import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'shimmer_text.dart';
import 'status_mark.dart';
import 'utils/motion.dart';

/// A compact chip for one agent tool call, such as 'Searching the web',
/// with a live progress fill, a ticking timer and a status that resolves to
/// done or failed.
///
/// ```dart
/// ToolCallChip(
///   label: 'Searching the web',
///   icon: Icons.public,
///   status: done ? MicroStatus.success : MicroStatus.loading,
/// )
/// ```
///
/// While [status] is [MicroStatus.loading] the chip's fill wipes across
/// it from the start edge like a progress bar: with a known [progress] the
/// fill follows that value; without one it creeps forward with the elapsed
/// time (fast at first, then slower, never quite reaching the end) while a
/// soft band of light loops across it. The label shimmers and a timer on
/// the trailing side ticks in tenths of a second ('2.4s').
///
/// When the status turns to [MicroStatus.success] the fill completes, the
/// chip settles with a green tint, the leading glyph morphs into a
/// checkmark ([StatusMark]) and the timer freezes. On [MicroStatus.error]
/// the fill completes in red, the glyph shows a cross and the chip shakes
/// horizontally once. [MicroStatus.idle] shows a pending chip with no fill
/// and no timer. Going back to loading starts a new run from zero.
///
/// When [detail] is set the chip shows a chevron and tapping it expands or
/// collapses the detail panel below it. [onTap], when set, is called on
/// every tap as well.
///
/// The timer is measured internally from the moment the status becomes
/// loading. Pass [elapsed] to show your own value instead.
///
/// Accessibility: the chip is announced as its label, its status
/// ('Pending', 'Running', 'Done' or 'Failed') and the elapsed time in whole
/// seconds. When it is tappable it is a focusable button (Enter or Space
/// activates it) that exposes its expanded state. The [detail] keeps its
/// own semantics and is hidden from assistive technology while collapsed.
///
/// Under reduced motion, or when [enabled] is `false`, there is no wipe,
/// no light band, no shimmer and no shake: a determinate [progress] is
/// shown directly, and status changes jump to their final look. The timer
/// still counts.
class ToolCallChip extends StatefulWidget {
  /// Creates a tool call chip.
  ///
  /// [progress], when given, must be in `[0, 1]`.
  const ToolCallChip({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.elapsed,
    this.progress,
    this.detail,
    this.onTap,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.showTimer = true,
    this.estimatedDuration = const Duration(seconds: 4),
    this.wipeDuration = const Duration(milliseconds: 1800),
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
    this.color,
    this.successColor,
    this.errorColor,
    this.backgroundColor,
    this.labelStyle,
    this.timerStyle,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
    this.semanticLabel,
    this.enabled = true,
  }) : assert(
         progress == null || (progress >= 0.0 && progress <= 1.0),
         'progress must be null or in [0, 1]',
       );

  /// The name of the tool call, for example 'Searching the web'.
  final String label;

  /// The state of the call: pending ([MicroStatus.idle]), running
  /// ([MicroStatus.loading]), done ([MicroStatus.success]) or failed
  /// ([MicroStatus.error]).
  final MicroStatus status;

  /// An optional icon for the tool, shown at the start while the call is
  /// pending or running. It is replaced by a checkmark or a cross once the
  /// call finishes. When null a [StatusMark] is shown in every state.
  final IconData? icon;

  /// An elapsed time to display instead of the internally measured one.
  ///
  /// When non-null no internal timer runs; rebuild with a new value to
  /// update the display.
  final Duration? elapsed;

  /// The known progress of a running call, in `[0, 1]`. When null the fill
  /// creeps forward with the elapsed time. Ignored for other states.
  final double? progress;

  /// Optional content revealed below the chip when it is tapped, for
  /// example the query or the sources of a search.
  final Widget? detail;

  /// Called every time the chip is tapped or activated with the keyboard.
  /// The chip is tappable when this or [detail] is non-null.
  final VoidCallback? onTap;

  /// Whether [detail] starts expanded. Defaults to `false`.
  final bool initiallyExpanded;

  /// Called with the new expanded state when the user toggles [detail].
  final ValueChanged<bool>? onExpansionChanged;

  /// Whether the elapsed time is shown on the trailing side. Defaults to
  /// `true`.
  final bool showTimer;

  /// A rough expected length of a call without [progress]. The fill covers
  /// about 80 percent of the chip after this long. Defaults to 4 seconds.
  final Duration estimatedDuration;

  /// The period of the soft light band looping across the fill while
  /// running. Defaults to 1800 milliseconds.
  final Duration wipeDuration;

  /// The length of the settle animation when the call finishes (fill
  /// completion, tint, shake). Defaults to 520 milliseconds.
  final Duration duration;

  /// The curve of the settle and expand animations. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// The accent of a running call: fill, light band and spinner. Defaults
  /// to [ColorScheme.primary].
  final Color? color;

  /// The tint of a finished call. Defaults to the same theme-aware green as
  /// [StatusMark].
  final Color? successColor;

  /// The tint of a failed call. Defaults to [ColorScheme.error].
  final Color? errorColor;

  /// The chip surface. Defaults to [ColorScheme.surfaceContainerLow].
  final Color? backgroundColor;

  /// The style of the label. Defaults to the theme's `labelLarge`.
  final TextStyle? labelStyle;

  /// The style of the timer. Defaults to the theme's `labelMedium` colored
  /// with [ColorScheme.onSurfaceVariant], with tabular figures.
  final TextStyle? timerStyle;

  /// The corner radius of the chip and the detail panel. Defaults to 12.
  final BorderRadius borderRadius;

  /// The padding inside the chip. Defaults to 12 horizontal by 7 vertical.
  final EdgeInsetsGeometry padding;

  /// Replaces [label] in the announcement for assistive technology.
  final String? semanticLabel;

  /// When `false` nothing animates; the timer still counts and the chip
  /// stays tappable. Defaults to `true`.
  final bool enabled;

  /// Formats [elapsed] the way the timer does: '2.4s' under ten seconds,
  /// '12s' under a minute, '1m 5s' from one minute on.
  static String formatElapsed(Duration elapsed) {
    final int tenths = elapsed.inMilliseconds ~/ 100;
    if (tenths < 100) {
      return '${tenths ~/ 10}.${tenths % 10}s';
    }
    final int seconds = elapsed.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    }
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }

  /// The spoken status: 'Pending', 'Running', 'Done' or 'Failed'.
  static String statusLabelFor(MicroStatus status) {
    switch (status) {
      case MicroStatus.idle:
        return 'Pending';
      case MicroStatus.loading:
        return 'Running';
      case MicroStatus.success:
        return 'Done';
      case MicroStatus.error:
        return 'Failed';
    }
  }

  @override
  State<ToolCallChip> createState() => _ToolCallChipState();
}

/// Live values of the chip fill, shared between the state and the painter.
class _ChipFill extends ChangeNotifier {
  /// Covered fraction of the chip, in `[0, 1]`.
  double fill = 0.0;

  /// Position of the looping light band, in `[0, 1)`.
  double sheen = 0.0;

  /// Strength of the light band, 0 when hidden.
  double sheenStrength = 0.0;

  void markChanged() => notifyListeners();
}

class _ToolCallChipState extends State<ToolCallChip>
    with TickerProviderStateMixin {
  /// Clock resolution: the timer shows tenths of a second.
  static const Duration _clockPeriod = Duration(milliseconds: 100);

  /// Highest fill reached by the time-driven fill.
  static const double _maxCreep = 0.92;

  /// Time constant, in seconds, of the fill following its target.
  static const double _follow = 0.16;

  /// Horizontal amplitude of the error shake, in logical pixels.
  static const double _shakeAmplitude = 5.0;

  /// Peak extra scale of the success pop.
  static const double _popAmount = 0.035;

  late final Ticker _ticker;
  late final AnimationController _transition;
  late final AnimationController _expand;
  late CurvedAnimation _expandAnimation;
  final _ChipFill _fill = _ChipFill();

  late final ValueNotifier<Duration> _elapsed;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _clock;
  int _ticks = 0;

  bool _reduced = false;
  bool _expanded = false;
  bool _focused = false;
  bool _hovered = false;

  /// Seconds since the current run started, measured by the ticker.
  double _runTime = 0.0;
  Duration _lastTick = Duration.zero;

  /// Fill and status on screen when the current settle started.
  double _fromFill = 0.0;
  MicroStatus _fromStatus = MicroStatus.idle;
  bool _shake = false;

  bool get _animate => widget.enabled && !_reduced;

  bool get _tappable => widget.detail != null || widget.onTap != null;

  bool get _clockShouldRun =>
      widget.status == MicroStatus.loading && widget.elapsed == null;

  @override
  void initState() {
    super.initState();
    _expanded = widget.detail != null && widget.initiallyExpanded;
    _ticker = createTicker(_onTick);
    _transition = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    )..addListener(_onTransition);
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(parent: _expand, curve: widget.curve);
    _fromStatus = widget.status;
    _elapsed = ValueNotifier<Duration>(widget.elapsed ?? Duration.zero);
    if (widget.status == MicroStatus.success ||
        widget.status == MicroStatus.error) {
      _fill.fill = 1.0;
    }
    if (_clockShouldRun) {
      _startClock();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(ToolCallChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _transition.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _expandAnimation.dispose();
      _expandAnimation = CurvedAnimation(parent: _expand, curve: widget.curve);
    }
    if (widget.detail == null && _expanded) {
      _expanded = false;
      _expand.value = 0.0;
    }
    if (widget.status != oldWidget.status) {
      _onStatusChanged(oldWidget.status);
    } else if (widget.elapsed != oldWidget.elapsed) {
      if (_clockShouldRun && _clock == null) {
        _startClock();
      } else if (!_clockShouldRun) {
        _stopClock();
      }
    }
    _sync();
    _publish();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopwatch.stop();
    _ticker.dispose();
    _transition
      ..removeListener(_onTransition)
      ..dispose();
    _expandAnimation.dispose();
    _expand.dispose();
    _elapsed.dispose();
    _fill.dispose();
    super.dispose();
  }

  // Clock ------------------------------------------------------------------

  void _startClock() {
    _clock?.cancel();
    _stopwatch.start();
    // Timer.tick counts elapsed periods even when events are delayed, and
    // advances with fake time in tests where the Stopwatch does not.
    final int base = _ticks;
    _clock = Timer.periodic(_clockPeriod, (Timer timer) {
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

  void _resetClock() {
    _stopClock();
    _ticks = 0;
    _stopwatch.reset();
  }

  Duration get _measured {
    final Duration ticked = _clockPeriod * _ticks;
    final Duration watched = _stopwatch.elapsed;
    return watched > ticked ? watched : ticked;
  }

  void _publish() {
    _elapsed.value = widget.elapsed ?? _measured;
  }

  // Fill -------------------------------------------------------------------

  void _onStatusChanged(MicroStatus old) {
    final MicroStatus status = widget.status;
    // Capture what is on screen before retargeting.
    _fromFill = _fill.fill;
    _fromStatus = old;
    _shake = false;
    switch (status) {
      case MicroStatus.loading:
        // A new run: clock and fill start from zero.
        _resetClock();
        if (_clockShouldRun) {
          _startClock();
        }
        _runTime = 0.0;
        _fill.fill = 0.0;
      case MicroStatus.idle:
        _resetClock();
        _fill.fill = 0.0;
      case MicroStatus.success:
      case MicroStatus.error:
        _stopClock();
        _shake = status == MicroStatus.error;
    }
    if (_animate) {
      _transition.forward(from: 0.0);
    } else {
      _transition
        ..stop()
        ..value = 1.0;
      _onTransition();
    }
    _fill.markChanged();
  }

  void _onTransition() {
    final MicroStatus status = widget.status;
    if (status == MicroStatus.success || status == MicroStatus.error) {
      // The fill completes during the first part of the settle.
      final double t = Interval(
        0.0,
        0.7,
        curve: Curves.easeOutCubic,
      ).transform(_transition.value);
      _fill.fill = _fromFill + (1.0 - _fromFill) * t;
      _fill.markChanged();
    }
  }

  /// Starts or stops the ticker and snaps the fill to match the current
  /// configuration.
  void _sync() {
    final bool running = widget.status == MicroStatus.loading;
    if (running && _animate) {
      _fill.sheenStrength = widget.progress == null ? 1.0 : 0.6;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      _fill.sheenStrength = 0.0;
      if (running) {
        _fill.fill = widget.progress ?? 0.0;
      }
      if (!_animate && _transition.isAnimating) {
        _transition
          ..stop()
          ..value = 1.0;
      }
      _fill.markChanged();
    }
  }

  double _creep(double seconds) {
    final double estimate = math.max(
      0.001,
      widget.estimatedDuration.inMicroseconds / 1e6,
    );
    return _maxCreep * (1.0 - math.exp(-2.0 * seconds / estimate));
  }

  void _onTick(Duration elapsed) {
    // Real elapsed time (not frame count) drives the fill, so a dropped
    // frame never slows the progress down.
    final double dt = math.max(0.0, (elapsed - _lastTick).inMicroseconds / 1e6);
    _lastTick = elapsed;
    _runTime += dt;
    final double target = widget.progress ?? _creep(_runTime);
    _fill.fill += (target - _fill.fill) * (1.0 - math.exp(-dt / _follow));
    final double period = math.max(
      0.001,
      widget.wipeDuration.inMicroseconds / 1e6,
    );
    _fill.sheen = (_runTime / period) % 1.0;
    _fill.markChanged();
  }

  // Interaction ------------------------------------------------------------

  void _handleTap() {
    if (!mounted) {
      return;
    }
    if (widget.detail != null) {
      final bool expanded = !_expanded;
      setState(() => _expanded = expanded);
      if (_animate) {
        if (expanded) {
          _expand.forward();
        } else {
          _expand.reverse();
        }
      } else {
        _expand.value = expanded ? 1.0 : 0.0;
      }
      widget.onExpansionChanged?.call(expanded);
    }
    widget.onTap?.call();
  }

  // Build ------------------------------------------------------------------

  Color _successColor(ColorScheme scheme) =>
      widget.successColor ??
      (scheme.brightness == Brightness.dark
          ? const Color(0xFF81C784)
          : const Color(0xFF2E7D32));

  Color _accentFor(MicroStatus status, ColorScheme scheme) {
    switch (status) {
      case MicroStatus.idle:
      case MicroStatus.loading:
        return widget.color ?? scheme.primary;
      case MicroStatus.success:
        return _successColor(scheme);
      case MicroStatus.error:
        return widget.errorColor ?? scheme.error;
    }
  }

  /// How strongly the border takes the accent of [status].
  static double _borderMixFor(MicroStatus status) {
    switch (status) {
      case MicroStatus.idle:
        return 0.0;
      case MicroStatus.loading:
        return 0.18;
      case MicroStatus.success:
        return 0.4;
      case MicroStatus.error:
        return 0.55;
    }
  }

  Widget _buildLeading(ColorScheme scheme, double size) {
    final IconData? icon = widget.icon;
    final bool finished =
        widget.status == MicroStatus.success ||
        widget.status == MicroStatus.error;
    final Widget mark = StatusMark(
      key: const ValueKey<String>('mark'),
      status: widget.status,
      progress: widget.status == MicroStatus.loading ? widget.progress : null,
      size: size,
      strokeWidth: math.max(1.5, size / 9),
      loadingColor: widget.color,
      successColor: _successColor(scheme),
      errorColor: widget.errorColor,
      enabled: _animate,
    );
    final Widget child = icon == null || finished
        ? mark
        : Icon(
            icon,
            key: const ValueKey<String>('icon'),
            size: size,
            color: scheme.onSurfaceVariant,
          );
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: _animate ? const Duration(milliseconds: 220) : Duration.zero,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }

  String _spokenTime(Duration elapsed) {
    final int seconds = elapsed.inSeconds;
    if (seconds < 60) {
      return seconds == 1 ? '1 second' : '$seconds seconds';
    }
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} '
        '$rest ${rest == 1 ? 'second' : 'seconds'}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MicroStatus status = widget.status;
    final bool running = status == MicroStatus.loading;
    final TextStyle labelStyle =
        widget.labelStyle ??
        theme.textTheme.labelLarge ??
        const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500);
    final TextStyle timerStyle =
        (widget.timerStyle ??
                theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ) ??
                TextStyle(fontSize: 12.0, color: scheme.onSurfaceVariant))
            .copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            );
    final double glyph = (labelStyle.fontSize ?? 14.0) + 2.0;
    final bool showTime =
        widget.showTimer &&
        (status != MicroStatus.idle || widget.elapsed != null);

    final Widget label = ShimmerText(
      widget.label,
      style: labelStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      baseColor: running
          ? scheme.onSurfaceVariant
          : (status == MicroStatus.idle
                ? scheme.onSurfaceVariant
                : scheme.onSurface),
      highlightColor: scheme.onSurface,
      enabled: running && _animate,
    );

    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildLeading(scheme, glyph),
        const SizedBox(width: 8.0),
        Flexible(child: label),
        if (showTime) ...<Widget>[
          const SizedBox(width: 10.0),
          ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (BuildContext context, Duration value, Widget? child) {
              return Text(
                ToolCallChip.formatElapsed(value),
                style: timerStyle,
                maxLines: 1,
              );
            },
          ),
        ],
        if (widget.detail != null) ...<Widget>[
          const SizedBox(width: 4.0),
          RotationTransition(
            turns: _expandAnimation.drive(Tween<double>(begin: 0.0, end: 0.5)),
            child: Icon(
              Icons.expand_more_rounded,
              size: glyph + 2.0,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    row = CustomPaint(
      painter: _ChipPainter(
        fill: _fill,
        transition: _transition,
        curve: widget.curve,
        background: widget.backgroundColor ?? scheme.surfaceContainerLow,
        border: scheme.outlineVariant,
        fromAccent: _accentFor(_fromStatus, scheme),
        toAccent: _accentFor(status, scheme),
        fromBorderMix: _borderMixFor(_fromStatus),
        toBorderMix: _borderMixFor(status),
        fillAlpha: scheme.brightness == Brightness.dark ? 0.2 : 0.12,
        borderRadius: widget.borderRadius,
        textDirection: Directionality.of(context),
        focusColor: _focused ? scheme.primary : null,
        hoverColor: _hovered ? scheme.onSurface.withValues(alpha: 0.04) : null,
      ),
      child: Padding(padding: widget.padding, child: row),
    );

    // Success pops slightly, error shakes; both only during the settle.
    row = AnimatedBuilder(
      animation: _transition,
      child: row,
      builder: (BuildContext context, Widget? child) {
        final double t = _transition.value;
        if (t >= 1.0 || !_animate) {
          return child!;
        }
        if (_shake) {
          final double dx =
              math.sin(t * math.pi * 6.0) *
              math.pow(1.0 - t, 1.5) *
              _shakeAmplitude;
          return Transform.translate(offset: Offset(dx, 0.0), child: child);
        }
        if (widget.status == MicroStatus.success) {
          final double pop = math.sin(
            math.pi * const Interval(0.45, 1.0).transform(t),
          );
          return Transform.scale(scale: 1.0 + _popAmount * pop, child: child);
        }
        return child!;
      },
    );

    row = RepaintBoundary(child: row);

    if (_tappable) {
      row = FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool value) {
          if (value != _focused && mounted) {
            setState(() => _focused = value);
          }
        },
        onShowHoverHighlight: (bool value) {
          if (value != _hovered && mounted) {
            setState(() => _hovered = value);
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _handleTap();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _handleTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: row,
        ),
      );
    }

    final String name = widget.semanticLabel ?? widget.label;
    final String statusLabel = ToolCallChip.statusLabelFor(status);
    final Widget chip = ValueListenableBuilder<Duration>(
      valueListenable: _elapsed,
      child: ExcludeSemantics(child: row),
      builder: (BuildContext context, Duration value, Widget? child) {
        return Semantics(
          container: true,
          button: _tappable ? true : null,
          expanded: widget.detail != null ? _expanded : null,
          onTap: _tappable ? _handleTap : null,
          label: showTime
              ? '$name, $statusLabel, ${_spokenTime(value)}'
              : '$name, $statusLabel',
          child: child,
        );
      },
    );

    final Widget? detail = widget.detail;
    if (detail == null) {
      return chip;
    }

    final Widget panel = Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? scheme.surfaceContainerLow,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: DefaultTextStyle.merge(
            style:
                theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ) ??
                TextStyle(fontSize: 12.0, color: scheme.onSurfaceVariant),
            child: detail,
          ),
        ),
      ),
    );

    final Widget body = AnimatedBuilder(
      animation: _expandAnimation,
      child: panel,
      builder: (BuildContext context, Widget? child) {
        final bool collapsed = _expand.isDismissed;
        final double t = _expandAnimation.value;
        return Offstage(
          offstage: collapsed,
          child: TickerMode(
            enabled: !collapsed,
            child: ClipRect(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                // Size to the panel's content, never to the whole available
                // width, so the chip keeps its content size (and stays
                // centered in a Center) whether it is bounded or not.
                widthFactor: 1.0,
                heightFactor: math.max(0.0, t),
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[chip, body],
    );
  }
}

/// Paints the chip surface: background, progress fill with its light band,
/// border, and the hover and focus highlights.
class _ChipPainter extends CustomPainter {
  _ChipPainter({
    required this.fill,
    required this.transition,
    required this.curve,
    required this.background,
    required this.border,
    required this.fromAccent,
    required this.toAccent,
    required this.fromBorderMix,
    required this.toBorderMix,
    required this.fillAlpha,
    required this.borderRadius,
    required this.textDirection,
    required this.focusColor,
    required this.hoverColor,
  }) : super(repaint: Listenable.merge(<Listenable>[fill, transition]));

  final _ChipFill fill;
  final Animation<double> transition;
  final Curve curve;
  final Color background;
  final Color border;
  final Color fromAccent;
  final Color toAccent;
  final double fromBorderMix;
  final double toBorderMix;
  final double fillAlpha;
  final BorderRadius borderRadius;
  final TextDirection textDirection;
  final Color? focusColor;
  final Color? hoverColor;

  /// Width of the soft leading edge of the fill, in logical pixels.
  static const double _softEdge = 40.0;

  /// Width of the light band as a fraction of the chip width.
  static const double _sheenWidth = 0.35;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = borderRadius.toRRect(rect);
    final double t = curve.transform(transition.value.clamp(0.0, 1.0));
    final Color accent = Color.lerp(fromAccent, toAccent, t) ?? toAccent;
    final double borderMix = fromBorderMix + (toBorderMix - fromBorderMix) * t;

    _paint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = background;
    canvas.drawRRect(rrect, _paint);

    canvas.save();
    canvas.clipRRect(rrect);
    if (textDirection == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0.0)
        ..scale(-1.0, 1.0);
    }

    final double f = fill.fill.clamp(0.0, 1.0);
    if (f > 0.0) {
      // The fill edge travels past the far edge so a full fill is solid.
      final double edge = f * (size.width + _softEdge);
      canvas.saveLayer(rect, Paint());
      _paint
        ..shader = null
        ..color = accent.withValues(alpha: accent.a * fillAlpha);
      canvas.drawRect(Rect.fromLTWH(0.0, 0.0, edge, size.height), _paint);

      final double strength = fill.sheenStrength;
      if (strength > 0.0) {
        // A soft band of light loops across the covered part.
        final double band = size.width * _sheenWidth;
        final double center = -band / 2 + fill.sheen * (edge + band);
        final Color glow = accent.withValues(
          alpha: accent.a * fillAlpha * 1.5 * strength,
        );
        // A shader is modulated by the paint opacity: keep it opaque.
        _paint
          ..color = const Color(0xFF000000)
          ..shader = LinearGradient(
            colors: <Color>[
              glow.withValues(alpha: 0.0),
              glow,
              glow.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(center - band / 2, 0.0, band, 1.0));
        canvas.drawRect(Rect.fromLTWH(0.0, 0.0, edge, size.height), _paint);
      }

      // Feather the leading edge of everything drawn above.
      _paint
        ..blendMode = BlendMode.dstIn
        ..color = const Color(0xFF000000)
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(edge - _softEdge, 0.0, _softEdge, 1.0));
      canvas.drawRect(rect, _paint);
      _paint.blendMode = BlendMode.srcOver;
      canvas.restore();
    }
    canvas.restore();
    _paint.shader = null;

    final Color? hover = hoverColor;
    if (hover != null) {
      _paint.color = hover;
      canvas.drawRRect(rrect, _paint);
    }

    final Color? focus = focusColor;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = focus == null ? 1.0 : 2.0
      ..color =
          focus ??
          Color.lerp(border, accent.withValues(alpha: 0.9), borderMix) ??
          border;
    canvas.drawRRect(rrect.deflate(_paint.strokeWidth / 2), _paint);
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.transition != transition ||
        oldDelegate.curve != curve ||
        oldDelegate.background != background ||
        oldDelegate.border != border ||
        oldDelegate.fromAccent != fromAccent ||
        oldDelegate.toAccent != toAccent ||
        oldDelegate.fromBorderMix != fromBorderMix ||
        oldDelegate.toBorderMix != toBorderMix ||
        oldDelegate.fillAlpha != fillAlpha ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.focusColor != focusColor ||
        oldDelegate.hoverColor != hoverColor;
  }
}
