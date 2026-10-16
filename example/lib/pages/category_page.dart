import 'package:flutter/material.dart';

import '../catalog/registry.dart';
import '../shared/component_table.dart';
import '../shared/page_scaffold.dart';
import '../shared/ui.dart';
import '../theme/tokens.dart';

/// All components of one category, as a statement with the table pushed
/// right.
class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final List<ComponentEntry> entries = Catalog.entriesIn(category);
    return PageScroll(
      top: 64,
      builder: (context, width) => Reveal(
        child: StatementTable(
          width: width,
          headline: category.name.length > 14
              ? category.name.toUpperCase().replaceFirst(' & ', '\n& ')
              : category.name.toUpperCase(),
          intro: category.description,
          naming: entries.length == 1
              ? 'One widget'
              : '${entries.length} widgets',
          table: ComponentTable(
            entries: entries,
            stacked: width < Breakpoints.phone,
          ),
        ),
      ),
    );
  }
}

/// Every component, grouped by category in one long table.
class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ComponentEntry> entries = Catalog.ordered;
    return PageScroll(
      top: 64,
      builder: (context, width) => Reveal(
        child: StatementTable(
          width: width,
          headline: 'EVERY WIDGET,\nONE IMPORT',
          intro:
              '${entries.length} components in ${Categories.components.length} '
              'groups. Each one is a single widget you wrap around your own.',
          naming: 'Index',
          table: ComponentTable(
            entries: entries,
            kindOf: (e) => e.category.name,
            stacked: width < Breakpoints.phone,
          ),
        ),
      ),
    );
  }
}
