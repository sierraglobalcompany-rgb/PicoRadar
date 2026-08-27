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

final bogotaNowProvider = Provider<DateTime>((ref) {
  return bogotaWallClock(DateTime.now());
});
