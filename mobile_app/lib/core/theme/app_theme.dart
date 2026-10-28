// The Material theme of the whole app, built from the design system:
//   app_colors.dart       colors
//   app_text_styles.dart  font Cairo and text sizes
//   app_spacing.dart      spaces, sizes, round corners, shadows, gradients
//   css.dart              helpers to draw like the design's CSS
// Importing this file gives all of them.
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_text_styles.dart';
export 'css.dart';

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      onPrimary: AppColors.white,
      secondary: AppColors.leaf,
      onSecondary: AppColors.green,
      surface: AppColors.cream,
      onSurface: AppColors.green,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.cream,
      iconTheme: const IconThemeData(color: AppColors.green),

      // Big, easy-to-read text.
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headline,
        headlineMedium: AppTextStyles.number,
        headlineSmall: AppTextStyles.sectionTitle,
        titleLarge: AppTextStyles.sectionTitle,
        titleMedium: AppTextStyles.cardTitle,
        titleSmall: AppTextStyles.cardTitleSmall,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySmall,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.label,
      ),

      // Screens not redesigned yet still have a top bar: make it blend in.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.green,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.sectionTitle,
      ),

      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shadowColor: AppColors.green.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // Buttons: pill shaped, light green, dark green text.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightGreen,
          foregroundColor: AppColors.green,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: AppTextStyles.cardTitleSmall,
          minimumSize: const Size(64, 56),
          side: const BorderSide(color: AppColors.green, width: 2),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: AppTextStyles.cardTitleSmall,
          minimumSize: const Size(64, 54),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.leaf
                : AppColors.white,
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.green),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.mint, width: 2),
          ),
          textStyle: WidgetStatePropertyAll(AppTextStyles.label),
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        ),
      ),

      // Text fields: white, round, no border line (a green line when typing).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMuted,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.green,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.leaf, width: 2),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green,
        contentTextStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        iconColor: AppColors.green,
        titleTextStyle: AppTextStyles.sectionTitle,
        contentTextStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.green,
        textColor: AppColors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
      ),
    );
  }
}
