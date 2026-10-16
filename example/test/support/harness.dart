import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions_example/app.dart';
import 'package:flutter_micro_interactions_example/catalog/registry.dart';
import 'package:flutter_micro_interactions_example/pages/component_page.dart';
import 'package:flutter_micro_interactions_example/shared/preview_card.dart';
import 'package:flutter_micro_interactions_example/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Roboto from the Flutter SDK so text in tests has real metrics
/// instead of the square test glyphs, which makes overflow checks
/// meaningful. Call it from `setUpAll`.
Future<void> loadTestFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final Directory dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in ['Regular', 'Medium', 'Bold']) {
    final File file = File('${dir.path}/Roboto-$weight.ttf');
    if (file.existsSync()) {
      final List<int> bytes = file.readAsBytesSync();
      roboto.addFont(
        Future<ByteData>.value(ByteData.sublistView(Uint8List.fromList(bytes))),
      );
    }
  }
  await roboto.load();
}

/// Pumps frames for [total] in steps of [step]. Never uses pumpAndSettle,
/// because many demos animate forever.
Future<void> pumpFor(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 100),
}) async {
  Duration elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Sets the test surface to [size] logical pixels.
void setSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Hosts a single [ComponentPage] like the gallery does, without needing
/// the entry to be in the registry.
class EntryTestApp extends StatefulWidget {
  const EntryTestApp({super.key, required this.entry, this.dark = true});

  final ComponentEntry entry;
  final bool dark;

  @override
  State<EntryTestApp> createState() => _EntryTestAppState();
}

class _EntryTestAppState extends State<EntryTestApp> {
  late final ShowcaseController _controller = ShowcaseController(
    initialRoute: ComponentRoute(widget.entry),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.dark ? darkTheme : lightTheme,
      builder: (context, child) =>
          Showcase(controller: _controller, child: child!),
      home: Scaffold(body: ComponentPage(entry: widget.entry)),
    );
  }
}

/// Builds the detail page of every entry in [entries] at a desktop and a
/// phone size (dark and light), with its thumbnail, and pumps a few frames. Fails on any exception, including layout overflows.
void smokeTestEntries(List<ComponentEntry> entries) {
  for (final ComponentEntry entry in entries) {
    for (final (String label, Size size, bool dark) in const [
      ('desktop', Size(1440, 900), true),
      ('phone', Size(390, 844), false),
    ]) {
      testWidgets('${entry.id} page builds on $label', (tester) async {
        setSurface(tester, size);
        await tester.pumpWidget(EntryTestApp(entry: entry, dark: dark));
        await pumpFor(tester, const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        expect(find.text(entry.name.toUpperCase()), findsWidgets);

        // Thumbnail used by the gallery cards.
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? darkTheme : lightTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  height: 180,
                  child: EntryThumbnail(entry: entry),
                ),
              ),
            ),
          ),
        );
        await pumpFor(tester, const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);

        // Unmount so timers and tickers are disposed before the test ends.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}
