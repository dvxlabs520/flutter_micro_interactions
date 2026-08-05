import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Shows a context menu when the [child] is long pressed.
///
/// The menu opens at the press position. Selecting an item fires
/// [LongPressMenuItem.onTap] and, when provided, [onSelected].
///
/// ```dart
/// LongPressMenu(
///   menuItems: [
///     LongPressMenuItem.copy(onTap: copyText),
///     LongPressMenuItem.delete(onTap: deleteText),
///   ],
///   child: const ListTile(title: Text('Long press me')),
/// )
/// ```
///
/// Every enabled item is also exposed as a [CustomSemanticsAction], so
/// assistive technology can trigger it without performing the gesture.
class LongPressMenu extends StatelessWidget {
  /// Creates a long press menu wrapper.
  ///
  /// [menuItems] must not be empty.
  const LongPressMenu({
    super.key,
    required this.child,
    required this.menuItems,
    this.onSelected,
    this.enableHaptics = true,
    this.enabled = true,
    this.menuBackgroundColor,
    this.menuElevation = 8.0,
    this.menuBorderRadius = 8.0,
    this.textStyle,
    this.iconColor,
  })  : assert(menuElevation >= 0.0, 'menuElevation must be non-negative'),
        assert(menuBorderRadius >= 0.0,
            'menuBorderRadius must be non-negative');

  /// The widget that reacts to the long press.
  final Widget child;

  /// The items shown in the menu.
  final List<LongPressMenuItem> menuItems;

  /// Called with the selected item after the menu closes, in addition to the
  /// item's own [LongPressMenuItem.onTap].
  final ValueChanged<LongPressMenuItem>? onSelected;

  /// Whether a medium impact haptic fires when the menu opens.
  /// Defaults to `true`.
  final bool enableHaptics;

  /// When `false` the child renders normally and no gesture is attached.
  final bool enabled;

  /// Background color of the menu. `null` uses the theme default.
  final Color? menuBackgroundColor;

  /// Elevation of the menu. Defaults to `8.0`.
  final double menuElevation;

  /// Corner radius of the menu. Defaults to `8.0`.
  final double menuBorderRadius;

  /// Text style for item labels. Destructive items are recolored with
  /// [ColorScheme.error].
  final TextStyle? textStyle;

  /// Color for item icons. Destructive items use [ColorScheme.error].
  final Color? iconColor;

  void _select(LongPressMenuItem item) {
    item.onTap?.call();
    onSelected?.call(item);
  }

  Future<void> _showContextMenu(
      BuildContext context, Offset globalPosition) async {
    if (enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RenderBox overlay = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject()! as RenderBox;
    final Offset localPosition = overlay.globalToLocal(globalPosition);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(localPosition, localPosition),
      Offset.zero & overlay.size,
    );

    final LongPressMenuItem? selected = await showMenu<LongPressMenuItem>(
      context: context,
      position: position,
      elevation: menuElevation,
      color: menuBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuBorderRadius),
      ),
      items: <PopupMenuEntry<LongPressMenuItem>>[
        for (final LongPressMenuItem item in menuItems)
          PopupMenuItem<LongPressMenuItem>(
            value: item,
            enabled: item.enabled,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 20.0,
                  color: item.destructive ? scheme.error : iconColor,
                ),
                const SizedBox(width: 12.0),
                Text(
                  item.label,
                  style: item.destructive
                      ? (textStyle ?? const TextStyle())
                          .copyWith(color: scheme.error)
                      : textStyle,
                ),
              ],
            ),
          ),
      ],
    );
    if (selected != null) {
      _select(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (final LongPressMenuItem item in menuItems)
          if (item.enabled && item.onTap != null)
            CustomSemanticsAction(label: item.label): () => _select(item),
      },
      child: GestureDetector(
        onLongPressStart: (LongPressStartDetails details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: child,
      ),
    );
  }
}

/// One entry of a [LongPressMenu].
///
/// ```dart
/// LongPressMenuItem(
///   icon: Icons.copy,
///   label: 'Copy',
///   onTap: copyText,
/// )
/// ```
class LongPressMenuItem {
  /// Creates a menu item.
  const LongPressMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  /// The icon shown next to the label.
  final IconData icon;

  /// The text of the item. Also used as the label of the item's
  /// [CustomSemanticsAction].
  final String label;

  /// Called when the item is selected.
  final VoidCallback? onTap;

  /// Whether the item can be selected. Defaults to `true`.
  final bool enabled;

  /// Whether the item is styled as destructive with [ColorScheme.error].
  /// Defaults to `false`.
  final bool destructive;

  /// A standard "Copy" item.
  static LongPressMenuItem copy({VoidCallback? onTap}) {
    return LongPressMenuItem(icon: Icons.copy, label: 'Copy', onTap: onTap);
  }

  /// A standard "Share" item.
  static LongPressMenuItem share({VoidCallback? onTap}) {
    return LongPressMenuItem(icon: Icons.share, label: 'Share', onTap: onTap);
  }

  /// A standard destructive "Delete" item.
  static LongPressMenuItem delete({VoidCallback? onTap}) {
    return LongPressMenuItem(
      icon: Icons.delete,
      label: 'Delete',
      onTap: onTap,
      destructive: true,
    );
  }

  /// A standard "Edit" item.
  static LongPressMenuItem edit({VoidCallback? onTap}) {
    return LongPressMenuItem(icon: Icons.edit, label: 'Edit', onTap: onTap);
  }

  /// A standard "Favorite" item.
  static LongPressMenuItem favorite({VoidCallback? onTap}) {
    return LongPressMenuItem(
      icon: Icons.favorite,
      label: 'Favorite',
      onTap: onTap,
    );
  }
}
