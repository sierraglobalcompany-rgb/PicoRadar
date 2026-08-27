import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSecureStorage {
  AppSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const fileMasterKeyStorageKey = 'file_master_key_v1';
  static const _fileMasterKeyLength = 32;

  final FlutterSecureStorage _storage;

  Future<String?> readSecret(String key) => _storage.read(key: key);

  Future<void> writeSecret(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> deleteSecret(String key) => _storage.delete(key: key);

  Future<SecretKey> getOrCreateFileMasterKey({
    String key = fileMasterKeyStorageKey,
  }) async {
    final encoded = await _storage.read(key: key);
    if (encoded != null) {
      final bytes = base64Decode(encoded);
      if (bytes.length != _fileMasterKeyLength) {
        throw StateError('Stored file master key has invalid length.');
      }
      return SecretKey(bytes);
    }

    final secretKey = SecretKeyData.random(length: _fileMasterKeyLength);
    final bytes = await secretKey.extractBytes();
    await _storage.write(key: key, value: base64Encode(bytes));
    return SecretKey(bytes);
  }
}
