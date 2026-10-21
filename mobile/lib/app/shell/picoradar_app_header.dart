import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/branding.dart';
import '../router/app_routes.dart';
import '../../features/pico_placa/data/pico_preferences.dart';
import '../../features/visual_assets/presentation/visual_asset_widgets.dart';
import '../theme/app_tokens.dart';

class PicoRadarAppHeader extends StatelessWidget {
  const PicoRadarAppHeader({
    required this.alertPreferences,
    required this.onNotificationsPressed,
    this.trailingControl,
    this.headerKey = const ValueKey('picoradar-app-header'),
    this.brandKey = const ValueKey('picoradar-brand-lockup'),
    this.capsuleKey = const ValueKey('picoradar-user-controls-capsule'),
    this.bellKey = const ValueKey('picoradar-notification-bell'),
    super.key,
  });

  final PicoAlertPreferences alertPreferences;
  final VoidCallback onNotificationsPressed;
  final Widget? trailingControl;
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
          _UserControls(
            key: capsuleKey,
            alertPreferences: alertPreferences,
            bellKey: bellKey,
            onNotificationsPressed: onNotificationsPressed,
            trailingControl: trailingControl,
          ),
        ],
      ),
    );
  }
}

class _UserControls extends ConsumerWidget {
  const _UserControls({
    required this.alertPreferences,
    required this.bellKey,
    required this.onNotificationsPressed,
    this.trailingControl,
    super.key,
  });

  final PicoAlertPreferences alertPreferences;
  final Key bellKey;
  final VoidCallback onNotificationsPressed;
  final Widget? trailingControl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularHeaderControl(
          key: ValueKey('picoradar-avatar-control'),
          child: HomeAvatarButton(
            embedded: true,
            visualSize: 36,
            semanticsLabel: 'Abrir avatar y ajustes',
            onTap: () => _showUserMenu(context, ref),
          ),
        ),
        if (trailingControl != null) ...[
          const SizedBox(width: AppSpacing.s),
          trailingControl!,
        ],
        const SizedBox(width: AppSpacing.s),
        _CircularHeaderControl(
          key: const ValueKey('picoradar-bell-control'),
          child: _NotificationBellButton(
            key: bellKey,
            alertPreferences: alertPreferences,
            onPressed: onNotificationsPressed,
          ),
        ),
      ],
    );
  }

  Future<void> _showUserMenu(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const ValueKey('header-change-avatar'),
                  leading: const Icon(Icons.face_outlined),
                  title: const Text('Cambiar avatar'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    if (context.mounted) {
                      await showAvatarPicker(context, ref);
                    }
                  },
                ),
                ListTile(
                  key: const ValueKey('header-open-settings'),
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configuración'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (context.mounted) {
                      context.push(AppRoute.settings.path);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircularHeaderControl extends StatelessWidget {
  const _CircularHeaderControl({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Center(
        child: Material(
          color: AppColors.surface,
          elevation: 3,
          shadowColor: AppColors.navy.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox.square(dimension: 42, child: Center(child: child)),
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
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
        iconSize: 24,
        onPressed: onPressed,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, color: AppColors.navy),
            if (alertPreferences.permissionGranted && alertPreferences.enabled)
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
    );
  }
}
