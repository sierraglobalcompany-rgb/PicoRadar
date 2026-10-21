import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/router/app_routes.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/features/alerts/application/alert_center.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
import 'package:picoradar/features/alerts/platform/alert_alarm_gateway.dart';
import 'package:picoradar/features/alerts/presentation/alerts_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

import '../features/home/presentation/v01b_test_font.dart';
import '../plate_test_fonts.dart';
import '../test_app_harness.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  setUpAll(loadV01bTestFont);

  late TestAppHarness harness;
  late VehicleProfile favorite;
  late VehicleProfile restricted;
  late _EntryNotificationScheduler scheduler;

  setUp(() {
    harness = TestAppHarness()..now = DateTime(2026, 9, 11, 12);
    scheduler = _EntryNotificationScheduler();
  });

  Future<ProviderContainer> openHome(WidgetTester tester) async {
    // Keep serialized storage operations inside the widget test's async zone.
    favorite = await harness.repository.createVehicle(
      plate: 'AAA111',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
    );
    restricted = await harness.repository.createVehicle(
      plate: 'ABC123',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
    );
    await harness.repository.setActiveVehicle(favorite.id);
    return _pumpHome(tester, harness, scheduler);
  }

  tearDown(() async => harness.dispose());

  testWidgets('bottom-bar Home entry reprioritizes exactly once', (
    tester,
  ) async {
    final container = await openHome(tester);
    expect(container.read(homeFocusedVehicleIdProvider), restricted.id);
    expect(container.read(homePriorityEntryProvider), 0);
    await _focusVehicle(tester, container, favorite.id);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();

    expect(container.read(homePriorityEntryProvider), 1);
    expect(container.read(homeFocusedVehicleIdProvider), restricted.id);
    expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();
    expect(container.read(homePriorityEntryProvider), 1);
    expect(tester.takeException(), isNull);
  });

  for (final replaceShell in [false, true]) {
    testWidgets('Garage to Settings (replace=$replaceShell) enters Home once', (
      tester,
    ) async {
      final container = await openHome(tester);
      await _focusVehicle(tester, container, favorite.id);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go(AppRoute.garage.path);
      await tester.pumpAndSettle();
      expect(_branchIndex(tester), AppTab.garage.index);
      if (replaceShell) {
        router.go(AppRoute.settings.path);
      } else {
        router.push(AppRoute.settings.path);
      }
      await tester.pumpAndSettle();
      if (replaceShell) {
        expect(find.byType(AppShell, skipOffstage: false), findsNothing);
      }

      final configure = find.byKey(
        const ValueKey('settings-go-home-notifications'),
      );
      await tester.ensureVisible(configure);
      await tester.tap(configure);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home/alerts');
      expect(find.byType(AlertsScreen), findsOneWidget);
      final alerts = await container.read(alertCenterProvider.future);
      expect(alerts.permissionsKnown, isTrue);
      expect(alerts.permission, isTrue);
      expect(alerts.alarmFailureMessage, isNull);
      expect(find.text('Notificaciones permitidas'), findsOneWidget);
      expect(find.text('Permisos sin confirmar'), findsNothing);
      expect(alerts.rows, hasLength(8));
      expect(
        alerts.rows.map((row) => row.category).toSet(),
        AlertCategory.values.toSet(),
      );
      expect(scheduler.permissionRequests, 0);
      expect(_branchIndex(tester), AppTab.home.index);
      expect(container.read(homePriorityEntryProvider), 1);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(homePriorityEntryProvider), 1);
      expect(container.read(homeFocusedVehicleIdProvider), restricted.id);
      expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home root-route replacement preserves its manual focus', (
    tester,
  ) async {
    final container = await openHome(tester);
    await _focusVehicle(tester, container, favorite.id);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go(AppRoute.settings.path);
    await tester.pumpAndSettle();
    expect(find.byType(AppShell, skipOffstage: false), findsNothing);
    final configure = find.byKey(
      const ValueKey('settings-go-home-notifications'),
    );
    await tester.ensureVisible(configure);
    await tester.tap(configure);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home/alerts');
    expect(find.byType(AlertsScreen), findsOneWidget);
    expect(find.text('Notificaciones permitidas'), findsOneWidget);
    expect(find.text('Permisos sin confirmar'), findsNothing);
    expect(scheduler.permissionRequests, 0);
    expect(container.read(homePriorityEntryProvider), 0);
    expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(homePriorityEntryProvider), 0);
    expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-branch detail push and pop preserve manual Home focus', (
    tester,
  ) async {
    final container = await openHome(tester);
    await _focusVehicle(tester, container, favorite.id);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push('${AppRoute.garage.path}/vehicle/${favorite.id}');
    await tester.pumpAndSettle();
    expect(_branchIndex(tester), AppTab.home.index);
    router.pop();
    await tester.pumpAndSettle();

    expect(container.read(homePriorityEntryProvider), 0);
    expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('minute updates and Apps overlay do not request Home priority', (
    tester,
  ) async {
    final container = await openHome(tester);
    await _focusVehicle(tester, container, favorite.id);
    for (var minute = 0; minute < 3; minute++) {
      harness.now = harness.now.add(const Duration(minutes: 1));
      container.invalidate(bogotaNowProvider);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(container.read(homePriorityEntryProvider), 0);
      expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    }
    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();
    expect(container.read(homePriorityEntryProvider), 0);
    expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    expect(tester.takeException(), isNull);
  });
}

int _branchIndex(WidgetTester tester) =>
    tester.widget<AppShell>(find.byType(AppShell)).navigationShell.currentIndex;

Future<void> _focusVehicle(
  WidgetTester tester,
  ProviderContainer container,
  String vehicleId,
) async {
  final vehicles = container.read(vehicleListProvider).requireValue;
  final focusedId = container.read(homeFocusedVehicleIdProvider);
  final from = vehicles.indexWhere((vehicle) => vehicle.id == focusedId);
  final to = vehicles.indexWhere((vehicle) => vehicle.id == vehicleId);
  expect(from, isNonNegative);
  expect(to, isNonNegative);
  await tester.fling(
    find.byKey(const ValueKey('home-vehicle-page-view')),
    Offset(to > from ? -600 : 600, 0),
    1200,
  );
  await tester.pumpAndSettle();
  expect(container.read(homeFocusedVehicleIdProvider), vehicleId);
}

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  TestAppHarness harness,
  _EntryNotificationScheduler scheduler,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('co.picoradar.app/widget'),
        (_) async => null,
      );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/widget'),
          null,
        );
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        tripMunicipalityCatalogProvider.overrideWithValue(
          AsyncValue.data(TestAppHarness.tripCatalog),
        ),
        registrationCityCatalogProvider.overrideWithValue(
          AsyncValue.data(TestAppHarness.registrationCatalog),
        ),
        currentInstantProvider.overrideWithValue(harness.now.toUtc()),
        startupReadinessProvider.overrideWith(
          (ref) async => const StartupReadiness(
            imageAssets: [],
            vehicleCount: 0,
            selectedJurisdictionId: null,
          ),
        ),
        picoNotificationSchedulerProvider.overrideWithValue(scheduler),
        alarmGatewayProvider.overrideWithValue(const _NoAlarmGateway()),
        bogotaNowProvider.overrideWith((ref) => harness.now),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        restrictionJurisdictionsProvider.overrideWith(
          (ref) async => const [
            RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
          ],
        ),
        selectedPicoJurisdictionIdProvider.overrideWith(
          (ref) async => 'co-ant-medellin',
        ),
        homeVehicleSnapshotsProvider.overrideWith(
          (ref, request) async => [
            for (final vehicle in request.vehicles)
              HomeVehicleSnapshot(
                vehicle: vehicle,
                today: RestrictionDayEvaluation(
                  status: vehicle.plate == 'ABC123'
                      ? RestrictionDayStatus.restricted
                      : RestrictionDayStatus.allowed,
                  effectiveWindows: vehicle.plate == 'ABC123'
                      ? const [
                          RestrictionDayWindow(
                            startMinute: 300,
                            endMinute: 1200,
                          ),
                        ]
                      : const [],
                ),
              ),
          ],
        ),
      ],
      child: const PicoRadarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

class _NoAlarmGateway extends AlertAlarmGateway {
  const _NoAlarmGateway();

  @override
  Future<AlarmStatus> status() async =>
      const AlarmStatus(testState: AlarmTestState.idle);

  @override
  Future<AlarmCapabilities> capabilities() async => const AlarmCapabilities();

  @override
  Future<void> requestPermissions() async =>
      throw StateError('Alarm permission must not be requested implicitly.');
}

class _EntryNotificationScheduler extends PicoNotificationScheduler {
  int permissionRequests = 0;

  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool?> areNotificationsEnabled() async => true;
  @override
  Future<Set<int>> pendingIds() async => {};
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
