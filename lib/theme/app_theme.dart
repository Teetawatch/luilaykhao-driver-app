import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat, professional design system for the driver app.
///
/// Principles: solid colours only — no gradients, no drop shadows, no glow.
/// Cards are separated by a hairline border on a slightly tinted background.
class AppTheme {
  // ── Brand palette (modern slate + blue, no neon) ──────────────────────
  static const Color primaryColor = Color(0xFF1E293B); // slate-800
  static const Color accentColor = Color(0xFF2563EB); // blue-600
  static const Color successColor = Color(0xFF16A34A); // green-600
  static const Color warningColor = Color(0xFFD97706); // amber-600
  static const Color errorColor = Color(0xFFDC2626); // red-600

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF4F5F7); // page background
  static const Color surfaceLight = Colors.white; // cards
  static const Color subtleFill = Color(0xFFF1F3F5); // inset chips / fields

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textMain = Color(0xFF111827); // gray-900
  static const Color textSecondary = Color(0xFF6B7280); // gray-500
  static const Color textMuted = Color(0xFF9CA3AF); // gray-400

  // ── Lines ─────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB); // hairline
  static const Color borderStrong = Color(0xFFD1D5DB);

  // ── Radii ─────────────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Kept for backwards compatibility — intentionally empty so any remaining
  // `boxShadow:` sites render flat. Do not add shadows here.
  static const List<BoxShadow> softShadow = <BoxShadow>[];
  static const List<BoxShadow> activeShadow = <BoxShadow>[];

  /// Standard flat card surface: white with a hairline border, no shadow.
  /// Pass [selected] to highlight with the accent colour.
  static BoxDecoration cardDecoration({
    bool selected = false,
    double radius = radiusLarge,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? surfaceLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected ? accentColor : border,
        width: selected ? 1.5 : 1,
      ),
    );
  }

  /// Soft tinted pill/chip fill for status labels and icon backgrounds.
  static BoxDecoration chipDecoration(Color color, {double radius = 999}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light();
    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceLight,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bgLight,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.anuphanTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.anuphan(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: textMain,
        ),
        headlineMedium: GoogleFonts.anuphan(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textMain,
        ),
        titleLarge: GoogleFonts.anuphan(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textMain,
        ),
        bodyLarge: GoogleFonts.anuphan(fontSize: 16, color: textMain),
        bodyMedium: GoogleFonts.anuphan(fontSize: 14, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textMain),
        titleTextStyle: GoogleFonts.anuphan(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textMain,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.anuphan(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.anuphan(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.anuphan(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtleFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );
  }
}
