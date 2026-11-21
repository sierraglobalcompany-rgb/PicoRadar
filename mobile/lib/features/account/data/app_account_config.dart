import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appAccountConfigProvider = Provider<AppAccountConfig>(
  (ref) => AppAccountConfig.fromEnvironment(),
);

class AppAccountConfig {
  const AppAccountConfig({
    required this.enabled,
    required this.emailEnabled,
    required this.apiBaseUrl,
    required this.privacyUrl,
    required this.privacyVersion,
    this.allowInsecureDev = false,
  });

  const AppAccountConfig.disabled()
    : enabled = false,
      emailEnabled = false,
      apiBaseUrl = '',
      privacyUrl = '',
      privacyVersion = '',
      allowInsecureDev = false;

  factory AppAccountConfig.fromEnvironment() {
    const appEnvironment = String.fromEnvironment('APP_ENV');
    return AppAccountConfig(
      enabled: const bool.fromEnvironment('PICORADAR_ACCOUNTS_ENABLED'),
      emailEnabled: const bool.fromEnvironment(
        'PICORADAR_ACCOUNT_EMAIL_ENABLED',
      ),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      privacyUrl: const String.fromEnvironment('PICORADAR_ACCOUNT_PRIVACY_URL'),
      privacyVersion: const String.fromEnvironment(
        'PICORADAR_ACCOUNT_PRIVACY_VERSION',
      ),
      allowInsecureDev:
          appEnvironment == 'dev' &&
          !kReleaseMode &&
          const bool.fromEnvironment('PICORADAR_ACCOUNTS_ALLOW_INSECURE_LOCAL'),
    );
  }

  final bool enabled;
  final bool emailEnabled;
  final String apiBaseUrl;
  final String privacyUrl;
  final String privacyVersion;
  final bool allowInsecureDev;

  Uri? get apiBaseUri => _parse(apiBaseUrl);
  Uri? get privacyUri => _parse(privacyUrl);

  bool get privacyConfigured =>
      privacyVersion.trim().isNotEmpty &&
      privacyUri != null &&
      privacyUri!.scheme == 'https';

  bool get isAvailable {
    final api = apiBaseUri;
    if (!enabled || !emailEnabled || api == null) return false;
    if (api.scheme == 'https') return true;
    return allowInsecureDev &&
        api.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '::1'}.contains(api.host);
  }

  Uri? _parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
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
