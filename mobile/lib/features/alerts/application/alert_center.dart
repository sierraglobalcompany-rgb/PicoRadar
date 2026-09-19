import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../pico_placa/platform/pico_notifications.dart';
import '../../vehicle_status/platform/obligation_notifications.dart';
import '../data/alert_settings.dart';
import '../platform/alert_alarm_gateway.dart';

final alertSettingsStoreProvider = Provider(
  (ref) => AlertSettingsStore(ref.watch(appDatabaseProvider)),
);
final alarmGatewayProvider = Provider<AlertAlarmGateway>(
  (ref) => const AlertAlarmGateway(),
);

class AlertCenterRow {
  const AlertCenterRow({
    required this.vehicle,
    required this.category,
    required this.settings,
    required this.scheduled,
    this.nextDate,
    this.dueDate,
  });
  final VehicleProfile vehicle;
  final AlertCategory category;
  final AlertSettings settings;
  final DateTime? nextDate, dueDate;
  final bool scheduled;
}

class AlertCenterData {
  const AlertCenterData({
    required this.rows,
    required this.permission,
    required this.capabilities,
    this.permissionsKnown = true,
    this.alarmFailureMessage,
    this.schedulingFailed = false,
  });
  final List<AlertCenterRow> rows;
  final bool permission, schedulingFailed;
  final bool permissionsKnown;
  final String? alarmFailureMessage;
  final AlarmCapabilities capabilities;
}

final alertCenterProvider = FutureProvider<AlertCenterData>((ref) async {
  final vehicles = await ref.watch(vehicleListProvider.future);
  final legacy = await ref.watch(picoAlertPreferencesProvider.future);
  final saved = await ref.watch(alertSettingsStoreProvider).loadAll();
  final scheduler = ref.watch(picoNotificationSchedulerProvider);
  final gateway = ref.watch(alarmGatewayProvider);
  var permission = false;
  var permissionsKnown = true;
  var capabilities = const AlarmCapabilities();
  var schedulingFailed = false;
  String? alarmFailure;
  try {
    final status = await gateway.status().timeout(const Duration(seconds: 3));
    alarmFailure = status.failureMessage;
  } catch (_) {
    alarmFailure = alarmFailureMessage(null);
  }
  try {
    await scheduler.initialize();
    final currentPermission = await scheduler.areNotificationsEnabled();
    permissionsKnown = currentPermission != null;
    permission = currentPermission == true;
  } catch (_) {
    permissionsKnown = false;
  }
  try {
    capabilities = await gateway.capabilities();
  } catch (_) {
    permissionsKnown = false;
  }
  schedulingFailed = !permissionsKnown || alarmFailure != null;
  try {
    await ref.watch(picoNotificationSyncProvider.future);
    await ref.watch(obligationNotificationSyncProvider.future);
  } catch (_) {
    schedulingFailed = true;
  }
  var pending = <int>{};
  try {
    pending = await scheduler.pendingIds();
  } catch (_) {
    // Revoked OS access must not hide the controls needed to recover it.
    schedulingFailed = true;
  }
  final obligations = await ref.watch(vehicleObligationStoreProvider).listAll();
  final now = ref.watch(bogotaNowProvider);
  final obligationPlans = planObligationNotifications(
    obligations: obligations,
    vehiclesById: {for (final v in vehicles) v.id: v},
    nowBogota: now,
    permissionGranted: permission,
    deliverySettings: saved,
  );
  final jurisdictions = await ref.watch(
    restrictionJurisdictionsProvider.future,
  );
  final selected = await ref.watch(selectedPicoJurisdictionIdProvider.future);
  final jurisdiction = jurisdictions.where((j) => j.id == selected).firstOrNull;
  final picoPlans = jurisdiction == null
      ? <PicoNotificationPlan>[]
      : await buildPicoNotificationPlans(
          store: ref.watch(restrictionStoreProvider),
          currentInstant: ref.watch(currentInstantProvider),
          nowBogota: now,
          vehicles: vehicles,
          jurisdiction: jurisdiction,
          alertPreferences: legacy,
          deliverySettings: saved,
        );
  final rows = <AlertCenterRow>[];
  for (final category in AlertCategory.values) {
    for (final vehicle in vehicles) {
      final obligation = obligations
          .where(
            (o) => o.vehicleId == vehicle.id && o.type.value == category.name,
          )
          .firstOrNull;
      final stored = saved
          .where((s) => s.vehicleId == vehicle.id && s.category == category)
          .firstOrNull
          ?.settings;
      final defaults = category == AlertCategory.pico
          ? AlertSettings(
              enabled: legacy.enabled,
              dayBefore: legacy.dayBeforeEnabled,
              sameDay: legacy.sameDayEnabled,
              dayBeforeMinute: legacy.dayBeforeMinute,
              sameDayMinute: legacy.sameDayMinute,
            )
          : AlertSettings(enabled: obligation?.reminderEnabled ?? true);
      final settings = (stored ?? defaults).copyWith(
        enabled: category == AlertCategory.pico
            ? (stored ?? defaults).enabled
            : (obligation?.reminderEnabled ?? (stored ?? defaults).enabled),
      );
      final events = category == AlertCategory.pico
          ? [
              for (final p in picoPlans.where((p) => p.vehicleId == vehicle.id))
                (p.id, p.scheduledAt),
            ]
          : [
              for (final p in obligationPlans.where(
                (p) =>
                    p.vehicleId == vehicle.id && p.type.value == category.name,
              ))
                (p.id, p.scheduledAt),
            ];
      events.sort((a, b) => a.$2.compareTo(b.$2));
      rows.add(
        AlertCenterRow(
          vehicle: vehicle,
          category: category,
          settings: settings,
          dueDate: obligation?.dueDate,
          nextDate: events.firstOrNull?.$2,
          scheduled:
              !schedulingFailed &&
              permission &&
              events.isNotEmpty &&
              pending.contains(events.first.$1),
        ),
      );
    }
  }
  return AlertCenterData(
    rows: rows,
    permission: permission,
    permissionsKnown: permissionsKnown,
    alarmFailureMessage: alarmFailure,
    capabilities: capabilities,
    schedulingFailed: schedulingFailed,
  );
});
