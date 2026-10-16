import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A one-time code input with one slot per character, where every digit
/// springs into place as it is typed.
///
/// ```dart
/// CodeSlots(
///   length: 6,
///   autofocus: true,
///   onCompleted: (String code) => verify(code),
/// )
/// ```
///
/// Each new character drops into its slot from slightly above with a
/// small scale overshoot; backspace pops it out again. The active slot
/// shows a blinking caret and an accent border that glides from slot to
/// slot as you type. Setting [hasError] shakes the row once and paints the
/// slots in the error color until it is cleared.
///
/// Under the hood a single invisible [EditableText] covers the row, so the
/// platform keyboard, IME, hardware keyboards, paste of a full code and
/// SMS autofill ([AutofillHints.oneTimeCode]) all work as in any text
/// field; the visible slots are painted from its value. The cursor always
/// stays at the end. Tapping the row focuses it and opens the keyboard;
/// a long press shows the paste menu. With [numeric] (the default) only
/// digits are accepted and the numeric keyboard is requested. Pasted text
/// is filtered, so a code like `123-456` fills all six slots.
///
/// [onChanged] and [onCompleted] fire for user input only, matching
/// [TextField]: programmatic changes through [controller] update the slots
/// (with the same animation) but do not call them. [onCompleted] fires
/// once each time the code becomes complete.
///
/// Accessibility: exposed as a single text field labelled with
/// [semanticLabel] whose value is the code (obscured when [obscure] is
/// true).
///
/// Reduced motion: characters appear and disappear instantly, the accent
/// border jumps between slots, the caret does not blink and the error
/// state shows without shaking.
class CodeSlots extends StatefulWidget {
  /// Creates a one-time code input.
  const CodeSlots({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.numeric = true,
    this.obscure = false,
    this.hasError = false,
    this.enabled = true,
    this.slotWidth = 48,
    this.slotHeight = 56,
    this.gap = 10,
    this.borderRadius = 12,
    this.textStyle,
    this.activeColor,
    this.borderColor,
    this.fillColor,
    this.errorColor,
    this.textInputAction = TextInputAction.done,
    this.semanticLabel = 'Verification code',
  }) : assert(length > 0 && length <= 12, 'length must be between 1 and 12'),
       assert(slotWidth > 0, 'slotWidth must be positive'),
       assert(slotHeight > 0, 'slotHeight must be positive'),
       assert(gap >= 0, 'gap must not be negative'),
       assert(borderRadius >= 0, 'borderRadius must not be negative');

  /// Number of slots, and the length of a complete code. Defaults to 6.
  final int length;

  /// Called with the current code whenever the user changes it.
  final ValueChanged<String>? onChanged;

  /// Called once with the code each time the user fills the last slot.
  final ValueChanged<String>? onCompleted;

  /// Called when the user presses the keyboard's action button.
  final ValueChanged<String>? onSubmitted;

  /// Optional controller holding the code. When null an internal
  /// controller is used. The caller owns the controller and must dispose
  /// it. Only the first [length] characters are shown.
  final TextEditingController? controller;

  /// Optional focus node. When null an internal one is used.
  final FocusNode? focusNode;

  /// Whether the input requests focus when first built. Defaults to false.
  final bool autofocus;

  /// When true (the default) only digits are accepted and the numeric
  /// keyboard is requested. When false letters and digits are accepted.
  final bool numeric;

  /// When true each filled slot shows a dot instead of its character, and
  /// the value is obscured for assistive technology. Defaults to false.
  final bool obscure;

  /// When true the slots use [errorColor]. Switching from false to true
  /// also shakes the row once.
  final bool hasError;

  /// When false the input is dimmed, cannot be focused and ignores input.
  final bool enabled;

  /// Width of each slot. Slots shrink to fit when there is less room.
  /// Defaults to 48.
  final double slotWidth;

  /// Height of each slot. Defaults to 56.
  final double slotHeight;

  /// Horizontal gap between slots. Defaults to 10.
  final double gap;

  /// Corner radius of each slot. Defaults to 12.
  final double borderRadius;

  /// Style of the characters. Defaults to the theme's `headlineSmall` with
  /// tabular figures and a semibold weight.
  final TextStyle? textStyle;

  /// Color of the active slot border and the caret. Defaults to the
  /// theme's `colorScheme.primary`.
  final Color? activeColor;

  /// Border color of inactive slots. Defaults to the theme's
  /// `colorScheme.outlineVariant`.
  final Color? borderColor;

  /// Background of each slot. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest` at 50 percent alpha.
  final Color? fillColor;

  /// Border and caret color while [hasError] is true. Defaults to the
  /// theme's `colorScheme.error`.
  final Color? errorColor;

  /// The keyboard action button. Defaults to [TextInputAction.done].
  final TextInputAction textInputAction;

  /// Label announced by assistive technology. Defaults to
  /// `'Verification code'`.
  final String semanticLabel;

  @override
  State<CodeSlots> createState() => _CodeSlotsState();
}

/// Spring that drops a character into its slot.
final SpringSimulation _entrySpring = SpringSimulation(
  const SpringDescription(mass: 1, stiffness: 540, damping: 22),
  0.0,
  1.0,
  0.0,
);

/// How long an entering character animates, in seconds.
const double _entrySeconds = 0.7;

/// How long a removed character takes to pop out, in seconds.
const double _exitSeconds = 0.18;

/// Mutable animation state shared by the input and its painter.
class _SlotsField extends ChangeNotifier {
  _SlotsField(int length) {
    resize(length);
  }

  /// Character currently shown in each slot, or null when empty.
  late List<String?> chars;

  /// Seconds since each character entered. Negative means waiting for a
  /// staggered start; [double.infinity] means at rest.
  late List<double> enterAge;

  /// Character popping out of each slot, or null.
  late List<String?> exitChars;

  /// Seconds since each character started popping out.
  late List<double> exitAge;

  /// Position of the accent border, in slots.
  double highlight = 0.0;

  /// Velocity of the accent border, in slots per second.
  double highlightVelocity = 0.0;

  /// Opacity of the accent border, 0 when unfocused.
  double highlightAlpha = 0.0;

  /// Horizontal shake offset in pixels.
  double shakeOffset = 0.0;

  /// Seconds since the current shake started, or infinity when idle.
  double shakeAge = double.infinity;

  /// Opacity of the caret.
  double caretOpacity = 1.0;

  void resize(int length) {
    chars = List<String?>.filled(length, null);
    enterAge = List<double>.filled(length, double.infinity);
    exitChars = List<String?>.filled(length, null);
    exitAge = List<double>.filled(length, double.infinity);
  }

  /// Laid out glyphs, cached per character for one style.
  final Map<String, TextPainter> _glyphs = <String, TextPainter>{};
  TextStyle? _glyphStyle;
  TextDirection? _glyphDirection;

  TextPainter glyph(String char, TextStyle style, TextDirection direction) {
    if (style != _glyphStyle || direction != _glyphDirection) {
      _clearGlyphs();
      _glyphStyle = style;
      _glyphDirection = direction;
    }
    return _glyphs.putIfAbsent(char, () {
      return TextPainter(
        text: TextSpan(text: char, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
    });
  }

  void _clearGlyphs() {
    for (final TextPainter painter in _glyphs.values) {
      painter.dispose();
    }
    _glyphs.clear();
  }

  void notify() => notifyListeners();

  @override
  void dispose() {
    _clearGlyphs();
    super.dispose();
  }
}

/// Filters the input to allowed characters and limits it to the code
/// length, letting a pasted full code replace the current one.
class _CodeFormatter extends TextInputFormatter {
  _CodeFormatter({required this.length, required this.numeric});

  final int length;
  final bool numeric;

  static final RegExp _notDigit = RegExp(r'[^0-9]');
  static final RegExp _notAlphanumeric = RegExp(r'[^0-9A-Za-z]');

  String _filter(String text) =>
      text.replaceAll(numeric ? _notDigit : _notAlphanumeric, '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String oldText = _filter(oldValue.text);
    String text = _filter(newValue.text);
    if (text.length > length) {
      if (text.length - oldText.length >= length) {
        // A whole code was pasted or autofilled: it replaces the old one.
        final String inserted = text.startsWith(oldText)
            ? text.substring(oldText.length)
            : text;
        text = inserted.substring(0, length);
      } else {
        text = text.substring(0, length);
      }
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CodeSlotsState extends State<CodeSlots> with TickerProviderStateMixin {
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  late final _SlotsField _field;
  late final Ticker _ticker;
  late final AnimationController _caret;
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  Duration _lastTick = Duration.zero;
  bool _reducedMotion = false;
  bool _focused = false;
  String? _completedCode;

  /// Delay between characters that arrive together, such as a paste.
  static const double _stagger = 0.045;

  /// Length and amplitude of the error shake.
  static const double _shakeSeconds = 0.45;
  static const double _shakeAmplitude = 9.0;

  static const double _highlightStiffness = 520.0;
  static const double _disabledOpacity = 0.45;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CodeSlots'));

  int get _activeIndex =>
      math.min(_visibleText.length, widget.length - 1).toInt();

  String get _visibleText {
    final String text = _controller.text;
    return text.length > widget.length
        ? text.substring(0, widget.length)
        : text;
  }

  @override
  void initState() {
    super.initState();
    _field = _SlotsField(widget.length);
    _ticker = createTicker(_onTick);
    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addListener(_onCaretTick);
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _focused = _focusNode.hasFocus;
    _syncChars(animate: false);
    _field.highlight = _activeIndex.toDouble();
    _field.highlightAlpha = _focused ? 1.0 : 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) _settleNow();
    _syncCaret();
  }

  @override
  void didUpdateWidget(CodeSlots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChanged);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocusChanged);
      _focused = _focusNode.hasFocus;
    }
    if (oldWidget.length != widget.length) {
      _field.resize(widget.length);
      _syncChars(animate: false);
      _field.highlight = _activeIndex.toDouble();
      _field.notify();
    } else if (oldWidget.controller != widget.controller) {
      _syncChars(animate: true);
    }
    if (widget.hasError && !oldWidget.hasError) _shake();
    if (!widget.enabled && oldWidget.enabled) {
      _focusNode.unfocus();
    }
    _syncCaret();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _caret.dispose();
    _ticker.dispose();
    _field.dispose();
    super.dispose();
  }

  // Text and focus -----------------------------------------------------

  void _onTextChanged() {
    final TextEditingValue value = _controller.value;
    final TextSelection end = TextSelection.collapsed(
      offset: value.text.length,
    );
    if (value.selection != end) {
      // Keep the cursor at the end whatever the platform tries.
      _controller.selection = end;
      return;
    }
    _syncChars(animate: true);
  }

  void _syncChars({required bool animate}) {
    final String text = _visibleText;
    final bool motion = animate && !_reducedMotion;
    int arrivals = 0;
    bool changed = false;
    for (int i = 0; i < widget.length; i++) {
      final String? next = i < text.length ? text[i] : null;
      final String? previous = _field.chars[i];
      if (next == previous) continue;
      changed = true;
      if (motion && previous != null) {
        _field.exitChars[i] = previous;
        _field.exitAge[i] = 0.0;
      } else {
        _field.exitChars[i] = null;
        _field.exitAge[i] = double.infinity;
      }
      if (next != null) {
        _field.enterAge[i] = motion ? -_stagger * arrivals : double.infinity;
        arrivals++;
      }
      _field.chars[i] = next;
    }
    if (!changed) return;
    if (motion) {
      _ensureTicking();
    } else {
      _field.highlight = _activeIndex.toDouble();
    }
    _restartCaret();
    _field.notify();
  }

  void _onFocusChanged() {
    final bool focused = _focusNode.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (_reducedMotion) {
      _field.highlightAlpha = focused ? 1.0 : 0.0;
      _field.highlight = _activeIndex.toDouble();
      _field.notify();
    } else {
      _ensureTicking();
    }
    _syncCaret();
  }

  void _handleUserChange(String text) {
    widget.onChanged?.call(text);
    if (text.length >= widget.length) {
      if (_completedCode != text) {
        _completedCode = text;
        widget.onCompleted?.call(text);
      }
    } else {
      _completedCode = null;
    }
  }

  void _requestKeyboard() {
    if (!widget.enabled) return;
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    _editableKey.currentState?.requestKeyboard();
  }

  void _showPasteMenu() {
    if (!widget.enabled) return;
    _requestKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editableKey.currentState?.showToolbar();
    });
  }

  // Animation ----------------------------------------------------------

  void _shake() {
    if (_reducedMotion) return;
    _field.shakeAge = 0.0;
    _ensureTicking();
  }

  void _ensureTicking() {
    if (_reducedMotion) {
      _settleNow();
      return;
    }
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _settleNow() {
    if (_ticker.isActive) _ticker.stop();
    for (int i = 0; i < widget.length; i++) {
      _field.enterAge[i] = double.infinity;
      _field.exitChars[i] = null;
      _field.exitAge[i] = double.infinity;
    }
    _field.highlight = _activeIndex.toDouble();
    _field.highlightVelocity = 0.0;
    _field.highlightAlpha = _focused ? 1.0 : 0.0;
    _field.shakeAge = double.infinity;
    _field.shakeOffset = 0.0;
    _field.notify();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Long frames (hitches, or big test pumps) advance the full time; the
    // sub steps below keep the integration stable.
    dt = math.min(dt, 0.5);
    bool busy = false;

    for (int i = 0; i < widget.length; i++) {
      if (_field.enterAge[i].isFinite) {
        _field.enterAge[i] += dt;
        if (_field.enterAge[i] >= _entrySeconds) {
          _field.enterAge[i] = double.infinity;
        } else {
          busy = true;
        }
      }
      if (_field.exitAge[i].isFinite) {
        _field.exitAge[i] += dt;
        if (_field.exitAge[i] >= _exitSeconds) {
          _field.exitAge[i] = double.infinity;
          _field.exitChars[i] = null;
        } else {
          busy = true;
        }
      }
    }

    // Accent border: a slightly springy glide towards the active slot.
    final double target = _activeIndex.toDouble();
    final double damping = 2 * math.sqrt(_highlightStiffness) * 0.78;
    final int subSteps = (dt / (1 / 240)).ceil();
    final double h = dt / subSteps;
    for (int s = 0; s < subSteps; s++) {
      final double accel =
          -_highlightStiffness * (_field.highlight - target) -
          damping * _field.highlightVelocity;
      _field.highlightVelocity += accel * h;
      _field.highlight += _field.highlightVelocity * h;
    }
    if ((_field.highlight - target).abs() < 1e-3 &&
        _field.highlightVelocity.abs() < 1e-2) {
      _field.highlight = target;
      _field.highlightVelocity = 0.0;
    } else {
      busy = true;
    }

    final double alphaTarget = _focused ? 1.0 : 0.0;
    _field.highlightAlpha +=
        (alphaTarget - _field.highlightAlpha) * (1 - math.exp(-dt * 16));
    if ((_field.highlightAlpha - alphaTarget).abs() < 0.01) {
      _field.highlightAlpha = alphaTarget;
    } else {
      busy = true;
    }

    if (_field.shakeAge.isFinite) {
      _field.shakeAge += dt;
      final double t = _field.shakeAge / _shakeSeconds;
      if (t >= 1) {
        _field.shakeAge = double.infinity;
        _field.shakeOffset = 0.0;
      } else {
        _field.shakeOffset =
            math.sin(t * math.pi * 6) * _shakeAmplitude * (1 - t) * (1 - t);
        busy = true;
      }
    }

    _field.notify();
    if (!busy) _ticker.stop();
  }

  bool get _caretShouldBlink =>
      _focused &&
      widget.enabled &&
      !_reducedMotion &&
      _visibleText.length < widget.length;

  void _syncCaret() {
    if (_caretShouldBlink) {
      if (!_caret.isAnimating) _caret.repeat();
    } else {
      _caret.stop();
      _caret.value = 0.0;
      _field.caretOpacity = 1.0;
    }
  }

  void _restartCaret() {
    if (_caretShouldBlink) {
      _caret.value = 0.0;
      _caret.repeat();
    } else {
      _syncCaret();
    }
  }

  void _onCaretTick() {
    // Visible for the first half, a quick fade out and back in.
    final double t = _caret.value;
    final double opacity;
    if (t < 0.5) {
      opacity = 1.0;
    } else if (t < 0.6) {
      opacity = 1.0 - (t - 0.5) / 0.1;
    } else if (t < 0.9) {
      opacity = 0.0;
    } else {
      opacity = (t - 0.9) / 0.1;
    }
    if (opacity != _field.caretOpacity) {
      _field.caretOpacity = opacity;
      _field.notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool enabled = widget.enabled;
    final Color activeColor = widget.activeColor ?? colorScheme.primary;
    final Color errorColor = widget.errorColor ?? colorScheme.error;
    final TextStyle textStyle =
        (theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24))
            .copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            )
            .merge(widget.textStyle);

    final Widget editable = EditableText(
      key: _editableKey,
      controller: _controller,
      focusNode: _focusNode,
      readOnly: !enabled,
      autofocus: widget.autofocus && enabled,
      style: textStyle.copyWith(color: Colors.transparent),
      cursorColor: Colors.transparent,
      backgroundCursorColor: Colors.transparent,
      selectionColor: Colors.transparent,
      showCursor: false,
      showSelectionHandles: false,
      rendererIgnoresPointer: true,
      maxLines: 1,
      keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
      textCapitalization: widget.numeric
          ? TextCapitalization.none
          : TextCapitalization.characters,
      textInputAction: widget.textInputAction,
      autofillHints: const <String>[AutofillHints.oneTimeCode],
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      obscureText: widget.obscure,
      inputFormatters: <TextInputFormatter>[
        _CodeFormatter(length: widget.length, numeric: widget.numeric),
      ],
      onChanged: _handleUserChange,
      onSubmitted: widget.onSubmitted,
      contextMenuBuilder:
          (BuildContext context, EditableTextState editableTextState) {
            return AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            );
          },
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int length = widget.length;
        double slotWidth = widget.slotWidth;
        double gap = widget.gap;
        final double natural = length * slotWidth + (length - 1) * gap;
        if (constraints.hasBoundedWidth && natural > constraints.maxWidth) {
          final double scale = constraints.maxWidth / natural;
          slotWidth *= scale;
          gap *= scale;
        }
        final double width = length * slotWidth + (length - 1) * gap;

        final Widget slots = RepaintBoundary(
          child: CustomPaint(
            size: Size(width, widget.slotHeight),
            painter: _SlotsPainter(
              field: _field,
              slotWidth: slotWidth,
              slotHeight: widget.slotHeight,
              gap: gap,
              radius: widget.borderRadius,
              textStyle: textStyle,
              activeColor: widget.hasError ? errorColor : activeColor,
              borderColor: widget.hasError
                  ? errorColor.withValues(alpha: 0.7)
                  : widget.borderColor ?? colorScheme.outlineVariant,
              filledBorderColor: widget.hasError
                  ? errorColor.withValues(alpha: 0.7)
                  : widget.borderColor ??
                        colorScheme.outline.withValues(alpha: 0.55),
              fillColor: widget.hasError
                  ? Color.alphaBlend(
                      errorColor.withValues(alpha: 0.08),
                      widget.fillColor ??
                          colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    )
                  : widget.fillColor ??
                        colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
              obscure: widget.obscure,
              showCaret: _focused && enabled,
              textDirection: Directionality.of(context),
            ),
          ),
        );

        Widget result = SizedBox(
          width: width,
          height: widget.slotHeight,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: slots),
              Positioned.fill(
                child: ExcludeFocus(excluding: !enabled, child: editable),
              ),
            ],
          ),
        );

        result = MouseRegion(
          cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _requestKeyboard : null,
            onLongPress: enabled ? _showPasteMenu : null,
            excludeFromSemantics: true,
            child: result,
          ),
        );

        if (!enabled) {
          result = Opacity(opacity: _disabledOpacity, child: result);
        }

        return MergeSemantics(
          child: Semantics(
            label: widget.semanticLabel,
            enabled: enabled,
            onTap: enabled ? _requestKeyboard : null,
            child: result,
          ),
        );
      },
    );
  }
}

class _SlotsPainter extends CustomPainter {
  _SlotsPainter({
    required this.field,
    required this.slotWidth,
    required this.slotHeight,
    required this.gap,
    required this.radius,
    required this.textStyle,
    required this.activeColor,
    required this.borderColor,
    required this.filledBorderColor,
    required this.fillColor,
    required this.obscure,
    required this.showCaret,
    required this.textDirection,
  }) : super(repaint: field);

  final _SlotsField field;
  final double slotWidth;
  final double slotHeight;
  final double gap;
  final double radius;
  final TextStyle textStyle;
  final Color activeColor;
  final Color borderColor;
  final Color filledBorderColor;
  final Color fillColor;
  final bool obscure;
  final bool showCaret;
  final TextDirection textDirection;

  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  void _paintChar(
    Canvas canvas,
    Offset center,
    String char, {
    required double scale,
    required double opacity,
    required double dy,
  }) {
    if (opacity <= 0 || scale <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy + dy);
    canvas.scale(scale);
    if (obscure) {
      _fill.color = textStyle.color!.withValues(
        alpha: textStyle.color!.a * opacity,
      );
      canvas.drawCircle(Offset.zero, slotHeight * 0.085, _fill);
    } else {
      final TextPainter glyph = field.glyph(char, textStyle, textDirection);
      final Rect bounds =
          Offset(-glyph.width / 2, -glyph.height / 2) &
          Size(glyph.width, glyph.height);
      if (opacity < 1) {
        canvas.saveLayer(
          bounds.inflate(4),
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
        glyph.paint(canvas, bounds.topLeft);
        canvas.restore();
      } else {
        glyph.paint(canvas, bounds.topLeft);
      }
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int length = field.chars.length;
    final bool rtl = textDirection == TextDirection.rtl;
    final double pitch = slotWidth + gap;

    // Slot rectangle at a (possibly fractional) index, in reading order.
    Rect slotRect(double index) {
      final double left = rtl
          ? size.width - slotWidth - index * pitch
          : index * pitch;
      return Rect.fromLTWH(left, 0, slotWidth, slotHeight);
    }

    canvas.save();
    canvas.translate(field.shakeOffset, 0);
    final Radius r = Radius.circular(radius);

    for (int i = 0; i < length; i++) {
      final RRect rrect = RRect.fromRectAndRadius(
        slotRect(i.toDouble()).deflate(0.75),
        r,
      );
      _fill.color = fillColor;
      canvas.drawRRect(rrect, _fill);
      _stroke
        ..strokeWidth = 1.5
        ..color = field.chars[i] != null ? filledBorderColor : borderColor;
      canvas.drawRRect(rrect, _stroke);
    }

    // Accent border gliding between slots, with a soft outer halo.
    if (field.highlightAlpha > 0) {
      final double index = field.highlight.clamp(0.0, length - 1.0).toDouble();
      final RRect rrect = RRect.fromRectAndRadius(
        slotRect(index).deflate(0.75),
        r,
      );
      _stroke
        ..strokeWidth = 4
        ..color = activeColor.withValues(alpha: 0.18 * field.highlightAlpha);
      canvas.drawRRect(rrect.inflate(2), _stroke);
      _stroke
        ..strokeWidth = 2
        ..color = activeColor.withValues(alpha: field.highlightAlpha);
      canvas.drawRRect(rrect, _stroke);
    }

    final double drop = slotHeight * 0.22;
    int filled = 0;
    for (int i = 0; i < length; i++) {
      final Offset center = slotRect(i.toDouble()).center;

      final String? exiting = field.exitChars[i];
      if (exiting != null && field.exitAge[i].isFinite) {
        final double p = (field.exitAge[i] / _exitSeconds)
            .clamp(0.0, 1.0)
            .toDouble();
        final double eased = Curves.easeIn.transform(p);
        _paintChar(
          canvas,
          center,
          exiting,
          scale: 1 - 0.55 * eased,
          opacity: 1 - eased,
          dy: drop * 0.35 * eased,
        );
      }

      final String? char = field.chars[i];
      if (char == null) continue;
      filled = i + 1;
      final double age = field.enterAge[i];
      if (!age.isFinite) {
        _paintChar(canvas, center, char, scale: 1, opacity: 1, dy: 0);
        continue;
      }
      if (age < 0) continue;
      final double e = _entrySpring.x(age);
      _paintChar(
        canvas,
        center,
        char,
        scale: 0.55 + 0.45 * e,
        opacity: (age / 0.09).clamp(0.0, 1.0).toDouble(),
        dy: -(1 - e) * drop,
      );
    }

    // Caret in the active empty slot.
    if (showCaret && filled < length && field.caretOpacity > 0) {
      // The caret rides with the gliding accent border.
      final Rect rect = slotRect(
        field.highlight.clamp(0.0, length - 1.0).toDouble(),
      );
      _fill.color = activeColor.withValues(alpha: field.caretOpacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: 2,
            height: slotHeight * 0.42,
          ),
          const Radius.circular(1),
        ),
        _fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlotsPainter oldDelegate) =>
      oldDelegate.field != field ||
      oldDelegate.slotWidth != slotWidth ||
      oldDelegate.slotHeight != slotHeight ||
      oldDelegate.gap != gap ||
      oldDelegate.radius != radius ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.filledBorderColor != filledBorderColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.obscure != obscure ||
      oldDelegate.showCaret != showCaret ||
      oldDelegate.textDirection != textDirection;
}
