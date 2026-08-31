import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';

void main() {
  late Directory root;
  late PrivateVehicleDocumentStore store;
  var ids = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picoradar-doc-store-test-');
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
    },
  );

  test(
    'replaces and deletes image documents without keeping old ciphertext',
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

      final replacement = await store.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.rtm,
        source: second,
        originalName: 'certificado.webp',
        mimeType: 'image/webp',
      );

      expect(await originalEncrypted.exists(), isFalse);
      expect(replacement.originalName, 'certificado.webp');
      expect(
        (await store.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.rtm,
        ))?.documentId,
        replacement.documentId,
      );

      await store.delete(replacement);
      expect(
        await store.get(
          vehicleId: 'vehicle-1',
          documentType: PrivateVehicleDocumentType.rtm,
        ),
        isNull,
      );
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
}
