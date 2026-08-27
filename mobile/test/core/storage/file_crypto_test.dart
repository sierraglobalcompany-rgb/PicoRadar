import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/file_crypto.dart';

void main() {
  group('FileCrypto', () {
    late FileCrypto crypto;
    late SecretKey key;

    setUp(() async {
      crypto = FileCrypto();
      key = await crypto.newFileKey();
    });

    test('encrypt decrypt returns the original bytes', () async {
      final plaintext = <int>[0, 1, 2, 3, 253, 254, 255];

      final encrypted = await crypto.encryptBytes(plaintext, key);
      final decrypted = await crypto.decryptBytes(encrypted, key);

      expect(decrypted, plaintext);
    });

    test(
      'encrypting the same bytes twice produces different envelopes',
      () async {
        final plaintext = 'same content'.codeUnits;

        final first = await crypto.encryptBytes(plaintext, key);
        final second = await crypto.encryptBytes(plaintext, key);

        expect(first, isNot(second));
        expect(await crypto.decryptBytes(first, key), plaintext);
        expect(await crypto.decryptBytes(second, key), plaintext);
      },
    );

    test('tampered ciphertext fails closed', () async {
      final encrypted = await crypto.encryptBytes('secret'.codeUnits, key);
      encrypted[encrypted.length - 1] ^= 0x01;

      expect(() => crypto.decryptBytes(encrypted, key), throwsA(anything));
    });

    test('tampered MAC fails closed', () async {
      final encrypted = await crypto.encryptBytes('secret'.codeUnits, key);
      final macStart = 7 + encrypted[5];
      encrypted[macStart] ^= 0x01;

      expect(() => crypto.decryptBytes(encrypted, key), throwsA(anything));
    });

    test('wrong key fails closed', () async {
      final encrypted = await crypto.encryptBytes('secret'.codeUnits, key);
      final wrongKey = await crypto.newFileKey();

      expect(() => crypto.decryptBytes(encrypted, wrongKey), throwsA(anything));
    });

    test('invalid or unknown envelopes fail closed', () async {
      expect(
        () => crypto.decryptBytes(<int>[1, 2, 3], key),
        throwsFormatException,
      );

      final encrypted = await crypto.encryptBytes('secret'.codeUnits, key);
      encrypted[4] = 99;

      expect(() => crypto.decryptBytes(encrypted, key), throwsFormatException);
    });

    test('encryptFile and decryptFile work with dart:io files', () async {
      final directory = await Directory.systemTemp.createTemp(
        'picoradar_crypto_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/plain.bin');
      final encrypted = File('${directory.path}/private/document.prcf');
      final decrypted = File('${directory.path}/plain.copy.bin');
      final plaintext = <int>[10, 20, 30, 40, 50];
      await source.writeAsBytes(plaintext);

      await crypto.encryptFile(
        source: source,
        destination: encrypted,
        key: key,
      );
      await crypto.decryptFile(
        source: encrypted,
        destination: decrypted,
        key: key,
      );

      expect(await decrypted.readAsBytes(), plaintext);
    });

    test(
      'deleteSourceOnSuccess deletes only after a successful write',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'picoradar_crypto_delete_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final failedSource = File('${directory.path}/failed-source.bin');
        final blockedParent = File('${directory.path}/blocked-parent');
        await failedSource.writeAsBytes(<int>[1, 2, 3]);
        await blockedParent.writeAsString('not a directory');

        await expectLater(
          crypto.encryptFile(
            source: failedSource,
            destination: File('${blockedParent.path}/encrypted.bin'),
            key: key,
            deleteSourceOnSuccess: true,
          ),
          throwsA(anything),
        );
        expect(await failedSource.exists(), isTrue);

        final successfulSource = File(
          '${directory.path}/successful-source.bin',
        );
        final destination = File('${directory.path}/encrypted.bin');
        await successfulSource.writeAsBytes(<int>[4, 5, 6]);

        await crypto.encryptFile(
          source: successfulSource,
          destination: destination,
          key: key,
          deleteSourceOnSuccess: true,
        );

        expect(await successfulSource.exists(), isFalse);
        expect(await destination.exists(), isTrue);
      },
    );
  });
}
