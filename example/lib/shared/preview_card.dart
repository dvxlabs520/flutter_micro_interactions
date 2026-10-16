import 'package:flutter/material.dart';

import '../catalog/models.dart';
import 'stage.dart';

/// The small live preview of an entry: its [ComponentEntry.thumbnail], or
/// its demo with default values scaled down to fit. Not interactive and
/// hidden from screen readers, so it can sit inside a link.
class EntryThumbnail extends StatefulWidget {
  const EntryThumbnail({super.key, required this.entry});

  final ComponentEntry entry;

  @override
  State<EntryThumbnail> createState() => _EntryThumbnailState();
}

class _EntryThumbnailState extends State<EntryThumbnail> {
  Knobs? _knobs;

  @override
  void dispose() {
    _knobs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ComponentEntry entry = widget.entry;
    Widget child;
    if (entry.thumbnail != null) {
      child = Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Builder(builder: entry.thumbnail!),
          ),
        ),
      );
    } else {
      final Knobs knobs = _knobs ??= Knobs(entry.knobs);
      child = Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 520,
            height: 320,
            child: StageBody(
              layout: entry.layout,
              child: entry.preview(context, knobs),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
