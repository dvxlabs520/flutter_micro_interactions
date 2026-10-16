import 'package:flutter/material.dart';

import '../app.dart';
import '../catalog/registry.dart';
import '../shared/code_view.dart';
import '../shared/page_scaffold.dart';
import '../shared/playground.dart';
import '../shared/stage.dart';
import '../shared/ui.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The page of one component: the name as the headline, one sentence, the
/// stage with the playground beside it, the code, notes and the neighbors.
class ComponentPage extends StatefulWidget {
  const ComponentPage({super.key, required this.entry});

  final ComponentEntry entry;

  @override
  State<ComponentPage> createState() => _ComponentPageState();
}

class _ComponentPageState extends State<ComponentPage> {
  late Knobs _knobs = Knobs(widget.entry.knobs);
  int _replay = 0;
  Brightness? _stageBrightness;

  @override
  void didUpdateWidget(ComponentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _knobs.dispose();
      _knobs = Knobs(widget.entry.knobs);
      _replay = 0;
    }
  }

  @override
  void dispose() {
    _knobs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ComponentEntry entry = widget.entry;
    final Brightness stageBrightness =
        _stageBrightness ?? Theme.of(context).brightness;
    return PageScroll(
      builder: (context, width) {
        final bool wide = width >= Breakpoints.sidePanel;
        final bool hasKnobs = entry.knobs.isNotEmpty;
        final double stageHeight = wide
            ? entry.stageHeight + 40
            : entry.stageHeight.clamp(340, 540) + 32;

        final Widget stage = Stage(
          entry: entry,
          knobs: _knobs,
          brightness: stageBrightness,
          height: stageHeight,
          replay: _replay,
          onReplay: entry.replayable ? () => setState(() => _replay++) : null,
          onToggleBrightness: () => setState(() {
            _stageBrightness = stageBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark;
          }),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(entry: entry),
            SizedBox(height: wide ? 48 : 32),
            if (wide && hasKnobs)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stage),
                  const SizedBox(width: 40),
                  SizedBox(width: 280, child: Playground(knobs: _knobs)),
                ],
              )
            else ...[
              stage,
              if (hasKnobs) ...[
                const SizedBox(height: 20),
                CollapsiblePlayground(knobs: _knobs),
              ],
            ],
            SizedBox(height: wide ? 64 : 48),
            ListenableBuilder(
              listenable: _knobs,
              builder: (context, _) => CodeView(code: entry.code(_knobs)),
            ),
            if (entry.notes.isNotEmpty) ...[
              SizedBox(height: wide ? 64 : 48),
              _Notes(entry: entry),
            ],
            SizedBox(height: wide ? 96 : 64),
            _Neighbors(entry: entry, wide: wide),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final ComponentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.name.toUpperCase(), style: AppType.head(context)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(entry.summary, style: AppType.lead(context)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextLink(
              label: entry.category.name,
              onTap: () => openRoute(context, CategoryRoute(entry.category)),
              style: AppType.small(context),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            if (entry.isNew) Text(', new', style: AppType.small(context)),
          ],
        ),
      ],
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.entry});

  final ComponentEntry entry;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accessibility and motion', style: AppType.lead(context)),
          const SizedBox(height: 12),
          Text(entry.notes.join(' '), style: AppType.body(context)),
          if (entry.apis.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Classes: ${entry.apis.join(', ')}.',
              style: AppType.small(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Neighbors extends StatelessWidget {
  const _Neighbors({required this.entry, required this.wide});

  final ComponentEntry entry;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final ComponentEntry? prev = Catalog.previous(entry);
    final ComponentEntry? next = Catalog.next(entry);
    final TextStyle style = AppType.lead(context);
    Widget link(String label, ComponentEntry e) => TextLink(
      label: label,
      onTap: () => openRoute(context, ComponentRoute(e), replace: true),
      style: style,
      restColor: Palette.of(context).ink,
    );
    final List<Widget> links = [
      if (prev != null) link('Previous: ${prev.name}', prev),
      if (next != null) link('Next: ${next.name}', next),
    ];
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: links,
      );
    }
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: prev == null ? null : link('Previous: ${prev.name}', prev),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: next == null ? null : link('Next: ${next.name}', next),
          ),
        ),
      ],
    );
  }
}
