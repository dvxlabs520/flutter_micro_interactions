import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The package version shown in the chrome.
const String packageVersion = '0.3.0';

/// The command that adds the package.
const String installCommand = 'flutter pub add flutter_micro_interactions';

/// The wordmark: the package name in Imbue capitals.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'MICRO INTERACTIONS',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: AppType.displayAt(context, size).copyWith(height: 1),
    );
  }
}

/// A plain text link: muted at rest, ink on hover, focus or when
/// [selected].
class TextLink extends StatefulWidget {
  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.style,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.restColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;

  /// Color at rest; defaults to the muted ink.
  final Color? restColor;

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool strong = widget.selected || _hovered || _focused;
    final TextStyle base = widget.style ?? AppType.body(context);
    final Color rest = widget.restColor ?? p.muted;
    // Ink links dim on hover; muted links come up to ink.
    final Color active = rest == p.ink ? p.muted : p.ink;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: FocusableActionDetector(
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: widget.padding,
            child: AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: base.copyWith(color: strong ? active : rest),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat field that deepens one tone step on hover and focus, and gives
/// a small press. The shared row of tables and lists.
class ToneButton extends StatefulWidget {
  const ToneButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.hoverColor,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? hoverColor;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  State<ToneButton> createState() => _ToneButtonState();
}

class _ToneButtonState extends State<ToneButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool on = _hovered || _focused;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: TapFeedback(
          scaleDown: 0.99,
          enableHaptics: false,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: on
                  ? (widget.hoverColor ?? p.surface)
                  : (widget.color ?? p.bg.withValues(alpha: 0)),
              borderRadius: kCorners,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The plain lowercase "new" that follows the name of a new component.
class NewMark extends StatelessWidget {
  const NewMark({super.key});

  @override
  Widget build(BuildContext context) =>
      Text('new', style: AppType.small(context));
}

/// The section entrance used across the site: a short rise and fade, with
/// [order] staggering the parts of one section by 70 ms.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.order = 0});

  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    return RevealOnScroll(
      distance: 24,
      threshold: 0.05,
      duration: const Duration(milliseconds: 650),
      delay: Duration(milliseconds: 70 * order),
      child: child,
    );
  }
}
