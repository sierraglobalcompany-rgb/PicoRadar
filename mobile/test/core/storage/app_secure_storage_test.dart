import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_secure_storage.dart';

void main() {
  group('AppSecureStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('memoizes concurrent file master key creation in process', () async {
      final keys = await Future.wait(
        List<Future<SecretKey>>.generate(
          50,
          (_) => AppSecureStorage().getOrCreateFileMasterKey(),
        ),
      );

      final keyBytes = await Future.wait(keys.map((key) => key.extractBytes()));
      final encoded = await AppSecureStorage().readSecret(
        AppSecureStorage.fileMasterKeyStorageKey,
      );

      expect(encoded, isNotNull);
      expect(base64Decode(encoded!), keyBytes.first);
      expect(keyBytes.map(base64Encode).toSet(), hasLength(1));
      expect(keyBytes.first.length, 32);
    });
  });
}
