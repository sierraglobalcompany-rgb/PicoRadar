import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

final _testBaseTime = _roundedFutureTestBaseTime();

DateTime _roundedFutureTestBaseTime() {
  final now = DateTime.now().toUtc().add(const Duration(minutes: 5));
  return DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unknown sensor speed remains distinct from a stopped vehicle', () {
    final unknown = DrivingState(
      status: DrivingSessionStatus.active,
      preferences: defaultDrivingPreferences,
      cameraCount: 0,
      cameraSpeedKnownCount: 0,
      currentPoint: DrivingPoint(
        latitude: 6.24,
        longitude: -75.57,
        accuracyMeters: 12,
        speedKmh: null,
        recordedAt: DateTime.utc(2026, 9, 6),
      ),
    );
    final stopped = DrivingState(
      status: DrivingSessionStatus.active,
      preferences: defaultDrivingPreferences,
      cameraCount: 0,
      cameraSpeedKnownCount: 0,
      currentPoint: DrivingPoint(
        latitude: 6.24,
        longitude: -75.57,
        accuracyMeters: 12,
        speedKmh: 0,
        recordedAt: DateTime.utc(2026, 9, 6),
      ),
    );

    expect(unknown.speedKmh, isNull);
    expect(stopped.speedKmh, 0);
  });

  test('GPS sample becomes stale and recovers on the next fresh fix', () async {
    final gateway = _FakeDrivingLocationGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack(cameras: [])),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(
          _FakeDrivingFeedbackGateway(),
        ),
        drivingClockProvider.overrideWithValue(() => _testBaseTime),
        drivingGpsStaleAfterProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 36, seconds: 0));
    await _flushController();
    expect(container.read(drivingControllerProvider).value!.speedKmh, 36);

    await Future<void>.delayed(const Duration(milliseconds: 35));
    var state = container.read(drivingControllerProvider).value!;
    expect(state.gpsQuality, GpsQuality.stale);
    expect(state.speedKmh, isNull);

    gateway.add(_point(latitude: 6.240, speedKmh: 42, seconds: 1));
    await _flushController();
    state = container.read(drivingControllerProvider).value!;
    expect(state.gpsQuality, GpsQuality.good);
    expect(state.speedKmh, 42);
  });

  test(
    'old GPS sample is stale immediately and does not activate cameras',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
          drivingClockProvider.overrideWithValue(
            () => _testBaseTime.add(const Duration(seconds: 20)),
          ),
          drivingGpsStaleAfterProvider.overrideWithValue(
            const Duration(seconds: 3),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 0));
      await _flushController();

      final state = container.read(drivingControllerProvider).value!;
      expect(state.gpsQuality, GpsQuality.stale);
      expect(state.speedKmh, isNull);
      expect(state.nearestCamera, isNull);
      expect(state.lastAlert, isNull);
      expect(feedback.spokenMessages, isEmpty);
      expect(feedback.soundCalls, 0);
      expect(feedback.vibrationCalls, 0);
    },
  );

  test('coalesces burst GPS work to the newest pending sample', () async {
    final gateway = _FakeDrivingLocationGateway(sync: true);
    final observedSeconds = <int>[];
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(
          _FakeDrivingFeedbackGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<AsyncValue<DrivingState>>(
      drivingControllerProvider,
      (_, next) {
        final second = next.asData?.value.currentPoint?.recordedAt.second;
        if (second != null) observedSeconds.add(second);
      },
    );
    addTearDown(subscription.close);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 20));
    gateway.add(_point(latitude: 6.240, speedKmh: 52, seconds: 21));
    gateway.add(_point(latitude: 6.241, speedKmh: 54, seconds: 22));
    await _flushController();

    expect(container.read(drivingControllerProvider).value!.speedKmh, 54);
    expect(observedSeconds, contains(20));
    expect(observedSeconds, contains(22));
    expect(observedSeconds.last, 22);
    expect(observedSeconds.length, lessThanOrEqualTo(4));
  });

  test('feedback failure does not stop later GPS speed updates', () async {
    final gateway = _FakeDrivingLocationGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(
          _FailingDrivingFeedbackGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
    await _flushController();
    gateway.add(_point(latitude: 6.242, speedKmh: 64, seconds: 21));
    await _flushController();

    final state = container.read(drivingControllerProvider).value!;
    expect(state.status, DrivingSessionStatus.active);
    expect(state.speedKmh, 64);
  });

  test('feedback failure is visible and keeps vibration fallback', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FailingDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();

    final state = container.read(drivingControllerProvider).value!;
    expect(state.status, DrivingSessionStatus.active);
    expect(state.errorMessage, contains('audio'));
    expect(feedback.vibrationCalls, 1);
  });

  test('dispose cancels GPS and emits no later feedback', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );

    await container.read(drivingControllerProvider.notifier).start();
    container.dispose();
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();

    expect(gateway.cancelled, isTrue);
    expect(feedback.spokenMessages, isEmpty);
    expect(feedback.soundCalls, 0);
  });

  test(
    'requests location only when the driver starts a foreground session',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.future);
      expect(gateway.requestPermissionCalls, 0);

      await container.read(drivingControllerProvider.notifier).start();
      expect(gateway.requestPermissionCalls, 1);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.active,
      );
      expect(feedback.keepScreenOnStates, [true]);

      gateway.add(_point(latitude: 6.239, speedKmh: 42, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 42, seconds: 1));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(drivingControllerProvider).value!;
      expect(state.nearestCamera, isNotNull);
      expect(state.speedKmh, 42);
      expect(state.speedState, DrivingSpeedState.within);
      expect(feedback.spokenMessages.single, contains('500 metros'));
      expect(feedback.spokenMessages.single, contains('Velocidad reportada'));
      expect(feedback.soundCalls, 1);
      expect(feedback.vibrationCalls, 1);

      await container.read(drivingControllerProvider.notifier).stop();
      expect(gateway.cancelled, isTrue);
      expect(feedback.keepScreenOnStates, [true, false]);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
    },
  );

  test('first movement sample does not emit a camera alert', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.2434, speedKmh: 42, seconds: 0));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNull);
    expect(state.lastAlert, isNull);
    expect(feedback.spokenMessages, isEmpty);
  });

  test(
    'poor GPS accuracy keeps speed but blocks camera alert stages',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      for (final latitude in [6.241, 6.242]) {
        gateway.add(
          _point(
            latitude: latitude,
            speedKmh: 42,
            seconds: latitude == 6.241 ? 0 : 1,
            accuracy: 90,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(drivingControllerProvider).value!;
      expect(state.speedKmh, 42);
      expect(state.gpsQuality, GpsQuality.weak);
      expect(state.nearestCamera, isNull);
      expect(state.lastAlert, isNull);
      expect(feedback.spokenMessages, isEmpty);
    },
  );

  test(
    'continuous speed state updates while the camera episode persists',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 50, seconds: 20));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.within,
      );

      gateway.add(_point(latitude: 6.242, speedKmh: 70, seconds: 21));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.over,
      );

      gateway.add(_point(latitude: 6.243, speedKmh: 54, seconds: 22));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.within,
      );
    },
  );

  test('unknown reported speed keeps comparison fail-closed', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith(
          (ref) async => _pack(speedLimitKmh: null),
        ),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 100, seconds: 0));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 100, seconds: 20));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.speedState, DrivingSpeedState.unknownReportedSpeed);
    expect(state.isOverspeeding, isFalse);
    expect(
      feedback.spokenMessages.single,
      isNot(contains('Velocidad reportada')),
    );
  });

  test('manual dismissal silences feedback through transient no-match and rearms later', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isTrue,
    );

    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(_point(latitude: 6.242, speedKmh: 68, seconds: 45));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(
      _point(latitude: 6.2422, speedKmh: 68, seconds: 50, accuracy: 95),
    );
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.2432, speedKmh: 68, seconds: 70));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isFalse,
    );
    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);

    gateway.add(_point(latitude: 6.252, speedKmh: 54, seconds: 100));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(drivingControllerProvider).value!.nearestCamera,
      isNull,
    );

    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 90));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 120));
    await Future<void>.delayed(Duration.zero);

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.nearestCamera, isNotNull);
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(feedback.spokenMessages, hasLength(2));
    expect(feedback.soundCalls, 2);
    expect(feedback.vibrationCalls, 2);
  });

  test('manual dismissal survives an accurate transient no-match in the same episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.showCameraAlertPanel,
      isTrue,
    );
    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    final feedbackAfterDismiss = (
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    );

    gateway.add(
      _point(latitude: 6.2412, speedKmh: 72, seconds: 30, heading: 120),
    );
    await _flushController();
    expect(
      container.read(drivingControllerProvider).value!.nearestCamera,
      isNull,
    );
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(_point(latitude: 6.2425, speedKmh: 72, seconds: 35));
    await _flushController();
    var current = container.read(drivingControllerProvider).value!;
    expect(current.nearestCamera?.camera.id, 'cam-1');
    expect(current.showCameraAlertPanel, isFalse);
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(_point(latitude: 6.2435, speedKmh: 72, seconds: 45));
    await _flushController();
    current = container.read(drivingControllerProvider).value!;
    expect(current.showCameraAlertPanel, isFalse);
    expect((
      feedback.spokenMessages.length,
      feedback.soundCalls,
      feedback.vibrationCalls,
    ), feedbackAfterDismiss);

    gateway.add(
      _point(latitude: 6.2412, speedKmh: 72, seconds: 80, heading: 120),
    );
    await _flushController();
    current = container.read(drivingControllerProvider).value!;
    expect(current.dismissedCameraId, isNull);

    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 90));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 120));
    await _flushController();

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.nearestCamera?.camera.id, 'cam-1');
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(feedback.spokenMessages, hasLength(2));
    expect(feedback.soundCalls, 2);
    expect(feedback.vibrationCalls, 2);
  });

  test(
    'a different camera can alert after dismissing the current episode',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(
              cameras: [
                _camera(id: 'cam-1', latitude: 6.244),
                _camera(id: 'cam-2', latitude: 6.246),
              ],
            ),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container
            .read(drivingControllerProvider)
            .value!
            .nearestCamera!
            .camera
            .id,
        'cam-1',
      );
      await container
          .read(drivingControllerProvider.notifier)
          .dismissCurrentCameraAlert();

      gateway.add(_point(latitude: 6.2446, speedKmh: 58, seconds: 45));
      await Future<void>.delayed(Duration.zero);

      final switched = container.read(drivingControllerProvider).value!;
      expect(switched.nearestCamera!.camera.id, 'cam-2');
      expect(switched.showCameraAlertPanel, isTrue);
      expect(feedback.spokenMessages, hasLength(2));
      expect(feedback.soundCalls, 2);
      expect(feedback.vibrationCalls, 2);
    },
  );

  test(
    'dismiss cancels an in-flight camera feedback before sound and vibration',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _ControllableDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();
      feedback.blockNextSpeak();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
      await feedback.waitForBlockedSpeak();

      await container
          .read(drivingControllerProvider.notifier)
          .dismissCurrentCameraAlert();
      feedback.releaseBlockedSpeak();
      await _flushController();

      expect(
        container.read(drivingControllerProvider).value!.showCameraAlertPanel,
        isFalse,
      );
      expect(feedback.soundCalls, 0);
      expect(feedback.vibrationCalls, 0);
      expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'turning away closes the active camera target and alert panel',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 55, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(drivingControllerProvider).value!.showCameraAlertPanel,
        isTrue,
      );

      gateway.add(
        _point(latitude: 6.2412, speedKmh: 55, seconds: 40, heading: 120),
      );
      await Future<void>.delayed(Duration.zero);

      final turnedAway = container.read(drivingControllerProvider).value!;
      expect(turnedAway.nearestCamera, isNull);
      expect(turnedAway.showCameraAlertPanel, isFalse);
      expect(feedback.spokenMessages, hasLength(1));
    },
  );

  test(
    'passing a camera closes the panel while still inside 120 meters',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.2437, speedKmh: 58, seconds: 20));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(drivingControllerProvider).value!.showCameraAlertPanel,
        isTrue,
      );

      gateway.add(_point(latitude: 6.2446, speedKmh: 58, seconds: 40));
      await Future<void>.delayed(Duration.zero);

      final afterPassing = container.read(drivingControllerProvider).value!;
      expect(afterPassing.nearestCamera, isNull);
      expect(afterPassing.showCameraAlertPanel, isFalse);
      expect(feedback.spokenMessages, hasLength(1));
    },
  );

  test(
    'overspeed pulse gate fires only on transition and respects reduced motion',
    () {
      final gate = OverspeedPulseGate();

      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isTrue,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isFalse,
      );
      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: true),
        isFalse,
      );
    },
  );

  test(
    'publishes fresh speed while feedback is pending and keeps latest sample',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _ControllableDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();

      feedback.blockNextSpeak();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
      await feedback.waitForBlockedSpeak();

      var latest = container.read(drivingControllerProvider).value!;
      expect(latest.currentPoint!.recordedAt.second, 20);
      expect(latest.speedKmh, 70);

      gateway.add(_point(latitude: 6.242, speedKmh: 72, seconds: 21));
      gateway.add(_point(latitude: 6.243, speedKmh: 74, seconds: 22));
      await _flushController();

      latest = container.read(drivingControllerProvider).value!;
      expect(latest.currentPoint!.recordedAt.second, 22);
      expect(latest.speedKmh, 74);

      feedback.releaseBlockedSpeak();
      await _flushController();

      latest = container.read(drivingControllerProvider).value!;
      expect(latest.currentPoint!.recordedAt.second, 22);
      expect(latest.speedKmh, 74);
      expect(feedback.spokenMessages, hasLength(1));
      expect(feedback.soundCalls, 1);
      expect(feedback.vibrationCalls, 1);
    },
  );

  test(
    'stop invalidates pending point work before delayed feedback completes',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _ControllableDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await _flushController();

      feedback.blockNextSpeak();
      gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
      await feedback.waitForBlockedSpeak();
      await container.read(drivingControllerProvider.notifier).stop();

      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
      feedback.releaseBlockedSpeak();
      await _flushController();

      final stopped = container.read(drivingControllerProvider).value!;
      expect(stopped.status, DrivingSessionStatus.idle);
      expect(stopped.nearestCamera, isNull);
      expect(stopped.lastAlert, isNull);
      expect(feedback.soundCalls, 0);
      expect(feedback.vibrationCalls, 0);
      expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
    },
  );

  test('stop during camera pack load does not resurrect the session', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final packCompleter = Completer<CameraPack>();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) => packCompleter.future),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final start = container.read(drivingControllerProvider.notifier).start();
    await _flushController();
    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.starting,
    );

    await container.read(drivingControllerProvider.notifier).stop();
    packCompleter.complete(_pack());
    await start;
    await _flushController();

    final stopped = container.read(drivingControllerProvider).value!;
    expect(stopped.status, DrivingSessionStatus.idle);
    expect(gateway.listenCalls, 0);
    expect(feedback.keepScreenOnStates, [false]);
    expect(feedback.stopOngoingFeedbackCalls, 1);
  });

  test(
    'stop during permission request cancels start before subscribing',
    () async {
      final gateway = _ControllableStartGateway(
        checkPermissionResult: DeviceLocationPermission.denied,
      );
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      final start = container.read(drivingControllerProvider.notifier).start();
      await gateway.waitForRequestPermission();
      await container.read(drivingControllerProvider.notifier).stop();
      gateway.completeRequestPermission(DeviceLocationPermission.granted);
      await start;
      await _flushController();

      final stopped = container.read(drivingControllerProvider).value!;
      expect(stopped.status, DrivingSessionStatus.idle);
      expect(gateway.listenCalls, 0);
      expect(gateway.requestPermissionCalls, 1);
      expect(feedback.keepScreenOnStates, [false]);
    },
  );

  test('stop during keep screen on prevents a location subscription', () async {
    final gateway = _ControllableStartGateway(
      checkPermissionResult: DeviceLocationPermission.granted,
    );
    final feedback = _ControllableDrivingFeedbackGateway()
      ..blockNextKeepScreenOnEnable();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final start = container.read(drivingControllerProvider.notifier).start();
    await feedback.waitForBlockedKeepScreenOnEnable();
    await container.read(drivingControllerProvider.notifier).stop();
    feedback.releaseBlockedKeepScreenOnEnable();
    await start;
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.idle,
    );
    expect(gateway.listenCalls, 0);
    expect(feedback.keepScreenOnStates.first, isTrue);
    expect(feedback.keepScreenOnStates.where((value) => !value), isNotEmpty);
    expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
  });

  test('double start while starting creates only one subscription', () async {
    final gateway = _ControllableStartGateway(
      checkPermissionResult: DeviceLocationPermission.denied,
    );
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    final firstStart = container
        .read(drivingControllerProvider.notifier)
        .start();
    await gateway.waitForRequestPermission();
    final secondStart = container
        .read(drivingControllerProvider.notifier)
        .start();
    gateway.completeRequestPermission(DeviceLocationPermission.granted);
    await Future.wait([firstStart, secondStart]);

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.active,
    );
    expect(gateway.requestPermissionCalls, 1);
    expect(gateway.listenCalls, 1);
    expect(feedback.keepScreenOnStates, [true]);
  });

  test('old blocked feedback cannot continue in a new session', () async {
    final gateway = _RestartableDrivingLocationGateway();
    final feedback = _ControllableDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    feedback.blockNextSpeak();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await feedback.waitForBlockedSpeak();
    await container.read(drivingControllerProvider.notifier).stop();
    await container.read(drivingControllerProvider.notifier).start();

    feedback.releaseBlockedSpeak();
    await _flushController();

    expect(
      container.read(drivingControllerProvider).value!.status,
      DrivingSessionStatus.active,
    );
    expect(feedback.soundCalls, 0);
    expect(feedback.vibrationCalls, 0);
    expect(feedback.stopOngoingFeedbackCalls, greaterThanOrEqualTo(1));
  });

  test('direct gap after dismissal creates a new camera episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
    await _flushController();
    await container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    final firstEpisodeKey = container
        .read(drivingControllerProvider)
        .value!
        .cameraEpisodeKey;

    gateway.add(_point(latitude: 6.2425, speedKmh: 58, seconds: 60));
    await _flushController();

    final rearmed = container.read(drivingControllerProvider).value!;
    expect(rearmed.dismissedCameraId, isNull);
    expect(rearmed.showCameraAlertPanel, isTrue);
    expect(rearmed.cameraEpisodeKey, isNot(firstEpisodeKey));
    expect(feedback.spokenMessages, hasLength(2));
  });

  test('out of order points do not update state or emit feedback', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 70, seconds: 20));
    await _flushController();
    final feedbackAfterFreshPoint = feedback.spokenMessages.length;

    gateway.add(_point(latitude: 6.242, speedKmh: 90, seconds: 10));
    await _flushController();

    final state = container.read(drivingControllerProvider).value!;
    expect(state.currentPoint!.recordedAt.second, 20);
    expect(state.speedKmh, 70);
    expect(feedback.spokenMessages, hasLength(feedbackAfterFreshPoint));
  });

  test('weak GPS resets movement baseline before matching resumes', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(
      _point(latitude: 6.240, speedKmh: 50, seconds: 10, accuracy: 95),
    );
    await _flushController();
    gateway.add(_point(latitude: 6.242, speedKmh: 58, seconds: 20));
    await _flushController();

    var state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNull);
    expect(feedback.spokenMessages, isEmpty);

    gateway.add(_point(latitude: 6.243, speedKmh: 58, seconds: 40));
    await _flushController();

    state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNotNull);
    expect(feedback.spokenMessages, hasLength(1));
  });

  test('visual preference changes do not rearm the current episode', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final preferences = MemoryPreferences();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
    await _flushController();
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 20));
    await _flushController();
    expect(feedback.spokenMessages, hasLength(1));

    await container
        .read(drivingControllerProvider.notifier)
        .savePreferences(
          defaultDrivingPreferences.copyWith(
            cameraVisualizationMode: CameraVisualizationMode.radar,
            hudMirrorEnabled: true,
            soundEnabled: false,
            vibrationEnabled: false,
          ),
        );
    gateway.add(_point(latitude: 6.241, speedKmh: 58, seconds: 21));
    await _flushController();

    expect(feedback.spokenMessages, hasLength(1));
    expect(feedback.soundCalls, 1);
    expect(feedback.vibrationCalls, 1);
  });

  test(
    'platform gateway sends one coordinated alert with audio settings',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.picoradar.app/driving'),
            (call) async {
              calls.add(call);
              return null;
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('co.picoradar.app/driving'),
              null,
            );
      });

      await const PlatformDrivingFeedbackGateway().playAlert(
        message: 'Prueba de voz',
        playSound: true,
        output: DrivingAlertOutput.phoneSpeaker,
        musicBehavior: DrivingMusicBehavior.pause,
        volume: 0.35,
      );

      expect(calls.single.method, 'playDrivingAlert');
      expect(calls.single.arguments, {
        'message': 'Prueba de voz',
        'playSound': true,
        'output': 'phoneSpeaker',
        'musicBehavior': 'pause',
        'volume': 0.35,
      });
    },
  );

  test(
    'platform gateway keeps tone-only and voice-only alerts distinct',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.picoradar.app/driving'),
            (call) async {
              calls.add(call);
              return null;
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('co.picoradar.app/driving'),
              null,
            );
      });
      const gateway = PlatformDrivingFeedbackGateway();

      await gateway.playAlert(
        playSound: true,
        output: DrivingAlertOutput.automatic,
        musicBehavior: DrivingMusicBehavior.duck,
        volume: 0,
      );
      await gateway.playAlert(
        message: 'Solo voz',
        playSound: false,
        output: DrivingAlertOutput.automatic,
        musicBehavior: DrivingMusicBehavior.duck,
        volume: 1,
      );

      expect(calls[0].arguments, containsPair('playSound', true));
      expect(calls[0].arguments, containsPair('message', null));
      expect(calls[0].arguments, containsPair('volume', 0.0));
      expect(calls[1].arguments, containsPair('playSound', false));
      expect(calls[1].arguments, containsPair('message', 'Solo voz'));
    },
  );
}

CameraPack _pack({int? speedLimitKmh = 60, List<TrafficCamera>? cameras}) {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras:
        cameras ??
        [_camera(id: 'cam-1', latitude: 6.244, speedLimitKmh: speedLimitKmh)],
  );
}

TrafficCamera _camera({
  required String id,
  required double latitude,
  int? speedLimitKmh = 60,
}) {
  return TrafficCamera(
    id: id,
    department: 'ANTIOQUIA',
    municipality: 'MEDELLIN',
    jurisdiction: 'Municipal',
    address: 'Avenida 80',
    latitude: latitude,
    longitude: -75.57,
    status: 'Aprobada',
    technology: 'Camara',
    kind: CameraKind.mixed,
    speedLimitKmh: speedLimitKmh,
  );
}

DrivingPoint _point({
  required double latitude,
  required double speedKmh,
  required int seconds,
  double heading = 0,
  double accuracy = 14,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: -75.57,
    accuracyMeters: accuracy,
    speedKmh: speedKmh,
    headingDegrees: heading,
    recordedAt: _testBaseTime.add(Duration(seconds: seconds)),
  );
}

class _FakeDrivingFeedbackGateway implements DrivingFeedbackGateway {
  final spokenMessages = <String>[];
  final keepScreenOnStates = <bool>[];
  var soundCalls = 0;
  var stopOngoingFeedbackCalls = 0;
  var vibrationCalls = 0;

  @override
  Future<void> playAlert({
    String? message,
    required bool playSound,
    required DrivingAlertOutput output,
    required DrivingMusicBehavior musicBehavior,
    required double volume,
  }) async {
    if (message != null) spokenMessages.add(message);
    if (playSound) soundCalls += 1;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOnStates.add(enabled);
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stopOngoingFeedbackCalls += 1;
  }

  @override
  Future<void> vibrate() async {
    vibrationCalls += 1;
  }
}

class _ControllableDrivingFeedbackGateway extends _FakeDrivingFeedbackGateway {
  Completer<void>? _blockedSpeak;
  Completer<void>? _speakStarted;
  Completer<void>? _blockedKeepScreenOnEnable;
  Completer<void>? _keepScreenOnEnableStarted;
  var _feedbackCancelled = false;

  void blockNextSpeak() {
    _blockedSpeak = Completer<void>();
    _speakStarted = Completer<void>();
  }

  Future<void> waitForBlockedSpeak() async {
    await _speakStarted!.future;
  }

  void releaseBlockedSpeak() {
    final blockedSpeak = _blockedSpeak;
    if (blockedSpeak != null && !blockedSpeak.isCompleted) {
      blockedSpeak.complete();
    }
  }

  void blockNextKeepScreenOnEnable() {
    _blockedKeepScreenOnEnable = Completer<void>();
    _keepScreenOnEnableStarted = Completer<void>();
  }

  Future<void> waitForBlockedKeepScreenOnEnable() async {
    await _keepScreenOnEnableStarted!.future;
  }

  void releaseBlockedKeepScreenOnEnable() {
    final blocked = _blockedKeepScreenOnEnable;
    if (blocked != null && !blocked.isCompleted) {
      blocked.complete();
    }
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOnStates.add(enabled);
    if (enabled && _blockedKeepScreenOnEnable != null) {
      _keepScreenOnEnableStarted?.complete();
      await _blockedKeepScreenOnEnable!.future;
      _blockedKeepScreenOnEnable = null;
    }
  }

  @override
  Future<void> playAlert({
    String? message,
    required bool playSound,
    required DrivingAlertOutput output,
    required DrivingMusicBehavior musicBehavior,
    required double volume,
  }) async {
    if (message != null) spokenMessages.add(message);
    _feedbackCancelled = false;
    _speakStarted?.complete();
    final blockedSpeak = _blockedSpeak;
    if (blockedSpeak != null) {
      await blockedSpeak.future;
      _blockedSpeak = null;
    }
    if (!_feedbackCancelled && playSound) soundCalls += 1;
  }

  @override
  Future<void> stopOngoingFeedback() async {
    _feedbackCancelled = true;
    await super.stopOngoingFeedback();
  }
}

class _FailingDrivingFeedbackGateway extends _FakeDrivingFeedbackGateway {
  @override
  Future<void> playAlert({
    String? message,
    required bool playSound,
    required DrivingAlertOutput output,
    required DrivingMusicBehavior musicBehavior,
    required double volume,
  }) async {
    throw PlatformException(code: 'audio_failed');
  }
}

class _FakeDrivingLocationGateway implements DrivingLocationGateway {
  _FakeDrivingLocationGateway({bool sync = false})
    : _controller = StreamController<DrivingPoint>(sync: sync);

  final StreamController<DrivingPoint> _controller;
  var requestPermissionCalls = 0;
  var cancelled = false;
  var listenCalls = 0;

  void add(DrivingPoint point) {
    _controller.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    return _controller.stream
        .map((point) => point)
        .doOnListenAndCancel(
          onListen: () {
            listenCalls += 1;
          },
          onCancel: () {
            cancelled = true;
          },
        );
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}

class _ControllableStartGateway extends _FakeDrivingLocationGateway {
  _ControllableStartGateway({required this.checkPermissionResult});

  final DeviceLocationPermission checkPermissionResult;
  Completer<DeviceLocationPermission>? _requestPermissionCompleter;
  Completer<void>? _requestPermissionStarted;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return checkPermissionResult;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    _requestPermissionCompleter = Completer<DeviceLocationPermission>();
    _requestPermissionStarted = Completer<void>()..complete();
    return _requestPermissionCompleter!.future;
  }

  Future<void> waitForRequestPermission() async {
    while (_requestPermissionStarted == null) {
      await Future<void>.delayed(Duration.zero);
    }
    await _requestPermissionStarted!.future;
  }

  void completeRequestPermission(DeviceLocationPermission permission) {
    final completer = _requestPermissionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(permission);
    }
  }
}

class _RestartableDrivingLocationGateway implements DrivingLocationGateway {
  StreamController<DrivingPoint>? _controller;
  var requestPermissionCalls = 0;
  var listenCalls = 0;
  var cancelled = false;

  void add(DrivingPoint point) {
    _controller?.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    final controller = StreamController<DrivingPoint>();
    _controller = controller;
    return controller.stream.doOnListenAndCancel(
      onListen: () {
        listenCalls += 1;
      },
      onCancel: () {
        cancelled = true;
      },
    );
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}

extension _CancelAwareStream<T> on Stream<T> {
  Stream<T> doOnListenAndCancel({
    required void Function() onListen,
    required void Function() onCancel,
  }) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        onListen();
        subscription = listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        onCancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}

Future<void> _flushController() async {
  for (var i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
