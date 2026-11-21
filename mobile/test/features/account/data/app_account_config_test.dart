import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/account/data/app_account_config.dart';

void main() {
  test(
    'accounts are unavailable until app, email, and API flags are present',
    () {
      expect(const AppAccountConfig.disabled().isAvailable, isFalse);
      expect(
        const AppAccountConfig(
          enabled: true,
          emailEnabled: false,
          apiBaseUrl: 'https://api.example.test',
          privacyUrl: 'https://example.test/privacy',
          privacyVersion: 'v1',
        ).isAvailable,
        isFalse,
      );
    },
  );

  test(
    'remote account API requires HTTPS and rejects URL credentials and query',
    () {
      AppAccountConfig config(String api) => AppAccountConfig(
        enabled: true,
        emailEnabled: true,
        apiBaseUrl: api,
        privacyUrl: 'https://example.test/privacy',
        privacyVersion: 'v1',
      );

      expect(config('https://api.example.test').isAvailable, isTrue);
      expect(config('http://api.example.test').isAvailable, isFalse);
      expect(config('https://user:pass@api.example.test').isAvailable, isFalse);
      expect(
        config('https://api.example.test?redirect=elsewhere').isAvailable,
        isFalse,
      );
    },
  );

  test('privacy policy is separately required for new account consent', () {
    const config = AppAccountConfig(
      enabled: true,
      emailEnabled: true,
      apiBaseUrl: 'https://api.example.test',
      privacyUrl: '',
      privacyVersion: '',
    );
    expect(config.isAvailable, isTrue);
    expect(config.privacyConfigured, isFalse);
  });
}
