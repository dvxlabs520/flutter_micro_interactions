import 'package:flutter/material.dart';

import '../catalog/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// The flat field that hosts a live demo. It applies its own light or dark
/// theme, so the stage toggle works independently of the app theme. Replay
/// and the light and dark switch sit at its bottom left as plain text.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.entry,
    required this.knobs,
    required this.brightness,
    required this.onToggleBrightness,
    this.onReplay,
    this.replay = 0,
    this.height,
  });

  final ComponentEntry entry;
  final Knobs knobs;
  final Brightness brightness;
  final VoidCallback onToggleBrightness;

  /// Shown as a Replay link when not null.
  final VoidCallback? onReplay;

  /// Bumped to remount the demo.
  final int replay;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = brightness == Brightness.dark
        ? darkTheme
        : lightTheme;
    final Palette sp = theme.extension<Palette>()!;
    return Theme(
      data: theme,
      child: AnimatedContainer(
        duration: Motion.medium,
        height: height ?? entry.stageHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: sp.surface, borderRadius: kCorners),
        child: Column(
          children: [
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: ListenableBuilder(
                  listenable: knobs,
                  builder: (context, _) => KeyedSubtree(
                    key: ValueKey('${entry.id}-$replay'),
                    child: StageBody(
                      layout: entry.layout,
                      child: entry.preview(context, knobs),
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    if (onReplay != null) ...[
                      TextLink(
                        label: 'Replay',
                        onTap: onReplay,
                        style: AppType.small(context),
                      ),
                      const SizedBox(width: 20),
                    ],
                    TextLink(
                      label: brightness == Brightness.dark
                          ? 'Light stage'
                          : 'Dark stage',
                      onTap: onToggleBrightness,
                      style: AppType.small(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays a demo out on the stage: centered with padding, scrolling when it
/// is taller than the stage, or filling it.
class StageBody extends StatelessWidget {
  const StageBody({super.key, required this.layout, required this.child});

  final StageLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (layout == StageLayout.fill) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
