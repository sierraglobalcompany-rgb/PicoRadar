import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  test('product sync rejects an HTTP CDN before storage', () async {
    var storageLoads = 0;
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(cdnBaseUrl: 'http://datasets.example.test'),
        ),
        tollInventoryStoreProvider.overrideWith((ref) async {
          storageLoads += 1;
          throw StateError('storage must not be initialized');
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(datasetSyncServiceProvider.future),
      throwsA(isA<ArgumentError>()),
    );
    expect(storageLoads, 0);
  });

  test('product sync rejects a cross-origin manifest before storage', () async {
    var storageLoads = 0;
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(
            cdnBaseUrl: 'https://datasets.example.test',
            manifestUrl: 'https://other.example.test/v1/manifest.json',
          ),
        ),
        tollInventoryStoreProvider.overrideWith((ref) async {
          storageLoads += 1;
          throw StateError('storage must not be initialized');
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(datasetSyncServiceProvider.future),
      throwsA(isA<ArgumentError>()),
    );
    expect(storageLoads, 0);
  });

  test('remote sync waits for an in-flight bundled restriction seed', () async {
    final seedStarted = Completer<void>();
    final releaseSeed = Completer<void>();
    var syncStarted = false;
    final service = _StubDatasetSyncService(
      database: database,
      run: () async {
        syncStarted = true;
        await _writeRestrictionVersion(database, 'remote', 'installed');
        return const DatasetSyncResult(imported: [restrictionsDatasetKey]);
      },
    );
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        datasetSyncServiceProvider.overrideWith((ref) async => service),
        bundledRestrictionsProvider.overrideWith((ref) async {
          final installed = await _restrictionVersion(database);
          if (installed != null) {
            return;
          }
          if (!seedStarted.isCompleted) {
            seedStarted.complete();
          }
          await releaseSeed.future;
          await _writeRestrictionVersion(database, 'bundled', 'bundled');
        }),
      ],
    );
    addTearDown(container.dispose);

    final seedFuture = container.read(bundledRestrictionsProvider.future);
    await seedStarted.future;
    final syncFuture = container.read(datasetSyncRunProvider.future);
    await Future<void>.delayed(Duration.zero);
    final syncRacedSeed = syncStarted;
    releaseSeed.complete();
    await seedFuture;
    await syncFuture;

    expect(syncRacedSeed, isFalse);
    expect(await _restrictionVersion(database), 'remote');
  });

  test('successful sync invalidates restriction and toll consumers', () async {
    var bundledLoads = 0;
    var jurisdictionLoads = 0;
    var tollLoads = 0;
    final tollDataset = TollInventoryDataset.fromJsonString(
      await File('assets/catalogs/tolls_inventory_v1.json').readAsString(),
    );
    late ProviderContainer container;
    final service = _StubDatasetSyncService(
      database: database,
      run: () async {
        final onCommitted = container.read(datasetSyncCommitHandlerProvider);
        onCommitted(restrictionsDatasetKey);
        onCommitted(tollInventoryDatasetKey);
        return const DatasetSyncResult(
          imported: [restrictionsDatasetKey, tollInventoryDatasetKey],
        );
      },
    );
    container = ProviderContainer(
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

  test(
    'partial sync invalidates committed restrictions and preserves tolls',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'picoradar_partial_sync_',
      );
      addTearDown(() => root.delete(recursive: true));
      final bundledTollJson = await File(
        'assets/catalogs/tolls_inventory_v1.json',
      ).readAsString();
      final oldToll = TollInventoryDataset.fromJsonString(bundledTollJson);
      final tollStore = TollInventoryStore(
        database: database,
        snapshotFile: File('${root.path}${Platform.pathSeparator}tolls.json'),
        bundledLoader: () async => bundledTollJson,
      );
      final restrictionBytes = await File(
        'assets/datasets/restrictions/restrictions_v1.json',
      ).readAsBytes();
      final restrictionJson =
          jsonDecode(utf8.decode(restrictionBytes)) as Map<String, dynamic>;
      final invalidTollBytes = utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'datasetKey': tollInventoryDatasetKey,
          'version': 'invalid-tolls',
          'generatedAt': '2026-09-05T00:00:00Z',
          'records': <Object?>[],
        }),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final manifest = {
        'schemaVersion': 1,
        'generatedAt': '2026-09-05T00:00:00Z',
        'minAppVersion': '1.0.0',
        'datasets': {
          restrictionsDatasetKey: {
            'version': restrictionJson['version'],
            'url': '/restrictions.json',
            'sha256': await _sha256Hex(restrictionBytes),
          },
          tollInventoryDatasetKey: {
            'version': 'invalid-tolls',
            'url': '/tolls.json',
            'sha256': await _sha256Hex(invalidTollBytes),
          },
        },
        'features': {'ads': false, 'cloud': false, 'paidDocuments': false},
      };
      server.listen((request) async {
        final bytes = switch (request.uri.path) {
          '/v1/manifest.json' => utf8.encode(jsonEncode(manifest)),
          '/restrictions.json' => restrictionBytes,
          '/tolls.json' => invalidTollBytes,
          _ => <int>[],
        };
        if (bytes.isEmpty) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.add(bytes);
        }
        await request.response.close();
      });

      var bundledLoads = 0;
      var jurisdictionLoads = 0;
      var tollLoads = 0;
      final origin = 'http://${server.address.address}:${server.port}';
      late ProviderContainer container;
      final service = DatasetSyncService(
        database: database,
        preferences: _MemoryPreferences(),
        config: AppConfig(cdnBaseUrl: origin),
        importers: const {restrictionsDatasetKey: importRestrictionsDataset},
        transactionalImporters: {
          tollInventoryDatasetKey: tollStore.transactionalImporter,
        },
        tempDirectory: root,
        onDatasetCommitted: (datasetKey) {
          container.read(datasetSyncCommitHandlerProvider)(datasetKey);
        },
      );
      container = ProviderContainer(
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
            return oldToll;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bundledRestrictionsProvider.future);
      await container.read(restrictionJurisdictionsProvider.future);
      final visibleToll = await container.read(
        tripTollInventoryProvider.future,
      );
      await expectLater(
        container.read(datasetSyncRunProvider.future),
        throwsA(isA<DatasetSyncException>()),
      );
      await container.read(bundledRestrictionsProvider.future);
      await container.read(restrictionJurisdictionsProvider.future);
      final tollAfterFailure = await container.read(
        tripTollInventoryProvider.future,
      );
      final restrictions = await database
          .select(database.restrictionCoverages)
          .get();

      expect(restrictions, isNotEmpty);
      expect(bundledLoads, 2);
      expect(jurisdictionLoads, 2);
      expect(tollLoads, 1);
      expect(tollAfterFailure, same(visibleToll));
    },
  );

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

Future<void> _writeRestrictionVersion(
  AppDatabase database,
  String version,
  String status,
) async {
  await database
      .into(database.datasetVersions)
      .insertOnConflictUpdate(
        DatasetVersionsCompanion.insert(
          id: restrictionsDatasetKey,
          datasetKey: restrictionsDatasetKey,
          version: version,
          status: status,
          appliedAt: Value(DateTime.now().toUtc()),
        ),
      );
}

Future<String?> _restrictionVersion(AppDatabase database) async {
  final rows = await (database.select(
    database.datasetVersions,
  )..where((row) => row.datasetKey.equals(restrictionsDatasetKey))).get();
  return rows.isEmpty ? null : rows.single.version;
}

Future<String> _sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
