import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/storage/app_preferences.dart';
import '../features/garage/data/vehicle_profile.dart';
import '../features/garage/data/vehicle_repository.dart';

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
