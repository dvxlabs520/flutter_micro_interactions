import 'dart:async';

// Grapheme iteration uses `Characters` from package:characters, which the
// Flutter SDK re-exports through material.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// How a [RotatingText] splits each phrase into animated units.
enum RotatingTextSplit {
  /// Every character (grapheme cluster) animates on its own.
  ///
  /// Each character is shaped on its own, which would break letters that
  /// join or reorder. So the widget automatically animates whole words
  /// instead when the ambient [Directionality] is right-to-left or a
  /// phrase contains a joining or complex script: Hebrew, Arabic, Syriac,
  /// Thaana, N'Ko, Indic scripts (U+0900 to U+0DFF), Tibetan, Myanmar,
  /// Khmer or Mongolian.
  characters,

  /// Every word animates on its own.
  words,
}

/// Where the stagger of a [RotatingText] transition begins.
enum RotatingTextStaggerFrom {
  /// The first unit moves first.
  first,

  /// The last unit moves first.
  last,

  /// The middle units move first, then the stagger spreads outwards.
  center,
}

/// Commands sent from a [RotatingTextController] to its widget.
enum _RotatingCommand { next, previous, jumpTo }

/// Programmatic control for a [RotatingText].
///
/// The caller owns and disposes the controller. Navigation calls made
/// while no [RotatingText] is attached are ignored; [start] and [stop]
/// are remembered and applied when a widget attaches.
///
/// ```dart
/// final RotatingTextController rotation = RotatingTextController();
/// // later
/// rotation.stop();
/// rotation.next();
/// rotation.jumpTo(0);
/// rotation.start();
/// ```
class RotatingTextController extends ChangeNotifier {
  /// Requested playback state. Null until [start] or [stop] is called; the
  /// widget then falls back to its `autoPlay` value.
  bool? _playRequested;

  /// Incremented for each navigation command.
  int _commandCount = 0;
  _RotatingCommand _command = _RotatingCommand.next;
  int _jumpIndex = 0;

  /// Reported back by the attached widget.
  int _currentIndex = 0;

  /// Index of the phrase shown by the attached [RotatingText]. Snapshot
  /// value, not a listenable property of its own; use
  /// `RotatingText.onIndexChanged` to observe changes.
  int get currentIndex => _currentIndex;

  /// Shows the next phrase. At the last phrase this wraps to the first
  /// when `loop` is true and does nothing otherwise.
  void next() => _issue(_RotatingCommand.next);

  /// Shows the previous phrase. At the first phrase this wraps to the last
  /// when `loop` is true and does nothing otherwise.
  void previous() => _issue(_RotatingCommand.previous);

  /// Shows the phrase at [index], which must be a valid index of
  /// `RotatingText.texts`.
  void jumpTo(int index) {
    _jumpIndex = index;
    _issue(_RotatingCommand.jumpTo);
  }

  /// Starts or resumes the automatic rotation.
  void start() {
    _playRequested = true;
    notifyListeners();
  }

  /// Stops the automatic rotation. The current phrase stays visible and
  /// [next], [previous] and [jumpTo] keep working.
  void stop() {
    _playRequested = false;
    notifyListeners();
  }

  void _issue(_RotatingCommand command) {
    _command = command;
    _commandCount++;
    notifyListeners();
  }
}

/// Text that cycles through phrases, animating each change one character
/// (or word) at a time.
///
/// ```dart
/// Row(
///   mainAxisSize: MainAxisSize.min,
///   children: <Widget>[
///     const Text('Build '),
///     RotatingText(
///       texts: const <String>['faster', 'smarter', 'together'],
///       style: Theme.of(context).textTheme.headlineSmall,
///     ),
///   ],
/// )
/// ```
///
/// Every [interval] the next phrase replaces the current one: outgoing
/// units slide up and fade out while incoming units slide up from below
/// and fade in. Each unit takes [duration], and units start [stagger]
/// apart, beginning from [staggerFrom]. The text is clipped to its box so
/// letters appear to come out of a mask. With [animateSize] the width
/// eases between phrases of different lengths.
///
/// Phrases render on a single line. They are iterated by grapheme
/// clusters, so emoji and accented characters are never split. Joining,
/// complex and right-to-left scripts always animate by words, so their
/// shaping stays intact (see [RotatingTextSplit.characters]). A phrase
/// whose first letter is right-to-left is laid out right to left.
///
/// Accessibility: the widget exposes the current phrase as its semantics
/// label. It is not a live region, so assistive technology is not
/// interrupted on every change.
///
/// Reduced motion: phrases still change every [interval], because the
/// content itself is informative, but each change is instant, without any
/// sliding, fading or size animation.
///
/// `enabled: false`: no automatic rotation and no animation. Controller
/// navigation still switches phrases, instantly.
class RotatingText extends StatefulWidget {
  /// Creates rotating text. [texts] must not be empty.
  const RotatingText({
    super.key,
    required this.texts,
    this.style,
    this.interval = const Duration(milliseconds: 2000),
    this.duration = const Duration(milliseconds: 500),
    this.stagger = const Duration(milliseconds: 25),
    this.staggerFrom = RotatingTextStaggerFrom.first,
    this.curve = Curves.easeOutCubic,
    this.splitBy = RotatingTextSplit.characters,
    this.loop = true,
    this.autoPlay = true,
    this.animateSize = true,
    this.controller,
    this.onIndexChanged,
    this.enabled = true,
  });

  /// The phrases to cycle through, in order. Must not be empty.
  final List<String> texts;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Time between two automatic changes, measured from the start of each
  /// change. Defaults to 2000 milliseconds.
  final Duration interval;

  /// How long one unit takes to move in or out. Defaults to 500
  /// milliseconds.
  final Duration duration;

  /// Delay between two consecutive units. Defaults to 25 milliseconds.
  final Duration stagger;

  /// Which unit moves first. Defaults to [RotatingTextStaggerFrom.first].
  final RotatingTextStaggerFrom staggerFrom;

  /// Curve applied to each unit. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Whether characters or words animate as units. Defaults to
  /// [RotatingTextSplit.characters].
  final RotatingTextSplit splitBy;

  /// Whether the rotation wraps from the last phrase to the first. When
  /// false the automatic rotation stops on the last phrase. Defaults to
  /// true.
  final bool loop;

  /// Whether the automatic rotation starts on its own. Ignored once
  /// [RotatingTextController.start] or [RotatingTextController.stop] has
  /// been called. Defaults to true.
  final bool autoPlay;

  /// Whether the width animates smoothly between phrases. When false the
  /// widget takes the width of the incoming phrase at once. Defaults to
  /// true.
  final bool animateSize;

  /// Optional controller. The caller owns and disposes it.
  final RotatingTextController? controller;

  /// Called with the new index whenever the phrase changes.
  final ValueChanged<int>? onIndexChanged;

  /// When false the phrase stays still: no automatic rotation and no
  /// animation.
  final bool enabled;

  @override
  State<RotatingText> createState() => _RotatingTextState();
}

class _RotatingTextState extends State<RotatingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transition;
  Timer? _timer;
  int _index = 0;

  /// Index of the outgoing phrase while a transition runs.
  int? _previousIndex;
  bool _playing = true;
  bool _reduced = false;

  /// Whether the ambient [Directionality] is right-to-left.
  bool _rtl = false;
  int _seenCommandCount = 0;

  /// Units of each phrase, computed lazily.
  final Map<int, List<String>> _unitCache = <int, List<String>>{};

  bool get _static => _reduced || !widget.enabled;

  @override
  void initState() {
    super.initState();
    _debugCheckConfig();
    // Starts completed so the first phrase is fully visible.
    _transition = AnimationController(vsync: this, value: 1.0)
      ..addStatusListener(_handleStatus);
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    final bool rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (rtl != _rtl) {
      _rtl = rtl;
      _unitCache.clear();
    }
    if (_static) _endTransition();
    _syncTimer();
  }

  @override
  void didUpdateWidget(RotatingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckConfig();
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _attach(widget.controller);
    } else if (widget.controller == null &&
        widget.autoPlay != oldWidget.autoPlay) {
      _playing = widget.autoPlay;
    }
    if (!listEquals(widget.texts, oldWidget.texts) ||
        widget.splitBy != oldWidget.splitBy) {
      _unitCache.clear();
      _endTransition();
      if (_index >= widget.texts.length) {
        _index = 0;
        widget.controller?._currentIndex = 0;
      }
    }
    if (_static) _endTransition();
    if (widget.interval != oldWidget.interval) {
      _cancelTimer();
    }
    _syncTimer();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _timer?.cancel();
    _transition.dispose();
    super.dispose();
  }

  /// Lists and durations cannot be validated in a const constructor, so
  /// they are validated here.
  void _debugCheckConfig() {
    assert(widget.texts.isNotEmpty, 'RotatingText.texts must not be empty');
    assert(widget.interval > Duration.zero, 'interval must be positive');
    assert(widget.duration > Duration.zero, 'duration must be positive');
    assert(widget.stagger >= Duration.zero, 'stagger must not be negative');
  }

  void _attach(RotatingTextController? controller) {
    _playing = controller?._playRequested ?? widget.autoPlay;
    if (controller == null) return;
    _seenCommandCount = controller._commandCount;
    controller._currentIndex = _index;
    controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final RotatingTextController controller = widget.controller!;
    _playing = controller._playRequested ?? widget.autoPlay;
    if (controller._commandCount != _seenCommandCount) {
      _seenCommandCount = controller._commandCount;
      switch (controller._command) {
        case _RotatingCommand.next:
          _next();
        case _RotatingCommand.previous:
          _previous();
        case _RotatingCommand.jumpTo:
          final int target = controller._jumpIndex;
          assert(
            target >= 0 && target < widget.texts.length,
            'jumpTo index $target is out of range',
          );
          if (target >= 0 && target < widget.texts.length) {
            _goTo(target);
          }
      }
    }
    _syncTimer();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() => _previousIndex = null);
    }
  }

  /// Stops a running transition and drops the outgoing phrase.
  void _endTransition() {
    if (_transition.isAnimating) _transition.stop();
    _previousIndex = null;
    _transition.value = 1.0;
  }

  void _next() {
    final int last = widget.texts.length - 1;
    if (_index < last) {
      _goTo(_index + 1);
    } else if (widget.loop && last > 0) {
      _goTo(0);
    }
  }

  void _previous() {
    if (_index > 0) {
      _goTo(_index - 1);
    } else if (widget.loop && widget.texts.length > 1) {
      _goTo(widget.texts.length - 1);
    }
  }

  void _goTo(int index) {
    if (index == _index) return;
    final int previous = _index;
    setState(() {
      _index = index;
      if (_static) {
        _endTransition();
      } else {
        _previousIndex = previous;
        _transition.duration = _transitionDuration(previous, index);
        _transition.forward(from: 0.0);
      }
    });
    widget.controller?._currentIndex = index;
    widget.onIndexChanged?.call(index);
    // The interval restarts from this change.
    _cancelTimer();
    _syncTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Schedules or cancels the next automatic change.
  void _syncTimer() {
    final bool canAdvance =
        widget.texts.length > 1 &&
        (widget.loop || _index < widget.texts.length - 1);
    if (!_playing || !widget.enabled || !canAdvance) {
      _cancelTimer();
      return;
    }
    _timer ??= Timer(widget.interval, () {
      _timer = null;
      if (!mounted) return;
      _next();
    });
  }

  List<String> _units(int index) {
    return _unitCache.putIfAbsent(index, () {
      final String text = widget.texts[index];
      final Characters graphemes = text.characters;
      final bool byWords =
          widget.splitBy == RotatingTextSplit.words ||
          _rtl ||
          _needsWordUnits(text);
      if (!byWords) {
        return graphemes.toList();
      }
      // Words and whitespace runs alternate as units.
      final List<String> units = <String>[];
      final StringBuffer buffer = StringBuffer();
      bool? inSpace;
      for (final String grapheme in graphemes) {
        final bool space = grapheme.trim().isEmpty;
        if (space != inSpace && buffer.isNotEmpty) {
          units.add(buffer.toString());
          buffer.clear();
        }
        inSpace = space;
        buffer.write(grapheme);
      }
      if (buffer.isNotEmpty) units.add(buffer.toString());
      return units;
    });
  }

  /// Stagger position (in units of [RotatingText.stagger]) of unit [i] of
  /// a phrase with [count] units.
  double _staggerSlot(int i, int count) {
    return switch (widget.staggerFrom) {
      RotatingTextStaggerFrom.first => i.toDouble(),
      RotatingTextStaggerFrom.last => (count - 1 - i).toDouble(),
      RotatingTextStaggerFrom.center => (i - (count - 1) / 2).abs(),
    };
  }

  double _maxSlot(int count) {
    if (count <= 1) return 0.0;
    return widget.staggerFrom == RotatingTextStaggerFrom.center
        ? (count - 1) / 2
        : (count - 1).toDouble();
  }

  Duration _transitionDuration(int from, int to) {
    final double slots =
        _maxSlot(_units(from).length) > _maxSlot(_units(to).length)
        ? _maxSlot(_units(from).length)
        : _maxSlot(_units(to).length);
    return widget.duration +
        Duration(microseconds: (widget.stagger.inMicroseconds * slots).round());
  }

  /// Curved progress of a unit at stagger [slot].
  double _unitProgress(double slot) {
    if (_transition.value >= 1.0) return 1.0;
    final double durationUs = widget.duration.inMicroseconds.toDouble();
    final double totalUs = (_transition.duration ?? widget.duration)
        .inMicroseconds
        .toDouble();
    final double elapsedUs = _transition.value * totalUs;
    final double startUs = slot * widget.stagger.inMicroseconds;
    final double t = ((elapsedUs - startUs) / durationUs).clamp(0.0, 1.0);
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return widget.curve.transform(t);
  }

  Widget _buildPhrase(int index, TextStyle style, {required bool incoming}) {
    final List<String> units = _units(index);
    final TextDirection direction =
        _firstStrongDirection(widget.texts[index]) ??
        Directionality.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: direction,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        for (int i = 0; i < units.length; i++)
          AnimatedBuilder(
            animation: _transition,
            child: Text(
              units[i],
              style: style,
              textDirection: direction,
              softWrap: false,
              maxLines: 1,
            ),
            builder: (BuildContext context, Widget? child) {
              final double t = _unitProgress(_staggerSlot(i, units.length));
              final double opacity = t.clamp(0.0, 1.0);
              return Opacity(
                opacity: incoming ? opacity : 1.0 - opacity,
                child: FractionalTranslation(
                  translation: Offset(0.0, incoming ? 1.0 - t : -t),
                  child: child,
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    final int? previous = _previousIndex;
    Widget content = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _buildPhrase(_index, base, incoming: true),
        if (previous != null)
          PositionedDirectional(
            start: 0.0,
            top: 0.0,
            child: _buildPhrase(previous, base, incoming: false),
          ),
      ],
    );
    if (widget.animateSize && !_static) {
      content = AnimatedSize(
        duration: widget.duration,
        curve: widget.curve,
        alignment: AlignmentDirectional.centerStart,
        child: content,
      );
    }
    return Semantics(
      label: widget.texts[_index],
      container: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(child: ClipRect(child: content)),
      ),
    );
  }
}

/// Whether [rune] belongs to a right-to-left script: Hebrew, Arabic,
/// Syriac, Thaana, N'Ko and the related blocks.
bool _isRtlRune(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFC) ||
    (rune >= 0x10800 && rune <= 0x10FFF) ||
    (rune >= 0x1E800 && rune <= 0x1EFFF);

/// Whether [text] contains a script whose letters join, stack or reorder
/// when shaped, so its characters must not be laid out one by one:
/// right-to-left scripts (Hebrew, Arabic, Syriac, Thaana, N'Ko), Indic
/// scripts (U+0900 to U+0DFF), Tibetan, Myanmar, Khmer and Mongolian.
bool _needsWordUnits(String text) {
  for (final int rune in text.runes) {
    if (_isRtlRune(rune) ||
        (rune >= 0x0900 && rune <= 0x0DFF) ||
        (rune >= 0x0F00 && rune <= 0x109F) ||
        (rune >= 0x1780 && rune <= 0x18AF)) {
      return true;
    }
  }
  return false;
}

/// The direction of [text] given by its first strong letter, or null when
/// it has none. A simplified version of the Unicode bidi rule P2 that
/// covers common scripts.
TextDirection? _firstStrongDirection(String text) {
  for (final int rune in text.runes) {
    if (_isRtlRune(rune)) return TextDirection.rtl;
    final bool ltr =
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0xC0 && rune <= 0x058F && rune != 0xD7 && rune != 0xF7) ||
        (rune >= 0x0900 && rune <= 0x1FFF) ||
        (rune >= 0x3040 && rune <= 0x9FFF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF);
    if (ltr) return TextDirection.ltr;
  }
  return null;
}
