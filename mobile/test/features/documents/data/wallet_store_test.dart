import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  final key = SecretKey(List<int>.filled(32, 19));

  WalletStore createStore() => WalletStore(
    db: db,
    legacyStore: legacy,
    rootDirectory: () async => root,
    cacheDirectory: () async => root,
    masterKey: () async => key,
  );

  Future<WalletDocumentInput> input(String name, List<int> bytes) async {
    final file = File('${root.path}/$name');
    await file.writeAsBytes(bytes);
    return WalletDocumentInput(
      source: file,
      originalName: name,
      mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'image/png',
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('wallet-test-');
    db = AppDatabase(NativeDatabase.memory());
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
    'initialization is idempotent with no vehicle and one Principal',
    () async {
      await store.initialize();
      await store.initialize();
      final drivers = await store.listDrivers();
      expect(drivers, hasLength(1));
      expect(drivers.single.id, 'principal');
      expect(drivers.single.displayName, 'Principal');
      expect(drivers.single.isPrincipal, isTrue);
      expect(await db.select(db.vehicles).get(), isEmpty);
    },
  );

  test('second driver survives restart and third is rejected', () async {
    await store.initialize();
    final second = await store.saveDriver(displayName: 'Persona sensible');
    await expectLater(store.saveDriver(displayName: 'Third'), throwsStateError);
    store = createStore();
    expect((await store.listDrivers()).last.displayName, 'Persona sensible');
    await store.saveDriver(id: second.id, displayName: 'Nombre actualizado');
    expect((await store.listDrivers()).last.displayName, 'Nombre actualizado');
    final raw = await db.customSelect('SELECT * FROM driver_profiles').get();
    expect(raw.toString(), isNot(contains('Persona sensible')));
    expect(raw.toString(), isNot(contains('Nombre actualizado')));
    await store.saveDriver(id: 'principal', displayName: 'Private name');
    await store.deleteDriver('principal');
    expect((await store.listDrivers()).first.displayName, 'Principal');
    await store.deleteDriver(second.id);
    expect(await store.listDrivers(), hasLength(1));
    await store.saveDriver(displayName: 'Replacement');
    expect(await store.listDrivers(), hasLength(2));
  });

  test('concurrent second profile requests cannot create a third', () async {
    await store.initialize();
    final results = await Future.wait([
      for (final name in ['Second', 'Third'])
        store
            .saveDriver(displayName: name)
            .then<Object>((v) => v, onError: (Object e) => e),
    ]);
    expect(results.whereType<WalletDriver>(), hasLength(1));
    expect(await store.listDrivers(), hasLength(2));
  });

  test(
    'driver front/back save encrypts metadata and bytes across restart',
    () async {
      final front = await input('identity-front.png', [137, 80, 78, 71, 1]);
      final back = await input('identity-back.png', [137, 80, 78, 71, 2]);
      final saved = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        front: front,
        back: back,
        metadata: const {'number': 'sensitive-number-4321'},
      );
      expect(saved.front, isNotNull);
      expect(saved.back, isNotNull);
      expect(saved.pdf, isNull);
      final raw = await db
          .customSelect('SELECT * FROM private_documents')
          .get();
      expect(raw.single.readNullable<String>('vehicle_id'), isNull);
      final encrypted = raw.single.read<Uint8List>('encrypted_metadata');
      final visible = utf8.decode(encrypted, allowMalformed: true);
      expect(visible, isNot(contains('sensitive-number-4321')));
      expect(visible, isNot(contains('identity-front.png')));
      store = createStore();
      final restored = (await store.listDocuments()).single;
      expect(restored.metadata['number'], 'sensitive-number-4321');
      expect(await store.readDocumentBytes(restored, WalletDocumentSide.back), [
        137,
        80,
        78,
        71,
        2,
      ]);
      await store.purgeViewerCache();
    },
  );

  test(
    'unknown owners and mixed PDF/images fail without inserting rows',
    () async {
      final pdf = await input('document.pdf', [37, 80, 68, 70]);
      final front = await input('front.png', [137, 80, 78, 71]);
      for (final owner in [
        const WalletOwner.vehicle('missing'),
        const WalletOwner.driver('missing'),
      ]) {
        await expectLater(
          store.saveDocument(
            owner: owner,
            type: owner.isDriver
                ? WalletDocumentType.identityCard
                : WalletDocumentType.soat,
            pdf: pdf,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        store.saveDocument(
          owner: const WalletOwner.driver('principal'),
          type: WalletDocumentType.identityCard,
          pdf: pdf,
          front: front,
        ),
        throwsArgumentError,
      );
      expect(await store.listDocuments(), isEmpty);
      expect(await db.select(db.vehicles).get(), isEmpty);
    },
  );

  test(
    'failed replacement preserves old copy and removes new ciphertext',
    () async {
      final pdf = await input('valid.pdf', [37, 80, 68, 70, 1]);
      final saved = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.driverLicense,
        pdf: pdf,
      );
      final front = await input('front.png', [137, 80, 78, 71]);
      final missing = WalletDocumentInput(
        source: File('${root.path}/missing.png'),
        originalName: 'missing.png',
        mimeType: 'image/png',
      );
      await expectLater(
        store.saveDocument(
          owner: saved.owner,
          type: saved.type,
          front: front,
          back: missing,
        ),
        throwsArgumentError,
      );
      final restored = (await store.listDocuments()).single;
      expect(restored.id, saved.id);
      expect(
        await (await store.decryptForView(
          restored,
          WalletDocumentSide.pdf,
        )).readAsBytes(),
        [37, 80, 68, 70, 1],
      );
    },
  );

  test(
    'encryption failure after front write rolls back both file and row',
    () async {
      final original = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.driverLicense,
        pdf: await input('original.pdf', [37, 80, 68, 70, 8]),
      );
      final failing = WalletStore(
        db: db,
        legacyStore: legacy,
        rootDirectory: () async => root,
        cacheDirectory: () async => root,
        masterKey: () async => key,
        fileCrypto: _FailSecondEncryption(),
      );
      await expectLater(
        failing.saveDocument(
          owner: original.owner,
          type: original.type,
          front: await input('front.png', [137, 80, 78, 71, 1]),
          back: await input('back.png', [137, 80, 78, 71, 2]),
        ),
        throwsStateError,
      );
      expect((await store.listDocuments()).single.id, original.id);
      final files = await Directory('${root.path}/wallet_documents')
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(files, hasLength(1));
      expect(await store.readDocumentBytes(original, WalletDocumentSide.pdf), [
        37,
        80,
        68,
        70,
        8,
      ]);
    },
  );

  test('authorization lost during encryption aborts replacement and cleans ciphertext', () async {
    final original = await store.saveDocument(
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.driverLicense,
      pdf: await input('original.pdf', [37, 80, 68, 70, 8]),
    );
    var authorized = true;
    final guarded = WalletStore(
      db: db,
      legacyStore: legacy,
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => key,
      fileCrypto: _RevokeOnEncrypt(() => authorized = false),
    );
    await expectLater(
      guarded.saveDocument(
        owner: original.owner,
        type: original.type,
        pdf: await input('replacement.pdf', [37, 80, 68, 70, 9]),
        isAuthorized: () => authorized,
      ),
      throwsA(isA<WalletAuthorizationException>()),
    );
    expect((await store.listDocuments()).single.id, original.id);
    final files = await Directory('${root.path}/wallet_documents')
        .list(recursive: true)
        .where((e) => e is File)
        .toList();
    expect(files, hasLength(1));
  });

  test(
    'unauthorized driver edits and deletes leave profile and document intact',
    () async {
      final doc = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.driverLicense,
        pdf: await input('keep.pdf', [37, 80, 68, 70]),
      );
      await expectLater(
        store.saveDriver(
          id: 'principal',
          displayName: 'Changed',
          isAuthorized: () => false,
        ),
        throwsA(isA<WalletAuthorizationException>()),
      );
      await expectLater(
        store.deleteDriver('principal', isAuthorized: () => false),
        throwsA(isA<WalletAuthorizationException>()),
      );
      await expectLater(
        store.deleteDocument(doc.id, isAuthorized: () => false),
        throwsA(isA<WalletAuthorizationException>()),
      );
      expect((await store.listDrivers()).single.displayName, 'Principal');
      expect((await store.listDocuments()).single.id, doc.id);
    },
  );

  test(
    'metadata ciphertext cannot be swapped across document owners',
    () async {
      final second = await store.saveDriver(displayName: 'Second');
      final one = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        pdf: await input('one.pdf', [37, 80, 68, 70, 1]),
      );
      final two = await store.saveDocument(
        owner: WalletOwner.driver(second.id),
        type: WalletDocumentType.identityCard,
        pdf: await input('two.pdf', [37, 80, 68, 70, 2]),
      );
      await db.customStatement(
        'UPDATE private_documents SET encrypted_metadata = '
        '(SELECT encrypted_metadata FROM private_documents WHERE id = ?) WHERE id = ?',
        [one.id, two.id],
      );
      await expectLater(store.listDocuments(), throwsFormatException);
    },
  );

  test(
    'deleting Principal clears documents and cannot remove default profile',
    () async {
      final doc = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        pdf: await input('principal.pdf', [37, 80, 68, 70]),
      );
      await store.saveDriver(id: 'principal', displayName: 'Private name');
      await store.deleteDriver('principal');
      expect((await store.listDrivers()).single.displayName, 'Principal');
      expect(await store.listDocuments(), isEmpty);
      await expectLater(
        store.readDocumentBytes(doc, WalletDocumentSide.pdf),
        throwsStateError,
      );
      final files = await Directory('${root.path}/wallet_documents')
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(files, isEmpty);
    },
  );

  test('repeated reads do not purge an active ephemeral PDF', () async {
    final saved = await store.saveDocument(
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.driverLicense,
      pdf: await input('view.pdf', [37, 80, 68, 70]),
    );
    final file = await store.decryptForView(saved, WalletDocumentSide.pdf);
    await store.listDocuments();
    await store.listDrivers();
    await store.initialize();
    expect(await file.exists(), isTrue);
    await WalletStore.purgeTemporaryViewerFiles(
      cacheDirectory: () async => root,
    );
    expect(await file.exists(), isFalse);
  });

  test(
    'restart removes interrupted ciphertext while preserving committed files',
    () async {
      final saved = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        pdf: await input('kept.pdf', [37, 80, 68, 70, 1]),
      );
      final interrupted = File(
        '${root.path}/wallet_documents/docs/'
        '${'f' * 32}/front.prcf',
      );
      await interrupted.parent.create(recursive: true);
      await interrupted.writeAsBytes([1, 2, 3]);
      await createStore().initialize();
      expect(await interrupted.exists(), isFalse);
      expect(await store.readDocumentBytes(saved, WalletDocumentSide.pdf), [
        37,
        80,
        68,
        70,
        1,
      ]);
    },
  );

  test(
    'legacy migration is idempotent and leaves encrypted index/files intact',
    () async {
      await db
          .into(db.vehicles)
          .insert(
            VehiclesCompanion.insert(id: 'real-vehicle', plate: 'AAA123'),
          );
      final source = await input('legacy.pdf', [37, 80, 68, 70, 9]);
      final old = await legacy.importDocument(
        vehicleId: 'real-vehicle',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: 'application/pdf',
      );
      final index = File('${root.path}/vehicle_documents/index_v1.prcf');
      final before = await index.readAsBytes();
      await store.initialize();
      await store.initialize();
      final migrated = (await store.listDocuments()).single;
      expect(migrated.id, old.documentId);
      expect(migrated.owner.vehicleId, 'real-vehicle');
      expect(migrated.pdf?.legacyMetadata?.documentId, old.documentId);
      expect(await index.readAsBytes(), before);
      expect(
        await (await store.decryptForView(
          migrated,
          WalletDocumentSide.pdf,
        )).readAsBytes(),
        [37, 80, 68, 70, 9],
      );
      expect(await legacy.listForVehicle('real-vehicle'), hasLength(1));
    },
  );

  test(
    'deleting migrated document does not resurrect on initialization',
    () async {
      await db
          .into(db.vehicles)
          .insert(
            VehiclesCompanion.insert(id: 'real-vehicle', plate: 'AAA123'),
          );
      final source = await input('legacy.pdf', [37, 80, 68, 70]);
      await legacy.importDocument(
        vehicleId: 'real-vehicle',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: 'application/pdf',
      );
      await store.initialize();
      await store.deleteDocument((await store.listDocuments()).single.id);
      expect(await legacy.listAllForMigration(), isEmpty);
      final oldFiles = await Directory('${root.path}/vehicle_documents/docs')
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(oldFiles, isEmpty);
      store = createStore();
      await store.initialize();
      expect(await store.listDocuments(), isEmpty);
    },
  );

  test(
    'corrupt legacy index fails visibly without replacing original bytes',
    () async {
      await db
          .into(db.vehicles)
          .insert(
            VehiclesCompanion.insert(id: 'real-vehicle', plate: 'AAA123'),
          );
      final index = File('${root.path}/vehicle_documents/index_v1.prcf');
      await index.parent.create(recursive: true);
      await index.writeAsBytes([1, 2, 3]);
      await expectLater(store.initialize(), throwsFormatException);
      expect(store.migrationReport.migrationFailed, isTrue);
      expect(store.migrationReport.needsRecovery, isTrue);
      expect(await index.readAsBytes(), [1, 2, 3]);
      expect(
        await db.customSelect('SELECT * FROM private_documents').get(),
        isEmpty,
      );
    },
  );

  test(
    'orphaned legacy records are retained encrypted and reported on restart',
    () async {
      final source = await input('orphan.pdf', [37, 80, 68, 70]);
      await legacy.importDocument(
        vehicleId: 'orphan-sensitive-owner',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: 'application/pdf',
      );
      final report = await store.initialize();
      expect(report.orphanedCount, 1);
      expect(store.migrationReport.orphanedCount, 1);
      expect(store.migrationReport.needsRecovery, isTrue);
      expect(report.importedCount, 0);
      expect(await db.select(db.vehicles).get(), isEmpty);
      expect(await store.listDocuments(), isEmpty);
      expect(await legacy.listAllForMigration(), hasLength(1));
      expect((await createStore().initialize()).orphanedCount, 1);
      final rows = await db
          .customSelect('SELECT * FROM wallet_migrations')
          .get();
      expect(rows.toString(), isNot(contains('orphan-sensitive-owner')));
    },
  );

  test(
    'replacement removes only requested legacy copy and preserves orphan',
    () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'real', plate: 'AAA123'));
      final original = await input('old.pdf', [37, 80, 68, 70, 1]);
      final old = await legacy.importDocument(
        vehicleId: 'real',
        documentType: PrivateVehicleDocumentType.soat,
        source: original.source,
        originalName: original.originalName,
        mimeType: original.mimeType,
      );
      final orphan = await legacy.importDocument(
        vehicleId: 'orphan',
        documentType: PrivateVehicleDocumentType.soat,
        source: original.source,
        originalName: original.originalName,
        mimeType: original.mimeType,
      );
      await store.initialize();
      final replacement = await store.saveDocument(
        owner: const WalletOwner.vehicle('real'),
        type: WalletDocumentType.soat,
        pdf: await input('new.pdf', [37, 80, 68, 70, 2]),
      );
      expect(
        await File(
          '${root.path}/vehicle_documents/${old.encryptedRelativePath}',
        ).exists(),
        isFalse,
      );
      expect(
        await File(
          '${root.path}/vehicle_documents/${orphan.encryptedRelativePath}',
        ).exists(),
        isTrue,
      );
      expect(
        (await legacy.listAllForMigration()).single.documentId,
        orphan.documentId,
      );
      expect(
        await store.readDocumentBytes(replacement, WalletDocumentSide.pdf),
        [37, 80, 68, 70, 2],
      );
      expect(store.migrationReport.orphanedCount, 1);
    },
  );

  test(
    'legacy cleanup failure persists encrypted retry record across restart',
    () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'real', plate: 'AAA123'));
      final source = await input('old.pdf', [37, 80, 68, 70]);
      final old = await legacy.importDocument(
        vehicleId: 'real',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: source.mimeType,
      );
      await store.initialize();
      final failingLegacy = _FailLegacyCleanup(root, key);
      final failing = WalletStore(
        db: db,
        legacyStore: failingLegacy,
        rootDirectory: () async => root,
        cacheDirectory: () async => root,
        masterKey: () async => key,
      );
      await failing.deleteDocument((await store.listDocuments()).single.id);
      expect(await store.listDocuments(), isEmpty);
      expect(failing.migrationReport.pendingCleanupCount, 1);
      expect(failing.migrationReport.needsRecovery, isTrue);
      final file = File(
        '${root.path}/vehicle_documents/${old.encryptedRelativePath}',
      );
      expect(await file.exists(), isTrue);
      final reopened = createStore();
      await reopened.initialize();
      expect(await file.exists(), isFalse);
      expect(await legacy.listAllForMigration(), isEmpty);
      expect(reopened.migrationReport.pendingCleanupCount, 0);
    },
  );

  test(
    'exact legacy cleanup preserves a newer index entry in the same slot',
    () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'real', plate: 'AAA123'));
      final source = await input('old.pdf', [37, 80, 68, 70]);
      final old = await legacy.importDocument(
        vehicleId: 'real',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: source.mimeType,
      );
      await store.initialize();
      final newer = await legacy.importDocument(
        vehicleId: 'real',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: source.mimeType,
      );
      await store.deleteDocument(old.documentId);
      expect(
        (await legacy.listAllForMigration()).single.documentId,
        newer.documentId,
      );
      expect(
        await File(
          '${root.path}/vehicle_documents/${newer.encryptedRelativePath}',
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'migration marker prevents importing a second mutable legacy source',
    () async {
      await store.initialize();
      await db
          .into(db.vehicles)
          .insert(
            VehiclesCompanion.insert(id: 'real-vehicle', plate: 'AAA123'),
          );
      final source = await input('late.pdf', [37, 80, 68, 70]);
      await legacy.importDocument(
        vehicleId: 'real-vehicle',
        documentType: PrivateVehicleDocumentType.soat,
        source: source.source,
        originalName: source.originalName,
        mimeType: 'application/pdf',
      );
      await createStore().initialize();
      expect(await store.listDocuments(), isEmpty);
    },
  );

  test(
    'image bytes reader creates no viewer plaintext for new documents',
    () async {
      final saved = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        front: await input('front.png', [137, 80, 78, 71, 42]),
      );
      expect(await store.readDocumentBytes(saved, WalletDocumentSide.front), [
        137,
        80,
        78,
        71,
        42,
      ]);
      final cache = Directory('${root.path}/wallet_document_viewer');
      expect(await cache.exists() ? await cache.list().toList() : [], isEmpty);
    },
  );

  test(
    'deleteForVehicle removes only the requested real vehicle documents',
    () async {
      for (final id in ['one', 'two']) {
        await db
            .into(db.vehicles)
            .insert(VehiclesCompanion.insert(id: id, plate: id));
        await store.saveDocument(
          owner: WalletOwner.vehicle(id),
          type: WalletDocumentType.soat,
          pdf: await input('$id.pdf', [37, 80, 68, 70]),
        );
      }
      await store.deleteForVehicle('one');
      final remaining = await store.listDocuments();
      expect(remaining.single.owner.vehicleId, 'two');
      expect(await db.select(db.vehicles).get(), hasLength(2));
    },
  );
}

class _FailSecondEncryption extends FileCrypto {
  var calls = 0;
  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) {
    if (++calls == 2) throw StateError('Injected encryption failure.');
    return super.encryptBytes(plaintext, key);
  }
}

class _RevokeOnEncrypt extends FileCrypto {
  _RevokeOnEncrypt(this.revoke);
  final void Function() revoke;
  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) async {
    final result = await super.encryptBytes(plaintext, key);
    revoke();
    return result;
  }
}

class _FailLegacyCleanup extends PrivateVehicleDocumentStore {
  _FailLegacyCleanup(Directory root, SecretKey key)
    : super(
        rootDirectory: () async => root,
        cacheDirectory: () async => root,
        masterKey: () async => key,
      );

  @override
  Future<void> removeMigratedReference(
    PrivateVehicleDocumentMetadata metadata,
  ) async {
    throw const FileSystemException('Injected cleanup failure');
  }
}
