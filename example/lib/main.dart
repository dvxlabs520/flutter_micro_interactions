import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import 'app.dart';
import 'theme/app_theme.dart';

void main() {
  // Geist and Geist Mono, fetched once by google_fonts. Tests skip this.
  AppFonts.useGoogleFonts = true;
  // On the web the initial route comes from the URL fragment, for example
  // `#/components/border-beam`.
  final String initialPath = WidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .defaultRouteName;
  // Load the MorphSlider shader early, so its first transition is smooth.
  MorphSlider.precacheShader();
  runApp(ShowcaseApp(initialPath: initialPath));
}
