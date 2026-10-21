import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/pico_placa/data/bundled_restrictions.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> load(Map<String, dynamic> dataset) {
    return ensureBundledRestrictionsLoaded(
      db,
      bundledLoader: () async => jsonEncode(dataset),
    );
  }

  Future<void> install({
    String status = 'bundled',
    String version = '2026.08.31-c10b-a',
    int publicationRevision = 0,
    String? sha256,
  }) async {
    await importRestrictionsDataset(db, _dataset(city: 'old-city'));
    await db
        .into(db.datasetVersions)
        .insert(
          DatasetVersionsCompanion.insert(
            id: 'existing-restrictions-id',
            datasetKey: restrictionsDatasetKey,
            version: version,
            status: status,
            publicationRevision: Value(publicationRevision),
            sha256: Value(sha256),
            appliedAt: Value(DateTime.utc(2026, 9, 10)),
          ),
        );
  }

  test(
    'asset loading releases the DB and a concurrent remote install wins',
    () async {
      await install();
      final loading = Completer<void>();
      final asset = Completer<String>();
      final pending = ensureBundledRestrictionsLoaded(
        db,
        bundledLoader: () {
          loading.complete();
          return asset.future;
        },
      );
      addTearDown(() async {
        if (!asset.isCompleted) asset.complete(jsonEncode(_dataset()));
        await pending;
      });
      await loading.future;
      await db.select(db.vehicles).get().timeout(const Duration(seconds: 2));
      await (db.update(
        db.datasetVersions,
      )..where((row) => row.datasetKey.equals(restrictionsDatasetKey))).write(
        const DatasetVersionsCompanion(
          status: Value('installed'),
          version: Value('2026.09.11-remote'),
          publicationRevision: Value(1),
        ),
      );
      asset.complete(jsonEncode(_dataset()));
      await pending;
      final metadata = await db.select(db.datasetVersions).getSingle();
      expect(metadata.version, '2026.09.11-remote');
      expect(metadata.status, 'installed');
      expect(
        (await db.select(db.restrictionCoverages).get()).single.jurisdictionId,
        'old-city',
      );
    },
  );

  test('fresh install loads coverage and bundled metadata', () async {
    await load(_dataset());
    final rows = await db.select(db.restrictionCoverages).get();
    final metadata = await db.select(db.datasetVersions).getSingle();
    expect(rows.single.jurisdictionId, 'new-city');
    expect(metadata.version, '2026.09.10-test');
    expect(metadata.status, 'bundled');
    expect(metadata.publicationRevision, 0);
  });

  test(
    'legacy upgrade loads the real APK asset and preserves private data',
    () async {
      await install();
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'saved-car', plate: 'ABC123'));
      await db
          .into(db.vehicleObligations)
          .insert(
            VehicleObligationsCompanion.insert(
              id: 'saved-soat',
              vehicleId: 'saved-car',
              type: 'soat',
              status: 'configured',
              dueDate: Value(DateTime(2027, 1, 1)),
            ),
          );
      await db
          .into(db.notificationPreferences)
          .insert(NotificationPreferencesCompanion.insert(id: 'saved-alerts'));
      final vehicles = await db.select(db.vehicles).get();
      final obligations = await db.select(db.vehicleObligations).get();
      final preferences = await db.select(db.notificationPreferences).get();
      final asset = jsonDecode(
        await File(bundledRestrictionsAsset).readAsString(),
      ) as Map<String, dynamic>;

      await load(asset);

      expect(await db.select(db.vehicles).get(), vehicles);
      expect(await db.select(db.vehicleObligations).get(), obligations);
      expect(await db.select(db.notificationPreferences).get(), preferences);
      final metadata = await db.select(db.datasetVersions).getSingle();
      expect(metadata.id, 'existing-restrictions-id');
      expect(metadata.version, asset['version']);
      expect(metadata.status, 'bundled');
      final rows = await db.select(db.restrictionCoverages).get();
      expect(
        rows.map((row) => row.jurisdictionId),
        contains('co-ant-medellin'),
      );
      expect(
        rows.map((row) => row.jurisdictionId),
        isNot(contains('old-city')),
      );
    },
  );

  test('repeated startup is idempotent including appliedAt and coverage timestamps', () async {
    await install();
    await load(_dataset());
    final beforeRows = await db.select(db.restrictionCoverages).get();
    final beforeVersion = await db.select(db.datasetVersions).getSingle();
    await load(_dataset());
    expect(await db.select(db.restrictionCoverages).get(), beforeRows);
    expect(await db.select(db.datasetVersions).getSingle(), beforeVersion);
  });

  for (final status in [
    'installed',
    'remote',
    'published',
    'current',
    'unknown',
  ]) {
    test('preserves $status even when the APK is newer', () async {
      await install(status: status);
      final rows = await db.select(db.restrictionCoverages).get();
      final metadata = await db.select(db.datasetVersions).getSingle();
      await load(_dataset());
      expect(await db.select(db.restrictionCoverages).get(), rows);
      expect(await db.select(db.datasetVersions).getSingle(), metadata);
    });
  }

  for (final version in [
    '2026.09.11-newer',
    '2026.09.10-another-build',
    'unknown-version',
    '2026.02.31-invalid-date',
    '2026.08.31garbage',
  ]) {
    test(
      'preserves bundled version with newer or ambiguous date: $version',
      () async {
        await install(version: version);
        final rows = await db.select(db.restrictionCoverages).get();
        final metadata = await db.select(db.datasetVersions).getSingle();
        await load(_dataset(generatedAt: '2026-09-10T23:59:00Z'));
        expect(await db.select(db.restrictionCoverages).get(), rows);
        expect(await db.select(db.datasetVersions).getSingle(), metadata);
      },
    );
  }

  test(
    'uses asset generatedAt rather than a newer-looking version string',
    () async {
      await install(version: '2026.09.09-local');
      final rows = await db.select(db.restrictionCoverages).get();
      await load(_dataset(generatedAt: '2026-09-08T12:00:00Z'));
      expect(await db.select(db.restrictionCoverages).get(), rows);
      expect(
        (await db.select(db.datasetVersions).getSingle()).version,
        '2026.09.09-local',
      );
    },
  );

  test('coverage without provenance is preserved', () async {
    await importRestrictionsDataset(db, _dataset(city: 'unknown-city'));
    final rows = await db.select(db.restrictionCoverages).get();
    await load(_dataset());
    expect(await db.select(db.restrictionCoverages).get(), rows);
    expect(await db.select(db.datasetVersions).get(), isEmpty);
  });

  test(
    'discordant candidate version and generation dates are not installed',
    () async {
      await install();
      final rows = await db.select(db.restrictionCoverages).get();
      final metadata = await db.select(db.datasetVersions).getSingle();
      await load(_dataset(generatedAt: '2026-09-12T00:00:00Z'));
      expect(await db.select(db.restrictionCoverages).get(), rows);
      expect(await db.select(db.datasetVersions).getSingle(), metadata);
    },
  );

  test(
    'remote metadata with missing coverage is not replaced by bundled data',
    () async {
      await install(status: 'installed');
      await db.delete(db.restrictionCoverages).go();
      final metadata = await db.select(db.datasetVersions).getSingle();
      await load(_dataset());
      expect(await db.select(db.restrictionCoverages).get(), isEmpty);
      expect(await db.select(db.datasetVersions).getSingle(), metadata);
    },
  );

  for (final hasRevision in [true, false]) {
    test(
      'contradictory bundled metadata with remote provenance is preserved: $hasRevision',
      () async {
        await install(
          publicationRevision: hasRevision ? 1 : 0,
          sha256: hasRevision ? null : 'remote-content-hash',
        );
        final rows = await db.select(db.restrictionCoverages).get();
        final metadata = await db.select(db.datasetVersions).getSingle();
        await load(_dataset());
        expect(await db.select(db.restrictionCoverages).get(), rows);
        expect(await db.select(db.datasetVersions).getSingle(), metadata);
      },
    );
  }

  for (final generatedAt in ['invalid', '2026-09-10T12:00:00']) {
    test(
      'invalid or timezone-ambiguous generatedAt preserves installed data: $generatedAt',
      () async {
        await install();
        final rows = await db.select(db.restrictionCoverages).get();
        final metadata = await db.select(db.datasetVersions).getSingle();
        await expectLater(
          load(_dataset(generatedAt: generatedAt)),
          throwsA(isA<DatasetSyncException>()),
        );
        expect(await db.select(db.restrictionCoverages).get(), rows);
        expect(await db.select(db.datasetVersions).getSingle(), metadata);
      },
    );
  }

  test(
    'invalid candidate schema leaves coverage and version unchanged',
    () async {
      await install();
      final rows = await db.select(db.restrictionCoverages).get();
      final metadata = await db.select(db.datasetVersions).getSingle();
      await expectLater(
        load(_dataset()..['schemaVersion'] = 99),
        throwsA(isA<DatasetSyncException>()),
      );
      expect(await db.select(db.restrictionCoverages).get(), rows);
      expect(await db.select(db.datasetVersions).getSingle(), metadata);
    },
  );

  test(
    'metadata write failure rolls back the already replaced coverage',
    () async {
      await install();
      final rows = await db.select(db.restrictionCoverages).get();
      final metadata = await db.select(db.datasetVersions).getSingle();
      await db.customStatement('''
      CREATE TEMP TRIGGER reject_dataset_update
      BEFORE UPDATE ON dataset_versions
      BEGIN SELECT RAISE(ABORT, 'test metadata failure'); END;
    ''');
      await expectLater(load(_dataset()), throwsA(isA<Exception>()));
      expect(await db.select(db.restrictionCoverages).get(), rows);
      expect(await db.select(db.datasetVersions).getSingle(), metadata);
    },
  );
}

Map<String, dynamic> _dataset({
  String city = 'new-city',
  String generatedAt = '2026-09-10T00:00:00Z',
}) => {
  'schemaVersion': 1,
  'datasetKey': restrictionsDatasetKey,
  'version': '2026.09.10-test',
  'generatedAt': generatedAt,
  'jurisdictions': [
    {
      'id': city,
      'name': 'Synthetic test city',
      'coverages': [
        {
          'vehicleKind': 'car',
          'serviceType': 'private',
          'verifiedAt': generatedAt,
          'staleAfter': '2026-10-01T05:00:00Z',
          'sourceUrls': ['https://example.test/NON_PRODUCTION_FIXTURE'],
          'rules': <Map<String, Object?>>[],
        },
      ],
    },
  ],
};
