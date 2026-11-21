import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v10 to v11 preserves user, dataset, alert, and coverage rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'picoradar_availability_migration_',
      );
      final path = '${directory.path}${Platform.pathSeparator}app.sqlite';
      final bytes = Uint8List.fromList([0, 7, 128, 255]);
      final alertJson = '{"enabled":true,"quietHours":false}';
      final database = AppDatabase(NativeDatabase(File(path)));
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));
      await database
          .into(database.privateDocuments)
          .insert(
            PrivateDocumentsCompanion.insert(
              id: 'document-1',
              vehicleId: const Value('vehicle-1'),
              type: 'soat',
              encryptedMetadata: bytes,
            ),
          );
      await database
          .into(database.datasetVersions)
          .insert(
            DatasetVersionsCompanion.insert(
              id: 'restrictions',
              datasetKey: 'restrictions',
              version: 'fixture-10',
              sha256: Value('a' * 64),
              status: 'installed',
              publicationRevision: const Value(7),
              appliedAt: Value(DateTime.utc(2026, 11, 10)),
            ),
          );
      await database
          .into(database.restrictionCoverages)
          .insert(
            RestrictionCoveragesCompanion.insert(
              id: 'co-fixture:car:private',
              jurisdictionId: 'co-fixture',
              jurisdictionName: 'Fixture',
              vehicleKind: 'car',
              serviceType: 'private',
              rulesJson: '[{"id":"preserve-me"}]',
              verifiedAt: DateTime.utc(2026, 11, 1),
              staleAfter: DateTime.utc(2026, 12, 1),
              sourceUrlsJson: '["https://example.test/source"]',
              coverageCompleteness: const Value('partial'),
            ),
          );
      await database.writeAlertSettings('vehicle-1', 'pico', alertJson);
      await database.close();

      final legacy = sqlite3.open(path);
      legacy.execute('DROP TABLE restriction_jurisdiction_availability');
      legacy.execute('PRAGMA user_version = 10');

      final migrated = AppDatabase(
        NativeDatabase.opened(legacy, closeUnderlyingOnClose: false),
      );
      try {
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          11,
        );
        final vehicle = await migrated.select(migrated.vehicles).getSingle();
        expect(vehicle.id, 'vehicle-1');
        expect(vehicle.plate, 'ABC123');
        final document = await migrated
            .customSelect(
              'SELECT encrypted_metadata FROM private_documents WHERE id = ?',
              variables: [Variable.withString('document-1')],
            )
            .getSingle();
        expect(document.read<Uint8List>('encrypted_metadata'), bytes);

        final dataset = await migrated
            .select(migrated.datasetVersions)
            .getSingle();
        expect(dataset.version, 'fixture-10');
        expect(dataset.sha256, 'a' * 64);
        expect(dataset.publicationRevision, 7);
        final coverage = await migrated
            .select(migrated.restrictionCoverages)
            .getSingle();
        expect(coverage.rulesJson, '[{"id":"preserve-me"}]');
        expect(coverage.coverageCompleteness, 'partial');
        expect(
          await migrated
              .customSelect('SELECT * FROM alert_delivery_settings')
              .get(),
          hasLength(1),
        );
        final alert = await migrated
            .customSelect('SELECT settings_json FROM alert_delivery_settings')
            .getSingle();
        expect(alert.read<String>('settings_json'), alertJson);
        expect(
          await migrated
              .select(migrated.restrictionJurisdictionAvailability)
              .get(),
          isEmpty,
        );
      } finally {
        await migrated.close();
        legacy.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
