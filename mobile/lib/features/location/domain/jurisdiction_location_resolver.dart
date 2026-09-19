import 'dart:math' as math;

import '../../pico_placa/data/restriction_store.dart';

const locationRefreshTtl = Duration(minutes: 20);
const maxJurisdictionAccuracyMeters = 200.0;

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

// These are conservative city-center hints, not municipal boundaries. Outside
// these cores the user must select the jurisdiction manually.
const jurisdictionLocationHints = [
  JurisdictionLocationHint(
    jurisdictionId: 'co-dc-bogota',
    centerLat: 4.7110,
    centerLon: -74.0721,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-ant-medellin',
    centerLat: 6.2442,
    centerLon: -75.5812,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-vac-cali',
    centerLat: 3.4516,
    centerLon: -76.5320,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-bol-cartagena',
    centerLat: 10.3910,
    centerLon: -75.4794,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-san-bucaramanga',
    centerLat: 7.1193,
    centerLon: -73.1227,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-atl-barranquilla',
    centerLat: 10.9685,
    centerLon: -74.7813,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-cal-manizales',
    centerLat: 5.0703,
    centerLon: -75.5138,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-cau-popayan',
    centerLat: 2.4448,
    centerLon: -76.6147,
    maxDetectionRadiusKm: 2,
  ),
  JurisdictionLocationHint(
    jurisdictionId: 'co-met-villavicencio',
    centerLat: 4.1420,
    centerLon: -73.6266,
    maxDetectionRadiusKm: 2,
  ),
];

String? resolveJurisdictionForPosition({
  required double latitude,
  required double longitude,
  required List<RestrictionJurisdiction> supportedJurisdictions,
  double accuracyMeters = 0,
  List<JurisdictionLocationHint> hints = jurisdictionLocationHints,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180 ||
      !accuracyMeters.isFinite ||
      accuracyMeters < 0 ||
      accuracyMeters > maxJurisdictionAccuracyMeters) {
    return null;
  }
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
    if (distanceKm + accuracyMeters / 1000 <= hint.maxDetectionRadiusKm) {
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
