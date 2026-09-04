import 'dart:async';
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

    final next = File('${root.path}/next.pdf');
    await next.writeAsBytes([9, 9, 9]);
    final nextMetadata = await failingStore.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.rtm,
      source: next,
      originalName: 'next.pdf',
      mimeType: 'application/pdf',
    );

    expect(nextMetadata.documentId, 'failed-replacement');
    expect(
      (await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
      ))?.documentId,
      nextMetadata.documentId,
    );
  });

  test(
    'serializes concurrent imports without losing encrypted index entries',
    () async {
      final first = File('${root.path}/first.pdf');
      final second = File('${root.path}/second.pdf');
      await first.writeAsBytes([1, 2, 3]);
      await second.writeAsBytes([4, 5, 6]);
      final blockingCrypto = _BlockingIndexCrypto();
      final mutatingStore = PrivateVehicleDocumentStore(
        rootDirectory: () async => root,
        cacheDirectory: () async => root,
        masterKey: () async => SecretKey(List<int>.filled(32, 9)),
        fileCrypto: blockingCrypto,
        idGenerator: () => 'concurrent-${(++ids).toString().padLeft(4, '0')}',
        now: () => DateTime.utc(2026, 8, 30, 12),
      );

      final importA = mutatingStore.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: first,
        originalName: 'first.pdf',
        mimeType: 'application/pdf',
      );
      await blockingCrypto.firstIndexWrite.future;
      final importB = mutatingStore.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
        source: second,
        originalName: 'second.pdf',
        mimeType: 'application/pdf',
      );
      await pumpEventQueue();

      blockingCrypto.releaseFirstIndexWrite();
      await blockingCrypto.secondIndexWrite.future;
      blockingCrypto.releaseSecondIndexWrite();
      final results = await Future.wait([importA, importB]);

      final documents = await mutatingStore.listForVehicle('vehicle-1');
      expect(documents.map((item) => item.documentType), [
        PrivateVehicleDocumentType.soat,
        PrivateVehicleDocumentType.rtm,
      ]);
      expect(documents.map((item) => item.documentId), [
        results[0].documentId,
        results[1].documentId,
      ]);
      expect(await _orphanedEncryptedDocuments(root, documents), isEmpty);
      expect(
        await (await mutatingStore.decryptForView(documents[0])).readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await (await mutatingStore.decryptForView(documents[1])).readAsBytes(),
        [4, 5, 6],
      );
    },
  );

  test('concurrent replace and delete preserve unrelated metadata', () async {
    final soat = File('${root.path}/soat.pdf');
    final rtm = File('${root.path}/rtm.pdf');
    final other = File('${root.path}/other.pdf');
    final replacement = File('${root.path}/replacement.pdf');
    await soat.writeAsBytes([1]);
    await rtm.writeAsBytes([2]);
    await other.writeAsBytes([3]);
    await replacement.writeAsBytes([4]);

    await store.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.soat,
      source: soat,
      originalName: 'soat.pdf',
      mimeType: 'application/pdf',
    );
    final rtmMetadata = await store.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.rtm,
      source: rtm,
      originalName: 'rtm.pdf',
      mimeType: 'application/pdf',
    );
    final otherMetadata = await store.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.other,
      source: other,
      originalName: 'other.pdf',
      mimeType: 'application/pdf',
    );

    final blockingCrypto = _BlockingIndexCrypto();
    final mutatingStore = PrivateVehicleDocumentStore(
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 9)),
      fileCrypto: blockingCrypto,
      idGenerator: () => 'replacement-soat',
      now: () => DateTime.utc(2026, 8, 30, 12, 1),
    );

    final replace = mutatingStore.replaceDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.soat,
      source: replacement,
      originalName: 'soat-new.pdf',
      mimeType: 'application/pdf',
    );
    await blockingCrypto.firstIndexWrite.future;
    final delete = mutatingStore.delete(rtmMetadata);

    blockingCrypto.releaseFirstIndexWrite();
    await blockingCrypto.secondIndexWrite.future;
    blockingCrypto.releaseSecondIndexWrite();
    await Future.wait<Object?>([replace, delete]);

    expect(
      (await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
      ))?.originalName,
      'soat-new.pdf',
    );
    expect(
      await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
      ),
      isNull,
    );
    expect(
      (await store.get(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.other,
      ))?.documentId,
      otherMetadata.documentId,
    );
    expect(
      await _orphanedEncryptedDocuments(
        root,
        await store.listForVehicle('vehicle-1'),
      ),
      isEmpty,
    );
  });

  test(
    'post-commit replacement cleanup failure does not fail logical success',
    () async {
      final key = SecretKey(List<int>.filled(32, 9));
      final index = File('${root.path}/vehicle_documents/index_v1.prcf');
      await index.parent.create(recursive: true);
      await index.writeAsBytes(
        await FileCrypto().encryptBytes(
          utf8.encode(
            jsonEncode([
              {
                'documentId': 'legacy-soat',
                'vehicleId': 'vehicle-1',
                'documentType': 'soat',
                'originalName': 'legacy.pdf',
                'mimeType': 'application/pdf',
                'importedAt': '2026-08-30T12:00:00.000Z',
                'encryptedRelativePath': '../unsafe.prcf',
              },
            ]),
          ),
          key,
        ),
      );
      final replacement = File('${root.path}/replacement.pdf');
      await replacement.writeAsBytes([7, 7, 7]);

      final metadata = await store.replaceDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: replacement,
        originalName: 'replacement.pdf',
        mimeType: 'application/pdf',
      );

      expect(metadata.originalName, 'replacement.pdf');
      expect(
        (await store.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.soat,
        ))?.documentId,
        metadata.documentId,
      );
      expect(await _orphanedEncryptedDocuments(root, [metadata]), isEmpty);
    },
  );

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

class _BlockingIndexCrypto extends FileCrypto {
  final firstIndexWrite = Completer<void>();
  final secondIndexWrite = Completer<void>();
  final _releaseFirst = Completer<void>();
  final _releaseSecond = Completer<void>();
  var indexWrites = 0;

  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) async {
    if (_isIndexPayload(plaintext)) {
      indexWrites += 1;
      if (indexWrites == 1) {
        firstIndexWrite.complete();
        await _releaseFirst.future;
      } else if (indexWrites == 2) {
        secondIndexWrite.complete();
        await _releaseSecond.future;
      }
    }
    return super.encryptBytes(plaintext, key);
  }

  void releaseFirstIndexWrite() {
    if (!_releaseFirst.isCompleted) {
      _releaseFirst.complete();
    }
  }

  void releaseSecondIndexWrite() {
    if (!_releaseSecond.isCompleted) {
      _releaseSecond.complete();
    }
  }

  bool _isIndexPayload(List<int> plaintext) {
    try {
      return jsonDecode(utf8.decode(plaintext)) is List;
    } catch (_) {
      return false;
    }
  }
}

Future<List<File>> _orphanedEncryptedDocuments(
  Directory root,
  List<PrivateVehicleDocumentMetadata> metadata,
) async {
  final storeRoot = Directory('${root.path}/vehicle_documents');
  final docsRoot = Directory('${storeRoot.path}/docs');
  if (!await docsRoot.exists()) {
    return const [];
  }
  final referenced = {
    for (final item in metadata)
      _normalizedPath(
        File('${storeRoot.path}/${item.encryptedRelativePath}').absolute.path,
      ),
  };
  return [
    await for (final entity in docsRoot.list(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.prcf') &&
          !referenced.contains(_normalizedPath(entity.absolute.path)))
        entity,
  ];
}

String _normalizedPath(String path) => path.replaceAll('\\', '/');
