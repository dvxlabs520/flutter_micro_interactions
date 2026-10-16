import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// A reorderable list with a polished lift effect on the dragged item.
///
/// Wraps [ReorderableListView] and decorates the drag proxy with a subtle
/// scale (about its center) and elevation while it is lifted. Indexes given
/// to [onReorderItem] are already adjusted for the removed item, so they can
/// be used directly with `removeAt` and `insert`.
///
/// Every child must have a [Key]:
///
/// ```dart
/// MicroReorderableList(
///   onReorderItem: (oldIndex, newIndex) {
///     setState(() => items.insert(newIndex, items.removeAt(oldIndex)));
///   },
///   children: [
///     for (final item in items) ListTile(key: ValueKey(item.id), title: Text(item.name)),
///   ],
/// )
/// ```
///
/// Use [MicroReorderableList.builder] for large or lazily built lists.
/// Under reduced motion the lifted item keeps its elevation but does not
/// animate its scale.
class MicroReorderableList extends StatelessWidget {
  /// Creates a reorderable list from an explicit list of [children].
  ///
  /// Every child must have a non-null key.
  MicroReorderableList({
    super.key,
    required List<Widget> this.children,
    this.onReorderItem,
    @Deprecated(
      'Use onReorderItem instead. '
      'This feature was deprecated after v0.3.0.',
    )
    this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.buildDefaultDragHandles = true,
    this.showDragHandle = false,
    this.liftScale = 1.04,
    this.liftElevation = 4.0,
    this.proxyDecorator,
  }) : itemBuilder = null,
       itemCount = null,
       assert(
         children.every((Widget child) => child.key != null),
         'Every child of MicroReorderableList must have a key.',
       ),
       assert(
         (onReorderItem == null) != (onReorder == null),
         'Provide exactly one of onReorderItem or onReorder.',
       ),
       assert(liftScale >= 1.0, 'liftScale must be >= 1.0'),
       assert(liftElevation >= 0.0, 'liftElevation must be non-negative');

  /// Creates a reorderable list that builds items lazily.
  ///
  /// Every widget returned by [itemBuilder] must have a non-null key.
  const MicroReorderableList.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    this.onReorderItem,
    @Deprecated(
      'Use onReorderItem instead. '
      'This feature was deprecated after v0.3.0.',
    )
    this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.buildDefaultDragHandles = true,
    this.showDragHandle = false,
    this.liftScale = 1.04,
    this.liftElevation = 4.0,
    this.proxyDecorator,
  }) : children = null,
       assert(itemCount >= 0, 'itemCount must be non-negative'),
       assert(
         (onReorderItem == null) != (onReorder == null),
         'Provide exactly one of onReorderItem or onReorder.',
       ),
       assert(liftScale >= 1.0, 'liftScale must be >= 1.0'),
       assert(liftElevation >= 0.0, 'liftElevation must be non-negative');

  /// The items of the list. `null` when using
  /// [MicroReorderableList.builder]. Every child must have a key.
  final List<Widget>? children;

  /// Lazily builds each item. `null` when using the default constructor.
  final IndexedWidgetBuilder? itemBuilder;

  /// Number of items for [MicroReorderableList.builder].
  final int? itemCount;

  /// Called when an item has been dragged to a new position.
  ///
  /// `newIndex` is already adjusted for the removed item, so the move is
  /// `items.insert(newIndex, items.removeAt(oldIndex))`.
  final ReorderCallback? onReorderItem;

  /// Legacy reorder callback where `newIndex` is the index *before* the
  /// item is removed. Callers adjust with
  /// `if (oldIndex < newIndex) newIndex -= 1;`.
  @Deprecated(
    'Use onReorderItem instead. '
    'This feature was deprecated after v0.3.0.',
  )
  final ReorderCallback? onReorder;

  /// Forwards a move to [onReorderItem], or to the legacy [onReorder] with
  /// the index converted back to the pre-removal convention.
  void _handleReorder(int oldIndex, int newIndex) {
    if (onReorderItem != null) {
      onReorderItem!(oldIndex, newIndex);
      return;
    }
    // ignore: deprecated_member_use_from_same_package
    onReorder!(oldIndex, oldIndex < newIndex ? newIndex + 1 : newIndex);
  }

  /// Called with the index of the item when a drag starts.
  final ValueChanged<int>? onReorderStart;

  /// Called with the index of the item when a drag ends.
  final ValueChanged<int>? onReorderEnd;

  /// Padding around the items.
  final EdgeInsets? padding;

  /// Optional external scroll controller. The caller keeps ownership.
  final ScrollController? scrollController;

  /// Whether the list sizes itself to its children. Defaults to `false`.
  final bool shrinkWrap;

  /// Physics for the list.
  final ScrollPhysics? physics;

  /// The axis along which the list scrolls. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the underlying [ReorderableListView] adds its own drag
  /// listeners to every item. Ignored (forced to `false`) when
  /// [showDragHandle] is `true`. Defaults to `true`.
  final bool buildDefaultDragHandles;

  /// When `true` each item shows an explicit drag handle wired with
  /// [ReorderableDragStartListener], and only the handle starts a drag.
  /// Defaults to `false`.
  final bool showDragHandle;

  /// How much the dragged item scales up while lifted. Defaults to `1.04`.
  ///
  /// Ignored when a custom [proxyDecorator] is provided, and not animated
  /// under reduced motion.
  final double liftScale;

  /// The elevation of the dragged item while lifted. Defaults to `4.0`.
  ///
  /// Ignored when a custom [proxyDecorator] is provided.
  final double liftElevation;

  /// Optional override for the drag proxy decoration. When `null` the
  /// default lift effect ([liftScale] plus [liftElevation]) is used.
  final ReorderItemProxyDecorator? proxyDecorator;

  Widget _defaultProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(animation.value);
        if (MicroMotion.isReduced(context)) {
          // Keep the elevation cue but skip the scale animation.
          return Material(
            color: Colors.transparent,
            elevation: liftElevation,
            child: child,
          );
        }
        return Transform.scale(
          scale: 1.0 + (liftScale - 1.0) * t,
          child: Material(
            color: Colors.transparent,
            elevation: liftElevation * t,
            child: child,
          ),
        );
      },
    );
  }

  Widget _wrapWithHandle(Widget item, int index) {
    assert(
      item.key != null,
      'Every item of MicroReorderableList must have a key.',
    );
    return KeyedSubtree(
      key: ValueKey<Key?>(item.key),
      child: Row(
        children: <Widget>[
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(Icons.drag_handle, semanticLabel: 'Drag to reorder'),
            ),
          ),
          Expanded(child: item),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReorderItemProxyDecorator decorator =
        proxyDecorator ?? _defaultProxyDecorator;
    final bool defaultHandles = showDragHandle
        ? false
        : buildDefaultDragHandles;

    if (itemBuilder != null) {
      return ReorderableListView.builder(
        itemCount: itemCount!,
        itemBuilder: (BuildContext context, int index) {
          final Widget item = itemBuilder!(context, index);
          return showDragHandle ? _wrapWithHandle(item, index) : item;
        },
        onReorderItem: _handleReorder,
        onReorderStart: onReorderStart,
        onReorderEnd: onReorderEnd,
        padding: padding,
        scrollController: scrollController,
        shrinkWrap: shrinkWrap,
        physics: physics,
        scrollDirection: scrollDirection,
        buildDefaultDragHandles: defaultHandles,
        proxyDecorator: decorator,
      );
    }

    return ReorderableListView(
      onReorderItem: _handleReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      padding: padding,
      scrollController: scrollController,
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      buildDefaultDragHandles: defaultHandles,
      proxyDecorator: decorator,
      children: <Widget>[
        for (int i = 0; i < children!.length; i++)
          if (showDragHandle)
            _wrapWithHandle(children![i], i)
          else
            children![i],
      ],
    );
  }
}
