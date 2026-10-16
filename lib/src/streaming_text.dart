import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'utils/motion.dart';

/// How new words of a [StreamingText] appear.
enum StreamingTextEffect {
  /// New words fade in.
  fade,

  /// New words fade in while going from blurred to sharp.
  blur,
}

/// Text that animates new words as they arrive, for streaming responses
/// from a language model or any text that grows over time.
///
/// Pass the full text received so far and rebuild as more arrives. Only
/// the newly appended words animate; text already on screen never moves.
///
/// ```dart
/// StreamingText(
///   text: response, // grows as tokens arrive
///   isStreaming: !done,
///   showCursor: true,
/// )
/// ```
///
/// When [text] changes to something that does not extend the previous
/// value (for example a new answer), the whole text animates in again.
///
/// Performance: the paragraph is laid out once per text change, like a plain
/// [Text]. The per-frame work is paint only: arriving words are faded (and
/// optionally blurred) over the already laid out paragraph, so long answers
/// stream smoothly.
///
/// The cursor is painted just after the last glyph and may extend a few
/// pixels past the end of a full line.
///
/// Accessibility: screen readers always get the full current text. Under
/// reduced motion, or when [enabled] is false, words appear instantly and
/// the cursor does not pulse.
class StreamingText extends StatefulWidget {
  /// Creates streaming text.
  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.effect = StreamingTextEffect.fade,
    this.duration = const Duration(milliseconds: 400),
    this.wordDelay = const Duration(milliseconds: 25),
    this.curve = Curves.easeOut,
    this.blurSigma = 4.0,
    this.isStreaming = true,
    this.showCursor = false,
    this.cursorColor,
    this.enabled = true,
  }) : assert(blurSigma >= 0, 'blurSigma must not be negative');

  /// The full text received so far.
  final String text;

  /// Style of the text. Defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// How the text is aligned horizontally.
  final TextAlign? textAlign;

  /// How new words appear. Defaults to [StreamingTextEffect.fade].
  final StreamingTextEffect effect;

  /// How long one word takes to appear. Defaults to 400 milliseconds.
  final Duration duration;

  /// Delay between consecutive words of the same chunk, so a large chunk
  /// flows in instead of popping. Defaults to 25 milliseconds.
  final Duration wordDelay;

  /// Curve applied to each word. Defaults to [Curves.easeOut].
  final Curve curve;

  /// Initial blur of a word for [StreamingTextEffect.blur]. Defaults to 4.
  final double blurSigma;

  /// Whether more text is still expected. Controls the cursor.
  final bool isStreaming;

  /// Whether a pulsing cursor is shown after the text while
  /// [isStreaming] is true. Defaults to false.
  final bool showCursor;

  /// Color of the cursor. Defaults to the text color.
  final Color? cursorColor;

  /// When false words appear instantly.
  final bool enabled;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

/// A run of text, by UTF-16 range, that started appearing at [startMs].
class _Segment {
  _Segment(this.start, this.end, this.startMs);

  final int start;
  final int end;
  final double startMs;
}

/// Mutable paint state shared by the state object and the render object.
///
/// The state updates it and notifies; the render object only repaints, so
/// no frame triggers a rebuild or a relayout.
class _RevealFrame extends ChangeNotifier {
  /// Words still appearing, with their progress (0 to 1) after the curve.
  final List<(_Segment, double)> pending = <(_Segment, double)>[];

  StreamingTextEffect effect = StreamingTextEffect.fade;
  double blurSigma = 0;

  /// Whether the cursor is painted, and its pulse (0 to 1).
  bool cursorVisible = false;
  double cursorPulse = 1;
  Color cursorColor = const Color(0xFF000000);

  void markChanged() => notifyListeners();
}

class _StreamingTextState extends State<StreamingText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _RevealFrame _frame = _RevealFrame();

  /// The text currently laid out.
  String _text = '';

  /// Words still animating, in order.
  final List<_Segment> _segments = <_Segment>[];

  /// Elapsed time of the running ticker in milliseconds.
  double _nowMs = 0;

  /// Offset that keeps start times continuous across ticker restarts.
  double _baseMs = 0;

  bool _reducedMotion = false;

  bool get _animate => widget.enabled && !_reducedMotion;

  bool get _cursorOn => widget.showCursor && widget.isStreaming;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_text.isEmpty && widget.text.isNotEmpty) {
      _append(widget.text);
    }
    _sync();
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _text) {
      if (widget.text.startsWith(_text)) {
        _append(widget.text.substring(_text.length));
      } else {
        _text = '';
        _segments.clear();
        _append(widget.text);
      }
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  double get _delayMs => widget.wordDelay.inMicroseconds / 1000;

  double get _durationMs =>
      math.max(1.0, widget.duration.inMicroseconds / 1000);

  void _append(String chunk) {
    final int offset = _text.length;
    _text += chunk;
    if (!_animate || chunk.isEmpty) return;
    // Words start after the last pending word, never in the past, so a
    // fast stream keeps a steady left-to-right flow.
    double start = _nowMs;
    if (_segments.isNotEmpty) {
      start = math.max(start, _segments.last.startMs + _delayMs);
    }
    for (final Match m in RegExp(r'\s*\S+\s*|\s+').allMatches(chunk)) {
      _segments.add(_Segment(offset + m.start, offset + m.end, start));
      start += _delayMs;
    }
  }

  /// Starts or stops the ticker and refreshes the paint state.
  void _sync() {
    if (!_animate) _segments.clear();
    final bool needsTicker = _segments.isNotEmpty || (_cursorOn && _animate);
    if (needsTicker && !_ticker.isActive) {
      _baseMs = _nowMs;
      _ticker.start();
    } else if (!needsTicker && _ticker.isActive) {
      _ticker.stop();
    }
    _updateFrame();
  }

  void _onTick(Duration elapsed) {
    _nowMs = _baseMs + elapsed.inMicroseconds / 1000;
    while (_segments.isNotEmpty &&
        _nowMs - _segments.first.startMs >= _durationMs) {
      _segments.removeAt(0);
    }
    if (_segments.isEmpty && !(_cursorOn && _animate)) {
      _ticker.stop();
    }
    _updateFrame();
  }

  void _updateFrame() {
    final TextStyle base = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    _frame
      ..effect = widget.effect
      ..blurSigma = widget.blurSigma
      ..cursorVisible = _cursorOn
      ..cursorColor =
          widget.cursorColor ??
          base.color ??
          Theme.of(context).colorScheme.onSurface
      ..cursorPulse = _animate
          ? 0.5 + 0.5 * math.cos(2 * math.pi * _nowMs / 900)
          : 1.0;
    _frame.pending
      ..clear()
      ..addAll(<(_Segment, double)>[
        for (final _Segment s in _segments)
          (
            s,
            widget.curve.transform(
              ((_nowMs - s.startMs) / _durationMs).clamp(0.0, 1.0),
            ),
          ),
      ]);
    _frame.markChanged();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    final Color color = base.color ?? Theme.of(context).colorScheme.onSurface;
    return _StreamingReveal(
      frame: _frame,
      child: RichText(
        text: TextSpan(
          text: _text,
          style: base.copyWith(color: color),
        ),
        textAlign: widget.textAlign ?? TextAlign.start,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

/// Paints [child], a [RenderParagraph], with arriving words faded in.
class _StreamingReveal extends SingleChildRenderObjectWidget {
  const _StreamingReveal({required this.frame, required super.child});

  final _RevealFrame frame;

  @override
  _RenderStreamingReveal createRenderObject(BuildContext context) =>
      _RenderStreamingReveal(frame);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStreamingReveal renderObject,
  ) {
    renderObject.frame = frame;
  }
}

class _RenderStreamingReveal extends RenderProxyBox {
  _RenderStreamingReveal(this._frame);

  _RevealFrame _frame;

  set frame(_RevealFrame value) {
    if (identical(value, _frame)) return;
    if (attached) _frame.removeListener(markNeedsPaint);
    _frame = value;
    if (attached) _frame.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _frame.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _frame.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderObject? paragraph = child;
    if (paragraph is! RenderParagraph) {
      super.paint(context, offset);
      return;
    }
    final List<(_Segment, double)> pending = _frame.pending;
    if (pending.isEmpty) {
      context.paintChild(paragraph, offset);
    } else {
      final Canvas canvas = context.canvas;
      final Rect bounds = (offset & size).inflate(_frame.blurSigma * 3 + 4);
      canvas.saveLayer(bounds, Paint());
      context.paintChild(paragraph, offset);
      final bool blur =
          _frame.effect == StreamingTextEffect.blur && _frame.blurSigma > 0;
      for (final (_Segment segment, double t) in pending) {
        if (t >= 1) continue;
        final List<TextBox> boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: segment.start, extentOffset: segment.end),
        );
        for (final TextBox box in boxes) {
          final Rect rect = box.toRect().shift(offset);
          if (!blur) {
            // Remove (1 - t) of the word: it fades in over the paragraph.
            canvas.drawRect(
              rect,
              Paint()
                ..blendMode = BlendMode.dstOut
                ..color = Color.fromRGBO(0, 0, 0, 1 - t),
            );
            continue;
          }
          // Remove the sharp word, then draw it again blurred at alpha t.
          canvas.drawRect(rect, Paint()..blendMode = BlendMode.dstOut);
          final double sigma = _frame.blurSigma * (1 - t);
          canvas.saveLayer(
            rect.inflate(sigma * 3),
            Paint()
              ..color = Color.fromRGBO(0, 0, 0, t)
              ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          );
          canvas.clipRect(rect);
          // The paragraph has no children, so painting it again only draws
          // its cached text.
          paragraph.paint(context, offset);
          canvas.restore();
        }
      }
      canvas.restore();
    }

    if (_frame.cursorVisible) {
      _paintCursor(context.canvas, paragraph, offset);
    }
  }

  void _paintCursor(Canvas canvas, RenderParagraph paragraph, Offset offset) {
    final int end = paragraph.text.toPlainText().length;
    final Offset caret = paragraph.getOffsetForCaret(
      TextPosition(offset: end),
      Rect.zero,
    );
    final double lineHeight = paragraph.getFullHeightForCaret(
      TextPosition(offset: end),
    );
    final double radius = lineHeight * 0.3;
    final double pulse = _frame.cursorPulse;
    final Color color = _frame.cursorColor;
    canvas.drawCircle(
      offset + caret + Offset(radius * 1.6, lineHeight / 2),
      radius * (0.8 + 0.2 * pulse),
      Paint()..color = color.withValues(alpha: color.a * (0.35 + 0.65 * pulse)),
    );
  }
}
