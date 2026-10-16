import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// One option of a [RubberSegment] control.
class RubberSegmentItem<T> {
  /// Creates a segment option.
  const RubberSegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  /// The value reported to [RubberSegment.onChanged] when this segment is
  /// chosen. Values must be unique within one control.
  final T value;

  /// The segment's label, typically a [Text]. Its text style and color are
  /// provided by the control.
  final Widget label;

  /// Optional icon shown before [label]. Its color and size are provided by
  /// the control.
  final Widget? icon;

  /// Optional label announced by assistive technology instead of the
  /// semantics of [label].
  final String? semanticLabel;
}

/// A segmented control whose selection thumb stretches like rubber when it
/// moves to another segment.
///
/// ```dart
/// RubberSegment<String>(
///   items: const <RubberSegmentItem<String>>[
///     RubberSegmentItem<String>(value: 'day', label: Text('Day')),
///     RubberSegmentItem<String>(value: 'week', label: Text('Week')),
///     RubberSegmentItem<String>(value: 'month', label: Text('Month')),
///   ],
///   value: _range,
///   onChanged: (String value) => setState(() => _range = value),
/// )
/// ```
///
/// Each edge of the thumb is driven by its own [SpringSimulation]. When
/// the selection changes, the leading edge (the one facing the new segment)
/// uses the quick [leadingSpring] and the trailing edge follows with the
/// softer [trailingSpring]. The thumb therefore elongates across the gap,
/// thins slightly while stretched, then contracts and squashes into place.
/// Label colors blend from [foregroundColor] to [selectedForegroundColor]
/// as the thumb passes over each segment.
///
/// Segments are equally wide by default (as wide as the widest segment).
/// With [fitContent] each segment is as wide as its own content. When the
/// parent forces a different width, the segments are scaled to fit.
/// Segments are measured again whenever their content changes, including
/// when the text scale, style or locale changes and when a font finishes
/// loading (for example a web font that arrives after the first frame).
///
/// The control is controlled: tapping a segment calls [onChanged], and the
/// thumb only moves when the parent rebuilds it with the new [value].
///
/// Accessibility: each segment is exposed as a checked or unchecked member
/// of a mutually exclusive group. The control is one keyboard focus stop
/// with a visible focus ring around the thumb; the arrow keys select the
/// previous or next segment (wrapping around, respecting the ambient
/// [Directionality]). The interactive area is at least 48 pixels tall even
/// when [height] is smaller.
///
/// When [onChanged] is null or [enabled] is false the control renders in a
/// dimmed disabled style and ignores input. Under reduced motion the thumb
/// jumps directly to the selected segment with no stretch.
class RubberSegment<T> extends StatefulWidget {
  /// Creates a rubber segmented control.
  const RubberSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.height = 40.0,
    this.padding = const EdgeInsets.all(4),
    this.segmentPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.thumbColor,
    this.backgroundColor,
    this.selectedForegroundColor,
    this.foregroundColor,
    this.textStyle,
    this.borderRadius,
    this.fitContent = false,
    this.leadingSpring = const SpringDescription(
      mass: 1.0,
      stiffness: 700.0,
      damping: 40.0,
    ),
    this.trailingSpring = const SpringDescription(
      mass: 1.0,
      stiffness: 300.0,
      damping: 25.0,
    ),
    this.enableHaptics = true,
    this.enabled = true,
  }) : assert(height > 0.0, 'height must be positive');

  /// The segments, in reading order. At least two are required (checked
  /// with an assert when the control builds).
  final List<RubberSegmentItem<T>> items;

  /// The value of the selected segment. Must match the value of one item.
  final T value;

  /// Called with the value of a segment the user chooses. When null the
  /// control renders disabled.
  final ValueChanged<T>? onChanged;

  /// Visual height of the control. Defaults to 40. The interactive area is
  /// at least 48 tall regardless.
  final double height;

  /// Space between the control's outer edge and the segments (and so the
  /// thumb). Defaults to 4 on every side.
  final EdgeInsets padding;

  /// Padding around the content of each segment. Defaults to 16
  /// horizontally.
  final EdgeInsets segmentPadding;

  /// Color of the selection thumb. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? thumbColor;

  /// Color of the control's background. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? backgroundColor;

  /// Label and icon color of the selected segment. Defaults to the theme's
  /// `colorScheme.onPrimary`.
  final Color? selectedForegroundColor;

  /// Label and icon color of unselected segments. Defaults to the theme's
  /// `colorScheme.onSurfaceVariant`.
  final Color? foregroundColor;

  /// Text style of the labels. Defaults to the theme's
  /// `textTheme.labelLarge`. Its color is replaced by the foreground colors.
  final TextStyle? textStyle;

  /// Corner radius of the control. Defaults to a fully rounded pill. The
  /// thumb uses the same radius reduced by [padding].
  final BorderRadius? borderRadius;

  /// When true each segment is as wide as its content; otherwise all
  /// segments share the width of the widest one. Defaults to false.
  final bool fitContent;

  /// Spring of the thumb edge that faces the newly selected segment. It
  /// should be quicker than [trailingSpring]. Defaults to a mass of 1,
  /// stiffness of 700 and damping of 40.
  final SpringDescription leadingSpring;

  /// Spring of the thumb edge that follows behind. Defaults to a mass of 1,
  /// stiffness of 300 and damping of 25, which lags and overshoots a little
  /// so the thumb squashes into place.
  final SpringDescription trailingSpring;

  /// Whether a selection click haptic is triggered when the user changes
  /// the selection. Defaults to true.
  final bool enableHaptics;

  /// When false the control renders disabled, exactly as if [onChanged]
  /// were null.
  final bool enabled;

  @override
  State<RubberSegment<T>> createState() => _RubberSegmentState<T>();
}

class _RubberSegmentState<T> extends State<RubberSegment<T>>
    with TickerProviderStateMixin {
  /// Start edge of the thumb, in segment index space (segment i spans i to
  /// i + 1).
  late final AnimationController _start;

  /// End edge of the thumb, in segment index space.
  late final AnimationController _end;

  late Listenable _edges;

  /// Bumped when the system fonts change; it keys the segment contents so
  /// they are rebuilt and measured with the new fonts.
  int _fontGeneration = 0;

  /// The pending frame callback that applies a system fonts change.
  int? _fontsCallbackId;

  bool _reducedMotion = false;
  bool _focused = false;
  int _index = 0;

  static const double _disabledOpacity = 0.38;

  static const Tolerance _tolerance = Tolerance(
    distance: 0.0005,
    velocity: 0.01,
  );

  bool get _interactive => widget.enabled && widget.onChanged != null;

  int _indexOf(T value) {
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.items[i].value == value) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _index = math.max(0, _indexOf(widget.value));
    _start = AnimationController.unbounded(
      vsync: this,
      value: _index.toDouble(),
    )..addStatusListener(_onEdgeStatus);
    _end = AnimationController.unbounded(vsync: this, value: _index + 1.0)
      ..addStatusListener(_onEdgeStatus);
    _edges = Listenable.merge(<Listenable>[_start, _end]);
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _jumpTo(_index);
    }
  }

  @override
  void didUpdateWidget(RubberSegment<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int index = math.max(0, _indexOf(widget.value));
    if (widget.items.length != oldWidget.items.length) {
      _index = index;
      _jumpTo(index);
      return;
    }
    if (index != _index) {
      _index = index;
      _moveTo(index);
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    final int? callbackId = _fontsCallbackId;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    _start.removeStatusListener(_onEdgeStatus);
    _end.removeStatusListener(_onEdgeStatus);
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  /// A font finished loading. [RenderParagraph] lays its text out again
  /// with the new font, but keeps reporting the intrinsic width measured
  /// with the old one, which the segment widths are based on. Rebuilding
  /// the segment contents gives them fresh render objects that measure with
  /// the new font, so labels are not truncated once the real font arrives.
  void _onSystemFontsChanged() {
    if (_fontsCallbackId != null) return;
    // The notification can arrive in any scheduler phase (on the web, in
    // the middle of a frame): apply it from a frame callback, as the
    // framework's own text render objects do.
    _fontsCallbackId = SchedulerBinding.instance.scheduleFrameCallback((
      Duration timeStamp,
    ) {
      _fontsCallbackId = null;
      if (!mounted) return;
      setState(() => _fontGeneration++);
    });
  }

  /// Snaps an edge exactly onto its segment boundary once its spring has
  /// come to rest within tolerance.
  void _onEdgeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!_start.isAnimating) _start.value = _index.toDouble();
    if (!_end.isAnimating) _end.value = _index + 1.0;
  }

  void _jumpTo(int index) {
    _start.value = index.toDouble();
    _end.value = index + 1.0;
  }

  /// Springs the thumb to segment [index]; the edge facing the travel
  /// direction leads.
  void _moveTo(int index) {
    if (_reducedMotion) {
      _jumpTo(index);
      return;
    }
    final double center = (_start.value + _end.value) / 2;
    final bool forward = index + 0.5 >= center;
    final SpringDescription startSpring = forward
        ? widget.trailingSpring
        : widget.leadingSpring;
    final SpringDescription endSpring = forward
        ? widget.leadingSpring
        : widget.trailingSpring;
    _start.animateWith(
      SpringSimulation(
        startSpring,
        _start.value,
        index.toDouble(),
        _start.velocity,
        tolerance: _tolerance,
      ),
    );
    _end.animateWith(
      SpringSimulation(
        endSpring,
        _end.value,
        index + 1.0,
        _end.velocity,
        tolerance: _tolerance,
      ),
    );
  }

  void _select(int index) {
    if (!_interactive) return;
    final T value = widget.items[index].value;
    if (value == widget.value) return;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    widget.onChanged?.call(value);
  }

  void _step(int delta) {
    final int count = widget.items.length;
    _select((_index + delta + count) % count);
  }

  /// How much of segment [index] the thumb currently covers, 0 to 1.
  double _coverage(int index) {
    final double lo = math.min(_start.value, _end.value);
    final double hi = math.max(_start.value, _end.value);
    final double overlap = math.min(hi, index + 1.0) - math.max(lo, index);
    return overlap.clamp(0.0, 1.0);
  }

  Widget _buildSegment(
    BuildContext context,
    int index,
    TextStyle textStyle,
    Color foreground,
    Color selectedForeground,
  ) {
    final RubberSegmentItem<T> item = widget.items[index];
    final bool selected = index == _index;
    final bool interactive = _interactive;
    final Widget content = AnimatedBuilder(
      animation: _edges,
      builder: (BuildContext context, Widget? child) {
        final Color color = Color.lerp(
          foreground,
          selectedForeground,
          _coverage(index),
        )!;
        return IconTheme.merge(
          data: IconThemeData(color: color, size: 18),
          child: DefaultTextStyle(
            style: textStyle.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            child: child!,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_fontGeneration),
        child: Padding(
          padding: widget.segmentPadding,
          child: Center(
            widthFactor: 1.0,
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
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: interactive,
      label: item.semanticLabel,
      onTap: interactive ? () => _select(index) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: interactive ? () => _select(index) : null,
        child: item.semanticLabel == null
            ? content
            : ExcludeSemantics(child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.items.length >= 2, 'RubberSegment needs at least two items');
    assert(
      _indexOf(widget.value) >= 0,
      'value must match the value of one of the items',
    );
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle textStyle =
        widget.textStyle ?? theme.textTheme.labelLarge ?? const TextStyle();
    final Color foreground = widget.foregroundColor ?? scheme.onSurfaceVariant;
    final Color selectedForeground =
        widget.selectedForegroundColor ?? scheme.onPrimary;
    final bool interactive = _interactive;

    Widget result = _RubberSegmentLayout(
      start: _start,
      end: _end,
      height: widget.height,
      padding: widget.padding,
      fitContent: widget.fitContent,
      borderRadius: widget.borderRadius,
      thumbColor: widget.thumbColor ?? scheme.primary,
      backgroundColor: widget.backgroundColor ?? scheme.surfaceContainerHighest,
      shadowColor: scheme.shadow,
      focusColor: scheme.primary,
      focused: _focused && interactive,
      squash: !_reducedMotion,
      textDirection: Directionality.of(context),
      children: <Widget>[
        for (int i = 0; i < widget.items.length; i++)
          _buildSegment(context, i, textStyle, foreground, selectedForeground),
      ],
    );

    if (!interactive) {
      return Opacity(opacity: _disabledOpacity, child: result);
    }

    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    result = FocusableActionDetector(
      onShowFocusHighlight: (bool focused) {
        if (focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _SegmentStepIntent(
          rtl ? 1 : -1,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            _SegmentStepIntent(rtl ? -1 : 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _SegmentStepIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _SegmentStepIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _SegmentStepIntent: CallbackAction<_SegmentStepIntent>(
          onInvoke: (_SegmentStepIntent intent) {
            _step(intent.delta);
            return null;
          },
        ),
      },
      child: result,
    );
    return result;
  }
}

/// Moves the selection by [delta] segments.
class _SegmentStepIntent extends Intent {
  const _SegmentStepIntent(this.delta);

  final int delta;
}

class _RubberSegmentLayout extends MultiChildRenderObjectWidget {
  const _RubberSegmentLayout({
    required this.start,
    required this.end,
    required this.height,
    required this.padding,
    required this.fitContent,
    required this.borderRadius,
    required this.thumbColor,
    required this.backgroundColor,
    required this.shadowColor,
    required this.focusColor,
    required this.focused,
    required this.squash,
    required this.textDirection,
    required super.children,
  });

  final Animation<double> start;
  final Animation<double> end;
  final double height;
  final EdgeInsets padding;
  final bool fitContent;
  final BorderRadius? borderRadius;
  final Color thumbColor;
  final Color backgroundColor;
  final Color shadowColor;
  final Color focusColor;
  final bool focused;
  final bool squash;
  final TextDirection textDirection;

  @override
  _RenderRubberSegment createRenderObject(BuildContext context) {
    return _RenderRubberSegment(
      start: start,
      end: end,
      height: height,
      padding: padding,
      fitContent: fitContent,
      borderRadius: borderRadius,
      thumbColor: thumbColor,
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      focusColor: focusColor,
      focused: focused,
      squash: squash,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRubberSegment renderObject,
  ) {
    renderObject
      ..start = start
      ..end = end
      ..height = height
      ..padding = padding
      ..fitContent = fitContent
      ..borderRadius = borderRadius
      ..thumbColor = thumbColor
      ..backgroundColor = backgroundColor
      ..shadowColor = shadowColor
      ..focusColor = focusColor
      ..focused = focused
      ..squash = squash
      ..textDirection = textDirection;
  }
}

class _SegmentParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays the segments out in a row and paints the background, the rubber
/// thumb and the focus ring behind or around them.
///
/// Segment widths come from the intrinsic widths of the children, measured
/// on every layout. A change in a label (text, style, scale, locale) clears
/// the cached intrinsics up the tree and so relayouts this object; a system
/// fonts change does too, through [RelayoutWhenSystemFontsChangeMixin].
class _RenderRubberSegment extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SegmentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SegmentParentData>,
        RelayoutWhenSystemFontsChangeMixin {
  _RenderRubberSegment({
    required this._start,
    required this._end,
    required this._height,
    required this._padding,
    required this._fitContent,
    required this._borderRadius,
    required this._thumbColor,
    required this._backgroundColor,
    required this._shadowColor,
    required this._focusColor,
    required this._focused,
    required this._squash,
    required this._textDirection,
  });

  /// Minimum height of the interactive area.
  static const double _minTapTarget = 48.0;

  /// Minimum width of one segment.
  static const double _minSegmentWidth = 48.0;

  Animation<double> _start;
  set start(Animation<double> value) {
    if (value == _start) return;
    if (attached) _start.removeListener(markNeedsPaint);
    _start = value;
    if (attached) _start.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Animation<double> _end;
  set end(Animation<double> value) {
    if (value == _end) return;
    if (attached) _end.removeListener(markNeedsPaint);
    _end = value;
    if (attached) _end.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _fitContent;
  set fitContent(bool value) {
    if (value == _fitContent) return;
    _fitContent = value;
    markNeedsLayout();
  }

  BorderRadius? _borderRadius;
  set borderRadius(BorderRadius? value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  Color _thumbColor;
  set thumbColor(Color value) {
    if (value == _thumbColor) return;
    _thumbColor = value;
    markNeedsPaint();
  }

  Color _backgroundColor;
  set backgroundColor(Color value) {
    if (value == _backgroundColor) return;
    _backgroundColor = value;
    markNeedsPaint();
  }

  Color _shadowColor;
  set shadowColor(Color value) {
    if (value == _shadowColor) return;
    _shadowColor = value;
    markNeedsPaint();
  }

  Color _focusColor;
  set focusColor(Color value) {
    if (value == _focusColor) return;
    _focusColor = value;
    markNeedsPaint();
  }

  bool _focused;
  set focused(bool value) {
    if (value == _focused) return;
    _focused = value;
    markNeedsPaint();
  }

  bool _squash;
  set squash(bool value) {
    if (value == _squash) return;
    _squash = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Segment rectangles in local coordinates, in item order.
  List<Rect> _rects = const <Rect>[];

  final Paint _paint = Paint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _start.addListener(markNeedsPaint);
    _end.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _start.removeListener(markNeedsPaint);
    _end.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SegmentParentData) {
      child.parentData = _SegmentParentData();
    }
  }

  double get _outerHeight => math.max(_height, _minTapTarget);

  double get _innerHeight => math.max(0.0, _height - _padding.vertical);

  List<double> _naturalWidths() {
    final List<double> widths = <double>[];
    RenderBox? child = firstChild;
    while (child != null) {
      widths.add(
        math.max(_minSegmentWidth, child.getMaxIntrinsicWidth(_innerHeight)),
      );
      child = childAfter(child);
    }
    if (!_fitContent && widths.isNotEmpty) {
      final double widest = widths.reduce(math.max);
      for (int i = 0; i < widths.length; i++) {
        widths[i] = widest;
      }
    }
    return widths;
  }

  /// Segment widths and the overall size for [constraints].
  (List<double>, Size) _measure(BoxConstraints constraints) {
    final List<double> widths = _naturalWidths();
    final double natural = widths.fold(0.0, (double a, double b) => a + b);
    final double width = constraints.constrainWidth(
      natural + _padding.horizontal,
    );
    final double available = math.max(0.0, width - _padding.horizontal);
    if (natural > 0.0 && available != natural) {
      final double scale = available / natural;
      for (int i = 0; i < widths.length; i++) {
        widths[i] *= scale;
      }
    }
    return (widths, Size(width, constraints.constrainHeight(_outerHeight)));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _naturalWidths().fold(0.0, (double a, double b) => a + b) +
      _padding.horizontal;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _outerHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _outerHeight;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints).$2;

  @override
  void performLayout() {
    final (List<double> widths, Size measured) = _measure(constraints);
    size = measured;
    final bool rtl = _textDirection == TextDirection.rtl;
    final List<Rect> rects = <Rect>[];
    double x = rtl ? size.width - _padding.right : _padding.left;
    final double top = (size.height - _height) / 2 + _padding.top;
    RenderBox? child = firstChild;
    int i = 0;
    while (child != null) {
      final double w = widths[i];
      final double left = rtl ? x - w : x;
      // Children span the full interactive height; their content is
      // centered in the visual band.
      child.layout(
        BoxConstraints.tightFor(width: w, height: size.height),
        parentUsesSize: false,
      );
      (child.parentData! as _SegmentParentData).offset = Offset(left, 0.0);
      rects.add(Rect.fromLTWH(left, top, w, _innerHeight));
      x = rtl ? x - w : x + w;
      child = childAfter(child);
      i++;
    }
    _rects = rects;
  }

  /// Maps a position in segment index space to a horizontal coordinate.
  double _xFor(double position) {
    final int count = _rects.length;
    final double p = position.clamp(0.0, count.toDouble());
    final int k = math.min(p.floor(), count - 1);
    final Rect rect = _rects[k];
    final double fraction = p - k;
    return _textDirection == TextDirection.rtl
        ? rect.right - fraction * rect.width
        : rect.left + fraction * rect.width;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final Rect band = Rect.fromLTWH(
      offset.dx,
      offset.dy + (size.height - _height) / 2,
      size.width,
      _height,
    );
    final BorderRadius outerRadius =
        _borderRadius ?? BorderRadius.circular(_height / 2);
    _paint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..color = _backgroundColor;
    canvas.drawRRect(outerRadius.toRRect(band), _paint);

    if (_rects.isNotEmpty) {
      final RRect thumb = _thumbRRect(offset, outerRadius);
      _paint
        ..color = _shadowColor.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawRRect(thumb.shift(const Offset(0.0, 1.0)), _paint);
      _paint
        ..maskFilter = null
        ..color = _thumbColor;
      canvas.drawRRect(thumb, _paint);
      defaultPaint(context, offset);
      if (_focused) {
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = _focusColor;
        context.canvas.drawRRect(
          thumb.inflate(math.min(2.0, _padding.top)),
          _paint,
        );
      }
    } else {
      defaultPaint(context, offset);
    }
  }

  RRect _thumbRRect(Offset offset, BorderRadius outerRadius) {
    final double a = _xFor(_start.value);
    final double b = _xFor(_end.value);
    final double left = math.min(a, b);
    final double right = math.max(a, b);
    // Thin the thumb while it is stretched and fatten it slightly while it
    // is compressed, as if its volume were preserved.
    final double length = (_end.value - _start.value).abs();
    double heightScale = 1.0;
    if (_squash && length > 0.0) {
      heightScale = math.pow(1.0 / length, 0.3).toDouble().clamp(0.82, 1.06);
    }
    final double maxHeight = math.max(0.0, _height - 2.0);
    final double height = math.min(_innerHeight * heightScale, maxHeight);
    final double centerY = offset.dy + size.height / 2;
    final Rect rect = Rect.fromLTRB(
      offset.dx + left,
      centerY - height / 2,
      offset.dx + right,
      centerY + height / 2,
    );
    final double radius = math.min(
      math.max(0.0, outerRadius.topLeft.x - _padding.top),
      math.min(rect.width, rect.height) / 2,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(radius));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
