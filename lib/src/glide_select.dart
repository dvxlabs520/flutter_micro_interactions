import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// One choice of a [GlideSelect].
///
/// ```dart
/// GlideSelectOption<String>(
///   value: 'mono',
///   label: 'Monospace',
///   icon: const Icon(Icons.code),
/// )
/// ```
class GlideSelectOption<T> {
  /// Creates an option for a [GlideSelect].
  const GlideSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  /// The value passed to [GlideSelect.onChanged] when this option is
  /// picked.
  final T value;

  /// Text shown in the menu row, and in the chip while selected. It is
  /// also used for type-ahead and as the row's semantics label.
  final String label;

  /// Optional leading widget, typically an [Icon]. It is shown in the
  /// menu row and in the chip while this option is selected.
  final Widget? icon;

  /// Whether this option can be highlighted and picked. Disabled options
  /// render dimmed and are skipped by keyboard navigation. Defaults to
  /// `true`.
  final bool enabled;
}

/// How wide the menu of a [GlideSelect] is.
enum GlideSelectMenuWidth {
  /// The menu is exactly as wide as the chip.
  matchChip,

  /// The menu is as wide as its widest row, but never narrower than the
  /// chip.
  intrinsic,
}

/// A compact select chip whose menu pops out of the chip's corner, with a
/// highlight pill that glides between rows.
///
/// ```dart
/// GlideSelect<String>(
///   hint: 'Font',
///   value: _font,
///   onChanged: (String font) => setState(() => _font = font),
///   options: const <GlideSelectOption<String>>[
///     GlideSelectOption<String>(value: 'sans', label: 'Sans serif'),
///     GlideSelectOption<String>(value: 'serif', label: 'Serif'),
///     GlideSelectOption<String>(value: 'mono', label: 'Monospace'),
///   ],
/// )
/// ```
///
/// Tapping the chip opens the menu in the app's [Overlay] (via
/// [OverlayPortal]), anchored to the chip's corner: it scales and fades
/// out of that corner, and reverses back into it when closing. The menu
/// opens below the chip and flips above it when there is not enough room
/// below. Tall menus scroll within [menuMaxHeight].
///
/// A soft highlight pill marks the row under the pointer or the keyboard
/// highlight. When the highlight moves, the pill glides to the new row on
/// two springs: the leading edge is stiffer than the trailing edge, so the
/// pill stretches slightly in the direction of travel and settles back to
/// one row tall. The selected row shows a check mark.
///
/// Keyboard: when the chip is focused, Enter, Space or the arrow keys open
/// the menu. While open, Up and Down move the highlight (skipping disabled
/// options), Home and End jump to the first and last option, Enter or
/// Space picks the highlighted option, typing letters jumps to the first
/// matching label (type-ahead), and Escape or Tab closes the menu. Tapping
/// outside closes it too. Focus stays on the chip the whole time.
///
/// The chip is exposed as a button with an expanded state, its hint as
/// label and the selected option as value. Menu rows are exposed as
/// buttons with a selected state.
///
/// Under reduced motion the menu appears and disappears instantly and the
/// pill jumps between rows without gliding.
class GlideSelect<T> extends StatefulWidget {
  /// Creates a glide select.
  const GlideSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.menuMaxHeight = 280.0,
    this.menuWidth = GlideSelectMenuWidth.intrinsic,
    this.itemHeight = 40.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.chipColor,
    this.chipBorderColor,
    this.menuColor,
    this.highlightColor,
    this.checkColor,
    this.textStyle,
    this.duration = const Duration(milliseconds: 260),
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(menuMaxHeight > 0, 'menuMaxHeight must be positive'),
       assert(itemHeight > 0, 'itemHeight must be positive');

  /// The options listed in the menu, in order.
  final List<GlideSelectOption<T>> options;

  /// The currently selected value, or null when nothing is selected. The
  /// widget is controlled: update [value] from [onChanged].
  final T? value;

  /// Called with the picked option's value. When null the chip renders
  /// disabled and cannot open.
  final ValueChanged<T>? onChanged;

  /// Placeholder shown in the chip while [value] matches no option. It is
  /// also the chip's default semantics label.
  final String? hint;

  /// Maximum height of the menu. Longer menus scroll. The menu also
  /// shrinks to the room available on screen. Defaults to 280.
  final double menuMaxHeight;

  /// How wide the menu is. Defaults to [GlideSelectMenuWidth.intrinsic].
  final GlideSelectMenuWidth menuWidth;

  /// Height of one menu row. Defaults to 40.
  final double itemHeight;

  /// Corner radius of the chip and the menu. The highlight pill uses a
  /// slightly smaller radius. Defaults to 12.
  final BorderRadius borderRadius;

  /// Padding inside the chip. Defaults to 14 horizontal by 10 vertical.
  final EdgeInsetsGeometry chipPadding;

  /// Background of the chip. Defaults to the theme's
  /// `colorScheme.surfaceContainerHighest`.
  final Color? chipColor;

  /// Border color of the chip. Defaults to the theme's
  /// `colorScheme.outlineVariant`. The border turns
  /// `colorScheme.primary` while the chip has keyboard focus.
  final Color? chipBorderColor;

  /// Background of the menu. Defaults to the theme's
  /// `colorScheme.surfaceContainer`.
  final Color? menuColor;

  /// Color of the gliding highlight pill. Defaults to the theme's
  /// `colorScheme.primary` at 12 percent alpha.
  final Color? highlightColor;

  /// Color of the check mark on the selected row. Defaults to the theme's
  /// `colorScheme.primary`.
  final Color? checkColor;

  /// Text style of the chip label and the rows. Defaults to the theme's
  /// `textTheme.bodyMedium`.
  final TextStyle? textStyle;

  /// Length of the open animation. Closing takes about two thirds of it.
  /// Defaults to 260 milliseconds.
  final Duration duration;

  /// When false the chip renders dimmed and cannot open; an open menu
  /// closes. Defaults to `true`.
  final bool enabled;

  /// Optional focus node of the chip. The caller owns and disposes it.
  final FocusNode? focusNode;

  /// Whether the chip requests focus when first built. Defaults to
  /// `false`.
  final bool autofocus;

  /// Semantics label of the chip. Defaults to [hint].
  final String? semanticLabel;

  @override
  State<GlideSelect<T>> createState() => _GlideSelectState<T>();
}

class _GlideSelectState<T> extends State<GlideSelect<T>>
    with TickerProviderStateMixin {
  /// Vertical padding above the first and below the last row.
  static const double _menuPadding = 6.0;

  /// Horizontal inset of the highlight pill inside the menu.
  static const double _pillInset = 6.0;

  /// Gap between the chip and the menu.
  static const double _gap = 6.0;

  /// Minimum distance between the menu and the screen edges.
  static const double _screenMargin = 8.0;

  /// Scale the menu starts from when popping out of the chip's corner.
  static const double _startScale = 0.6;

  /// Spring of the pill edge that leads the motion.
  static final SpringDescription _leadSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 900, ratio: 0.9);

  /// Spring of the pill edge that trails the motion.
  static final SpringDescription _trailSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.85);

  late final AnimationController _menuController;
  late CurvedAnimation _scaleAnimation;
  late CurvedAnimation _fadeAnimation;
  late final AnimationController _pillTop;
  late final AnimationController _pillBottom;
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final Object _tapGroupId = Object();
  FocusNode? _ownFocusNode;
  ScrollController? _scrollController;
  Timer? _typeAheadTimer;
  String _typeAhead = '';

  bool _isOpen = false;
  bool _flipAbove = false;
  bool _hovered = false;
  bool _focusHighlight = false;
  bool _reducedMotion = false;
  int _highlight = -1;
  Size _chipSize = Size.zero;
  double _menuMaxHeight = 0.0;
  double _overlayWidth = double.infinity;

  FocusNode get _focusNode => widget.focusNode ?? _ownFocusNode!;

  bool get _interactive =>
      widget.enabled && widget.onChanged != null && widget.options.isNotEmpty;

  int get _selectedIndex {
    final T? value = widget.value;
    if (value == null) return -1;
    for (int i = 0; i < widget.options.length; i++) {
      if (widget.options[i].value == value) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownFocusNode = FocusNode(debugLabel: 'GlideSelect');
    }
    _focusNode.addListener(_handleFocusChange);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
    _menuController = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: _reverseDuration,
    );
    _menuController.addStatusListener(_handleMenuStatus);
    _createCurves();
    _pillTop = AnimationController.unbounded(vsync: this);
    _pillBottom = AnimationController.unbounded(vsync: this);
  }

  Duration get _reverseDuration =>
      Duration(microseconds: widget.duration.inMicroseconds * 2 ~/ 3);

  void _createCurves() {
    _scaleAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (_reducedMotion) {
      _pillTop.stop();
      _pillBottom.stop();
    }
  }

  @override
  void didUpdateWidget(GlideSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(
        _handleFocusChange,
      );
      if (widget.focusNode == null) {
        _ownFocusNode ??= FocusNode(debugLabel: 'GlideSelect');
      } else {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_handleFocusChange);
    }
    if (widget.duration != oldWidget.duration) {
      _menuController.duration = widget.duration;
      _menuController.reverseDuration = _reverseDuration;
    }
    if (_highlight >= widget.options.length) {
      _highlight = widget.options.isEmpty ? -1 : widget.options.length - 1;
      _jumpPill(_highlight);
    }
    if (_isOpen && !_interactive) {
      // Close after the build phase; the portal cannot change during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen && !_interactive) _close();
      });
    }
  }

  @override
  void dispose() {
    _typeAheadTimer?.cancel();
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _focusNode.removeListener(_handleFocusChange);
    _ownFocusNode?.dispose();
    _menuController.removeStatusListener(_handleMenuStatus);
    _scaleAnimation.dispose();
    _fadeAnimation.dispose();
    _menuController.dispose();
    _pillTop.dispose();
    _pillBottom.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    _updateFocusHighlight();
    if (!_focusNode.hasFocus && _isOpen) {
      _close();
    }
  }

  void _handleHighlightMode(FocusHighlightMode mode) => _updateFocusHighlight();

  void _updateFocusHighlight() {
    if (!mounted) return;
    final bool show =
        _focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (show != _focusHighlight) {
      setState(() => _focusHighlight = show);
    }
  }

  void _handleMenuStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _portal.isShowing) {
      _portal.hide();
    }
  }

  // ---------------------------------------------------------------------
  // Opening and closing.

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    if (_isOpen || !_interactive || !mounted) return;
    _measure();
    final int selected = _selectedIndex;
    _highlight = selected >= 0 && widget.options[selected].enabled
        ? selected
        : _nextEnabled(-1, 1);
    _jumpPill(_highlight);

    final double rowsHeight =
        widget.options.length * widget.itemHeight + _menuPadding * 2;
    final double viewport = math.min(rowsHeight, _menuMaxHeight);
    double initialOffset = 0.0;
    if (_highlight >= 0) {
      final double rowCenter =
          _menuPadding + (_highlight + 0.5) * widget.itemHeight;
      initialOffset = (rowCenter - viewport / 2).clamp(
        0.0,
        math.max(0.0, rowsHeight - viewport),
      );
    }
    final ScrollController? previous = _scrollController;
    if (previous == null || !previous.hasClients) {
      previous?.dispose();
      _scrollController = ScrollController(initialScrollOffset: initialOffset);
    } else {
      previous.jumpTo(initialOffset);
    }

    setState(() => _isOpen = true);
    if (!_portal.isShowing) _portal.show();
    if (_reducedMotion) {
      _menuController.value = 1.0;
    } else {
      _menuController.forward();
    }
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _close() {
    if (!_isOpen || !mounted) return;
    setState(() => _isOpen = false);
    _typeAheadTimer?.cancel();
    _typeAhead = '';
    if (_reducedMotion) {
      _menuController.value = 0.0;
      if (_portal.isShowing) _portal.hide();
    } else {
      _menuController.reverse();
    }
  }

  /// Measures the chip and decides whether the menu flips above it.
  void _measure() {
    final RenderBox? chip = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (chip == null || !chip.hasSize) return;
    _chipSize = chip.size;
    if (overlay == null || !overlay.hasSize) {
      _flipAbove = false;
      _menuMaxHeight = widget.menuMaxHeight;
      return;
    }
    _overlayWidth = overlay.size.width;
    final Offset topLeft = chip.localToGlobal(Offset.zero, ancestor: overlay);
    final double spaceBelow =
        overlay.size.height -
        topLeft.dy -
        chip.size.height -
        _gap -
        _screenMargin;
    final double spaceAbove = topLeft.dy - _gap - _screenMargin;
    final double rowsHeight =
        widget.options.length * widget.itemHeight + _menuPadding * 2;
    final double wanted = math.min(rowsHeight, widget.menuMaxHeight);
    _flipAbove = spaceBelow < wanted && spaceAbove > spaceBelow;
    final double room = _flipAbove ? spaceAbove : spaceBelow;
    final double minimum = widget.itemHeight + _menuPadding * 2;
    _menuMaxHeight = math.max(minimum, math.min(widget.menuMaxHeight, room));
  }

  // ---------------------------------------------------------------------
  // Highlight pill.

  double _rowTop(int index) => _menuPadding + index * widget.itemHeight;

  void _jumpPill(int index) {
    final int i = math.max(index, 0);
    _pillTop.value = _rowTop(i);
    _pillBottom.value = _rowTop(i) + widget.itemHeight;
  }

  void _moveHighlight(int index, {bool scroll = false}) {
    if (index < 0 || index >= widget.options.length) return;
    if (!widget.options[index].enabled) return;
    if (index == _highlight) return;
    final bool down = index > _highlight;
    setState(() => _highlight = index);
    final double top = _rowTop(index);
    final double bottom = top + widget.itemHeight;
    if (_reducedMotion || !_portal.isShowing) {
      _jumpPill(index);
    } else {
      _pillTop.animateWith(
        SpringSimulation(
          down ? _trailSpring : _leadSpring,
          _pillTop.value,
          top,
          _pillTop.velocity,
        ),
      );
      _pillBottom.animateWith(
        SpringSimulation(
          down ? _leadSpring : _trailSpring,
          _pillBottom.value,
          bottom,
          _pillBottom.velocity,
        ),
      );
    }
    if (scroll) _ensureVisible(index);
  }

  void _ensureVisible(int index) {
    final ScrollController? controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final ScrollPosition position = controller.position;
    final double top = _rowTop(index) - _menuPadding;
    final double bottom = _rowTop(index) + widget.itemHeight + _menuPadding;
    double? target;
    if (top < position.pixels) {
      target = top;
    } else if (bottom > position.pixels + position.viewportDimension) {
      target = bottom - position.viewportDimension;
    }
    if (target == null) return;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (_reducedMotion) {
      controller.jumpTo(target);
    } else {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int _nextEnabled(int from, int step) {
    int i = from + step;
    while (i >= 0 && i < widget.options.length) {
      if (widget.options[i].enabled) return i;
      i += step;
    }
    return -1;
  }

  void _select(int index) {
    if (index < 0 || index >= widget.options.length) return;
    final GlideSelectOption<T> option = widget.options[index];
    if (!option.enabled || !_interactive) return;
    widget.onChanged?.call(option.value);
    _close();
  }

  // ---------------------------------------------------------------------
  // Keyboard.

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_interactive) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    final bool activate =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (!_isOpen) {
      if (event is KeyDownEvent &&
          (activate ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowUp)) {
        _open();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final int next = _nextEnabled(_highlight, 1);
      if (next >= 0) _moveHighlight(next, scroll: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final int next = _nextEnabled(_highlight, -1);
      if (next >= 0) _moveHighlight(next, scroll: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      final int next = _nextEnabled(-1, 1);
      if (next >= 0) _moveHighlight(next, scroll: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      final int next = _nextEnabled(widget.options.length, -1);
      if (next >= 0) _moveHighlight(next, scroll: true);
      return KeyEventResult.handled;
    }
    if (activate &&
        !(key == LogicalKeyboardKey.space && _typeAhead.isNotEmpty)) {
      if (event is KeyDownEvent) _select(_highlight);
      return KeyEventResult.handled;
    }
    final String? character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.codeUnitAt(0) >= 0x20 &&
        character.codeUnitAt(0) != 0x7f) {
      _typeAheadSearch(character.toLowerCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _typeAheadSearch(String character) {
    _typeAheadTimer?.cancel();
    _typeAheadTimer = Timer(const Duration(milliseconds: 700), () {
      _typeAhead = '';
    });
    _typeAhead += character;
    final int count = widget.options.length;
    // A single key cycles through matches; longer input refines in place.
    final int start = _typeAhead.length == 1 ? _highlight + 1 : _highlight;
    for (int n = 0; n < count; n++) {
      final int i = (math.max(start, 0) + n) % count;
      final GlideSelectOption<T> option = widget.options[i];
      if (option.enabled && option.label.toLowerCase().startsWith(_typeAhead)) {
        _moveHighlight(i, scroll: true);
        return;
      }
    }
  }

  // ---------------------------------------------------------------------
  // Building.

  TextStyle _textStyle(BuildContext context) =>
      widget.textStyle ??
      Theme.of(context).textTheme.bodyMedium ??
      const TextStyle(fontSize: 14);

  Widget _buildMenu(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final Alignment chipCorner = _flipAbove
        ? (rtl ? Alignment.topRight : Alignment.topLeft)
        : (rtl ? Alignment.bottomRight : Alignment.bottomLeft);
    final Alignment menuCorner = _flipAbove
        ? (rtl ? Alignment.bottomRight : Alignment.bottomLeft)
        : (rtl ? Alignment.topRight : Alignment.topLeft);
    final TextStyle style = _textStyle(context);
    final Color highlight =
        widget.highlightColor ?? scheme.primary.withValues(alpha: 0.12);
    final Color check = widget.checkColor ?? scheme.primary;
    final int selected = _selectedIndex;
    final double rowsHeight =
        widget.options.length * widget.itemHeight + _menuPadding * 2;
    final double pillRadius = math.max(
      0.0,
      widget.borderRadius.topLeft.x - _pillInset / 2,
    );

    Widget rows = Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PillPainter(
                  top: _pillTop,
                  bottom: _pillBottom,
                  color: highlight,
                  radius: pillRadius,
                  inset: _pillInset,
                  visible: _highlight >= 0,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: _menuPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < widget.options.length; i++)
                _buildRow(context, i, i == selected, style, check),
            ],
          ),
        ),
      ],
    );

    rows = SingleChildScrollView(
      controller: _scrollController,
      primary: false,
      child: rows,
    );

    Widget menu = Material(
      color: widget.menuColor ?? scheme.surfaceContainer,
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.4),
      // A hairline border keeps the menu distinct on dark surfaces, where
      // the shadow is barely visible.
      shape: RoundedRectangleBorder(
        borderRadius: widget.borderRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: math.min(rowsHeight, _menuMaxHeight),
        child: rows,
      ),
    );

    final double minWidth = _chipSize.width;
    if (widget.menuWidth == GlideSelectMenuWidth.matchChip) {
      menu = SizedBox(width: minWidth, child: menu);
    } else {
      final double maxWidth = math.max(
        minWidth,
        _overlayWidth - _screenMargin * 2,
      );
      menu = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: IntrinsicWidth(child: menu),
      );
    }

    menu = Semantics(
      explicitChildNodes: true,
      label: widget.semanticLabel ?? widget.hint,
      child: menu,
    );

    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: chipCorner,
        followerAnchor: menuCorner,
        offset: Offset(0, _flipAbove ? -_gap : _gap),
        child: TapRegion(
          groupId: _tapGroupId,
          onTapOutside: (PointerDownEvent _) => _close(),
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: AnimatedBuilder(
              animation: _menuController,
              child: menu,
              builder: (BuildContext context, Widget? child) {
                final double scale =
                    _startScale + (1.0 - _startScale) * _scaleAnimation.value;
                return Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: math.max(scale, 0.0),
                    alignment: menuCorner,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    bool isSelected,
    TextStyle style,
    Color check,
  ) {
    final GlideSelectOption<T> option = widget.options[index];
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = scheme.onSurface.withValues(
      alpha: option.enabled ? 1.0 : 0.38,
    );
    Widget row = SizedBox(
      height: widget.itemHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
        child: Row(
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(
                  size: 18,
                  color: foreground.withValues(alpha: foreground.a * 0.8),
                ),
                child: option.icon!,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 18,
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 18, color: check)
                  : null,
            ),
          ],
        ),
      ),
    );
    row = MouseRegion(
      cursor: option.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (PointerEnterEvent _) => _moveHighlight(index),
      onHover: (PointerHoverEvent _) => _moveHighlight(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: option.enabled ? () => _select(index) : null,
        child: row,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      enabled: option.enabled,
      label: option.label,
      onTap: option.enabled ? () => _select(index) : null,
      child: ExcludeSemantics(child: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle style = _textStyle(context);
    final bool interactive = _interactive;
    final int selected = _selectedIndex;
    final GlideSelectOption<T>? option = selected >= 0
        ? widget.options[selected]
        : null;

    final Color baseColor = widget.chipColor ?? scheme.surfaceContainerHighest;
    final Color chipColor = interactive && (_hovered || _isOpen)
        ? Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.05), baseColor)
        : baseColor;
    final Color borderColor = _focusHighlight
        ? scheme.primary
        : (widget.chipBorderColor ?? scheme.outlineVariant);

    final Widget label = option != null
        ? Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: scheme.onSurface),
          )
        : Text(
            widget.hint ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: scheme.onSurfaceVariant),
          );

    Widget chip = DecoratedBox(
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: borderColor,
          width: _focusHighlight ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: widget.chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (option?.icon != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(size: 18, color: scheme.onSurfaceVariant),
                child: option!.icon!,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: label),
            const SizedBox(width: 6),
            RotationTransition(
              turns: _scaleAnimation.drive(Tween<double>(begin: 0.0, end: 0.5)),
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (!interactive) {
      chip = Opacity(opacity: 0.5, child: chip);
    }

    chip = MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (PointerEnterEvent _) => setState(() => _hovered = true),
      onExit: (PointerExitEvent _) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive
            ? () {
                _focusNode.requestFocus();
                _toggle();
              }
            : null,
        child: chip,
      ),
    );

    chip = Semantics(
      container: true,
      button: true,
      enabled: interactive,
      expanded: _isOpen,
      label: widget.semanticLabel ?? widget.hint,
      value: option?.label,
      onTap: interactive ? _toggle : null,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: interactive,
        onKeyEvent: _handleKey,
        child: ExcludeSemantics(child: chip),
      ),
    );

    return TapRegion(
      groupId: _tapGroupId,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _buildMenu,
          child: chip,
        ),
      ),
    );
  }
}

/// Paints the gliding highlight pill between two animated edges.
class _PillPainter extends CustomPainter {
  _PillPainter({
    required this.top,
    required this.bottom,
    required this.color,
    required this.radius,
    required this.inset,
    required this.visible,
  }) : super(repaint: Listenable.merge(<Listenable>[top, bottom]));

  final Animation<double> top;
  final Animation<double> bottom;
  final Color color;
  final double radius;
  final double inset;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final double t = math.min(top.value, bottom.value);
    final double b = math.max(top.value, bottom.value);
    final Rect rect = Rect.fromLTRB(inset, t, size.width - inset, b);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PillPainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.inset != inset ||
      oldDelegate.visible != visible;
}
