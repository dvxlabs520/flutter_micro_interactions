import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';
import 'voice_waveform.dart';

/// A round microphone button that swells into a recording capsule with
/// live equalizer bars, a running timer and a stop button.
///
/// ```dart
/// VoicePill(
///   recording: isRecording,
///   onChanged: (bool value) => setState(() => isRecording = value),
///   levelListenable: micLevel, // 0..1 from your own audio stack
/// )
/// ```
///
/// Idle, the widget is a [size] circle with a microphone icon. When
/// [recording] turns `true` the circle grows with a spring into a capsule
/// of [expandedWidth], keeping its end edge in place: the microphone turns
/// into a stop button at the end, a [VoiceWaveform] follows the voice
/// [level] in the middle, and a timer ('0:12') counts the recording time.
/// When [onCancel] is set, a small close button appears at the start.
/// Stopping folds the capsule back into the circle, which lands with a
/// short squash and stretch.
///
/// The widget does not record anything itself: tapping the circle calls
/// [onChanged] with `true`, tapping the stop button calls it with `false`,
/// and the parent decides by rebuilding with a new [recording] value. When
/// [onChanged] is null the button is shown dimmed and does not react.
///
/// Colors: idle uses [idleColor] ([ColorScheme.surfaceContainerHighest])
/// with [idleForegroundColor] ([ColorScheme.onSurface]); recording uses
/// [recordingColor] ([ColorScheme.primary]) with [recordingForegroundColor]
/// ([ColorScheme.onPrimary]). Pass `colorScheme.error` and
/// `colorScheme.onError` for a red recording state.
///
/// Accessibility: the main button is announced as 'Start recording' or
/// 'Stop recording' (see [startLabel] and [stopLabel]) and is focusable
/// (Enter or Space activates it). While recording, the timer is exposed as
/// 'Recording' with the time as its value, and the close button as
/// [cancelLabel].
///
/// Under reduced motion, or when [enabled] is `false`, the capsule opens
/// and closes instantly with no spring and no squash, and the bars show
/// the level directly; the timer still counts.
class VoicePill extends StatefulWidget {
  /// Creates a voice recording pill.
  ///
  /// [level] must be in `[0, 1]`, [size] must be positive and
  /// [expandedWidth] must be at least `2 * size`.
  const VoicePill({
    super.key,
    required this.recording,
    required this.onChanged,
    this.onCancel,
    this.level = 0.0,
    this.levelListenable,
    this.elapsed,
    this.size = 48.0,
    this.expandedWidth = 208.0,
    this.idleColor,
    this.idleForegroundColor,
    this.recordingColor,
    this.recordingForegroundColor,
    this.micIcon = Icons.mic_rounded,
    this.stopIcon = Icons.stop_rounded,
    this.barCount = 9,
    this.timerStyle,
    this.startLabel = 'Start recording',
    this.stopLabel = 'Stop recording',
    this.cancelLabel = 'Cancel recording',
    this.enableHaptics = false,
    this.enabled = true,
  }) : assert(level >= 0.0 && level <= 1.0, 'level must be in [0, 1]'),
       assert(size > 0.0, 'size must be positive'),
       assert(
         expandedWidth >= size * 2,
         'expandedWidth must be at least twice the size',
       ),
       assert(barCount > 0, 'barCount must be positive');

  /// Whether a recording is in progress. The parent owns this value.
  final bool recording;

  /// Called with `true` when the idle circle is tapped and with `false`
  /// when the stop button is tapped. When null the pill is disabled.
  final ValueChanged<bool>? onChanged;

  /// Called when the close button at the start of the capsule is tapped.
  /// When null no close button is shown.
  final VoidCallback? onCancel;

  /// The current voice loudness, in `[0, 1]`. Ignored when
  /// [levelListenable] is set. Defaults to 0.
  final double level;

  /// An optional source of the voice loudness, read every frame without
  /// rebuilding the parent. Takes precedence over [level].
  final ValueListenable<double>? levelListenable;

  /// A recording time to display instead of the internally measured one.
  ///
  /// When non-null no internal timer runs; rebuild with a new value to
  /// update the display.
  final Duration? elapsed;

  /// The diameter of the idle circle and the height of the capsule.
  /// Defaults to 48.
  final double size;

  /// The width of the open capsule. Defaults to 208.
  final double expandedWidth;

  /// The idle background. Defaults to
  /// [ColorScheme.surfaceContainerHighest].
  final Color? idleColor;

  /// The idle icon color. Defaults to [ColorScheme.onSurface].
  final Color? idleForegroundColor;

  /// The capsule background while recording. Defaults to
  /// [ColorScheme.primary].
  final Color? recordingColor;

  /// The color of the bars, timer and buttons while recording. Defaults to
  /// [ColorScheme.onPrimary].
  final Color? recordingForegroundColor;

  /// The idle icon. Defaults to [Icons.mic_rounded].
  final IconData micIcon;

  /// The icon of the button that ends the recording. Defaults to
  /// [Icons.stop_rounded]; [Icons.check_rounded] suits a confirm action.
  final IconData stopIcon;

  /// The number of equalizer bars. Defaults to 9.
  final int barCount;

  /// The style of the timer. Defaults to the theme's `labelLarge` with
  /// tabular figures, in the recording foreground color.
  final TextStyle? timerStyle;

  /// The announced label of the idle button. Defaults to
  /// 'Start recording'.
  final String startLabel;

  /// The announced label of the stop button. Defaults to 'Stop recording'.
  final String stopLabel;

  /// The announced label of the close button. Defaults to
  /// 'Cancel recording'.
  final String cancelLabel;

  /// Whether a light haptic impact plays when a button is pressed.
  /// Defaults to `false`.
  final bool enableHaptics;

  /// When `false` nothing animates (the capsule opens and closes
  /// instantly), but the buttons and the timer still work. Defaults to
  /// `true`.
  final bool enabled;

  /// Formats [elapsed] the way the timer does: '0:12', '12:03', or
  /// '1:02:03' from one hour on.
  static String formatElapsed(Duration elapsed) {
    final int total = elapsed.inSeconds;
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final String ss = (total % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
    }
    return '$minutes:$ss';
  }

  @override
  State<VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<VoicePill> with TickerProviderStateMixin {
  /// Slightly bouncy spring used to open the capsule.
  static final SpringDescription _openSpring =
      SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 380.0,
        ratio: 0.68,
      );

  /// Quick, non-bouncy spring used to fold it back.
  static final SpringDescription _closeSpring =
      SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 520.0,
        ratio: 1.0,
      );

  static const Tolerance _tolerance = Tolerance(
    distance: 0.001,
    velocity: 0.01,
  );

  /// Peak scale change of the landing squash.
  static const double _squashAmount = 0.13;

  /// Scale of a pressed button.
  static const double _pressedScale = 0.92;

  /// 0 for the circle, 1 for the open capsule (may overshoot on open).
  late final AnimationController _expansion;

  /// Runs the squash and stretch after the capsule folds back.
  late final AnimationController _squash;

  late final ValueNotifier<Duration> _elapsed;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _clock;
  int _ticks = 0;

  bool _reduced = false;
  bool _pressed = false;

  bool get _animate => widget.enabled && !_reduced;

  bool get _interactive => widget.onChanged != null;

  bool get _clockShouldRun => widget.recording && widget.elapsed == null;

  @override
  void initState() {
    super.initState();
    _expansion = AnimationController.unbounded(
      vsync: this,
      value: widget.recording ? 1.0 : 0.0,
    );
    _squash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 1.0,
    );
    _elapsed = ValueNotifier<Duration>(widget.elapsed ?? Duration.zero);
    if (_clockShouldRun) {
      _startClock();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (!_animate) {
      _snap();
    }
  }

  @override
  void didUpdateWidget(VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording != oldWidget.recording) {
      if (widget.recording) {
        // A new recording: measure from zero.
        _stopClock();
        _ticks = 0;
        _stopwatch.reset();
        if (_clockShouldRun) {
          _startClock();
        }
      } else {
        _stopClock();
      }
      _animateTo(widget.recording ? 1.0 : 0.0);
    } else if (widget.elapsed != oldWidget.elapsed) {
      if (_clockShouldRun && _clock == null) {
        _startClock();
      } else if (!_clockShouldRun) {
        _stopClock();
      }
    }
    if (!_animate) {
      _snap();
    }
    if (!_interactive) {
      _pressed = false;
    }
    _publish();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopwatch.stop();
    _expansion.dispose();
    _squash.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  // Clock ------------------------------------------------------------------

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

  // Motion -----------------------------------------------------------------

  /// Jumps every animation to its resting value.
  void _snap() {
    _expansion
      ..stop()
      ..value = widget.recording ? 1.0 : 0.0;
    _squash
      ..stop()
      ..value = 1.0;
  }

  void _animateTo(double target) {
    if (!_animate) {
      _snap();
      return;
    }
    final bool opening = target > _expansion.value;
    _expansion
        .animateWith(
          SpringSimulation(
            opening ? _openSpring : _closeSpring,
            _expansion.value,
            target,
            _expansion.velocity,
            tolerance: _tolerance,
          ),
        )
        .then((_) {
          // A spring stops within a tolerance: land exactly on the target.
          if (mounted) {
            _expansion.value = target;
          }
        });
    if (opening) {
      _squash
        ..stop()
        ..value = 1.0;
    } else {
      _squash.forward(from: 0.0);
    }
  }

  /// Squash amount for squash progress [t]: compress, stretch, settle.
  static double _squashAt(double t) {
    final double u = const Interval(0.25, 1.0).transform(t);
    if (u <= 0.0 || u >= 1.0) {
      return 0.0;
    }
    return math.sin(u * math.pi * 2.0) * math.pow(1.0 - u, 2.0);
  }

  // Interaction ------------------------------------------------------------

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  void _activateMain() {
    final ValueChanged<bool>? onChanged = widget.onChanged;
    if (onChanged == null || !mounted) {
      return;
    }
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    onChanged(!widget.recording);
  }

  void _activateCancel() {
    final VoidCallback? onCancel = widget.onCancel;
    if (onCancel == null || !widget.recording || !mounted) {
      return;
    }
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    onCancel();
  }

  // Build ------------------------------------------------------------------

  Widget _buildContent(Color foreground, TextStyle timerStyle) {
    final double size = widget.size;
    final Widget timer = ValueListenableBuilder<Duration>(
      valueListenable: _elapsed,
      builder: (BuildContext context, Duration value, Widget? child) {
        final String text = VoicePill.formatElapsed(value);
        return Semantics(
          container: true,
          label: 'Recording',
          value: text,
          child: ExcludeSemantics(
            child: Text(text, style: timerStyle, maxLines: 1),
          ),
        );
      },
    );
    return Row(
      children: <Widget>[
        if (widget.onCancel != null)
          _PillButton(
            label: widget.cancelLabel,
            onActivate: _activateCancel,
            focusColor: foreground,
            child: SizedBox(
              width: size * 0.85,
              height: size,
              child: Icon(
                Icons.close_rounded,
                size: size * 0.4,
                color: foreground.withValues(alpha: 0.85),
              ),
            ),
          )
        else
          SizedBox(width: size * 0.4),
        Expanded(
          child: Center(
            child: ExcludeSemantics(
              child: VoiceWaveform(
                level: widget.level,
                levelListenable: widget.levelListenable,
                active: widget.recording,
                barCount: widget.barCount,
                barWidth: 3.0,
                spacing: 3.0,
                minHeight: 3.0,
                maxHeight: size * 0.46,
                color: foreground,
                enabled: widget.enabled,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        timer,
        SizedBox(width: size + 2.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color idleBg = widget.idleColor ?? scheme.surfaceContainerHighest;
    final Color idleFg = widget.idleForegroundColor ?? scheme.onSurface;
    final Color recBg = widget.recordingColor ?? scheme.primary;
    final Color recFg = widget.recordingForegroundColor ?? scheme.onPrimary;
    final TextStyle timerStyle =
        (widget.timerStyle ??
                theme.textTheme.labelLarge ??
                const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500))
            .copyWith(
              color: widget.timerStyle?.color ?? recFg,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            );
    final double size = widget.size;
    final bool recording = widget.recording;
    final Duration pressDuration = _animate
        ? const Duration(milliseconds: 110)
        : Duration.zero;

    // The capsule content: built once and faded in by the builder.
    final Widget content = _buildContent(recFg, timerStyle);

    final Widget pill = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_expansion, _squash]),
      builder: (BuildContext context, Widget? child) {
        final double e = _expansion.value;
        final double open = e.clamp(0.0, 1.0);
        final double width = math.max(
          size,
          size + (widget.expandedWidth - size) * e,
        );
        final Color background = Color.lerp(idleBg, recBg, open) ?? recBg;
        final Color foreground = Color.lerp(idleFg, recFg, open) ?? recFg;
        final double contentOpacity = const Interval(
          0.45,
          1.0,
          curve: Curves.easeOut,
        ).transform(open);
        final double squash = _squashAt(_squash.value) * _squashAmount;
        final double stopScale = Curves.easeOutBack.transform(
          const Interval(0.25, 1.0).transform(open),
        );
        final double micOpacity =
            1.0 - const Interval(0.0, 0.5).transform(open);

        final Widget endButton = _PillButton(
          label: recording ? widget.stopLabel : widget.startLabel,
          onActivate: _interactive ? _activateMain : null,
          onPressedChanged: _setPressed,
          focusColor: recording ? recFg : scheme.primary,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // The stop button: a solid disc that grows in with the
                // capsule and dips while pressed.
                // The microphone fades out quickly as the capsule opens,
                // under the stop disc that grows in its place.
                if (micOpacity > 0.0)
                  Opacity(
                    key: const ValueKey<String>('mic'),
                    opacity: micOpacity,
                    child: Icon(
                      widget.micIcon,
                      size: size * 0.46,
                      color: foreground,
                    ),
                  ),
                if (stopScale > 0.0)
                  AnimatedScale(
                    key: const ValueKey<String>('stop'),
                    scale: recording && _pressed ? _pressedScale : 1.0,
                    duration: pressDuration,
                    child: Transform.scale(
                      scale: stopScale.clamp(0.0, 1.2),
                      child: Container(
                        width: size - 12.0,
                        height: size - 12.0,
                        decoration: BoxDecoration(
                          color: recFg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.stopIcon,
                          size: size * 0.42,
                          color: recBg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return SizedBox(
          width: width,
          height: size,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(1.0 + squash, 1.0 - squash, 1.0),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: background,
                shape: const StadiumBorder(),
                shadows: open > 0.0
                    ? <BoxShadow>[
                        BoxShadow(
                          color: recBg.withValues(alpha: 0.28 * open),
                          blurRadius: 16.0 * open,
                          offset: Offset(0.0, 4.0 * open),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Stack(
                  children: <Widget>[
                    if (e > 0.001 || recording)
                      Positioned.fill(
                        key: const ValueKey<String>('content'),
                        child: OverflowBox(
                          alignment: AlignmentDirectional.centerEnd,
                          minWidth: widget.expandedWidth,
                          maxWidth: widget.expandedWidth,
                          child: IgnorePointer(
                            ignoring: !recording,
                            child: Opacity(
                              opacity: contentOpacity,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      key: const ValueKey<String>('end'),
                      top: 0.0,
                      bottom: 0.0,
                      end: 0.0,
                      child: endButton,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: content,
    );

    Widget result = AnimatedScale(
      scale: !recording && _pressed ? _pressedScale : 1.0,
      duration: pressDuration,
      curve: Curves.easeOut,
      child: pill,
    );
    if (!_interactive) {
      result = Opacity(opacity: 0.5, child: result);
    }
    return result;
  }
}

/// A focusable, tappable region with button semantics and a focus ring.
class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.label,
    required this.onActivate,
    required this.focusColor,
    required this.child,
    this.onPressedChanged,
  });

  final String label;
  final VoidCallback? onActivate;
  final ValueChanged<bool>? onPressedChanged;
  final Color focusColor;
  final Widget child;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _focused = false;

  void _press(bool value) => widget.onPressedChanged?.call(value);

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onActivate = widget.onActivate;
    final bool enabled = onActivate != null;
    Widget child = widget.child;
    if (_focused) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(color: widget.focusColor, width: 2.0),
          ),
        ),
        child: child,
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: onActivate,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (bool value) {
            if (value != _focused && mounted) {
              setState(() => _focused = value);
            }
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                onActivate?.call();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent intent) {
                onActivate?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _press(true) : null,
            onTapUp: enabled ? (_) => _press(false) : null,
            onTapCancel: enabled ? () => _press(false) : null,
            onTap: onActivate,
            child: child,
          ),
        ),
      ),
    );
  }
}
