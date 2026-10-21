import 'dart:convert';
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
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/maintenance/application/maintenance_reminders.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/pico_placa/domain/bogota_time.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';

class _HarnessWalletPlatform extends WalletPlatform {
  _HarnessWalletPlatform(this.root);
  final Directory root;
  @override
  Future<void> setSecure(bool enabled) async {}
  @override
  Future<String> noBackupDirectory() async => root.path;
}

class _HarnessWalletAuthenticator implements WalletDeviceAuthenticator {
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async =>
      WalletAuthenticationResult.success;
}

class _HarnessWalletPreferences implements WalletSecurityPreferencesStore {
  WalletSecurityPreferences value = const WalletSecurityPreferences(
    offerSeen: true,
  );
  @override
  Future<WalletSecurityPreferences> read() async => value;
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {
    value = preferences;
  }
}

class _NoDeviceLocationGateway implements DeviceLocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.notRequested;
  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.denied;
  @override
  Future<DeviceLocationResult> getCurrentPosition() async =>
      const DeviceLocationError(DeviceLocationFailure.serviceDisabled);
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<bool> openLocationSettings() async => false;
}

class TestAppHarness {
  static final registrationCatalog = RegistrationCityCatalog.fromJson(
    jsonDecode(File(registrationCityCatalogAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );
  // Load the real asset outside rootBundle's isolate work in fake-async tests.
  static final tripCatalog = TripMunicipalityCatalog.fromJson(
    jsonDecode(File(tripMunicipalityCatalogAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );

  TestAppHarness()
    : database = _createDatabase(),
      preferences = MemoryPreferences(),
      documentRoot = Directory.systemTemp.createTempSync(
        'picoradar-documents-test-',
      ) {
    documentStore = PrivateVehicleDocumentStore(
      rootDirectory: () async => documentRoot,
      cacheDirectory: () async => documentRoot,
      masterKey: () async => SecretKey(List<int>.filled(32, 7)),
      idGenerator: _nextDocumentId,
    );
    walletStore = WalletStore(
      db: database,
      legacyStore: documentStore,
      rootDirectory: () async => documentRoot,
      cacheDirectory: () async => documentRoot,
      masterKey: () async => SecretKey(List<int>.filled(32, 7)),
    );
  }

  final AppDatabase database;
  final MemoryPreferences preferences;
  final Directory documentRoot;
  late final PrivateVehicleDocumentStore documentStore;
  late final WalletStore walletStore;
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
    VehicleAssociatedDataCleaner? vehicleAssociatedDataCleaner,
    DeviceLocationGateway? deviceLocationGateway,
    PrivateVehicleDocumentStore? documentStoreOverride,
    List<VehicleProfile>? vehicleListOverride,
    VehicleProfile? activeVehicleOverride,
    String? documentVehicleIdOverride,
    PrivateVehicleDocumentType? documentTypeOverride,
    PrivateVehicleDocumentMetadata? documentMetadataOverride,
    bool overrideHomeBannerCampaign = false,
    HomeBannerCampaign? homeBannerCampaignOverride,
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
        walletStoreProvider.overrideWithValue(walletStore),
        walletPlatformProvider.overrideWithValue(
          _HarnessWalletPlatform(documentRoot),
        ),
        walletFileKeyProvider.overrideWithValue(
          () async => SecretKey(List<int>.filled(32, 7)),
        ),
        walletSessionProvider.overrideWith((ref) {
          final session = WalletSession(
            authenticator: _HarnessWalletAuthenticator(),
            preferences: _HarnessWalletPreferences(),
          );
          ref.onDispose(session.dispose);
          return session;
        }),
        appDatabaseProvider.overrideWithValue(database),
        datasetSnapshotsDirectoryProvider.overrideWith(
          (ref) async => documentRoot,
        ),
        appPreferencesProvider.overrideWithValue(preferences),
        tripMunicipalityCatalogProvider.overrideWithValue(
          AsyncValue.data(tripCatalog),
        ),
        registrationCityCatalogProvider.overrideWithValue(
          AsyncValue.data(registrationCatalog),
        ),
        picoNotificationSchedulerProvider.overrideWithValue(
          _FakePicoNotificationScheduler(),
        ),
        externalLauncherProvider.overrideWithValue(
          externalLauncher ?? _FakeExternalLauncher(),
        ),
        privateVehicleDocumentStoreProvider.overrideWithValue(
          documentStoreOverride ?? documentStore,
        ),
        vehicleAssociatedDataCleanerProvider.overrideWithValue(
          vehicleAssociatedDataCleaner ?? _NoOpVehicleAssociatedDataCleaner(),
        ),
        vehicleDocumentGatewayProvider.overrideWithValue(
          documentGateway ?? _FakeVehicleDocumentGateway(),
        ),
        deviceLocationGatewayProvider.overrideWithValue(
          deviceLocationGateway ?? _NoDeviceLocationGateway(),
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
        currentInstantProvider.overrideWithValue(
          bogotaScheduledTime(
            date: now,
            minuteOfDay: now.hour * 60 + now.minute,
          ).toUtc().add(
            Duration(
              seconds: now.second,
              milliseconds: now.millisecond,
              microseconds: now.microsecond,
            ),
          ),
        ),
        startupReadinessProvider.overrideWith(
          (ref) async => const StartupReadiness(
            imageAssets: [],
            vehicleCount: 0,
            selectedJurisdictionId: null,
          ),
        ),
        if (moduleFeatureFlags.isNotEmpty)
          moduleFeatureFlagsProvider.overrideWithValue(moduleFeatureFlags),
        if (overrideHomeBannerCampaign)
          homeBannerCampaignProvider.overrideWithValue(
            AsyncValue.data(homeBannerCampaignOverride),
          ),
      ],
      child: childOverride ?? const PicoRadarApp(),
    );
    await tester.pumpWidget(wrap == null ? app : wrap(app));
    await tester.pump();
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
  }

  String _nextDocumentId() {
    _documentIdSequence += 1;
    return 'document-${_documentIdSequence.toString().padLeft(4, '0')}';
  }

  Future<void> dispose() async {
    await database.close();
    if (documentRoot.existsSync()) {
      documentRoot.deleteSync(recursive: true);
    }
  }
}

// File futures and image decoding are not settled by fake frame time. Wait for
// the observed state while yielding real I/O, with a bounded wall-clock budget.
// The old 1–3 second frame loops expired while durable writes were still active.
Future<void> pumpUntilRealIo(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
}) async {
  final elapsed = Stopwatch()..start();
  while (!condition() && elapsed.elapsed < const Duration(seconds: 30)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: '$reason (${elapsed.elapsed})');
}

class _NoOpVehicleAssociatedDataCleaner extends VehicleAssociatedDataCleaner {
  _NoOpVehicleAssociatedDataCleaner()
    : super(
        documentStore: PrivateVehicleDocumentStore(),
        defenseCaseStore: DefenseCaseStore(),
        peritajesDraftStore: PeritajesDraftStore(MemoryPreferences()),
        preferences: MemoryPreferences(),
      );

  @override
  Future<void> deleteForVehicle(String vehicleId) async {}

  @override
  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) async {
    if (!isAuthorized()) throw StateError('Wallet authorization expired.');
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

  @override
  Future<void> rescheduleMaintenanceNotifications(
    List<MaintenanceReminder> reminders, {
    required Map<String, String> platesByVehicleId,
  }) async {}

  @override
  Future<void> cancelMaintenanceNotifications() async {}
}

class _FakeExternalLauncher implements ExternalLauncher {
  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async => true;
}

class _FakeVehicleDocumentGateway implements VehicleDocumentGateway {
  @override
  Future<void> clearTemporaryFiles() async {}

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
