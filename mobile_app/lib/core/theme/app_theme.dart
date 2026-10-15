// Colors and text styles of the whole app.
// Change a color here and it changes everywhere.
import 'package:flutter/material.dart';

import '../enums.dart';

/// The Looz color palette (natural / earthy).
class AppColors {
  static const olive = Color(0xFF6B7A2E); // main color (buttons, icons)
  static const almond = Color(0xFFF5ECD7); // page background (almond beige)
  static const almondLight = Color(0xFFFFFBF2); // cards
  static const brown = Color(0xFF8B6B4A); // second color (assistant, badges)
  static const textDark = Color(0xFF3B2F25); // main text color

  // Status colors (health, urgency)
  static const good = Color(0xFF4C9A2A); // green
  static const warning = Color(0xFFE8912D); // orange
  static const danger = Color(0xFFC8442F); // red

  static const premium = Color(0xFFD4A62A); // gold

  /// Returns green / orange / red for a status level.
  static Color forLevel(StatusLevel level) {
    switch (level) {
      case StatusLevel.good:
        return good;
      case StatusLevel.warning:
        return warning;
      case StatusLevel.danger:
        return danger;
    }
  }
}

/// The Material 3 theme of the app.
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.olive,
        primary: AppColors.olive,
        secondary: AppColors.brown,
        surface: AppColors.almond,
      ),
      scaffoldBackgroundColor: AppColors.almond,

      // Big, easy-to-read text.
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.textDark),
        bodyMedium: TextStyle(fontSize: 16, color: AppColors.textDark),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.almond,
        foregroundColor: AppColors.textDark,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.almondLight,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Bottom navigation: tall bar, big icons.
      navigationBarTheme: NavigationBarThemeData(
        height: 84,
        backgroundColor: AppColors.almondLight,
        indicatorColor: AppColors.olive.withValues(alpha: 0.2),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 32, color: AppColors.olive),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.olive,
        foregroundColor: Colors.white,
      ),
    );
  }
}
