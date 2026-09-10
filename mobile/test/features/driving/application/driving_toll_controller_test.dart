import 'dart:async';

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
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';

import '../../../test_app_harness.dart';
import '../toll_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'turning tolls off during GPS startup cannot restore enabled preferences',
    () async {
      final h = _Harness();
      await h.container.read(drivingControllerProvider.future);
      await h.controller.savePreferences(
        defaultDrivingPreferences.copyWith(tollAlertsEnabled: true),
      );
      h.location.serviceGate = Completer<bool>();
      final starting = h.controller.start();
      await _flush();
      expect(h.state.status, DrivingSessionStatus.starting);
      await h.controller.savePreferences(
        h.state.preferences.copyWith(tollAlertsEnabled: false),
      );
      h.location.serviceGate!.complete(true);
      await starting;
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.preferences.tollAlertsEnabled, isFalse);
      expect(h.state.nearestToll, isNull);
      expect(h.feedback.messages, isEmpty);
    },
  );

  test('Cocorna simulation uses real toll and never the GPS gateway', () async {
    final h = _Harness();
    await h.container.read(drivingControllerProvider.future);
    await h.controller.savePreferences(
      defaultDrivingPreferences.copyWith(tollAlertsEnabled: true),
    );
    await h.controller.start(
      simulationScenario: DrivingSimulationScenario.cocorna,
    );
    if (!canUseDebugDrivingSimulation) {
      expect(h.state.status, DrivingSessionStatus.locationUnavailable);
      expect(h.state.currentPoint, isNull);
      return;
    }
    expect(h.state.simulationName, 'Simulación · Peaje Cocorná');
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    expect(h.state.nearestToll!.toll.id, cocorna.id);
    expect(h.state.nearestToll!.toll.latitude, cocorna.latitude);
    expect(h.feedback.messages.single, 'Peaje ${cocorna.name} a 500 metros.');
    await h.controller.stop();
    expect(h.state.nearestToll, isNull);
  });

  test(
    'historical nonoperational toll does not produce a driving alert',
    () async {
      final historical = realTollInventory.records.firstWhere(
        (record) =>
            record.operationClassification ==
            TollOperationClassification.nonOperationalHistorical,
      );
      final h = _Harness(
        inventory: () async => TollInventoryDataset(
          version: realTollInventory.version,
          sourceTimestamp: realTollInventory.sourceTimestamp,
          records: [historical],
        ),
      );
      await h.start();
      h.location.points.add(tollPoint(650, 0, toll: historical));
      await _flush();
      h.location.points.add(tollPoint(490, 20, toll: historical));
      await _flush();
      expect(h.state.nearestToll, isNull);
      expect(h.state.showTollAlertPanel, isFalse);
    },
  );

  test(
    'tolls default off and providers stay outside the GPS hot path',
    () async {
      final h = _Harness();
      await h.start(enabled: false);
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.nearestToll, isNull);
      expect(h.inventoryLoads, 0);
      expect(h.tariffLoads, 0);
      await h.controller.savePreferences(
        h.state.preferences.copyWith(tollAlertsEnabled: true),
      );
      await _flush();
      await h.point(390, 40);
      await h.point(290, 60);
      expect(h.inventoryLoads, 1);
      expect(h.tariffLoads, 1);
      expect(h.state.nearestToll!.toll, same(cocorna));
      expect(h.state.reliableHeadingDegrees, 0);
      expect(h.state.referenceCharge!.categoryCode, 'I');
      expect(
        h.state.referenceCharge!.nominalMinor,
        realTollCatalog.byId(cocorna.id)!.categoryI!.amountMinor,
      );
      expect(h.feedback.messages.first, 'Peaje ${cocorna.name} a 500 metros.');
      expect(h.feedback.sounds, 2);
      expect(h.feedback.vibrations, 2);
    },
  );

  test('one camera card and camera audio take priority over a toll', () async {
    final h = _Harness(camera: true);
    await h.start();
    await h.point(650, 0);
    await h.point(490, 20);
    expect(h.state.showCameraAlertPanel, isTrue);
    expect(h.state.showTollAlertPanel, isFalse);
    expect(h.feedback.messages.single, startsWith('Cámara a 500 metros.'));
    await h.controller.dismissCurrentCameraAlert();
    await h.point(450, 40);
    expect(h.state.showTollAlertPanel, isTrue);
    expect(h.feedback.messages, hasLength(1));
    await h.point(290, 60);
    expect(h.feedback.messages.last, 'Peaje ${cocorna.name} a 300 metros.');
  });

  test(
    'priority change stops a pending toll voice before camera feedback',
    () async {
      final h = _Harness(camera: true);
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      await h.controller.dismissCurrentCameraAlert();
      h.feedback.block = Completer<void>();
      await h.point(290, 40);
      expect(h.feedback.messages.last, startsWith('Peaje '));
      final previousStops = h.feedback.stops;
      final previousSounds = h.feedback.sounds;
      // A new camera episode wins immediately even while old toll speech waits.
      await h.point(90, 80);
      expect(h.state.showCameraAlertPanel, isTrue);
      expect(h.state.showTollAlertPanel, isFalse);
      expect(h.feedback.stops, greaterThan(previousStops));
      h.feedback.block!.complete();
      h.feedback.block = null;
      await _flush();
      expect(h.feedback.messages.last, startsWith('Cámara '));
      expect(h.feedback.sounds, previousSounds + 1);
    },
  );

  for (final action in ['dismiss', 'off', 'pass', 'stop', 'weak', 'dispose']) {
    test(
      '$action cancels pending toll feedback without late state restoration',
      () async {
        final h = _Harness();
        await h.start();
        await h.point(650, 0);
        h.feedback.block = Completer<void>();
        await h.point(490, 20);
        expect(h.feedback.messages, hasLength(1));
        final stops = h.feedback.stops;
        switch (action) {
          case 'dismiss':
            await h.controller.dismissCurrentToll();
          case 'off':
            await h.controller.savePreferences(
              h.state.preferences.copyWith(tollAlertsEnabled: false),
            );
          case 'pass':
            await h.point(-40, 40);
          case 'stop':
            await h.controller.stop();
          case 'weak':
            await h.point(300, 40, accuracy: 95);
          case 'dispose':
            h.dispose();
        }
        h.feedback.block!.complete();
        h.feedback.block = null;
        await _flush();
        expect(h.feedback.stops, greaterThan(stops));
        expect(h.feedback.sounds, 0);
        expect(h.feedback.vibrations, 0);
        if (action != 'dispose') expect(h.state.showTollAlertPanel, isFalse);
        if (action == 'off') {
          await h.controller.savePreferences(
            h.state.preferences.copyWith(tollAlertsEnabled: true),
          );
          await h.point(290, 80);
          expect(h.state.nearestToll, isNull);
          expect(h.feedback.messages, hasLength(1));
        }
      },
    );
  }

  test(
    'delayed catalogs do not block GPS or restore a stopped session',
    () async {
      final inventory = Completer<TollInventoryDataset>();
      final tariffs = Completer<TollTariffCatalog>();
      final h = _Harness(
        inventory: () => inventory.future,
        catalog: () => tariffs.future,
      );
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.isActive, isTrue);
      expect(h.state.currentPoint!.recordedAt.second, 20);
      await h.controller.stop();
      inventory.complete(_inventory);
      tariffs.complete(realTollCatalog);
      await _flush();
      expect(h.state.isActive, isFalse);
      expect(h.state.nearestToll, isNull);
      expect(h.feedback.messages, isEmpty);
    },
  );

  for (final inventoryError in [false, true]) {
    test(
      'catalog load error (inventory=$inventoryError) keeps cameras and GPS active',
      () async {
        final h = _Harness(
          camera: true,
          inventory: inventoryError
              ? () async => throw StateError('inventory unavailable')
              : null,
          catalog: () async => throw StateError('tariff unavailable'),
        );
        await h.start();
        await h.point(650, 0);
        await h.point(490, 20);
        expect(h.state.isActive, isTrue);
        expect(h.state.showCameraAlertPanel, isTrue);
        expect(h.state.tollDataError, isNotNull);
        expect(h.feedback.messages.single, startsWith('Cámara '));
        if (!inventoryError) {
          expect(h.state.referenceCharge!.amountMinor, isNull);
          expect(h.state.referenceCharge!.nominalMinor, isNull);
          expect(h.state.referenceCharge!.pendingReason, isNotNull);
        }
        await h.point(290, 40);
        expect(h.inventoryLoads, 1);
        expect(h.tariffLoads, 1);
      },
    );
  }

  for (final control in [
    'BLOQUEADO_REVISION',
    'EXCLUIR_ESTACION_RETIRADA',
    'NO_CATEGORY_I',
    'VALIDAR_CODIGO_Y_SENTIDO',
  ]) {
    test('$control reference preserves publication controls', () async {
      final h = _Harness(catalog: () async => _catalogWithControl(control));
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      final charge = h.state.referenceCharge!;
      expect(charge.categoryCode, 'I');
      expect(charge.amountMinor, isNull);
      expect(charge.pendingReason, isNotNull);
      expect(
        charge.nominalMinor,
        control == 'VALIDAR_CODIGO_Y_SENTIDO' ? isNotNull : isNull,
      );
    });
  }

  test('shared voice sound vibration settings apply to tolls', () async {
    final h = _Harness();
    await h.start();
    await h.controller.savePreferences(
      h.state.preferences.copyWith(
        voiceEnabled: false,
        soundEnabled: false,
        vibrationEnabled: true,
      ),
    );
    await h.point(650, 0);
    await h.point(490, 20);
    expect(h.state.showTollAlertPanel, isTrue);
    expect(h.feedback.messages, isEmpty);
    expect(h.feedback.sounds, 0);
    expect(h.feedback.vibrations, 1);
  });

  for (final failedInventory in [false, true]) {
    test(
      'performance: retries failed toll snapshot on next session (inventory=$failedInventory)',
      () async {
        var fail = true;
        final h = _Harness(
          inventory: () async {
            if (fail && failedInventory) throw StateError('inventory failed');
            return _inventory;
          },
          catalog: () async {
            if (fail && !failedInventory) throw StateError('tariffs failed');
            return realTollCatalog;
          },
        );
        await h.start();
        await h.point(650, 0);
        await h.point(490, 20);
        expect(h.state.tollDataError, isNotNull);
        expect(h.inventoryLoads, 1);
        expect(h.tariffLoads, 1);

        await h.controller.stop();
        fail = false;
        await h.start();
        await h.point(650, 0);
        await h.point(490, 20);
        expect(h.state.tollDataError, isNull);
        expect(h.state.nearestToll?.toll.id, cocorna.id);
        expect(h.state.referenceCharge?.amountMinor, isNotNull);
        final loads = (h.inventoryLoads, h.tariffLoads);
        await h.point(290, 40);
        await h.point(90, 60);
        expect((h.inventoryLoads, h.tariffLoads), loads);
      },
    );
  }

  test(
    'performance: inventory refresh applies between sessions only',
    () async {
      var inventory = _inventory;
      final h = _Harness(inventory: () async => inventory);
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.nearestToll?.toll.id, cocorna.id);

      inventory = TollInventoryDataset(
        version: 'synthetic-next-version',
        sourceTimestamp: _inventory.sourceTimestamp,
        records: const [],
      );
      h.container.invalidate(tripTollInventoryProvider);
      await h.container.read(tripTollInventoryProvider.future);
      await h.point(290, 40);
      expect(h.state.nearestToll?.toll.id, cocorna.id);
      expect(h.state.isActive, isTrue);
      final loads = h.inventoryLoads;

      await h.controller.stop();
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.nearestToll, isNull);
      expect(h.state.tollDataError, isNull);
      expect(h.inventoryLoads, loads);
    },
  );

  test('performance: tariff refresh applies between sessions only', () async {
    var catalog = realTollCatalog;
    final h = _Harness(catalog: () async => catalog);
    await h.start();
    await h.point(650, 0);
    await h.point(490, 20);
    final amount = h.state.referenceCharge!.amountMinor;
    expect(amount, isNotNull);

    catalog = _catalogWithControl('BLOQUEADO_REVISION');
    h.container.invalidate(tripTollTariffCatalogProvider);
    await h.container.read(tripTollTariffCatalogProvider.future);
    await h.point(290, 40);
    expect(h.state.referenceCharge!.amountMinor, amount);

    await h.controller.stop();
    await h.start();
    await h.point(650, 0);
    await h.point(490, 20);
    expect(h.state.referenceCharge!.amountMinor, isNull);
    expect(h.state.referenceCharge!.pendingReason, isNotNull);
  });

  test(
    'performance: toll map identity is stable only within its session',
    () async {
      final h = _Harness();
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      final firstKey = h.state.tollEpisodeKey;
      expect(firstKey, isNotNull);
      await h.point(290, 40);
      expect(h.state.tollEpisodeKey, firstKey);

      await h.controller.stop();
      await h.start();
      await h.point(650, 0);
      await h.point(490, 20);
      expect(h.state.nearestToll?.toll.id, cocorna.id);
      expect(h.state.tollEpisodeKey, isNotNull);
      expect(h.state.tollEpisodeKey, isNot(firstKey));
    },
  );

  for (final lateError in [false, true]) {
    test(
      'performance: old toll load cannot replace a new session (error=$lateError)',
      () async {
        final oldLoad = Completer<TollInventoryDataset>();
        var inventory = oldLoad.future;
        final h = _Harness(inventory: () => inventory);
        await h.start();
        await h.controller.stop();

        inventory = Future.value(
          TollInventoryDataset(
            version: 'synthetic-next-session',
            sourceTimestamp: _inventory.sourceTimestamp,
            records: const [],
          ),
        );
        h.container.invalidate(tripTollInventoryProvider);
        await h.start();
        if (lateError) {
          oldLoad.completeError(StateError('superseded load'));
        } else {
          oldLoad.complete(_inventory);
        }
        await _flush();
        await h.point(650, 0);
        await h.point(490, 20);
        expect(h.state.isActive, isTrue);
        expect(h.state.nearestToll, isNull);
        expect(h.state.tollDataError, isNull);
        expect(h.feedback.messages, isEmpty);
      },
    );
  }

  for (final camera in [false, true]) {
    test(
      'performance: recreated controller has distinct map identity (camera=$camera)',
      () async {
        final first = _Harness(camera: camera);
        await first.start();
        await first.point(650, 0);
        await first.point(490, 20);
        final firstKey = camera
            ? first.state.cameraEpisodeKey
            : first.state.tollEpisodeKey;
        expect(firstKey, isNotNull);
        await first.controller.stop();
        first.dispose();

        final next = _Harness(camera: camera);
        await next.start();
        await next.point(650, 0);
        await next.point(490, 20);
        final nextKey = camera
            ? next.state.cameraEpisodeKey
            : next.state.tollEpisodeKey;
        expect(nextKey, isNotNull);
        expect(nextKey, isNot(firstKey));
      },
    );
  }

  test('visual toll pulse fires without voice sound or vibration', () async {
    final h = _Harness();
    await h.start();
    await h.controller.savePreferences(
      h.state.preferences.copyWith(
        visualAlertsEnabled: true,
        voiceEnabled: false,
        soundEnabled: false,
        vibrationEnabled: false,
      ),
    );
    await h.point(650, 0);
    await h.point(490, 20);

    expect(h.state.visualAlertPulseKey, isNotNull);
    expect(h.feedback.messages, isEmpty);
    expect(h.feedback.sounds, 0);
    expect(h.feedback.vibrations, 0);
  });
}

TollInventoryDataset get _inventory => TollInventoryDataset(
  version: realTollInventory.version,
  sourceTimestamp: realTollInventory.sourceTimestamp,
  records: [cocorna],
);

TollTariffCatalog _catalogWithControl(String control) {
  final station = realTollCatalog.byId(cocorna.id)!;
  return TollTariffCatalog(
    version: realTollCatalog.version,
    currency: realTollCatalog.currency,
    amountUnit: realTollCatalog.amountUnit,
    source: realTollCatalog.source,
    counts: realTollCatalog.counts,
    stations: [
      TollTariffStation(
        id: station.id,
        name: station.name,
        department: station.department,
        latitude: station.latitude,
        longitude: station.longitude,
        operationStatus: station.operationStatus,
        publicationControl: control == 'NO_CATEGORY_I'
            ? station.publicationControl
            : control,
        routeRule: station.routeRule,
        logicalChargeGroup: station.logicalChargeGroup,
        evidenceQuality: station.evidenceQuality,
        generalRates: control == 'NO_CATEGORY_I'
            ? station.generalRates
                  .where((rate) => rate.categoryCode != 'I')
                  .toList()
            : station.generalRates,
        specialRates: station.specialRates,
      ),
    ],
  );
}

class _Harness {
  _Harness({
    bool camera = false,
    Future<TollInventoryDataset> Function()? inventory,
    Future<TollTariffCatalog> Function()? catalog,
  }) {
    container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        drivingLocationGatewayProvider.overrideWithValue(location),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        cameraPackProvider.overrideWith(
          (ref) async => CameraPack(
            source: const CameraPackSource(
              name: 'Test',
              pageUrl: 'https://example.com',
              dataUrl: 'https://example.com',
              fetchedAtUtc: '2026-09-09T00:00:00Z',
            ),
            cameras: camera
                ? [
                    TrafficCamera(
                      id: 'camera-priority',
                      department: 'ANTIOQUIA',
                      municipality: 'COCORNA',
                      jurisdiction: 'Test',
                      address: 'Test',
                      latitude: cocorna.latitude,
                      longitude: cocorna.longitude,
                      status: 'Test',
                      technology: 'Test',
                      kind: CameraKind.mixed,
                      speedLimitKmh: 40,
                    ),
                  ]
                : [],
          ),
        ),
        tripTollInventoryProvider.overrideWith((ref) async {
          inventoryLoads++;
          return inventory == null ? _inventory : await inventory();
        }),
        tripTollTariffCatalogProvider.overrideWith((ref) async {
          tariffLoads++;
          return catalog == null ? realTollCatalog : await catalog();
        }),
      ],
    );
    addTearDown(dispose);
  }
  late final ProviderContainer container;
  final location = _Location();
  final feedback = _Feedback();
  int inventoryLoads = 0;
  int tariffLoads = 0;
  bool disposed = false;
  DrivingController get controller =>
      container.read(drivingControllerProvider.notifier);
  DrivingState get state => container.read(drivingControllerProvider).value!;
  Future<void> start({bool enabled = true}) async {
    await container.read(drivingControllerProvider.future);
    await controller.savePreferences(
      defaultDrivingPreferences.copyWith(tollAlertsEnabled: enabled),
    );
    await controller.start();
    await _flush();
  }

  Future<void> point(double south, int seconds, {double accuracy = 12}) async {
    location.points.add(tollPoint(south, seconds, accuracy: accuracy));
    await _flush();
  }

  void dispose() {
    if (!disposed) {
      disposed = true;
      container.dispose();
    }
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Location implements DrivingLocationGateway {
  final points = StreamController<DrivingPoint>.broadcast();
  Completer<bool>? serviceGate;
  @override
  Future<bool> isLocationServiceEnabled() async =>
      serviceGate == null ? true : await serviceGate!.future;
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.granted;
  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.granted;
  @override
  Stream<DrivingPoint> positionStream() => points.stream;
}

class _Feedback implements DrivingFeedbackGateway {
  final messages = <String>[];
  int sounds = 0;
  int vibrations = 0;
  int stops = 0;
  Completer<void>? block;
  @override
  Future<void> speak(String message) async {
    messages.add(message);
    await block?.future;
  }

  @override
  Future<void> playSound() async {
    sounds++;
  }

  @override
  Future<void> vibrate() async {
    vibrations++;
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stops++;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
}
