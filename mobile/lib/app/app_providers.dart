import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/database/app_database.dart'
    hide MaintenanceRecord, VehicleObligation;
import '../core/storage/app_preferences.dart';
import '../core/sync/dataset_sync_service.dart';
import '../features/defense/application/defense_case_providers.dart';
import '../features/documents/application/wallet_providers.dart'
    show walletDocumentsProvider, walletSessionProvider, walletStoreProvider;
import '../features/documents/data/wallet_models.dart';
import '../features/garage/application/vehicle_associated_data_cleaner.dart';
import '../features/garage/data/vehicle_profile.dart';
import '../features/garage/data/vehicle_repository.dart';
import '../features/home/data/home_banner_config.dart';
import '../features/maintenance/data/maintenance_record.dart';
import '../features/maintenance/data/maintenance_notification_preferences.dart';
import '../features/maintenance/data/maintenance_repository.dart';
import '../features/maintenance/application/maintenance_reminders.dart';
import '../features/vehicle_status/data/vehicle_obligation_store.dart';
import '../features/vehicle_status/data/tax_catalog.dart';
import '../features/vehicle_status/data/tax_catalog_store.dart';
import '../features/vehicle_status/data/private_vehicle_document_store.dart';
import '../features/vehicle_status/domain/vehicle_obligation.dart';
import '../features/vehicle_status/platform/obligation_notifications.dart';
import '../features/vehicle_status/platform/vehicle_document_gateway.dart';
import '../features/visual_assets/data/visual_asset_catalogs.dart';
import '../features/visual_assets/data/visual_asset_preferences.dart';
import '../features/pico_placa/data/bundled_restrictions.dart';
import '../features/pico_placa/data/pico_preferences.dart';
import '../features/pico_placa/data/restriction_dataset.dart';
import '../features/pico_placa/data/restriction_store.dart';
import '../features/pico_placa/domain/bogota_time.dart';
import '../features/pico_placa/platform/pico_notifications.dart';
import '../features/pico_placa/platform/pico_widget_bridge.dart';
import '../features/peritajes/data/peritajes_draft_store.dart';
import '../features/trip/data/toll_inventory.dart';
import '../features/trip/data/toll_tariff_catalog.dart';
import '../features/trip/data/trip_route_preview_data.dart';
import 'app_clock.dart';
import '../features/alerts/data/alert_settings.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences();
});

final maintenanceNotificationPreferencesProvider =
    Provider<MaintenanceNotificationPreferences>((ref) {
      return MaintenanceNotificationPreferences(
        ref.watch(appPreferencesProvider),
      );
    });

final maintenanceDateRemindersEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, vehicleId) {
      return ref
          .watch(maintenanceNotificationPreferencesProvider)
          .isEnabled(vehicleId);
    });

final avatarCatalogProvider = FutureProvider<AvatarCatalog>((ref) {
  return loadAvatarCatalog(rootBundle);
});

final vehicleVisualCatalogProvider = FutureProvider<VehicleVisualCatalog>((
  ref,
) {
  return loadVehicleVisualCatalog(rootBundle);
});

final homeBannerConfigProvider = FutureProvider<HomeBannerConfig>((ref) async {
  final source = await rootBundle.loadString(homeBannerConfigAssetPath);
  return HomeBannerConfig.fromJsonString(source);
});

final datasetSyncConfigProvider = Provider<AppConfig?>((ref) {
  const cdnBaseUrl = String.fromEnvironment('CDN_BASE_URL');
  if (cdnBaseUrl.trim().isEmpty) {
    return null;
  }
  return AppConfig(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    cdnBaseUrl: cdnBaseUrl,
    manifestUrl: const String.fromEnvironment('MANIFEST_URL'),
  );
});

final datasetSnapshotsDirectoryProvider = FutureProvider<Directory>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  return Directory('${directory.path}${Platform.pathSeparator}datasets');
});

final tollInventoryStoreProvider = FutureProvider<TollInventoryStore>((
  ref,
) async {
  final datasetsDirectory = await ref.watch(
    datasetSnapshotsDirectoryProvider.future,
  );
  return TollInventoryStore(
    database: ref.watch(appDatabaseProvider),
    snapshotFile: File(
      '${datasetsDirectory.path}${Platform.pathSeparator}tolls_inventory.json',
    ),
    bundledLoader: () => rootBundle.loadString(bundledTollInventoryAsset),
  );
});

final datasetSyncCommitHandlerProvider =
    Provider<void Function(String datasetKey)>((ref) {
      return (datasetKey) {
        if (datasetKey == restrictionsDatasetKey) {
          ref.invalidate(bundledRestrictionsProvider);
          ref.invalidate(restrictionJurisdictionsProvider);
        } else if (datasetKey == tollInventoryDatasetKey) {
          ref.invalidate(tripTollInventoryProvider);
        } else if (datasetKey == taxCalendarsDatasetKey) {
          ref.invalidate(taxCatalogProvider);
        }
      };
    });

final tripTollInventoryProvider = FutureProvider<TollInventoryDataset>((
  ref,
) async {
  return (await ref.watch(tollInventoryStoreProvider.future)).load();
});

final taxCatalogStoreProvider = FutureProvider<TaxCatalogStore>((ref) async {
  final directory = await ref.watch(datasetSnapshotsDirectoryProvider.future);
  return TaxCatalogStore(
    database: ref.watch(appDatabaseProvider),
    snapshotFile: File(
      '${directory.path}${Platform.pathSeparator}tax_calendars.json',
    ),
    bundledLoader: () => rootBundle.loadString(bundledTaxCatalogAsset),
  );
});

final taxCatalogProvider = FutureProvider<TaxCatalog>((ref) async {
  return (await ref.watch(taxCatalogStoreProvider.future)).load();
});

// Startup and an open tax screen share one request and the same cooldown.
final _datasetRefreshProvider =
    Provider<Future<DatasetSyncResult?> Function(bool)>((ref) {
      Future<DatasetSyncResult?>? pending;
      DateTime? retryAfter;
      DatasetSyncResult? previous;
      return (force) {
        if (pending != null) return pending!;
        final now = DateTime.now();
        if (!force && retryAfter != null && now.isBefore(retryAfter!)) {
          return Future.value(previous);
        }
        Future<DatasetSyncResult?> run() async {
          try {
            final service = await ref.read(datasetSyncServiceProvider.future);
            if (service == null) return null;
            await ref.read(bundledRestrictionsProvider.future);
            previous = await service.sync();
            retryAfter = DateTime.now().add(const Duration(hours: 6));
            return previous;
          } catch (_) {
            retryAfter = DateTime.now().add(const Duration(minutes: 5));
            rethrow;
          } finally {
            pending = null;
          }
        }

        return pending = run();
      };
    });

final taxCatalogRefreshProvider = Provider<Future<bool> Function(bool)>((ref) {
  final refresh = ref.watch(_datasetRefreshProvider);
  return (force) async {
    final result = await refresh(force);
    return result != null &&
        (result.notModified ||
            result.imported.contains(taxCalendarsDatasetKey) ||
            result.skippedCurrent.contains(taxCalendarsDatasetKey));
  };
});

final tripTollTariffCatalogProvider = FutureProvider<TollTariffCatalog>((ref) {
  return loadTollTariffCatalog(rootBundle);
});

final datasetSyncServiceProvider = FutureProvider<DatasetSyncService?>((
  ref,
) async {
  final config = ref.watch(datasetSyncConfigProvider);
  if (config == null) {
    return null;
  }
  _validateProductDatasetConfig(config);
  final tollStore = await ref.watch(tollInventoryStoreProvider.future);
  final taxStore = await ref.watch(taxCatalogStoreProvider.future);
  return DatasetSyncService(
    database: ref.watch(appDatabaseProvider),
    preferences: ref.watch(appPreferencesProvider),
    config: config,
    importers: const {restrictionsDatasetKey: importRestrictionsDataset},
    transactionalImporters: {
      tollInventoryDatasetKey: tollStore.transactionalImporter,
      taxCalendarsDatasetKey: taxStore.transactionalImporter,
    },
    onDatasetCommitted: ref.watch(datasetSyncCommitHandlerProvider),
  );
});

final datasetSyncRunProvider = FutureProvider<DatasetSyncResult?>((ref) async {
  return ref.watch(_datasetRefreshProvider)(false);
});

final tripCameraPackSnapshotProvider = FutureProvider<TripCameraPackSnapshot>((
  ref,
) {
  return loadTripCameraPackSnapshot(rootBundle);
});

final homeBannerCampaignProvider = FutureProvider<HomeBannerCampaign?>((
  ref,
) async {
  return selectHomeBannerCampaign(
    config: await ref.watch(homeBannerConfigProvider.future),
    preferences: ref.watch(appPreferencesProvider),
  );
});

final selectedAvatarIdProvider = FutureProvider<String?>((ref) {
  return loadSelectedAvatarId(ref.watch(appPreferencesProvider));
});

final vehicleVisualOverrideProvider = FutureProvider.family<String?, String>((
  ref,
  vehicleId,
) {
  return loadVehicleVisualOverride(
    ref.watch(appPreferencesProvider),
    vehicleId,
  );
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
  final scheduler = PicoNotificationScheduler(
    settingsLoader: () =>
        AlertSettingsStore(ref.read(appDatabaseProvider)).loadAll(),
  );
  ref.onDispose(() {});
  return scheduler;
});

final vehicleObligationStoreProvider = Provider<VehicleObligationStore>((ref) {
  return VehicleObligationStore(ref.watch(appDatabaseProvider));
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(database: ref.watch(appDatabaseProvider));
});

final maintenanceRecordsProvider =
    FutureProvider.family<List<MaintenanceRecord>, String>((ref, vehicleId) {
      return ref.watch(maintenanceRepositoryProvider).listByVehicle(vehicleId);
    });

final privateVehicleDocumentStoreProvider =
    Provider<PrivateVehicleDocumentStore>((ref) {
      return PrivateVehicleDocumentStore();
    });

final vehicleAssociatedDataCleanerProvider =
    Provider<VehicleAssociatedDataCleaner>((ref) {
      final preferences = ref.watch(appPreferencesProvider);
      return VehicleAssociatedDataCleaner(
        walletStore: ref.watch(walletStoreProvider),
        defenseCaseStore: ref.watch(defenseCaseStoreProvider),
        peritajesDraftStore: PeritajesDraftStore(preferences),
        preferences: preferences,
      );
    });

final vehicleDocumentGatewayProvider = Provider<VehicleDocumentGateway>((ref) {
  return const FilePickerVehicleDocumentGateway();
});

final vehicleObligationsProvider =
    FutureProvider.family<List<VehicleObligation>, String>((ref, vehicleId) {
      return ref
          .watch(vehicleObligationStoreProvider)
          .listForVehicle(vehicleId);
    });

final vehicleObligationProvider =
    FutureProvider.family<VehicleObligation?, (String, VehicleObligationType)>((
      ref,
      key,
    ) {
      return ref.watch(vehicleObligationStoreProvider).get(key.$1, key.$2);
    });

final privateVehicleDocumentProvider =
    FutureProvider.family<
      PrivateVehicleDocumentMetadata?,
      (String, PrivateVehicleDocumentType)
    >((ref, key) {
      return ref
          .watch(privateVehicleDocumentStoreProvider)
          .get(vehicleId: key.$1, documentType: key.$2);
    });

final vehicleWalletDocumentProvider = FutureProvider.autoDispose
    .family<WalletDocument?, (String, WalletDocumentType)>((ref, key) async {
      final session = ref.watch(walletSessionProvider);
      var access = (session.accessAllowed, session.epoch);
      void sessionChanged() {
        final next = (session.accessAllowed, session.epoch);
        if (next == access) return;
        access = next;
        ref.invalidateSelf();
      }

      session.addListener(sessionChanged);
      ref.onDispose(() => session.removeListener(sessionChanged));
      if (!session.accessAllowed) return null;
      final epoch = session.epoch;
      final owner = WalletOwner.vehicle(key.$1);
      final documents = await ref.watch(walletDocumentsProvider(owner).future);
      if (!session.isAuthorizedEpoch(epoch)) return null;
      for (final document in documents) {
        if (document.owner == owner && document.type == key.$2) return document;
      }
      return null;
    }, dependencies: [walletSessionProvider, walletDocumentsProvider]);

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
  final jurisdictions = await ref.watch(
    restrictionJurisdictionsProvider.future,
  );
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
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(bogotaDateProvider);
  await ref.watch(bundledRestrictionsProvider.future);
  if (!active) return;
  final vehicles = await ref.watch(vehicleListProvider.future);
  if (!active) return;
  if (vehicles.isEmpty) {
    await _tryCancelPicoNotifications(ref, () => active);
    return;
  }

  final alertPreferences = await ref.watch(picoAlertPreferencesProvider.future);
  if (!active) return;
  if (!alertPreferences.permissionGranted) {
    if (alertPreferences.permissionRequested) {
      await _tryCancelPicoNotifications(ref, () => active);
    }
    return;
  }

  final selectedJurisdictionId = await ref.watch(
    selectedPicoJurisdictionIdProvider.future,
  );
  if (!active) return;
  final jurisdictions = await ref.watch(
    restrictionJurisdictionsProvider.future,
  );
  if (!active) return;
  final jurisdiction = _jurisdiction(jurisdictions, selectedJurisdictionId);
  if (jurisdiction == null) {
    await _tryCancelPicoNotifications(ref, () => active);
    return;
  }

  final scheduler = ref.watch(picoNotificationSchedulerProvider);
  try {
    await scheduler.initialize();
    if (!active) return;
    final deliverySettings = await scheduler.loadDeliverySettings();
    if (!active) return;
    if (!alertPreferences.enabled &&
        !deliverySettings.any(
          (s) => s.category == AlertCategory.pico && s.settings.enabled,
        )) {
      await scheduler.cancelPicoNotifications();
      return;
    }
    final plans = await buildPicoNotificationPlans(
      store: ref.watch(restrictionStoreProvider),
      currentInstant: ref.read(currentInstantProvider),
      nowBogota: ref.read(bogotaNowProvider),
      vehicles: vehicles,
      jurisdiction: jurisdiction,
      alertPreferences: alertPreferences,
      deliverySettings: deliverySettings,
      retainRecentAlarms: true,
    );
    if (!active) return;
    await scheduler.reschedule(plans);
  } on MissingPluginException {
    return;
  }
});

final obligationNotificationSyncProvider = FutureProvider<void>((ref) async {
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(bogotaDateProvider);
  final alertPreferences = await ref.watch(picoAlertPreferencesProvider.future);
  if (!active) return;
  final scheduler = ref.watch(picoNotificationSchedulerProvider);
  final vehicles = await ref.watch(vehicleListProvider.future);
  if (!active) return;
  final vehiclesById = {for (final vehicle in vehicles) vehicle.id: vehicle};
  final obligations = await ref.watch(vehicleObligationStoreProvider).listAll();
  if (!active) return;
  try {
    await scheduler.initialize();
    if (!active) return;
    final deliverySettings = await scheduler.loadDeliverySettings();
    if (!active) return;
    final plans = planObligationNotifications(
      obligations: obligations,
      vehiclesById: vehiclesById,
      nowBogota: ref.read(bogotaNowProvider),
      permissionGranted: alertPreferences.permissionGranted,
      deliverySettings: deliverySettings,
      retainRecentAlarms: true,
    );
    if (plans.isEmpty) {
      await scheduler.cancelObligationNotifications();
      return;
    }
    await scheduler.rescheduleObligationNotifications(plans);
  } on MissingPluginException {
    return;
  }
});

final maintenanceNotificationSyncProvider = FutureProvider<void>((ref) async {
  var active = true;
  ref.onDispose(() => active = false);
  ref.watch(bogotaDateProvider);
  final preferences = await ref.watch(picoAlertPreferencesProvider.future);
  if (!active) return;
  final scheduler = ref.watch(picoNotificationSchedulerProvider);
  if (!preferences.permissionGranted) {
    try {
      await scheduler.cancelMaintenanceNotifications();
    } on MissingPluginException {
      return;
    }
    return;
  }
  final vehicles = await ref.watch(vehicleListProvider.future);
  if (!active) return;
  final reminders = <MaintenanceReminder>[];
  final maintenancePreferences = ref.watch(
    maintenanceNotificationPreferencesProvider,
  );
  for (final vehicle in vehicles) {
    if (!await maintenancePreferences.isEnabled(vehicle.id)) {
      continue;
    }
    if (!active) return;
    final records = await ref
        .watch(maintenanceRepositoryProvider)
        .listByVehicle(vehicle.id);
    if (!active) return;
    final latestOdometer = records
        .map((record) => record.odometer)
        .whereType<int>()
        .fold<int?>(null, (latest, value) {
          if (latest == null || value > latest) return value;
          return latest;
        });
    reminders.addAll(
      planMaintenanceReminders(
        vehicleId: vehicle.id,
        records: records,
        now: ref.read(bogotaNowProvider),
        latestOdometer: latestOdometer,
      ),
    );
  }
  try {
    await scheduler.initialize();
    if (!active) return;
    await scheduler.rescheduleMaintenanceNotifications(
      reminders,
      platesByVehicleId: const {},
    );
  } on MissingPluginException {
    return;
  }
});

final currentInstantProvider = Provider<DateTime>((ref) {
  return ref.watch(appClockProvider);
});

final bogotaNowProvider = Provider<DateTime>((ref) {
  return bogotaWallClock(ref.watch(currentInstantProvider));
});

final bogotaDateProvider = Provider<DateTime>((ref) {
  final date = ref.watch(
    bogotaNowProvider.select((now) => (now.year, now.month, now.day)),
  );
  return DateTime(date.$1, date.$2, date.$3);
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

Future<void> _tryCancelPicoNotifications(
  Ref ref,
  bool Function() isActive,
) async {
  try {
    final scheduler = ref.watch(picoNotificationSchedulerProvider);
    await scheduler.initialize();
    if (!isActive()) return;
    await scheduler.cancelPicoNotifications();
  } on MissingPluginException {
    return;
  }
}

void _validateProductDatasetConfig(AppConfig config) {
  final cdn = config.cdnBaseUri;
  final manifest = config.manifestUri;
  if (cdn.scheme != 'https' || manifest.scheme != 'https') {
    throw ArgumentError('CDN_BASE_URL and MANIFEST_URL must use HTTPS.');
  }
  if (cdn.host != manifest.host ||
      _effectiveUriPort(cdn) != _effectiveUriPort(manifest)) {
    throw ArgumentError('MANIFEST_URL must use the CDN_BASE_URL origin.');
  }
}

int _effectiveUriPort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }
  return uri.scheme == 'https' ? 443 : 80;
}
