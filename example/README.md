# Micro Interactions gallery

The example app of `flutter_micro_interactions`: a component gallery with a
live stage, a playground and a copyable code snippet for every widget. It runs
on web, desktop and mobile.

```sh
cd example
flutter run -d chrome      # or macos, windows, linux, ios, android
flutter build web --release
```

On the web every page has its own address, for example
`/#/components/border-beam` or `/#/category/ai`.

## Structure

```
lib/
  main.dart                 entry point (Imbue, Albert Sans and JetBrains Mono
                            via google_fonts; precaches the MorphSlider shader)
  app.dart                  ShowcaseApp, routes, ShowcaseController, openRoute
  catalog/
    models.dart             ComponentEntry, Category, ComponentTag, StageLayout
    knobs.dart              playground knobs, Knobs values, snippet helpers
    categories.dart         every category, in display order
    registry.dart           the list of entries, lookup and search
    timings.dart            default timing per entry, for the tables
  demos/<category>/*.dart   one file per component family
  pages/                    home, component, category, index, get started
  shell/                    site bar, component index, phone bar, search
  shared/                   stage, playground, code view, component table,
                            demo kit, procedural images, links
  theme/                    design tokens ("frost and slate") and ThemeData
test/
  widget_test.dart          smoke tests: home, search, every page and every
                            registry entry at desktop and phone sizes
  support/harness.dart      test helpers (real fonts, EntryTestApp)
```

The visual system: a cool white ground with one paler surface step, slate
ink and a single teal accent used once per screen on the primary action.
Surfaces are separated by tone, never by lines or shadows; every corner is
4 px. Display lines are Imbue capitals, text is Albert Sans, and monospace
appears only inside code blocks.

For reviewing long pages on the web, `?y=<offset>` opens a page scrolled
(for example `/#/?y=2400`) and `?still=1` turns animations off.

## Adding a component

1. Create `lib/demos/<category>/<name>.dart` with one top-level entry:

   ```dart
   final ComponentEntry fooEntry = ComponentEntry(
     id: 'foo',                       // used in the URL
     name: 'Foo',                     // shown in the sidebar and on cards
     category: Categories.borders,
     summary: 'One or two sentences on what it does and when to use it.',
     apis: const ['Foo', 'FooController'],
     tags: const [ComponentTag.newly],
     knobs: [
       const SliderKnob(id: 'speed', label: 'Speed', min: 0.5, max: 2,
           initial: 1),
       const ToggleKnob(id: 'active', label: 'Active', initial: true),
     ],
     preview: (context, knobs) => Foo(
       speed: knobs.number('speed'),
       active: knobs.flag('active'),
       child: const DemoCard(child: Text('Hello')),
     ),
     thumbnail: (context) => const Foo(child: DemoCard(child: Text('Hi'))),
     code: (knobs) => dartCall('Foo', {
       'speed': knobs.arg('speed'),     // left out while at its default
       'active': knobs.arg('active'),
       'child': 'const MyCard()',
     }),
     notes: const ['What screen readers get and what reduced motion does.'],
   );
   ```

2. Import the file in `lib/catalog/registry.dart` and add `fooEntry` to
   `registry` where it should appear in its category. Add its default timing
   to `lib/catalog/timings.dart` for the component tables.

That is all: the component index, search, the home index table, the category
page, previous and next links and the smoke tests pick it up. `lib/demos/ai/border_beam.dart` is a
complete reference.

Guidelines:

- Read colors and text styles from `Theme.of(context)`. The stage has its own
  light and dark toggle, so hard coded colors break one of the two. Prefer
  tone steps (`surfaceContainer` on the stage) to outlines and shadows.
- Demos must fit a 340 px wide phone stage. Use `StageLayout.fill` with
  `PhoneFrame` for lists and scroll views.
- Keep `initial` of a knob equal to the widget default, so the snippet only
  shows what was changed.
- Never download or bundle images; use `GeneratedImage` from
  `lib/shared/generated_images.dart`.
- Run `flutter analyze` and `flutter test` in `example/`. The smoke test opens
  every entry at desktop and phone sizes and fails on any exception, layout
  overflows included.
