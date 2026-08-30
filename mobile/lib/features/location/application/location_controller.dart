import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/storage/app_preferences.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../pico_placa/data/restriction_store.dart';
import '../data/location_preferences.dart';
import '../domain/jurisdiction_location_resolver.dart';
import '../platform/device_location_gateway.dart';

final deviceLocationGatewayProvider = Provider<DeviceLocationGateway>((ref) {
  return const GeolocatorDeviceLocationGateway();
});

final locationStateProvider =
    AsyncNotifierProvider<LocationController, LocationState>(
      LocationController.new,
    );

enum LocationRefreshStatus {
  idle,
  refreshing,
  detected,
  outsideCoverage,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  positionUnavailable,
}

class LocationState {
  const LocationState({
    required this.mode,
    required this.effectiveJurisdictionId,
    required this.lastManualJurisdictionId,
    required this.lastGpsRefreshAt,
    required this.refreshStatus,
  });

  final LocationMode mode;
  final String? effectiveJurisdictionId;
  final String? lastManualJurisdictionId;
  final DateTime? lastGpsRefreshAt;
  final LocationRefreshStatus refreshStatus;

  LocationState copyWith({
    LocationMode? mode,
    String? effectiveJurisdictionId,
    bool clearEffectiveJurisdictionId = false,
    String? lastManualJurisdictionId,
    DateTime? lastGpsRefreshAt,
    LocationRefreshStatus? refreshStatus,
  }) {
    return LocationState(
      mode: mode ?? this.mode,
      effectiveJurisdictionId: clearEffectiveJurisdictionId
          ? null
          : effectiveJurisdictionId ?? this.effectiveJurisdictionId,
      lastManualJurisdictionId:
          lastManualJurisdictionId ?? this.lastManualJurisdictionId,
      lastGpsRefreshAt: lastGpsRefreshAt ?? this.lastGpsRefreshAt,
      refreshStatus: refreshStatus ?? this.refreshStatus,
    );
  }
}

class LocationController extends AsyncNotifier<LocationState> {
  @override
  Future<LocationState> build() async {
    final preferences = ref.watch(appPreferencesProvider);
    final locationPreferences = await loadLocationPreferences(preferences);
    final selectedJurisdictionId = await preferences.getString(
      picoJurisdictionPreferenceKey,
    );
    final jurisdictions = await ref.watch(
      restrictionJurisdictionsProvider.future,
    );
    final effectiveJurisdictionId = _validJurisdictionId(
      selectedJurisdictionId,
      jurisdictions,
    );
    return LocationState(
      mode: locationPreferences.mode,
      effectiveJurisdictionId: effectiveJurisdictionId,
      lastManualJurisdictionId: _validJurisdictionId(
        locationPreferences.lastManualJurisdictionId,
        jurisdictions,
      ),
      lastGpsRefreshAt: locationPreferences.lastGpsRefreshAt,
      refreshStatus: LocationRefreshStatus.idle,
    );
  }

  Future<void> selectManual(RestrictionJurisdiction jurisdiction) async {
    final preferences = ref.read(appPreferencesProvider);
    await saveLocationMode(preferences, LocationMode.manual);
    await saveLastManualJurisdiction(preferences, jurisdiction.id);
    await _setEffectiveJurisdiction(preferences, jurisdiction.id);
    state = AsyncData(
      (state.asData?.value ?? await build()).copyWith(
        mode: LocationMode.manual,
        effectiveJurisdictionId: jurisdiction.id,
        lastManualJurisdictionId: jurisdiction.id,
        refreshStatus: LocationRefreshStatus.idle,
      ),
    );
  }

  Future<LocationRefreshStatus> enableGpsAuto() {
    return refreshGps(requestPermission: true, force: true);
  }

  Future<LocationRefreshStatus> refreshGps({
    required bool requestPermission,
    bool force = false,
  }) async {
    final current = state.asData?.value ?? await build();
    if (!force &&
        current.mode == LocationMode.gpsAuto &&
        current.lastGpsRefreshAt != null &&
        ref
                .read(currentInstantProvider)
                .toUtc()
                .difference(current.lastGpsRefreshAt!) <
            locationRefreshTtl) {
      return current.refreshStatus;
    }

    state = AsyncData(
      current.copyWith(
        mode: LocationMode.gpsAuto,
        refreshStatus: LocationRefreshStatus.refreshing,
      ),
    );

    final preferences = ref.read(appPreferencesProvider);
    await saveLocationMode(preferences, LocationMode.gpsAuto);
    final gateway = ref.read(deviceLocationGatewayProvider);
    if (!await gateway.isLocationServiceEnabled()) {
      return _finish(current, LocationRefreshStatus.serviceDisabled);
    }

    var permission = await gateway.checkPermission();
    if (permission != DeviceLocationPermission.granted) {
      if (!requestPermission) {
        final status = permission == DeviceLocationPermission.notRequested
            ? LocationRefreshStatus.idle
            : _permissionStatus(permission);
        return _finish(current, status);
      }
      permission = await gateway.requestPermission();
    }
    if (permission != DeviceLocationPermission.granted) {
      return _finish(current, _permissionStatus(permission));
    }

    final result = await gateway.getCurrentPosition();
    if (result is DeviceLocationError) {
      return _finish(current, _failureStatus(result.failure));
    }
    final point = (result as DeviceLocationSuccess).point;
    final jurisdictions = await ref.read(
      restrictionJurisdictionsProvider.future,
    );
    final detectedJurisdictionId = resolveJurisdictionForPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      supportedJurisdictions: jurisdictions,
    );
    final now = ref.read(currentInstantProvider).toUtc();
    await saveLastGpsRefreshAt(preferences, now);
    if (detectedJurisdictionId == null) {
      return _finish(
        current,
        LocationRefreshStatus.outsideCoverage,
        lastGpsRefreshAt: now,
      );
    }
    await _setEffectiveJurisdiction(preferences, detectedJurisdictionId);
    state = AsyncData(
      current.copyWith(
        mode: LocationMode.gpsAuto,
        effectiveJurisdictionId: detectedJurisdictionId,
        lastGpsRefreshAt: now,
        refreshStatus: LocationRefreshStatus.detected,
      ),
    );
    return LocationRefreshStatus.detected;
  }

  Future<LocationRefreshStatus?> refreshGpsIfDue() async {
    final current = state.asData?.value ?? await build();
    if (current.mode != LocationMode.gpsAuto) {
      return null;
    }
    final lastRefresh = current.lastGpsRefreshAt;
    if (lastRefresh != null &&
        ref.read(currentInstantProvider).toUtc().difference(lastRefresh) <
            locationRefreshTtl) {
      return null;
    }
    return refreshGps(requestPermission: false);
  }

  Future<bool> openAppSettings() {
    return ref.read(deviceLocationGatewayProvider).openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return ref.read(deviceLocationGatewayProvider).openLocationSettings();
  }

  Future<LocationRefreshStatus> _finish(
    LocationState previous,
    LocationRefreshStatus status, {
    DateTime? lastGpsRefreshAt,
  }) async {
    state = AsyncData(
      previous.copyWith(
        mode: LocationMode.gpsAuto,
        lastGpsRefreshAt: lastGpsRefreshAt,
        refreshStatus: status,
      ),
    );
    return status;
  }

  Future<void> _setEffectiveJurisdiction(
    AppPreferences preferences,
    String jurisdictionId,
  ) async {
    await preferences.setString(picoJurisdictionPreferenceKey, jurisdictionId);
    ref.invalidate(selectedPicoJurisdictionIdProvider);
    ref.invalidate(picoNotificationSyncProvider);
    ref.invalidate(picoWidgetSyncProvider);
  }

  String? _validJurisdictionId(
    String? jurisdictionId,
    List<RestrictionJurisdiction> jurisdictions,
  ) {
    if (jurisdictionId == null) {
      return null;
    }
    return jurisdictions.any(
          (jurisdiction) => jurisdiction.id == jurisdictionId,
        )
        ? jurisdictionId
        : null;
  }

  LocationRefreshStatus _permissionStatus(DeviceLocationPermission permission) {
    return switch (permission) {
      DeviceLocationPermission.granted => LocationRefreshStatus.idle,
      DeviceLocationPermission.denied => LocationRefreshStatus.permissionDenied,
      DeviceLocationPermission.deniedForever =>
        LocationRefreshStatus.permissionDeniedForever,
      DeviceLocationPermission.notRequested =>
        LocationRefreshStatus.permissionDenied,
    };
  }

  LocationRefreshStatus _failureStatus(DeviceLocationFailure failure) {
    return switch (failure) {
      DeviceLocationFailure.serviceDisabled =>
        LocationRefreshStatus.serviceDisabled,
      DeviceLocationFailure.permissionDenied =>
        LocationRefreshStatus.permissionDenied,
      DeviceLocationFailure.permissionDeniedForever =>
        LocationRefreshStatus.permissionDeniedForever,
      DeviceLocationFailure.positionUnavailable =>
        LocationRefreshStatus.positionUnavailable,
    };
  }
}
