import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class FileCrypto {
  FileCrypto({AesGcm? cipher}) : _cipher = cipher ?? AesGcm.with256bits();

  static const envelopeVersion = 1;
  static const _magic = <int>[0x50, 0x52, 0x43, 0x46]; // PRCF
  static const _versionOffset = 4;
  static const _nonceLengthOffset = 5;
  static const _macLengthOffset = 6;
  static const _payloadOffset = 7;
  static const _macLength = 16;

  final AesGcm _cipher;

  Future<SecretKey> newFileKey() => _cipher.newSecretKey();

  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(plaintext, secretKey: key, nonce: nonce);

    return Uint8List.fromList(<int>[
      ..._magic,
      envelopeVersion,
      nonce.length,
      box.mac.bytes.length,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  Future<Uint8List> decryptBytes(List<int> envelope, SecretKey key) async {
    final parsed = _parseEnvelope(envelope);
    final plaintext = await _cipher.decrypt(
      SecretBox(parsed.cipherText, nonce: parsed.nonce, mac: Mac(parsed.mac)),
      secretKey: key,
    );
    return Uint8List.fromList(plaintext);
  }

  Future<void> encryptFile({
    required File source,
    required File destination,
    required SecretKey key,
    bool deleteSourceOnSuccess = false,
  }) async {
    _ensureDifferentPaths(source, destination);
    final plaintext = await source.readAsBytes();
    final encrypted = await encryptBytes(plaintext, key);
    await _writeAtomically(destination, encrypted);
    if (deleteSourceOnSuccess) {
      await source.delete();
    }
  }

  Future<void> decryptFile({
    required File source,
    required File destination,
    required SecretKey key,
    bool deleteSourceOnSuccess = false,
  }) async {
    _ensureDifferentPaths(source, destination);
    final envelope = await source.readAsBytes();
    final plaintext = await decryptBytes(envelope, key);
    await _writeAtomically(destination, plaintext);
    if (deleteSourceOnSuccess) {
      await source.delete();
    }
  }

  _EncryptedEnvelope _parseEnvelope(List<int> bytes) {
    if (bytes.length < _payloadOffset) {
      throw const FormatException('Encrypted file envelope is too short.');
    }
    for (var i = 0; i < _magic.length; i += 1) {
      if (bytes[i] != _magic[i]) {
        throw const FormatException(
          'Encrypted file envelope magic is invalid.',
        );
      }
    }
    if (bytes[_versionOffset] != envelopeVersion) {
      throw const FormatException(
        'Encrypted file envelope version is unsupported.',
      );
    }

    final nonceLength = bytes[_nonceLengthOffset];
    final macLength = bytes[_macLengthOffset];
    if (nonceLength != _cipher.nonceLength || macLength != _macLength) {
      throw const FormatException(
        'Encrypted file envelope lengths are invalid.',
      );
    }

    final nonceStart = _payloadOffset;
    final macStart = nonceStart + nonceLength;
    final cipherTextStart = macStart + macLength;
    if (bytes.length < cipherTextStart) {
      throw const FormatException(
        'Encrypted file envelope payload is invalid.',
      );
    }

    return _EncryptedEnvelope(
      nonce: bytes.sublist(nonceStart, macStart),
      mac: bytes.sublist(macStart, cipherTextStart),
      cipherText: bytes.sublist(cipherTextStart),
    );
  }

  void _ensureDifferentPaths(File source, File destination) {
    if (source.absolute.path == destination.absolute.path) {
      throw ArgumentError('Source and destination must be different files.');
    }
  }

  Future<void> _writeAtomically(File destination, List<int> bytes) async {
    await destination.parent.create(recursive: true);
    final temp = File(
      '${destination.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      await temp.writeAsBytes(bytes, flush: true);
      if (await destination.exists()) {
        await destination.delete();
      }
      await temp.rename(destination.path);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }
}

class _EncryptedEnvelope {
  const _EncryptedEnvelope({
    required this.nonce,
    required this.mac,
    required this.cipherText,
  });

  final List<int> nonce;
  final List<int> mac;
  final List<int> cipherText;
}
