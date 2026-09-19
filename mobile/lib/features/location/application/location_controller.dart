import 'dart:async';

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
  int _operation = 0;
  Future<void> _pendingWrites = Future<void>.value();
  bool _jurisdictionInvalidationPending = false;

  @override
  Future<LocationState> build() async {
    ref.onDispose(() => _operation += 1);
    final preferences = ref.watch(appPreferencesProvider);
    final jurisdictionsFuture = ref.watch(
      restrictionJurisdictionsProvider.future,
    );
    await _pendingWrites;
    final locationPreferences = await loadLocationPreferences(preferences);
    final selectedJurisdictionId = await preferences.getString(
      picoJurisdictionPreferenceKey,
    );
    final jurisdictions = await jurisdictionsFuture;
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
    final operation = ++_operation;
    final current = state.asData?.value ?? await future;
    if (!_isCurrent(operation)) return;
    final next = current.copyWith(
      mode: LocationMode.manual,
      effectiveJurisdictionId: jurisdiction.id,
      lastManualJurisdictionId: jurisdiction.id,
      refreshStatus: LocationRefreshStatus.idle,
    );
    state = AsyncData(next);
    await _commit(operation, next, notifyJurisdiction: true);
  }

  Future<LocationRefreshStatus> enableGpsAuto() {
    return refreshGps(requestPermission: true, force: true);
  }

  Future<LocationRefreshStatus> refreshGps({
    required bool requestPermission,
    bool force = false,
  }) async {
    final loaded = state.asData?.value;
    final waitingOperation = loaded == null ? ++_operation : _operation;
    final current = loaded ?? await future;
    if (!_isCurrent(waitingOperation)) return LocationRefreshStatus.idle;
    if (!force && current.refreshStatus == LocationRefreshStatus.refreshing) {
      return LocationRefreshStatus.refreshing;
    }
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

    final operation = ++_operation;
    final refreshing = current.copyWith(
      mode: LocationMode.gpsAuto,
      refreshStatus: LocationRefreshStatus.refreshing,
    );
    state = AsyncData(refreshing);

    if (!await _commit(operation, refreshing) || !_isCurrent(operation)) {
      return LocationRefreshStatus.idle;
    }
    final gateway = ref.read(deviceLocationGatewayProvider);
    final serviceEnabled = await gateway.isLocationServiceEnabled();
    if (!_isCurrent(operation)) return LocationRefreshStatus.idle;
    if (!serviceEnabled) {
      return _finish(operation, current, LocationRefreshStatus.serviceDisabled);
    }

    var permission = await gateway.checkPermission();
    if (!_isCurrent(operation)) return LocationRefreshStatus.idle;
    if (permission != DeviceLocationPermission.granted) {
      if (!requestPermission) {
        final status = permission == DeviceLocationPermission.notRequested
            ? LocationRefreshStatus.idle
            : _permissionStatus(permission);
        return _finish(operation, current, status);
      }
      permission = await gateway.requestPermission();
      if (!_isCurrent(operation)) return LocationRefreshStatus.idle;
    }
    if (permission != DeviceLocationPermission.granted) {
      return _finish(operation, current, _permissionStatus(permission));
    }

    final result = await gateway.getCurrentPosition();
    if (!_isCurrent(operation)) return LocationRefreshStatus.idle;
    if (result is DeviceLocationError) {
      return _finish(operation, current, _failureStatus(result.failure));
    }
    final point = (result as DeviceLocationSuccess).point;
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180 ||
        !point.accuracyMeters.isFinite ||
        point.accuracyMeters < 0 ||
        point.accuracyMeters > maxJurisdictionAccuracyMeters) {
      return _finish(
        operation,
        current,
        LocationRefreshStatus.positionUnavailable,
      );
    }
    final jurisdictions = await ref.read(
      restrictionJurisdictionsProvider.future,
    );
    if (!_isCurrent(operation)) return LocationRefreshStatus.idle;
    final detectedJurisdictionId = resolveJurisdictionForPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracyMeters: point.accuracyMeters,
      supportedJurisdictions: jurisdictions,
    );
    final now = ref.read(currentInstantProvider).toUtc();
    if (detectedJurisdictionId == null) {
      return _finish(
        operation,
        current,
        LocationRefreshStatus.outsideCoverage,
        lastGpsRefreshAt: now,
      );
    }
    final committed = await _commit(
      operation,
      current.copyWith(
        mode: LocationMode.gpsAuto,
        effectiveJurisdictionId: detectedJurisdictionId,
        lastGpsRefreshAt: now,
        refreshStatus: LocationRefreshStatus.detected,
      ),
      notifyJurisdiction: true,
    );
    return committed && _isCurrent(operation)
        ? LocationRefreshStatus.detected
        : LocationRefreshStatus.idle;
  }

  Future<LocationRefreshStatus?> refreshGpsIfDue() async {
    final operation = _operation;
    final current = state.asData?.value ?? await future;
    if (!_isCurrent(operation)) return null;
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
    int operation,
    LocationState previous,
    LocationRefreshStatus status, {
    DateTime? lastGpsRefreshAt,
  }) async {
    final committed = await _commit(
      operation,
      previous.copyWith(
        mode: LocationMode.gpsAuto,
        lastGpsRefreshAt: lastGpsRefreshAt,
        refreshStatus: status,
      ),
    );
    return committed && _isCurrent(operation)
        ? status
        : LocationRefreshStatus.idle;
  }

  bool _isCurrent(int operation) => operation == _operation && ref.mounted;

  Future<bool> _commit(
    int operation,
    LocationState next, {
    bool notifyJurisdiction = false,
  }) async {
    if (notifyJurisdiction && _isCurrent(operation)) {
      _jurisdictionInvalidationPending = true;
    }
    final previousWrites = _pendingWrites;
    final done = Completer<void>();
    _pendingWrites = done.future;
    try {
      // A started preferences write cannot be cancelled. The latest complete
      // snapshot follows it, repairing any fields written by a superseded call.
      await previousWrites;
      if (!_isCurrent(operation)) return false;
      final preferences = ref.read(appPreferencesProvider);
      await saveLocationMode(preferences, next.mode);
      if (!_isCurrent(operation)) return false;
      await _writeOptionalString(
        preferences,
        lastManualJurisdictionPreferenceKey,
        next.lastManualJurisdictionId,
      );
      if (!_isCurrent(operation)) return false;
      await _writeOptionalString(
        preferences,
        picoJurisdictionPreferenceKey,
        next.effectiveJurisdictionId,
      );
      if (!_isCurrent(operation)) return false;
      final refreshAt = next.lastGpsRefreshAt;
      if (refreshAt == null) {
        await preferences.remove(lastGpsRefreshAtPreferenceKey);
      } else {
        await saveLastGpsRefreshAt(preferences, refreshAt);
      }
      if (!_isCurrent(operation)) return false;
      state = AsyncData(next);
      if (_jurisdictionInvalidationPending) {
        _jurisdictionInvalidationPending = false;
        ref.invalidate(selectedPicoJurisdictionIdProvider);
        ref.invalidate(picoNotificationSyncProvider);
        ref.invalidate(picoWidgetSyncProvider);
      }
      return true;
    } finally {
      done.complete();
    }
  }

  Future<void> _writeOptionalString(
    AppPreferences preferences,
    String key,
    String? value,
  ) => value == null
      ? preferences.remove(key)
      : preferences.setString(key, value);

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
