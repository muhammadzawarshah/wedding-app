import 'package:flutter/material.dart';

class AppColors {
  static const paperBlue = Color(0xFFDDECF1);
  static const paperBlueDark = Color(0xFFC6DCE5);
  static const deepInk = Color(0xFF334049);
  static const mutedInk = Color(0xFF65747D);
  static const passportGold = Color(0xFFC79D47);
  static const warmWhite = Color(0xFFFFFCF7);
  static const roseTaupe = Color(0xFF8B6B66);
  static const success = Color(0xFF2E7D65);
  static const danger = Color(0xFFB75C52);
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.passportGold,
      primary: AppColors.deepInk,
      secondary: AppColors.passportGold,
      surface: AppColors.warmWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paperBlue,
      fontFamily: 'Georgia',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: AppColors.deepInk,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.deepInk,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.deepInk,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.deepInk,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.deepInk,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: AppColors.deepInk,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.mutedInk,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.warmWhite.withValues(alpha: 0.92),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.deepInk.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.warmWhite.withValues(alpha: 0.94),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.passportGold,
            width: 1.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepInk,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepInk,
          side: const BorderSide(color: AppColors.deepInk),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
