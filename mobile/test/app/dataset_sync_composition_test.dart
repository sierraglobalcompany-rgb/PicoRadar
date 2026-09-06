import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('missing CDN configuration performs no sync or storage work', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        datasetSyncConfigProvider.overrideWithValue(null),
        tollInventoryStoreProvider.overrideWith((ref) async {
          throw StateError('storage must not be initialized');
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(datasetSyncRunProvider.future), isNull);
  });

  test('production service composes restriction and toll importers', () async {
    final root = await Directory.systemTemp.createTemp(
      'picoradar_sync_composition_',
    );
    addTearDown(() => root.delete(recursive: true));
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(cdnBaseUrl: 'https://datasets.example.test'),
        ),
        datasetSnapshotsDirectoryProvider.overrideWith((ref) async => root),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(datasetSyncServiceProvider.future);

    expect(service, isNotNull);
    expect(service!.importers.keys, {restrictionsDatasetKey});
    expect(service.transactionalImporters.keys, {tollInventoryDatasetKey});
  });

  test('successful sync invalidates restriction and toll consumers', () async {
    var bundledLoads = 0;
    var jurisdictionLoads = 0;
    var tollLoads = 0;
    final tollDataset = TollInventoryDataset.fromJsonString(
      await File('assets/catalogs/tolls_inventory_v1.json').readAsString(),
    );
    final service = _StubDatasetSyncService(
      database: database,
      run: () async => const DatasetSyncResult(),
    );
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        datasetSyncServiceProvider.overrideWith((ref) async => service),
        bundledRestrictionsProvider.overrideWith((ref) async {
          bundledLoads += 1;
        }),
        restrictionJurisdictionsProvider.overrideWith((ref) async {
          jurisdictionLoads += 1;
          return [];
        }),
        tripTollInventoryProvider.overrideWith((ref) async {
          tollLoads += 1;
          return tollDataset;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bundledRestrictionsProvider.future);
    await container.read(restrictionJurisdictionsProvider.future);
    await container.read(tripTollInventoryProvider.future);
    await container.read(datasetSyncRunProvider.future);
    await container.read(bundledRestrictionsProvider.future);
    await container.read(restrictionJurisdictionsProvider.future);
    await container.read(tripTollInventoryProvider.future);

    expect(bundledLoads, 2);
    expect(jurisdictionLoads, 2);
    expect(tollLoads, 2);
  });

  test('failed sync preserves existing consumer values', () async {
    var bundledLoads = 0;
    var jurisdictionLoads = 0;
    var tollLoads = 0;
    final tollDataset = TollInventoryDataset.fromJsonString(
      await File('assets/catalogs/tolls_inventory_v1.json').readAsString(),
    );
    final service = _StubDatasetSyncService(
      database: database,
      run: () async => throw const DatasetSyncException('offline'),
    );
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        datasetSyncServiceProvider.overrideWith((ref) async => service),
        bundledRestrictionsProvider.overrideWith((ref) async {
          bundledLoads += 1;
        }),
        restrictionJurisdictionsProvider.overrideWith((ref) async {
          jurisdictionLoads += 1;
          return [];
        }),
        tripTollInventoryProvider.overrideWith((ref) async {
          tollLoads += 1;
          return tollDataset;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bundledRestrictionsProvider.future);
    await container.read(restrictionJurisdictionsProvider.future);
    await container.read(tripTollInventoryProvider.future);
    await expectLater(
      container.read(datasetSyncRunProvider.future),
      throwsA(isA<DatasetSyncException>()),
    );
    await container.read(bundledRestrictionsProvider.future);
    await container.read(restrictionJurisdictionsProvider.future);
    await container.read(tripTollInventoryProvider.future);

    expect(bundledLoads, 1);
    expect(jurisdictionLoads, 1);
    expect(tollLoads, 1);
  });
}

class _StubDatasetSyncService extends DatasetSyncService {
  _StubDatasetSyncService({required super.database, required this.run})
    : super(
        preferences: _MemoryPreferences(),
        config: AppConfig(cdnBaseUrl: 'https://datasets.example.test'),
        importers: const {},
      );

  final Future<DatasetSyncResult> Function() run;

  @override
  Future<DatasetSyncResult> sync({CancelToken? cancelToken}) => run();
}

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
