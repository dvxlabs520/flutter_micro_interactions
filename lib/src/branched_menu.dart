import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/motion.dart';

/// One selectable entry of a [BranchedMenuSection].
///
/// ```dart
/// BranchedMenuItem(id: 'install', label: 'Installation', badge: 'New')
/// ```
class BranchedMenuItem {
  /// Creates a menu item.
  const BranchedMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.badge,
  });

  /// Unique id of the item across the whole menu. It is passed to
  /// [BranchedMenu.onSelected] and compared with
  /// [BranchedMenu.selectedId].
  final String id;

  /// Text of the item.
  final String label;

  /// Optional leading icon, typically an [Icon].
  final Widget? icon;

  /// Optional short text shown as a small pill after the label, such as
  /// "New" or a count.
  final String? badge;
}

/// A collapsible group of [BranchedMenuItem]s with a title.
///
/// ```dart
/// BranchedMenuSection(
///   title: 'Getting started',
///   items: const <BranchedMenuItem>[
///     BranchedMenuItem(id: 'intro', label: 'Introduction'),
///     BranchedMenuItem(id: 'install', label: 'Installation'),
///   ],
/// )
/// ```
class BranchedMenuSection {
  /// Creates a menu section.
  const BranchedMenuSection({
    required this.title,
    required this.items,
    this.initiallyExpanded = true,
  });

  /// Title shown in the section header.
  final String title;

  /// Items of the section, in order.
  final List<BranchedMenuItem> items;

  /// Whether the section starts expanded. Defaults to `true`.
  final bool initiallyExpanded;
}

/// A collapsible navigation menu, like a docs sidebar, whose sections
/// branch off a vertical trunk line and whose selection is traced along
/// that trunk.
///
/// ```dart
/// BranchedMenu(
///   selectedId: _page,
///   onSelected: (String id) => setState(() => _page = id),
///   sections: const <BranchedMenuSection>[
///     BranchedMenuSection(
///       title: 'Getting started',
///       items: <BranchedMenuItem>[
///         BranchedMenuItem(id: 'intro', label: 'Introduction'),
///         BranchedMenuItem(id: 'install', label: 'Installation'),
///       ],
///     ),
///     BranchedMenuSection(
///       title: 'Components',
///       items: <BranchedMenuItem>[
///         BranchedMenuItem(id: 'button', label: 'Button', badge: 'New'),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// A thin trunk runs down the leading edge, with a node at every section
/// header. Tapping a header expands or collapses its section with a smooth
/// size animation. Items connect to the trunk with small rounded branch
/// lines.
///
/// The selected item gets a soft pill background and a highlighted line
/// traced from the top of the trunk down to it. When the selection
/// changes, the highlight first retracts from the old item back along its
/// branch and the trunk to the point both paths share, then grows along
/// the trunk and out to the new item. When the section of the selected
/// item collapses, the highlight follows it up to the section's node.
///
/// The menu is controlled: tapping an item calls [onSelected], and the
/// highlight moves once [selectedId] changes.
///
/// Keyboard: headers and items are focusable. Up and Down move focus
/// between visible rows, Home and End jump to the first and last row,
/// Right expands a collapsed section (or enters an expanded one), Left
/// collapses a section or moves from an item to its header, and Enter or
/// Space activates the focused row. Headers are exposed as buttons with
/// an expanded state; items as buttons with a selected state.
///
/// Under reduced motion, or when [enabled] is false, sections open and
/// close instantly and the highlight jumps without tracing. A disabled
/// menu is also dimmed and ignores input.
class BranchedMenu extends StatefulWidget {
  /// Creates a branched menu.
  const BranchedMenu({
    super.key,
    required this.sections,
    this.selectedId,
    this.onSelected,
    this.indent = 24.0,
    this.itemHeight = 36.0,
    this.sectionSpacing = 4.0,
    this.trunkColor,
    this.highlightColor,
    this.selectedBackgroundColor,
    this.textStyle,
    this.headerStyle,
    this.duration = const Duration(milliseconds: 300),
    this.traceDuration = const Duration(milliseconds: 480),
    this.curve = Curves.easeInOutCubic,
    this.enabled = true,
  }) : assert(indent >= 16, 'indent must be at least 16'),
       assert(itemHeight >= 24, 'itemHeight must be at least 24'),
       assert(sectionSpacing >= 0, 'sectionSpacing must not be negative');

  /// The sections of the menu, in order.
  final List<BranchedMenuSection> sections;

  /// Id of the selected item, or null for no selection.
  final String? selectedId;

  /// Called with an item's id when it is tapped or activated.
  final ValueChanged<String>? onSelected;

  /// Horizontal distance from the trunk to the item pills. Defaults to 24.
  final double indent;

  /// Height of every header and item row. Defaults to 36.
  final double itemHeight;

  /// Vertical gap between two sections. Defaults to 4.
  final double sectionSpacing;

  /// Color of the trunk, branches and nodes. Defaults to the theme's
  /// `colorScheme.outlineVariant`.
  final Color? trunkColor;

  /// Color of the traced selection line and the selected label. Defaults
  /// to the theme's `colorScheme.primary`.
  final Color? highlightColor;

  /// Pill background of the selected item. Defaults to the theme's
  /// `colorScheme.primary` at 10 percent alpha.
  final Color? selectedBackgroundColor;

  /// Text style of items. Defaults to the theme's `textTheme.bodyMedium`.
  final TextStyle? textStyle;

  /// Text style of section headers. Defaults to the theme's
  /// `textTheme.labelLarge` with a semi-bold weight.
  final TextStyle? headerStyle;

  /// Length of the expand and collapse animation. Defaults to 300
  /// milliseconds.
  final Duration duration;

  /// Length of the selection trace (retract plus grow). Defaults to 480
  /// milliseconds.
  final Duration traceDuration;

  /// Curve of the expand, collapse and trace animations. Defaults to
  /// [Curves.easeInOutCubic].
  final Curve curve;

  /// When false the menu is dimmed, ignores input and changes without
  /// animation. Defaults to `true`.
  final bool enabled;

  @override
  State<BranchedMenu> createState() => _BranchedMenuState();
}

/// A resolved position of a traced item.
class _TraceTarget {
  const _TraceTarget(this.id, this.section, this.item);

  final String id;
  final int section;
  final int item;
}

/// What part of which path is currently drawn.
class _TraceState {
  const _TraceState(this.target, this.length);

  final _TraceTarget? target;
  final double length;
}

/// Vertical layout of the menu at the current point of the expand
/// animations, shared by the painter and the state.
class _MenuGeometry {
  _MenuGeometry({
    required this.counts,
    required this.expansion,
    required this.rowHeight,
    required this.spacing,
    required this.trunkX,
    required this.branchEnd,
  }) {
    double top = 0.0;
    for (int s = 0; s < counts.length; s++) {
      _tops.add(top);
      top += rowHeight + counts[s] * rowHeight * expansion[s];
      if (s < counts.length - 1) top += spacing;
    }
  }

  final List<int> counts;
  final List<double> expansion;
  final double rowHeight;
  final double spacing;
  final double trunkX;
  final double branchEnd;
  final List<double> _tops = <double>[];

  /// Corner radius of a branch.
  double get radius => math.min(8.0, (branchEnd - trunkX) * 0.6);

  double sectionTop(int s) => _tops[s];

  double headerCenter(int s) => _tops[s] + rowHeight / 2;

  double get trunkTop => counts.isEmpty ? 0.0 : headerCenter(0);

  double itemCenter(int s, int i) =>
      _tops[s] + rowHeight + i * rowHeight + rowHeight / 2;

  double contentHeight(int s) => counts[s] * rowHeight * expansion[s];

  /// End of the trunk: the last header, or the branch start of the last
  /// visible item of the last section.
  double get trunkBottom {
    if (counts.isEmpty) return 0.0;
    final int last = counts.length - 1;
    final double header = headerCenter(last);
    if (counts[last] == 0) return header;
    final double lastItem = itemCenter(last, counts[last] - 1) - radius;
    return header + (lastItem - header) * expansion[last];
  }

  /// End point and branch scale of the traced path to [target].
  ({double y, double scale}) _end(_TraceTarget target) {
    final double e = expansion[target.section];
    final double header = headerCenter(target.section);
    final double y =
        header + (itemCenter(target.section, target.item) - header) * e;
    return (y: y, scale: e);
  }

  /// Where the path to [target] ends.
  Offset endPoint(_TraceTarget target) {
    final ({double y, double scale}) end = _end(target);
    return Offset(trunkX + (branchEnd - trunkX) * end.scale, end.y);
  }

  /// Length of the trunk part of the path to [target].
  double verticalLength(_TraceTarget target) {
    final ({double y, double scale}) end = _end(target);
    return math.max(0.0, end.y - radius * end.scale - trunkTop);
  }

  /// Total length of the path to [target].
  double pathLength(_TraceTarget target) {
    final ({double y, double scale}) end = _end(target);
    final double r = radius * end.scale;
    final double horizontal = math.max(
      0.0,
      (trunkX + (branchEnd - trunkX) * end.scale) - (trunkX + r),
    );
    return verticalLength(target) + math.pi / 2 * r + horizontal;
  }

  /// Adds the first [length] pixels of the path to [target] to [path].
  void addTrace(Path path, _TraceTarget target, double length) {
    if (length <= 0) return;
    final ({double y, double scale}) end = _end(target);
    final double r = radius * end.scale;
    final double xEnd = trunkX + (branchEnd - trunkX) * end.scale;
    final double vertical = verticalLength(target);
    double remaining = length;
    path.moveTo(trunkX, trunkTop);
    if (remaining <= vertical) {
      path.lineTo(trunkX, trunkTop + remaining);
      return;
    }
    path.lineTo(trunkX, trunkTop + vertical);
    remaining -= vertical;
    if (r > 0.01) {
      final double arc = math.pi / 2 * r;
      final Rect circle = Rect.fromCircle(
        center: Offset(trunkX + r, end.y - r),
        radius: r,
      );
      if (remaining <= arc) {
        path.arcTo(circle, math.pi, -math.pi / 2 * (remaining / arc), false);
        return;
      }
      path.arcTo(circle, math.pi, -math.pi / 2, false);
      remaining -= arc;
    }
    final double horizontal = math.max(0.0, xEnd - (trunkX + r));
    path.lineTo(trunkX + r + math.min(remaining, horizontal), end.y);
  }

  /// Resolves which path is drawn, and how much of it, at progress [t] of
  /// a retract-then-grow trace from [from] to [to].
  _TraceState resolve(
    _TraceTarget? from,
    double? fromLength,
    _TraceTarget? to,
    double t,
  ) {
    final double lengthFrom = from == null
        ? 0.0
        : math.min(fromLength ?? double.infinity, pathLength(from));
    final double lengthTo = to == null ? 0.0 : pathLength(to);
    final double common = from == null || to == null
        ? 0.0
        : math.min(
            lengthFrom,
            math.min(verticalLength(from), verticalLength(to)),
          );
    final double back = lengthFrom - common;
    final double forward = lengthTo - common;
    final double total = back + forward;
    if (total <= 0.0 || t >= 1.0) return _TraceState(to, lengthTo);
    final double distance = t.clamp(0.0, 1.0) * total;
    if (distance < back) return _TraceState(from, lengthFrom - distance);
    return _TraceState(to, common + distance - back);
  }
}

class _BranchedMenuState extends State<BranchedMenu>
    with TickerProviderStateMixin {
  /// Distance from the leading edge to the trunk.
  static const double _trunkX = 12.0;

  /// Horizontal padding inside an item pill.
  static const double _pillPadding = 10.0;

  final List<AnimationController> _expand = <AnimationController>[];
  final List<CurvedAnimation> _expandCurves = <CurvedAnimation>[];
  final List<bool> _expanded = <bool>[];
  final List<FocusNode> _headerNodes = <FocusNode>[];
  final Map<String, FocusNode> _itemNodes = <String, FocusNode>{};
  late final AnimationController _trace;
  late CurvedAnimation _traceCurve;

  String? _fromId;
  double? _fromLength;
  String? _toId;
  bool _reducedMotion = false;

  bool get _animate => widget.enabled && !_reducedMotion;

  double get _branchEnd => _trunkX + widget.indent - _pillPadding;

  @override
  void initState() {
    super.initState();
    _trace = AnimationController(
      vsync: this,
      duration: widget.traceDuration,
      value: 1.0,
    );
    _traceCurve = CurvedAnimation(parent: _trace, curve: widget.curve);
    _syncSections(initial: true);
    _toId = widget.selectedId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MicroMotion.isReduced(context);
    if (!_animate) _finishAnimations();
  }

  @override
  void didUpdateWidget(BranchedMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.traceDuration != oldWidget.traceDuration) {
      _trace.duration = widget.traceDuration;
    }
    if (widget.duration != oldWidget.duration) {
      for (final AnimationController controller in _expand) {
        controller.duration = widget.duration;
      }
    }
    if (widget.curve != oldWidget.curve) {
      _traceCurve.dispose();
      _traceCurve = CurvedAnimation(parent: _trace, curve: widget.curve);
      for (int s = 0; s < _expandCurves.length; s++) {
        _expandCurves[s].dispose();
        _expandCurves[s] = CurvedAnimation(
          parent: _expand[s],
          curve: widget.curve,
        );
      }
    }
    if (widget.sections.length != oldWidget.sections.length) {
      _syncSections(initial: false);
    }
    _pruneItemNodes();
    if (widget.enabled != oldWidget.enabled && !_animate) {
      _finishAnimations();
    }
    if (widget.selectedId != oldWidget.selectedId) {
      _retrace(widget.selectedId);
    }
  }

  @override
  void dispose() {
    for (final CurvedAnimation curve in _expandCurves) {
      curve.dispose();
    }
    for (final AnimationController controller in _expand) {
      controller.dispose();
    }
    for (final FocusNode node in _headerNodes) {
      node.dispose();
    }
    for (final FocusNode node in _itemNodes.values) {
      node.dispose();
    }
    _traceCurve.dispose();
    _trace.dispose();
    super.dispose();
  }

  void _syncSections({required bool initial}) {
    final int count = widget.sections.length;
    while (_expand.length > count) {
      _expandCurves.removeLast().dispose();
      _expand.removeLast().dispose();
      _expanded.removeLast();
      _headerNodes.removeLast().dispose();
    }
    while (_expand.length < count) {
      final bool open = widget.sections[_expand.length].initiallyExpanded;
      final AnimationController controller = AnimationController(
        vsync: this,
        duration: widget.duration,
        value: open ? 1.0 : 0.0,
      );
      controller.addStatusListener(_handleExpandStatus);
      _expand.add(controller);
      _expandCurves.add(
        CurvedAnimation(parent: controller, curve: widget.curve),
      );
      _expanded.add(open);
      _headerNodes.add(
        FocusNode(debugLabel: 'BranchedMenu section ${_headerNodes.length}'),
      );
    }
  }

  void _handleExpandStatus(AnimationStatus status) {
    // Fully collapsed sections drop their rows from the tree.
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _pruneItemNodes() {
    final Set<String> ids = <String>{
      for (final BranchedMenuSection section in widget.sections)
        for (final BranchedMenuItem item in section.items) item.id,
    };
    final List<String> stale = _itemNodes.keys
        .where((String id) => !ids.contains(id))
        .toList();
    for (final String id in stale) {
      _itemNodes.remove(id)?.dispose();
    }
  }

  FocusNode _itemNode(String id) => _itemNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'BranchedMenu $id'),
  );

  void _finishAnimations() {
    for (int s = 0; s < _expand.length; s++) {
      _expand[s].value = _expanded[s] ? 1.0 : 0.0;
    }
    _fromId = null;
    _fromLength = null;
    _trace.value = 1.0;
  }

  _TraceTarget? _locate(String? id) {
    if (id == null) return null;
    for (int s = 0; s < widget.sections.length; s++) {
      final List<BranchedMenuItem> items = widget.sections[s].items;
      for (int i = 0; i < items.length; i++) {
        if (items[i].id == id) return _TraceTarget(id, s, i);
      }
    }
    return null;
  }

  _MenuGeometry _geometry() => _MenuGeometry(
    counts: <int>[
      for (final BranchedMenuSection section in widget.sections)
        section.items.length,
    ],
    expansion: <double>[
      for (final CurvedAnimation curve in _expandCurves)
        curve.value.clamp(0.0, 1.0),
    ],
    rowHeight: widget.itemHeight,
    spacing: widget.sectionSpacing,
    trunkX: _trunkX,
    branchEnd: _branchEnd,
  );

  void _retrace(String? id) {
    if (!_animate) {
      _fromId = null;
      _fromLength = null;
      _toId = id;
      _trace.value = 1.0;
      return;
    }
    final _TraceState current = _geometry().resolve(
      _locate(_fromId),
      _fromLength,
      _locate(_toId),
      _traceCurve.value,
    );
    _fromId = current.target?.id;
    _fromLength = current.length;
    _toId = id;
    _trace.forward(from: 0.0);
  }

  void _toggle(int section) {
    if (!widget.enabled) return;
    setState(() => _expanded[section] = !_expanded[section]);
    if (!_animate) {
      _expand[section].value = _expanded[section] ? 1.0 : 0.0;
    } else if (_expanded[section]) {
      _expand[section].forward();
    } else {
      _expand[section].reverse();
    }
  }

  void _select(String id) {
    if (!widget.enabled) return;
    widget.onSelected?.call(id);
  }

  // ---------------------------------------------------------------------
  // Keyboard.

  /// Focusable rows in visual order; items of collapsed sections are left
  /// out.
  List<({FocusNode node, int section, String? id})> _visibleRows() {
    final List<({FocusNode node, int section, String? id})> rows =
        <({FocusNode node, int section, String? id})>[];
    for (int s = 0; s < widget.sections.length; s++) {
      rows.add((node: _headerNodes[s], section: s, id: null));
      if (!_expanded[s]) continue;
      for (final BranchedMenuItem item in widget.sections[s].items) {
        rows.add((node: _itemNode(item.id), section: s, id: item.id));
      }
    }
    return rows;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!widget.enabled) return KeyEventResult.ignored;
    final List<({FocusNode node, int section, String? id})> rows =
        _visibleRows();
    final int index = rows.indexWhere(
      (({FocusNode node, int section, String? id}) row) => row.node.hasFocus,
    );
    if (index < 0) return KeyEventResult.ignored;
    final ({FocusNode node, int section, String? id}) row = rows[index];
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final LogicalKeyboardKey key = event.logicalKey;
    final LogicalKeyboardKey inward = rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final LogicalKeyboardKey outward = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (index < rows.length - 1) rows[index + 1].node.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) rows[index - 1].node.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      rows.first.node.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      rows.last.node.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == inward && row.id == null) {
      if (!_expanded[row.section]) {
        _toggle(row.section);
      } else if (index < rows.length - 1 &&
          rows[index + 1].section == row.section) {
        rows[index + 1].node.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == outward) {
      if (row.id != null) {
        _headerNodes[row.section].requestFocus();
      } else if (_expanded[row.section]) {
        _toggle(row.section);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------
  // Building.

  Widget _buildHeader(BuildContext context, int s, TextStyle style) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BranchedMenuSection section = widget.sections[s];
    final bool expanded = _expanded[s];
    final BorderRadius radius = BorderRadius.circular(widget.itemHeight / 4);
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: expanded,
        enabled: widget.enabled,
        child: SizedBox(
          height: widget.itemHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: _trunkX + 6),
            child: InkWell(
              focusNode: _headerNodes[s],
              canRequestFocus: widget.enabled,
              borderRadius: radius,
              onTap: widget.enabled ? () => _toggle(s) : null,
              hoverColor: scheme.onSurface.withValues(alpha: 0.04),
              focusColor: scheme.onSurface.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    ExcludeSemantics(
                      child: RotationTransition(
                        turns: _expandCurves[s].drive(
                          Tween<double>(begin: -0.25, end: 0.0),
                        ),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    BranchedMenuItem item,
    TextStyle style,
    Color highlight,
    Color selectedBackground,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool selected = item.id == widget.selectedId;
    final BorderRadius radius = BorderRadius.circular(widget.itemHeight / 4);
    final Color foreground = selected ? highlight : scheme.onSurfaceVariant;
    final Duration fade = _animate
        ? const Duration(milliseconds: 220)
        : Duration.zero;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: widget.enabled,
        child: SizedBox(
          height: widget.itemHeight,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: _branchEnd,
              top: 2,
              bottom: 2,
            ),
            child: AnimatedContainer(
              duration: fade,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected
                    ? selectedBackground
                    : selectedBackground.withValues(alpha: 0.0),
                borderRadius: radius,
              ),
              child: InkWell(
                focusNode: _itemNode(item.id),
                canRequestFocus: widget.enabled,
                borderRadius: radius,
                onTap: widget.enabled ? () => _select(item.id) : null,
                hoverColor: scheme.onSurface.withValues(alpha: 0.04),
                focusColor: scheme.onSurface.withValues(alpha: 0.10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _pillPadding),
                  child: Row(
                    children: <Widget>[
                      if (item.icon != null) ...<Widget>[
                        ExcludeSemantics(
                          child: IconTheme.merge(
                            data: IconThemeData(size: 16, color: foreground),
                            child: item.icon!,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: fade,
                          style: style.copyWith(
                            color: foreground,
                            fontWeight: selected ? FontWeight.w600 : null,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (item.badge != null) ...<Widget>[
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            child: Text(
                              item.badge!,
                              style:
                                  (theme.textTheme.labelSmall ??
                                          const TextStyle(fontSize: 11))
                                      .copyWith(
                                        color: scheme.onPrimaryContainer,
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems(
    BuildContext context,
    int s,
    TextStyle style,
    Color highlight,
    Color selectedBackground,
  ) {
    final AnimationController controller = _expand[s];
    if (controller.isDismissed && !_expanded[s]) {
      return const SizedBox.shrink();
    }
    Widget items = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final BranchedMenuItem item in widget.sections[s].items)
          _buildItem(context, item, style, highlight, selectedBackground),
      ],
    );
    if (!_expanded[s]) {
      // Collapsing: keep the rows painted but out of focus and semantics.
      items = ExcludeFocus(child: ExcludeSemantics(child: items));
    }
    final CurvedAnimation size = _expandCurves[s];
    return AnimatedBuilder(
      animation: size,
      child: items,
      builder: (BuildContext context, Widget? child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: size.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color trunk = widget.trunkColor ?? scheme.outlineVariant;
    final Color highlight = widget.highlightColor ?? scheme.primary;
    final Color selectedBackground =
        widget.selectedBackgroundColor ??
        scheme.primary.withValues(alpha: 0.10);
    final TextStyle itemStyle =
        widget.textStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final TextStyle headerStyle =
        widget.headerStyle ??
        (theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14)).copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        );

    final List<Widget> children = <Widget>[];
    for (int s = 0; s < widget.sections.length; s++) {
      if (s > 0) children.add(SizedBox(height: widget.sectionSpacing));
      children.add(_buildHeader(context, s, headerStyle));
      children.add(
        _buildItems(context, s, itemStyle, highlight, selectedBackground),
      );
    }

    Widget menu = CustomPaint(
      painter: _BranchPainter(
        repaint: Listenable.merge(<Listenable>[..._expandCurves, _trace]),
        counts: <int>[
          for (final BranchedMenuSection section in widget.sections)
            section.items.length,
        ],
        expansion: List<Animation<double>>.of(_expandCurves),
        rowHeight: widget.itemHeight,
        spacing: widget.sectionSpacing,
        trunkX: _trunkX,
        branchEnd: _branchEnd,
        from: _locate(_fromId),
        fromLength: _fromLength,
        to: _locate(_toId),
        trace: _traceCurve,
        trunkColor: trunk,
        highlightColor: highlight,
        nodeFill: scheme.surface,
        textDirection: Directionality.of(context),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    menu = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: FocusTraversalGroup(child: menu),
    );

    if (!widget.enabled) {
      menu = Opacity(opacity: 0.6, child: menu);
    }
    return menu;
  }
}

/// Paints the trunk, branches, section nodes and the traced selection.
class _BranchPainter extends CustomPainter {
  _BranchPainter({
    required Listenable repaint,
    required this.counts,
    required this.expansion,
    required this.rowHeight,
    required this.spacing,
    required this.trunkX,
    required this.branchEnd,
    required this.from,
    required this.fromLength,
    required this.to,
    required this.trace,
    required this.trunkColor,
    required this.highlightColor,
    required this.nodeFill,
    required this.textDirection,
  }) : super(repaint: repaint);

  final List<int> counts;

  /// Expansion of each section; read on every paint so the layout follows
  /// the expand animations.
  final List<Animation<double>> expansion;
  final double rowHeight;
  final double spacing;
  final double trunkX;
  final double branchEnd;
  final _TraceTarget? from;
  final double? fromLength;
  final _TraceTarget? to;
  final Animation<double> trace;
  final Color trunkColor;
  final Color highlightColor;
  final Color nodeFill;
  final TextDirection textDirection;

  final Path _branches = Path();
  final Path _highlight = Path();

  static const double _strokeWidth = 1.5;
  static const double _highlightWidth = 2.0;
  static const double _nodeRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final _MenuGeometry g = _MenuGeometry(
      counts: counts,
      expansion: <double>[
        for (final Animation<double> e in expansion) e.value.clamp(0.0, 1.0),
      ],
      rowHeight: rowHeight,
      spacing: spacing,
      trunkX: trunkX,
      branchEnd: branchEnd,
    );
    if (g.counts.isEmpty) return;
    canvas.save();
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final double x = g.trunkX;
    final double r = g.radius;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trunkColor;

    // Trunk.
    canvas.drawLine(Offset(x, g.trunkTop), Offset(x, g.trunkBottom), line);

    // Branches, clipped to each section's visible content.
    for (int s = 0; s < g.counts.length; s++) {
      final double height = g.contentHeight(s);
      if (g.counts[s] == 0 || height <= 0.5) continue;
      final double top = g.sectionTop(s) + g.rowHeight;
      _branches.reset();
      for (int i = 0; i < g.counts[s]; i++) {
        final double y = g.itemCenter(s, i);
        _branches
          ..moveTo(x, y - r)
          ..arcTo(
            Rect.fromCircle(center: Offset(x + r, y - r), radius: r),
            math.pi,
            -math.pi / 2,
            false,
          )
          ..lineTo(g.branchEnd, y);
      }
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, top, size.width, height));
      canvas.drawPath(_branches, line);
      canvas.restore();
    }

    // Traced selection.
    final _TraceState state = g.resolve(from, fromLength, to, trace.value);
    double reach = -1.0;
    final _TraceTarget? target = state.target;
    if (target != null && state.length > 0) {
      _highlight.reset();
      g.addTrace(_highlight, target, state.length);
      canvas.drawPath(
        _highlight,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _highlightWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = highlightColor,
      );
      reach = g.trunkTop + math.min(state.length, g.verticalLength(target));
      final double total = g.pathLength(target);
      final double expansion = g.expansion[target.section];
      if (state.length >= total - 0.5 && expansion > 0.0) {
        // A small dot where the trace meets the item; it shrinks away with
        // the branch when the section collapses.
        canvas.drawCircle(
          g.endPoint(target),
          2.5 * expansion,
          Paint()..color = highlightColor,
        );
      }
    }

    // Section nodes, lit once the trace passes them.
    final Paint ring = Paint()..color = nodeFill;
    final Paint node = Paint();
    for (int s = 0; s < g.counts.length; s++) {
      final Offset center = Offset(x, g.headerCenter(s));
      final bool lit = reach >= center.dy - 0.5;
      canvas.drawCircle(center, _nodeRadius + 1.5, ring);
      node.color = lit ? highlightColor : trunkColor;
      canvas.drawCircle(center, _nodeRadius, node);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BranchPainter oldDelegate) =>
      oldDelegate.from?.id != from?.id ||
      oldDelegate.from?.section != from?.section ||
      oldDelegate.from?.item != from?.item ||
      oldDelegate.fromLength != fromLength ||
      oldDelegate.to?.id != to?.id ||
      oldDelegate.to?.section != to?.section ||
      oldDelegate.to?.item != to?.item ||
      oldDelegate.trace != trace ||
      oldDelegate.trunkColor != trunkColor ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.nodeFill != nodeFill ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.spacing != spacing ||
      oldDelegate.trunkX != trunkX ||
      oldDelegate.branchEnd != branchEnd ||
      !listEquals(oldDelegate.counts, counts) ||
      !listEquals(oldDelegate.expansion, expansion);
}
