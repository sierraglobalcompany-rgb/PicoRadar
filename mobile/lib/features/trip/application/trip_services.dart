import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/domain/restriction_engine.dart';
import '../data/trip_draft_store.dart';
import '../data/trip_municipality_catalog.dart';
import 'trip_restriction_evaluation.dart';

export 'trip_restriction_evaluation.dart' show TripEndpointRestriction;

final tripDraftStoreProvider = Provider<TripDraftStore>((ref) {
  return TripDraftStore(ref.watch(appPreferencesProvider));
});

final tripExternalNavigationProvider = Provider<TripExternalNavigation>((ref) {
  return TripExternalNavigation(ref.watch(externalLauncherProvider));
});

const inviasRoadStatusUrl = 'https://hermes2.invias.gov.co/SIV/';

typedef TripRestrictionQuery = ({
  TripMunicipality? municipality,
  VehicleProfile? vehicle,
  DateTime date,
});

final tripRestrictionProvider =
    FutureProvider.family<TripEndpointRestriction, TripRestrictionQuery>((
      ref,
      query,
    ) async {
      final municipality = query.municipality;
      final vehicle = query.vehicle;
      final jurisdictionId = municipality?.jurisdictionId;
      if (municipality == null || vehicle == null || jurisdictionId == null) {
        return const TripEndpointRestriction(
          status: RestrictionDayStatus.unknown,
          sourceUrl: null,
        );
      }
      final ruleSet = await ref
          .watch(restrictionStoreProvider)
          .loadCoverage(
            jurisdictionId,
            vehicle.kind,
            vehicle.serviceType,
            ref.watch(bogotaNowProvider),
          );
      final evaluation = evaluateRestrictionDay(
        ruleSet: ruleSet,
        jurisdictionId: jurisdictionId,
        plate: vehicle.plate,
        vehicleKind: vehicle.kind,
        serviceType: vehicle.serviceType,
        date: query.date,
      );
      return TripEndpointRestriction(
        status: evaluation.status,
        sourceUrl:
            evaluation.sourceUrl ??
            (ruleSet.sourceUrls.isEmpty ? null : ruleSet.sourceUrls.first),
      );
    });

typedef TripInstantRestrictionQuery = ({
  TripMunicipality? municipality,
  VehicleProfile? vehicle,
  DateTime instantUtc,
});

final tripInstantRestrictionProvider =
    FutureProvider.family<TripEndpointRestriction, TripInstantRestrictionQuery>((
      ref,
      query,
    ) async {
      final instantUtc = query.instantUtc.toUtc();
      final nowUtc = ref.watch(currentInstantProvider).toUtc();
      final municipality = query.municipality;
      final vehicle = query.vehicle;
      final jurisdictionId = municipality?.jurisdictionId;
      var ruleSet = const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
      if (vehicle != null &&
          jurisdictionId != null &&
          jurisdictionId.isNotEmpty) {
        final store = ref.watch(restrictionStoreProvider);
        try {
          ruleSet = await store.loadCoverage(
            jurisdictionId,
            vehicle.kind,
            vehicle.serviceType,
            nowUtc,
          );
        } on Object {
          return TripEndpointRestriction(
            status: RestrictionDayStatus.unknown,
            instantStatus: RestrictionStatus.unknown,
            reason: 'load_error',
            evaluatedAtUtc: instantUtc,
          );
        }
      }
      return evaluateTripRestriction(
        ruleSet: ruleSet,
        municipality: municipality,
        vehicle: vehicle,
        instantUtc: instantUtc,
        nowUtc: nowUtc,
      );
    });

class TripExternalNavigation {
  const TripExternalNavigation(this._launcher);

  final ExternalLauncher _launcher;

  Future<bool> openGoogleMaps({required String destination, String? origin}) {
    return _launcher.openExternal(
      googleMapsTripUrl(origin: origin, destination: destination),
    );
  }

  Future<bool> openWaze({required String destination}) {
    return _launcher.openExternal(wazeTripUrl(destination: destination));
  }

  Future<bool> openInviasRoadStatus() {
    return _launcher.openExternal(inviasRoadStatusUrl);
  }
}

String googleMapsTripUrl({String? origin, required String destination}) {
  final queryParameters = <String, String>{
    'api': '1',
    if (_hasText(origin)) 'origin': origin!.trim(),
    'destination': destination.trim(),
    'travelmode': 'driving',
  };
  return Uri.https('www.google.com', '/maps/dir/', queryParameters).toString();
}

String wazeTripUrl({required String destination}) {
  return Uri.https('waze.com', '/ul', {
    'q': destination.trim(),
    'navigate': 'yes',
  }).toString();
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
