import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/file_crypto.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late PrivateVehicleDocumentStore legacy;
  late WalletStore store;
  final key = SecretKey(List<int>.filled(32, 41));
  const owner = WalletOwner.preparation('preparation-stable-id');

  WalletStore createStore({bool Function()? rootUnavailable}) => WalletStore(
    db: db,
    legacyStore: legacy,
    rootDirectory: () async {
      if (rootUnavailable?.call() ?? false) {
        throw const FileSystemException('Injected storage failure');
      }
      return root;
    },
    cacheDirectory: () async => root,
    masterKey: () async => key,
  );

  Future<WalletDocumentInput> input(String name) async {
    final source = File('${root.path}/$name');
    await source.writeAsString('%PDF-1.7\n$name');
    return WalletDocumentInput(
      source: source,
      originalName: name,
      mimeType: 'application/pdf',
    );
  }

  File encryptedFile(WalletDocument document) => File(
    '${root.path}/wallet_documents/${document.pdf!.encryptedRelativePath}',
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('wallet-preparation-store-');
    db = AppDatabase(NativeDatabase(File('${root.path}/wallet.sqlite')));
    legacy = PrivateVehicleDocumentStore(
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => key,
    );
    store = createStore();
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'preparation owner has independent identity and stable encrypted row',
    () async {
      expect(owner.id, 'preparation-stable-id');
      expect(owner.isDriver, isFalse);
      expect(owner.isPreparation, isTrue);
      expect(owner.driverId, isNull);
      expect(owner.vehicleId, isNull);
      expect({
        owner,
        WalletOwner.vehicle(owner.id),
        WalletOwner.driver(owner.id),
      }, hasLength(3));
      expect(await store.preparationExists(owner.id), isFalse);
      expect(await store.ensurePreparation(owner.id), owner);
      final before = (await db.select(db.walletPreparations).get()).single;
      await Future.wait([
        store.ensurePreparation(owner.id),
        createStore().ensurePreparation(owner.id),
      ]);
      final after = (await db.select(db.walletPreparations).get()).single;
      expect(after.encryptedMetadata, orderedEquals(before.encryptedMetadata));
      expect(
        utf8.decode(after.encryptedMetadata, allowMalformed: true),
        isNot(contains(owner.id)),
      );
      expect(
        jsonDecode(
          utf8.decode(
            await FileCrypto().decryptBytes(after.encryptedMetadata, key),
          ),
        ),
        {'id': owner.id},
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${root.path}/wallet.sqlite')));
      store = createStore();
      expect(await store.listPreparations(), [owner]);
      expect(await store.preparationExists(owner.id), isTrue);
      expect(await db.select(db.vehicles).get(), isEmpty);
    },
  );

  test(
    'all six preparation types roundtrip without a vehicle across restart',
    () async {
      await store.ensurePreparation(owner.id);
      const types = [
        WalletDocumentType.trafficLicense,
        WalletDocumentType.soat,
        WalletDocumentType.rtm,
        WalletDocumentType.appraisal,
        WalletDocumentType.salePurchase,
        WalletDocumentType.other,
      ];
      for (final type in types) {
        final document = await store.saveDocument(
          owner: owner,
          type: type,
          pdf: await input('${type.value}.pdf'),
          metadata: {'note': 'private preparation note'},
        );
        final ciphertext = await encryptedFile(document).readAsBytes();
        expect(
          utf8.decode(ciphertext, allowMalformed: true),
          isNot(contains('%PDF')),
        );
      }
      await db.close();
      db = AppDatabase(NativeDatabase(File('${root.path}/wallet.sqlite')));
      store = createStore();
      final documents = await store.listDocuments(owner: owner);
      expect(documents, hasLength(types.length));
      for (final document in documents) {
        expect(document.owner, owner);
        expect(document.metadata['note'], 'private preparation note');
        expect(
          utf8.decode(
            await store.readDocumentBytes(document, WalletDocumentSide.pdf),
          ),
          '%PDF-1.7\n${document.type.value}.pdf',
        );
      }
      final rows = await db.select(db.privateDocuments).get();
      expect(
        rows.every(
          (r) =>
              r.vehicleId == null &&
              r.driverId == null &&
              r.preparationId == owner.id,
        ),
        isTrue,
      );
      expect(await db.select(db.vehicles).get(), isEmpty);
    },
  );

  test(
    'unknown preparation and invalid types cannot write documents',
    () async {
      final pdf = await input('file.pdf');
      await expectLater(
        store.saveDocument(
          owner: owner,
          type: WalletDocumentType.soat,
          pdf: pdf,
        ),
        throwsArgumentError,
      );
      for (final id in ['', ' ', ' padded ', 'bad\u0000id']) {
        await expectLater(store.ensurePreparation(id), throwsArgumentError);
      }
      await store.ensurePreparation(owner.id);
      for (final type in [
        WalletDocumentType.identityCard,
        WalletDocumentType.driverLicense,
        WalletDocumentType.voluntaryInsurance,
      ]) {
        await expectLater(
          store.saveDocument(owner: owner, type: type, pdf: pdf),
          throwsArgumentError,
        );
      }
      expect(await store.listDocuments(), isEmpty);
    },
  );

  test(
    'vehicle cleanup cannot affect preparation even with the same ID',
    () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: owner.id, plate: 'ABC123'));
      await store.ensurePreparation(owner.id);
      final preparation = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.soat,
        pdf: await input('preparation.pdf'),
      );
      final vehicle = await store.saveDocument(
        owner: WalletOwner.vehicle(owner.id),
        type: WalletDocumentType.soat,
        pdf: await input('vehicle.pdf'),
      );
      await store.deleteForVehicle(owner.id);
      await (db.delete(db.vehicles)..where((r) => r.id.equals(owner.id))).go();
      expect(
        await store.listDocuments(owner: WalletOwner.vehicle(owner.id)),
        isEmpty,
      );
      expect(
        (await store.listDocuments(owner: owner)).single.id,
        preparation.id,
      );
      expect(await encryptedFile(vehicle).exists(), isFalse);
      expect(await encryptedFile(preparation).exists(), isTrue);
      expect(await store.preparationExists(owner.id), isTrue);
      expect(
        utf8.decode(
          await store.readDocumentBytes(preparation, WalletDocumentSide.pdf),
        ),
        contains('preparation.pdf'),
      );
    },
  );

  test(
    'replacement and preparation deletion clean only their own files',
    () async {
      await store.ensurePreparation(owner.id);
      final original = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.soat,
        pdf: await input('original.pdf'),
      );
      final other = await store.ensurePreparation('other-preparation');
      final retained = await store.saveDocument(
        owner: other,
        type: WalletDocumentType.soat,
        pdf: await input('retained.pdf'),
      );
      final replacement = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.soat,
        pdf: await input('replacement.pdf'),
      );
      expect(await encryptedFile(original).exists(), isFalse);
      expect(
        (await store.listDocuments(owner: owner)).single.id,
        replacement.id,
      );
      final preview = await store.decryptForView(
        replacement,
        WalletDocumentSide.pdf,
      );
      await store.deletePreparation(owner.id, isAuthorized: () => true);
      expect(await preview.exists(), isFalse);
      expect(await encryptedFile(replacement).exists(), isFalse);
      expect(await encryptedFile(retained).exists(), isTrue);
      expect(await store.preparationExists(owner.id), isFalse);
      expect(await store.listPreparations(), [other]);
      expect((await store.listDocuments()).single.id, retained.id);
      await expectLater(
        store.readDocumentBytes(replacement, WalletDocumentSide.pdf),
        throwsStateError,
      );
      await store.deletePreparation(owner.id);
      expect(store.migrationReport.pendingCleanupCount, 0);
    },
  );

  test(
    'revoked authorization rolls back creation, replacement and deletion',
    () async {
      final denied = throwsA(isA<WalletAuthorizationException>());
      var calls = 0;
      await expectLater(
        store.ensurePreparation(owner.id, isAuthorized: () => ++calls < 3),
        denied,
      );
      expect(await store.preparationExists(owner.id), isFalse);
      await store.ensurePreparation(owner.id);
      final original = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.soat,
        pdf: await input('kept.pdf'),
      );
      calls = 0;
      await expectLater(
        store.saveDocument(
          owner: owner,
          type: WalletDocumentType.soat,
          pdf: await input('rejected.pdf'),
          isAuthorized: () => ++calls < 4,
        ),
        denied,
      );
      expect((await store.listDocuments(owner: owner)).single.id, original.id);
      expect(await encryptedFile(original).exists(), isTrue);
      calls = 0;
      await expectLater(
        store.deletePreparation(owner.id, isAuthorized: () => ++calls < 3),
        denied,
      );
      expect(await store.preparationExists(owner.id), isTrue);
      expect((await store.listDocuments(owner: owner)).single.id, original.id);
      expect(await encryptedFile(original).exists(), isTrue);
      final files = await Directory('${root.path}/wallet_documents')
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(files, hasLength(1));
      expect(
        await (db.select(
          db.walletMigrations,
        )..where((r) => r.id.like('cleanup:%'))).get(),
        isEmpty,
      );
    },
  );

  test(
    'encrypted preparation and document identities reject relabeling',
    () async {
      await store.ensurePreparation(owner.id);
      final original = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.soat,
        pdf: await input('kept.pdf'),
      );
      await store.ensurePreparation('other');
      await (db.update(
        db.privateDocuments,
      )..where((r) => r.id.equals(original.id))).write(
        const PrivateDocumentsCompanion(preparationId: Value('other')),
      );
      await expectLater(
        store.listDocuments(owner: const WalletOwner.preparation('other')),
        throwsFormatException,
      );
      await db.customStatement(
        "UPDATE wallet_preparations SET id='changed' WHERE id=?",
        [owner.id],
      );
      await expectLater(
        store.preparationExists('changed'),
        throwsFormatException,
      );
      await expectLater(
        store.ensurePreparation('changed'),
        throwsFormatException,
      );
      await expectLater(store.listPreparations(), throwsFormatException);
    },
  );

  test(
    'preparation deletion journals cleanup failure and retries on reopen',
    () async {
      var unavailable = false;
      store = createStore(rootUnavailable: () => unavailable);
      await store.ensurePreparation(owner.id);
      final document = await store.saveDocument(
        owner: owner,
        type: WalletDocumentType.appraisal,
        pdf: await input('pending.pdf'),
      );
      unavailable = true;
      await store.deletePreparation(owner.id);
      expect(await store.preparationExists(owner.id), isFalse);
      expect(await store.listDocuments(owner: owner), isEmpty);
      expect(await encryptedFile(document).exists(), isTrue);
      expect(store.migrationReport.pendingCleanupCount, 1);
      expect(
        await (db.select(
          db.walletMigrations,
        )..where((r) => r.id.like('cleanup:%'))).get(),
        hasLength(1),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${root.path}/wallet.sqlite')));
      store = createStore();
      await store.initialize();
      expect(await encryptedFile(document).exists(), isFalse);
      expect(store.migrationReport.pendingCleanupCount, 0);
      expect(await store.listPreparations(), isEmpty);
    },
  );

  test('v7 document metadata without preparationId remains readable', () async {
    await store.initialize();
    final encrypted = await FileCrypto().encryptBytes(
      utf8.encode(
        jsonEncode({
          'id': 'v7-driver',
          'driverId': WalletStore.principalId,
          'vehicleId': null,
          'type': WalletDocumentType.identityCard.value,
          'metadata': {'keep': 'yes'},
        }),
      ),
      key,
    );
    await db
        .into(db.privateDocuments)
        .insert(
          PrivateDocumentsCompanion.insert(
            id: 'v7-driver',
            driverId: const Value(WalletStore.principalId),
            type: WalletDocumentType.identityCard.value,
            encryptedMetadata: encrypted,
          ),
        );
    final document = (await store.listDocuments()).single;
    expect(document.owner, const WalletOwner.driver(WalletStore.principalId));
    expect(document.metadata, {'keep': 'yes'});
  });
}
