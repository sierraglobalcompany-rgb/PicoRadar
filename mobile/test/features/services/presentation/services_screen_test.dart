import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/services/presentation/services_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import 'v01b_tools_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadV01bToolsTestFont);

  for (final stage in ['service', 'check', 'position']) {
    testWidgets('F13 initial $stage exception leaves GPS retry available', (
      tester,
    ) async {
      final location = _FakeDeviceLocationGateway.success(
        const DeviceLocationPoint(
          latitude: 6.244203,
          longitude: -75.581212,
          accuracyMeters: 18,
        ),
      )..throwAt = stage;
      await _pumpServices(
        tester,
        activeVehicle: null,
        locationGateway: location,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sin señal GPS'), findsOneWidget);
      location.throwAt = null;
      await tester.tap(find.byKey(const ValueKey('services-location-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Medellín'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final stage in ['service', 'check', 'request', 'position']) {
    testWidgets('F13 $stage exception permits fallback and a later search', (
      tester,
    ) async {
      final location = _FakeDeviceLocationGateway(
        checkPermissionResult: DeviceLocationPermission.denied,
      );
      final launcher = _FakeExternalLauncher();
      await _pumpServices(
        tester,
        activeVehicle: null,
        locationGateway: location,
        externalLauncher: launcher,
      );
      await tester.pumpAndSettle();
      location.throwAt = stage;
      await tester.tap(find.byKey(const ValueKey('services-search-tow')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Seleccionar ciudad'), findsOneWidget);
      await tester.tap(find.text('Seleccionar ciudad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('services-city-fallback-search')),
        'medellin',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medellín - Antioquia'));
      await tester.pumpAndSettle();
      expect(launcher.openedUris, hasLength(1));
      location.throwAt = null;
      await tester.tap(find.byKey(const ValueKey('services-search-tow')));
      await tester.pumpAndSettle();
      expect(launcher.openedUris, hasLength(2));
    });
  }

  testWidgets('renders the GPS-first mockup structure without city field', (
    tester,
  ) async {
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá D. C.'),
      locationGateway: _FakeDeviceLocationGateway.success(
        const DeviceLocationPoint(
          latitude: 6.244203,
          longitude: -75.581212,
          accuracyMeters: 18,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Servicios'), findsNothing);
    expect(find.text('Servicios para\ntu vehículo'), findsOneWidget);
    expect(find.text('Medellín'), findsOneWidget);
    expect(find.textContaining('Bogotá'), findsNothing);
    expect(
      find.byKey(const ValueKey('services-location-pill')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    expect(find.byKey(const ValueKey('services-city-field')), findsNothing);
    expect(find.text('Buscar grúa 24 horas'), findsOneWidget);
    expect(find.text('Buscar batería'), findsOneWidget);
    expect(find.text('Buscar llantas'), findsOneWidget);
    expect(find.text('Buscar taller mecánico'), findsOneWidget);
    expect(find.text('Abrir CDA dentro de PicoRadar'), findsOneWidget);
  });

  testWidgets('each service opens Google Maps with current coordinates', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    final location = _FakeDeviceLocationGateway.success(
      const DeviceLocationPoint(
        latitude: 6.244203,
        longitude: -75.581212,
        accuracyMeters: 18,
      ),
    );
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Cali'),
      externalLauncher: launcher,
      locationGateway: location,
    );

    for (final key in [
      'services-search-tow',
      'services-search-battery',
      'services-search-tires',
      'services-search-mechanic',
    ]) {
      final action = find.byKey(ValueKey(key));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    expect(location.positionsRequested, 5);
    expect(
      launcher.openedUris.map((uri) => Uri.parse(uri).queryParameters['query']),
      [
        'grúa 24 horas cerca de 6.244203,-75.581212',
        'batería cerca de 6.244203,-75.581212',
        'llantas cerca de 6.244203,-75.581212',
        'taller mecánico cerca de 6.244203,-75.581212',
      ],
    );
    expect(
      launcher.openedUris,
      everyElement(
        startsWith('https://www.google.com/maps/search/?api=1&query='),
      ),
    );
  });

  testWidgets(
    'permission denial offers catalog city fallback without mutating vehicle',
    (tester) async {
      final launcher = _FakeExternalLauncher();
      final location = _FakeDeviceLocationGateway(
        checkPermissionResult: DeviceLocationPermission.denied,
        requestPermissionResult: DeviceLocationPermission.denied,
      );
      final vehicle = _vehicle(registrationCity: 'Bogotá D. C.');
      await _pumpServices(
        tester,
        activeVehicle: vehicle,
        externalLauncher: launcher,
        locationGateway: location,
      );

      await tester.tap(find.byKey(const ValueKey('services-search-tow')));
      await tester.pumpAndSettle();
      expect(find.text('Permiso de ubicación'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Seleccionar ciudad'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('services-city-fallback-field')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('services-city-fallback-search')),
        'medellin',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medellín - Antioquia'));
      await tester.pumpAndSettle();

      expect(vehicle.registrationCity, 'Bogotá D. C.');
      expect(location.positionsRequested, 0);
      expect(
        Uri.parse(launcher.openedUris.single).queryParameters['query'],
        'grúa 24 horas Medellín - Antioquia',
      );
    },
  );

  testWidgets(
    'typed city text without selecting a catalog row does not launch',
    (tester) async {
      final launcher = _FakeExternalLauncher();
      await _pumpServices(
        tester,
        activeVehicle: _vehicle(registrationCity: 'Bogotá D. C.'),
        externalLauncher: launcher,
        locationGateway: _FakeDeviceLocationGateway(
          checkPermissionResult: DeviceLocationPermission.denied,
          requestPermissionResult: DeviceLocationPermission.denied,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('services-search-tow')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Seleccionar ciudad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('services-city-fallback-search')),
        'ciudad inventada',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados en el catálogo local.'), findsOneWidget);
      expect(launcher.openedUris, isEmpty);
    },
  );

  testWidgets('service uses selected visit city when GPS keeps failing', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    final location = _FakeDeviceLocationGateway(serviceEnabled: false);
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá D. C.'),
      externalLauncher: launcher,
      locationGateway: location,
    );

    await tester.tap(find.byKey(const ValueKey('services-location-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar ciudad'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('services-city-fallback-search')),
      'medellin',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medellín - Antioquia'));
    await tester.pumpAndSettle();

    final tires = find.byKey(const ValueKey('services-search-tires'));
    await tester.ensureVisible(tires);
    await tester.pumpAndSettle();
    await tester.tap(tires);
    await tester.pumpAndSettle();

    expect(find.text('Medellín'), findsOneWidget);
    expect(
      Uri.parse(launcher.openedUris.single).queryParameters['query'],
      'llantas Medellín - Antioquia',
    );
  });

  testWidgets('disabled location can open location settings', (tester) async {
    final location = _FakeDeviceLocationGateway(serviceEnabled: false);
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: null),
      locationGateway: location,
    );

    final battery = find.byKey(const ValueKey('services-search-battery'));
    await tester.ensureVisible(battery);
    await tester.pumpAndSettle();
    await tester.tap(battery);
    await tester.pumpAndSettle();
    expect(find.text('Activa la ubicación'), findsOneWidget);

    await tester.tap(find.text('Abrir ajustes de ubicación'));
    await tester.pumpAndSettle();

    expect(location.locationSettingsOpened, 1);
  });

  testWidgets(
    'launcher failure shows a controlled message after GPS succeeds',
    (tester) async {
      final launcher = _FakeExternalLauncher(openResult: false);
      await _pumpServices(
        tester,
        activeVehicle: _vehicle(registrationCity: 'Cali'),
        externalLauncher: launcher,
        locationGateway: _FakeDeviceLocationGateway.success(
          const DeviceLocationPoint(
            latitude: 4.711,
            longitude: -74.0721,
            accuracyMeters: 20,
          ),
        ),
      );

      final battery = find.byKey(const ValueKey('services-search-battery'));
      await tester.ensureVisible(battery);
      await tester.pumpAndSettle();
      await tester.tap(battery);
      await tester.pumpAndSettle();

      expect(launcher.openedUris, hasLength(1));
      expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
    },
  );

  testWidgets('CDA action stays inside PicoRadar and does not launch search', (
    tester,
  ) async {
    var cdaOpened = false;
    final launcher = _FakeExternalLauncher();
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá'),
      onOpenCda: () => cdaOpened = true,
      externalLauncher: launcher,
    );

    final cda = find.byKey(const ValueKey('services-open-cda'));
    await tester.ensureVisible(cda);
    await tester.pumpAndSettle();
    await tester.tap(cda);
    await tester.pump();

    expect(cdaOpened, isTrue);
    expect(launcher.openedUris, isEmpty);
  });

  testWidgets('dispose during GPS lookup does not touch UI or ref', (
    tester,
  ) async {
    final pendingPosition = Completer<DeviceLocationResult>();
    final location = _FakeDeviceLocationGateway(
      checkPermissionResult: DeviceLocationPermission.notRequested,
      pendingPosition: pendingPosition,
    );
    final launcher = _FakeExternalLauncher();
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Cali'),
      externalLauncher: launcher,
      locationGateway: location,
    );

    final battery = find.byKey(const ValueKey('services-search-battery'));
    await tester.ensureVisible(battery);
    await tester.pumpAndSettle();
    await tester.tap(battery);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingPosition.complete(
      const DeviceLocationSuccess(
        DeviceLocationPoint(
          latitude: 3.4516,
          longitude: -76.532,
          accuracyMeters: 16,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(launcher.openedUris, isEmpty);
  });

  testWidgets(
    'normal Mi A3 viewport exposes CDA and disclaimer without scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpServices(
        tester,
        activeVehicle: _vehicle(registrationCity: 'Bogotá D. C.'),
        locationGateway: _FakeDeviceLocationGateway.success(
          const DeviceLocationPoint(
            latitude: 6.244203,
            longitude: -75.581212,
            accuracyMeters: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CDA en PicoRadar').hitTestable(), findsOneWidget);
      expect(
        find.textContaining('PicoRadar no presta').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('normal Mi A3 viewport keeps lower actions above shell nav', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá D. C.'),
      locationGateway: _FakeDeviceLocationGateway.success(
        const DeviceLocationPoint(
          latitude: 6.244203,
          longitude: -75.581212,
          accuracyMeters: 18,
        ),
      ),
      bottomOverlayHeight: 92,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('services-open-cda')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.textContaining('PicoRadar no presta').hitTestable(),
      findsOneWidget,
    );
  });

  for (final size in [
    const Size(360, 780),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('services viewport has tappable actions $size/$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final semantics = tester.ensureSemantics();
        try {
          await _pumpServices(
            tester,
            activeVehicle: _vehicle(registrationCity: 'Medellín'),
          );

          for (final entry in [
            ('services-search-tow', 'Buscar grúa 24 horas'),
            ('services-search-battery', 'Buscar batería'),
            ('services-search-tires', 'Buscar llantas'),
            ('services-search-mechanic', 'Buscar taller mecánico'),
            ('services-open-cda', 'Abrir CDA dentro de PicoRadar'),
          ]) {
            final action = find.byKey(ValueKey(entry.$1));
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            final node = tester.getSemantics(find.bySemanticsLabel(entry.$2));
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
              reason: '${entry.$1} must be reachable with accessibility',
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}

Future<void> _pumpServices(
  WidgetTester tester, {
  required VehicleProfile? activeVehicle,
  VoidCallback? onOpenCda,
  ExternalLauncher? externalLauncher,
  DeviceLocationGateway? locationGateway,
  double bottomOverlayHeight = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeVehicleProvider.overrideWithValue(AsyncValue.data(activeVehicle)),
        externalLauncherProvider.overrideWithValue(
          externalLauncher ?? _FakeExternalLauncher(),
        ),
        deviceLocationGatewayProvider.overrideWithValue(
          locationGateway ?? _FakeDeviceLocationGateway.success(),
        ),
        registrationCityCatalogProvider.overrideWithValue(
          const AsyncValue.data(_testRegistrationCatalog),
        ),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        home: bottomOverlayHeight <= 0
            ? ServicesScreen(onOpenCda: onOpenCda)
            : Stack(
                children: [
                  ServicesScreen(onOpenCda: onOpenCda),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bottomOverlayHeight,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ],
              ),
      ),
    ),
  );
  await tester.pump();
}

const _testRegistrationCatalog = RegistrationCityCatalog(
  records: [
    RegistrationCity(
      municipality: 'Bogotá',
      department: 'Bogotá D.C.',
      displayName: 'Bogotá - Bogotá D.C.',
      source: 'test',
    ),
    RegistrationCity(
      municipality: 'Medellín',
      department: 'Antioquia',
      displayName: 'Medellín - Antioquia',
      source: 'test',
    ),
    RegistrationCity(
      municipality: 'Chía',
      department: 'Cundinamarca',
      displayName: 'Chía - Cundinamarca',
      source: 'test',
    ),
  ],
);

VehicleProfile _vehicle({required String? registrationCity}) {
  return VehicleProfile(
    id: 'vehicle-1',
    plate: 'ABC123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    registrationCity: registrationCity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeDeviceLocationGateway implements DeviceLocationGateway {
  _FakeDeviceLocationGateway({
    this.serviceEnabled = true,
    this.checkPermissionResult = DeviceLocationPermission.granted,
    this.requestPermissionResult = DeviceLocationPermission.granted,
    this.positionResult = const DeviceLocationSuccess(
      DeviceLocationPoint(
        latitude: 4.711,
        longitude: -74.0721,
        accuracyMeters: 24,
      ),
    ),
    this.pendingPosition,
  });

  factory _FakeDeviceLocationGateway.success([
    DeviceLocationPoint point = const DeviceLocationPoint(
      latitude: 4.711,
      longitude: -74.0721,
      accuracyMeters: 24,
    ),
  ]) {
    return _FakeDeviceLocationGateway(
      positionResult: DeviceLocationSuccess(point),
    );
  }

  final bool serviceEnabled;
  final DeviceLocationPermission checkPermissionResult;
  final DeviceLocationPermission requestPermissionResult;
  final DeviceLocationResult positionResult;
  final Completer<DeviceLocationResult>? pendingPosition;
  int positionsRequested = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;
  String? throwAt;

  void _checkFailure(String stage) {
    if (throwAt == stage) throw StateError('location unavailable');
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    _checkFailure('service');
    return serviceEnabled;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    _checkFailure('check');
    return checkPermissionResult;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    _checkFailure('request');
    return requestPermissionResult;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() {
    _checkFailure('position');
    positionsRequested++;
    final pending = pendingPosition;
    if (pending != null) {
      return pending.future;
    }
    return Future.value(positionResult);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true});

  final bool openResult;
  final openedUris = <String>[];
  final calledPhones = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return true;
  }

  @override
  Future<bool> openExternal(String uri) async {
    openedUris.add(uri);
    return openResult;
  }
}
