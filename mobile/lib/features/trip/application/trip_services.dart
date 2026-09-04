import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/trip_draft_store.dart';

final tripDraftStoreProvider = Provider<TripDraftStore>((ref) {
  return TripDraftStore(ref.watch(appPreferencesProvider));
});

final tripExternalNavigationProvider = Provider<TripExternalNavigation>((ref) {
  return TripExternalNavigation(ref.watch(externalLauncherProvider));
});

const inviasRoadStatusUrl =
    'https://www.invias.gov.co/index.php/informacion-institucional/2-uncategorised/57-estado-de-la-red-vial';

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
