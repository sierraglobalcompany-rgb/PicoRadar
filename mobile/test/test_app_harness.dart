import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';

class TestAppHarness {
  TestAppHarness()
    : database = _createDatabase(),
      preferences = MemoryPreferences();

  final AppDatabase database;
  final MemoryPreferences preferences;
  DateTime now = DateTime(2026, 8, 27, 22);
  int _vehicleIdSequence = 0;

  static AppDatabase _createDatabase() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(NativeDatabase.memory());
  }

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

  Future<void> pump(
    WidgetTester tester, {
    Map<String, bool> moduleFeatureFlags = const {},
    ExternalLauncher? externalLauncher,
    Widget Function(Widget child)? wrap,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/widget'),
          (_) async => null,
        );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.picoradar.app/widget'),
            null,
          );
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final app = ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(preferences),
        picoNotificationSchedulerProvider.overrideWithValue(
          _FakePicoNotificationScheduler(),
        ),
        externalLauncherProvider.overrideWithValue(
          externalLauncher ?? _FakeExternalLauncher(),
        ),
        bogotaNowProvider.overrideWithValue(now),
        if (moduleFeatureFlags.isNotEmpty)
          moduleFeatureFlagsProvider.overrideWithValue(moduleFeatureFlags),
      ],
      child: const PicoRadarApp(),
    );
    await tester.pumpWidget(wrap == null ? app : wrap(app));
    await tester.pump();
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> dispose() async {
    // Flutter widget teardown can outlive the test body while providers still
    // finish async work. The in-memory DB is scoped to the test isolate.
  }
}

class _FakePicoNotificationScheduler extends PicoNotificationScheduler {
  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<void> reschedule(List<PicoNotificationPlan> plans) async {}

  @override
  Future<void> cancelPicoNotifications() async {}

  @override
  Future<void> rescheduleObligationNotifications(
    List<ObligationNotificationPlan> plans,
  ) async {}

  @override
  Future<void> cancelObligationNotifications() async {}
}

class _FakeExternalLauncher implements ExternalLauncher {
  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async => true;
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
