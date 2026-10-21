import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/bounded_stream.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late _MemoryPreferences preferences;
  late Directory tempDirectory;
  late Directory snapshotDirectory;
  late _HttpFixtureServer server;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    preferences = _MemoryPreferences();
    tempDirectory = await Directory.systemTemp.createTemp(
      'picoradar_sync_hardening_',
    );
    snapshotDirectory = await Directory.systemTemp.createTemp(
      'picoradar_toll_snapshot_',
    );
    server = await _HttpFixtureServer.start();
  });

  tearDown(() async {
    await server.close();
    await db.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
    if (await snapshotDirectory.exists()) {
      await snapshotDirectory.delete(recursive: true);
    }
  });

  test('Python compiler bytes reach the engine through HTTP and Drift', () async {
    expect(
      (await _compiledRuleEvaluation(db)).status,
      RestrictionStatus.unknown,
    );
    final firstOutput = Directory('${tempDirectory.path}/compiled-first');
    final secondOutput = Directory('${tempDirectory.path}/compiled-second');
    await _compileViajeR2Fixture(firstOutput);
    await _compileViajeR2Fixture(secondOutput);

    final manifestFile = File(
      '${firstOutput.path}/data/releases/viaje_r2/local_test/manifest.json',
    );
    final restrictionFile = File(
      '${firstOutput.path}/mobile/assets/datasets/restrictions/restrictions_v1.json',
    );
    final tollFile = File(
      '${firstOutput.path}/mobile/assets/catalogs/tolls_inventory_v1.json',
    );
    final manifestBytes = await manifestFile.readAsBytes();
    final restrictionBytes = await restrictionFile.readAsBytes();
    final tollBytes = await tollFile.readAsBytes();
    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    final restrictionEntry = Map<String, dynamic>.from(
      (manifest['datasets'] as Map)[restrictionsDatasetKey] as Map,
    );

    expect(
      await File(
        '${secondOutput.path}/mobile/assets/datasets/restrictions/restrictions_v1.json',
      ).readAsBytes(),
      restrictionBytes,
    );
    expect(await _sha256Hex(restrictionBytes), restrictionEntry['sha256']);
    expect(utf8.decode(restrictionBytes), contains('NON_PRODUCTION_FIXTURE'));

    _serveBytes(server, '/v1/manifest.json', manifestBytes, etag: '"viaje-r2"');
    _serveBytes(
      server,
      '/assets/datasets/restrictions/restrictions_v1.json',
      restrictionBytes,
    );
    _serveBytes(server, '/assets/catalogs/tolls_inventory_v1.json', tollBytes);
    final snapshot = File('${snapshotDirectory.path}/tolls.json');
    final tollStore = TollInventoryStore(
      database: db,
      snapshotFile: snapshot,
      bundledLoader: () =>
          File('assets/catalogs/tolls_inventory_v1.json').readAsString(),
    );

    final result = await _service(
      db,
      preferences,
      tempDirectory,
      server,
      importers: {restrictionsDatasetKey: importRestrictionsDataset},
      transactionalImporters: {
        tollInventoryDatasetKey: tollStore.transactionalImporter,
      },
      currentTime: DateTime.utc(2026, 9, 6, 12),
    ).sync();

    expect(result.imported, [restrictionsDatasetKey, tollInventoryDatasetKey]);
    final tollSha = (manifest['datasets'] as Map)['tolls_inventory']['sha256'];
    expect(await File('${snapshot.path}.$tollSha').readAsBytes(), tollBytes);
    expect((await tollStore.load()).records, hasLength(184));
    expect((await tollStore.load()).sourceTimestamp, DateTime.utc(2026, 9, 5));
    expect(await _version(db, tollInventoryDatasetKey), '2026.09.05-viaje-r2');
    final compiledCoverage = (await db.select(db.restrictionCoverages).get())
        .singleWhere((row) => row.id == 'co-ant-medellin:car:private');
    expect(compiledCoverage.rulesJson, contains('NON_PRODUCTION_FIXTURE'));
    expect(
      (await _compiledRuleEvaluation(db)).status,
      RestrictionStatus.restricted,
    );
    expect(
      (await _compiledRuleEvaluation(db, plate: 'ABC154')).status,
      RestrictionStatus.allowed,
    );
    expect(
      (await _compiledRuleEvaluation(db, isHoliday: true)).status,
      RestrictionStatus.allowed,
    );
    expect(
      (await _compiledRuleEvaluation(
        db,
        localDateTime: DateTime(2027, 1, 3, 8),
      )).status,
      RestrictionStatus.stale,
    );
    expect(
      await preferences.getString(DatasetSyncService.manifestEtagPreferenceKey),
      '"viaje-r2"',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('rejects payload metadata that differs from manifest', () async {
    final payload = await _payload({
      'schemaVersion': 1,
      'datasetKey': 'tolls_inventory',
      'version': '2.0',
      'generatedAt': '2026-09-04T00:00:00Z',
      'rows': <Object?>[],
    });
    _serveManifest(server, {
      'tolls_inventory': _entry(
        version: '2.1',
        path: '/tolls.json',
        sha256: payload.sha256,
        sourceTimestamp: '2026-09-05T00:00:00Z',
      ),
    });
    _serveBytes(server, '/tolls.json', payload.bytes);
    var imported = false;

    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'tolls_inventory': (_, _) async => imported = true},
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(imported, isFalse);
    expect(await _version(db, 'tolls_inventory'), isNull);
  });

  test('rejects future, expired, and incompatible manifests', () async {
    for (final manifest in [
      _manifest(<String, Object?>{}, generatedAt: '2026-09-06T00:00:00Z'),
      _manifest(<String, Object?>{}, minAppVersion: '2.0.0'),
      _manifest({
        'restrictions': _entry(
          version: '2.0',
          path: '/unused.json',
          sha256: 'a' * 64,
          expiresAt: '2026-09-04T23:59:59Z',
        ),
      }),
    ]) {
      _serveJson(server, '/v1/manifest.json', manifest);
      await expectLater(
        _service(
          db,
          preferences,
          tempDirectory,
          server,
          importers: {'restrictions': (_, _) async {}},
        ).sync(),
        throwsA(isA<DatasetSyncException>()),
      );
    }
    expect(await db.select(db.datasetVersions).get(), isEmpty);
  });

  test('caps a chunked manifest without Content-Length', () async {
    final oversizedManifest = utf8.encode(
      jsonEncode({..._manifest(<String, Object?>{}), 'padding': 'x' * 512}),
    );
    _serveChunked(
      server,
      '/v1/manifest.json',
      oversizedManifest,
      chunkSize: 17,
    );

    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        maxManifestBytes: 96,
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await db.select(db.datasetVersions).get(), isEmpty);
  });

  test('rejects same-version hash replay and numeric downgrade', () async {
    await _insertVersion(db, 'restrictions', version: '2.0', sha256: 'a' * 64);
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/replay.json',
        sha256: 'b' * 64,
      ),
    });
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    _serveManifest(server, {
      'restrictions': _entry(
        version: '1.9',
        path: '/downgrade.json',
        sha256: 'c' * 64,
      ),
    });
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await _version(db, 'restrictions'), '2.0');
  });

  test(
    'rejects opaque version changes without a publication revision',
    () async {
      await _insertVersion(
        db,
        restrictionsDatasetKey,
        version: '2026.09.06-newer',
        sha256: 'a' * 64,
      );
      final payload = await _payload({
        'datasetKey': restrictionsDatasetKey,
        'version': '2026.09.05-older',
        'rows': <Object?>[],
      });
      _serveManifest(server, {
        restrictionsDatasetKey: _entry(
          version: '2026.09.05-older',
          path: '/opaque-rollback.json',
          sha256: payload.sha256,
        ),
      });
      _serveBytes(server, '/opaque-rollback.json', payload.bytes);
      var imported = false;

      await expectLater(
        _service(
          db,
          preferences,
          tempDirectory,
          server,
          importers: {restrictionsDatasetKey: (_, _) async => imported = true},
        ).sync(),
        throwsA(isA<DatasetSyncException>()),
      );

      expect(imported, isFalse);
      expect(await _version(db, restrictionsDatasetKey), '2026.09.06-newer');
    },
  );

  test(
    'accepts an older payload only with a newer publication revision',
    () async {
      await _insertVersion(
        db,
        restrictionsDatasetKey,
        version: '2',
        sha256: 'a' * 64,
      );
      final payload = await _payload({
        'datasetKey': restrictionsDatasetKey,
        'version': '1',
        'rows': <Object?>[],
      });
      _serveManifest(server, {
        restrictionsDatasetKey: _entry(
          version: '1',
          path: '/authorized-rollback.json',
          sha256: payload.sha256,
          publicationRevision: 2,
        ),
      });
      _serveBytes(server, '/authorized-rollback.json', payload.bytes);

      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {restrictionsDatasetKey: (_, _) async {}},
      ).sync();
      final revision = await db
          .customSelect(
            'SELECT publication_revision FROM dataset_versions '
            'WHERE dataset_key = ?',
            variables: [Variable.withString(restrictionsDatasetKey)],
          )
          .getSingle();

      expect(result.imported, [restrictionsDatasetKey]);
      expect(await _version(db, restrictionsDatasetKey), '1');
      expect(revision.read<int>('publication_revision'), 2);
    },
  );

  test('bounded file writes cancel an oversized producer and close the partial file', () async {
    final destination = File('${tempDirectory.path}/bounded.bin');
    var delivered = 0;
    var producerFinalized = false;

    Stream<List<int>> oversizedChunks() async* {
      try {
        for (var index = 0; index < 17; index++) {
          yield List<int>.filled(13, index);
          delivered++;
        }
      } finally {
        producerFinalized = true;
      }
    }

    await expectLater(
      writeBoundedStream(
        oversizedChunks(),
        destination,
        maxBytes: 48,
        label: 'Test dataset',
      ),
      throwsA(isA<BoundedStreamException>()),
    );

    expect(producerFinalized, isTrue);
    expect(delivered, lessThan(17));
    expect(await destination.length(), lessThanOrEqualTo(48));
  });

  test('caps a chunked dataset without Content-Length', () async {
    final oversized = await _payload({'rows': 'x' * 200});
    var importCalls = 0;
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/oversized.json',
        sha256: oversized.sha256,
      ),
    });
    _serveChunked(
      server,
      '/oversized.json',
      oversized.bytes,
      chunkSize: 13,
      chunkDelay: const Duration(milliseconds: 3),
    );
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {
          'restrictions': (_, _) async {
            importCalls++;
          },
        },
        maxDownloadBytes: 48,
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await db.select(db.datasetVersions).get(), isEmpty);
    expect(importCalls, 0);
    expect(await tempDirectory.list().toList(), isEmpty);
  });

  test('caps high-expansion gzip while decoding its stream', () async {
    final compressed = await _payload({'rows': 'x' * 100000}, compressed: true);
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/expanded.json.gz',
        sha256: compressed.sha256,
        contentEncoding: 'gzip',
      ),
    });
    _serveChunked(server, '/expanded.json.gz', compressed.bytes, chunkSize: 11);
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
        maxDecodedBytes: 1024,
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await db.select(db.datasetVersions).get(), isEmpty);
  });

  test('HTTP failure and redirect preserve the installed version', () async {
    await _insertVersion(db, 'restrictions', version: '1.0');
    server.handlers['/v1/manifest.json'] = (request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    };
    await expectLater(
      _service(db, preferences, tempDirectory, server).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/redirect',
        sha256: 'a' * 64,
      ),
    });
    server.handlers['/redirect'] = (request) async {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'https://example.com/tolls.json',
      );
      await request.response.close();
    };
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await _version(db, 'restrictions'), '1.0');
  });

  test('timeout and cancellation preserve the installed version', () async {
    await _insertVersion(db, 'restrictions', version: '1.0');
    final payload = await _payload({'rows': <Object?>[]});
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/slow.json',
        sha256: payload.sha256,
      ),
    });
    server.handlers['/slow.json'] = (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      request.response.add(payload.bytes);
      await request.response.close();
    };
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
        receiveTimeout: const Duration(milliseconds: 30),
      ).sync(),
      throwsA(anyOf(isA<DatasetSyncException>(), isA<DioException>())),
    );
    expect(await _version(db, 'restrictions'), '1.0');

    final cancelToken = CancelToken();
    Timer(const Duration(milliseconds: 30), () => cancelToken.cancel('test'));
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync(cancelToken: cancelToken),
      throwsA(anyOf(isA<DatasetSyncException>(), isA<DioException>())),
    );
    expect(await _version(db, 'restrictions'), '1.0');
  });

  test(
    'version write failure after replacement restores snapshot and version',
    () async {
      final asset = _readJson(File('assets/catalogs/tolls_inventory_v1.json'));
      final snapshot = File('${snapshotDirectory.path}/tolls.json');
      final store = TollInventoryStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => jsonEncode(asset),
      );
      final previousPayload = await _payload(asset);
      _serveManifest(server, {
        tollInventoryDatasetKey: _entry(
          version: asset['version'] as String,
          path: '/previous-tolls.json',
          sha256: previousPayload.sha256,
          sourceTimestamp: '2026-09-05T00:00:00Z',
        ),
      });
      _serveBytes(server, '/previous-tolls.json', previousPayload.bytes);
      await _service(
        db,
        preferences,
        tempDirectory,
        server,
        transactionalImporters: {
          tollInventoryDatasetKey: store.transactionalImporter,
        },
      ).sync();
      final previousHash = await _installedHash(db, tollInventoryDatasetKey);
      final previousSnapshot = File('${snapshot.path}.$previousHash');
      final previousBytes = await previousSnapshot.readAsBytes();
      final replacement = _copy(asset)..['version'] = '2026.09.06-local-test';
      final payload = await _payload(replacement);
      _serveManifest(server, {
        tollInventoryDatasetKey: _entry(
          version: '2026.09.06-local-test',
          path: '/replacement-tolls.json',
          sha256: payload.sha256,
          sourceTimestamp: '2026-09-05T00:00:00Z',
        ),
      });
      _serveBytes(server, '/replacement-tolls.json', payload.bytes);
      await db.customStatement('''
        CREATE TRIGGER reject_toll_version_update
        BEFORE UPDATE ON dataset_versions
        WHEN OLD.dataset_key = 'tolls_inventory'
        BEGIN
          SELECT RAISE(ABORT, 'forced version write failure');
        END;
      ''');

      await expectLater(
        _service(
          db,
          preferences,
          tempDirectory,
          server,
          transactionalImporters: {
            tollInventoryDatasetKey: store.transactionalImporter,
          },
        ).sync(),
        throwsA(anything),
      );

      expect(await previousSnapshot.readAsBytes(), previousBytes);
      expect(
        await _version(db, tollInventoryDatasetKey),
        '2026.09.05-viaje-r2',
      );
      expect(await _installedHash(db, tollInventoryDatasetKey), previousHash);
      expect((await store.load()).version, '2026.09.05-viaje-r2');
    },
  );

  test(
    '304 retries without ETag when an installed snapshot is missing',
    () async {
      final asset = _readJson(File('assets/catalogs/tolls_inventory_v1.json'));
      final payload = await _payload(asset);
      final snapshot = File('${snapshotDirectory.path}/tolls.json');
      final store = TollInventoryStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => jsonEncode(asset),
      );
      final manifest = _manifest({
        tollInventoryDatasetKey: _entry(
          version: asset['version'] as String,
          path: '/recover-tolls.json',
          sha256: payload.sha256,
          sourceTimestamp: '2026-09-05T00:00:00Z',
        ),
      });
      const etag = '"recover-tolls"';
      var conditionalManifestRequests = 0;
      var unconditionalManifestRequests = 0;
      var tollDownloads = 0;
      server.handlers['/v1/manifest.json'] = (request) async {
        if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
          conditionalManifestRequests += 1;
          request.response.statusCode = HttpStatus.notModified;
          await request.response.close();
          return;
        }
        unconditionalManifestRequests += 1;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set(HttpHeaders.etagHeader, etag);
        request.response.write(jsonEncode(manifest));
        await request.response.close();
      };
      server.handlers['/recover-tolls.json'] = (request) async {
        tollDownloads += 1;
        request.response.headers.contentType = ContentType.binary;
        request.response.contentLength = payload.bytes.length;
        request.response.add(payload.bytes);
        await request.response.close();
      };
      final service = _service(
        db,
        preferences,
        tempDirectory,
        server,
        transactionalImporters: {
          tollInventoryDatasetKey: store.transactionalImporter,
        },
      );

      expect((await service.sync()).imported, [tollInventoryDatasetKey]);
      expect(unconditionalManifestRequests, 1);
      expect(conditionalManifestRequests, 0);
      expect(tollDownloads, 1);
      await File('${snapshot.path}.${payload.sha256}').delete();

      await expectLater(store.load(), throwsA(isA<DatasetSyncException>()));

      final recovery = await service.sync();
      expect(recovery.imported, [tollInventoryDatasetKey]);
      expect(recovery.skippedCurrent, isEmpty);
      expect(recovery.notModified, isFalse);
      expect(unconditionalManifestRequests, 2);
      expect(conditionalManifestRequests, 1);
      expect(tollDownloads, 2);
      expect(
        await File('${snapshot.path}.${payload.sha256}').readAsBytes(),
        payload.bytes,
      );
      expect(await _installedHash(db, tollInventoryDatasetKey), payload.sha256);
      expect(await _version(db, tollInventoryDatasetKey), asset['version']);
      expect((await store.load()).version, asset['version']);
    },
  );

  test(
    '304 validates plain and transactional importer keys together',
    () async {
      await preferences.setString(
        DatasetSyncService.manifestEtagPreferenceKey,
        '"union-etag"',
      );
      final payload = await _payload({
        'datasetKey': restrictionsDatasetKey,
        'version': '2026.09.06-sync',
        'rows': <Object?>[],
      });
      var conditionalRequests = 0;
      var unconditionalRequests = 0;
      var downloads = 0;
      server.handlers['/v1/manifest.json'] = (request) async {
        if (request.headers.value(HttpHeaders.ifNoneMatchHeader) != null) {
          conditionalRequests += 1;
          request.response.statusCode = HttpStatus.notModified;
          await request.response.close();
          return;
        }
        unconditionalRequests += 1;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            _manifest({
              restrictionsDatasetKey: _entry(
                version: '2026.09.06-sync',
                path: '/missing-restrictions.json',
                sha256: payload.sha256,
                publicationRevision: 1,
              ),
            }),
          ),
        );
        await request.response.close();
      };
      server.handlers['/missing-restrictions.json'] = (request) async {
        downloads += 1;
        request.response.add(payload.bytes);
        await request.response.close();
      };

      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {restrictionsDatasetKey: (_, _) async {}},
      ).sync();

      expect(result.imported, [restrictionsDatasetKey]);
      expect(conditionalRequests, 1);
      expect(unconditionalRequests, 1);
      expect(downloads, 1);
    },
  );
}

Future<RestrictionEvaluation> _compiledRuleEvaluation(
  AppDatabase db, {
  String plate = 'ABC145',
  DateTime? localDateTime,
  bool isHoliday = false,
}) async {
  final evaluatedAt = localDateTime ?? DateTime(2026, 9, 7, 8);
  final rules = await RestrictionStore(db).loadCoverage(
    'co-ant-medellin',
    VehicleKind.car,
    VehicleServiceType.private,
    evaluatedAt,
  );
  return const RestrictionEngine().evaluate(
    RestrictionContext(
      jurisdictionId: 'co-ant-medellin',
      plate: plate,
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationOrigin: RegistrationOrigin.local,
      localDateTime: evaluatedAt,
      isHoliday: isHoliday,
      coverageKnown: rules.coverageKnown,
      dataIsStale: rules.dataIsStale,
    ),
    rules.rules,
  );
}

DatasetSyncService _service(
  AppDatabase db,
  AppPreferences preferences,
  Directory tempDirectory,
  _HttpFixtureServer server, {
  Map<String, DatasetImporter> importers = const {},
  Map<String, TransactionalDatasetImporter> transactionalImporters = const {},
  int maxManifestBytes = 64 * 1024,
  int maxDownloadBytes = 1024 * 1024,
  int maxDecodedBytes = 4 * 1024 * 1024,
  Duration receiveTimeout = const Duration(seconds: 2),
  DateTime? currentTime,
}) {
  return DatasetSyncService(
    database: db,
    preferences: preferences,
    config: AppConfig(cdnBaseUrl: server.origin.toString()),
    importers: importers,
    transactionalImporters: transactionalImporters,
    http: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: receiveTimeout,
      ),
    ),
    tempDirectory: tempDirectory,
    currentAppVersion: '1.0.0',
    now: () => currentTime ?? DateTime.utc(2026, 9, 5, 12),
    maxManifestBytes: maxManifestBytes,
    maxDownloadBytes: maxDownloadBytes,
    maxDecodedBytes: maxDecodedBytes,
  );
}

void _serveManifest(_HttpFixtureServer server, Map<String, Object?> datasets) {
  _serveJson(server, '/v1/manifest.json', _manifest(datasets));
}

void _serveJson(
  _HttpFixtureServer server,
  String path,
  Object? value, {
  String? etag,
}) {
  server.handlers[path] = (request) async {
    request.response.headers.contentType = ContentType.json;
    if (etag != null) {
      request.response.headers.set(HttpHeaders.etagHeader, etag);
    }
    request.response.write(jsonEncode(value));
    await request.response.close();
  };
}

void _serveBytes(
  _HttpFixtureServer server,
  String path,
  List<int> bytes, {
  String? etag,
}) {
  server.handlers[path] = (request) async {
    request.response.headers.contentType = ContentType.binary;
    if (etag != null) {
      request.response.headers.set(HttpHeaders.etagHeader, etag);
    }
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  };
}

void _serveChunked(
  _HttpFixtureServer server,
  String path,
  List<int> bytes, {
  required int chunkSize,
  Duration chunkDelay = Duration.zero,
}) {
  server.handlers[path] = (request) async {
    request.response.headers.contentType = ContentType.binary;
    request.response.bufferOutput = false;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = offset + chunkSize < bytes.length
          ? offset + chunkSize
          : bytes.length;
      request.response.add(bytes.sublist(offset, end));
      await request.response.flush();
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
    }
    await request.response.close();
  };
}

Map<String, Object?> _manifest(
  Map<String, Object?> datasets, {
  String generatedAt = '2026-09-05T00:00:00Z',
  String minAppVersion = '1.0.0',
}) {
  return {
    'schemaVersion': 1,
    'generatedAt': generatedAt,
    'minAppVersion': minAppVersion,
    'datasets': datasets,
    'features': {'ads': false, 'cloud': false, 'paidDocuments': false},
  };
}

Map<String, Object?> _entry({
  required String version,
  required String path,
  required String sha256,
  String? contentEncoding,
  String? expiresAt,
  String? sourceTimestamp,
  int? publicationRevision,
}) {
  return {
    'version': version,
    'url': path,
    'sha256': sha256,
    'contentEncoding': ?contentEncoding,
    'expiresAt': ?expiresAt,
    'sourceTimestamp': ?sourceTimestamp,
    'publicationRevision': ?publicationRevision,
  };
}

Future<_Payload> _payload(
  Map<String, Object?> json, {
  bool compressed = false,
}) async {
  final plain = utf8.encode(jsonEncode(json));
  final bytes = compressed ? gzip.encode(plain) : plain;
  final hash = await Sha256().hash(bytes);
  return _Payload(
    bytes,
    hash.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
  );
}

Future<void> _compileViajeR2Fixture(Directory outputRoot) async {
  final repoRoot = Directory.current.parent;
  final result = await Process.run(Platform.environment['PYTHON'] ?? 'python', [
    '${repoRoot.path}/scripts/tests/viaje_r2_bridge_fixture.py',
    '--seed-repo-root',
    repoRoot.path,
    '--output-root',
    outputRoot.path,
  ], runInShell: Platform.isWindows);
  expect(
    result.exitCode,
    0,
    reason:
        'Python bridge compiler failed:\n${result.stdout}\n${result.stderr}',
  );
}

Future<String> _sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<void> _insertVersion(
  AppDatabase db,
  String key, {
  required String version,
  String? sha256,
}) async {
  await db
      .into(db.datasetVersions)
      .insert(
        DatasetVersionsCompanion.insert(
          id: key,
          datasetKey: key,
          version: version,
          sha256: Value(sha256),
          status: 'installed',
        ),
      );
}

Future<String?> _version(AppDatabase db, String key) async {
  final rows = await (db.select(
    db.datasetVersions,
  )..where((row) => row.datasetKey.equals(key))).get();
  return rows.isEmpty ? null : rows.single.version;
}

Future<String?> _installedHash(AppDatabase db, String key) async {
  final rows = await (db.select(
    db.datasetVersions,
  )..where((row) => row.datasetKey.equals(key))).get();
  return rows.isEmpty ? null : rows.single.sha256;
}

Map<String, dynamic> _readJson(File file) {
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

Map<String, dynamic> _copy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

class _Payload {
  const _Payload(this.bytes, this.sha256);

  final List<int> bytes;
  final String sha256;
}

class _MemoryPreferences implements AppPreferences {
  final _values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}

typedef _Handler = FutureOr<void> Function(HttpRequest request);

class _HttpFixtureServer {
  _HttpFixtureServer._(this._server);

  final HttpServer _server;
  final handlers = <String, _Handler>{};

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<_HttpFixtureServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _HttpFixtureServer._(server);
    server.listen((request) async {
      final handler = fixture.handlers[request.uri.path];
      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      try {
        await handler(request);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {
          // Client timeout or cancellation may close the response first.
        }
      }
    });
    return fixture;
  }

  Future<void> close() => _server.close(force: true);
}
