import 'dart:convert';
import 'dart:io';

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
      snapshot = File('${root.path}/tolls_inventory.json');
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
        snapshotFile: snapshot,
        bundledLoader: () async => bundled,
      );

      final first = await store.load();
      expect(first.version, '2026.09.05-viaje-r2');
      expect(await snapshot.exists(), isFalse);

      final imported = _copy(assetJson)..['version'] = '2026.09.06-local-test';
      await store.datasetImporter(db, imported);

      expect((await store.load()).version, '2026.09.06-local-test');
      expect(await snapshot.exists(), isTrue);
    });

    test(
      'failed import preserves the previous snapshot byte for byte',
      () async {
        final store = TollInventoryStore(
          snapshotFile: snapshot,
          bundledLoader: () async => jsonEncode(assetJson),
        );
        await store.datasetImporter(db, assetJson);
        final previous = await snapshot.readAsBytes();
        final invalid = _copy(assetJson);
        ((invalid['records'] as List)[0]['tariffsBySourceCategoryCOP']
                as Map<String, dynamic>)['category_1'] =
            0;

        await expectLater(
          store.datasetImporter(db, invalid),
          throwsA(isA<DatasetSyncException>()),
        );

        expect(await snapshot.readAsBytes(), previous);
        expect((await store.load()).version, '2026.09.05-viaje-r2');
      },
    );
  });
}

Map<String, dynamic> _copy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}
