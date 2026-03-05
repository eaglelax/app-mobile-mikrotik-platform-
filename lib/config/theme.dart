import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFDC3545);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF17A2B8);

  static const Color darkBg = Color(0xFF1A1D21);
  static const Color darkCard = Color(0xFF23272B);
  static const Color darkSurface = Color(0xFF2D3238);
  static const Color darkBorder = Color(0xFF3A3F47);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: darkCard,
          error: danger,
        ),
        scaffoldBackgroundColor: darkBg,
        cardColor: darkCard,
        dividerColor: darkBorder,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkCard,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkCard,
          selectedItemColor: primary,
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: darkBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: primary,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFF1A1D21)),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D21),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
}
