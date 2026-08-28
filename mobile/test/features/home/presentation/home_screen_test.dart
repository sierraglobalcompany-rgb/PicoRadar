import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  group('Home V2 shell states', () {
    testWidgets('no vehicle keeps the branded header and R01 empty state', (
      tester,
    ) async {
      await _pumpHome(tester, harness);

      expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-empty-state')), findsOneWidget);
      expect(find.text('No tienes vehículos todavía'), findsOneWidget);
      expect(find.text('Agregar vehículo'), findsOneWidget);
    });

    testWidgets('vehicle without city remains Home V2 and fails closed', (
      tester,
    ) async {
      await _createVehicle(harness, plate: 'ABC123');

      await _pumpHome(tester, harness);

      expect(
        find.byKey(const ValueKey('home-vehicle-carousel')),
        findsOneWidget,
      );
      expect(find.text('Selecciona dónde vas a conducir'), findsOneWidget);
      expect(find.text('Sin confirmar'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);
    });

    testWidgets('one vehicle hides the counter and renders the status grid', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.byKey(const ValueKey('home-carousel-counter')), findsNothing);
      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
      expect(find.text('SOAT'), findsOneWidget);
      expect(find.text('Tecnomecánica'), findsOneWidget);
      expect(find.text('Comparendos'), findsOneWidget);
    });

    testWidgets('three vehicles use PageView without auto advance', (
      tester,
    ) async {
      await _createVehicle(harness, plate: 'AAA111');
      await _createVehicle(
        harness,
        plate: 'ABC124',
        nickname: 'Familiar',
        brand: 'Marca local',
        model: 'Modelo QA',
        year: 2026,
      );
      await _createVehicle(
        harness,
        plate: 'MOT07A',
        kind: VehicleKind.motorcycle,
        nickname: 'Moto QA',
      );
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHome(tester, harness);
      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('home-vehicle-page-view')),
      );

      expect(pageView.controller?.viewportFraction, closeTo(0.78, 0.001));
      expect(pageView.pageSnapping, isTrue);
      expect(
        find.byKey(const ValueKey('home-carousel-counter')),
        findsOneWidget,
      );
      expect(find.text('1 de 3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('1 de 3'), findsOneWidget);
    });
  });

  group('Home V2 priority and focus', () {
    test('active restricted starts active', () {
      final active = _snapshot('active', RestrictionDayStatus.restricted);
      final other = _snapshot('other', RestrictionDayStatus.restricted);

      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [other, active],
          activeVehicleId: 'active',
        ),
        1,
      );
    });

    test('non-active restricted starts restricted', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('active', RestrictionDayStatus.allowed),
            _snapshot('restricted', RestrictionDayStatus.restricted),
          ],
          activeVehicleId: 'active',
        ),
        1,
      );
    });

    test('multiple restricted without active uses deterministic first', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('first', RestrictionDayStatus.restricted),
            _snapshot('second', RestrictionDayStatus.restricted),
          ],
          activeVehicleId: 'missing',
        ),
        0,
      );
    });

    test('none restricted starts active or first fallback', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('first', RestrictionDayStatus.allowed),
            _snapshot('active', RestrictionDayStatus.allowed),
          ],
          activeVehicleId: 'active',
        ),
        1,
      );
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [_snapshot('first', RestrictionDayStatus.allowed)],
          activeVehicleId: null,
        ),
        0,
      );
    });

    test('stale and unknown are not prioritized as restricted', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('stale', RestrictionDayStatus.stale),
            _snapshot('active', RestrictionDayStatus.allowed),
          ],
          activeVehicleId: 'active',
        ),
        1,
      );
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('unknown', RestrictionDayStatus.unknown),
            _snapshot('active', RestrictionDayStatus.allowed),
          ],
          activeVehicleId: 'active',
        ),
        1,
      );
    });

    testWidgets('swipe changes focused vehicle and lower cards follow it', (
      tester,
    ) async {
      final second = await _createVehicle(harness, plate: 'ABC124');
      final active = await _createVehicle(harness, plate: 'AAA111');
      await _setVehicleCreatedAt(harness, second.id, DateTime.utc(2026, 8, 1));
      await _setVehicleCreatedAt(harness, active.id, DateTime.utc(2026, 8, 2));
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: second.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 26),
      );
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHome(tester, harness);
      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));

      await tester.fling(
        find.byKey(const ValueKey('home-vehicle-page-view')),
        const Offset(-600, 0),
        1200,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.text('30 días'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('card tap opens that vehicle detail without mutating active', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      final restricted = await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHomeApp(tester, harness);
      expect(find.text('ABC123'), findsOneWidget);
      await tester.tap(find.text('ABC123'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('detail-${restricted.id}'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('start driving promotes focused vehicle only by explicit CTA', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      final restricted = await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHomeApp(tester, harness);
      expect(find.text('Pico y placa hoy'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);

      await tester.ensureVisible(
        find.byKey(const ValueKey('home-start-driving')),
      );
      await tester.pump();
      await tester.tap(find.text('Iniciar conducción'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('drive'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, restricted.id);
    });
  });

  group('Home V2 data truth', () {
    testWidgets('SOAT and RTM missing show Sin configurar', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));
      expect(find.text('0 pendientes'), findsNothing);
      expect(find.text('Consultar'), findsOneWidget);
    });

    testWidgets('real SOAT and RTM due dates derive summaries', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      final store = VehicleObligationStore(harness.database);
      await store.upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 26),
      );
      await store.upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.rtm,
        dueDate: DateTime(2026, 12, 31),
      );

      await _pumpHome(tester, harness);

      expect(find.text('30 días'), findsOneWidget);
      expect(find.text('126 días'), findsOneWidget);
      expect(find.text('Vence pronto según la fecha guardada'), findsOneWidget);
      expect(find.text('Vigente según la fecha guardada'), findsOneWidget);
    });

    testWidgets('stale and unknown restrictions never render green allowed', (
      tester,
    ) async {
      harness.now = DateTime(2027, 1, 2);
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Datos pendientes'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);

      harness = TestAppHarness();
      await _readyHome(
        harness,
        plate: 'TAX123',
        serviceType: VehicleServiceType.taxi,
      );
      await _pumpHome(tester, harness);

      expect(find.text('Sin confirmar'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);
    });

    testWidgets('banner copy is truthful and does not mention Protect', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Más control, más tranquilidad.'), findsOneWidget);
      expect(
        find.textContaining('Próximamente nuevas funciones'),
        findsOneWidget,
      );
      expect(find.textContaining('PicoRadar Protect'), findsNothing);
    });
  });

  group('Home V2 notifications and accessibility', () {
    testWidgets('bell opens explicit notification activation sheet', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);
      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('home-notification-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsOneWidget,
      );
    });

    testWidgets('denied notification permission does not re-prompt', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await savePicoAlertPreferences(
        harness.preferences,
        const PicoAlertPreferences(
          enabled: true,
          dayBeforeEnabled: true,
          sameDayEnabled: true,
          dayBeforeMinute: 19 * 60,
          sameDayMinute: 5 * 60,
          permissionRequested: true,
          permissionGranted: false,
        ),
      );

      await _pumpHome(tester, harness);
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsNothing,
      );
      expect(
        find.textContaining('Permiso de notificaciones desactivado'),
        findsOneWidget,
      );
    });

    testWidgets(
      'granted notification settings remain available in bell sheet',
      (tester) async {
        await _readyHome(harness, plate: 'ABC124');
        await savePicoAlertPreferences(
          harness.preferences,
          const PicoAlertPreferences(
            enabled: true,
            dayBeforeEnabled: true,
            sameDayEnabled: true,
            dayBeforeMinute: 19 * 60,
            sameDayMinute: 5 * 60,
            permissionRequested: true,
            permissionGranted: true,
          ),
        );

        await _pumpHome(tester, harness);
        await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Recordatorios habilitados'), findsOneWidget);
        expect(find.text('Día anterior'), findsOneWidget);
        expect(find.text('Hora día anterior'), findsOneWidget);
        expect(find.text('19:00'), findsOneWidget);
        expect(find.text('Mismo día'), findsOneWidget);
        expect(find.text('Hora mismo día'), findsOneWidget);
        expect(find.text('05:00'), findsOneWidget);
      },
    );

    testWidgets('alert preference toggle is saved from the bell sheet', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await savePicoAlertPreferences(
        harness.preferences,
        const PicoAlertPreferences(
          enabled: true,
          dayBeforeEnabled: true,
          sameDayEnabled: true,
          dayBeforeMinute: 19 * 60,
          sameDayMinute: 5 * 60,
          permissionRequested: true,
          permissionGranted: true,
        ),
      );

      await _pumpHome(tester, harness);
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.ensureVisible(
        find.byKey(const ValueKey('pico-alerts-enabled')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pico-alerts-enabled')));
      await tester.pump();

      final loaded = await loadPicoAlertPreferences(harness.preferences);
      expect(loaded.enabled, isFalse);
      expect(loaded.permissionRequested, isTrue);
      expect(loaded.permissionGranted, isTrue);
    });

    testWidgets('reduced motion keeps restricted state readable', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC123');

      await _pumpHome(
        tester,
        harness,
        wrap: (child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      );

      expect(find.text('Pico y placa hoy'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    });
  });

  group('Home V2 viewport QA', () {
    final cases = <({String name, Size size, double textScale})>[
      (name: '360x800', size: Size(360, 800), textScale: 1),
      (name: '390x844', size: Size(390, 844), textScale: 1),
      (name: '412x915', size: Size(412, 915), textScale: 1),
      (name: '390x844 textScale 1.5', size: Size(390, 844), textScale: 1.5),
      (name: '390x844 textScale 2.0', size: Size(390, 844), textScale: 2),
      (name: '844x390 landscape', size: Size(844, 390), textScale: 1),
    ];

    for (final viewport in cases) {
      testWidgets('renders without layout exceptions at ${viewport.name}', (
        tester,
      ) async {
        await _readyHome(harness, plate: 'ABC124');

        await _pumpHome(
          tester,
          harness,
          viewportSize: viewport.size,
          textScaleFactor: viewport.textScale,
        );

        expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-vehicle-carousel')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Pico detail continuity', () {
    testWidgets('pico detail shows próximos 7 días', (tester) async {
      await _readyHome(
        harness,
        plate: 'TAX078',
        serviceType: VehicleServiceType.taxi,
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness);

      expect(find.text('Próximos 7 días'), findsOneWidget);
      expect(find.text('Fuente oficial: bogota.gov.co'), findsOneWidget);
    });

    testWidgets('pico detail does not show allowed after staleAfter', (
      tester,
    ) async {
      harness.now = DateTime(2026, 8, 31, 7);
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness);

      expect(find.text('Datos desactualizados'), findsWidgets);
      expect(find.text('Puedes circular'), findsNothing);
    });
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  TestAppHarness harness, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget Function(Widget child)? wrap,
}) async {
  await _pump(
    tester,
    harness,
    const Scaffold(body: HomeScreen()),
    viewportSize: viewportSize,
    textScaleFactor: textScaleFactor,
    wrap: wrap,
  );
}

Future<void> _pumpDetail(WidgetTester tester, TestAppHarness harness) async {
  await _pump(tester, harness, const PicoDetailScreen());
}

Future<void> _pumpHomeApp(WidgetTester tester, TestAppHarness harness) async {
  await _installWidgetChannelMock(tester, harness);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/garage/vehicle/:id',
        builder: (context, state) =>
            Text('detail-${state.pathParameters['id']}'),
      ),
      GoRoute(path: '/drive', builder: (context, state) => const Text('drive')),
      GoRoute(
        path: '/apps/module/:id',
        builder: (context, state) => Text(
          'module-${state.pathParameters['id']}-${state.uri.queryParameters['vehicleId']}',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _providerScope(
      harness,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await _pumpAsyncHome(tester);
}

Future<void> _pump(
  WidgetTester tester,
  TestAppHarness harness,
  Widget child, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget Function(Widget child)? wrap,
}) async {
  await _installWidgetChannelMock(tester, harness, viewportSize: viewportSize);
  if (textScaleFactor != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final app = _providerScope(harness, child: MaterialApp(home: child));
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await _pumpAsyncHome(tester);
}

Widget _providerScope(TestAppHarness harness, {required Widget child}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(harness.database),
      appPreferencesProvider.overrideWithValue(harness.preferences),
      bundledRestrictionsProvider.overrideWith((ref) async {}),
      restrictionJurisdictionsProvider.overrideWith(
        (ref) async => _jurisdictions,
      ),
      restrictionStoreProvider.overrideWithValue(
        _FakeRestrictionStore(harness.database, harness.now),
      ),
      picoNotificationSchedulerProvider.overrideWithValue(
        _FakePicoNotificationScheduler(),
      ),
      bogotaNowProvider.overrideWithValue(harness.now),
      currentInstantProvider.overrideWithValue(harness.now.toUtc()),
    ],
    child: child,
  );
}

Future<void> _installWidgetChannelMock(
  WidgetTester tester,
  TestAppHarness harness, {
  Size viewportSize = _defaultViewportSize,
}) async {
  _configureMobileViewport(tester, viewportSize);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('co.picoradar.app/widget'),
        (_) async => null,
      );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/widget'),
          null,
        );
  });
}

const _defaultViewportSize = Size(390, 844);

void _configureMobileViewport(WidgetTester tester, Size viewportSize) {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpAsyncHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<VehicleProfile> _readyHome(
  TestAppHarness harness, {
  required String plate,
  String jurisdictionId = 'co-ant-medellin',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) async {
  final vehicle = await _createVehicle(
    harness,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
  );
  await harness.repository.setActiveVehicle(vehicle.id);
  await harness.preferences.setString(
    picoJurisdictionPreferenceKey,
    jurisdictionId,
  );
  return vehicle;
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? nickname,
  String? brand,
  String? model,
  int? year,
}) async {
  return harness.repository.createVehicle(
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    nickname: nickname,
    registrationCity: 'Bogota',
    brand: brand,
    model: model,
    year: year,
  );
}

Future<void> _setVehicleCreatedAt(
  TestAppHarness harness,
  String vehicleId,
  DateTime createdAt,
) async {
  await (harness.database.update(
    harness.database.vehicles,
  )..where((row) => row.id.equals(vehicleId))).write(
    VehiclesCompanion(createdAt: Value(createdAt), updatedAt: Value(createdAt)),
  );
}

HomeVehicleSnapshot _snapshot(String id, RestrictionDayStatus status) {
  return HomeVehicleSnapshot(
    vehicle: VehicleProfile(
      id: id,
      plate: id.toUpperCase().padRight(6, '1').substring(0, 6),
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    today: RestrictionDayEvaluation(status: status, effectiveWindows: const []),
    tomorrow: const RestrictionDayEvaluation(
      status: RestrictionDayStatus.allowed,
      effectiveWindows: [],
    ),
  );
}

const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
];

class _FakeRestrictionStore extends RestrictionStore {
  _FakeRestrictionStore(super.database, this.now);

  final DateTime now;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    if (jurisdictionId == 'co-ant-medellin' &&
        serviceType == VehicleServiceType.taxi) {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }

    final staleAfter = jurisdictionId == 'co-ant-medellin'
        ? DateTime.utc(2027, 1, 1, 5)
        : DateTime.utc(2026, 9, 1, 5);
    final stale = jurisdictionId == 'co-ant-medellin'
        ? this.now.isAfter(DateTime(2026, 12, 31, 23, 59))
        : this.now.isAfter(DateTime(2026, 8, 31, 23, 59));
    if (jurisdictionId == 'co-ant-medellin') {
      return RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: stale,
        staleAfter: staleAfter,
        rules: [
          _rule(
            id: 'medellin-particular-thursday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.thursday},
            digitPosition: vehicleKind == VehicleKind.motorcycle
                ? RestrictionDigitPosition.firstNumeric
                : RestrictionDigitPosition.lastNumeric,
            digits: {3},
          ),
        ],
        verifiedAt: DateTime(2026, 8, 1),
        sourceUrls: const ['https://www.medellin.gov.co/source'],
      );
    }

    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: stale,
      staleAfter: staleAfter,
      rules: [
        _rule(
          id: 'bogota-private-monday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          weekdays: {DateTime.monday},
          digits: {3},
          appliesOnHolidays: false,
        ),
        _rule(
          id: 'bogota-private-thursday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          weekdays: {DateTime.thursday},
          digits: {3},
          appliesOnHolidays: false,
        ),
        _rule(
          id: 'bogota-taxi-thursday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.thursday},
          digits: {5, 6},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
        _rule(
          id: 'bogota-taxi-friday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.friday},
          digits: {7, 8},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
      ],
      verifiedAt: DateTime(2026, 8, 1),
      sourceUrls: const ['https://bogota.gov.co/source'],
    );
  }
}

RestrictionRule _rule({
  required String id,
  required String jurisdictionId,
  required Set<VehicleKind> vehicleKinds,
  required Set<VehicleServiceType> serviceTypes,
  required Set<int> weekdays,
  required Set<int> digits,
  RestrictionDigitPosition digitPosition = RestrictionDigitPosition.lastNumeric,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 1260),
  ],
  bool appliesOnHolidays = true,
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: jurisdictionId,
    priority: 100,
    effect: RestrictionEffect.restrict,
    validFrom: DateTime(2026, 8),
    validUntil: DateTime(2026, 12, 31, 23, 59, 59),
    vehicleKinds: vehicleKinds,
    serviceTypes: serviceTypes,
    weekdays: weekdays,
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: timeWindows,
    appliesOnHolidays: appliesOnHolidays,
  );
}

class _FakePicoNotificationScheduler extends PicoNotificationScheduler {
  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<void> reschedule(List<PicoNotificationPlan> plans) async {}

  @override
  Future<void> cancelPicoNotifications() async {}

  @override
  Future<void> rescheduleObligationNotifications(
    List<ObligationNotificationPlan> plans,
  ) async {}

  @override
  Future<void> cancelObligationNotifications() async {}
}
