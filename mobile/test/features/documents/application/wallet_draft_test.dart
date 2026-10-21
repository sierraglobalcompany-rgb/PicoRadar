import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_draft.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';

class _PartialWriteFile extends Fake implements File {
  _PartialWriteFile(this.real);
  final File real;
  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await real.writeAsBytes(bytes.take(3).toList(), flush: true);
    throw const FileSystemException('Simulated full storage');
  }

  @override
  Future<bool> exists() => real.exists();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      real.delete(recursive: recursive);
}

void main() {
  late Directory root;
  final key = SecretKey(List.filled(32, 11));
  setUp(() => root = Directory.systemTemp.createTempSync('wallet-draft-test-'));
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'failed materialization removes partial plaintext and wipes buffer',
    () async {
      final file = File('${root.path}/partial.pdf');
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      await expectLater(
        writeWalletPlaintext(_PartialWriteFile(file), bytes),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.exists(), isFalse);
      expect(bytes, everyElement(0));
    },
  );

  test(
    'stages ciphertext, detects actual MIME and never deletes source',
    () async {
      final bytes = [0xff, 0xd8, 0xff, 0xe0, ...List.filled(64, 23)];
      final original = File('${root.path}/user-original.pdf');
      await original.writeAsBytes(bytes);
      final draft = await WalletDraft.stage(
        [
          WalletDocumentInput(
            source: original,
            originalName: 'wrong-extension.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        key: key,
        cacheRoot: root,
      );
      expect(draft.files.single.mimeType, 'image/jpeg');
      expect(await draft.files.single.encrypted.readAsBytes(), isNot(bytes));
      expect(await draft.read(0), bytes);
      final temporary = await draft.materialize(0);
      expect(await temporary.readAsBytes(), bytes);
      await draft.dispose();
      expect(await temporary.exists(), isFalse);
      expect(await original.readAsBytes(), bytes);
    },
  );

  test(
    'partial failure removes pending ciphertext but preserves originals',
    () async {
      final good = File('${root.path}/good.jpg')
        ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 1]);
      final bad = File('${root.path}/bad.jpg')
        ..writeAsStringSync('not a document');
      await expectLater(
        WalletDraft.stage(
          [
            WalletDocumentInput(
              source: good,
              originalName: 'good.jpg',
              mimeType: 'image/jpeg',
            ),
            WalletDocumentInput(
              source: bad,
              originalName: 'bad.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
          key: key,
          cacheRoot: root,
        ),
        throwsFormatException,
      );
      expect(Directory('${root.path}/wallet_pending').listSync(), isEmpty);
      expect(good.existsSync() && bad.existsSync(), isTrue);
    },
  );

  test('restart cleanup removes only app-owned pending directory', () async {
    final original = File('${root.path}/original.png')
      ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 1]);
    await WalletDraft.stage(
      [
        WalletDocumentInput(
          source: original,
          originalName: 'original.png',
          mimeType: 'image/png',
        ),
      ],
      key: key,
      cacheRoot: root,
    );
    await WalletDraft.purgeAbandoned(cacheRoot: root);
    expect(Directory('${root.path}/wallet_pending').existsSync(), isFalse);
    expect(original.existsSync(), isTrue);
  });
}
