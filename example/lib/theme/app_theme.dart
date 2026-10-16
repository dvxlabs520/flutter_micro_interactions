import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Fonts of the showcase: Imbue for display lines (uppercase), Albert Sans
/// for everything else, JetBrains Mono inside code blocks only. Loaded with
/// google_fonts when [useGoogleFonts] is true (set in `main`); tests leave
/// it off so they never touch the network.
abstract final class AppFonts {
  static bool useGoogleFonts = false;

  static TextStyle display(TextStyle style) => useGoogleFonts
      ? GoogleFonts.imbue(textStyle: style)
      : style.copyWith(fontFamily: 'serif');

  static TextStyle text(TextStyle style) =>
      useGoogleFonts ? GoogleFonts.albertSans(textStyle: style) : style;

  static TextTheme textTheme(TextTheme base) =>
      useGoogleFonts ? GoogleFonts.albertSansTextTheme(base) : base;

  static TextStyle mono([TextStyle style = const TextStyle()]) {
    if (useGoogleFonts) return GoogleFonts.jetBrainsMono(textStyle: style);
    return style.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
    );
  }
}

/// The five type steps. A screen uses at most these five sizes: one very
/// large (the display), one small and little in between.
abstract final class AppType {
  static bool _phone(BuildContext c) =>
      MediaQuery.sizeOf(c).width < Breakpoints.phone;

  /// 13.5 to 14 px: captions, the index, categories.
  static TextStyle small(BuildContext c) => AppFonts.text(
    TextStyle(
      fontSize: _phone(c) ? 13.5 : 14,
      height: 1.45,
      color: Palette.of(c).muted,
    ),
  );

  /// 17 to 18 px: running text, at full contrast.
  static TextStyle body(BuildContext c) => AppFonts.text(
    TextStyle(
      fontSize: _phone(c) ? 17 : 18,
      height: 1.55,
      color: Palette.of(c).ink,
    ),
  );

  /// 20 to 24 px: the sentence under a headline, rows that lead.
  static TextStyle lead(BuildContext c) => AppFonts.text(
    TextStyle(
      fontSize: _phone(c) ? 20 : 24,
      height: 1.4,
      color: Palette.of(c).ink,
    ),
  );

  /// 40 to 96 px (6vw), Imbue: section and page headlines. Pass
  /// uppercase text of two lines at most.
  static TextStyle head(BuildContext c) {
    final double w = MediaQuery.sizeOf(c).width;
    return displayAt(c, (w * 0.06).clamp(40.0, 96.0));
  }

  /// Imbue at an explicit [size], for the hero and other poster lines.
  static TextStyle displayAt(BuildContext c, double size) => AppFonts.display(
    TextStyle(
      fontSize: size,
      height: 0.95,
      letterSpacing: -0.02 * size,
      fontWeight: FontWeight.w500,
      color: Palette.of(c).ink,
    ),
  );
}

/// Builds the Material theme for one [Palette].
ThemeData buildTheme(Palette p) {
  final bool dark = p.isDark;
  final Color cardOnStage = dark
      ? const Color(0xFF213038)
      : const Color(0xFFFAFCFC);
  final ColorScheme scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: dark ? const Color(0xFF113A40) : const Color(0xFFD3ECEE),
    onPrimaryContainer: dark
        ? const Color(0xFF9FDCE2)
        : const Color(0xFF0A4E56),
    secondary: p.ink,
    onSecondary: p.bg,
    secondaryContainer: p.surfaceStrong,
    onSecondaryContainer: p.ink,
    tertiary: dark ? const Color(0xFFE0A458) : const Color(0xFFB4651E),
    onTertiary: dark ? const Color(0xFF241505) : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF3A2A16) : const Color(0xFFF6E3CC),
    onTertiaryContainer: dark
        ? const Color(0xFFF2D3A8)
        : const Color(0xFF6B3A0E),
    error: dark ? const Color(0xFFF0857C) : const Color(0xFFB83A30),
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF41201D) : const Color(0xFFF7DEDB),
    onErrorContainer: dark ? const Color(0xFFF7C4BE) : const Color(0xFF7A1F18),
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceDim: p.surface,
    surfaceBright: cardOnStage,
    surfaceContainerLowest: dark ? const Color(0xFF0C1215) : Colors.white,
    surfaceContainerLow: p.bg,
    surfaceContainer: cardOnStage,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.surfaceStrong,
    outline: dark ? const Color(0xFF4A5A61) : const Color(0xFF9AA8AE),
    outlineVariant: dark ? const Color(0xFF2A3A41) : const Color(0xFFD5DDE1),
    shadow: const Color(0xFF0B1418),
    scrim: Colors.black,
    inverseSurface: p.ink,
    onInverseSurface: p.bg,
    inversePrimary: p.accent,
  );

  final TextTheme base = const TextTheme(
    displayLarge: TextStyle(fontSize: 56, height: 1.0),
    displayMedium: TextStyle(fontSize: 44, height: 1.05),
    displaySmall: TextStyle(fontSize: 36, height: 1.1),
    headlineLarge: TextStyle(fontSize: 32, height: 1.15),
    headlineMedium: TextStyle(fontSize: 26, height: 1.2),
    headlineSmall: TextStyle(fontSize: 22, height: 1.25),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    titleSmall: TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.55),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5),
    bodySmall: TextStyle(fontSize: 13.5, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  ).apply(bodyColor: p.ink, displayColor: p.ink);

  final TextTheme textTheme = AppFonts.textTheme(base);
  const OutlinedBorder shape = RoundedRectangleBorder(borderRadius: kCorners);
  const Size buttonSize = Size(0, 44);
  final TextStyle? buttonText = textTheme.labelLarge;

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: textTheme,
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    hoverColor: p.surfaceStrong.withValues(alpha: 0.6),
    highlightColor: Colors.transparent,
    focusColor: p.surfaceStrong,
    dividerTheme: const DividerThemeData(
      color: Colors.transparent,
      thickness: 0,
      space: 0,
    ),
    iconTheme: IconThemeData(color: p.ink, size: 20),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      elevation: 0,
      width: 300,
    ),
    cardTheme: CardThemeData(
      color: cardOnStage,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      textColor: p.ink,
      tileColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: buttonSize,
        shape: shape,
        textStyle: buttonText,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.surfaceStrong,
        foregroundColor: p.ink,
        elevation: 0,
        minimumSize: buttonSize,
        shape: shape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surfaceStrong,
        minimumSize: buttonSize,
        shape: shape,
        side: BorderSide.none,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 40),
        shape: shape,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.ink, shape: shape),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.muted,
        selectedBackgroundColor: p.ink,
        selectedForegroundColor: p.bg,
        side: BorderSide.none,
        shape: shape,
        textStyle: textTheme.labelMedium,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.ink,
      side: BorderSide.none,
      labelStyle: textTheme.labelMedium?.copyWith(color: p.ink),
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
      showCheckmark: false,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.ink,
      inactiveTrackColor: p.surfaceStrong,
      thumbColor: p.ink,
      overlayColor: p.ink.withValues(alpha: 0.08),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.bg : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.ink : p.surfaceStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
      side: BorderSide(color: p.muted, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.bg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      border: const OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: p.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: kCorners),
      textStyle: textTheme.labelMedium?.copyWith(color: p.bg),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.muted.withValues(alpha: 0.4)),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(kRadius),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bg),
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: kCorners),
    ),
  );
}

final ThemeData darkTheme = buildTheme(Palette.dark);
final ThemeData lightTheme = buildTheme(Palette.light);
