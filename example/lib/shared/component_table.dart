import 'package:flutter/material.dart';

import '../app.dart';
import '../catalog/models.dart';
import '../catalog/timings.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// A plain table of components: the kind in muted ink, the name, the
/// default timing right aligned with a small arrow. Rows are separated by
/// space only, with extra space every fourth row. Each row opens the
/// component page.
class ComponentTable extends StatelessWidget {
  const ComponentTable({
    super.key,
    required this.entries,
    this.kindOf,
    this.stacked = false,
  });

  final List<ComponentEntry> entries;

  /// The muted first column; defaults to the main class name.
  final String Function(ComponentEntry entry)? kindOf;

  /// Phone layout: the kind sits above the name.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final TextStyle name = AppFonts.text(
      TextStyle(fontSize: 16.5, height: 1.4, color: p.ink),
    );
    final TextStyle muted = name.copyWith(color: p.muted);
    String kind(ComponentEntry e) =>
        kindOf?.call(e) ?? (e.apis.isNotEmpty ? e.apis.first : '');

    final List<Widget> rows = [];
    for (int i = 0; i < entries.length; i++) {
      final ComponentEntry e = entries[i];
      final Widget nameText = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: e.name),
            if (e.isNew) TextSpan(text: '  new', style: AppType.small(context)),
          ],
        ),
        style: name,
      );
      final Widget value = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timingOf(e.id), style: muted),
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward, size: 16, color: p.ink),
        ],
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i > 0 && i % 4 == 0 ? 20 : 2),
          child: ToneButton(
            semanticLabel: 'Open ${e.name}',
            onTap: () => openRoute(context, ComponentRoute(e)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: stacked
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind(e), style: AppType.small(context)),
                            nameText,
                          ],
                        ),
                      ),
                      value,
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, c) => Row(
                      children: [
                        SizedBox(
                          width: c.maxWidth * 0.34,
                          child: Text(
                            kind(e),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                        Expanded(child: nameText),
                        value,
                      ],
                    ),
                  ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// "Statement, table pushed right": a headline of a few words on the left
/// over the full width, and below it the table in the right five of
/// twelve columns, with one plain naming word hanging in column seven.
class StatementTable extends StatelessWidget {
  const StatementTable({
    super.key,
    required this.headline,
    required this.table,
    this.naming,
    this.intro,
    this.under,
    this.width,
  });

  /// Two lines at most, uppercase.
  final String headline;
  final Widget table;
  final String? naming;

  /// Optional sentence under the headline at lead size.
  final String? intro;

  /// Optional widget under the table, for example a link.
  final Widget? under;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = width ?? constraints.maxWidth;
        final bool phone = w < Breakpoints.phone + 120;
        final double vw = MediaQuery.sizeOf(context).width / 100;
        final TextStyle head = AppType.displayAt(
          context,
          phone ? (9.5 * vw).clamp(34, 60) : (4.5 * vw).clamp(40, 68),
        ).copyWith(height: 0.98);
        final List<String> lines = headline.split('\n');
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < lines.length; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 && !phone ? 3 * vw : 0),
                child: Text(lines[i], style: head),
              ),
            if (intro != null) ...[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(intro!, style: AppType.lead(context)),
              ),
            ],
          ],
        );
        if (phone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 40), table, ?under],
          );
        }
        final double col = (w + 24) / 12;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 96),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: col * 6),
                SizedBox(
                  width: col - 24,
                  child: naming == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(naming!, style: AppType.small(context)),
                        ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [table, ?under],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
