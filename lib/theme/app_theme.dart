import 'package:flutter/material.dart';

/// Centralised design tokens for the app.
/// All color constants are declared as `const` so they can be used inside
/// `const` widget constructors without "Invalid constant value" errors.
class AppTheme {
  AppTheme._();

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF9F6FB);
  static const Color backgroundDark  = Color(0xFF1D1B20);
  static const Color surfaceColor    = Color(0xFFEDE7F6); // card/icon bg
  static const Color onSurfaceColor  = Color(0xFF6750A4); // icon on surface

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF6750A4);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1D1B20);
  static const Color textSecondary = Color(0xFF6B6572);
  static const Color textTertiary  = Color(0xFF9E99A3);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color incomeColor  = Color(0xFF2D9D5C);
  static const Color expenseColor = Color(0xFFE63946);
  static const Color successColor = Color(0xFF2D9D5C);
  static const Color warningColor = Color(0xFFFFB703);
  static const Color borderColor  = Color(0xFFE8E0EC);

  // ── Text styles ──────────────────────────────────────────────────────────

  /// Small, wide-tracked label used for section headings (e.g. "RECENT").
  static const TextStyle trackingWide = TextStyle(
        fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: textSecondary,
  );

  /// Like [trackingWide] but slightly lighter weight — for secondary labels.
  static const TextStyle trackingWideSecondary = TextStyle(
        fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: textTertiary,
  );

  /// Compact monospace-flavoured style for numbers/percentages.
  static const TextStyle smallMonoTextStyle = TextStyle(
        fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  // ── Theme ────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: backgroundLight,
        ),
        scaffoldBackgroundColor: backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundLight,
          foregroundColor: textPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(
                        fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
}
