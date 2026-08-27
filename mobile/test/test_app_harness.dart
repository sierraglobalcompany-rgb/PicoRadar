import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';

class TestAppHarness {
  TestAppHarness()
    : database = AppDatabase(NativeDatabase.memory()),
      preferences = MemoryPreferences();

  final AppDatabase database;
  final MemoryPreferences preferences;
  int _vehicleIdSequence = 0;

  VehicleRepository get repository {
    return VehicleRepository(
      database: database,
      preferences: preferences,
      idGenerator: _nextVehicleId,
    );
  }

  String _nextVehicleId() {
    _vehicleIdSequence += 1;
    return _vehicleIdSequence.toString().padLeft(32, '0');
  }

  Future<void> pump(WidgetTester tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const PicoRadarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await database.close();
  }
}

class MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
