import 'dart:async';
import 'dart:math' as math;

// Grapheme iteration uses `Characters` from package:characters, which the
// Flutter SDK re-exports through material.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// The order in which a sequential [DecryptedText] resolves its characters.
enum DecryptRevealDirection {
  /// From the first character to the last.
  start,

  /// From the last character to the first.
  end,

  /// From the middle outwards.
  center,

  /// In a random order.
  random,
}

/// What starts a [DecryptedText] animation.
enum DecryptTrigger {
  /// The animation plays when the widget is first built, if `autoPlay` is
  /// true.
  mount,

  /// The animation plays while a mouse pointer hovers the text. When the
  /// pointer leaves, the final text is restored at once.
  hover,
}

/// Programmatic control for a [DecryptedText].
///
/// The caller owns and disposes the controller. Calls made while no
/// [DecryptedText] is attached are ignored.
///
/// ```dart
/// final DecryptedTextController decrypt = DecryptedTextController();
/// // later
/// decrypt.play();
/// ```
class DecryptedTextController extends ChangeNotifier {
  /// Incremented by [play] so the widget can detect play requests.
  int _playCount = 0;

  /// Incremented by [reset] so the widget can detect reset requests.
  int _resetCount = 0;

  /// Reported back by the attached widget.
  bool _isAnimating = false;

  /// Whether the attached [DecryptedText] is currently scrambling.
  /// Snapshot value, not a listenable property of its own.
  bool get isAnimating => _isAnimating;

  /// Starts a new decrypt run. Does nothing while a run is in progress.
  void play() {
    _playCount++;
    notifyListeners();
  }

  /// Stops any running decrypt and shows the final text.
  void reset() {
    _resetCount++;
    notifyListeners();
  }
}

/// Text that scrambles through random glyphs before resolving to the real
/// text, like a message being decrypted.
///
/// ```dart
/// DecryptedText(
///   text: 'Access granted',
///   sequential: true,
///   revealDirection: DecryptRevealDirection.center,
///   style: Theme.of(context).textTheme.titleLarge,
/// )
/// ```
///
/// On every tick, one [interval] apart, the unresolved characters are
/// replaced with random glyphs from [characters]. When [sequential] is
/// true one more character resolves on each tick, in the order given by
/// [revealDirection]. When false, all characters scramble for
/// [maxIterations] ticks and then resolve together. Whitespace never
/// scrambles. Unresolved characters use [encryptedStyle].
///
/// [animateOn] picks the trigger: on mount (with [autoPlay]) or while a
/// mouse hovers the text. A [DecryptedTextController] can start and reset
/// runs at any time. Pass a [seed] for a repeatable scramble, for example
/// in tests.
///
/// Layout: the final text is rendered invisibly in a [Stack] under the
/// scrambled text, so the widget keeps the size of the final text while
/// scrambling. Scrambled glyphs may be wider than the final ones and can
/// overflow slightly; they are not clipped.
///
/// Text is iterated by grapheme clusters ([Characters]), so emoji and
/// accented characters are never split.
///
/// Accessibility: the semantics label is always the final text (or
/// [semanticLabel]), never the scrambled glyphs.
///
/// Reduced motion and `enabled: false`: the final text is shown at once, no
/// timers run, and a run that would have started completes immediately and
/// fires [onCompleted].
class DecryptedText extends StatefulWidget {
  /// Creates a decrypting text.
  const DecryptedText({
    super.key,
    required this.text,
    this.style,
    this.encryptedStyle,
    this.textAlign = TextAlign.start,
    this.characters = defaultCharacters,
    this.interval = const Duration(milliseconds: 50),
    this.maxIterations = 10,
    this.sequential = false,
    this.revealDirection = DecryptRevealDirection.start,
    this.animateOn = DecryptTrigger.mount,
    this.autoPlay = true,
    this.controller,
    this.onCompleted,
    this.enabled = true,
    this.seed,
    this.semanticLabel,
  }) : assert(characters != '', 'characters must not be empty'),
       assert(maxIterations > 0, 'maxIterations must be positive');

  /// The default glyph pool: Latin letters, digits and common symbols.
  static const String defaultCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
      r'!@#$%^&*()_+-=[]{}<>?/|';

  /// The final text.
  final String text;

  /// Style of resolved characters. Falls back to the ambient
  /// [DefaultTextStyle].
  final TextStyle? style;

  /// Style of unresolved (scrambled) characters, merged over [style].
  /// Defaults to the resolved color at half its opacity.
  final TextStyle? encryptedStyle;

  /// Horizontal alignment of the text. Defaults to [TextAlign.start].
  final TextAlign textAlign;

  /// Pool of glyphs used while scrambling. Must not be empty. Defaults to
  /// [defaultCharacters].
  final String characters;

  /// Time between two scramble ticks. Larger values scramble more slowly.
  /// Must be positive. Defaults to 50 milliseconds.
  final Duration interval;

  /// Number of scramble ticks before all characters resolve when
  /// [sequential] is false. Defaults to 10.
  final int maxIterations;

  /// When true, characters resolve one per tick in [revealDirection]
  /// order. When false, all characters resolve together after
  /// [maxIterations] ticks. Defaults to false.
  final bool sequential;

  /// Order in which characters resolve when [sequential] is true.
  /// Defaults to [DecryptRevealDirection.start].
  final DecryptRevealDirection revealDirection;

  /// What starts the animation. Defaults to [DecryptTrigger.mount].
  final DecryptTrigger animateOn;

  /// Whether a [DecryptTrigger.mount] widget plays when first built.
  /// Defaults to true.
  final bool autoPlay;

  /// Optional playback controller. The caller owns and disposes it.
  final DecryptedTextController? controller;

  /// Called each time a run resolves to the final text. Also called when
  /// a run would start under reduced motion or with [enabled] false.
  final VoidCallback? onCompleted;

  /// When false the final text is shown without scrambling.
  final bool enabled;

  /// Seed for the random glyph and order generator. Null uses an unseeded
  /// generator.
  final int? seed;

  /// Semantics label exposed to assistive technology. Defaults to [text].
  final String? semanticLabel;

  @override
  State<DecryptedText> createState() => _DecryptedTextState();
}

class _DecryptedTextState extends State<DecryptedText> {
  Timer? _timer;
  math.Random _random = math.Random();
  bool _reduced = false;
  bool _initialized = false;

  /// Grapheme clusters of the final text.
  List<String> _target = const <String>[];

  /// Grapheme clusters of the glyph pool.
  List<String> _pool = const <String>[];

  /// What is currently shown for each grapheme.
  List<String> _display = const <String>[];

  /// Whether each grapheme shows its final value.
  List<bool> _resolved = const <bool>[];

  /// Resolve order of the non-whitespace graphemes (sequential mode).
  List<int> _order = const <int>[];
  int _orderPosition = 0;
  int _iteration = 0;

  int _seenPlayCount = 0;
  int _seenResetCount = 0;

  bool get _static => _reduced || !widget.enabled;
  bool get _scrambling => _timer != null;

  @override
  void initState() {
    super.initState();
    _debugCheckConfig();
    _random = math.Random(widget.seed);
    _pool = widget.characters.characters.toList();
    _loadTarget();
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    if (!_initialized) {
      _initialized = true;
      if (widget.animateOn == DecryptTrigger.mount && widget.autoPlay) {
        _play();
      }
    } else if (_static && _scrambling) {
      _finish();
    }
  }

  @override
  void didUpdateWidget(DecryptedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckConfig();
    if (widget.controller != oldWidget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    }
    if (widget.seed != oldWidget.seed) {
      _random = math.Random(widget.seed);
    }
    if (widget.characters != oldWidget.characters) {
      _pool = widget.characters.characters.toList();
    }
    if (widget.text != oldWidget.text) {
      final bool wasScrambling = _scrambling;
      _stopTimer();
      _loadTarget();
      if (wasScrambling) _play();
    } else if (_scrambling && _static) {
      _finish();
    } else if (_scrambling && widget.interval != oldWidget.interval) {
      _stopTimer();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _timer?.cancel();
    super.dispose();
  }

  /// Durations cannot be compared in a const constructor, so the interval is
  /// validated here.
  void _debugCheckConfig() {
    assert(widget.interval > Duration.zero, 'interval must be positive');
  }

  void _attach(DecryptedTextController? controller) {
    if (controller == null) return;
    _seenPlayCount = controller._playCount;
    _seenResetCount = controller._resetCount;
    controller._isAnimating = _scrambling;
    controller.addListener(_handleControllerChanged);
  }

  void _detach(DecryptedTextController? controller) {
    if (controller == null) return;
    controller.removeListener(_handleControllerChanged);
    controller._isAnimating = false;
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final DecryptedTextController controller = widget.controller!;
    if (controller._resetCount != _seenResetCount) {
      _seenResetCount = controller._resetCount;
      _reset();
    }
    if (controller._playCount != _seenPlayCount) {
      _seenPlayCount = controller._playCount;
      _play();
    }
  }

  /// Shows the final text with every grapheme resolved.
  void _loadTarget() {
    _target = widget.text.characters.toList();
    _display = List<String>.of(_target);
    _resolved = List<bool>.filled(_target.length, true);
  }

  static bool _isSpace(String grapheme) => grapheme.trim().isEmpty;

  /// Starts a run, or completes it at once when motion is disabled.
  void _play() {
    if (_scrambling) return;
    if (_static || _pool.isEmpty) {
      _setState(_loadTarget);
      _notifyCompleted();
      return;
    }
    _setState(() {
      _resolved = <bool>[for (final String g in _target) _isSpace(g)];
      _order = _buildOrder();
      _orderPosition = 0;
      _iteration = 0;
      _scramble();
    });
    if (_order.isEmpty) {
      // Nothing to scramble (empty or whitespace-only text).
      _finish();
      return;
    }
    _startTimer();
  }

  /// Stops any run and shows the final text, without firing onCompleted.
  void _reset() {
    _stopTimer();
    _setState(_loadTarget);
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.interval, (_) => _tick());
    widget.controller?._isAnimating = true;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    widget.controller?._isAnimating = false;
  }

  void _tick() {
    if (!mounted) return;
    if (widget.sequential) {
      if (_orderPosition < _order.length) {
        _resolved[_order[_orderPosition]] = true;
        _orderPosition++;
      }
      if (_orderPosition >= _order.length) {
        _finish();
        return;
      }
    } else {
      _iteration++;
      if (_iteration >= widget.maxIterations) {
        _finish();
        return;
      }
    }
    setState(_scramble);
  }

  /// Ends the current run on the final text and fires onCompleted.
  void _finish() {
    _stopTimer();
    _setState(_loadTarget);
    _notifyCompleted();
  }

  /// Replaces every unresolved grapheme with a random glyph.
  void _scramble() {
    final List<String> display = List<String>.of(_target);
    for (int i = 0; i < _target.length; i++) {
      if (!_resolved[i]) {
        display[i] = _pool[_random.nextInt(_pool.length)];
      }
    }
    _display = display;
  }

  List<int> _buildOrder() {
    final List<int> indices = <int>[
      for (int i = 0; i < _target.length; i++)
        if (!_isSpace(_target[i])) i,
    ];
    switch (widget.revealDirection) {
      case DecryptRevealDirection.start:
        return indices;
      case DecryptRevealDirection.end:
        return indices.reversed.toList();
      case DecryptRevealDirection.center:
        final double middle = (_target.length - 1) / 2;
        // Stable sort by distance from the middle; ties keep the earlier
        // index first.
        final List<int> sorted = List<int>.of(indices);
        mergeSort<int>(
          sorted,
          compare: (int a, int b) {
            return (a - middle).abs().compareTo((b - middle).abs());
          },
        );
        return sorted;
      case DecryptRevealDirection.random:
        return indices..shuffle(_random);
    }
  }

  /// Runs [fn] in setState unless the framework is already building, in
  /// which case a rebuild is pending and mutating directly is safe.
  void _setState(VoidCallback fn) {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (!mounted ||
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      fn();
    } else {
      setState(fn);
    }
  }

  /// Calls onCompleted, after the frame when the framework is building.
  void _notifyCompleted() {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onCompleted?.call();
      });
    } else {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    final Color color = base.color ?? Theme.of(context).colorScheme.onSurface;
    final TextStyle encrypted = base
        .copyWith(color: color.withValues(alpha: color.a * 0.5))
        .merge(widget.encryptedStyle);

    // Group consecutive graphemes with the same state into one span.
    final List<InlineSpan> spans = <InlineSpan>[];
    final StringBuffer run = StringBuffer();
    bool? runResolved;
    void flush() {
      if (run.isEmpty) return;
      spans.add(
        TextSpan(text: run.toString(), style: runResolved! ? null : encrypted),
      );
      run.clear();
    }

    for (int i = 0; i < _display.length; i++) {
      if (_resolved[i] != runResolved) {
        flush();
        runResolved = _resolved[i];
      }
      run.write(_display[i]);
    }
    flush();

    Widget content = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Reserves the size of the final text so the layout never jitters.
        Opacity(
          opacity: 0.0,
          child: Text(widget.text, style: base, textAlign: widget.textAlign),
        ),
        Positioned.fill(
          child: Text.rich(
            TextSpan(children: spans),
            key: const ValueKey<String>('DecryptedText.visible'),
            style: base,
            textAlign: widget.textAlign,
          ),
        ),
      ],
    );

    if (widget.animateOn == DecryptTrigger.hover) {
      content = MouseRegion(
        onEnter: (_) => _play(),
        onExit: (_) => _reset(),
        child: content,
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? widget.text,
      container: true,
      child: ExcludeSemantics(child: content),
    );
  }
}
