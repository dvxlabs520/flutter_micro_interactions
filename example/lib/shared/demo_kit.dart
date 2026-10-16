import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

/// Building blocks shared by the demos, so every stage uses the same sample
/// surfaces, spacing and copy style. They read colors from the stage theme,
/// so they follow the stage light and dark toggle.

/// Swatches offered by color knobs. `null` means the widget's default.
const List<Color?> demoSwatches = [
  null,
  Color(0xFF0D7480),
  Color(0xFF2D5F75),
  Color(0xFF52702E),
  Color(0xFFB4651E),
  Color(0xFFB83A30),
];

/// A neutral card used as the child of border and pointer effects.
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.radius = 10,
    this.color,
    this.showBorder = false,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: child,
    );
  }
}

/// A title and a muted line, the usual content of a sample card.
class DemoCardText extends StatelessWidget {
  const DemoCardText({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String title;
  final String? body;
  final IconData? icon;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (icon != null) ...[
          IconBadge(icon: icon!),
          const SizedBox(height: 16),
        ],
        Text(title, style: theme.textTheme.titleMedium),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            textAlign: crossAxisAlignment == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A rounded square holding an icon, tinted with the accent.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 36, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color c = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// A small muted caption under a demo, for example "Tap the icon".
class DemoCaption extends StatelessWidget {
  const DemoCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A circle with initials, for chat and list demos.
class DemoAvatar extends StatelessWidget {
  const DemoAvatar(this.initials, {super.key, this.color, this.size = 36});

  final String initials;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.18),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: c,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A phone sized frame for list and scroll demos. It fills the available
/// height and clips its content to rounded corners.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.width = 380,
    this.title,
    this.trailing,
  });

  final Widget child;
  final double width;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (title != null)
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title!, style: theme.textTheme.titleMedium),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list row with an avatar, a title and a subtitle.
class DemoListRow extends StatelessWidget {
  const DemoListRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.initials,
    this.color,
    this.trailing,
    this.background,
  });

  final String title;
  final String subtitle;
  final String? initials;
  final Color? color;
  final Widget? trailing;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          DemoAvatar(initials ?? title.substring(0, 1), color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Colors used for sample avatars.
const List<Color> demoAccents = [
  Color(0xFF0D7480),
  Color(0xFF2D5F75),
  Color(0xFFB4651E),
  Color(0xFF52702E),
  Color(0xFFB83A30),
  Color(0xFF5D6B72),
];

/// Shows a short confirmation using the package's own toast.
void demoToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  ToastNotification.show(
    context: context,
    message: message,
    type: type,
    position: ToastPosition.bottom,
    duration: const Duration(seconds: 2),
    borderRadius: const BorderRadius.all(Radius.circular(4)),
  );
}

/// Vertical gap helper used inside demo columns.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
