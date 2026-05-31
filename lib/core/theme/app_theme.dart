import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryGreenLight = Color(0xFF2D7A4F);
  static const primaryGreenDark = Color(0xFF3CAF6E);

  static ThemeData dark() {
    const background = Color(0xFF0D1B12);
    const surface = Color(0xFF1A2E20);
    const primaryText = Color(0xFFEDEDED);
    const secondaryText = Color(0xFFB3B3B3);
    const primaryGreen = primaryGreenDark;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      useMaterial3: true,

      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primaryGreen,
        onPrimary: Colors.white,
        onBackground: primaryText,
        onSurface: primaryText,
      ),

      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryText,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          color: secondaryText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: primaryText,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          color: secondaryText,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surface,
          disabledForegroundColor: secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        iconTheme: const IconThemeData(color: primaryText),
      ),
    );
  }

  static ThemeData light() {
    const background = Color(0xFFF5F5F5);
    const surface = Color(0xFFFFFFFF);
    const primaryText = Color(0xFF1C1C1E);
    const secondaryText = Color(0xFF666666);
    const primaryGreen = primaryGreenLight;

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      useMaterial3: true,

      colorScheme: const ColorScheme.light(
        background: background,
        surface: surface,
        primary: primaryGreen,
        onPrimary: Colors.white,
        onBackground: primaryText,
        onSurface: primaryText,
      ),

      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryText,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          color: secondaryText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: primaryText,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          color: secondaryText,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        iconTheme: const IconThemeData(color: primaryText),
      ),
    );
  }
}