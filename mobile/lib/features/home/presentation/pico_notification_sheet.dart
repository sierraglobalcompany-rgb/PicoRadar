import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/actions_and_badges.dart';
import '../../pico_placa/data/pico_preferences.dart';

class PicoNotificationSheet extends ConsumerWidget {
  const PicoNotificationSheet({required this.alertPreferences, super.key});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            key: const ValueKey('home-notification-sheet'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Alertas', style: AppTextStyles.h1)),
                  IconButton(
                    key: const ValueKey('notification-sheet-close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              const Text('Recordatorios locales, sin cuenta ni servidor.'),
              const SizedBox(height: AppSpacing.l),
              if (!alertPreferences.permissionRequested)
                PrimaryButton(
                  key: const ValueKey('home-enable-notifications'),
                  label: 'Activar notificaciones',
                  icon: Icons.notifications_active_outlined,
                  onPressed: () => _requestPermission(context, ref),
                )
              else if (!alertPreferences.permissionGranted)
                const Text(
                  'Permiso de notificaciones desactivado. Puedes habilitarlo desde los ajustes del sistema.',
                )
              else ...[
                SwitchListTile(
                  key: const ValueKey('pico-alerts-enabled'),
                  value: alertPreferences.enabled,
                  onChanged: (value) =>
                      _save(ref, alertPreferences.copyWith(enabled: value)),
                  title: const Text('Recordatorios habilitados'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  key: const ValueKey('pico-day-before-enabled'),
                  value: alertPreferences.dayBeforeEnabled,
                  onChanged: alertPreferences.enabled
                      ? (value) => _save(
                          ref,
                          alertPreferences.copyWith(dayBeforeEnabled: value),
                        )
                      : null,
                  title: const Text('Día anterior'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  key: const ValueKey('pico-day-before-time'),
                  enabled:
                      alertPreferences.enabled &&
                      alertPreferences.dayBeforeEnabled,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora día anterior'),
                  trailing: Text(
                    _formatMinute(alertPreferences.dayBeforeMinute),
                  ),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    initialMinute: alertPreferences.dayBeforeMinute,
                    onSelected: (minute) =>
                        alertPreferences.copyWith(dayBeforeMinute: minute),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('pico-same-day-enabled'),
                  value: alertPreferences.sameDayEnabled,
                  onChanged: alertPreferences.enabled
                      ? (value) => _save(
                          ref,
                          alertPreferences.copyWith(sameDayEnabled: value),
                        )
                      : null,
                  title: const Text('Mismo día'),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  key: const ValueKey('pico-same-day-time'),
                  enabled:
                      alertPreferences.enabled &&
                      alertPreferences.sameDayEnabled,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm),
                  title: const Text('Hora mismo día'),
                  trailing: Text(_formatMinute(alertPreferences.sameDayMinute)),
                  onTap: () => _pickTime(
                    context,
                    ref,
                    initialMinute: alertPreferences.sameDayMinute,
                    onSelected: (minute) =>
                        alertPreferences.copyWith(sameDayMinute: minute),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context, WidgetRef ref) async {
    var granted = false;
    try {
      final scheduler = ref.read(picoNotificationSchedulerProvider);
      await scheduler.initialize();
      granted = await scheduler.requestPermission();
    } on MissingPluginException {
      granted = true;
    }
    await _save(
      ref,
      alertPreferences.copyWith(
        permissionRequested: true,
        permissionGranted: granted,
      ),
    );
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de notificaciones denegado.')),
      );
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required int initialMinute,
    required PicoAlertPreferences Function(int minute) onSelected,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialMinute ~/ 60,
        minute: initialMinute % 60,
      ),
    );
    if (selected == null) {
      return;
    }
    await _save(ref, onSelected((selected.hour * 60) + selected.minute));
  }

  Future<void> _save(WidgetRef ref, PicoAlertPreferences value) async {
    await savePicoAlertPreferences(ref.read(appPreferencesProvider), value);
    ref.invalidate(picoAlertPreferencesProvider);
    ref.invalidate(picoNotificationSyncProvider);
  }
}

String _formatMinute(int minute) {
  final hour = (minute ~/ 60).toString().padLeft(2, '0');
  final minutes = (minute % 60).toString().padLeft(2, '0');
  return '$hour:$minutes';
}
