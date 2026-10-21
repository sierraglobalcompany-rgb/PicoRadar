import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
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
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tax commit reloads the catalog but unrelated commits do not', () async {
    final store = _CatalogStore(_catalog('bundled'));
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [taxCatalogStoreProvider.overrideWith((ref) async => store)],
    );
    addTearDown(container.dispose);

    final first = await container.read(taxCatalogProvider.future);
    store.catalog = _catalog('installed');
    final committed = container.read(datasetSyncCommitHandlerProvider);
    for (final key in [
      restrictionsDatasetKey,
      tollInventoryDatasetKey,
      'unknown_dataset',
    ]) {
      committed(key);
      expect(await container.read(taxCatalogProvider.future), same(first));
    }
    expect(store.loads, 1);

    committed(taxCalendarsDatasetKey);
    expect(
      (await container.read(taxCatalogProvider.future)).version,
      'installed',
    );
    expect(store.loads, 2);
  });

  test(
    'production composition imports tax bytes and refreshes its consumer',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final root = await Directory.systemTemp.createTemp(
        'picoradar_tax_composition_',
      );
      addTearDown(() => root.delete(recursive: true));
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
          datasetSyncConfigProvider.overrideWithValue(
            AppConfig(cdnBaseUrl: 'https://datasets.example.org'),
          ),
          datasetSnapshotsDirectoryProvider.overrideWith((ref) async => root),
        ],
      );
      addTearDown(container.dispose);
      final before = await container.read(taxCatalogProvider.future);
      final service = (await container.read(
        datasetSyncServiceProvider.future,
      ))!;
      addTearDown(() => service.http.close(force: true));
      final bytes = utf8.encode(jsonEncode(_payload('sync-test-v2')));
      final digest = await Sha256().hash(bytes);
      final sha = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final transport = _MemoryHttp({
        '/v1/manifest.json': utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'generatedAt': '2026-09-13T12:00:00Z',
            'minAppVersion': '1.0.0',
            'datasets': {
              taxCalendarsDatasetKey: {
                'version': 'sync-test-v2',
                'url': '/tax-calendars.json',
                'sha256': sha,
              },
            },
            'features': {'ads': false, 'cloud': false, 'paidDocuments': false},
          }),
        ),
        '/tax-calendars.json': bytes,
      });
      service.http.httpClientAdapter = transport;

      final result = await service.sync();
      final after = await container.read(taxCatalogProvider.future);
      final installed =
          await (database.select(database.datasetVersions)
                ..where((row) => row.datasetKey.equals(taxCalendarsDatasetKey)))
              .getSingle();

      expect(result.imported, [taxCalendarsDatasetKey]);
      expect(result.skippedMissingImporter, isEmpty);
      expect(after.version, 'sync-test-v2');
      expect(after, isNot(same(before)));
      expect(installed.version, after.version);
      expect(installed.sha256, sha);
      expect(installed.status, 'installed');
      final store = await container.read(taxCatalogStoreProvider.future);
      expect(
        await File('${store.snapshotFile.path}.$sha').readAsBytes(),
        bytes,
      );
      expect(transport.paths, ['/v1/manifest.json', '/tax-calendars.json']);
    },
  );

  test(
    'no CDN returns false for automatic and manual refresh without storage',
    () async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          datasetSyncConfigProvider.overrideWithValue(null),
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('No database expected'),
          ),
          datasetSnapshotsDirectoryProvider.overrideWith(
            (ref) async => throw StateError('No storage expected'),
          ),
          bundledRestrictionsProvider.overrideWith(
            (ref) async => throw StateError('No seed expected'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(datasetSyncServiceProvider.future), isNull);
      final refresh = container.read(taxCatalogRefreshProvider);
      expect(await container.read(datasetSyncRunProvider.future), isNull);
      expect(await refresh(false), isFalse);
      expect(await refresh(true), isFalse);
      expect(await refresh(false), isFalse);
    },
  );

  for (final startupFirst in [true, false]) {
    test(
      'startup and automatic/manual tax refresh share one flight (startupFirst=$startupFirst)',
      () async {
        final response = Completer<DatasetSyncResult>();
        final service = _SyncService(() => response.future);
        final container = _syncContainer(service);
        final refresh = container.read(taxCatalogRefreshProvider);
        final Future<DatasetSyncResult?> startup;
        final Future<bool> automatic;
        if (startupFirst) {
          startup = container.read(datasetSyncRunProvider.future);
          automatic = refresh(false);
        } else {
          automatic = refresh(false);
          startup = container.read(datasetSyncRunProvider.future);
        }
        final manual = refresh(true);
        await _flush();
        expect(service.calls, 1);
        const result = DatasetSyncResult(imported: [taxCalendarsDatasetKey]);
        response.complete(result);
        expect(await startup, same(result));
        expect(await automatic, isTrue);
        expect(await manual, isTrue);
        expect(service.calls, 1);
      },
    );
  }

  test(
    'all refresh entry points wait for service and bundled seed readiness',
    () async {
      final ready = Completer<DatasetSyncService?>();
      final seed = Completer<void>();
      var seedLoads = 0;
      final service = _SyncService(
        () async => const DatasetSyncResult(notModified: true),
      );
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          datasetSyncServiceProvider.overrideWith((ref) => ready.future),
          bundledRestrictionsProvider.overrideWith((ref) {
            seedLoads++;
            return seed.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final startup = container.read(datasetSyncRunProvider.future);
      final refresh = container.read(taxCatalogRefreshProvider);
      final automatic = refresh(false);
      final manual = refresh(true);
      await _flush();
      expect(service.calls, 0);
      ready.complete(service);
      await _flush();
      expect(seedLoads, 1);
      expect(service.calls, 0);
      seed.complete();
      expect((await startup)!.notModified, isTrue);
      expect(await automatic, isTrue);
      expect(await manual, isTrue);
      expect(service.calls, 1);
    },
  );

  for (final notModified in [true, false]) {
    test(
      'success suppresses immediate automatic refresh; manual bypasses (304=$notModified)',
      () async {
        final service = _SyncService(
          () async => DatasetSyncResult(
            notModified: notModified,
            imported: notModified ? const [] : const [taxCalendarsDatasetKey],
          ),
        );
        final container = _syncContainer(service);
        final startup = await container.read(datasetSyncRunProvider.future);
        final refresh = container.read(taxCatalogRefreshProvider);
        for (var i = 0; i < 3; i++) {
          expect(await refresh(false), isTrue);
          container.invalidate(datasetSyncRunProvider);
          expect(
            await container.read(datasetSyncRunProvider.future),
            same(startup),
          );
        }
        expect(service.calls, 1);
        expect(await refresh(true), isTrue);
        expect(service.calls, 2);
        expect(await refresh(false), isTrue);
        expect(service.calls, 2);
      },
    );
  }

  test('shared failure reaches all callers, preserves catalog and cools automatic retries', () async {
    final failed = Completer<DatasetSyncResult>();
    var next = failed.future;
    final service = _SyncService(() => next);
    final store = _CatalogStore(_catalog('last-usable'));
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        datasetSyncServiceProvider.overrideWith((ref) async => service),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        taxCatalogStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);
    final visible = await container.read(taxCatalogProvider.future);
    final refresh = container.read(taxCatalogRefreshProvider);
    final startup = container.read(datasetSyncRunProvider.future);
    final automatic = refresh(false);
    final manual = refresh(true);
    const failure = DatasetSyncException('Synthetic offline failure');
    final failures = Future.wait([
      expectLater(startup, throwsA(same(failure))),
      expectLater(automatic, throwsA(same(failure))),
      expectLater(manual, throwsA(same(failure))),
    ]);
    await _flush();
    expect(service.calls, 1);
    failed.completeError(failure);
    await failures;
    expect(await container.read(taxCatalogProvider.future), same(visible));
    expect(store.loads, 1);
    expect(await refresh(false), isFalse);
    container.invalidate(datasetSyncRunProvider);
    expect(await container.read(datasetSyncRunProvider.future), isNull);
    expect(service.calls, 1);

    next = Future.value(const DatasetSyncResult(notModified: true));
    expect(await refresh(true), isTrue);
    expect(service.calls, 2);
    expect(await refresh(false), isTrue);
    expect(service.calls, 2);
  });

  test(
    'seed failure releases the flight and manual retry can recover',
    () async {
      var seedFails = true;
      final service = _SyncService(
        () async => const DatasetSyncResult(imported: [taxCalendarsDatasetKey]),
      );
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          datasetSyncServiceProvider.overrideWith((ref) async => service),
          bundledRestrictionsProvider.overrideWith((ref) async {
            if (seedFails) throw StateError('Synthetic seed failure');
          }),
        ],
      );
      addTearDown(container.dispose);
      final refresh = container.read(taxCatalogRefreshProvider);
      await expectLater(refresh(false), throwsA(isA<StateError>()));
      expect(service.calls, 0);
      expect(await refresh(false), isFalse);
      seedFails = false;
      container.invalidate(bundledRestrictionsProvider);
      expect(await refresh(true), isTrue);
      expect(service.calls, 1);
    },
  );

  for (final (label, result, expected) in [
    ('empty manifest', const DatasetSyncResult(), false),
    (
      'unrelated import',
      const DatasetSyncResult(imported: [tollInventoryDatasetKey]),
      false,
    ),
    (
      'missing tax importer',
      const DatasetSyncResult(skippedMissingImporter: [taxCalendarsDatasetKey]),
      false,
    ),
    (
      'current tax dataset',
      const DatasetSyncResult(skippedCurrent: [taxCalendarsDatasetKey]),
      true,
    ),
  ]) {
    test('tax refresh reports availability accurately for $label', () async {
      final service = _SyncService(() async => result);
      final container = _syncContainer(service);
      expect(await container.read(taxCatalogRefreshProvider)(true), expected);
      expect(service.calls, 1);
    });
  }
}

ProviderContainer _syncContainer(_SyncService service) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      datasetSyncServiceProvider.overrideWith((ref) async => service),
      bundledRestrictionsProvider.overrideWith((ref) async {}),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _SyncService extends Fake implements DatasetSyncService {
  _SyncService(this.run);
  final Future<DatasetSyncResult> Function() run;
  int calls = 0;

  @override
  Future<DatasetSyncResult> sync({CancelToken? cancelToken}) {
    calls++;
    return run();
  }
}

class _CatalogStore extends Fake implements TaxCatalogStore {
  _CatalogStore(this.catalog);
  TaxCatalog catalog;
  int loads = 0;

  @override
  Future<TaxCatalog> load() async {
    loads++;
    return catalog;
  }
}

class _MemoryPreferences extends Fake implements AppPreferences {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class _MemoryHttp implements HttpClientAdapter {
  _MemoryHttp(this.responses);
  final Map<String, List<int>> responses;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final bytes = responses[options.uri.path];
    if (bytes == null) throw StateError('Unexpected synthetic HTTP request');
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        HttpHeaders.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TaxCatalog _catalog(String version) => TaxCatalog.fromJson(_payload(version));

Map<String, dynamic> _payload(String version) => {
  'schemaVersion': 1,
  'datasetKey': taxCalendarsDatasetKey,
  'version': version,
  'generatedAt': '2026-09-13T12:00:00Z',
  'authorities': [
    {
      'id': 'bogota',
      'territoryCode': '11',
      'territoryName': 'Bogota D. C.',
      'name': 'Synthetic tax authority',
      'institutionalUrl': 'https://hacienda.example.org/',
      'portalUrl': null,
      'sourceUrls': ['https://hacienda.example.org/directorio'],
      'reviewedAt': null,
    },
  ],
  'calendars': <Object?>[],
};
