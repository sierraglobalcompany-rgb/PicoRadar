import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';

void main() {
  late Map<String, dynamic> assetJson;

  setUpAll(() {
    assetJson = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/catalogs/tolls_inventory_v1.json').readAsStringSync(),
      ) as Map,
    );
  });

  test('parses 184 physical stations without verified charges or prices', () {
    final dataset = TollInventoryDataset.fromJson(assetJson);

    expect(dataset.version, '2026.09.05-viaje-r2');
    expect(dataset.sourceTimestamp, DateTime.utc(2026, 9, 5));
    expect(dataset.records, hasLength(184));
    expect(dataset.records.map((record) => record.id).toSet(), hasLength(184));
    expect(dataset.verifiedChargeEventCount, 0);
    expect(dataset.knownTariffCount, 0);
    expect(dataset.tariffCellCount, 1288);
    expect(
      dataset.records
          .where(
            (record) =>
                record.operationClassification ==
                TollOperationClassification.nonOperationalHistorical,
          )
          .length,
      2,
    );
    expect(
      dataset.records
          .where(
            (record) =>
                record.operationClassification ==
                TollOperationClassification.damagedReviewRequired,
          )
          .length,
      1,
    );
  });

  test('preserves grouping, sense, and separate GPS provenance', () {
    final dataset = TollInventoryDataset.fromJson(assetJson);
    final grouped = dataset.records.firstWhere(
      (record) => record.chargeGroupRaw != null,
    );

    expect(grouped.recordKind, TollRecordKind.physicalStation);
    expect(grouped.chargeEventVerified, isFalse);
    expect(grouped.chargeGroupRaw, isNotEmpty);
    expect(grouped.routeCountingRuleRaw, isNotEmpty);
    expect(grouped.inventorySource, startsWith('https://'));
    expect(grouped.gpsSource, startsWith('https://'));
  });

  test('rejects wrong schema, duplicate IDs, and a null changed to zero', () {
    final wrongSchema = _copy(assetJson)..['schemaVersion'] = 2;
    final duplicate = _copy(assetJson);
    (duplicate['records'] as List)[1]['id'] =
        (duplicate['records'] as List)[0]['id'];
    final inventedFree = _copy(assetJson);
    ((inventedFree['records'] as List)[0]['tariffsBySourceCategoryCOP']
            as Map<String, dynamic>)['category_1'] =
        0;

    expect(
      () => TollInventoryDataset.fromJson(wrongSchema),
      throwsA(isA<DatasetSyncException>()),
    );
    expect(
      () => TollInventoryDataset.fromJson(duplicate),
      throwsA(isA<DatasetSyncException>()),
    );
    expect(
      () => TollInventoryDataset.fromJson(inventedFree),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects truncated JSON and mismatched inventory semantics', () {
    final encoded = jsonEncode(assetJson);
    final wrongScope = _copy(assetJson)
      ..['inventoryScope'] = 'active_charge_events';

    expect(
      () => TollInventoryDataset.fromJsonString(
        encoded.substring(0, encoded.length - 20),
      ),
      throwsA(isA<DatasetSyncException>()),
    );
    expect(
      () => TollInventoryDataset.fromJson(wrongScope),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  group('TollInventoryStore', () {
    late Directory root;
    late File snapshot;
    late AppDatabase db;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('picoradar_tolls_');
      snapshot = File(
        '${root.path}${Platform.pathSeparator}tolls_inventory.json',
      );
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('loads bundled bytes until an imported snapshot exists', () async {
      final bundled = jsonEncode(assetJson);
      final store = TollInventoryStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => bundled,
      );

      final first = await store.load();
      expect(first.version, '2026.09.05-viaje-r2');
      expect(await snapshot.exists(), isFalse);

      final imported = _copy(assetJson)..['version'] = '2026.09.06-local-test';
      await _installSnapshot(store, db, imported);
      final importedSha = await _sha256(utf8.encode(jsonEncode(imported)));

      expect((await store.load()).version, '2026.09.06-local-test');
      expect(await File('${snapshot.path}.$importedSha').exists(), isTrue);
    });

    test(
      'failed import preserves the previous snapshot byte for byte',
      () async {
        final store = TollInventoryStore(
          database: db,
          snapshotFile: snapshot,
          bundledLoader: () async => jsonEncode(assetJson),
        );
        await _installSnapshot(store, db, assetJson);
        final previousSha = await _sha256(utf8.encode(jsonEncode(assetJson)));
        final selectedSnapshot = File('${snapshot.path}.$previousSha');
        final previous = await selectedSnapshot.readAsBytes();
        final invalid = _copy(assetJson);
        ((invalid['records'] as List)[0]['tariffsBySourceCategoryCOP']
                as Map<String, dynamic>)['category_1'] =
            0;

        await expectLater(
          _prepareSnapshot(store, db, invalid),
          throwsA(isA<DatasetSyncException>()),
        );

        expect(await selectedSnapshot.readAsBytes(), previous);
        expect((await store.load()).version, '2026.09.05-viaje-r2');
      },
    );

    test(
      'rejects a valid JSON snapshot changed after verified import',
      () async {
        final store = TollInventoryStore(
          database: db,
          snapshotFile: snapshot,
          bundledLoader: () async => jsonEncode(assetJson),
        );
        await _installSnapshot(store, db, assetJson);
        final installedSha = await _sha256(utf8.encode(jsonEncode(assetJson)));
        final changed = _copy(assetJson);
        (changed['records'] as List).first['name'] = 'Changed after import';
        await File('${snapshot.path}.$installedSha')
            .writeAsString(jsonEncode(changed), flush: true);

        await expectLater(store.load(), throwsA(isA<DatasetSyncException>()));
      },
    );

    test(
      'keeps the database-selected snapshot visible before commit',
      () async {
        final store = TollInventoryStore(
          database: db,
          snapshotFile: snapshot,
          bundledLoader: () async => jsonEncode(assetJson),
        );
        await _installSnapshot(store, db, assetJson);
        final oldBytes = utf8.encode(jsonEncode(assetJson));
        final oldSha = await _sha256(oldBytes);
        final replacement = _copy(assetJson)
          ..['version'] = '2026.09.06-local-test';
        final replacementBytes = utf8.encode(jsonEncode(replacement));
        final replacementSha = await _sha256(replacementBytes);

        final prepared = await store.transactionalImporter(
          db,
          replacement,
          replacementBytes,
          replacementSha,
        );
        addTearDown(prepared.rollback);

        expect((await store.load()).version, assetJson['version']);
        expect(await File('${snapshot.path}.$oldSha').exists(), isTrue);
        expect(await File('${snapshot.path}.$replacementSha').exists(), isTrue);
      },
    );

    test(
      'database commit atomically selects the new immutable snapshot',
      () async {
        final store = TollInventoryStore(
          database: db,
          snapshotFile: snapshot,
          bundledLoader: () async => jsonEncode(assetJson),
        );
        await _installSnapshot(store, db, assetJson);
        final oldSha = await _sha256(utf8.encode(jsonEncode(assetJson)));
        final replacement = _copy(assetJson)
          ..['version'] = '2026.09.06-local-test';
        final replacementBytes = utf8.encode(jsonEncode(replacement));
        final replacementSha = await _sha256(replacementBytes);
        final prepared = await store.transactionalImporter(
          db,
          replacement,
          replacementBytes,
          replacementSha,
        );

        await db.transaction(() async {
          await prepared.activate();
          await (db.update(
                db.datasetVersions,
              )..where((row) => row.datasetKey.equals(tollInventoryDatasetKey)))
              .write(
                DatasetVersionsCompanion(
                  version: const Value('2026.09.06-local-test'),
                  sha256: Value(replacementSha),
                ),
              );
        });

        expect((await store.load()).version, '2026.09.06-local-test');
        expect(await File('${snapshot.path}.$oldSha').exists(), isTrue);
        expect(await File('${snapshot.path}.$replacementSha').exists(), isTrue);
        await prepared.commit();
      },
    );

    test('cleanup preserves overlapping prepared snapshots', () async {
      final store = TollInventoryStore(
        database: db,
        snapshotFile: snapshot,
        bundledLoader: () async => jsonEncode(assetJson),
      );
      await _installSnapshot(store, db, assetJson);
      final first = _copy(assetJson)..['version'] = '2026.09.06-concurrent-a';
      final firstBytes = utf8.encode(jsonEncode(first));
      final firstSha = await _sha256(firstBytes);
      final firstPrepared = await store.transactionalImporter(
        db,
        first,
        firstBytes,
        firstSha,
      );
      await _selectSnapshot(
        db,
        firstPrepared,
        version: first['version'] as String,
        sha256: firstSha,
      );

      final second = _copy(assetJson)..['version'] = '2026.09.06-concurrent-b';
      final secondBytes = utf8.encode(jsonEncode(second));
      final secondSha = await _sha256(secondBytes);
      final secondPrepared = await store.transactionalImporter(
        db,
        second,
        secondBytes,
        secondSha,
      );

      final reader = store.load();
      final cleanup = firstPrepared.commit();
      expect((await reader).version, first['version']);
      await cleanup;
      expect(await File('${snapshot.path}.$secondSha').exists(), isTrue);

      await _selectSnapshot(
        db,
        secondPrepared,
        version: second['version'] as String,
        sha256: secondSha,
      );
      await secondPrepared.commit();
      expect((await store.load()).version, second['version']);
    });
  });
}

Future<void> _installSnapshot(
  TollInventoryStore store,
  AppDatabase db,
  Map<String, dynamic> json,
) async {
  final prepared = await _prepareSnapshot(store, db, json);
  try {
    await db.transaction(() async {
      await prepared.activate();
      await db
          .into(db.datasetVersions)
          .insert(
            DatasetVersionsCompanion.insert(
              id: tollInventoryDatasetKey,
              datasetKey: tollInventoryDatasetKey,
              version: json['version'] as String,
              sha256: Value(await _sha256(utf8.encode(jsonEncode(json)))),
              status: 'installed',
            ),
          );
    });
  } catch (_) {
    await prepared.rollback();
    rethrow;
  }
  await prepared.commit();
}

Future<PreparedDatasetImport> _prepareSnapshot(
  TollInventoryStore store,
  AppDatabase db,
  Map<String, dynamic> json,
) async {
  final bytes = utf8.encode(jsonEncode(json));
  return store.transactionalImporter(db, json, bytes, await _sha256(bytes));
}

Future<void> _selectSnapshot(
  AppDatabase db,
  PreparedDatasetImport prepared, {
  required String version,
  required String sha256,
}) async {
  await db.transaction(() async {
    await prepared.activate();
    await (db.update(
      db.datasetVersions,
    )..where((row) => row.datasetKey.equals(tollInventoryDatasetKey))).write(
      DatasetVersionsCompanion(version: Value(version), sha256: Value(sha256)),
    );
  });
}

Future<String> _sha256(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Map<String, dynamic> _copy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}
