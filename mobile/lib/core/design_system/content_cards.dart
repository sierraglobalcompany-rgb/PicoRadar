import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'actions_and_badges.dart';
import 'surfaces.dart';

enum StatusTone { success, warning, danger, neutral }

class StatusCard extends StatelessWidget {
  const StatusCard({
    required this.title,
    required this.message,
    required this.tone,
    super.key,
  });

  final String title;
  final String message;
  final StatusTone tone;

  Color get _color {
    return switch (tone) {
      StatusTone.success => AppColors.green,
      StatusTone.warning => AppColors.orange,
      StatusTone.danger => AppColors.red,
      StatusTone.neutral => AppColors.blue,
    };
  }

  String get _semanticStatus {
    return switch (tone) {
      StatusTone.success => 'Estado correcto',
      StatusTone.warning => 'Estado preventivo',
      StatusTone.danger => 'Estado critico',
      StatusTone.neutral => 'Estado informativo',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      label: _semanticStatus,
      child: AppCard(
        backgroundColor: color.withValues(alpha: 0.08),
        borderColor: color.withValues(alpha: 0.28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.circle, size: 14, color: color),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.h2.copyWith(color: color)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.plate,
    required this.kindLabel,
    required this.active,
    this.onTap,
    super.key,
  });

  final String plate;
  final String kindLabel;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = active ? AppColors.green : AppColors.navy;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plate, style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.xs),
                Text(kindLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
          SourceBadge(label: active ? 'Activo' : 'Inactivo', verified: active),
          Icon(Icons.chevron_right, color: statusColor),
        ],
      ),
    );
  }
}

class DocumentExpiryCard extends StatelessWidget {
  const DocumentExpiryCard({
    required this.title,
    required this.expiryLabel,
    required this.tone,
    super.key,
  });

  final String title;
  final String expiryLabel;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusTone.success => AppColors.green,
      StatusTone.warning => AppColors.orange,
      StatusTone.danger => AppColors.red,
      StatusTone.neutral => AppColors.blue,
    };

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: color),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(expiryLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppLauncherTile extends StatelessWidget {
  const AppLauncherTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badge,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Icon(icon, color: AppColors.blue),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(title, style: AppTextStyles.bodyStrong, softWrap: true),
                if (badge != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  SourceBadge(label: badge!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
