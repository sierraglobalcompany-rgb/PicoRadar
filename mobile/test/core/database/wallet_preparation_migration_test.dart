import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/file_crypto.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  for (final version in [6, 7, 8]) {
    test('v$version preserves data and enforces three exclusive owners', () async {
      final root = await Directory.systemTemp.createTemp('wallet-preparation-');
      final file = File('${root.path}/wallet.sqlite');
      final key = SecretKey(List<int>.filled(32, 23));
      final crypto = FileCrypto();
      final metadata = {
        'id': 'kept',
        'driverId': null,
        'vehicleId': 'vehicle',
        'type': 'soat',
        'metadata': {'private': 'preserve-me'},
      };
      final ciphertext = await crypto.encryptBytes(
        utf8.encode(jsonEncode(metadata)),
        key,
      );
      if (version < 8) {
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
          "VALUES ('vehicle','ABC123',123,456)",
        );
        old.execute('CREATE TABLE unrelated_data (value TEXT NOT NULL)');
        old.execute("INSERT INTO unrelated_data VALUES ('keep')");
        if (version == 7) {
          old.execute('''CREATE TABLE driver_profiles (
            id TEXT NOT NULL PRIMARY KEY, slot INTEGER NOT NULL UNIQUE,
            encrypted_metadata BLOB NOT NULL,
            CHECK (slot IN (0, 1)),
            CHECK ((slot = 0 AND id = 'principal') OR
              (slot = 1 AND id <> 'principal')))''');
          old.execute('''CREATE TABLE private_documents (
            id TEXT NOT NULL PRIMARY KEY,
            driver_id TEXT REFERENCES driver_profiles(id) ON DELETE CASCADE,
            vehicle_id TEXT REFERENCES vehicles(id) ON DELETE CASCADE,
            type TEXT NOT NULL, encrypted_metadata BLOB NOT NULL,
            imported_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            CHECK ((driver_id IS NOT NULL AND vehicle_id IS NULL) OR
              (driver_id IS NULL AND vehicle_id IS NOT NULL)))''');
          old.execute(
            'CREATE UNIQUE INDEX private_documents_driver_type_idx '
            'ON private_documents(driver_id,type)',
          );
          old.execute(
            'CREATE UNIQUE INDEX private_documents_vehicle_type_idx '
            'ON private_documents(vehicle_id,type)',
          );
          old.execute('''CREATE TABLE wallet_migrations (
            id TEXT NOT NULL PRIMARY KEY, encrypted_metadata BLOB NOT NULL,
            completed_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')))''');
          old.execute("INSERT INTO driver_profiles VALUES ('principal',0,?)", [
            ciphertext,
          ]);
          old.execute(
            "INSERT INTO private_documents "
            "(id,vehicle_id,type,encrypted_metadata,imported_at) "
            "VALUES ('kept','vehicle','soat',?,123456)",
            [ciphertext],
          );
          old.execute(
            "INSERT INTO private_documents "
            "(id,driver_id,type,encrypted_metadata,imported_at) "
            "VALUES ('driver-copy','principal','identity_card',?,456789)",
            [ciphertext],
          );
          old.execute("INSERT INTO wallet_migrations VALUES ('legacy',?,987)", [
            ciphertext,
          ]);
        }
        old.execute('PRAGMA user_version=$version');
        old.close();
      }
      var db = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          AppDatabase.currentSchemaVersion,
        );
        if (version < 8) {
          expect((await db.select(db.vehicles).get()).single.plate, 'ABC123');
          expect(
            (await db.customSelect('SELECT * FROM unrelated_data').getSingle())
                .read<String>('value'),
            'keep',
          );
        } else {
          await db.customStatement(
            "INSERT INTO vehicles (id,plate) "
            "VALUES ('vehicle','ABC123')",
          );
        }
        if (version == 7) {
          final rows = await db.select(db.privateDocuments).get();
          expect(rows, hasLength(2));
          for (final row in rows) {
            expect(row.encryptedMetadata, orderedEquals(ciphertext));
            expect(row.preparationId, isNull);
          }
          final kept = rows.singleWhere((r) => r.id == 'kept');
          expect(kept.vehicleId, 'vehicle');
          expect(kept.importedAt.millisecondsSinceEpoch, 123456000);
          expect(
            jsonDecode(
              utf8.decode(
                await crypto.decryptBytes(kept.encryptedMetadata, key),
              ),
            ),
            metadata,
          );
          expect(
            (await db.select(db.driverProfiles).get()).single.encryptedMetadata,
            orderedEquals(ciphertext),
          );
          expect(
            (await db.select(db.walletMigrations).get())
                .single
                .encryptedMetadata,
            orderedEquals(ciphertext),
          );
        } else {
          await db.customStatement(
            "INSERT INTO driver_profiles "
            "(id,slot,encrypted_metadata) VALUES ('principal',0,X'01')",
          );
        }
        await db.customStatement(
          "INSERT INTO wallet_preparations "
          "(id,encrypted_metadata) VALUES ('preparation',X'01')",
        );

        // Exercise all 2^3 combinations, not just one ambiguous-owner pair.
        for (var mask = 0; mask < 8; mask++) {
          final operation = db.customStatement(
            'INSERT INTO private_documents '
            '(id,driver_id,vehicle_id,preparation_id,type,encrypted_metadata) '
            'VALUES (?,?,?,?,?,?)',
            [
              'combination-$mask',
              (mask & 1) != 0 ? 'principal' : null,
              (mask & 2) != 0 ? 'vehicle' : null,
              (mask & 4) != 0 ? 'preparation' : null,
              'other',
              Uint8List.fromList([1]),
            ],
          );
          if ([1, 2, 4].contains(mask)) {
            await operation;
          } else {
            await expectLater(operation, throwsException);
          }
        }
        for (final owner in ['driver_id', 'vehicle_id', 'preparation_id']) {
          await expectLater(
            db.customStatement(
              'INSERT INTO private_documents '
              '(id,$owner,type,encrypted_metadata) VALUES (?,?,?,?)',
              [
                'missing-$owner',
                'missing',
                'other',
                Uint8List.fromList([1]),
              ],
            ),
            throwsException,
          );
          final ownerId = switch (owner) {
            'driver_id' => 'principal',
            'vehicle_id' => 'vehicle',
            _ => 'preparation',
          };
          await expectLater(
            db.customStatement(
              'INSERT INTO private_documents '
              '(id,$owner,type,encrypted_metadata) VALUES (?,?,?,?)',
              [
                'duplicate-$owner',
                ownerId,
                'other',
                Uint8List.fromList([1]),
              ],
            ),
            throwsException,
          );
        }
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        await db.customStatement("DELETE FROM vehicles WHERE id='vehicle'");
        var documents = await db.select(db.privateDocuments).get();
        expect(documents.where((r) => r.vehicleId != null), isEmpty);
        expect(
          documents.where((r) => r.preparationId == 'preparation'),
          hasLength(1),
        );
        await db.customStatement(
          "DELETE FROM wallet_preparations WHERE id='preparation'",
        );
        documents = await db.select(db.privateDocuments).get();
        expect(documents, isNotEmpty);
        expect(documents.every((r) => r.driverId == 'principal'), isTrue);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    });
  }
}
