import 'dart:math' as math;

import '../../pico_placa/data/restriction_store.dart';

const locationRefreshTtl = Duration(minutes: 20);

class JurisdictionLocationHint {
  const JurisdictionLocationHint({
    required this.jurisdictionId,
    required this.centerLat,
    required this.centerLon,
    required this.maxDetectionRadiusKm,
  });

  final String jurisdictionId;
  final double centerLat;
  final double centerLon;
  final double maxDetectionRadiusKm;
}

const jurisdictionLocationHints = [
  JurisdictionLocationHint(
    jurisdictionId: 'co-dc-bogota',
    centerLat: 4.7110,
    centerLon: -74.0721,
    maxDetectionRadiusKm: 45,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-ant-medellin',
    centerLat: 6.2442,
    centerLon: -75.5812,
    maxDetectionRadiusKm: 35,
  ),
];

String? resolveJurisdictionForPosition({
  required double latitude,
  required double longitude,
  required List<RestrictionJurisdiction> supportedJurisdictions,
  List<JurisdictionLocationHint> hints = jurisdictionLocationHints,
}) {
  final supportedIds = supportedJurisdictions
      .map((jurisdiction) => jurisdiction.id)
      .toSet();
  final matches = <({JurisdictionLocationHint hint, double distanceKm})>[];
  for (final hint in hints) {
    if (!supportedIds.contains(hint.jurisdictionId)) {
      continue;
    }
    final distanceKm = haversineDistanceKm(
      latitude,
      longitude,
      hint.centerLat,
      hint.centerLon,
    );
    if (distanceKm <= hint.maxDetectionRadiusKm) {
      matches.add((hint: hint, distanceKm: distanceKm));
    }
  }

  if (matches.length != 1) {
    return null;
  }
  return matches.single.hint.jurisdictionId;
}

double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
