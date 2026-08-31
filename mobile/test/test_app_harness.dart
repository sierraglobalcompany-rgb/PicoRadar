import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';

class TestAppHarness {
  TestAppHarness()
    : database = _createDatabase(),
      preferences = MemoryPreferences(),
      documentRoot = Directory.systemTemp.createTempSync(
        'picoradar-documents-test-',
      );

  final AppDatabase database;
  final MemoryPreferences preferences;
  final Directory documentRoot;
  DateTime now = DateTime(2026, 8, 27, 22);
  int _vehicleIdSequence = 0;
  int _documentIdSequence = 0;

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
    VehicleDocumentGateway? documentGateway,
    List<VehicleProfile>? vehicleListOverride,
    VehicleProfile? activeVehicleOverride,
    String? documentVehicleIdOverride,
    PrivateVehicleDocumentType? documentTypeOverride,
    PrivateVehicleDocumentMetadata? documentMetadataOverride,
    Widget? childOverride,
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
        privateVehicleDocumentStoreProvider.overrideWithValue(
          PrivateVehicleDocumentStore(
            rootDirectory: () async => documentRoot,
            cacheDirectory: () async => documentRoot,
            masterKey: () async => SecretKey(List<int>.filled(32, 7)),
            idGenerator: _nextDocumentId,
          ),
        ),
        vehicleDocumentGatewayProvider.overrideWithValue(
          documentGateway ?? _FakeVehicleDocumentGateway(),
        ),
        if (vehicleListOverride != null)
          vehicleListProvider.overrideWithValue(
            AsyncValue.data(vehicleListOverride),
          ),
        if (activeVehicleOverride != null)
          activeVehicleProvider.overrideWithValue(
            AsyncValue.data(activeVehicleOverride),
          ),
        if (documentVehicleIdOverride != null &&
            documentTypeOverride != null &&
            documentMetadataOverride != null)
          privateVehicleDocumentProvider((
            documentVehicleIdOverride,
            documentTypeOverride,
          )).overrideWithValue(AsyncValue.data(documentMetadataOverride)),
        bogotaNowProvider.overrideWithValue(now),
        startupReadinessProvider.overrideWith(
          (ref) async => const StartupReadiness(
            imageAssets: [],
            vehicleCount: 0,
            selectedJurisdictionId: null,
          ),
        ),
        if (moduleFeatureFlags.isNotEmpty)
          moduleFeatureFlagsProvider.overrideWithValue(moduleFeatureFlags),
      ],
      child: childOverride ?? const PicoRadarApp(),
    );
    await tester.pumpWidget(wrap == null ? app : wrap(app));
    await tester.pump();
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  String _nextDocumentId() {
    _documentIdSequence += 1;
    return 'document-${_documentIdSequence.toString().padLeft(4, '0')}';
  }

  Future<void> dispose() async {
    unawaited(database.close());
    if (documentRoot.existsSync()) {
      documentRoot.deleteSync(recursive: true);
    }
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

class _FakeVehicleDocumentGateway implements VehicleDocumentGateway {
  @override
  Future<bool> openDocument(File file) async => true;

  @override
  Future<PickedVehicleDocument?> pickDocument() async => null;
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
