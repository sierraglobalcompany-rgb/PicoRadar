import 'package:flutter/material.dart';

import 'app_tokens.dart';

ThemeData buildPicoRadarTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    secondary: AppColors.blue,
    surface: AppColors.surface,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AppColors.teal.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.teal : AppColors.navy,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: AppColors.navy,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(
        color: AppColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
  );
}
