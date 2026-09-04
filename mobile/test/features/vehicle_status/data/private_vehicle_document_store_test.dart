import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/file_crypto.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';

void main() {
  late Directory root;
  late PrivateVehicleDocumentStore store;
  var ids = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picoradar-doc-store-test-');
    ids = 0;
    store = PrivateVehicleDocumentStore(
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 9)),
      idGenerator: () => 'doc-${(++ids).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 8, 30, 12),
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'imports PDF into encrypted app-owned storage and decrypts for view',
    () async {
      final source = File('${root.path}/source.pdf');
      await source.writeAsBytes([0x25, 0x50, 0x44, 0x46]);

      final metadata = await store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'poliza.pdf',
        mimeType: 'application/pdf',
      );

      final saved = await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
      );
      expect(saved?.documentId, metadata.documentId);
      expect(saved?.originalName, 'poliza.pdf');
      expect(saved?.mimeType, 'application/pdf');

      final encrypted = File(
        '${root.path}/vehicle_documents/${metadata.encryptedRelativePath}',
      );
      expect(await encrypted.exists(), isTrue);
      expect(await encrypted.readAsBytes(), isNot([0x25, 0x50, 0x44, 0x46]));

      final viewFile = await store.decryptForView(metadata);
      expect(await viewFile.readAsBytes(), [0x25, 0x50, 0x44, 0x46]);
      expect(await viewFile.exists(), isTrue);

      await store.purgeViewerCache();
      expect(await viewFile.exists(), isFalse);
    },
  );

  test('reads existing index v1 metadata for SOAT and RTM', () async {
    final key = SecretKey(List<int>.filled(32, 9));
    final legacyIndex = File('${root.path}/vehicle_documents/index_v1.prcf');
    await legacyIndex.parent.create(recursive: true);
    await legacyIndex.writeAsBytes(
      await FileCrypto().encryptBytes(
        utf8.encode(
          jsonEncode([
            {
              'documentId': 'legacy-soat',
              'vehicleId': 'vehicle-1',
              'documentType': 'soat',
              'originalName': 'soat.pdf',
              'mimeType': 'application/pdf',
              'importedAt': '2026-08-30T12:00:00.000Z',
              'encryptedRelativePath': 'docs/soat/vehicle-1/legacy-soat.prcf',
            },
            {
              'documentId': 'legacy-rtm',
              'vehicleId': 'vehicle-1',
              'documentType': 'rtm',
              'originalName': 'rtm.pdf',
              'mimeType': 'application/pdf',
              'importedAt': '2026-08-30T12:00:00.000Z',
              'encryptedRelativePath': 'docs/rtm/vehicle-1/legacy-rtm.prcf',
            },
          ]),
        ),
        key,
      ),
    );

    final documents = await store.listForVehicle('vehicle-1');

    expect(documents.map((item) => item.documentType), [
      PrivateVehicleDocumentType.soat,
      PrivateVehicleDocumentType.rtm,
    ]);
    expect(documents.map((item) => item.documentId), [
      'legacy-soat',
      'legacy-rtm',
    ]);
  });

  test(
    'round-trips every vehicle document type with encrypted bytes',
    () async {
      for (final type in PrivateVehicleDocumentType.values) {
        final source = File('${root.path}/${type.value}.pdf');
        final bytes = [type.index + 1, type.index + 2, type.index + 3];
        await source.writeAsBytes(bytes);

        final metadata = await store.importDocument(
          vehicleId: 'vehicle-${type.index}',
          documentType: type,
          source: source,
          originalName: '${type.value}.pdf',
          mimeType: '',
        );

        final encrypted = File(
          '${root.path}/vehicle_documents/${metadata.encryptedRelativePath}',
        );
        expect(await encrypted.exists(), isTrue);
        expect(await encrypted.readAsBytes(), isNot(bytes));
        expect(
          await (await store.decryptForView(metadata)).readAsBytes(),
          bytes,
        );
        expect(
          (await store.listForVehicle('vehicle-${type.index}'))
              .single
              .documentType,
          type,
        );
      }
    },
  );

  test(
    'replaces and deletes image documents without keeping old files',
    () async {
      final first = File('${root.path}/first.png');
      final second = File('${root.path}/second.webp');
      await first.writeAsBytes([1, 2, 3]);
      await second.writeAsBytes([4, 5, 6]);

      final original = await store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
        source: first,
        originalName: 'certificado.png',
        mimeType: 'image/png',
      );
      final originalEncrypted = File(
        '${root.path}/vehicle_documents/${original.encryptedRelativePath}',
      );
      final originalViewFile = await store.decryptForView(original);
      expect(await originalViewFile.exists(), isTrue);

      final replacement = await store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
        source: second,
        originalName: 'certificado.webp',
        mimeType: 'image/webp',
      );

      expect(await originalEncrypted.exists(), isFalse);
      expect(await originalViewFile.exists(), isFalse);
      expect(replacement.originalName, 'certificado.webp');
      expect(
        (await store.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.rtm,
        ))?.documentId,
        replacement.documentId,
      );

      final replacementViewFile = await store.decryptForView(replacement);
      expect(await replacementViewFile.exists(), isTrue);

      await store.delete(replacement);
      expect(await replacementViewFile.exists(), isFalse);
      expect(
        await store.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.rtm,
        ),
        isNull,
      );
    },
  );

  test('rolls back failed replacement index writes without deleting previous copy', () async {
    final first = File('${root.path}/first.pdf');
    final second = File('${root.path}/second.pdf');
    await first.writeAsBytes([1, 2, 3]);
    await second.writeAsBytes([4, 5, 6]);

    final original = await store.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.soat,
      source: first,
      originalName: 'first.pdf',
      mimeType: 'application/pdf',
    );
    final originalEncrypted = File(
      '${root.path}/vehicle_documents/${original.encryptedRelativePath}',
    );
    final failingStore = PrivateVehicleDocumentStore(
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 9)),
      fileCrypto: _FailingIndexCrypto(),
      idGenerator: () => 'failed-replacement',
      now: () => DateTime.utc(2026, 8, 30, 12, 1),
    );

    await expectLater(
      failingStore.replaceDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: second,
        originalName: 'second.pdf',
        mimeType: 'application/pdf',
      ),
      throwsStateError,
    );

    expect(await originalEncrypted.exists(), isTrue);
    expect(
      (await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
      ))?.documentId,
      original.documentId,
    );
    expect(
      await File(
        '${root.path}/vehicle_documents/docs/soat/vehicle-1/failed-replacement.prcf',
      ).exists(),
      isFalse,
    );
  });

  test('purges index temp file when index rename fails', () async {
    final blockedIndex = Directory(
      '${root.path}/vehicle_documents/index_v1.prcf',
    );
    await blockedIndex.create(recursive: true);
    final source = File('${root.path}/source.pdf');
    await source.writeAsBytes([1, 2, 3]);

    await expectLater(
      store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.other,
        source: source,
        originalName: 'source.pdf',
        mimeType: 'application/pdf',
      ),
      throwsA(isA<FileSystemException>()),
    );

    final storeRoot = Directory('${root.path}/vehicle_documents');
    final leftovers = storeRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.contains('.tmp.'))
        .toList();
    expect(leftovers, isEmpty);
    expect(
      await File(
        '${root.path}/vehicle_documents/docs/other/vehicle-1/doc-0001.prcf',
      ).exists(),
      isFalse,
    );
  });

  test(
    'malformed encrypted index fails visibly instead of disappearing',
    () async {
      final key = SecretKey(List<int>.filled(32, 9));
      final index = File('${root.path}/vehicle_documents/index_v1.prcf');
      await index.parent.create(recursive: true);
      await index.writeAsBytes(
        await FileCrypto().encryptBytes(
          utf8.encode(jsonEncode({'bad': true})),
          key,
        ),
      );

      await expectLater(
        store.listForVehicle('vehicle-1'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'rejects unsafe encrypted paths before creating plaintext viewer files',
    () async {
      final metadata = PrivateVehicleDocumentMetadata(
        documentId: 'unsafe-view',
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.other,
        originalName: '../unsafe.pdf',
        mimeType: 'application/pdf',
        importedAt: DateTime.utc(2026, 8, 30, 12),
        encryptedRelativePath: '../outside.prcf',
      );

      await expectLater(
        store.decryptForView(metadata),
        throwsA(isA<FormatException>()),
      );
      expect(
        await File(
          '${root.path}/vehicle_document_viewer/unsafe-view/unsafe.pdf',
        ).exists(),
        isFalse,
      );
    },
  );

  test(
    'sanitizes vehicle id path segment without changing stored metadata',
    () async {
      final source = File('${root.path}/source.pdf');
      await source.writeAsBytes([1, 2, 3]);

      final metadata = await store.importDocument(
        vehicleId: '../vehicle-1',
        documentType: PrivateVehicleDocumentType.other,
        source: source,
        originalName: 'source.pdf',
        mimeType: 'application/pdf',
      );

      expect(metadata.vehicleId, '../vehicle-1');
      expect(metadata.encryptedRelativePath, contains('.._vehicle-1'));
      expect(metadata.encryptedRelativePath, isNot(contains('../vehicle-1')));
      expect(
        await File(
          '${root.path}/vehicle_documents/${metadata.encryptedRelativePath}',
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'new store instance reads encrypted metadata and purges stale viewer cache',
    () async {
      final source = File('${root.path}/source.jpg');
      await source.writeAsBytes([7, 8, 9]);

      final metadata = await store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'poliza.jpg',
        mimeType: 'image/jpeg',
      );
      final viewFile = await store.decryptForView(metadata);

      final restartedStore = PrivateVehicleDocumentStore(
        rootDirectory: () async => root,
        cacheDirectory: () async => root,
        masterKey: () async => SecretKey(List<int>.filled(32, 9)),
        idGenerator: () => 'unused',
      );

      expect(
        (await restartedStore.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.soat,
        ))?.documentId,
        metadata.documentId,
      );
      expect(await viewFile.exists(), isTrue);

      await restartedStore.purgeViewerCache();
      expect(await viewFile.exists(), isFalse);
    },
  );

  test('rejects unsupported document extensions', () async {
    final source = File('${root.path}/source.txt');
    await source.writeAsString('plain text');

    expect(
      () => store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'source.txt',
        mimeType: 'text/plain',
      ),
      throwsArgumentError,
    );
  });

  test('rejects documents over the local import limit', () async {
    final source = File('${root.path}/large.pdf');
    final handle = await source.open(mode: FileMode.write);
    await handle.truncate(PrivateVehicleDocumentStore.maxImportBytes + 1);
    await handle.close();

    await expectLater(
      store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'large.pdf',
        mimeType: 'application/pdf',
      ),
      throwsArgumentError,
    );
  });
}

class _FailingIndexCrypto extends FileCrypto {
  var encryptCalls = 0;

  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) {
    encryptCalls += 1;
    if (encryptCalls == 2) {
      throw StateError('index write failed');
    }
    return super.encryptBytes(plaintext, key);
  }
}
