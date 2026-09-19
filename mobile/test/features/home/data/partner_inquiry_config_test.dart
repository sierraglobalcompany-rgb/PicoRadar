import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/data/partner_inquiry_config.dart';

void main() {
  test(
    'production gate requires HTTPS privacy and admin review configuration',
    () {
      const ready = PartnerInquiryConfig(
        enabled: true,
        apiBaseUrl: 'https://api.picoradar.test',
        privacyVersion: '2026-09-19',
        privacyUrl: 'https://picoradar.test/privacidad/aliados',
        adminReviewConfigured: true,
      );

      expect(ready.isAvailable, isTrue);
      expect(ready.apiBaseUri?.scheme, 'https');
    },
  );

  test(
    'gate fails closed for HTTP missing privacy or missing admin review',
    () {
      const base = PartnerInquiryConfig(
        enabled: true,
        apiBaseUrl: 'http://api.picoradar.test',
        privacyVersion: '2026-09-19',
        privacyUrl: 'https://picoradar.test/privacidad/aliados',
        adminReviewConfigured: true,
      );
      const missingPrivacy = PartnerInquiryConfig(
        enabled: true,
        apiBaseUrl: 'https://api.picoradar.test',
        privacyVersion: '',
        privacyUrl: '',
        adminReviewConfigured: true,
      );
      const missingAdmin = PartnerInquiryConfig(
        enabled: true,
        apiBaseUrl: 'https://api.picoradar.test',
        privacyVersion: '2026-09-19',
        privacyUrl: 'https://picoradar.test/privacidad/aliados',
        adminReviewConfigured: false,
      );

      expect(base.isAvailable, isFalse);
      expect(missingPrivacy.isAvailable, isFalse);
      expect(missingAdmin.isAvailable, isFalse);
    },
  );

  test('explicit dev-test override accepts localhost only', () {
    const dev = PartnerInquiryConfig(
      enabled: true,
      apiBaseUrl: 'http://127.0.0.1:8000',
      privacyVersion: 'dev-test-v1',
      privacyUrl: 'https://example.test/dev-privacy',
      adminReviewConfigured: true,
      allowInsecureDev: true,
    );
    const remoteHttp = PartnerInquiryConfig(
      enabled: true,
      apiBaseUrl: 'http://example.test',
      privacyVersion: 'dev-test-v1',
      privacyUrl: 'https://example.test/dev-privacy',
      adminReviewConfigured: true,
      allowInsecureDev: true,
    );

    expect(dev.isAvailable, isTrue);
    expect(remoteHttp.isAvailable, isFalse);
  });
}
