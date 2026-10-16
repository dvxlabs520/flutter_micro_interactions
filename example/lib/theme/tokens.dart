import 'package:flutter/material.dart';

/// Colors of the showcase: "Frost and slate". A cool white ground, one paler
/// blue-grey surface step, slate ink and a single teal accent that appears
/// at most once per screen, on the primary action.
///
/// Surfaces are separated by tone steps, never by lines or shadows.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceStrong,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
  });

  final Brightness brightness;

  /// The ground of every page.
  final Color bg;

  /// Panels, the stage, fields and the component index.
  final Color surface;

  /// One step deeper than [surface]: hover and pressed states, the selected
  /// option of a control.
  final Color surfaceStrong;

  /// Running text and headlines, at full contrast.
  final Color ink;

  /// Secondary text: categories, captions, hints.
  final Color muted;

  /// Teal. The primary action only.
  final Color accent;

  /// Text on [accent].
  final Color onAccent;

  bool get isDark => brightness == Brightness.dark;

  static const Palette light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF7F9FA),
    surface: Color(0xFFECF0F2),
    surfaceStrong: Color(0xFFDDE4E8),
    ink: Color(0xFF1F3038),
    muted: Color(0xFF5D6B72),
    accent: Color(0xFF0D7480),
    onAccent: Color(0xFFFFFFFF),
  );

  static const Palette dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF10181C),
    surface: Color(0xFF18242A),
    surfaceStrong: Color(0xFF223138),
    ink: Color(0xFFE8EEF0),
    muted: Color(0xFF9AA8AE),
    accent: Color(0xFF2BA3AF),
    onAccent: Color(0xFF071417),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceStrong: l(surfaceStrong, other.surfaceStrong),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
    );
  }
}

/// The one corner radius of the whole app: square, 4 px. Buttons, the
/// stage, fields, frames.
const double kRadius = 4;
const BorderRadius kCorners = BorderRadius.all(Radius.circular(kRadius));

/// The 8 px spacing grid.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
}

/// Breakpoints of the responsive shell.
abstract final class Breakpoints {
  /// From this width the component index is a permanent column.
  static const double sidebar = 1000;

  /// From this content width the playground sits beside the stage.
  static const double sidePanel = 860;

  /// Below this width the phone layouts apply.
  static const double phone = 640;
}

/// Page margins: one pair for the whole app.
double pageMargin(double width) => width < Breakpoints.phone ? 16 : 32;

/// Shared motion values for the chrome.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 240);
  static const Curve curve = Curves.easeOutCubic;
}
