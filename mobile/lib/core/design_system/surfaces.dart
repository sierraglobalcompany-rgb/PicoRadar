import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: borderColor),
    );

    return Material(
      color: backgroundColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PicoSurface extends StatelessWidget {
  const PicoSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(child: child),
    );
  }
}

class DrivingSurface extends StatelessWidget {
  const DrivingSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('driving-surface'),
      color: const Color(0xFF07131F),
      child: DefaultTextStyle(
        style: AppTextStyles.body.copyWith(color: Colors.white),
        child: child,
      ),
    );
  }
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.input,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
