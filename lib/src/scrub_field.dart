import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A compact number chip, like the ones in design tools, that you drag
/// sideways to scrub its value or tap to type an exact number.
///
/// ```dart
/// ScrubField(
///   label: 'W',
///   suffix: 'px',
///   value: width,
///   min: 0,
///   max: 1200,
///   onChanged: (double v) => setState(() => width = v),
/// )
/// ```
///
/// Dragging horizontally changes the value by [step] for every
/// [sensitivity] pixels of movement: right increases, left decreases. On
/// desktop the mouse cursor shows a left-right resize arrow. Past [min] or
/// [max] the value stays clamped while the chip itself stretches a little
/// further with rubber-band resistance, then springs back when released.
///
/// Tapping (or clicking) without dragging turns the chip into an inline
/// text field with the current value selected. Enter or moving focus away
/// commits the typed number (clamped to the range); Escape cancels.
///
/// The field is controlled: it always shows [value] and reports new values
/// through [onChanged]. When [onChanged] is null or [enabled] is false it
/// renders dimmed and ignores input.
///
/// Accessibility: exposed as an adjustable control (a slider role) with
/// its formatted value and the values one [step] up and down; screen
/// readers can adjust it with their increase and decrease gestures, and
/// activating it opens the text field. When focused the arrow keys step
/// the value (hold Shift for ten steps) and Enter or Space starts typing.
///
/// Reduced motion: no rubber-band stretch or spring; the value simply
/// stops at the limit. Border and color changes switch instantly.
class ScrubField extends StatefulWidget {
  /// Creates a scrub field.
  const ScrubField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1.0,
    this.fractionDigits = 0,
    this.sensitivity = 4.0,
    this.label,
    this.suffix,
    this.width,
    this.textStyle,
    this.backgroundColor,
    this.accentColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.maxOvershoot = 18.0,
    this.duration = const Duration(milliseconds: 150),
    this.enabled = true,
    this.enableHaptics = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(min < max, 'min must be less than max'),
       assert(step > 0, 'step must be positive'),
       assert(
         fractionDigits >= 0 && fractionDigits <= 20,
         'fractionDigits must be between 0 and 20',
       ),
       assert(sensitivity > 0, 'sensitivity must be positive'),
       assert(maxOvershoot >= 0, 'maxOvershoot must not be negative'),
       assert(width == null || width > 0, 'width must be positive');

  /// The current value.
  final double value;

  /// Called with the new value while scrubbing, after typing a value, and
  /// on keyboard or assistive technology changes. When null the field
  /// renders disabled.
  final ValueChanged<double>? onChanged;

  /// Called with the current value when a scrub or edit starts.
  final ValueChanged<double>? onChangeStart;

  /// Called with the final value when a scrub or edit ends.
  final ValueChanged<double>? onChangeEnd;

  /// The smallest allowed value. Defaults to no lower limit.
  final double min;

  /// The largest allowed value. Defaults to no upper limit.
  final double max;

  /// Amount the value changes per scrub step or arrow key. Defaults to 1.
  final double step;

  /// Number of digits shown after the decimal point. Typed values are
  /// rounded to this precision. Defaults to 0.
  final int fractionDigits;

  /// Pixels of horizontal drag per [step]. Defaults to 4.
  final double sensitivity;

  /// Optional short label shown before the value, such as `W` or `Opacity`.
  final String? label;

  /// Optional unit shown after the value, such as `px` or `%`.
  final String? suffix;

  /// Fixed width of the chip. When null the chip sizes to its content.
  final double? width;

  /// Style of the value text. Defaults to the theme's `bodyMedium` with
  /// tabular figures and a medium weight.
  final TextStyle? textStyle;

  /// Background of the chip. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? backgroundColor;

  /// Color of the border and value while scrubbing or editing. Defaults to
  /// the theme's `colorScheme.primary`.
  final Color? accentColor;

  /// Corner radius of the chip. Defaults to 8.
  final BorderRadius borderRadius;

  /// Padding inside the chip.
  final EdgeInsetsGeometry padding;

  /// Furthest the chip can stretch past a limit, in pixels. 0 disables
  /// the rubber band. Defaults to 18.
  final double maxOvershoot;

  /// Length of the border and color transitions. Defaults to 150
  /// milliseconds.
  final Duration duration;

  /// When false the field renders dimmed and ignores input, exactly as if
  /// [onChanged] were null.
  final bool enabled;

  /// Whether a selection haptic tick plays on every scrub step. Defaults
  /// to false.
  final bool enableHaptics;

  /// Optional focus node for the chip (not the inline text field).
  final FocusNode? focusNode;

  /// Whether the chip requests focus when first built. Defaults to false.
  final bool autofocus;

  /// Semantic label announced for the field. Defaults to [label].
  final String? semanticLabel;

  @override
  State<ScrubField> createState() => _ScrubFieldState();
}

class _ScrubStepIntent extends Intent {
  const _ScrubStepIntent(this.steps);

  final int steps;
}

class _ScrubFieldState extends State<ScrubField>
    with SingleTickerProviderStateMixin {
  /// Visual stretch past a limit, in pixels. Negative means past [min].
  late final AnimationController _overshoot;
  final TextEditingController _text = TextEditingController();
  final FocusNode _editFocus = FocusNode(debugLabel: 'ScrubField edit');
  FocusNode? _ownChipFocus;

  bool _reducedMotion = false;
  bool _scrubbing = false;
  bool _editing = false;
  bool _hovering = false;
  bool _focusHighlight = false;

  double _dragStartValue = 0.0;
  double _dragDx = 0.0;

  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 20,
  );

  static const double _disabledOpacity = 0.45;

  /// Slope of the rubber band near the limit.
  static const double _rubberSlope = 0.55;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  FocusNode get _chipFocus =>
      widget.focusNode ?? (_ownChipFocus ??= FocusNode(debugLabel: 'Scrub'));

  @override
  void initState() {
    super.initState();
    _overshoot = AnimationController.unbounded(vsync: this);
    _editFocus.addListener(_onEditFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _overshoot.stop();
      _overshoot.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(ScrubField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive) {
      _scrubbing = false;
      _focusHighlight = false;
      if (_editing) _editing = false;
      if (_overshoot.value != 0.0) {
        _overshoot.stop();
        _overshoot.value = 0.0;
      }
    }
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownChipFocus?.dispose();
      _ownChipFocus = null;
    }
  }

  @override
  void dispose() {
    _editFocus.removeListener(_onEditFocusChange);
    _editFocus.dispose();
    _ownChipFocus?.dispose();
    _text.dispose();
    _overshoot.dispose();
    super.dispose();
  }

  // Values -------------------------------------------------------------

  /// Removes floating point noise such as 0.30000000000000004.
  double _clean(double value) {
    if (!value.isFinite) return value;
    return double.parse(value.toStringAsFixed(10));
  }

  double _clamp(double value) => value.clamp(widget.min, widget.max);

  String _format(double value) => value.toStringAsFixed(widget.fractionDigits);

  String _formatWithSuffix(double value) {
    final String? suffix = widget.suffix;
    return suffix == null ? _format(value) : '${_format(value)} $suffix';
  }

  void _emit(double value) {
    if (value == widget.value) return;
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onChanged?.call(value);
  }

  double _stepped(int steps) =>
      _clean(_clamp(widget.value + steps * widget.step));

  void _adjust(int steps) {
    if (!_interactive) return;
    final double next = _stepped(steps);
    if (next == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  /// Maps a drag past the limit (in pixels) to a damped visual stretch.
  double _rubberBand(double pixels) {
    final double limit = widget.maxOvershoot;
    if (limit <= 0 || pixels <= 0) return 0.0;
    return limit * (1 - 1 / (pixels * _rubberSlope / limit + 1));
  }

  // Scrubbing ----------------------------------------------------------

  void _handleDragStart(DragStartDetails details) {
    if (!_interactive || _editing) return;
    _overshoot.stop();
    _dragStartValue = widget.value;
    _dragDx = 0.0;
    setState(() => _scrubbing = true);
    widget.onChangeStart?.call(widget.value);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_scrubbing) return;
    _dragDx += details.delta.dx;
    final double steps = _dragDx / widget.sensitivity;
    final double raw = _dragStartValue + steps * widget.step;
    final double next = _clean(
      _clamp(_dragStartValue + steps.truncate() * widget.step),
    );
    if (!_reducedMotion) {
      double over = 0.0;
      if (raw > widget.max) {
        over = _rubberBand(
          (raw - widget.max) / widget.step * widget.sensitivity,
        );
      } else if (raw < widget.min) {
        over = -_rubberBand(
          (widget.min - raw) / widget.step * widget.sensitivity,
        );
      }
      _overshoot.value = over;
    }
    _emit(next);
  }

  void _handleDragEnd([DragEndDetails? details]) {
    if (!_scrubbing) return;
    setState(() => _scrubbing = false);
    _springBack();
    widget.onChangeEnd?.call(widget.value);
  }

  void _springBack() {
    if (_overshoot.value == 0.0) return;
    if (_reducedMotion) {
      _overshoot.value = 0.0;
      return;
    }
    _overshoot
        .animateWith(SpringSimulation(_spring, _overshoot.value, 0.0, 0.0))
        .then((_) {
          // The simulation stops within its tolerance; land exactly on 0.
          if (mounted && !_scrubbing) _overshoot.value = 0.0;
        });
  }

  // Editing ------------------------------------------------------------

  void _startEditing() {
    if (!_interactive || _editing) return;
    _text.value = TextEditingValue(
      text: _format(widget.value),
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: _format(widget.value).length,
      ),
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _editFocus.requestFocus();
    });
  }

  void _onEditFocusChange() {
    if (!_editFocus.hasFocus && _editing) _commit(restoreFocus: false);
  }

  void _commit({bool restoreFocus = true}) {
    if (!_editing) return;
    String input = _text.text.trim().replaceAll(',', '.');
    final String? suffix = widget.suffix;
    if (suffix != null && input.endsWith(suffix)) {
      input = input.substring(0, input.length - suffix.length).trim();
    }
    final double? parsed = double.tryParse(input);
    _finishEditing(restoreFocus: restoreFocus);
    if (parsed == null || !parsed.isFinite) return;
    final double next = _clean(
      double.parse(_clamp(parsed).toStringAsFixed(widget.fractionDigits)),
    );
    if (next == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    _emit(next);
    widget.onChangeEnd?.call(next);
  }

  void _cancel() => _finishEditing(restoreFocus: true);

  void _finishEditing({required bool restoreFocus}) {
    if (!_editing) return;
    setState(() => _editing = false);
    if (restoreFocus) _chipFocus.requestFocus();
  }

  // Building -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool interactive = _interactive;
    final Color accent = widget.accentColor ?? colorScheme.primary;
    final Color background =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest;
    final Duration duration = _reducedMotion ? Duration.zero : widget.duration;
    final bool active = _scrubbing || _editing;

    final TextStyle valueStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle())
            .copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: _scrubbing ? accent : colorScheme.onSurface,
            )
            .merge(widget.textStyle);
    final TextStyle sideStyle = valueStyle.copyWith(
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurfaceVariant,
    );

    final Color borderColor = active
        ? accent
        : _focusHighlight
        ? accent.withValues(alpha: 0.6)
        : _hovering
        ? colorScheme.outline.withValues(alpha: 0.6)
        : colorScheme.outlineVariant.withValues(alpha: 0.0);

    final Widget valueWidget = _editing
        ? _buildEditor(valueStyle, accent)
        : AnimatedDefaultTextStyle(
            duration: duration,
            style: valueStyle,
            child: Text(_format(widget.value), maxLines: 1),
          );

    Widget chip = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      width: widget.width,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(accent.withValues(alpha: 0.08), background)
            : background,
        borderRadius: widget.borderRadius,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.label != null) ...<Widget>[
            Text(widget.label!, style: sideStyle, maxLines: 1),
            const SizedBox(width: 8),
          ],
          if (widget.width != null)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: valueWidget,
              ),
            )
          else
            valueWidget,
          if (widget.suffix != null) ...<Widget>[
            const SizedBox(width: 3),
            Text(widget.suffix!, style: sideStyle, maxLines: 1),
          ],
        ],
      ),
    );

    // Rubber band: shift and stretch the chip towards the pulled side.
    chip = AnimatedBuilder(
      animation: _overshoot,
      child: chip,
      builder: (BuildContext context, Widget? child) {
        final double over = _overshoot.value;
        if (over == 0.0) return child!;
        final double stretch = over.abs() * 0.004;
        return Transform.translate(
          offset: Offset(over, 0),
          child: Transform.scale(
            scaleX: 1 + stretch,
            scaleY: 1 - stretch * 0.5,
            child: child,
          ),
        );
      },
    );

    final String? semanticLabel = widget.semanticLabel ?? widget.label;

    if (!interactive) {
      return Semantics(
        slider: true,
        enabled: false,
        label: semanticLabel,
        value: _formatWithSuffix(widget.value),
        child: Opacity(
          opacity: _disabledOpacity,
          child: ExcludeSemantics(child: chip),
        ),
      );
    }

    if (_editing) {
      // The text field provides its own semantics while editing.
      return Semantics(label: semanticLabel, child: chip);
    }

    chip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startEditing,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragEnd,
      child: chip,
    );

    return Semantics(
      slider: true,
      enabled: true,
      label: semanticLabel,
      value: _formatWithSuffix(widget.value),
      increasedValue: _formatWithSuffix(_stepped(1)),
      decreasedValue: _formatWithSuffix(_stepped(-1)),
      onIncrease: () => _adjust(1),
      onDecrease: () => _adjust(-1),
      onTap: _startEditing,
      child: FocusableActionDetector(
        focusNode: _chipFocus,
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.resizeLeftRight,
        onShowFocusHighlight: (bool value) {
          if (value != _focusHighlight) {
            setState(() => _focusHighlight = value);
          }
        },
        onShowHoverHighlight: (bool value) {
          if (value != _hovering) setState(() => _hovering = value);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _ScrubStepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _ScrubStepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _ScrubStepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _ScrubStepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
              _ScrubStepIntent(10),
          SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
              _ScrubStepIntent(10),
          SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
              _ScrubStepIntent(-10),
          SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
              _ScrubStepIntent(-10),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          _ScrubStepIntent: CallbackAction<_ScrubStepIntent>(
            onInvoke: (_ScrubStepIntent intent) {
              _adjust(intent.steps);
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _startEditing();
              return null;
            },
          ),
        },
        child: chip,
      ),
    );
  }

  Widget _buildEditor(TextStyle style, Color accent) {
    final bool signed = widget.min < 0;
    final bool decimal = widget.fractionDigits > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 28),
      child: IntrinsicWidth(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _cancel,
          },
          child: TextField(
            controller: _text,
            focusNode: _editFocus,
            autofocus: true,
            style: style,
            cursorColor: accent,
            cursorWidth: 1.5,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.numberWithOptions(
              signed: signed,
              decimal: decimal,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-+eE ]')),
            ],
            decoration: const InputDecoration.collapsed(hintText: null),
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _editFocus.unfocus(),
          ),
        ),
      ),
    );
  }
}
