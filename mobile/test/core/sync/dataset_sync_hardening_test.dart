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
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
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

  test('imports generated local manifest through real importers', () async {
    final manifest = _readJson(
      File('../data/releases/viaje_r2/local_test/manifest.json'),
    );
    final restrictionBytes = await File(
      'assets/datasets/restrictions/restrictions_v1.json',
    ).readAsBytes();
    final tollBytes = await File('assets/catalogs/tolls_inventory_v1.json')
        .readAsBytes();
    _serveJson(server, '/v1/manifest.json', manifest, etag: '"viaje-r2"');
    _serveBytes(
      server,
      '/assets/datasets/restrictions/restrictions_v1.json',
      restrictionBytes,
    );
    _serveBytes(server, '/assets/catalogs/tolls_inventory_v1.json', tollBytes);
    final snapshot = File('${snapshotDirectory.path}/tolls.json');
    final tollStore = TollInventoryStore(
      snapshotFile: snapshot,
      bundledLoader: () =>
          File('assets/catalogs/tolls_inventory_v1.json').readAsString(),
    );

    final result = await _service(
      db,
      preferences,
      tempDirectory,
      server,
      importers: {
        restrictionsDatasetKey: importRestrictionsDataset,
        tollInventoryDatasetKey: tollStore.datasetImporter,
      },
    ).sync();

    expect(result.imported, [restrictionsDatasetKey, tollInventoryDatasetKey]);
    expect((await tollStore.load()).records, hasLength(184));
    expect((await tollStore.load()).sourceTimestamp, DateTime.utc(2026, 9, 5));
    expect(await _version(db, tollInventoryDatasetKey), '2026.09.05-viaje-r2');
    expect(await db.select(db.restrictionCoverages).get(), hasLength(9));
    expect(
      await preferences.getString(DatasetSyncService.manifestEtagPreferenceKey),
      '"viaje-r2"',
    );
  });

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

  test('enforces downloaded and gzip-decoded size limits', () async {
    final oversized = await _payload({'rows': 'x' * 200});
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/oversized.json',
        sha256: oversized.sha256,
      ),
    });
    _serveBytes(server, '/oversized.json', oversized.bytes);
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
        maxDownloadBytes: 32,
      ).sync(),
      throwsA(isA<DatasetSyncException>()),
    );

    final compressed = await _payload({'rows': 'x' * 500}, compressed: true);
    _serveManifest(server, {
      'restrictions': _entry(
        version: '2.0',
        path: '/expanded.json.gz',
        sha256: compressed.sha256,
        contentEncoding: 'gzip',
      ),
    });
    _serveBytes(server, '/expanded.json.gz', compressed.bytes);
    await expectLater(
      _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
        maxDecodedBytes: 64,
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
    'failed toll import keeps previous snapshot and dataset version',
    () async {
      final asset = _readJson(File('assets/catalogs/tolls_inventory_v1.json'));
      final snapshot = File('${snapshotDirectory.path}/tolls.json');
      final store = TollInventoryStore(
        snapshotFile: snapshot,
        bundledLoader: () async => jsonEncode(asset),
      );
      await store.importJson(asset);
      final previousBytes = await snapshot.readAsBytes();
      await _insertVersion(
        db,
        tollInventoryDatasetKey,
        version: '2026.09.05-viaje-r2',
      );
      final invalid = _copy(asset)..['version'] = '2026.09.06-local-test';
      ((invalid['records'] as List)[0]['tariffsBySourceCategoryCOP']
              as Map<String, dynamic>)['category_1'] =
          0;
      final payload = await _payload(invalid);
      _serveManifest(server, {
        tollInventoryDatasetKey: _entry(
          version: '2026.09.06-local-test',
          path: '/invalid-tolls.json',
          sha256: payload.sha256,
          sourceTimestamp: '2026-09-05T00:00:00Z',
        ),
      });
      _serveBytes(server, '/invalid-tolls.json', payload.bytes);

      await expectLater(
        _service(
          db,
          preferences,
          tempDirectory,
          server,
          importers: {tollInventoryDatasetKey: store.datasetImporter},
        ).sync(),
        throwsA(isA<DatasetSyncException>()),
      );

      expect(await snapshot.readAsBytes(), previousBytes);
      expect(
        await _version(db, tollInventoryDatasetKey),
        '2026.09.05-viaje-r2',
      );
    },
  );
}

DatasetSyncService _service(
  AppDatabase db,
  AppPreferences preferences,
  Directory tempDirectory,
  _HttpFixtureServer server, {
  Map<String, DatasetImporter> importers = const {},
  int maxDownloadBytes = 1024 * 1024,
  int maxDecodedBytes = 4 * 1024 * 1024,
  Duration receiveTimeout = const Duration(seconds: 2),
}) {
  return DatasetSyncService(
    database: db,
    preferences: preferences,
    config: AppConfig(cdnBaseUrl: server.origin.toString()),
    importers: importers,
    http: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: receiveTimeout,
      ),
    ),
    tempDirectory: tempDirectory,
    currentAppVersion: '1.0.0',
    now: () => DateTime.utc(2026, 9, 5, 12),
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

void _serveBytes(_HttpFixtureServer server, String path, List<int> bytes) {
  server.handlers[path] = (request) async {
    request.response.headers.contentType = ContentType.binary;
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
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
}) {
  return {
    'version': version,
    'url': path,
    'sha256': sha256,
    'contentEncoding': ?contentEncoding,
    'expiresAt': ?expiresAt,
    'sourceTimestamp': ?sourceTimestamp,
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
