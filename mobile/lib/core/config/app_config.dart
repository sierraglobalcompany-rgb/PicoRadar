class AppConfig {
  AppConfig({
    String? apiBaseUrl,
    required String cdnBaseUrl,
    String? manifestUrl,
  }) : apiBaseUri = _parseOptionalUri('API_BASE_URL', apiBaseUrl),
       cdnBaseUri = _parseRequiredUri('CDN_BASE_URL', cdnBaseUrl),
       manifestUri = _parseManifestUri(cdnBaseUrl, manifestUrl);

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      cdnBaseUrl: const String.fromEnvironment('CDN_BASE_URL'),
      manifestUrl: const String.fromEnvironment('MANIFEST_URL'),
    );
  }

  final Uri? apiBaseUri;
  final Uri cdnBaseUri;
  final Uri manifestUri;

  static Uri? _parseOptionalUri(String name, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return _absoluteUri(name, trimmed);
  }

  static Uri _parseRequiredUri(String name, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$name is required.');
    }
    return _absoluteUri(name, trimmed);
  }

  static Uri _parseManifestUri(String cdnBaseUrl, String? manifestUrl) {
    final cdn = _parseRequiredUri('CDN_BASE_URL', cdnBaseUrl);
    final trimmedManifest = manifestUrl?.trim();
    if (trimmedManifest == null || trimmedManifest.isEmpty) {
      return cdn.resolve('/v1/manifest.json');
    }

    final parsed = Uri.parse(trimmedManifest);
    if (parsed.hasScheme) {
      return _absoluteUri('MANIFEST_URL', trimmedManifest);
    }
    return cdn.resolveUri(parsed);
  }

  static Uri _absoluteUri(String name, String value) {
    final parsed = Uri.parse(value);
    if (!parsed.hasScheme || parsed.host.isEmpty) {
      throw ArgumentError('$name must be an absolute URL.');
    }
    if (parsed.scheme != 'https' && parsed.scheme != 'http') {
      throw ArgumentError('$name must use http or https.');
    }
    return parsed;
  }
}
