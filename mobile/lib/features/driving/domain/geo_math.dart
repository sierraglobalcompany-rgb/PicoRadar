import 'dart:math' as math;

const earthRadiusMeters = 6371000.0;

double distanceMeters({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  final dLat = _radians(toLatitude - fromLatitude);
  final dLon = _radians(toLongitude - fromLongitude);
  final lat1 = _radians(fromLatitude);
  final lat2 = _radians(toLatitude);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double bearingDegrees({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  final lat1 = _radians(fromLatitude);
  final lat2 = _radians(toLatitude);
  final dLon = _radians(toLongitude - fromLongitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (_degrees(math.atan2(y, x)) + 360) % 360;
}

double angleDifferenceDegrees(double a, double b) {
  return signedAngleDeltaDegrees(a, b).abs();
}

double signedAngleDeltaDegrees(double fromDegrees, double toDegrees) {
  return ((toDegrees - fromDegrees + 540) % 360) - 180;
}

double _radians(double degrees) => degrees * math.pi / 180;

double _degrees(double radians) => radians * 180 / math.pi;
