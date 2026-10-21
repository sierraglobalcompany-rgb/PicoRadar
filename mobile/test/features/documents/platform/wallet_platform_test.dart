import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('co.picoradar.app/wallet');
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final code in [
    'protected_pdf',
    'invalid_session',
    'pdf_unavailable',
    'closed',
  ]) {
    test('preserves existing native viewer failure category $code', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: code),
          );
      await expectLater(
        const WalletPlatform().openPdf('/private.pdf'),
        throwsA(
          isA<WalletPlatformException>().having((e) => e.code, 'code', code),
        ),
      );
    });
  }
  for (final code in [
    'scanner_start_failed',
    'scanner_services_update',
    '/private/secret.jpg',
  ]) {
    test('scan exposes only finite diagnostics: $code', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: code,
              message: 'private content',
              details: '/private/path',
            );
          });
      await expectLater(
        const WalletPlatform().scan(),
        throwsA(
          isA<WalletPlatformException>().having(
            (e) => e.code,
            'code',
            code.startsWith('scanner_') ? code : 'platform_failed',
          ),
        ),
      );
    });
  }
}
