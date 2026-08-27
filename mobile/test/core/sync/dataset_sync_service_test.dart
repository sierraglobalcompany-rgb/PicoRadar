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
import 'package:picoradar/core/sync/dataset_manifest.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('DatasetManifest', () {
    test('parses schema V1 and normalizes dataset version to string', () {
      final manifest = DatasetManifest.fromJson({
        'schemaVersion': 1,
        'generatedAt': '2026-08-26T10:00:00Z',
        'minAppVersion': '1.0.0',
        'datasets': {
          'restrictions': {
            'version': 20260826,
            'url': '/datasets/restrictions.json',
            'sha256': 'a' * 64,
          },
        },
        'features': {'ads': false, 'cloud': false},
      });

      expect(manifest.schemaVersion, 1);
      expect(manifest.datasets['restrictions']?.version, '20260826');
      expect(manifest.features['ads'], isFalse);
    });

    test('rejects incompatible schema before any dataset can be imported', () {
      expect(
        () => DatasetManifest.fromJson({
          'schemaVersion': 2,
          'generatedAt': '2026-08-26T10:00:00Z',
          'minAppVersion': '1.0.0',
          'datasets': <String, Object?>{},
          'features': <String, Object?>{},
        }),
        throwsA(isA<ManifestFormatException>()),
      );
    });
  });

  group('DatasetSyncService', () {
    late AppDatabase db;
    late _MemoryPreferences preferences;
    late Directory tempDirectory;
    late _HttpFixtureServer server;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      preferences = _MemoryPreferences();
      tempDirectory = await Directory.systemTemp.createTemp(
        'picoradar_sync_test_',
      );
      server = await _HttpFixtureServer.start();
    });

    tearDown(() async {
      await server.close();
      await db.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('imports a dataset with a valid manifest and SHA-256', () async {
      final payload = await _payload({
        'rows': ['bogota'],
      });
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: '/datasets/restrictions.json',
          sha256: payload.sha256,
        ),
      });
      _serveBytes(server, '/datasets/restrictions.json', payload.bytes);

      final imports = <Map<String, dynamic>>[];
      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, json) async => imports.add(json)},
      ).sync();

      expect(result.imported, ['restrictions']);
      expect(imports.single['rows'], ['bogota']);
    });

    test('skips download when the installed version is current', () async {
      await _insertDatasetVersion(db, version: '2026.08.26');
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: '/datasets/should-not-download.json',
          sha256: 'a' * 64,
        ),
      });
      server.handlers['/datasets/should-not-download.json'] = (request) {
        fail('Current datasets must not be downloaded again.');
      };

      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync();

      expect(result.skippedCurrent, ['restrictions']);
    });

    test(
      'sends If-None-Match and stores the fresh ETag after success',
      () async {
        await preferences.setString(
          DatasetSyncService.manifestEtagPreferenceKey,
          '"old-etag"',
        );
        String? ifNoneMatch;
        server.handlers['/v1/manifest.json'] = (request) async {
          ifNoneMatch = request.headers.value(HttpHeaders.ifNoneMatchHeader);
          await _respondJson(
            request,
            _manifest(<String, Object?>{}),
            etag: '"new-etag"',
          );
        };

        await _service(db, preferences, tempDirectory, server).sync();

        expect(ifNoneMatch, '"old-etag"');
        expect(
          await preferences.getString(
            DatasetSyncService.manifestEtagPreferenceKey,
          ),
          '"new-etag"',
        );
      },
    );

    test('treats 304 as a normal no-op', () async {
      await _insertDatasetVersion(db, version: '2026.08.25');
      await preferences.setString(
        DatasetSyncService.manifestEtagPreferenceKey,
        '"known-etag"',
      );
      server.handlers['/v1/manifest.json'] = (request) async {
        request.response.statusCode = HttpStatus.notModified;
        await request.response.close();
      };

      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
      ).sync();

      expect(result.notModified, isTrue);
      expect(await _datasetVersion(db), '2026.08.25');
    });

    test('rejects SHA-256 mismatches before calling the importer', () async {
      final payload = await _payload({
        'rows': ['bogota'],
      });
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: '/datasets/restrictions.json',
          sha256: 'b' * 64,
        ),
      });
      _serveBytes(server, '/datasets/restrictions.json', payload.bytes);

      var imported = false;
      await expectLater(
        _service(
          db,
          preferences,
          tempDirectory,
          server,
          importers: {'restrictions': (_, _) async => imported = true},
        ).sync(),
        throwsA(isA<DatasetSyncException>()),
      );

      expect(imported, isFalse);
      expect(await _datasetVersion(db), isNull);
    });

    test('hashes gzip bytes before decompressing and importing JSON', () async {
      final payload = await _payload({
        'rows': ['medellin'],
      }, compressed: true);
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: '/datasets/restrictions.json.gz',
          sha256: payload.sha256,
          contentEncoding: 'gzip',
        ),
      });
      _serveBytes(server, '/datasets/restrictions.json.gz', payload.bytes);

      final imports = <Map<String, dynamic>>[];
      await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, json) async => imports.add(json)},
      ).sync();

      expect(imports.single['rows'], ['medellin']);
    });

    test(
      'rejects invalid dataset JSON without advancing dataset_versions',
      () async {
        final bytes = utf8.encode('[]');
        final sha256 = await _sha256Hex(bytes);
        _serveManifest(server, {
          'restrictions': _entry(
            version: '2026.08.26',
            path: '/datasets/restrictions.json',
            sha256: sha256,
          ),
        });
        _serveBytes(server, '/datasets/restrictions.json', bytes);

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

        expect(await _datasetVersion(db), isNull);
      },
    );

    test(
      'rolls back importer writes and keeps the old version on failure',
      () async {
        await _insertDatasetVersion(db, version: '2026.08.25');
        final payload = await _payload({
          'rows': ['bogota'],
        });
        _serveManifest(server, {
          'restrictions': _entry(
            version: '2026.08.26',
            path: '/datasets/restrictions.json',
            sha256: payload.sha256,
          ),
        });
        _serveBytes(server, '/datasets/restrictions.json', payload.bytes);

        await expectLater(
          _service(
            db,
            preferences,
            tempDirectory,
            server,
            importers: {
              'restrictions': (database, _) async {
                await database
                    .into(database.vehicles)
                    .insert(
                      VehiclesCompanion.insert(
                        id: 'vehicle-from-import',
                        plate: 'ABC123',
                      ),
                    );
                throw const DatasetSyncException('Importer failed.');
              },
            },
          ).sync(),
          throwsA(isA<DatasetSyncException>()),
        );

        expect(await db.select(db.vehicles).get(), isEmpty);
        expect(await _datasetVersion(db), '2026.08.25');
      },
    );

    test('updates dataset_versions only after a successful import', () async {
      final payload = await _payload({
        'rows': ['cali'],
      });
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: '/datasets/restrictions.json',
          sha256: payload.sha256,
        ),
      });
      _serveBytes(server, '/datasets/restrictions.json', payload.bytes);

      await _service(
        db,
        preferences,
        tempDirectory,
        server,
        importers: {'restrictions': (_, _) async {}},
      ).sync();

      final row = await _datasetVersionRow(db);
      expect(row?.version, '2026.08.26');
      expect(row?.sha256, payload.sha256);
      expect(row?.status, 'installed');
    });

    test(
      'cleans temporary files after successful and failed downloads',
      () async {
        final goodPayload = await _payload({
          'rows': ['bogota'],
        });
        _serveManifest(server, {
          'restrictions': _entry(
            version: '2026.08.26',
            path: '/datasets/good.json',
            sha256: goodPayload.sha256,
          ),
        });
        _serveBytes(server, '/datasets/good.json', goodPayload.bytes);

        await _service(
          db,
          preferences,
          tempDirectory,
          server,
          importers: {'restrictions': (_, _) async {}},
        ).sync();
        expect(await tempDirectory.list().toList(), isEmpty);

        _serveManifest(server, {
          'restrictions': _entry(
            version: '2026.08.27',
            path: '/datasets/bad.json',
            sha256: 'c' * 64,
          ),
        });
        _serveBytes(server, '/datasets/bad.json', goodPayload.bytes);

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
        expect(await tempDirectory.list().toList(), isEmpty);
      },
    );

    test('rejects absolute dataset URLs from a different origin', () async {
      _serveManifest(server, {
        'restrictions': _entry(
          version: '2026.08.26',
          path: 'https://example.com/datasets/restrictions.json',
          sha256: 'a' * 64,
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

      expect(await _datasetVersion(db), isNull);
    });

    test('skips datasets without a registered importer', () async {
      _serveManifest(server, {
        'future_dataset': _entry(
          version: '2026.08.26',
          path: '/datasets/future.json',
          sha256: 'a' * 64,
        ),
      });

      final result = await _service(
        db,
        preferences,
        tempDirectory,
        server,
      ).sync();

      expect(result.skippedMissingImporter, ['future_dataset']);
      expect(await db.select(db.datasetVersions).get(), isEmpty);
    });
  });
}

DatasetSyncService _service(
  AppDatabase db,
  AppPreferences preferences,
  Directory tempDirectory,
  _HttpFixtureServer server, {
  Map<String, DatasetImporter> importers = const {},
}) {
  return DatasetSyncService(
    database: db,
    preferences: preferences,
    config: AppConfig(cdnBaseUrl: server.origin.toString()),
    importers: importers,
    http: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    ),
    tempDirectory: tempDirectory,
  );
}

void _serveManifest(_HttpFixtureServer server, Map<String, Object?> datasets) {
  server.handlers['/v1/manifest.json'] = (request) async {
    await _respondJson(request, _manifest(datasets));
  };
}

void _serveBytes(_HttpFixtureServer server, String path, List<int> bytes) {
  server.handlers[path] = (request) async {
    request.response.headers.contentType = ContentType.binary;
    request.response.add(bytes);
    await request.response.close();
  };
}

Map<String, Object?> _manifest(Map<String, Object?> datasets) {
  return {
    'schemaVersion': 1,
    'generatedAt': '2026-08-26T10:00:00Z',
    'minAppVersion': '1.0.0',
    'datasets': datasets,
    'features': {'ads': false, 'cloud': false, 'paidDocuments': false},
  };
}

Map<String, Object?> _entry({
  required String version,
  required String path,
  required String sha256,
  String? contentEncoding,
}) {
  final entry = {'version': version, 'url': path, 'sha256': sha256};
  if (contentEncoding != null) {
    entry['contentEncoding'] = contentEncoding;
  }
  return entry;
}

Future<_DatasetPayload> _payload(
  Map<String, Object?> json, {
  bool compressed = false,
}) async {
  final plainBytes = utf8.encode(jsonEncode(json));
  final bytes = compressed ? gzip.encode(plainBytes) : plainBytes;
  return _DatasetPayload(bytes: bytes, sha256: await _sha256Hex(bytes));
}

Future<String> _sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<void> _insertDatasetVersion(
  AppDatabase db, {
  required String version,
}) async {
  await db
      .into(db.datasetVersions)
      .insert(
        DatasetVersionsCompanion.insert(
          id: 'restrictions',
          datasetKey: 'restrictions',
          version: version,
          status: 'installed',
        ),
      );
}

Future<String?> _datasetVersion(AppDatabase db) async {
  return (await _datasetVersionRow(db))?.version;
}

Future<DatasetVersion?> _datasetVersionRow(AppDatabase db) async {
  final rows = await (db.select(
    db.datasetVersions,
  )..where((row) => row.datasetKey.equals('restrictions'))).get();
  return rows.isEmpty ? null : rows.single;
}

Future<void> _respondJson(
  HttpRequest request,
  Object? json, {
  String? etag,
}) async {
  request.response.headers.contentType = ContentType.json;
  if (etag != null) {
    request.response.headers.set(HttpHeaders.etagHeader, etag);
  }
  request.response.write(jsonEncode(json));
  await request.response.close();
}

class _DatasetPayload {
  const _DatasetPayload({required this.bytes, required this.sha256});

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

typedef _HttpHandler = FutureOr<void> Function(HttpRequest request);

class _HttpFixtureServer {
  _HttpFixtureServer._(this._server);

  final HttpServer _server;
  final handlers = <String, _HttpHandler>{};

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}/');

  static Future<_HttpFixtureServer> start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _HttpFixtureServer._(httpServer);
    httpServer.listen((request) async {
      final handler = fixture.handlers[request.uri.path];
      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      try {
        await handler(request);
      } catch (error) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(error.toString());
          await request.response.close();
        } catch (_) {
          // The handler may already have closed the response before failing.
        }
      }
    });
    return fixture;
  }

  Future<void> close() => _server.close(force: true);
}
