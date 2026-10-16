import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// How the fill of a [HoldToConfirm] grows while the button is held.
enum HoldFillStyle {
  /// The fill grows from the start edge to the end edge, following the
  /// ambient [Directionality].
  horizontal,

  /// The fill rises from the bottom like a liquid, with a gentle wave on
  /// its top edge.
  liquid,
}

/// Programmatic control for a [HoldToConfirm] button.
///
/// ```dart
/// final controller = HoldToConfirmController();
/// // ...
/// HoldToConfirm(
///   controller: controller,
///   resetAfterConfirm: false,
///   onConfirmed: deleteAccount,
///   child: const Text('Hold to delete'),
/// );
/// // later, for example after the request fails:
/// controller.reset();
/// ```
///
/// [isConfirmed] reflects whether the attached button is confirmed. Dispose
/// the controller yourself when it is no longer needed.
class HoldToConfirmController extends ChangeNotifier {
  bool _isConfirmed = false;
  bool _resetRequested = false;

  /// Whether the attached button is currently in its confirmed state.
  bool get isConfirmed => _isConfirmed;

  /// Drains the attached button back to its initial state so it can be
  /// held again. A no-op when the button is already at rest.
  void reset() {
    _resetRequested = true;
    notifyListeners();
  }
}

/// A button that fills up while it is pressed and held, and confirms once
/// the fill is complete, for destructive or important actions.
///
/// ```dart
/// HoldToConfirm(
///   onConfirmed: deleteAccount,
///   child: const Text('Hold to delete'),
/// )
/// ```
///
/// Pressing starts the fill, which takes [holdDuration] to complete; the
/// fill is linear so it shows honest progress. Releasing early drains the
/// fill back over at most [drainDuration] and nothing is confirmed. When
/// the fill completes, [onConfirmed] is called exactly once and
/// [confirmedChild] (if any) cross-fades in. With [resetAfterConfirm] the
/// button drains back to its initial state after [resetDelay]; otherwise
/// call [HoldToConfirmController.reset] to reuse it.
///
/// The label is drawn twice: once in [foregroundColor] over the background
/// and once in [fillForegroundColor] clipped to the fill, so the text stays
/// legible as the fill passes under it. [fillStyle] picks a horizontal
/// fill or a rising liquid fill with a wavy top edge.
///
/// With [enableHaptics] a selection click plays when the hold starts and a
/// heavy impact when it confirms.
///
/// Accessibility: screen reader and keyboard users cannot easily press and
/// hold, so the button is exposed to assistive technology as a button
/// whose semantic tap confirms directly, without holding. It is focusable,
/// and pressing Enter or Space while focused also confirms directly.
///
/// Under reduced motion holding still takes [holdDuration] (the delay is
/// functional, not decorative), but the liquid wave is static and draining
/// and resetting jump instantly. When [enabled] is `false` the button
/// renders dimmed, ignores input, and its semantics are disabled.
class HoldToConfirm extends StatefulWidget {
  /// Creates a hold-to-confirm button.
  const HoldToConfirm({
    super.key,
    required this.child,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.drainDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.fillStyle = HoldFillStyle.horizontal,
    this.fillColor,
    this.backgroundColor,
    this.foregroundColor,
    this.fillForegroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
    this.enableHaptics = true,
    this.resetAfterConfirm = true,
    this.resetDelay = const Duration(milliseconds: 800),
    this.confirmedChild,
    this.onProgress,
    this.controller,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The label of the button, typically a [Text].
  final Widget child;

  /// Called exactly once per confirmation: when a hold completes, or on a
  /// semantic tap or keyboard activation.
  final VoidCallback onConfirmed;

  /// How long the button must be held to confirm. Defaults to 1500
  /// milliseconds.
  final Duration holdDuration;

  /// The longest time the fill takes to drain back after an early release
  /// or a reset; a partial fill drains proportionally faster. Defaults to
  /// 300 milliseconds.
  final Duration drainDuration;

  /// The curve of the drain and reset animations. Defaults to
  /// [Curves.easeOutCubic]. The hold itself is always linear.
  final Curve curve;

  /// Whether the fill grows horizontally or rises like a liquid. Defaults
  /// to [HoldFillStyle.horizontal].
  final HoldFillStyle fillStyle;

  /// The color of the fill. Defaults to [ColorScheme.primary].
  final Color? fillColor;

  /// The color of the button behind the fill. Defaults to
  /// [ColorScheme.primaryContainer].
  final Color? backgroundColor;

  /// The text and icon color over [backgroundColor]. Defaults to
  /// [ColorScheme.onPrimaryContainer].
  final Color? foregroundColor;

  /// The text and icon color over [fillColor]. Defaults to
  /// [ColorScheme.onPrimary].
  final Color? fillForegroundColor;

  /// The corner radius of the button. Defaults to a pill (stadium) shape.
  final BorderRadius? borderRadius;

  /// Padding around [child]. Defaults to 28 horizontal by 16 vertical.
  final EdgeInsetsGeometry padding;

  /// Whether haptics play at the start of a hold and on confirmation.
  /// Defaults to `true`.
  final bool enableHaptics;

  /// Whether the button drains back to its initial state [resetDelay]
  /// after confirming. Defaults to `true`.
  final bool resetAfterConfirm;

  /// The delay before the automatic reset. Defaults to 800 milliseconds.
  final Duration resetDelay;

  /// Shown instead of [child] once confirmed, cross-faded in. When null
  /// [child] stays visible.
  final Widget? confirmedChild;

  /// Called with the fill progress in `[0, 1]` whenever it changes, while
  /// holding, draining and resetting.
  final ValueChanged<double>? onProgress;

  /// Optional controller to reset the button and read its confirmed state.
  final HoldToConfirmController? controller;

  /// When `false` the button renders dimmed, ignores input, and its
  /// semantics are disabled. Defaults to `true`.
  final bool enabled;

  /// Optional semantic label. When null the text of [child] is used.
  final String? semanticLabel;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with TickerProviderStateMixin {
  /// The fill fraction in `[0, 1]`.
  late final AnimationController _fill;

  /// Phase of the liquid wave, repeating from 0 to 1.
  late final AnimationController _wave;

  Timer? _resetTimer;
  bool _holding = false;
  bool _confirmed = false;
  bool _focused = false;
  bool _reduced = false;

  /// The period of one wave cycle.
  static const Duration _wavePeriod = Duration(milliseconds: 1200);

  /// The cross-fade duration between [HoldToConfirm.child] and
  /// [HoldToConfirm.confirmedChild].
  static const Duration _swapDuration = Duration(milliseconds: 200);

  bool get _canInteract => widget.enabled && !_confirmed;

  @override
  void initState() {
    super.initState();
    // Preserve the real hold duration even when the platform asks to
    // disable animations: the delay is functional, not decorative.
    _fill = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _wave = AnimationController(vsync: this, duration: _wavePeriod);
    _fill
      ..addListener(_onFillChanged)
      ..addStatusListener(_onFillStatus);
    widget.controller?.addListener(_onControllerCommand);
    widget.controller?._isConfirmed = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MicroMotion.isReduced(context);
    _syncWave();
  }

  @override
  void didUpdateWidget(HoldToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerCommand);
      widget.controller?.addListener(_onControllerCommand);
      widget.controller?._isConfirmed = _confirmed;
    }
    if (widget.holdDuration != oldWidget.holdDuration && _holding) {
      // Continue the current hold at the new pace.
      _startFilling();
    }
    if (!widget.enabled && oldWidget.enabled && !_confirmed) {
      _holding = false;
      _fill
        ..stop()
        ..value = 0.0;
    }
    if (!widget.resetAfterConfirm && oldWidget.resetAfterConfirm) {
      _resetTimer?.cancel();
      _resetTimer = null;
    }
    _syncWave();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    widget.controller?.removeListener(_onControllerCommand);
    _fill
      ..removeListener(_onFillChanged)
      ..removeStatusListener(_onFillStatus);
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _onFillChanged() {
    widget.onProgress?.call(_fill.value);
    _syncWave();
  }

  void _onFillStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding && !_confirmed) {
      _holding = false;
      _confirm();
    }
  }

  void _onControllerCommand() {
    final HoldToConfirmController controller = widget.controller!;
    if (controller._resetRequested) {
      controller._resetRequested = false;
      _reset();
    }
  }

  /// Runs the wave only while a partial liquid fill is visible.
  void _syncWave() {
    final bool shouldRun =
        widget.fillStyle == HoldFillStyle.liquid &&
        widget.enabled &&
        !_reduced &&
        _fill.value > 0.0 &&
        _fill.value < 1.0;
    if (shouldRun) {
      if (!_wave.isAnimating) {
        _wave.repeat();
      }
    } else if (_wave.isAnimating) {
      _wave.stop();
    }
  }

  void _startFilling() {
    final double remaining = 1.0 - _fill.value;
    if (remaining <= 0.0) {
      _onFillStatus(AnimationStatus.completed);
      return;
    }
    _fill.animateTo(
      1.0,
      duration: widget.holdDuration * remaining,
      curve: Curves.linear,
    );
  }

  /// Animates the fill to [target] over a duration proportional to the
  /// distance, jumping instantly under reduced motion.
  void _settle(double target) {
    _fill.stop();
    final double distance = (target - _fill.value).abs();
    if (_reduced || distance == 0.0) {
      _fill.value = target;
      return;
    }
    _fill.animateTo(
      target,
      duration: widget.drainDuration * distance,
      curve: widget.curve,
    );
  }

  void _handleTapDown(TapDownDetails details) {
    if (!mounted || !_canInteract || _holding) {
      return;
    }
    _holding = true;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    _startFilling();
  }

  void _release() {
    if (!mounted || !_holding) {
      return;
    }
    _holding = false;
    if (!_confirmed) {
      _settle(0.0);
    }
  }

  void _handleTapUp(TapUpDetails details) => _release();

  void _handleTapCancel() => _release();

  /// Confirms the button. Safe to call repeatedly; [HoldToConfirm.onConfirmed]
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
      HapticFeedback.heavyImpact();
    }
    if (_fill.value < 1.0) {
      _settle(1.0);
    }
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

  /// Confirms directly, for semantic taps and keyboard activation.
  void _confirmDirectly() {
    if (!_canInteract) {
      return;
    }
    _holding = false;
    _confirm();
  }

  /// Returns the button to its initial state.
  void _reset() {
    if (!mounted) {
      return;
    }
    _resetTimer?.cancel();
    _resetTimer = null;
    _holding = false;
    if (!_confirmed && _fill.value == 0.0 && !_fill.isAnimating) {
      return;
    }
    setState(() {
      _confirmed = false;
    });
    widget.controller?._isConfirmed = false;
    _settle(0.0);
  }

  void _handleFocusChange(bool focused) {
    if (focused != _focused && mounted) {
      setState(() {
        _focused = focused;
      });
    }
  }

  Widget _buildLabel(Color color) {
    final Widget? confirmedChild = widget.confirmedChild;
    final bool showConfirmed = _confirmed && confirmedChild != null;
    final Widget content = KeyedSubtree(
      key: ValueKey<bool>(showConfirmed),
      child: showConfirmed ? confirmedChild : widget.child,
    );
    return IconTheme.merge(
      data: IconThemeData(color: color),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: Padding(
          padding: widget.padding,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: AnimatedSwitcher(
              duration: _reduced ? Duration.zero : _swapDuration,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color fillColor = widget.fillColor ?? scheme.primary;
    final Color backgroundColor =
        widget.backgroundColor ?? scheme.primaryContainer;
    final Color foregroundColor =
        widget.foregroundColor ?? scheme.onPrimaryContainer;
    final Color fillForegroundColor =
        widget.fillForegroundColor ?? scheme.onPrimary;
    final BorderRadius? radius = widget.borderRadius;
    final ShapeBorder shape = radius == null
        ? const StadiumBorder()
        : RoundedRectangleBorder(borderRadius: radius);
    final TextDirection direction = Directionality.of(context);

    final Widget fillLayer = Positioned.fill(
      child: ExcludeSemantics(
        child: ClipPath(
          clipper: _FillClipper(
            fill: _fill,
            wave: _wave,
            style: widget.fillStyle,
            textDirection: direction,
          ),
          child: ColoredBox(
            color: fillColor,
            child: _buildLabel(fillForegroundColor),
          ),
        ),
      ),
    );

    Widget surface = DefaultTextStyle.merge(
      style: theme.textTheme.labelLarge,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape, textDirection: direction),
        child: ColoredBox(
          color: backgroundColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0, minWidth: 64.0),
            child: Stack(
              children: <Widget>[_buildLabel(foregroundColor), fillLayer],
            ),
          ),
        ),
      ),
    );

    surface = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: radius == null
            ? StadiumBorder(
                side: _focused
                    ? BorderSide(color: scheme.primary, width: 2.0)
                    : BorderSide.none,
              )
            : RoundedRectangleBorder(
                borderRadius: radius,
                side: _focused
                    ? BorderSide(color: scheme.primary, width: 2.0)
                    : BorderSide.none,
              ),
      ),
      child: surface,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: _canInteract ? _confirmDirectly : null,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onFocusChange: _handleFocusChange,
        mouseCursor: _canInteract
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              _confirmDirectly();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) {
              _confirmDirectly();
              return null;
            },
          ),
        },
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled ? _handleTapDown : null,
            onTapUp: widget.enabled ? _handleTapUp : null,
            onTapCancel: widget.enabled ? _handleTapCancel : null,
            child: surface,
          ),
        ),
      ),
    );
  }
}

/// Clips the fill layer of a [HoldToConfirm] to the current fill shape.
class _FillClipper extends CustomClipper<Path> {
  _FillClipper({
    required this.fill,
    required this.wave,
    required this.style,
    required this.textDirection,
  }) : super(reclip: Listenable.merge(<Listenable>[fill, wave]));

  final Animation<double> fill;
  final Animation<double> wave;
  final HoldFillStyle style;
  final TextDirection textDirection;

  /// The wave amplitude as a fraction of the button height.
  static const double _amplitudeFactor = 0.08;

  /// Horizontal distance between two wave samples, in logical pixels.
  static const double _sampleStep = 4.0;

  @override
  Path getClip(Size size) {
    final double t = fill.value.clamp(0.0, 1.0);
    final Path path = Path();
    if (t <= 0.0) {
      return path;
    }
    if (t >= 1.0) {
      return path..addRect(Offset.zero & size);
    }
    switch (style) {
      case HoldFillStyle.horizontal:
        final double width = size.width * t;
        final double left = textDirection == TextDirection.rtl
            ? size.width - width
            : 0.0;
        return path..addRect(Rect.fromLTWH(left, 0.0, width, size.height));
      case HoldFillStyle.liquid:
        final double level = size.height * (1.0 - t);
        // Flatten the wave near empty and full so the edges look settled.
        final double taper = math.min(1.0, math.min(t, 1.0 - t) * 5.0);
        final double amplitude = size.height * _amplitudeFactor * taper;
        final double phase = wave.value * 2 * math.pi;
        path.moveTo(0.0, size.height);
        for (double x = 0.0; x <= size.width; x += _sampleStep) {
          final double y =
              level +
              math.sin(x / size.width * 2 * math.pi + phase) * amplitude;
          path.lineTo(x, y);
        }
        final double endY = level + math.sin(2 * math.pi + phase) * amplitude;
        path
          ..lineTo(size.width, endY)
          ..lineTo(size.width, size.height)
          ..close();
        return path;
    }
  }

  @override
  bool shouldReclip(_FillClipper oldClipper) {
    return oldClipper.fill != fill ||
        oldClipper.wave != wave ||
        oldClipper.style != style ||
        oldClipper.textDirection != textDirection;
  }
}
