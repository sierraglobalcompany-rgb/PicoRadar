import '../../garage/data/vehicle_profile.dart';
import '../data/trip_municipality_catalog.dart';

class TripPlanRequest {
  const TripPlanRequest({
    required this.requestId,
    required this.origin,
    required this.destination,
    required this.vehicle,
    required this.departureUtc,
    this.standardVehicleConfirmed = false,
  });

  final String requestId;
  final TripMunicipality origin;
  final TripMunicipality destination;
  final VehicleProfile vehicle;
  final DateTime departureUtc;
  final bool standardVehicleConfirmed;

  String get vehicleCategory => !standardVehicleConfirmed
      ? 'unsupported_vehicle'
      : vehicle.kind == VehicleKind.motorcycle
      ? 'motorcycle'
      : vehicle.serviceType == VehicleServiceType.taxi
      ? 'taxi'
      : 'car';

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'origin': _municipality(origin),
    'destination': _municipality(destination),
    'departureUtc': departureUtc.toUtc().toIso8601String(),
    'timeZone': 'America/Bogota',
    'vehicleCategory': vehicleCategory,
    'paymentMethod': 'cash',
    'alternatives': 3,
  };

  static Map<String, String> _municipality(TripMunicipality value) => {
    'code': value.code,
    'municipality': value.municipality,
    'department': value.department,
  };
}

class TripPlan {
  TripPlan({
    required this.requestId,
    required this.generatedAtUtc,
    required this.provider,
    required this.attribution,
    required this.origin,
    required this.destination,
    required List<TripRouteOption> routes,
  }) : routes = List.unmodifiable(routes);
  final String requestId;
  final DateTime generatedAtUtc;
  final String provider;
  final String attribution;
  final TripResolvedPoint origin;
  final TripResolvedPoint destination;
  final List<TripRouteOption> routes;
}

class TripResolvedPoint {
  const TripResolvedPoint({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
  final String label;
  final double latitude;
  final double longitude;
}

class TripRouteOption {
  const TripRouteOption({
    required this.id,
    required this.summary,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.timeBasis,
    required this.tolls,
  });
  final String id;
  final String summary;
  final int distanceMeters;
  final int durationSeconds;
  final String timeBasis;
  final TripTolls tolls;

  DateTime arrivalUtc(DateTime departureUtc) =>
      departureUtc.toUtc().add(Duration(seconds: durationSeconds));
}

enum TripTollCoverage {
  complete,
  partial,
  unknown,
  noChargeConfirmed,
  unsupportedVehicle,
}

class TripTolls {
  TripTolls({
    required this.coverage,
    required this.vehicleCategory,
    this.paymentMethod = 'cash',
    this.totalMinor,
    this.subtotalMinor,
    this.missingRates = 0,
    this.stationCount,
    this.payableCount,
    List<TripTollCharge> charges = const [],
  }) : charges = List.unmodifiable(charges);
  final TripTollCoverage coverage;
  final String vehicleCategory;
  final String paymentMethod;
  final int? totalMinor;
  final int? subtotalMinor;
  final int missingRates;
  final int? stationCount;
  final int? payableCount;
  final List<TripTollCharge> charges;
}

class TripTollCharge {
  const TripTollCharge({
    required this.name,
    this.amountMinor,
    this.sourceUrl,
    this.effectiveAt,
  });
  final String name;
  final int? amountMinor;
  final String? sourceUrl;
  final String? effectiveAt;
}

class TripPlanFailure implements Exception {
  const TripPlanFailure(this.code, {this.maxFutureDays});
  final String code;
  final int? maxFutureDays;
  @override
  String toString() => 'TripPlanFailure($code)';
}
