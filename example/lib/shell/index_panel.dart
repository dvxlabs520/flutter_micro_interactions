import 'package:flutter/material.dart';

import '../app.dart';
import '../catalog/registry.dart';
import '../shared/ui.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The component index: a plain text list on the surface tone. Category
/// names in the small step, components at reading size, the current one in
/// ink. Filtered by the bar's search field.
class IndexPanel extends StatelessWidget {
  const IndexPanel({super.key, this.inDrawer = false});

  /// Closes the drawer before navigating.
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final ShowcaseController controller = Showcase.of(context);
    final Palette p = Palette.of(context);
    final AppRoute route = controller.route;
    final String query = inDrawer ? '' : controller.query;

    void open(AppRoute r) {
      if (inDrawer) Navigator.of(context).pop();
      openRoute(context, r);
    }

    final TextStyle item = AppFonts.text(
      TextStyle(fontSize: 15.5, height: 1.35, color: p.muted),
    );
    final List<Widget> children = [];

    Widget entryLink(ComponentEntry e, {String? trailing}) {
      final bool current =
          !inDrawer && route is ComponentRoute && route.entry.id == e.id;
      return TextLink(
        label: trailing == null ? e.name : '${e.name}  $trailing',
        selected: current,
        onTap: () => open(ComponentRoute(e)),
        style: item.copyWith(
          fontWeight: current ? FontWeight.w500 : FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(vertical: 5),
      );
    }

    if (query.isNotEmpty) {
      final List<ComponentEntry> hits = Catalog.search(query);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            hits.isEmpty
                ? 'Nothing matches "$query" yet.'
                : hits.length == 1
                ? 'One match'
                : '${hits.length} matches',
            style: AppType.small(context),
          ),
        ),
      );
      for (final ComponentEntry e in hits) {
        children.add(entryLink(e));
      }
    } else {
      children.add(
        TextLink(
          label: 'All components',
          selected: !inDrawer && route is IndexRoute,
          onTap: () => open(const IndexRoute()),
          style: item,
          padding: const EdgeInsets.symmetric(vertical: 5),
        ),
      );
      children.add(
        TextLink(
          label: 'Get started',
          selected: !inDrawer && route is GetStartedRoute,
          onTap: () => open(const GetStartedRoute()),
          style: item,
          padding: const EdgeInsets.symmetric(vertical: 5),
        ),
      );
      for (final Category c in Categories.components) {
        final List<ComponentEntry> entries = Catalog.entriesIn(c);
        if (entries.isEmpty) continue;
        children.add(const SizedBox(height: 28));
        children.add(
          TextLink(
            label: c.name,
            selected:
                !inDrawer && route is CategoryRoute && route.category == c,
            onTap: () => open(CategoryRoute(c)),
            style: AppType.small(context),
            padding: const EdgeInsets.only(bottom: 6),
          ),
        );
        for (final ComponentEntry e in entries) {
          children.add(entryLink(e));
        }
      }
    }

    return Container(
      color: p.surface,
      child: ListView(
        padding: EdgeInsets.fromLTRB(32, inDrawer ? 24 : 32, 24, 48),
        children: children,
      ),
    );
  }
}
