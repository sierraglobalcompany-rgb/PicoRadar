import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final partnerInquiryConfigProvider = Provider<PartnerInquiryConfig>((ref) {
  return PartnerInquiryConfig.fromEnvironment();
});

class PartnerInquiryConfig {
  const PartnerInquiryConfig({
    required this.enabled,
    required this.apiBaseUrl,
    required this.privacyVersion,
    required this.privacyUrl,
    required this.adminReviewConfigured,
    this.allowInsecureDev = false,
  });

  const PartnerInquiryConfig.disabled()
    : enabled = false,
      apiBaseUrl = '',
      privacyVersion = '',
      privacyUrl = '',
      adminReviewConfigured = false,
      allowInsecureDev = false;

  factory PartnerInquiryConfig.fromEnvironment() {
    const appEnvironment = String.fromEnvironment('APP_ENV');
    return PartnerInquiryConfig(
      enabled: const bool.fromEnvironment(
        'PICORADAR_PARTNER_INQUIRIES_ENABLED',
      ),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      privacyVersion: const String.fromEnvironment(
        'PICORADAR_PARTNER_PRIVACY_VERSION',
      ),
      privacyUrl: const String.fromEnvironment('PICORADAR_PARTNER_PRIVACY_URL'),
      adminReviewConfigured: const bool.fromEnvironment(
        'PICORADAR_PARTNER_ADMIN_REVIEW_CONFIGURED',
      ),
      allowInsecureDev:
          appEnvironment == 'dev' &&
          !kReleaseMode &&
          const bool.fromEnvironment(
            'PICORADAR_PARTNER_INQUIRIES_ALLOW_INSECURE_DEV',
          ),
    );
  }

  final bool enabled;
  final String apiBaseUrl;
  final String privacyVersion;
  final String privacyUrl;
  final bool adminReviewConfigured;
  final bool allowInsecureDev;

  Uri? get apiBaseUri => _absoluteUri(apiBaseUrl);
  Uri? get privacyUri => _absoluteUri(privacyUrl);

  bool get isAvailable {
    final api = apiBaseUri;
    final privacy = privacyUri;
    if (!enabled ||
        !adminReviewConfigured ||
        privacyVersion.trim().isEmpty ||
        api == null ||
        privacy == null ||
        privacy.scheme != 'https') {
      return false;
    }
    if (api.scheme == 'https') return true;
    return allowInsecureDev &&
        api.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '::1'}.contains(api.host);
  }

  static Uri? _absoluteUri(String source) {
    final uri = Uri.tryParse(source.trim());
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }
}
