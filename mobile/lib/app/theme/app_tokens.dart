import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF17324D);
  static const teal = Color(0xFF0B7A75);
  static const blue = Color(0xFF2F6FED);
  static const green = Color(0xFF1B8A5A);
  static const orange = Color(0xFFD97706);
  static const red = Color(0xFFC2413B);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F8FA);
  static const border = Color(0xFFD9E2EA);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const card = 8.0;
  static const button = 22.0;
}

abstract final class AppIconSize {
  static const m = 24.0;
  static const l = 32.0;
}
