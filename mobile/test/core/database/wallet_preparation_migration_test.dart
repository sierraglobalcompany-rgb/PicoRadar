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

import 'legacy_database_fixture.dart';

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
      final old = sqlite3.open(file.path);
      createLegacyDatabaseFixture(old, version: version);
      old.execute('''
        INSERT INTO vehicles (id, plate, created_at, updated_at)
        VALUES ('vehicle', 'ABC123', 123, 456)
      ''');
      old.execute('CREATE TABLE unrelated_data (value TEXT NOT NULL)');
      old.execute("INSERT INTO unrelated_data VALUES ('keep')");
      if (version >= 7) {
        old.execute("INSERT INTO driver_profiles VALUES ('principal',0,?)", [
          ciphertext,
        ]);
        if (version == 7) {
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
        } else {
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
        }
        old.execute("INSERT INTO wallet_migrations VALUES ('legacy',?,987)", [
          ciphertext,
        ]);
      }
      if (version == 8) {
        old.execute("INSERT INTO wallet_preparations VALUES ('historical',?)", [
          ciphertext,
        ]);
      }
      old.close();
      var db = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          AppDatabase.currentSchemaVersion,
        );
        expect((await db.select(db.vehicles).get()).single.plate, 'ABC123');
        expect(
          (await db.customSelect('SELECT * FROM unrelated_data').getSingle())
              .read<String>('value'),
          'keep',
        );
        if (version >= 7) {
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
          if (version == 8) {
            expect(
              (await db.select(db.walletPreparations).get())
                  .single
                  .encryptedMetadata,
              orderedEquals(ciphertext),
            );
          }
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
