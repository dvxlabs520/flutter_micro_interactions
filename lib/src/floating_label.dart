import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// A text field whose label animates between the hint position and a
/// floated position above the input text.
///
/// The label rests inside the field like a hint. When the field gains
/// focus or contains text, the label visibly slides up and shrinks into
/// the floated position, animated with [duration] and [curve]. The label
/// color follows focus (primary color) and validation errors (error
/// color).
///
/// The field is a real [TextFormField]: [validator] participates in
/// `Form.of(context).validate()` and error text is rendered by the
/// decoration itself.
///
/// When the platform requests reduced motion the label jumps between
/// positions without animating.
///
/// ```dart
/// FloatingLabel(
///   label: 'Email',
///   keyboardType: TextInputType.emailAddress,
///   validator: (value) =>
///       (value == null || !value.contains('@')) ? 'Invalid email' : null,
/// )
/// ```
class FloatingLabel extends StatefulWidget {
  /// Creates a floating label text field.
  const FloatingLabel({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.style,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.border,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
  }) : assert(maxLines == null || maxLines > 0, 'maxLines must be positive'),
       assert(minLines == null || minLines > 0, 'minLines must be positive');

  /// The text shown as the animated floating label.
  final String label;

  /// Optional hint shown inside the field while it is focused and empty
  /// (once the label has floated out of the way).
  final String? hint;

  /// Controls the text being edited. When null an internal controller is
  /// created and disposed by this widget.
  final TextEditingController? controller;

  /// Focus node of the field. When null an internal node is created and
  /// disposed by this widget.
  final FocusNode? focusNode;

  /// Validator wired to [TextFormField.validator]; it participates in
  /// `Form.validate()`.
  final String? Function(String?)? validator;

  /// When validation runs automatically. Defaults to
  /// [AutovalidateMode.disabled].
  final AutovalidateMode autovalidateMode;

  /// Whether the text is obscured (for passwords).
  final bool obscureText;

  /// Keyboard type for the field.
  final TextInputType? keyboardType;

  /// The action button on the software keyboard.
  final TextInputAction? textInputAction;

  /// Input formatters applied to the field.
  final List<TextInputFormatter>? inputFormatters;

  /// Style of the input text. The resting label matches this style's
  /// font size.
  final TextStyle? style;

  /// Icon shown before the input text.
  final Widget? prefixIcon;

  /// Icon shown after the input text.
  final Widget? suffixIcon;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Border of the field. Defaults to an [OutlineInputBorder].
  final InputBorder? border;

  /// Whether the field accepts input.
  final bool enabled;

  /// Maximum number of lines. Defaults to 1.
  final int? maxLines;

  /// Minimum number of lines.
  final int? minLines;

  /// Length of the label float animation. Defaults to 200 milliseconds.
  final Duration duration;

  /// Curve of the label float animation. Defaults to [Curves.easeOut].
  final Curve curve;

  @override
  State<FloatingLabel> createState() => _FloatingLabelState();
}

class _FloatingLabelState extends State<FloatingLabel>
    with SingleTickerProviderStateMixin {
  // Fixed geometry so the animated label lines up with the input text.
  static const double _horizontalPadding = 12.0;
  static const double _topPadding = 22.0;
  static const double _bottomPadding = 14.0;
  static const double _prefixIconWidth = 48.0;
  static const double _floatedTop = 6.0;
  static const double _floatedScale = 0.75;

  late final AnimationController _floatController;
  late CurvedAnimation _float;

  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  bool _hasError = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _shouldFloat =>
      _effectiveFocusNode.hasFocus || _effectiveController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _float = CurvedAnimation(parent: _floatController, curve: widget.curve);
    _effectiveController.addListener(_updateFloat);
    _effectiveFocusNode.addListener(_updateFloat);
    if (_shouldFloat) {
      _floatController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FloatingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _floatController.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _float.dispose();
      _float = CurvedAnimation(parent: _floatController, curve: widget.curve);
    }
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _updateFloat,
      );
      if (widget.controller != null && _internalController != null) {
        _internalController!.dispose();
        _internalController = null;
      }
      _effectiveController.addListener(_updateFloat);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(_updateFloat);
      if (widget.focusNode != null && _internalFocusNode != null) {
        _internalFocusNode!.dispose();
        _internalFocusNode = null;
      }
      _effectiveFocusNode.addListener(_updateFloat);
    }
    _syncFloat(animate: true);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_updateFloat);
    widget.focusNode?.removeListener(_updateFloat);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    _float.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _updateFloat() {
    if (!mounted) return;
    setState(() {});
    _syncFloat(animate: true);
  }

  void _syncFloat({required bool animate}) {
    if (!animate || MicroMotion.isReduced(context)) {
      _floatController.stop();
      _floatController.value = _shouldFloat ? 1.0 : 0.0;
      return;
    }
    if (_shouldFloat) {
      _floatController.forward();
    } else {
      _floatController.reverse();
    }
  }

  String? _runValidator(String? value) {
    final String? result = widget.validator?.call(value);
    final bool hasError = result != null;
    if (hasError != _hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasError = hasError;
          });
        }
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle inputStyle =
        widget.style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final double labelLeft = widget.prefixIcon != null
        ? _prefixIconWidth
        : _horizontalPadding + 4.0;

    final Color labelColor = _hasError
        ? theme.colorScheme.error
        : _effectiveFocusNode.hasFocus
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Stack(
      children: <Widget>[
        TextFormField(
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          validator: widget.validator == null ? null : _runValidator,
          autovalidateMode: widget.autovalidateMode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          style: inputStyle,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          decoration: InputDecoration(
            // The label is drawn by this widget; only show the hint once
            // the label has floated out of the way.
            hintText: _shouldFloat ? widget.hint : null,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            border: widget.border ?? const OutlineInputBorder(),
            contentPadding: const EdgeInsets.fromLTRB(
              _horizontalPadding + 4.0,
              _topPadding,
              _horizontalPadding,
              _bottomPadding,
            ),
          ),
        ),
        // The animated label. Pointer events pass through to the field.
        Positioned(
          left: labelLeft,
          top: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _float,
              builder: (BuildContext context, Widget? child) {
                final double t = _float.value;
                final double top = lerpDouble(_topPadding, _floatedTop, t)!;
                final double scale = lerpDouble(1.0, _floatedScale, t)!;
                return Transform.translate(
                  offset: Offset(0, top),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: child,
                  ),
                );
              },
              child: AnimatedDefaultTextStyle(
                duration: MicroMotion.effectiveDuration(
                  context,
                  widget.duration,
                ),
                curve: widget.curve,
                style: inputStyle.copyWith(color: labelColor),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
