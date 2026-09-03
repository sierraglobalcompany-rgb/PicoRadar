import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/router/app_routes.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/fotomultas/presentation/fotomultas_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

void main() {
  testWidgets('shows loading state while the camera pack resolves', (
    tester,
  ) async {
    final completer = Completer<CameraPack>();
    await _pumpScreen(tester, loader: () => completer.future);

    expect(find.byKey(const ValueKey('fotomultas-loading')), findsOneWidget);
    completer.complete(_pack());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fotomultas-list')), findsOneWidget);
  });

  testWidgets('shows pack error and retries through cameraPackProvider', (
    tester,
  ) async {
    var shouldFail = true;
    var attempts = 0;
    await _pumpScreen(
      tester,
      loader: () {
        attempts += 1;
        if (shouldFail) {
          return Future<CameraPack>.error('pack unavailable');
        }
        return Future.value(_pack());
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar las cámaras.'), findsOneWidget);
    expect(find.text('pack unavailable'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('fotomultas-retry')));
    await tester.pumpAndSettle();

    expect(attempts, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('fotomultas-list')), findsOneWidget);
  });

  testWidgets('calculates summary counts from the provided pack', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('3 cámaras'), findsOneWidget);
    expect(find.text('2 con velocidad reportada'), findsOneWidget);
    expect(find.text('fuente ANSV'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fotomultas-source-date')),
      findsOneWidget,
    );
    expect(
      find.textContaining('no consulta comparendos ni confirma una sanción'),
      findsOneWidget,
    );
  });

  testWidgets('searches by city, address, authority and normalized accents', (
    tester,
  ) async {
    await _pumpScreen(tester);
    final field = find.byKey(const ValueKey('fotomultas-search-field'));

    await tester.enterText(field, 'medellin');
    await tester.pumpAndSettle();
    expect(find.text('CRA 43 A - CL 10'), findsOneWidget);
    expect(find.text('AV CL 80 - CR 98'), findsNothing);

    await tester.enterText(field, 'cl 80');
    await tester.pumpAndSettle();
    expect(find.text('AV CL 80 - CR 98'), findsOneWidget);
    expect(find.text('CRA 43 A - CL 10'), findsNothing);

    await tester.enterText(field, 'secretaria distrital');
    await tester.pumpAndSettle();
    expect(find.text('AV CL 80 - CR 98'), findsOneWidget);

    await tester.enterText(field, 'transito de medellin');
    await tester.pumpAndSettle();
    expect(find.text('CRA 43 A - CL 10'), findsOneWidget);
  });

  testWidgets('filters cameras with and without reported speed', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Con vel.'));
    await tester.pumpAndSettle();

    expect(find.text('Velocidad reportada: 50 km/h'), findsOneWidget);
    expect(find.text('Velocidad reportada: 80 km/h'), findsOneWidget);
    expect(find.text('Velocidad no publicada'), findsNothing);

    await tester.tap(find.text('Sin vel.'));
    await tester.pumpAndSettle();

    expect(find.text('Velocidad no publicada'), findsOneWidget);
    expect(find.text('Velocidad reportada: 50 km/h'), findsNothing);
  });

  testWidgets('shows empty search state', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('fotomultas-search-field')),
      'no existe',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fotomultas-empty-search')),
      findsOneWidget,
    );
    expect(
      find.text('No encontramos cámaras con esa búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('detail with known speed shows available ANSV fields', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(390, 1200));

    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fotomultas-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('AV CL 80 - CR 98'), findsWidgets);
    expect(find.text('BOGOTA D.C · BOGOTA D.C'), findsWidgets);
    expect(find.text('Velocidad reportada por ANSV'), findsOneWidget);
    expect(find.text('Velocidad reportada: 50 km/h'), findsWidgets);
    expect(find.text('Radar Doppler'), findsOneWidget);
    expect(find.text('Fijo'), findsOneWidget);
    expect(find.text('DEI29CAM01'), findsOneWidget);
    expect(find.text('C02, C14'), findsOneWidget);
    expect(find.text('ANSV ubicaciones aprobadas'), findsOneWidget);
  });

  testWidgets('detail without speed omits empty optional fields', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(390, 1200));

    await tester.tap(
      find.byKey(const ValueKey('fotomultas-camera-unknown-bog')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Velocidad no publicada'), findsWidgets);
    expect(find.text('Tecnología'), findsNothing);
    expect(find.text('Tipo de instalación'), findsNothing);
    expect(find.text('Equipo'), findsNothing);
    expect(find.text('Códigos de infracción'), findsNothing);
  });

  testWidgets('source action opens ANSV and reports launcher failure', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, launcher: launcher, size: const Size(390, 1200));

    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-open-source')));
    await tester.pump();

    expect(launcher.openedUris.single, _sourceUrl);

    final failingLauncher = _FakeExternalLauncher(openResult: false);
    await _pumpScreen(
      tester,
      launcher: failingLauncher,
      size: const Size(390, 1200),
    );
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-open-source')));
    await tester.pump();

    expect(find.text('No pudimos abrir la fuente ANSV.'), findsOneWidget);
  });

  testWidgets('main CTA and detail CTA open Conducir', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('fotomultas-open-driving')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-marker')), findsOneWidget);

    await _pumpScreen(tester, size: const Size(390, 1200));
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-detail-open-driving')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-marker')), findsOneWidget);
  });

  testWidgets('detail actions stay above the shell bottom navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpScreenWithBottomNavigation(tester);
    expect(find.byKey(const ValueKey('fotomultas-list')), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 600));

    final bottomNavRect = tester.getRect(
      find.byKey(const ValueKey('app-bottom-navigation')),
    );
    final drivingAction = find.byKey(
      const ValueKey('fotomultas-detail-open-driving'),
    );
    final sourceAction = find.byKey(const ValueKey('fotomultas-open-source'));

    expect(
      find.byKey(const ValueKey('fotomultas-detail-sheet')),
      findsOneWidget,
    );
    expect(drivingAction, findsOneWidget);
    expect(sourceAction, findsOneWidget);
    expect(tester.getRect(drivingAction).bottom, lessThan(bottomNavRect.top));
    expect(tester.getRect(sourceAction).bottom, lessThan(bottomNavRect.top));
    expect(
      tester.hitTestOnBinding(tester.getCenter(drivingAction)).path,
      isNotEmpty,
    );
    expect(
      tester.hitTestOnBinding(tester.getCenter(sourceAction)).path,
      isNotEmpty,
    );
  });

  testWidgets('target phones and text scales render without exceptions', (
    tester,
  ) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(360, 800), 2.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpScreen(tester, size: testCase.$1, textScale: testCase.$2);
      expect(find.text('3 cámaras'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpScreenWithBottomNavigation(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraPackProvider.overrideWith((ref) => Future.value(_pack())),
        externalLauncherProvider.overrideWithValue(_FakeExternalLauncher()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: const FotomultasScreen(),
          bottomNavigationBar: AppBottomNav(
            destinations: [
              for (final tab in AppTab.values)
                AppBottomNavDestination(
                  label: tab.label,
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  color: tab.color,
                  keyName: tab.name,
                ),
            ],
            currentIndex: AppTab.apps.index,
            onSelect: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<CameraPack> Function()? loader,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const FotomultasScreen()),
      GoRoute(
        path: AppRoute.drive.path,
        builder: (context, state) => const _DriveMarker(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraPackProvider.overrideWith((ref) {
          return loader == null ? Future.value(_pack()) : loader();
        }),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
  await tester.pump();
}

CameraPack _pack() {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV ubicaciones aprobadas',
      pageUrl: _sourceUrl,
      dataUrl: _sourceUrl,
      fetchedAtUtc: '2026-08-31T10:44:00-05:00',
    ),
    cameras: [
      _camera(
        id: 'known-bog',
        department: 'BOGOTA D.C',
        municipality: 'BOGOTA D.C',
        address: 'AV CL 80 - CR 98',
        authority: 'SECRETARIA DISTRITAL DE MOVILIDAD',
        speed: 50,
        technology: 'Radar Doppler',
        installationType: 'Fijo',
        equipmentName: 'DEI29CAM01',
        codes: const ['C02', 'C14'],
      ),
      _camera(
        id: 'known-med',
        department: 'ANTIOQUIA',
        municipality: 'MEDELLÍN',
        address: 'CRA 43 A - CL 10',
        authority: 'SECRETARÍA DE TRÁNSITO DE MEDELLÍN',
        speed: 80,
        technology: 'Video Detección',
        installationType: 'Fijo',
        equipmentName: 'MED01',
      ),
      _camera(
        id: 'unknown-bog',
        department: 'BOGOTA D.C',
        municipality: 'BOGOTA D.C',
        address: 'AK 30 - CL 45',
        authority: 'SECRETARIA DISTRITAL DE MOVILIDAD',
      ),
    ],
  );
}

TrafficCamera _camera({
  required String id,
  required String department,
  required String municipality,
  required String address,
  required String authority,
  int? speed,
  String? technology,
  String? installationType,
  String? equipmentName,
  List<String> codes = const [],
}) {
  return TrafficCamera(
    id: id,
    department: department,
    municipality: municipality,
    jurisdiction: 'Distrital',
    address: address,
    latitude: 4.7,
    longitude: -74.1,
    status: 'Aprobada',
    technology: technology,
    kind: CameraKind.mixed,
    speedLimitKmh: speed,
    operationStatus: 'Operando',
    trafficAuthority: authority,
    installationType: installationType,
    equipmentName: equipmentName,
    rawInfractionCodes: codes,
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true});

  final bool openResult;
  final openedUris = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    openedUris.add(uri);
    return openResult;
  }
}

class _DriveMarker extends StatelessWidget {
  const _DriveMarker();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Conducir', key: ValueKey('drive-marker')),
    );
  }
}

const _sourceUrl =
    'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html';
