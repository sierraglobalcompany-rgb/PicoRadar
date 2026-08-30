import 'package:flutter/material.dart';

import '../../core/design_system/branding.dart';
import '../../features/pico_placa/data/pico_preferences.dart';
import '../../features/visual_assets/presentation/visual_asset_widgets.dart';
import '../theme/app_tokens.dart';

class PicoRadarAppHeader extends StatelessWidget {
  const PicoRadarAppHeader({
    required this.alertPreferences,
    required this.onNotificationsPressed,
    this.headerKey = const ValueKey('picoradar-app-header'),
    this.brandKey = const ValueKey('picoradar-brand-lockup'),
    this.capsuleKey = const ValueKey('picoradar-user-controls-capsule'),
    this.bellKey = const ValueKey('picoradar-notification-bell'),
    super.key,
  });

  final PicoAlertPreferences alertPreferences;
  final VoidCallback onNotificationsPressed;
  final Key headerKey;
  final Key brandKey;
  final Key capsuleKey;
  final Key bellKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: headerKey,
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PicoRadarBrandLockup(key: brandKey, markSize: 30),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          _UserControlsCapsule(
            key: capsuleKey,
            alertPreferences: alertPreferences,
            bellKey: bellKey,
            onNotificationsPressed: onNotificationsPressed,
          ),
        ],
      ),
    );
  }
}

class _UserControlsCapsule extends StatelessWidget {
  const _UserControlsCapsule({
    required this.alertPreferences,
    required this.bellKey,
    required this.onNotificationsPressed,
    super.key,
  });

  final PicoAlertPreferences alertPreferences;
  final Key bellKey;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.navy.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HomeAvatarButton(embedded: true, visualSize: 40),
            Container(
              width: 1,
              height: 28,
              color: AppColors.border.withValues(alpha: 0.72),
            ),
            _NotificationBellButton(
              key: bellKey,
              alertPreferences: alertPreferences,
              onPressed: onNotificationsPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.alertPreferences,
    required this.onPressed,
    super.key,
  });

  final PicoAlertPreferences alertPreferences;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir notificaciones',
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.navy,
              ),
              if (alertPreferences.permissionGranted &&
                  alertPreferences.enabled)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
