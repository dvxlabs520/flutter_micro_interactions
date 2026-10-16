import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions_example/app.dart';
import 'package:flutter_micro_interactions_example/catalog/registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('home renders on desktop', (tester) async {
    setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(const ShowcaseApp());
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('MICRO INTERACTIONS'), findsWidgets);
    expect(find.text('TINY MOTION,'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('home renders on a phone', (tester) async {
    setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(const ShowcaseApp());
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('TINY MOTION,'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search filters the component index', (tester) async {
    setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(const ShowcaseApp(initialPath: '/components'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, 'beam');
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('match'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('index and get started pages build', (tester) async {
    for (final Size size in const [Size(1440, 900), Size(390, 844)]) {
      setSurface(tester, size);
      for (final String path in const ['/components', '/get-started']) {
        await tester.pumpWidget(ShowcaseApp(initialPath: path));
        await pumpFor(tester, const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
  });

  testWidgets('every category page builds', (tester) async {
    setSurface(tester, const Size(1440, 900));
    for (final Category c in Categories.components) {
      await tester.pumpWidget(ShowcaseApp(initialPath: '/category/${c.id}'));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('deep link opens a component page', (tester) async {
    setSurface(tester, const Size(1440, 900));
    final ComponentEntry first = Catalog.ordered.first;
    await tester.pumpWidget(
      ShowcaseApp(initialPath: '/components/${first.id}'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Playground'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  group('component pages', () {
    smokeTestEntries(registry);
  });
}
