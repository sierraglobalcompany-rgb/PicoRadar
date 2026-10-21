class TripTileConfig {
  const TripTileConfig({
    required this.enabled,
    required this.urlTemplate,
    required this.userAgent,
    required this.attribution,
  });

  final bool enabled;
  final String urlTemplate;
  final String userAgent;
  final String attribution;
}

TripTileConfig resolveTripTileConfig({
  required bool approved,
  required String urlTemplate,
  required String userAgent,
  required String attribution,
}) {
  final resolvedUrl = urlTemplate.trim();
  final resolvedAgent = userAgent.trim();
  final resolvedAttribution = attribution.trim();
  final uri = Uri.tryParse(
    resolvedUrl
        .replaceAll('{z}', '0')
        .replaceAll('{x}', '0')
        .replaceAll('{y}', '0'),
  );
  final validTemplate =
      resolvedUrl.contains('{z}') &&
      resolvedUrl.contains('{x}') &&
      resolvedUrl.contains('{y}');
  final validHttpsUrl =
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
  final enabled =
      approved &&
      validTemplate &&
      validHttpsUrl &&
      resolvedAgent.isNotEmpty &&
      resolvedAttribution.isNotEmpty;

  return TripTileConfig(
    enabled: enabled,
    urlTemplate: resolvedUrl,
    userAgent: resolvedAgent,
    attribution: resolvedAttribution,
  );
}
