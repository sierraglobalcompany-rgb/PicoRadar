import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/storage/app_preferences.dart';
import '../features/garage/data/vehicle_profile.dart';
import '../features/garage/data/vehicle_repository.dart';
import '../features/pico_placa/data/bundled_restrictions.dart';
import '../features/pico_placa/data/pico_preferences.dart';
import '../features/pico_placa/data/restriction_store.dart';
import '../features/pico_placa/domain/bogota_time.dart';
import '../features/pico_placa/platform/pico_notifications.dart';
import '../features/pico_placa/platform/pico_widget_bridge.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences();
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(
    database: ref.watch(appDatabaseProvider),
    preferences: ref.watch(appPreferencesProvider),
  );
});

final vehicleListProvider = FutureProvider<List<VehicleProfile>>((ref) {
  return ref.watch(vehicleRepositoryProvider).listVehicles();
});

final activeVehicleProvider = FutureProvider<VehicleProfile?>((ref) {
  return ref.watch(vehicleRepositoryProvider).getActiveVehicle();
});

final restrictionStoreProvider = Provider<RestrictionStore>((ref) {
  return RestrictionStore(ref.watch(appDatabaseProvider));
});

final bundledRestrictionsProvider = FutureProvider<void>((ref) {
  return ensureBundledRestrictionsLoaded(ref.watch(appDatabaseProvider));
});

final restrictionJurisdictionsProvider =
    FutureProvider<List<RestrictionJurisdiction>>((ref) async {
      await ref.watch(bundledRestrictionsProvider.future);
      return ref.watch(restrictionStoreProvider).listJurisdictions();
    });

final selectedPicoJurisdictionIdProvider = FutureProvider<String?>((ref) {
  return ref
      .watch(appPreferencesProvider)
      .getString(picoJurisdictionPreferenceKey);
});

final picoAlertPreferencesProvider = FutureProvider<PicoAlertPreferences>((
  ref,
) {
  return loadPicoAlertPreferences(ref.watch(appPreferencesProvider));
});

final picoNotificationSchedulerProvider = Provider<PicoNotificationScheduler>((
  ref,
) {
  final scheduler = PicoNotificationScheduler();
  ref.onDispose(() {});
  return scheduler;
});

final picoWidgetBridgeProvider = Provider<PicoWidgetBridge>((ref) {
  return const PicoWidgetBridge();
});

final picoWidgetSnapshotSyncProvider = Provider<PicoWidgetSnapshotSync>((ref) {
  return PicoWidgetSnapshotSync(ref.watch(picoWidgetBridgeProvider));
});

final picoWidgetSyncProvider = FutureProvider<void>((ref) async {
  final vehicles = await ref.watch(vehicleListProvider.future);
  final activeVehicle = await ref.watch(activeVehicleProvider.future);
  final selectedJurisdictionId = await ref.watch(
    selectedPicoJurisdictionIdProvider.future,
  );
  final jurisdictions = await ref.watch(restrictionJurisdictionsProvider.future);
  final vehicle = activeVehicle ?? (vehicles.isEmpty ? null : vehicles.first);
  final jurisdictionName = _jurisdictionName(
    jurisdictions,
    selectedJurisdictionId,
  );
  try {
    await ref
        .watch(picoWidgetSnapshotSyncProvider)
        .sync(vehicle: vehicle, jurisdictionName: jurisdictionName);
  } on MissingPluginException {
    return;
  }
});

final picoNotificationSyncProvider = FutureProvider<void>((ref) async {
  await ref.watch(bundledRestrictionsProvider.future);
  final vehicles = await ref.watch(vehicleListProvider.future);
  if (vehicles.isEmpty) {
    return;
  }

  final alertPreferences = await ref.watch(picoAlertPreferencesProvider.future);
  if (!alertPreferences.permissionGranted) {
    if (alertPreferences.permissionRequested) {
      await _tryCancelPicoNotifications(ref);
    }
    return;
  }

  final selectedJurisdictionId = await ref.watch(
    selectedPicoJurisdictionIdProvider.future,
  );
  final jurisdictions = await ref.watch(restrictionJurisdictionsProvider.future);
  final jurisdiction = _jurisdiction(jurisdictions, selectedJurisdictionId);
  if (jurisdiction == null) {
    return;
  }

  final scheduler = ref.watch(picoNotificationSchedulerProvider);
  try {
    await scheduler.initialize();
    if (!alertPreferences.enabled) {
      await scheduler.cancelPicoNotifications();
      return;
    }
    final plans = await buildPicoNotificationPlans(
      store: ref.watch(restrictionStoreProvider),
      currentInstant: ref.watch(currentInstantProvider),
      nowBogota: ref.watch(bogotaNowProvider),
      vehicles: vehicles,
      jurisdiction: jurisdiction,
      alertPreferences: alertPreferences,
    );
    await scheduler.reschedule(plans);
  } on MissingPluginException {
    return;
  }
});

final currentInstantProvider = Provider<DateTime>((ref) {
  return DateTime.now().toUtc();
});

final bogotaNowProvider = Provider<DateTime>((ref) {
  return bogotaWallClock(DateTime.now());
});

RestrictionJurisdiction? _jurisdiction(
  List<RestrictionJurisdiction> jurisdictions,
  String? selectedJurisdictionId,
) {
  if (selectedJurisdictionId == null) {
    return null;
  }
  for (final jurisdiction in jurisdictions) {
    if (jurisdiction.id == selectedJurisdictionId) {
      return jurisdiction;
    }
  }
  return null;
}

String? _jurisdictionName(
  List<RestrictionJurisdiction> jurisdictions,
  String? selectedJurisdictionId,
) {
  return _jurisdiction(jurisdictions, selectedJurisdictionId)?.name;
}

Future<void> _tryCancelPicoNotifications(Ref ref) async {
  try {
    final scheduler = ref.watch(picoNotificationSchedulerProvider);
    await scheduler.initialize();
    await scheduler.cancelPicoNotifications();
  } on MissingPluginException {
    return;
  }
}
