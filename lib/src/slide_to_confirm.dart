import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// Programmatic control for a [SlideToConfirm] widget.
///
/// ```dart
/// final controller = SlideToConfirmController();
/// // ...
/// SlideToConfirm(
///   controller: controller,
///   onConfirmed: submitPayment,
/// );
/// // later, for example after the payment fails:
/// controller.reset();
/// ```
///
/// [isConfirmed] reflects whether the attached control has been confirmed.
/// Dispose the controller yourself when it is no longer needed.
class SlideToConfirmController extends ChangeNotifier {
  bool _isConfirmed = false;
  bool _resetRequested = false;

  /// Whether the attached control is currently in its confirmed state.
  bool get isConfirmed => _isConfirmed;

  /// Returns the attached control to its initial state so it can be used
  /// again. A no-op when the control is already at rest.
  void reset() {
    _resetRequested = true;
    notifyListeners();
  }
}

/// A slide-to-confirm control: the user drags a thumb across a track to the
/// end to confirm an action, in the style of payment and destructive action
/// confirmations.
///
/// ```dart
/// SlideToConfirm(
///   label: 'Slide to pay',
///   onConfirmed: submitPayment,
/// )
/// ```
///
/// Dragging moves the thumb along the track; [label] fades out as progress
/// grows and a fill in [fillColor] advances behind the thumb. Releasing
/// below [confirmThreshold] springs the thumb back to the start. Releasing
/// at or past the threshold animates the thumb to the end, plays a light
/// haptic, cross-fades [confirmedChild] in, and calls [onConfirmed] exactly
/// once. With [resetAfterConfirm] the control springs back to its initial
/// state after [resetDelay]; otherwise call [SlideToConfirmController.reset]
/// to reuse it.
///
/// The slide direction follows the ambient [Directionality]: the thumb
/// always travels from the start edge to the end edge.
///
/// Accessibility: the slide gesture is hard to perform for motor-impaired
/// users, so the control is also exposed to assistive technology as a
/// button labelled [label] whose semantic tap confirms directly, without the
/// gesture. It is focusable, and pressing Enter or Space while focused also
/// confirms. Under reduced motion dragging still works, but the spring-back
/// and settle animations jump instantly to their end state.
///
/// When [enabled] is `false` the control renders dimmed, ignores gestures
/// and keyboard input, and its semantics are disabled.
class SlideToConfirm extends StatefulWidget {
  /// Creates a slide-to-confirm control.
  ///
  /// [height] must be positive and [confirmThreshold] must be in `(0, 1]`.
  const SlideToConfirm({
    super.key,
    required this.onConfirmed,
    this.thumb,
    this.label = 'Slide to confirm',
    this.labelStyle,
    this.trackColor,
    this.fillColor,
    this.thumbColor,
    this.height = 56.0,
    this.borderRadius,
    this.confirmThreshold = 0.85,
    this.resetAfterConfirm = false,
    this.resetDelay = const Duration(milliseconds: 1200),
    this.springDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.confirmedChild,
    this.onProgress,
    this.enableHaptics = true,
    this.enabled = true,
    this.controller,
  })  : assert(height > 0.0, 'height must be positive'),
        assert(confirmThreshold > 0.0 && confirmThreshold <= 1.0,
            'confirmThreshold must be in (0, 1]');

  /// Called exactly once when the control is confirmed, whether by drag,
  /// semantic tap, or keyboard activation. Fired immediately when the
  /// confirmation is decided, not after the settle animation.
  final VoidCallback onConfirmed;

  /// The content of the draggable thumb. Defaults to a circular arrow icon
  /// pointing towards the end of the track.
  final Widget? thumb;

  /// The instruction text shown centered on the track. Also used as the
  /// semantic label of the control. Defaults to `'Slide to confirm'`.
  final String label;

  /// The style of [label]. Defaults to the theme's `titleMedium` colored
  /// with [ColorScheme.onSurfaceVariant].
  final TextStyle? labelStyle;

  /// The color of the track. Defaults to
  /// [ColorScheme.surfaceContainerHighest].
  final Color? trackColor;

  /// The color of the fill that advances behind the thumb as progress
  /// grows. Defaults to [ColorScheme.primary].
  final Color? fillColor;

  /// The background color of the default thumb. Defaults to
  /// [ColorScheme.primary]. Ignored when a custom [thumb] is given.
  final Color? thumbColor;

  /// The height of the control (and the diameter of the default thumb).
  /// Defaults to 56.
  final double height;

  /// The corner radius of the track. Defaults to a stadium shape
  /// (`BorderRadius.circular(height / 2)`).
  final BorderRadius? borderRadius;

  /// The fraction of the track the thumb must pass for a release to
  /// confirm, in `(0, 1]`. Defaults to 0.85.
  final double confirmThreshold;

  /// When `true` the control springs back to its initial state [resetDelay]
  /// after confirming. Defaults to `false`.
  final bool resetAfterConfirm;

  /// The delay before the automatic reset when [resetAfterConfirm] is
  /// `true`. Defaults to 1200 milliseconds.
  final Duration resetDelay;

  /// The duration of the spring-back and settle animations. Defaults to 300
  /// milliseconds.
  final Duration springDuration;

  /// The curve of the spring-back and settle animations. Defaults to
  /// [Curves.easeOutCubic].
  final Curve curve;

  /// Shown centered on the track once confirmed, cross-faded in over the
  /// label. Defaults to a check icon.
  final Widget? confirmedChild;

  /// Called with the current progress in `[0, 1]` whenever the thumb moves,
  /// during drags and during animations.
  final ValueChanged<double>? onProgress;

  /// Whether a light haptic plays on confirmation. Defaults to `true`.
  final bool enableHaptics;

  /// When `false` the control renders dimmed, ignores gestures and keyboard
  /// input, and its semantics are disabled. Defaults to `true`.
  final bool enabled;

  /// Optional controller to reset the control programmatically and read its
  /// confirmed state.
  final SlideToConfirmController? controller;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  /// Progress of the thumb along the track as a fraction in `[0, 1]`.
  ///
  /// Storing a fraction (instead of pixels) keeps the thumb position valid
  /// when the track width changes mid-gesture or mid-animation.
  late final AnimationController _progress;

  /// The label opacity, derived from [_progress]: fully visible at rest,
  /// fully faded once progress reaches 60%.
  late final Animation<double> _labelOpacity;

  Timer? _resetTimer;
  bool _confirmed = false;
  bool _dragging = false;
  bool _focused = false;
  double _trackWidth = 0.0;

  /// Fallback width used when the parent gives unbounded width constraints.
  static const double _fallbackWidth = 280.0;

  bool get _canInteract => widget.enabled && !_confirmed;

  double get _travel => math.max(0.0, _trackWidth - widget.height);

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this);
    _labelOpacity = _progress.drive(
      Tween<double>(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: const Interval(0.0, 0.6))),
    );
    _progress.addListener(_notifyProgress);
    widget.controller?.addListener(_onControllerCommand);
    widget.controller?._isConfirmed = false;
  }

  @override
  void didUpdateWidget(SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerCommand);
      widget.controller?.addListener(_onControllerCommand);
      widget.controller?._isConfirmed = _confirmed;
    }
    if (!widget.enabled && oldWidget.enabled) {
      // Cancel any in-flight gesture and return an unconfirmed thumb to the
      // start so the control cannot be left half-slid while disabled.
      _dragging = false;
      if (!_confirmed) {
        _progress
          ..stop()
          ..value = 0.0;
      }
    }
    if (!widget.resetAfterConfirm && oldWidget.resetAfterConfirm) {
      _resetTimer?.cancel();
      _resetTimer = null;
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    widget.controller?.removeListener(_onControllerCommand);
    _progress.dispose();
    super.dispose();
  }

  void _notifyProgress() {
    widget.onProgress?.call(_progress.value);
  }

  void _onControllerCommand() {
    final SlideToConfirmController controller = widget.controller!;
    if (controller._resetRequested) {
      controller._resetRequested = false;
      _reset();
    }
  }

  /// Animates the thumb to [target], jumping instantly under reduced
  /// motion.
  void _settle(double target) {
    _progress.stop();
    if (MicroMotion.isReduced(context)) {
      _progress.value = target;
      return;
    }
    _progress.animateTo(
      target,
      duration: widget.springDuration,
      curve: widget.curve,
    );
  }

  /// Confirms the control. Safe to call repeatedly; [SlideToConfirm.onConfirmed]
  /// fires only on the first call since the last reset.
  void _confirm() {
    if (_confirmed || !mounted) {
      return;
    }
    setState(() {
      _confirmed = true;
    });
    widget.controller?._isConfirmed = true;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _settle(1.0);
    widget.onConfirmed();
    if (widget.resetAfterConfirm) {
      _resetTimer?.cancel();
      _resetTimer = Timer(widget.resetDelay, () {
        if (mounted) {
          _reset();
        }
      });
    }
  }

  /// Returns the control to its initial state.
  void _reset() {
    if (!mounted) {
      return;
    }
    _resetTimer?.cancel();
    _resetTimer = null;
    _dragging = false;
    if (!_confirmed && _progress.value == 0.0 && !_progress.isAnimating) {
      return;
    }
    setState(() {
      _confirmed = false;
    });
    widget.controller?._isConfirmed = false;
    _settle(0.0);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!mounted || !_canInteract) {
      return;
    }
    _dragging = true;
    _progress.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!mounted || !_dragging || !_canInteract) {
      return;
    }
    final double travel = _travel;
    if (travel <= 0.0) {
      return;
    }
    double delta = details.delta.dx;
    if (Directionality.of(context) == TextDirection.rtl) {
      delta = -delta;
    }
    _progress.value = (_progress.value + delta / travel).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!mounted || !_dragging) {
      return;
    }
    _dragging = false;
    if (_confirmed) {
      return;
    }
    if (_progress.value >= widget.confirmThreshold) {
      _confirm();
    } else {
      _settle(0.0);
    }
  }

  void _handleDragCancel() {
    if (!mounted || !_dragging) {
      return;
    }
    _dragging = false;
    if (!_confirmed) {
      _settle(0.0);
    }
  }

  void _handleActivate() {
    if (_canInteract) {
      _confirm();
    }
  }

  void _handleFocusChange(bool focused) {
    if (focused != _focused && mounted) {
      setState(() {
        _focused = focused;
      });
    }
  }

  Widget _buildDefaultThumb(ColorScheme scheme, TextDirection direction) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.thumbColor ?? scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            direction == TextDirection.rtl
                ? Icons.arrow_back
                : Icons.arrow_forward,
            color: scheme.onPrimary,
            size: math.min(24.0, widget.height * 0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextDirection direction = Directionality.of(context);
    final Color trackColor = widget.trackColor ?? scheme.surfaceContainerHighest;
    final Color fillColor = widget.fillColor ?? scheme.primary;
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    final TextStyle? labelStyle = widget.labelStyle ??
        theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant);
    final Widget thumb =
        widget.thumb ?? _buildDefaultThumb(scheme, direction);
    final Widget confirmedChild = widget.confirmedChild ??
        Icon(Icons.check, color: scheme.onPrimary);

    final Widget track = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _trackWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _fallbackWidth;
        return SizedBox(
          width: _trackWidth,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: _focused
                  ? Border.all(color: scheme.primary, width: 2.0)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ColoredBox(color: trackColor),
                  ),
                  PositionedDirectional(
                    top: 0.0,
                    bottom: 0.0,
                    start: 0.0,
                    child: AnimatedBuilder(
                      animation: _progress,
                      child: ColoredBox(color: fillColor),
                      builder: (BuildContext context, Widget? child) {
                        final double width = math.min(
                          _progress.value * _travel + widget.height,
                          _trackWidth,
                        );
                        return SizedBox(width: width, child: child);
                      },
                    ),
                  ),
                  Center(
                    child: FadeTransition(
                      opacity: _labelOpacity,
                      child: Text(
                        widget.label,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Center(
                    child: ExcludeSemantics(
                      excluding: !_confirmed,
                      child: AnimatedOpacity(
                        opacity: _confirmed ? 1.0 : 0.0,
                        duration: MicroMotion.effectiveDuration(
                          context,
                          const Duration(milliseconds: 200),
                        ),
                        curve: widget.curve,
                        child: confirmedChild,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0.0,
                    bottom: 0.0,
                    start: 0.0,
                    child: AnimatedBuilder(
                      animation: _progress,
                      child: SizedBox(
                        width: widget.height,
                        height: widget.height,
                        child: thumb,
                      ),
                      builder: (BuildContext context, Widget? child) {
                        return Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: _progress.value * _travel,
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: _canInteract ? _confirm : null,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onFocusChange: _handleFocusChange,
        mouseCursor: _canInteract
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _handleActivate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _handleActivate();
              return null;
            },
          ),
        },
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: GestureDetector(
            excludeFromSemantics: true,
            onHorizontalDragStart: widget.enabled ? _handleDragStart : null,
            onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
            onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
            onHorizontalDragCancel:
                widget.enabled ? _handleDragCancel : null,
            child: track,
          ),
        ),
      ),
    );
  }
}
