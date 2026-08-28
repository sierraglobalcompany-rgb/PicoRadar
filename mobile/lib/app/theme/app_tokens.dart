import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF17324D);
  static const teal = Color(0xFF0B7A75);
  static const blue = Color(0xFF2F6FED);
  static const green = Color(0xFF1B8A5A);
  static const orange = Color(0xFFD97706);
  static const red = Color(0xFFC2413B);
  static const plateYellow = Color(0xFFF6C515);
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
  static const xxxl = 48.0;
}

abstract final class AppRadius {
  static const card = 22.0;
  static const button = 22.0;
  static const modal = 26.0;
  static const input = 18.0;
  static const chip = 999.0;
}

abstract final class AppIconSize {
  static const m = 24.0;
  static const l = 32.0;
}

abstract final class AppMotion {
  static const microPress = Duration(milliseconds: 110);
  static const fade = Duration(milliseconds: 180);
  static const navBounce = Duration(milliseconds: 220);
  static const carouselSnap = Duration(milliseconds: 300);
  static const restrictedPulse = Duration(milliseconds: 1700);

  static const standardCurve = Curves.easeOutCubic;
  static const springCurve = Curves.easeOutBack;
}

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.08,
    color: AppColors.navy,
  );

  static const h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.16,
    color: AppColors.navy,
  );

  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.navy,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.38,
    color: AppColors.navy,
  );

  static const bodyStrong = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.navy,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.navy,
  );
}
