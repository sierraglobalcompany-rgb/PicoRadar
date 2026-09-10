import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';

import '../../../test_app_harness.dart';

void main() {
  late MemoryPreferences preferences;
  late _ControlledLocationGateway gateway;

  setUp(() {
    preferences = MemoryPreferences();
    gateway = _ControlledLocationGateway();
  });

  ProviderContainer container({
    VehicleProfile Function()? activeVehicle,
    Completer<List<RestrictionJurisdiction>>? jurisdictionsGate,
  }) {
    return ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => jurisdictionsGate == null
              ? _jurisdictions
              : await jurisdictionsGate.future,
        ),
        currentInstantProvider.overrideWithValue(_now),
        deviceLocationGatewayProvider.overrideWithValue(gateway),
        if (activeVehicle != null)
          activeVehicleProvider.overrideWith((ref) async => activeVehicle()),
      ],
    );
  }

  for (final newerManual in [true, false]) {
    test(
      'latest ${newerManual ? 'manual' : 'GPS'} wins during initial load',
      () async {
        final gate = Completer<List<RestrictionJurisdiction>>();
        final ref = container(jurisdictionsGate: gate);
        addTearDown(ref.dispose);
        final controller = ref.read(locationStateProvider.notifier);
        final older = controller.enableGpsAuto();
        final Future<Object?> newer = newerManual
            ? controller.selectManual(_jurisdictions[2])
            : controller.enableGpsAuto();
        gate.complete(_jurisdictions);
        await Future.wait([older, newer]);

        if (newerManual) {
          _expectManual(ref, preferences, _jurisdictions[2]);
          expect(gateway.positionCalls, 0);
        } else {
          expect(
            ref.read(locationStateProvider).requireValue.refreshStatus,
            LocationRefreshStatus.detected,
          );
          expect(
            preferences.values[picoJurisdictionPreferenceKey],
            'co-dc-bogota',
          );
          expect(gateway.positionCalls, 1);
        }
      },
    );
  }

  test(
    'nonforced refresh does not cancel pending forced GPS with recent fix',
    () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      expect(await controller.enableGpsAuto(), LocationRefreshStatus.detected);
      final pending = gateway.enqueuePosition();
      final forced = controller.refreshGps(
        requestPermission: false,
        force: true,
      );
      await pending.started.future;

      expect(
        await controller.refreshGps(requestPermission: false),
        LocationRefreshStatus.refreshing,
      );
      expect(gateway.positionCalls, 2);
      pending.result.complete(
        DeviceLocationSuccess(_centers['co-san-bucaramanga']!),
      );
      expect(await forced, LocationRefreshStatus.detected);

      final selected = ref.read(locationStateProvider).requireValue;
      expect(selected.refreshStatus, LocationRefreshStatus.detected);
      expect(selected.effectiveJurisdictionId, 'co-san-bucaramanga');
      expect(
        preferences.values[picoJurisdictionPreferenceKey],
        selected.effectiveJurisdictionId,
      );
      expect(gateway.positionCalls, 2);
    },
  );

  for (final write in [
    (name: 'GPS mode', key: locationModePreferenceKey, value: 'gpsAuto'),
    (
      name: 'GPS city',
      key: picoJurisdictionPreferenceKey,
      value: 'co-dc-bogota',
    ),
    (
      name: 'GPS freshness',
      key: lastGpsRefreshAtPreferenceKey,
      value: _now.millisecondsSinceEpoch,
    ),
  ]) {
    test('newer manual repairs an in-flight ${write.name} write', () async {
      final controlled = _DelayedPreferences();
      preferences = controlled;
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[2]);
      final held = controlled.holdNext(write.key, write.value);
      final gps = controller.enableGpsAuto();
      await held.started.future;

      final manual = controller.selectManual(_jurisdictions[3]);
      held.release.complete();
      await Future.wait([gps, manual]);

      _expectManual(ref, preferences, _jurisdictions[3]);
      expect(
        preferences.values.containsKey(lastGpsRefreshAtPreferenceKey),
        isFalse,
      );
      expect(gateway.positionCalls, write.name == 'GPS mode' ? 0 : 1);
    });
  }

  for (final nextGps in [false, true]) {
    test(
      'in-flight manual write cannot overwrite newer ${nextGps ? 'GPS' : 'manual'}',
      () async {
        final controlled = _DelayedPreferences();
        preferences = controlled;
        final ref = container();
        addTearDown(ref.dispose);
        final controller = ref.read(locationStateProvider.notifier);
        await ref.read(locationStateProvider.future);
        await controller.selectManual(_jurisdictions[0]);
        final held = controlled.holdNext(
          picoJurisdictionPreferenceKey,
          _jurisdictions[2].id,
        );
        final older = controller.selectManual(_jurisdictions[2]);
        await held.started.future;

        gateway.point = _centers['co-san-bucaramanga']!;
        final Future<Object?> newer = nextGps
            ? controller.enableGpsAuto()
            : controller.selectManual(_jurisdictions[3]);
        held.release.complete();
        await Future.wait([older, newer]);

        final selected = ref.read(locationStateProvider).requireValue;
        expect(selected.effectiveJurisdictionId, 'co-san-bucaramanga');
        expect(
          preferences.values[picoJurisdictionPreferenceKey],
          selected.effectiveJurisdictionId,
        );
        expect(
          preferences.values[lastManualJurisdictionPreferenceKey],
          selected.lastManualJurisdictionId,
        );
        expect(
          preferences.values[locationModePreferenceKey],
          nextGps ? 'gpsAuto' : 'manual',
        );
        expect(
          selected.mode,
          nextGps ? LocationMode.gpsAuto : LocationMode.manual,
        );
        if (!nextGps) _expectManual(ref, preferences, _jurisdictions[3]);
      },
    );
  }

  test(
    'GPS failure carries pending manual city invalidation to consumers',
    () async {
      final controlled = _DelayedPreferences();
      preferences = controlled;
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[0]);
      expect(
        await ref.read(selectedPicoJurisdictionIdProvider.future),
        'co-dc-bogota',
      );
      final held = controlled.holdNext(
        picoJurisdictionPreferenceKey,
        _jurisdictions[2].id,
      );
      final manual = controller.selectManual(_jurisdictions[2]);
      await held.started.future;

      final pending = gateway.enqueuePosition();
      final gps = controller.enableGpsAuto();
      held.release.complete();
      await pending.started.future;
      pending.result.complete(
        const DeviceLocationError(DeviceLocationFailure.positionUnavailable),
      );
      await Future.wait([manual, gps]);

      final selected = ref.read(locationStateProvider).requireValue;
      expect(selected.refreshStatus, LocationRefreshStatus.positionUnavailable);
      expect(selected.effectiveJurisdictionId, 'co-cal-manizales');
      expect(
        preferences.values[picoJurisdictionPreferenceKey],
        selected.effectiveJurisdictionId,
      );
      expect(
        await ref.read(selectedPicoJurisdictionIdProvider.future),
        selected.effectiveJurisdictionId,
      );
    },
  );

  for (final outcome in _lateResults.entries) {
    test('newer manual wins over pending GPS ${outcome.key}', () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[0]);
      final pending = gateway.enqueuePosition();
      final oldOperation = controller.enableGpsAuto();
      await pending.started.future;

      await controller.selectManual(_jurisdictions[2]);
      final saved = Map<String, Object?>.of(preferences.values);
      pending.result.complete(outcome.value);
      final result = await oldOperation;

      _expectManual(ref, preferences, _jurisdictions[2]);
      expect(preferences.values, saved);
      expect(result, isNot(LocationRefreshStatus.detected));
      expect(gateway.positionCalls, 1);
    });
  }

  for (final permission in [
    DeviceLocationPermission.granted,
    DeviceLocationPermission.denied,
  ]) {
    test('newer manual stops delayed permission ${permission.name}', () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[0]);
      gateway.permissionGate = Completer<DeviceLocationPermission>();
      final oldOperation = controller.enableGpsAuto();
      await gateway.permissionStarted.future;

      await controller.selectManual(_jurisdictions[2]);
      final saved = Map<String, Object?>.of(preferences.values);
      gateway.permissionGate!.complete(permission);
      await oldOperation;

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 0);
      _expectManual(ref, preferences, _jurisdictions[2]);
      expect(preferences.values, saved);
    });
  }

  for (final outcome in _lateResults.entries) {
    test('newer GPS wins over older GPS ${outcome.key}', () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[0]);
      final older = gateway.enqueuePosition();
      final oldOperation = controller.enableGpsAuto();
      await older.started.future;
      final newer = gateway.enqueuePosition();
      final newOperation = controller.refreshGps(
        requestPermission: false,
        force: true,
      );
      await newer.started.future;

      newer.result.complete(
        DeviceLocationSuccess(_centers['co-san-bucaramanga']!),
      );
      expect(await newOperation, LocationRefreshStatus.detected);
      final saved = Map<String, Object?>.of(preferences.values);
      final selected = ref.read(locationStateProvider).requireValue;
      older.result.complete(outcome.value);
      await oldOperation;

      expect(ref.read(locationStateProvider).requireValue, same(selected));
      expect(selected.mode, LocationMode.gpsAuto);
      expect(selected.effectiveJurisdictionId, 'co-san-bucaramanga');
      expect(selected.lastManualJurisdictionId, 'co-dc-bogota');
      expect(selected.refreshStatus, LocationRefreshStatus.detected);
      expect(preferences.values, saved);
      expect(preferences.values[locationModePreferenceKey], 'gpsAuto');
      expect(
        preferences.values[picoJurisdictionPreferenceKey],
        'co-san-bucaramanga',
      );
      expect(gateway.positionCalls, 2);
    });
  }

  for (final outcome in _lateResults.entries) {
    test('disposed controller ignores pending GPS ${outcome.key}', () async {
      final ref = container();
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[0]);
      final pending = gateway.enqueuePosition();
      final oldOperation = controller.enableGpsAuto();
      // Attach the error observer before completing work on a disposed provider.
      final completion = expectLater(oldOperation, completes);
      await pending.started.future;
      final saved = Map<String, Object?>.of(preferences.values);

      ref.dispose();
      pending.result.complete(outcome.value);
      await completion;

      expect(preferences.values, saved);
      expect(gateway.positionCalls, 1);
    });
  }

  test(
    'disposal during permission check never starts a position read',
    () async {
      final ref = container();
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      gateway.permissionGate = Completer<DeviceLocationPermission>();
      final operation = controller.enableGpsAuto();
      final completion = expectLater(operation, completes);
      await gateway.permissionStarted.future;
      final saved = Map<String, Object?>.of(preferences.values);

      ref.dispose();
      gateway.permissionGate!.complete(DeviceLocationPermission.granted);
      await completion;

      expect(gateway.positionCalls, 0);
      expect(gateway.requestPermissionCalls, 0);
      expect(preferences.values, saved);
    },
  );

  for (final center in _centers.entries) {
    test(
      'GPS uses supported center ${center.key}, never registration',
      () async {
        var vehicle = _vehicle('BOG126', 'Bogota');
        final ref = container(activeVehicle: () => vehicle);
        addTearDown(ref.dispose);
        await ref.read(activeVehicleProvider.future);
        final controller = ref.read(locationStateProvider.notifier);
        await ref.read(locationStateProvider.future);
        expect(
          ref.read(locationStateProvider).requireValue.effectiveJurisdictionId,
          isNull,
        );
        await controller.selectManual(_jurisdictions[2]);
        gateway.point = center.value;
        expect(
          await controller.enableGpsAuto(),
          LocationRefreshStatus.detected,
        );
        final detected = ref.read(locationStateProvider).requireValue;
        expect(detected.effectiveJurisdictionId, center.key);
        expect(preferences.values[picoJurisdictionPreferenceKey], center.key);

        vehicle = _vehicle('MED124', 'Manizales');
        ref.invalidate(activeVehicleProvider);
        await ref.read(activeVehicleProvider.future);
        expect(ref.read(locationStateProvider).requireValue, same(detected));
        expect(gateway.positionCalls, 1);
        expect(vehicle.plate, 'MED124');
        expect(vehicle.registrationCity, 'Manizales');
        expect(preferences.values.keys.toSet(), {
          locationModePreferenceKey,
          lastManualJurisdictionPreferenceKey,
          picoJurisdictionPreferenceKey,
          lastGpsRefreshAtPreferenceKey,
        });
        expect(
          preferences.values[lastGpsRefreshAtPreferenceKey],
          _now.millisecondsSinceEpoch,
        );
      },
    );
  }

  for (final invalid in <String, DeviceLocationPoint>{
    'NaN accuracy': DeviceLocationPoint(
      latitude: _bogota.latitude,
      longitude: _bogota.longitude,
      accuracyMeters: double.nan,
    ),
    'negative accuracy': DeviceLocationPoint(
      latitude: _bogota.latitude,
      longitude: _bogota.longitude,
      accuracyMeters: -1,
    ),
    'nonfinite latitude': DeviceLocationPoint(
      latitude: double.infinity,
      longitude: _bogota.longitude,
      accuracyMeters: 60,
    ),
    'nonfinite longitude': DeviceLocationPoint(
      latitude: _bogota.latitude,
      longitude: double.nan,
      accuracyMeters: 60,
    ),
    'latitude below range': DeviceLocationPoint(
      latitude: -90.1,
      longitude: _bogota.longitude,
      accuracyMeters: 60,
    ),
    'latitude above range': DeviceLocationPoint(
      latitude: 90.1,
      longitude: _bogota.longitude,
      accuracyMeters: 60,
    ),
    'longitude below range': DeviceLocationPoint(
      latitude: _bogota.latitude,
      longitude: -180.1,
      accuracyMeters: 60,
    ),
    'longitude above range': DeviceLocationPoint(
      latitude: _bogota.latitude,
      longitude: 180.1,
      accuracyMeters: 60,
    ),
  }.entries) {
    test('invalid GPS ${invalid.key} does not confirm a fresh city', () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await ref.read(locationStateProvider.future);
      await controller.selectManual(_jurisdictions[2]);
      gateway.point = invalid.value;

      final result = await controller.enableGpsAuto();

      expect(result, LocationRefreshStatus.positionUnavailable);
      final state = ref.read(locationStateProvider).requireValue;
      expect(state.effectiveJurisdictionId, _jurisdictions[2].id);
      expect(state.lastGpsRefreshAt, isNull);
      expect(
        preferences.values[picoJurisdictionPreferenceKey],
        _jurisdictions[2].id,
      );
      expect(
        preferences.values.containsKey(lastGpsRefreshAtPreferenceKey),
        isFalse,
      );
    });
  }
}

void _expectManual(
  ProviderContainer ref,
  MemoryPreferences preferences,
  RestrictionJurisdiction jurisdiction,
) {
  final state = ref.read(locationStateProvider).requireValue;
  expect(state.mode, LocationMode.manual);
  expect(state.effectiveJurisdictionId, jurisdiction.id);
  expect(state.lastManualJurisdictionId, jurisdiction.id);
  expect(state.refreshStatus, LocationRefreshStatus.idle);
  expect(state.lastGpsRefreshAt, isNull);
  expect(preferences.values[locationModePreferenceKey], 'manual');
  expect(preferences.values[picoJurisdictionPreferenceKey], jurisdiction.id);
  expect(
    preferences.values[lastManualJurisdictionPreferenceKey],
    jurisdiction.id,
  );
}

final _now = DateTime.utc(2026, 9, 10, 15);

VehicleProfile _vehicle(String plate, String registrationCity) =>
    VehicleProfile(
      id: 'synthetic-location-vehicle',
      plate: plate,
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: registrationCity,
      createdAt: _now,
      updatedAt: _now,
    );

const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogota'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
  RestrictionJurisdiction(id: 'co-cal-manizales', name: 'Manizales'),
  RestrictionJurisdiction(id: 'co-san-bucaramanga', name: 'Bucaramanga'),
];

// Synthetic fixtures at existing catalog centers, never sampled user positions.
const _bogota = DeviceLocationPoint(
  latitude: 4.7110,
  longitude: -74.0721,
  accuracyMeters: 60,
);
const _centers = {
  'co-dc-bogota': _bogota,
  'co-ant-medellin': DeviceLocationPoint(
    latitude: 6.2442,
    longitude: -75.5812,
    accuracyMeters: 60,
  ),
  'co-cal-manizales': DeviceLocationPoint(
    latitude: 5.0703,
    longitude: -75.5138,
    accuracyMeters: 60,
  ),
  'co-san-bucaramanga': DeviceLocationPoint(
    latitude: 7.1193,
    longitude: -73.1227,
    accuracyMeters: 60,
  ),
};

const _lateResults = <String, DeviceLocationResult>{
  'success': DeviceLocationSuccess(_bogota),
  'failure': DeviceLocationError(DeviceLocationFailure.positionUnavailable),
  'outsideCoverage': DeviceLocationSuccess(
    DeviceLocationPoint(latitude: 0, longitude: 0, accuracyMeters: 60),
  ),
};

class _PendingPosition {
  final started = Completer<void>();
  final result = Completer<DeviceLocationResult>();
}

class _PendingWrite {
  _PendingWrite(this.key, this.value);

  final String key;
  final Object value;
  final started = Completer<void>();
  final release = Completer<void>();
}

class _DelayedPreferences extends MemoryPreferences {
  _PendingWrite? _pending;

  _PendingWrite holdNext(String key, Object value) {
    return _pending = _PendingWrite(key, value);
  }

  Future<void> _beforeWrite(String key, Object value) async {
    final pending = _pending;
    if (pending == null || pending.key != key || pending.value != value) return;
    _pending = null;
    pending.started.complete();
    await pending.release.future;
  }

  @override
  Future<void> setString(String key, String value) async {
    await _beforeWrite(key, value);
    await super.setString(key, value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _beforeWrite(key, value);
    await super.setInt(key, value);
  }
}

class _ControlledLocationGateway implements DeviceLocationGateway {
  final _positions = Queue<_PendingPosition>();
  final permissionStarted = Completer<void>();
  Completer<DeviceLocationPermission>? permissionGate;
  DeviceLocationPoint point = _bogota;
  int positionCalls = 0;
  int requestPermissionCalls = 0;

  _PendingPosition enqueuePosition() {
    final pending = _PendingPosition();
    _positions.add(pending);
    return pending;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    if (!permissionStarted.isCompleted) permissionStarted.complete();
    return permissionGate == null
        ? DeviceLocationPermission.granted
        : await permissionGate!.future;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    positionCalls += 1;
    if (_positions.isEmpty) return DeviceLocationSuccess(point);
    final pending = _positions.removeFirst();
    pending.started.complete();
    return pending.result.future;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
