import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'legacy_database_fixture.dart';

void main() {
  test(
    'v6 migration preserves existing data and creates wallet constraints',
    () async {
      final root = await Directory.systemTemp.createTemp('wallet-migration-');
      final file = File('${root.path}/app.sqlite');
      final old = sqlite3.open(file.path);
      createLegacyDatabaseFixture(old, version: 6);
      old.execute(
        "INSERT INTO vehicles (id,plate,created_at,updated_at) "
        "VALUES ('existing','ABC123',0,0)",
      );
      old.execute('''
        INSERT INTO vehicle_obligations
          (id, vehicle_id, type, status, due_date, created_at, updated_at)
        VALUES ('existing:soat', 'existing', 'soat', 'configured',
          1799971200, 0, 0)
      ''');
      old.execute('''
        INSERT INTO restriction_coverages (
          id, jurisdiction_id, jurisdiction_name, vehicle_kind, service_type,
          rules_json, verified_at, stale_after, source_urls_json, updated_at
        ) VALUES ('coverage-1', 'co-dc-bogota', 'Bogota', 'car', 'private',
          '[]', 1760000000, 1770000000, '[]', 123456)
      ''');
      old.execute('CREATE TABLE preserved_fixture (payload TEXT NOT NULL)');
      old.execute(
        "INSERT INTO preserved_fixture VALUES ('keep-all-existing-data')",
      );
      old.execute('PRAGMA user_version=6');
      old.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        expect((await db.select(db.vehicles).get()).single.plate, 'ABC123');
        expect(
          (await db.select(db.vehicleObligations).get()).single.id,
          'existing:soat',
        );
        final coverage =
            (await db.select(db.restrictionCoverages).get()).single;
        expect(coverage.jurisdictionId, 'co-dc-bogota');
        expect(coverage.coverageCompleteness, 'legacy');
        expect(
          (await db.customSelect('SELECT * FROM preserved_fixture').getSingle())
              .read<String>('payload'),
          'keep-all-existing-data',
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          AppDatabase.currentSchemaVersion,
        );
        await db.customStatement(
          "INSERT INTO driver_profiles "
          "(id,slot,encrypted_metadata) VALUES ('principal',0,X'01')",
        );
        await db.customStatement(
          "INSERT INTO driver_profiles "
          "(id,slot,encrypted_metadata) VALUES ('second',1,X'01')",
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO driver_profiles "
            "(id,slot,encrypted_metadata) VALUES ('third',2,X'01')",
          ),
          throwsException,
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO private_documents "
            "(id,type,encrypted_metadata) VALUES ('no-owner','soat',X'01')",
          ),
          throwsException,
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO private_documents "
            "(id,type,vehicle_id,encrypted_metadata) "
            "VALUES ('fake','soat','missing',X'01')",
          ),
          throwsException,
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO private_documents "
            "(id,type,vehicle_id,driver_id,encrypted_metadata) "
            "VALUES ('both','soat','existing','principal',X'01')",
          ),
          throwsException,
        );
        await db.customStatement(
          "INSERT INTO private_documents "
          "(id,type,vehicle_id,encrypted_metadata) "
          "VALUES ('real','soat','existing',X'01')",
        );
        await (db.delete(
          db.vehicles,
        )..where((v) => v.id.equals('existing'))).go();
        expect(
          await db.customSelect('SELECT * FROM private_documents').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );
}
