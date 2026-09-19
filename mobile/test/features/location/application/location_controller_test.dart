import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';
import 'package:picoradar/features/location/domain/jurisdiction_location_resolver.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';

import '../../../test_app_harness.dart';

void main() {
  late MemoryPreferences preferences;
  late _FakeDeviceLocationGateway gateway;
  late DateTime now;

  setUp(() {
    preferences = MemoryPreferences();
    gateway = _FakeDeviceLocationGateway();
    now = DateTime.utc(2026, 8, 27, 18);
  });

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => _jurisdictions,
        ),
        currentInstantProvider.overrideWithValue(now),
        deviceLocationGatewayProvider.overrideWithValue(gateway),
      ],
    );
  }

  test('build does not check or request location permission', () async {
    final ref = container();
    addTearDown(ref.dispose);

    await ref.read(locationStateProvider.future);

    expect(gateway.checkPermissionCalls, 0);
    expect(gateway.requestPermissionCalls, 0);
    expect(gateway.positionCalls, 0);
  });

  test(
    'uncertain GPS cannot replace a manually selected jurisdiction',
    () async {
      final ref = container();
      addTearDown(ref.dispose);
      final controller = ref.read(locationStateProvider.notifier);
      await controller.selectManual(_jurisdictions.first);
      gateway.point = const DeviceLocationPoint(
        latitude: 6.2442,
        longitude: -75.5812,
        accuracyMeters: 5000,
      );
      final result = await controller.enableGpsAuto();
      expect(result, LocationRefreshStatus.positionUnavailable);
      expect(
        await preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
    },
  );

  test(
    'manual selection persists as the effective Pico jurisdiction',
    () async {
      final ref = container();
      addTearDown(ref.dispose);
      await ref.read(locationStateProvider.future);

      await ref
          .read(locationStateProvider.notifier)
          .selectManual(_jurisdictions.first);

      final state = await ref.read(locationStateProvider.future);
      expect(state.mode, LocationMode.manual);
      expect(state.effectiveJurisdictionId, 'co-dc-bogota');
      expect(state.lastManualJurisdictionId, 'co-dc-bogota');
      expect(
        await preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
    },
  );

  test(
    'GPS auto requests permission only from explicit enable and detects Bogota',
    () async {
      final ref = container();
      addTearDown(ref.dispose);
      gateway
        ..permission = DeviceLocationPermission.denied
        ..permissionAfterRequest = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );

      final result = await ref
          .read(locationStateProvider.notifier)
          .enableGpsAuto();

      final state = await ref.read(locationStateProvider.future);
      expect(result, LocationRefreshStatus.detected);
      expect(state.mode, LocationMode.gpsAuto);
      expect(state.effectiveJurisdictionId, 'co-dc-bogota');
      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.positionCalls, 1);
      expect(
        await preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
      expect(await preferences.getString(locationModePreferenceKey), 'gpsAuto');
    },
  );

  test(
    'GPS auto updates the effective city when the vehicle moves cities',
    () async {
      await preferences.setString(locationModePreferenceKey, 'gpsAuto');
      await preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );
      final ref = container();
      addTearDown(ref.dispose);
      gateway.point = const DeviceLocationPoint(
        latitude: 6.2442,
        longitude: -75.5812,
        accuracyMeters: 35,
      );

      final result = await ref
          .read(locationStateProvider.notifier)
          .refreshGps(requestPermission: false, force: true);

      final state = await ref.read(locationStateProvider.future);
      expect(result, LocationRefreshStatus.detected);
      expect(state.mode, LocationMode.gpsAuto);
      expect(state.effectiveJurisdictionId, 'co-ant-medellin');
      expect(
        await preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
    },
  );

  test(
    'GPS outside coverage preserves the last effective jurisdiction',
    () async {
      await preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );
      final ref = container();
      addTearDown(ref.dispose);
      gateway.point = const DeviceLocationPoint(
        latitude: 10.3910,
        longitude: -75.4794,
        accuracyMeters: 90,
      );

      final result = await ref
          .read(locationStateProvider.notifier)
          .refreshGps(requestPermission: true, force: true);

      final state = await ref.read(locationStateProvider.future);
      expect(result, LocationRefreshStatus.outsideCoverage);
      expect(state.effectiveJurisdictionId, 'co-ant-medellin');
      expect(
        await preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect(state.lastGpsRefreshAt, now);
    },
  );

  test(
    'resume TTL refresh does not prompt when permission is not requested',
    () async {
      await preferences.setString(locationModePreferenceKey, 'gpsAuto');
      await preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );
      final ref = container();
      addTearDown(ref.dispose);
      gateway.permission = DeviceLocationPermission.notRequested;

      final result = await ref
          .read(locationStateProvider.notifier)
          .refreshGpsIfDue();

      final state = await ref.read(locationStateProvider.future);
      expect(result, LocationRefreshStatus.idle);
      expect(state.effectiveJurisdictionId, 'co-dc-bogota');
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 0);
    },
  );

  test('resume TTL skips GPS when recent refresh is still valid', () async {
    await preferences.setString(locationModePreferenceKey, 'gpsAuto');
    await preferences.setString(picoJurisdictionPreferenceKey, 'co-dc-bogota');
    await preferences.setInt(
      lastGpsRefreshAtPreferenceKey,
      now.subtract(locationRefreshTtl ~/ 2).millisecondsSinceEpoch,
    );
    final ref = container();
    addTearDown(ref.dispose);

    final result = await ref
        .read(locationStateProvider.notifier)
        .refreshGpsIfDue();

    expect(result, isNull);
    expect(gateway.checkPermissionCalls, 0);
    expect(gateway.requestPermissionCalls, 0);
  });

  test('permission and service failures are explicit states', () async {
    final deniedForever = container();
    addTearDown(deniedForever.dispose);
    gateway.permission = DeviceLocationPermission.deniedForever;

    final deniedResult = await deniedForever
        .read(locationStateProvider.notifier)
        .enableGpsAuto();

    expect(deniedResult, LocationRefreshStatus.permissionDeniedForever);
    expect(gateway.requestPermissionCalls, 1);

    final serviceGateway = _FakeDeviceLocationGateway()..serviceEnabled = false;
    final serviceRef = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => _jurisdictions,
        ),
        currentInstantProvider.overrideWithValue(now),
        deviceLocationGatewayProvider.overrideWithValue(serviceGateway),
      ],
    );
    addTearDown(serviceRef.dispose);

    final serviceResult = await serviceRef
        .read(locationStateProvider.notifier)
        .enableGpsAuto();

    expect(serviceResult, LocationRefreshStatus.serviceDisabled);
    expect(serviceGateway.requestPermissionCalls, 0);
  });
}

const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogota'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
];

class _FakeDeviceLocationGateway implements DeviceLocationGateway {
  bool serviceEnabled = true;
  DeviceLocationPermission permission = DeviceLocationPermission.granted;
  DeviceLocationPermission? permissionAfterRequest;
  DeviceLocationResult? positionResult;
  DeviceLocationPoint point = const DeviceLocationPoint(
    latitude: 6.2442,
    longitude: -75.5812,
    accuracyMeters: 60,
  );
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int positionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    checkPermissionCalls += 1;
    return permission;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    permission = permissionAfterRequest ?? permission;
    return permission;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    positionCalls += 1;
    return positionResult ?? DeviceLocationSuccess(point);
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls += 1;
    return true;
  }
}
