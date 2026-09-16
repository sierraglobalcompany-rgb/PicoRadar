import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog_store.dart';

import 'tax_catalog_test.dart' show taxFixture;

void main() {
  late Directory root;
  late File snapshot;
  late AppDatabase db;
  late TaxCatalogStore store;
  late Map<String, dynamic> json;

  Future<String> hash(Map<String, dynamic> value) =>
      _sha(utf8.encode(jsonEncode(value)));
  Future<PreparedDatasetImport> prepare(Map<String, dynamic> value) async {
    final bytes = utf8.encode(jsonEncode(value));
    return store.transactionalImporter(db, value, bytes, await _sha(bytes));
  }

  Future<void> select(
    PreparedDatasetImport prepared,
    Map<String, dynamic> value,
  ) async {
    await db.transaction(() async {
      await prepared.activate();
      await db
          .into(db.datasetVersions)
          .insertOnConflictUpdate(
            DatasetVersionsCompanion.insert(
              id: taxCalendarsDatasetKey,
              datasetKey: taxCalendarsDatasetKey,
              version: value['version'] as String,
              sha256: Value(await hash(value)),
              status: 'installed',
            ),
          );
    });
  }

  Future<void> install(Map<String, dynamic> value) async {
    final prepared = await prepare(value);
    await select(prepared, value);
    await prepared.commit();
  }

  Future<DatasetVersion> installed() =>
      db.select(db.datasetVersions).getSingle();
  Future<bool> usable() async => store.transactionalImporter
      .isInstalledVersionUsable(db, await installed());

  setUp(() async {
    root = await Directory.systemTemp.createTemp('picoradar_tax_test_');
    snapshot = File('${root.path}/tax_calendars.json');
    db = AppDatabase(NativeDatabase.memory());
    json = taxFixture();
    final bundled = jsonEncode(json);
    store = TaxCatalogStore(
      database: db,
      snapshotFile: snapshot,
      bundledLoader: () async => bundled,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'bundled fallback before install, remote selection and restart',
    () async {
      expect((await store.load()).version, 'test-v1');
      expect(store.lastLoadWarning, isNull);
      expect(await snapshot.exists(), isFalse);
      json['version'] = 'remote-v2';
      await install(json);
      expect((await store.load()).version, 'remote-v2');
      expect(store.lastLoadWarning, isNull);
      final restarted = TaxCatalogStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => throw StateError('must use installed bytes'),
      );
      expect((await restarted.load()).version, 'remote-v2');
      expect(await usable(), isTrue);
    },
  );

  test(
    'prepare and activate preserve old selection until database commit',
    () async {
      await install(json);
      final oldFile = File('${snapshot.path}.${await hash(json)}');
      json['version'] = 'remote-v2';
      final prepared = await prepare(json);
      await prepared.activate();
      expect((await store.load()).version, 'test-v1');
      await select(prepared, json);
      expect((await store.load()).version, 'remote-v2');
      expect(await oldFile.exists(), isTrue);
      await prepared.commit();
      await prepared.commit();
      expect(await oldFile.exists(), isFalse);
      expect(await usable(), isTrue);
    },
  );

  test(
    'failed database transaction rolls back selection and candidate only',
    () async {
      await install(json);
      final oldFile = File('${snapshot.path}.${await hash(json)}');
      final oldBytes = await oldFile.readAsBytes();
      json['version'] = 'remote-v2';
      final prepared = await prepare(json);
      await expectLater(
        db.transaction(() async {
          await select(prepared, json);
          throw StateError('injected failure before commit');
        }),
        throwsStateError,
      );
      await prepared.rollback();
      await prepared.rollback();
      expect((await store.load()).version, 'test-v1');
      expect(await oldFile.readAsBytes(), oldBytes);
      expect(
        await File('${snapshot.path}.${await hash(json)}').exists(),
        isFalse,
      );
      expect(await usable(), isTrue);
    },
  );

  test(
    'invalid data, hash and JSON/bytes mismatch cannot replace last version',
    () async {
      await install(json);
      final bytes = utf8.encode(jsonEncode(json));
      await expectLater(
        store.transactionalImporter(db, json, bytes, '0' * 64),
        throwsA(isA<DatasetSyncException>()),
      );
      final other = taxFixture()..['version'] = 'mismatched';
      await expectLater(
        store.transactionalImporter(db, other, bytes, await _sha(bytes)),
        throwsA(isA<DatasetSyncException>()),
      );
      json['schemaVersion'] = 99;
      await expectLater(prepare(json), throwsA(isA<DatasetSyncException>()));
      expect((await store.load()).version, 'test-v1');
      expect(await usable(), isTrue);
    },
  );

  test('rejects verified malformed UTF-8 and wrong database', () async {
    final bytes = [0xff, 0xfe];
    await expectLater(
      store.transactionalImporter(db, json, bytes, await _sha(bytes)),
      throwsA(isA<DatasetSyncException>()),
    );
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final valid = utf8.encode(jsonEncode(json));
    await expectLater(
      store.transactionalImporter(other, json, valid, await _sha(valid)),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test(
    'usable check rejects corrupt, missing and mismatched snapshots',
    () async {
      await install(json);
      final file = File('${snapshot.path}.${await hash(json)}');
      await file.writeAsString('{"changed":true}', flush: true);
      expect(await usable(), isFalse);
      expect((await store.load()).version, 'test-v1');
      expect(store.lastLoadWarning, isNotEmpty);
      expect(await usable(), isFalse);
      await file.delete();
      expect(await usable(), isFalse);
      await install(json);
      await db
          .update(db.datasetVersions)
          .write(const DatasetVersionsCompanion(version: Value('wrong')));
      expect(await usable(), isFalse);
      await db
          .update(db.datasetVersions)
          .write(const DatasetVersionsCompanion(sha256: Value('invalid')));
      expect(await usable(), isFalse);
    },
  );

  for (final state in ['missing', 'corrupt']) {
    test(
      '$state installed snapshot uses validated bundle with warning until repair',
      () async {
        json['version'] = 'remote-v2';
        await install(json);
        final selected = await installed();
        final file = File('${snapshot.path}.${await hash(json)}');
        if (state == 'missing') {
          await file.delete();
        } else {
          await file.writeAsString('corrupt snapshot', flush: true);
        }

        expect(await usable(), isFalse);
        final fallback = await store.load();
        expect(fallback.version, 'test-v1');
        expect(store.lastLoadWarning, contains('respaldo incluido en la app'));
        final warning = store.lastLoadWarning;
        expect(await installed(), selected);
        expect(await usable(), isFalse);
        expect(store.lastLoadWarning, warning);
        if (state == 'missing') {
          expect(await file.exists(), isFalse);
        } else {
          expect(await file.readAsString(), 'corrupt snapshot');
        }

        // Retry without manually deleting a corrupt file.
        await install(json);
        expect(await file.readAsBytes(), utf8.encode(jsonEncode(json)));
        expect(await usable(), isTrue);
        expect((await store.load()).version, 'remote-v2');
        expect(store.lastLoadWarning, isNull);
        expect(await installed(), selected);
      },
    );
  }

  test('bootstrap load clears a previous fallback warning', () async {
    await install(json);
    await File('${snapshot.path}.${await hash(json)}').delete();
    await store.load();
    expect(store.lastLoadWarning, isNotEmpty);

    await db.delete(db.datasetVersions).go();
    expect((await store.load()).version, 'test-v1');
    expect(store.lastLoadWarning, isNull);
  });

  for (final brokenBundle in ['{bad', '{"schemaVersion":99}']) {
    test('fallback rejects invalid bundle $brokenBundle', () async {
      await install(json);
      await File('${snapshot.path}.${await hash(json)}').delete();
      final selected = await installed();
      final fallbackStore = TaxCatalogStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => brokenBundle,
      );

      await expectLater(
        fallbackStore.load(),
        throwsA(isA<DatasetSyncException>()),
      );
      expect(await usable(), isFalse);
      expect(await installed(), selected);
    });
  }

  test('fallback propagates bootstrap read errors', () async {
    await install(json);
    await File('${snapshot.path}.${await hash(json)}').delete();
    final failure = FileSystemException('Synthetic bundle read failure');
    final fallbackStore = TaxCatalogStore(
      database: db,
      snapshotFile: snapshot,
      bundledLoader: () async => throw failure,
    );

    await expectLater(fallbackStore.load(), throwsA(same(failure)));
    expect(await usable(), isFalse);
  });

  test(
    'same-hash repair survives failed transaction and late rollback',
    () async {
      await install(json);
      final selected = await installed();
      final file = File('${snapshot.path}.${await hash(json)}');
      await file.writeAsString('corrupt snapshot', flush: true);
      expect(await usable(), isFalse);

      final prepared = await prepare(json);
      expect(await installed(), selected);
      expect(await usable(), isTrue);
      await expectLater(
        db.transaction(() async {
          await select(prepared, json);
          throw StateError('injected failure after same-hash repair');
        }),
        throwsStateError,
      );
      await prepared.rollback();
      await prepared.rollback();
      expect(await file.readAsBytes(), utf8.encode(jsonEncode(json)));
      expect(await installed(), selected);
      expect((await store.load()).version, 'test-v1');
      expect(store.lastLoadWarning, isNull);
    },
  );

  test(
    'unselected repair rollback preserves the last good selection',
    () async {
      await install(json);
      final selected = await installed();
      final oldFile = File('${snapshot.path}.${await hash(json)}');
      final oldBytes = await oldFile.readAsBytes();
      final next = taxFixture()..['version'] = 'remote-v2';
      final nextFile = File('${snapshot.path}.${await hash(next)}');
      await nextFile.writeAsString('corrupt unselected snapshot', flush: true);

      final prepared = await prepare(next);
      expect(await nextFile.readAsBytes(), utf8.encode(jsonEncode(next)));
      expect((await store.load()).version, 'test-v1');
      await expectLater(
        db.transaction(() async {
          await select(prepared, next);
          throw StateError('injected failure after unselected repair');
        }),
        throwsStateError,
      );
      await prepared.rollback();
      expect(await nextFile.exists(), isFalse);
      expect(await oldFile.readAsBytes(), oldBytes);
      expect(await installed(), selected);
      expect(await usable(), isTrue);
    },
  );

  test(
    'failed replacement preserves selected data and cleans candidate',
    () async {
      await install(json);
      final selected = await installed();
      final oldFile = File('${snapshot.path}.${await hash(json)}');
      final oldBytes = await oldFile.readAsBytes();
      final next = taxFixture()..['version'] = 'remote-v2';
      // A directory cannot be replaced by File.rename on either target OS.
      await Directory('${snapshot.path}.${await hash(next)}').create();

      await expectLater(prepare(next), throwsA(isA<DatasetSyncException>()));
      expect(await installed(), selected);
      expect(await oldFile.readAsBytes(), oldBytes);
      expect(await usable(), isTrue);
      expect(
        (await root.list().toList()).where(
          (entity) => entity.path.contains('.candidate.'),
        ),
        isEmpty,
      );
    },
  );

  test(
    '304 usable requires correct database, dataset key and installed status',
    () async {
      await install(json);
      final row = await installed();
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final check = store.transactionalImporter.isInstalledVersionUsable;
      expect(await check(other, row), isFalse);
      expect(await check(db, row.copyWith(datasetKey: 'other')), isFalse);
      expect(await check(db, row.copyWith(status: 'pending')), isFalse);
      expect(await check(db, row), isTrue);
    },
  );

  test(
    'overlapping candidates and stale cleanup preserve selected snapshot',
    () async {
      await install(json);
      final a = taxFixture()..['version'] = 'a';
      final b = taxFixture()..['version'] = 'b';
      final first = await prepare(a);
      final second = await prepare(b);
      await select(first, a);
      await select(second, b);
      await second.commit();
      expect(await File('${snapshot.path}.${await hash(a)}').exists(), isTrue);
      await first.commit();
      expect((await store.load()).version, 'b');
      expect(await usable(), isTrue);
    },
  );

  test(
    'same-hash preparation and late rollback never delete selected data',
    () async {
      final first = await prepare(json);
      final second = await prepare(json);
      await first.rollback();
      expect(
        await File('${snapshot.path}.${await hash(json)}').exists(),
        isTrue,
      );
      await select(second, json);
      await second.rollback();
      expect(await usable(), isTrue);
    },
  );

  test(
    'future compatible year arrives through an installed snapshot',
    () async {
      json['version'] = '2027.1';
      final calendar = (json['calendars'] as List).single;
      calendar['id'] = 'bogota-2027-vehicle-tax';
      calendar['year'] = 2027;
      calendar['events'].single['date'] = '2027-07-23';
      await install(json);
      expect((await store.load()).calendarFor('bogota', 2027), isNotNull);
      expect((await store.load()).calendarFor('bogota', 2026), isNull);
    },
  );

  for (final state in ['usable', 'missing', 'corrupt']) {
    test('real sync 304 handles $state snapshot', () async {
      await install(json);
      final file = File('${snapshot.path}.${await hash(json)}');
      final needsRepair = state != 'usable';
      if (state == 'missing') {
        await file.delete();
      } else if (state == 'corrupt') {
        await file.writeAsString('corrupt snapshot', flush: true);
      }
      if (needsRepair) {
        expect(await usable(), isFalse);
        await store.load();
        expect(store.lastLoadWarning, isNotEmpty);
      }
      final requests = <RequestOptions>[];
      final bytes = utf8.encode(jsonEncode(json));
      final sha = await _sha(bytes);
      final prefs = _MemoryPreferences();
      await prefs.setString(
        DatasetSyncService.manifestEtagPreferenceKey,
        'existing-etag',
      );
      final http = Dio();
      addTearDown(() => http.close(force: true));
      http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final isManifest = options.path.endsWith('manifest.json');
            final status = requests.length == 1 ? 304 : 200;
            final body = isManifest
                ? jsonEncode({
                    'schemaVersion': 1,
                    'generatedAt': '2026-09-13T16:00:00Z',
                    'minAppVersion': '1.0.0',
                    'datasets': {
                      taxCalendarsDatasetKey: {
                        'version': json['version'],
                        'url': '/tax.json',
                        'sha256': sha,
                      },
                    },
                    'features': <String, bool>{},
                  })
                : utf8.decode(bytes);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: status,
                data: ResponseBody.fromString(
                  status == 304 ? '' : body,
                  status,
                ),
              ),
            );
          },
        ),
      );
      final service = DatasetSyncService(
        database: db,
        preferences: prefs,
        config: AppConfig(cdnBaseUrl: 'https://datasets.picoradar.co'),
        importers: const {},
        transactionalImporters: {
          taxCalendarsDatasetKey: store.transactionalImporter,
        },
        http: http,
        tempDirectory: root,
        now: () => DateTime.utc(2026, 9, 13, 17),
      );
      final result = await service.sync();
      expect(result.notModified, !needsRepair);
      expect(requests, hasLength(needsRepair ? 3 : 1));
      expect(
        requests.first.headers[HttpHeaders.ifNoneMatchHeader],
        'existing-etag',
      );
      if (needsRepair) {
        expect(
          requests[1].headers.containsKey(HttpHeaders.ifNoneMatchHeader),
          isFalse,
        );
        expect(result.imported, contains(taxCalendarsDatasetKey));
      }
      expect(await usable(), isTrue);
      expect((await store.load()).version, 'test-v1');
      expect(store.lastLoadWarning, isNull);
      expect(await file.readAsBytes(), bytes);
    });
  }
}

Future<String> _sha(List<int> bytes) async =>
    (await Sha256().hash(bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

class _MemoryPreferences implements AppPreferences {
  final _values = <String, Object>{};
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
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}
