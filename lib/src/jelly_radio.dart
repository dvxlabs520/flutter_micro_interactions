import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// One option of a [JellyRadioGroup].
class JellyRadioItem<T> {
  /// Creates a radio chip option.
  const JellyRadioItem({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  /// The value reported to [JellyRadioGroup.onChanged] when this chip is
  /// chosen. Values must be unique within one group.
  final T value;

  /// The chip's label, typically a [Text]. Its text style and color are
  /// provided by the group.
  final Widget label;

  /// Optional icon shown before [label]. Its color and size are provided by
  /// the group.
  final Widget? icon;

  /// Optional label announced by assistive technology instead of the
  /// semantics of [label].
  final String? semanticLabel;
}

/// A group of radio chips with a soft, jelly-like selection.
///
/// ```dart
/// JellyRadioGroup<String>(
///   items: const <JellyRadioItem<String>>[
///     JellyRadioItem<String>(value: 's', label: Text('Small')),
///     JellyRadioItem<String>(value: 'm', label: Text('Medium')),
///     JellyRadioItem<String>(value: 'l', label: Text('Large')),
///   ],
///   value: _size,
///   onChanged: (String value) => setState(() => _size = value),
/// )
/// ```
///
/// When a chip becomes selected it swells to [selectedScale] on an
/// underdamped [spring], wobbling slightly wider than tall and back like
/// jelly, while its fill grows outward from its center. At the same moment
/// its neighbours receive a small impulse that pushes them [pushDistance]
/// pixels away before they spring back (chips two places away move less).
/// The previously selected chip shrinks back and its fill retreats to the
/// center. Label colors switch once the fill is under them.
///
/// Chips are laid out in a row or a column ([direction]), or in a [Wrap]
/// when [wrap] is true. The push moves along [direction].
///
/// The group is controlled: tapping a chip calls [onChanged], and the chip
/// only swells when the parent rebuilds the group with the new [value]. A
/// null [value] means no chip is selected.
///
/// Accessibility: each chip is exposed as a checked or unchecked member of
/// a mutually exclusive group, with a tap target of at least 48 by 48. The
/// group is one keyboard focus stop with a visible focus ring around the
/// current chip; the arrow keys select the previous or next chip (wrapping
/// around, respecting the ambient [Directionality]), and Enter or Space
/// selects the focused chip when nothing is selected yet.
///
/// When [onChanged] is null or [enabled] is false the group renders in a
/// dimmed disabled style and ignores input. Under reduced motion selection
/// changes are instant: no swell overshoot, no wobble and no push.
class JellyRadioGroup<T> extends StatefulWidget {
  /// Creates a group of jelly radio chips.
  const JellyRadioGroup({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.direction = Axis.horizontal,
    this.wrap = false,
    this.spacing = 8.0,
    this.runSpacing = 0.0,
    this.chipHeight = 36.0,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.shape,
    this.selectedColor,
    this.selectedForegroundColor,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.textStyle,
    this.selectedScale = 1.08,
    this.pushDistance = 6.0,
    this.spring = const SpringDescription(
      mass: 1.0,
      stiffness: 380.0,
      damping: 17.0,
    ),
    this.enableHaptics = true,
    this.enabled = true,
  }) : assert(spacing >= 0.0, 'spacing must not be negative'),
       assert(runSpacing >= 0.0, 'runSpacing must not be negative'),
       assert(chipHeight > 0.0, 'chipHeight must be positive'),
       assert(selectedScale >= 1.0, 'selectedScale must be at least 1'),
       assert(pushDistance >= 0.0, 'pushDistance must not be negative');

  /// The chips, in reading order. At least one is required (checked with
  /// an assert when the group builds).
  final List<JellyRadioItem<T>> items;

  /// The value of the selected chip, or null when no chip is selected.
  final T? value;

  /// Called with the value of a chip the user chooses. When null the group
  /// renders disabled.
  final ValueChanged<T>? onChanged;

  /// Whether chips are laid out in a row or a column. Defaults to
  /// [Axis.horizontal].
  final Axis direction;

  /// When true chips flow onto new runs with a [Wrap] instead of a single
  /// row or column. Defaults to false.
  final bool wrap;

  /// Gap between neighbouring chip tap targets along [direction]. Defaults
  /// to 8.
  final double spacing;

  /// Gap between runs when [wrap] is true. Defaults to 0, since each chip
  /// already sits in a 48 pixel tall tap target.
  final double runSpacing;

  /// Visual height of a chip. Defaults to 36. The tap target is at least
  /// 48 tall regardless.
  final double chipHeight;

  /// Padding around each chip's content. Defaults to 16 horizontally.
  final EdgeInsets chipPadding;

  /// Shape of every chip. Defaults to a [StadiumBorder]. Only the outline
  /// path is used; the border side is drawn from [borderColor].
  final OutlinedBorder? shape;

  /// Fill color of the selected chip. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? selectedColor;

  /// Label and icon color of the selected chip. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? selectedForegroundColor;

  /// Fill color of unselected chips. Defaults to transparent.
  final Color? backgroundColor;

  /// Label and icon color of unselected chips. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant`.
  final Color? foregroundColor;

  /// Outline color of unselected chips. Defaults to the theme's
  /// `colorScheme.outlineVariant`.
  final Color? borderColor;

  /// Text style of the labels. Defaults to the theme's
  /// `textTheme.labelLarge`. Its color is replaced by the foreground colors.
  final TextStyle? textStyle;

  /// Resting scale of the selected chip. Defaults to 1.08.
  final double selectedScale;

  /// How far, in logical pixels, the direct neighbours of a newly selected
  /// chip are pushed away before they spring back. Defaults to 6.
  final double pushDistance;

  /// Spring of the swell and of the neighbour push. A low damping ratio
  /// gives the jelly overshoot. Defaults to a mass of 1, stiffness of 380
  /// and damping of 17.
  final SpringDescription spring;

  /// Whether a selection click haptic is triggered when the user changes
  /// the selection. Defaults to true.
  final bool enableHaptics;

  /// When false the group renders disabled, exactly as if [onChanged] were
  /// null.
  final bool enabled;

  @override
  State<JellyRadioGroup<T>> createState() => _JellyRadioGroupState<T>();
}

class _JellyRadioGroupState<T> extends State<JellyRadioGroup<T>>
    with TickerProviderStateMixin {
  /// Per chip selection progress: 0 unselected, 1 selected. Overshoots
  /// while the spring wobbles.
  final List<AnimationController> _swell = <AnimationController>[];

  /// Per chip push offset in logical pixels along the main axis.
  final List<AnimationController> _push = <AnimationController>[];

  bool _reducedMotion = false;
  bool _focused = false;
  int _selected = -1;

  /// Chip that keyboard actions apply to when nothing is selected.
  int _cursor = 0;

  /// Peak displacement of [JellyRadioGroup.spring] after a unit velocity
  /// impulse, used to turn [JellyRadioGroup.pushDistance] into a velocity.
  double _peakPerVelocity = 1.0;

  static const double _minTapTarget = 48.0;
  static const double _disabledOpacity = 0.38;

  /// Wobble (scale difference between width and height) per unit of swell
  /// velocity.
  static const double _wobblePerVelocity = 0.006;
  static const double _maxWobble = 0.05;

  static const Curve _labelCurve = Interval(0.3, 0.85);

  static const Tolerance _tolerance = Tolerance(
    distance: 0.0005,
    velocity: 0.01,
  );

  bool get _interactive => widget.enabled && widget.onChanged != null;

  int _indexOf(T? value) {
    if (value == null) return -1;
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.items[i].value == value) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _selected = _indexOf(widget.value);
    _cursor = math.max(0, _selected);
    _syncControllers();
    _peakPerVelocity = _measurePeak(widget.spring);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _jumpAll();
    }
  }

  @override
  void didUpdateWidget(JellyRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spring != oldWidget.spring) {
      _peakPerVelocity = _measurePeak(widget.spring);
    }
    final int selected = _indexOf(widget.value);
    if (widget.items.length != oldWidget.items.length) {
      _selected = selected;
      _cursor = math.max(0, math.min(_cursor, widget.items.length - 1));
      if (selected >= 0) _cursor = selected;
      _syncControllers();
      _jumpAll();
      return;
    }
    if (selected != _selected) {
      final int previous = _selected;
      _selected = selected;
      if (selected >= 0) _cursor = selected;
      _animateSelection(previous, selected);
    }
  }

  @override
  void dispose() {
    for (final AnimationController c in _swell) {
      c.dispose();
    }
    for (final AnimationController c in _push) {
      c.dispose();
    }
    super.dispose();
  }

  /// Creates or disposes per chip controllers to match the item count.
  void _syncControllers() {
    while (_swell.length > widget.items.length) {
      _swell.removeLast().dispose();
      _push.removeLast().dispose();
    }
    while (_swell.length < widget.items.length) {
      final int i = _swell.length;
      final AnimationController swell = AnimationController.unbounded(
        vsync: this,
        value: i == _selected ? 1.0 : 0.0,
      );
      swell.addStatusListener((AnimationStatus status) {
        // Snap exactly onto the target once the spring is within tolerance.
        if (status == AnimationStatus.completed) {
          swell.value = i == _selected ? 1.0 : 0.0;
        }
      });
      final AnimationController push = AnimationController.unbounded(
        vsync: this,
      );
      push.addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) push.value = 0.0;
      });
      _swell.add(swell);
      _push.add(push);
    }
  }

  void _jumpAll() {
    for (int i = 0; i < _swell.length; i++) {
      _swell[i].value = i == _selected ? 1.0 : 0.0;
      _push[i].value = 0.0;
    }
  }

  /// Peak displacement of [spring] released from rest with velocity 1.
  static double _measurePeak(SpringDescription spring) {
    final SpringSimulation simulation = SpringSimulation(spring, 0.0, 0.0, 1.0);
    double peak = 0.0;
    for (double t = 0.0; t < 1.0; t += 0.002) {
      final double x = simulation.x(t);
      if (x < peak) break;
      peak = x;
    }
    return peak > 0.0 ? peak : 1.0;
  }

  void _animateSelection(int previous, int selected) {
    if (_reducedMotion) {
      _jumpAll();
      return;
    }
    for (int i = 0; i < _swell.length; i++) {
      final double target = i == selected ? 1.0 : 0.0;
      if (_swell[i].value != target || _swell[i].isAnimating) {
        _swell[i].animateWith(
          SpringSimulation(
            widget.spring,
            _swell[i].value,
            target,
            _swell[i].velocity,
            tolerance: _tolerance,
          ),
        );
      }
    }
    if (selected < 0 || widget.pushDistance == 0.0) return;
    for (int i = 0; i < _push.length; i++) {
      final int distance = i - selected;
      if (distance == 0 || distance.abs() > 2) continue;
      final double strength = distance.abs() == 1 ? 1.0 : 0.4;
      final double impulse =
          distance.sign * strength * widget.pushDistance / _peakPerVelocity;
      _push[i].animateWith(
        SpringSimulation(
          widget.spring,
          _push[i].value,
          0.0,
          _push[i].velocity + impulse,
          tolerance: const Tolerance(distance: 0.01, velocity: 0.1),
        ),
      );
    }
  }

  void _select(int index) {
    if (!_interactive) return;
    _cursor = index;
    final T value = widget.items[index].value;
    if (value == widget.value) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    widget.onChanged?.call(value);
  }

  void _step(int delta) {
    final int count = widget.items.length;
    final int from = _selected >= 0 ? _selected : _cursor - (delta > 0 ? 1 : 0);
    _select((from + delta + count) % count);
  }

  Widget _buildChip(
    BuildContext context,
    int index,
    _ChipStyle style,
    bool rtl,
  ) {
    final JellyRadioItem<T> item = widget.items[index];
    final bool selected = index == _selected;
    final bool interactive = _interactive;
    final bool horizontal = widget.direction == Axis.horizontal;
    final AnimationController swell = _swell[index];
    final AnimationController push = _push[index];
    final bool showFocus = _focused && interactive && index == _cursor;

    final Widget content = Padding(
      padding: widget.chipPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            item.icon!,
            const SizedBox(width: 6),
          ],
          Flexible(child: item.label),
        ],
      ),
    );

    final Widget chip = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[swell, push]),
      child: content,
      builder: (BuildContext context, Widget? child) {
        final double t = swell.value;
        // Saturate slightly early so the fill stays complete while the
        // spring wobbles just below its target.
        final double progress = (t / 0.9).clamp(0.0, 1.0);
        final double scale = 1.0 + (widget.selectedScale - 1.0) * t;
        final double wobble = (swell.velocity * _wobblePerVelocity).clamp(
          -_maxWobble,
          _maxWobble,
        );
        // The label switches color once the fill is under it.
        final Color foreground = Color.lerp(
          style.foreground,
          style.selectedForeground,
          _labelCurve.transform(progress),
        )!;
        final double along = push.value * (horizontal && rtl ? -1.0 : 1.0);
        return Transform.translate(
          offset: horizontal ? Offset(along, 0.0) : Offset(0.0, along),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              scale + wobble,
              scale - wobble,
              1.0,
            ),
            child: CustomPaint(
              painter: _JellyChipPainter(
                progress: progress,
                shape: style.shape,
                background: style.background,
                fill: style.fill,
                border: style.border,
                focusColor: style.focusColor,
                focused: showFocus,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 18),
                child: DefaultTextStyle(
                  style: style.textStyle.copyWith(color: foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: interactive,
      label: item.semanticLabel,
      onTap: interactive ? () => _select(index) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: interactive ? () => _select(index) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: SizedBox(
              height: widget.chipHeight,
              child: Center(
                widthFactor: 1.0,
                child: item.semanticLabel == null
                    ? chip
                    : ExcludeSemantics(child: chip),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.items.isNotEmpty, 'JellyRadioGroup needs at least one item');
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final _ChipStyle style = _ChipStyle(
      shape: widget.shape ?? const StadiumBorder(),
      background: widget.backgroundColor ?? Colors.transparent,
      fill: widget.selectedColor ?? scheme.primary,
      border: widget.borderColor ?? scheme.outlineVariant,
      foreground: widget.foregroundColor ?? scheme.onSurfaceVariant,
      selectedForeground: widget.selectedForegroundColor ?? scheme.onPrimary,
      focusColor: scheme.primary,
      textStyle:
          widget.textStyle ?? theme.textTheme.labelLarge ?? const TextStyle(),
    );
    final List<Widget> chips = <Widget>[
      for (int i = 0; i < widget.items.length; i++)
        _buildChip(context, i, style, rtl),
    ];

    Widget result;
    if (widget.wrap) {
      result = Wrap(
        direction: widget.direction,
        spacing: widget.spacing,
        runSpacing: widget.runSpacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      );
    } else {
      final List<Widget> spaced = <Widget>[
        for (int i = 0; i < chips.length; i++) ...<Widget>[
          if (i > 0)
            SizedBox(
              width: widget.direction == Axis.horizontal ? widget.spacing : 0,
              height: widget.direction == Axis.vertical ? widget.spacing : 0,
            ),
          chips[i],
        ],
      ];
      result = Flex(
        direction: widget.direction,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.direction == Axis.vertical
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: spaced,
      );
    }

    if (!_interactive) {
      return Opacity(opacity: _disabledOpacity, child: result);
    }

    final bool horizontal = widget.direction == Axis.horizontal;
    final int left = horizontal && rtl ? 1 : -1;
    return FocusableActionDetector(
      onShowFocusHighlight: (bool focused) {
        if (focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _JellyStepIntent(
          left,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowRight): _JellyStepIntent(
          -left,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _JellyStepIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _JellyStepIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _JellyStepIntent: CallbackAction<_JellyStepIntent>(
          onInvoke: (_JellyStepIntent intent) {
            _step(intent.delta);
            return null;
          },
        ),
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            _select(_cursor);
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (ButtonActivateIntent intent) {
            _select(_cursor);
            return null;
          },
        ),
      },
      child: result,
    );
  }
}

/// Moves the selection by [delta] chips.
class _JellyStepIntent extends Intent {
  const _JellyStepIntent(this.delta);

  final int delta;
}

/// Resolved colors and shapes shared by every chip in one build.
class _ChipStyle {
  const _ChipStyle({
    required this.shape,
    required this.background,
    required this.fill,
    required this.border,
    required this.foreground,
    required this.selectedForeground,
    required this.focusColor,
    required this.textStyle,
  });

  final OutlinedBorder shape;
  final Color background;
  final Color fill;
  final Color border;
  final Color foreground;
  final Color selectedForeground;
  final Color focusColor;
  final TextStyle textStyle;
}

class _JellyChipPainter extends CustomPainter {
  _JellyChipPainter({
    required this.progress,
    required this.shape,
    required this.background,
    required this.fill,
    required this.border,
    required this.focusColor,
    required this.focused,
  });

  /// Selection progress, 0 to 1.
  final double progress;
  final OutlinedBorder shape;
  final Color background;
  final Color fill;
  final Color border;
  final Color focusColor;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Path outline = shape.getOuterPath(rect);
    final Paint paint = Paint();
    if (background.a > 0.0) {
      canvas.drawPath(outline, paint..color = background);
    }
    if (progress > 0.0) {
      // The fill grows from the center as a smaller copy of the chip
      // shape; its height leads slightly so it reads as a pill, not a line.
      final Rect fillRect = Rect.fromCenter(
        center: rect.center,
        width: size.width * progress,
        height: size.height * math.sqrt(progress),
      );
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawPath(shape.getOuterPath(fillRect), paint..color = fill);
      canvas.restore();
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Color.lerp(border, fill, progress)!;
    canvas.drawPath(shape.getOuterPath(rect.deflate(0.5)), paint);
    if (focused) {
      paint
        ..strokeWidth = 2.0
        ..color = focusColor;
      canvas.drawPath(shape.getOuterPath(rect.inflate(3.0)), paint);
    }
  }

  @override
  bool shouldRepaint(_JellyChipPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shape != shape ||
        oldDelegate.background != background ||
        oldDelegate.fill != fill ||
        oldDelegate.border != border ||
        oldDelegate.focusColor != focusColor ||
        oldDelegate.focused != focused;
  }
}
