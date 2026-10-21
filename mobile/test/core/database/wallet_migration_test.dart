import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v6 migration preserves existing data and creates wallet constraints',
    () async {
      final root = await Directory.systemTemp.createTemp('wallet-migration-');
      final file = File('${root.path}/app.sqlite');
      final old = sqlite3.open(file.path);
      old.execute('''CREATE TABLE vehicles (
      id TEXT NOT NULL PRIMARY KEY, plate TEXT NOT NULL,
      nickname TEXT, kind TEXT NOT NULL DEFAULT 'car',
      service_type TEXT NOT NULL DEFAULT 'private', subtype TEXT,
      registration_city TEXT, brand TEXT, model TEXT, year INTEGER,
      color TEXT, fuel TEXT, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL)''');
      old.execute(
        "INSERT INTO vehicles (id,plate,created_at,updated_at) "
        "VALUES ('existing','ABC123',0,0)",
      );
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
