import 'dart:ui' as ui;

// Grapheme iteration uses `Characters` from package:characters, which the
// Flutter SDK re-exports through material.dart.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// How a [TextReveal] splits its text into animated units.
enum TextRevealSplit {
  /// Every character (grapheme cluster) animates on its own. Characters of
  /// one word always stay together on the same line.
  ///
  /// Each character is shaped on its own, which would break letters that
  /// join or reorder. So the widget automatically animates whole words
  /// instead when the ambient [Directionality] is right-to-left or the
  /// text contains a joining or complex script: Hebrew, Arabic, Syriac,
  /// Thaana, N'Ko, Indic scripts (U+0900 to U+0DFF), Tibetan, Myanmar,
  /// Khmer or Mongolian.
  characters,

  /// Every word animates on its own.
  words,
}

/// The entrance effect applied to each unit of a [TextReveal].
enum TextRevealEffect {
  /// Fades the unit in.
  fade,

  /// Fades the unit in while it slides up from 0.4 em below its place.
  slideUp,

  /// Fades the unit in while a blur with a sigma of 6 clears to sharp text.
  blur,

  /// Fades the unit in while it grows from 60 percent to full size.
  scale,
}

/// Programmatic control for a [TextReveal].
///
/// The caller owns and disposes the controller. Calls made while no
/// [TextReveal] is attached are ignored.
///
/// ```dart
/// final TextRevealController reveal = TextRevealController();
/// // later
/// reveal.reset();
/// reveal.play();
/// ```
class TextRevealController extends ChangeNotifier {
  /// Incremented by [play] so the widget can detect play requests.
  int _playCount = 0;

  /// Incremented by [reset] so the widget can detect reset requests.
  int _resetCount = 0;

  /// Reported back by the attached widget.
  bool _isAnimating = false;

  /// Reported back by the attached widget.
  bool _isCompleted = false;

  /// Whether the attached [TextReveal] is currently revealing its text.
  /// Snapshot value, not a listenable property of its own.
  bool get isAnimating => _isAnimating;

  /// Whether the attached [TextReveal] shows its text fully revealed.
  /// Snapshot value, not a listenable property of its own.
  bool get isCompleted => _isCompleted;

  /// Starts the reveal. When the text is already fully revealed, the
  /// reveal replays from the start. Does nothing while a reveal runs.
  void play() {
    _playCount++;
    notifyListeners();
  }

  /// Stops any running reveal and hides the text again, ready for
  /// [play]. Has no visible effect under reduced motion or when the widget
  /// is disabled, where the text always stays fully visible.
  void reset() {
    _resetCount++;
    notifyListeners();
  }
}

/// A run of the source text: either whitespace or a word.
class _RevealSegment {
  const _RevealSegment.space(this.text)
    : isSpace = true,
      graphemes = const <String>[],
      firstUnit = 0;

  const _RevealSegment.word(this.text, this.graphemes, this.firstUnit)
    : isSpace = false;

  /// The full text of the segment.
  final String text;

  /// Whether the segment is whitespace (never animated).
  final bool isSpace;

  /// Grapheme clusters of a word segment.
  final List<String> graphemes;

  /// Index of the first animated unit of this segment.
  final int firstUnit;
}

/// Text that enters with a staggered animation, one character or one word
/// at a time.
///
/// ```dart
/// TextReveal(
///   text: 'Ship faster with less code',
///   effect: TextRevealEffect.blur,
///   splitBy: TextRevealSplit.words,
///   style: Theme.of(context).textTheme.headlineMedium,
/// )
/// ```
///
/// The text is split into units ([splitBy]) and each unit plays the
/// [effect] over [duration], starting [stagger] after the previous one.
/// The widget lays out like a normal paragraph from the first frame: every
/// unit keeps its final place while hidden, lines wrap at spaces, and the
/// characters of one word never break across lines. Units are iterated by
/// grapheme clusters, so emoji and accented characters are never split.
///
/// Joining, complex and right-to-left scripts always animate by words, so
/// their shaping stays intact (see [TextRevealSplit.characters]). Text
/// whose first letter is right-to-left is laid out right to left, word by
/// word; there, runs of whitespace collapse to a single space.
///
/// Changing [text] or [splitBy] replays the reveal. Use a
/// [TextRevealController] with `autoPlay: false` to start it later, for
/// example when the widget scrolls into view.
///
/// Accessibility: the widget exposes the full text (or [semanticLabel]) as
/// a single semantics node; the animated units are excluded.
///
/// Reduced motion and `enabled: false`: the final text is shown
/// immediately, no frames are scheduled and [onCompleted] still fires.
class TextReveal extends StatefulWidget {
  /// Creates a staggered text reveal.
  const TextReveal({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.splitBy = TextRevealSplit.characters,
    this.effect = TextRevealEffect.slideUp,
    this.duration = const Duration(milliseconds: 450),
    this.stagger = const Duration(milliseconds: 50),
    this.curve = Curves.easeOutCubic,
    this.autoPlay = true,
    this.controller,
    this.onCompleted,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The text to reveal.
  final String text;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal alignment of the paragraph. Defaults to [TextAlign.start].
  final TextAlign textAlign;

  /// Whether characters or words animate as units. Defaults to
  /// [TextRevealSplit.characters].
  final TextRevealSplit splitBy;

  /// The entrance effect of each unit. Defaults to
  /// [TextRevealEffect.slideUp].
  final TextRevealEffect effect;

  /// How long one unit takes to appear. Must be positive. Defaults to 450
  /// milliseconds.
  final Duration duration;

  /// Delay between the start of two consecutive units. Defaults to 50
  /// milliseconds. Around 40 milliseconds suits characters and 80
  /// milliseconds suits words.
  final Duration stagger;

  /// Curve applied to each unit. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// Whether the reveal starts on its own when the widget is first built.
  /// When false the text stays hidden until [TextRevealController.play].
  /// Defaults to true.
  final bool autoPlay;

  /// Optional playback controller. The caller owns and disposes it.
  final TextRevealController? controller;

  /// Called when the text is fully revealed. Also called under reduced
  /// motion and when [enabled] is false, where the text appears at once.
  final VoidCallback? onCompleted;

  /// When false the text is shown fully revealed without animation.
  final bool enabled;

  /// Semantics label exposed to assistive technology. Defaults to [text].
  final String? semanticLabel;

  @override
  State<TextReveal> createState() => _TextRevealState();
}

class _TextRevealState extends State<TextReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_RevealSegment> _segments = const <_RevealSegment>[];
  int _unitCount = 0;
  bool _reduced = false;

  /// Whether a reveal has been requested (autoPlay or a play call).
  bool _started = false;

  /// Whether [TextReveal.onCompleted] fired for the current reveal.
  bool _completedFired = false;

  int _seenPlayCount = 0;
  int _seenResetCount = 0;

  /// Whether the ambient [Directionality] is right-to-left.
  bool _rtl = false;

  /// Whether the parsed units are whole words.
  bool _byWords = false;

  bool get _static => _reduced || !widget.enabled;

  /// Whether the text must animate by words: requested, right-to-left
  /// context, or a joining or complex script.
  bool _wantsWords() =>
      widget.splitBy == TextRevealSplit.words ||
      _rtl ||
      _needsWordUnits(widget.text);

  @override
  void initState() {
    super.initState();
    _debugCheckConfig();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleStatus);
    _parse();
    _controller.duration = _totalDuration();
    _started = widget.autoPlay;
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (_wantsWords() != _byWords) {
      // Same text, new units: keep the current progress.
      _parse();
      _controller.duration = _totalDuration();
      if (_controller.isAnimating) _controller.forward();
    }
    _sync();
  }

  @override
  void didUpdateWidget(TextReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugCheckConfig();
    if (widget.controller != oldWidget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    }
    final bool textChanged =
        widget.text != oldWidget.text || _wantsWords() != _byWords;
    if (textChanged) {
      _parse();
    }
    if (textChanged ||
        widget.duration != oldWidget.duration ||
        widget.stagger != oldWidget.stagger) {
      _controller.duration = _totalDuration();
      if (_controller.isAnimating) {
        // Continue from the current point with the new timing.
        _controller.forward();
      }
    }
    if (textChanged) {
      // Replay the reveal for the new text.
      _completedFired = false;
      _started = _started || widget.autoPlay;
      _controller.value = 0.0;
    }
    _sync();
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _controller.dispose();
    super.dispose();
  }

  /// Durations cannot be compared in a const constructor, so they are
  /// validated here.
  void _debugCheckConfig() {
    assert(widget.duration > Duration.zero, 'duration must be positive');
    assert(widget.stagger >= Duration.zero, 'stagger must not be negative');
  }

  void _attach(TextRevealController? controller) {
    if (controller == null) return;
    _seenPlayCount = controller._playCount;
    _seenResetCount = controller._resetCount;
    controller.addListener(_handleControllerChanged);
    _report();
  }

  void _detach(TextRevealController? controller) {
    if (controller == null) return;
    controller.removeListener(_handleControllerChanged);
    controller._isAnimating = false;
    controller._isCompleted = false;
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final TextRevealController controller = widget.controller!;
    if (controller._resetCount != _seenResetCount) {
      _seenResetCount = controller._resetCount;
      if (!_static) {
        _started = false;
        _completedFired = false;
        _controller.value = 0.0;
      }
    }
    if (controller._playCount != _seenPlayCount) {
      _seenPlayCount = controller._playCount;
      _started = true;
      if (!_static && !_controller.isAnimating) {
        if (_controller.value >= 1.0) {
          _completedFired = false;
        }
        _controller.forward(from: _controller.value >= 1.0 ? 0.0 : null);
      }
    }
    _sync();
  }

  /// Splits [TextReveal.text] into whitespace runs and words.
  void _parse() {
    final List<_RevealSegment> segments = <_RevealSegment>[];
    final bool byWords = _wantsWords();
    int unit = 0;
    final StringBuffer buffer = StringBuffer();
    List<String> graphemes = <String>[];
    bool? inSpace;

    void flush() {
      if (buffer.isEmpty) return;
      if (inSpace!) {
        segments.add(_RevealSegment.space(buffer.toString()));
      } else {
        segments.add(_RevealSegment.word(buffer.toString(), graphemes, unit));
        unit += byWords ? 1 : graphemes.length;
      }
      buffer.clear();
      graphemes = <String>[];
    }

    for (final String grapheme in widget.text.characters) {
      final bool space = grapheme.trim().isEmpty;
      if (space != inSpace) {
        flush();
        inSpace = space;
      }
      buffer.write(grapheme);
      if (!space) graphemes.add(grapheme);
    }
    flush();
    _segments = segments;
    _unitCount = unit;
    _byWords = byWords;
  }

  Duration _totalDuration() {
    final int extra = _unitCount > 1 ? _unitCount - 1 : 0;
    return widget.duration + widget.stagger * extra;
  }

  /// Applies reduced motion, `enabled` and the playback request.
  void _sync() {
    if (_static) {
      if (_controller.isAnimating) _controller.stop();
      if (_controller.value < 1.0) {
        // Triggers the completed status, which fires onCompleted.
        _controller.value = 1.0;
      } else if (!_completedFired) {
        _fireCompleted();
      }
    } else if (_started &&
        !_controller.isAnimating &&
        _controller.value < 1.0) {
      _controller.forward();
    }
    _report();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completedFired) {
      _fireCompleted();
    }
    _report();
  }

  /// Calls [TextReveal.onCompleted], deferring it to after the frame when
  /// the framework is building, so callers may safely call setState.
  void _fireCompleted() {
    _completedFired = true;
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

  void _report() {
    final TextRevealController? controller = widget.controller;
    if (controller == null) return;
    controller._isAnimating = _controller.isAnimating;
    controller._isCompleted = _controller.value >= 1.0;
  }

  /// Curved progress of unit [index] in the range [0, 1] (or slightly
  /// outside for overshooting curves).
  double _unitProgress(int index) {
    if (_controller.value >= 1.0) return 1.0;
    final double durationUs = widget.duration.inMicroseconds.toDouble();
    final double totalUs = _controller.duration!.inMicroseconds.toDouble();
    final double elapsedUs = _controller.value * totalUs;
    final double startUs = index * widget.stagger.inMicroseconds.toDouble();
    final double t = ((elapsedUs - startUs) / durationUs).clamp(0.0, 1.0);
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return widget.curve.transform(t);
  }

  /// Builds one animated unit. Inside a [WidgetSpan] the paragraph already
  /// applies the text scale, so callers pass [TextScaler.noScaling] there.
  Widget _buildUnit(
    String text,
    int index,
    TextStyle style,
    double em,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final Widget label = Text(
      text,
      style: style,
      textScaler: textScaler,
      textDirection: direction,
      softWrap: false,
    );
    final TextRevealEffect effect = widget.effect;
    return AnimatedBuilder(
      animation: _controller,
      child: label,
      builder: (BuildContext context, Widget? child) {
        final double t = _unitProgress(index);
        final double opacity = t.clamp(0.0, 1.0);
        Widget result = child!;
        switch (effect) {
          case TextRevealEffect.fade:
            break;
          case TextRevealEffect.slideUp:
            result = Transform.translate(
              offset: Offset(0.0, (1.0 - t) * 0.4 * em),
              child: result,
            );
          case TextRevealEffect.blur:
            final double sigma = 6.0 * (1.0 - opacity);
            result = ImageFiltered(
              enabled: sigma > 0.01,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: result,
            );
          case TextRevealEffect.scale:
            result = Transform.scale(scale: 0.6 + 0.4 * t, child: result);
        }
        return Opacity(opacity: opacity, child: result);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    final double em = base.fontSize ?? kDefaultFontSize;
    final TextDirection ambient = Directionality.of(context);
    final TextDirection direction =
        _firstStrongDirection(widget.text) ?? ambient;

    final Widget content = direction == TextDirection.rtl
        ? _buildRightToLeft(context, base, em, ambient)
        : _buildParagraph(base, em, ambient);

    return Semantics(
      label: widget.semanticLabel ?? widget.text,
      container: true,
      child: ExcludeSemantics(child: RepaintBoundary(child: content)),
    );
  }

  /// Left-to-right layout: a paragraph with one inline widget per word, so
  /// lines can only wrap at the whitespace between words.
  Widget _buildParagraph(TextStyle base, double em, TextDirection ambient) {
    const TextDirection direction = TextDirection.ltr;
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final _RevealSegment segment in _segments) {
      if (segment.isSpace) {
        spans.add(TextSpan(text: segment.text));
        continue;
      }
      final Widget word;
      if (_byWords) {
        word = _buildUnit(
          segment.text,
          segment.firstUnit,
          base,
          em,
          direction,
          TextScaler.noScaling,
        );
      } else {
        word = Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: direction,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            for (int i = 0; i < segment.graphemes.length; i++)
              _buildUnit(
                segment.graphemes[i],
                segment.firstUnit + i,
                base,
                em,
                direction,
                TextScaler.noScaling,
              ),
          ],
        );
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: word,
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      textDirection: direction,
      textAlign: _physicalAlign(widget.textAlign, ambient, direction),
    );
  }

  /// Right-to-left layout. Inline widgets are not reordered by the
  /// paragraph's bidi algorithm, so the words are placed explicitly with a
  /// right-to-left [Wrap] per line. Runs of whitespace collapse to the
  /// width of one space.
  Widget _buildRightToLeft(
    BuildContext context,
    TextStyle base,
    double em,
    TextDirection ambient,
  ) {
    const TextDirection direction = TextDirection.rtl;
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final TextPainter space = TextPainter(
      text: TextSpan(text: ' ', style: base),
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    final double spaceWidth = space.width;
    space.dispose();

    final List<List<Widget>> lines = <List<Widget>>[<Widget>[]];
    for (final _RevealSegment segment in _segments) {
      if (segment.isSpace) {
        final int breaks = '\n'.allMatches(segment.text).length;
        for (int i = 0; i < breaks; i++) {
          lines.add(<Widget>[]);
        }
        continue;
      }
      lines.last.add(
        _buildUnit(
          segment.text,
          segment.firstUnit,
          base,
          em,
          direction,
          textScaler,
        ),
      );
    }

    // Resolve the alignment against the surrounding layout direction.
    final bool ambientLtr = ambient == TextDirection.ltr;
    final bool center = widget.textAlign == TextAlign.center;
    final bool left = switch (widget.textAlign) {
      TextAlign.left => true,
      TextAlign.right => false,
      TextAlign.end => !ambientLtr,
      _ => ambientLtr,
    };
    final WrapAlignment wrapAlignment = center
        ? WrapAlignment.center
        : (left ? WrapAlignment.end : WrapAlignment.start);

    final List<Widget> rows = <Widget>[
      for (final List<Widget> line in lines)
        if (line.isEmpty)
          // Keeps the height of an empty line.
          Text('', style: base, textScaler: textScaler)
        else
          Wrap(
            textDirection: direction,
            alignment: wrapAlignment,
            spacing: spaceWidth,
            children: line,
          ),
    ];
    if (rows.length == 1) return rows.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : (left ? CrossAxisAlignment.start : CrossAxisAlignment.end),
      children: rows,
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

/// Maps a directional [align] to a physical one when the paragraph
/// [direction] differs from the [ambient] one, so `start` keeps meaning the
/// start of the surrounding layout.
TextAlign _physicalAlign(
  TextAlign align,
  TextDirection ambient,
  TextDirection direction,
) {
  if (ambient == direction) return align;
  final bool ltr = ambient == TextDirection.ltr;
  return switch (align) {
    TextAlign.start => ltr ? TextAlign.left : TextAlign.right,
    TextAlign.end => ltr ? TextAlign.right : TextAlign.left,
    _ => align,
  };
}
