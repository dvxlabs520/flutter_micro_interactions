import 'package:flutter/material.dart';

import 'knobs.dart';

export 'knobs.dart';

/// A group of components shown together in the sidebar and on the home page.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  final String id;
  final String name;
  final IconData icon;
  final String description;

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Small labels shown next to a component name.
enum ComponentTag {
  newly('New'),
  ai('AI'),
  pointer('Pointer'),
  gesture('Gesture');

  const ComponentTag(this.label);

  final String label;
}

/// Builds the live demo of a component from the current playground values.
typedef DemoBuilder = Widget Function(BuildContext context, Knobs knobs);

/// Builds the code snippet of a component from the current playground
/// values.
typedef CodeBuilder = String Function(Knobs knobs);

/// How the demo is laid out on the stage.
enum StageLayout {
  /// Centered, with generous padding. The default.
  center,

  /// Fills the stage, for lists and scrollables (usually inside a
  /// `PhoneFrame`).
  fill,
}

/// One page of the gallery: a widget family with its live demo,
/// playground controls, code snippet and notes.
///
/// Add a new component by creating `lib/demos/<category>/<name>.dart` with a
/// top-level `final ComponentEntry fooEntry = ComponentEntry(...)` and adding
/// `fooEntry` to `registry` in `lib/catalog/registry.dart`.
@immutable
class ComponentEntry {
  const ComponentEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.preview,
    required this.code,
    this.apis = const [],
    this.tags = const [],
    this.knobs = const [],
    this.thumbnail,
    this.notes = const [],
    this.replayable = false,
    this.stageHeight = 420,
    this.layout = StageLayout.center,
  });

  /// Stable, url friendly id, for example `border-beam`.
  final String id;

  /// Human readable name, for example `Border Beam`.
  final String name;

  final Category category;

  /// One or two sentences that say what the component is for.
  final String summary;

  /// Public classes covered by this entry, for example
  /// `['BorderBeam', 'BorderBeamStyle']`. Shown on the page and searched.
  final List<String> apis;

  final List<ComponentTag> tags;

  /// Playground controls. Their values are passed to [preview] and [code].
  final List<Knob<Object?>> knobs;

  /// The live demo shown on the stage.
  final DemoBuilder preview;

  /// A small preview for the gallery cards. Falls back to a scaled down
  /// [preview] with default values.
  final WidgetBuilder? thumbnail;

  /// The code snippet, reflecting the playground values.
  final CodeBuilder code;

  /// Accessibility and reduced motion notes.
  final List<String> notes;

  /// Shows a Replay button that remounts the demo.
  final bool replayable;

  /// Height of the stage on wide screens.
  final double stageHeight;

  final StageLayout layout;

  bool get isNew => tags.contains(ComponentTag.newly);

  /// Lower case text matched by the search field.
  String get searchText => [
    name,
    summary,
    category.name,
    ...apis,
    for (final ComponentTag tag in tags) tag.label,
  ].join(' ').toLowerCase();
}
