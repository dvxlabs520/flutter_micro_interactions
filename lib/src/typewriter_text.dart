import 'dart:async';

// Grapheme iteration uses `Characters` from package:characters, which the
// Flutter SDK re-exports through material.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// Programmatic control for a [TypewriterText].
///
/// The caller owns and disposes the controller. Attach it to a
/// [TypewriterText] and drive playback with [start], [stop] and [reset].
///
/// ```dart
/// final _typing = TypewriterController();
/// // later
/// _typing.stop();
/// _typing.start();
/// _typing.reset();
/// ```
class TypewriterController extends ChangeNotifier {
  /// Requested playback state. Null until [start], [stop] or [reset] is
  /// called; the widget then falls back to its `autoPlay` value.
  bool? _playRequested;

  /// Incremented by [reset] so the widget can detect reset requests.
  int _resetCount = 0;

  /// Reported back by the attached widget.
  bool _isTyping = false;

  /// Whether the attached [TypewriterText] is currently animating (typing,
  /// pausing between strings, or deleting). Snapshot value, not a listenable
  /// property of its own.
  bool get isTyping => _isTyping;

  /// Starts or resumes the typewriter animation.
  void start() {
    _playRequested = true;
    notifyListeners();
  }

  /// Stops the animation, freezing the currently visible text.
  void stop() {
    _playRequested = false;
    notifyListeners();
  }

  /// Restarts the animation from the first string.
  void reset() {
    _resetCount++;
    _playRequested = true;
    notifyListeners();
  }
}

/// Internal phases of the typewriter state machine.
enum _TypewriterPhase {
  /// Adding one character per tick.
  typing,

  /// Holding a fully typed string before moving on.
  pausing,

  /// Removing one character per tick.
  deleting,

  /// A non-looping run has finished; no more ticks are scheduled.
  done,
}

/// Text that types itself out character by character, with an optional
/// blinking cursor, optional deleting and support for cycling through
/// several strings.
///
/// ```dart
/// TypewriterText(
///   strings: const ['Hello', 'World'],
///   loop: true,
///   style: Theme.of(context).textTheme.headlineSmall,
/// )
/// ```
///
/// For a single string use [TypewriterText.single].
///
/// The state machine is driven by one tracked [Timer]
/// (typing -> pausing -> deleting -> next), so rapid configuration changes
/// and disposal mid-animation never leave a dangling callback. The cursor
/// blink runs on a separate lightweight periodic timer.
///
/// Layout: the widget renders the full current target string invisibly
/// (opacity 0) in a [Stack] under the visible substring, so its width and
/// height stay constant while typing instead of jittering per character.
///
/// Strings are iterated by grapheme clusters ([Characters]), so emoji and
/// accented characters are never split mid-glyph.
///
/// Accessibility: the semantics label is always the full target string,
/// never the partially typed text. [semanticLabel] overrides it. No live
/// region is used, so assistive technology is not spammed per character.
///
/// Reduced motion: each string is shown complete without any timers. When
/// [loop] is true the widget does not cycle and shows the first string;
/// when false it shows the last string and [onAllCompleted] fires once.
class TypewriterText extends StatefulWidget {
  /// Creates a typewriter text that cycles through [strings].
  ///
  /// [strings] must not be empty (validated in `initState`).
  const TypewriterText({
    super.key,
    required this.strings,
    this.style,
    this.textAlign = TextAlign.start,
    this.typeSpeed = const Duration(milliseconds: 60),
    this.deleteSpeed = const Duration(milliseconds: 40),
    this.pauseBetween = const Duration(milliseconds: 1500),
    this.loop = false,
    this.deleteBeforeNext = true,
    this.showCursor = true,
    this.cursor = '|',
    this.cursorColor,
    this.cursorBlinkSpeed = const Duration(milliseconds: 500),
    this.controller,
    this.onStringCompleted,
    this.onAllCompleted,
    this.autoPlay = true,
    this.enabled = true,
    this.semanticLabel,
  });

  /// Convenience constructor for the one-string case.
  ///
  /// ```dart
  /// TypewriterText.single(text: 'Welcome back')
  /// ```
  TypewriterText.single({
    super.key,
    required String text,
    this.style,
    this.textAlign = TextAlign.start,
    this.typeSpeed = const Duration(milliseconds: 60),
    this.deleteSpeed = const Duration(milliseconds: 40),
    this.pauseBetween = const Duration(milliseconds: 1500),
    this.loop = false,
    this.deleteBeforeNext = true,
    this.showCursor = true,
    this.cursor = '|',
    this.cursorColor,
    this.cursorBlinkSpeed = const Duration(milliseconds: 500),
    this.controller,
    this.onStringCompleted,
    this.onAllCompleted,
    this.autoPlay = true,
    this.enabled = true,
    this.semanticLabel,
  }) : strings = <String>[text];

  /// The strings to type, in order. Must not be empty.
  final List<String> strings;

  /// Text style of the rendered characters. Falls back to the ambient
  /// [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal alignment of the text. Defaults to [TextAlign.start].
  final TextAlign textAlign;

  /// Delay between typed characters. Defaults to 60 milliseconds.
  final Duration typeSpeed;

  /// Delay between deleted characters. Defaults to 40 milliseconds.
  final Duration deleteSpeed;

  /// Hold time after a string finishes typing, before deleting or moving
  /// to the next string. Defaults to 1500 milliseconds.
  final Duration pauseBetween;

  /// When true the widget cycles through [strings] forever. When false it
  /// plays each string once in order and stops on the last one, fully
  /// typed. Defaults to false.
  final bool loop;

  /// When true, characters are deleted one by one before the next string
  /// is typed. When false the text is cleared instantly. Defaults to true.
  final bool deleteBeforeNext;

  /// Whether the cursor is rendered. Defaults to true.
  final bool showCursor;

  /// The cursor character. Defaults to `'|'`.
  final String cursor;

  /// Cursor color. Defaults to the [style] color, or the theme's
  /// `colorScheme.primary` when the style has no color.
  final Color? cursorColor;

  /// One on/off blink interval of the cursor. Defaults to 500 milliseconds.
  final Duration cursorBlinkSpeed;

  /// Optional playback controller. The caller owns and disposes it.
  final TypewriterController? controller;

  /// Called every time a string finishes typing.
  final VoidCallback? onStringCompleted;

  /// Called once when a non-looping run has typed its last string.
  final VoidCallback? onAllCompleted;

  /// Whether the animation starts on its own. Ignored once a
  /// [controller] method has been called. Defaults to true.
  final bool autoPlay;

  /// When false all timers are cancelled and the currently visible text
  /// is frozen in place.
  final bool enabled;

  /// Semantics label exposed to assistive technology. Defaults to the
  /// full current target string.
  final String? semanticLabel;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  /// The single state-machine driver. Always tracked and cancelled; never
  /// a chained bare `Future.delayed`.
  Timer? _timer;

  /// Lightweight cursor blink timer, independent of the driver.
  Timer? _cursorTimer;

  _TypewriterPhase _phase = _TypewriterPhase.typing;
  int _stringIndex = 0;
  int _visibleCount = 0;
  bool _cursorVisible = true;
  bool _playing = true;
  bool _reduced = false;
  bool _allCompletedFired = false;
  int _seenResetCount = 0;

  /// Grapheme clusters of the current target string.
  List<String> _graphemes = const <String>[];

  @override
  void initState() {
    super.initState();
    assert(widget.strings.isNotEmpty, 'TypewriterText.strings must not be empty');
    _loadString();
    _seenResetCount = widget.controller?._resetCount ?? 0;
    _playing = widget.controller?._playRequested ?? widget.autoPlay;
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MicroMotion.isReduced(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (!reduced) {
        // Motion was re-enabled: restart cleanly from the beginning.
        _restart();
      }
    }
    _sync();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      oldWidget.controller?._isTyping = false;
      widget.controller?.addListener(_handleControllerChanged);
      _seenResetCount = widget.controller?._resetCount ?? 0;
      _playing = widget.controller?._playRequested ?? widget.autoPlay;
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _playing = widget.autoPlay;
    }
    if (!listEquals(widget.strings, oldWidget.strings)) {
      _restart();
    } else if (_timer != null &&
        (widget.typeSpeed != oldWidget.typeSpeed ||
            widget.deleteSpeed != oldWidget.deleteSpeed ||
            widget.pauseBetween != oldWidget.pauseBetween)) {
      // Restart the pending tick with the new speed for the current phase.
      _cancelDriver();
    }
    if (widget.showCursor != oldWidget.showCursor ||
        widget.cursorBlinkSpeed != oldWidget.cursorBlinkSpeed) {
      _cursorTimer?.cancel();
      _cursorTimer = null;
      _cursorVisible = true;
    }
    _sync();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    widget.controller?._isTyping = false;
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  /// Loads the grapheme clusters of the current target string.
  void _loadString() {
    _graphemes = widget.strings.isEmpty
        ? const <String>[]
        : widget.strings[_stringIndex].characters.toList();
  }

  /// Resets the state machine to the first string, keeping the playback
  /// state, and lets [_sync] reschedule.
  void _restart() {
    _cancelDriver();
    setStateIfMounted(() {
      _stringIndex = 0;
      _visibleCount = 0;
      _phase = _TypewriterPhase.typing;
      _allCompletedFired = false;
      _loadString();
    });
  }

  /// Runs [fn] inside setState when a frame is not already being built;
  /// during `didChangeDependencies`/`didUpdateWidget` a rebuild is already
  /// scheduled, so mutating directly is safe.
  void setStateIfMounted(VoidCallback fn) {
    if (!mounted) {
      fn();
      return;
    }
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
    } else {
      fn();
    }
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final TypewriterController controller = widget.controller!;
    if (controller._resetCount != _seenResetCount) {
      _seenResetCount = controller._resetCount;
      _restart();
    }
    _playing = controller._playRequested ?? widget.autoPlay;
    _sync();
  }

  /// Central playback reconciliation: applies reduced motion, `enabled`
  /// and the requested playback state to the two timers.
  void _sync() {
    if (widget.strings.isEmpty) return;
    if (_reduced) {
      _cancelDriver();
      _cursorTimer?.cancel();
      _cursorTimer = null;
      _cursorVisible = true;
      // Show a single complete string, no timers, no cycling.
      final int index = widget.loop ? 0 : widget.strings.length - 1;
      if (_stringIndex != index || _visibleCount != _graphemes.length) {
        setStateIfMounted(() {
          _stringIndex = index;
          _loadString();
          _visibleCount = _graphemes.length;
          _phase = _TypewriterPhase.done;
        });
      } else {
        _phase = _TypewriterPhase.done;
      }
      if (!widget.loop && !_allCompletedFired) {
        _allCompletedFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onAllCompleted?.call();
        });
      }
      return;
    }
    if (!widget.enabled || !_playing) {
      // Freeze: cancel timers, keep the current text on screen.
      _cancelDriver();
      _cursorTimer?.cancel();
      _cursorTimer = null;
      _cursorVisible = true;
      return;
    }
    _ensureCursorTimer();
    if (_phase != _TypewriterPhase.done && _timer == null) {
      _schedule(_delayForPhase());
    }
  }

  Duration _delayForPhase() {
    return switch (_phase) {
      _TypewriterPhase.typing => widget.typeSpeed,
      _TypewriterPhase.pausing => widget.pauseBetween,
      _TypewriterPhase.deleting => widget.deleteSpeed,
      _TypewriterPhase.done => Duration.zero,
    };
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tick);
    widget.controller?._isTyping = true;
  }

  void _cancelDriver() {
    _timer?.cancel();
    _timer = null;
    widget.controller?._isTyping = false;
  }

  /// One step of the state machine: typing -> pausing -> deleting -> next.
  void _tick() {
    _timer = null;
    if (!mounted) return;
    switch (_phase) {
      case _TypewriterPhase.typing:
        if (_visibleCount < _graphemes.length) {
          setState(() => _visibleCount++);
        }
        if (_visibleCount >= _graphemes.length) {
          widget.onStringCompleted?.call();
          final bool last = _stringIndex >= widget.strings.length - 1;
          if (last && !widget.loop) {
            _phase = _TypewriterPhase.done;
            _cancelDriver();
            if (!_allCompletedFired) {
              _allCompletedFired = true;
              widget.onAllCompleted?.call();
            }
            return;
          }
          _phase = _TypewriterPhase.pausing;
          _schedule(widget.pauseBetween);
        } else {
          _schedule(widget.typeSpeed);
        }
      case _TypewriterPhase.pausing:
        if (widget.deleteBeforeNext && _visibleCount > 0) {
          _phase = _TypewriterPhase.deleting;
          _deleteStep();
        } else {
          setState(() {
            _visibleCount = 0;
            _advanceString();
          });
          _phase = _TypewriterPhase.typing;
          _schedule(widget.typeSpeed);
        }
      case _TypewriterPhase.deleting:
        _deleteStep();
      case _TypewriterPhase.done:
        break;
    }
  }

  void _deleteStep() {
    if (_visibleCount > 0) {
      setState(() => _visibleCount--);
    }
    if (_visibleCount <= 0) {
      setState(_advanceString);
      _phase = _TypewriterPhase.typing;
      _schedule(widget.typeSpeed);
    } else {
      _schedule(widget.deleteSpeed);
    }
  }

  void _advanceString() {
    _stringIndex = (_stringIndex + 1) % widget.strings.length;
    _loadString();
  }

  void _ensureCursorTimer() {
    if (!widget.showCursor) return;
    _cursorTimer ??= Timer.periodic(widget.cursorBlinkSpeed, (_) {
      if (!mounted) return;
      setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.strings.isEmpty) return const SizedBox.shrink();
    final String target = widget.strings[_stringIndex];
    final String visible =
        _graphemes.take(_visibleCount.clamp(0, _graphemes.length)).join();
    final TextStyle base =
        DefaultTextStyle.of(context).style.merge(widget.style);
    final Color cursorColor = widget.cursorColor ??
        widget.style?.color ??
        Theme.of(context).colorScheme.primary;

    // The full target string (plus cursor) is rendered invisibly to
    // reserve the final layout size, so the widget does not jitter while
    // characters appear. The visible substring is painted over it.
    final Widget sizeReservation = Opacity(
      opacity: 0.0,
      child: Text(
        widget.showCursor ? '$target${widget.cursor}' : target,
        style: base,
        textAlign: widget.textAlign,
      ),
    );
    final Widget visibleText = Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          TextSpan(text: visible),
          if (widget.showCursor)
            TextSpan(
              text: widget.cursor,
              // A transparent cursor keeps its layout slot while blinking.
              style: TextStyle(
                color: _cursorVisible
                    ? cursorColor
                    : cursorColor.withValues(alpha: 0.0),
              ),
            ),
        ],
      ),
      key: const ValueKey<String>('TypewriterText.visible'),
      textAlign: widget.textAlign,
    );

    // Always expose the full target string, never the partial text. No
    // live region: announcing every character would spam screen readers.
    return Semantics(
      label: widget.semanticLabel ?? target,
      container: true,
      child: ExcludeSemantics(
        child: Stack(
          children: <Widget>[
            sizeReservation,
            Positioned.fill(child: visibleText),
          ],
        ),
      ),
    );
  }
}
