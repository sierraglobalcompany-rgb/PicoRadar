import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_detail_screen.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_preferences.dart';

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

    testWidgets('location card is compact and does not prompt on startup', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.notRequested;
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      final locationCard = find.byKey(const ValueKey('home-location-card'));
      expect(locationCard, findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Bogotá'), findsOneWidget);
      final locationSize = tester.getSize(locationCard);
      expect(locationSize.height, 54);
      expect(locationSize.width, lessThan(390 * 0.72));
      expect(locationSize.width, greaterThan(390 * 0.60));
      expect(
        tester.getTopLeft(locationCard).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('home-vehicle-carousel')))
              .dy,
        ),
      );
      expect(gateway.checkPermissionCalls, 0);
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 0);
    });

    testWidgets('location card stays compact at small phone width', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, viewportSize: const Size(360, 800));

      final locationSize = tester.getSize(
        find.byKey(const ValueKey('home-location-card')),
      );
      expect(locationSize.height, 54);
      expect(locationSize.width, lessThan(360 * 0.72));
      expect(locationSize.width, greaterThan(360 * 0.60));
    });

    testWidgets('location sheet switches manual jurisdiction from Home', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await _pumpHome(tester, harness);

      await tester.tap(find.byKey(const ValueKey('home-location-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jurisdiction-co-dc-bogota')));
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
      expect(
        await harness.preferences.getString(locationModePreferenceKey),
        'manual',
      );
    });

    testWidgets('location sheet GPS auto does one-shot foreground detection', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      await tester.tap(find.byKey(const ValueKey('home-location-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-gps-auto-option')));
      await tester.pumpAndSettle();

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 1);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
      expect(
        await harness.preferences.getString(locationModePreferenceKey),
        'gpsAuto',
      );
      final gpsCardSize = tester.getSize(
        find.byKey(const ValueKey('home-location-card')),
      );
      expect(gpsCardSize.height, 54);
      expect(gpsCardSize.width, lessThan(390 * 0.72));
      expect(find.text('GPS activo'), findsOneWidget);
    });

    testWidgets('resume TTL refresh does not request permission implicitly', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 1);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
    });

    testWidgets('one vehicle hides the counter and renders the status grid', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
      );
      await harness.preferences.setString(
        selectedAvatarPreferenceKey,
        'avatar_003',
      );

      await _pumpHome(tester, harness);

      expect(
        find.byKey(const ValueKey('home-avatar-image-avatar_003')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('vehicle-visual-image-${vehicle.id}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-carousel-counter')), findsNothing);
      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
      expect(find.text('SOAT'), findsOneWidget);
      expect(find.text('Tecnomecánica'), findsOneWidget);
      expect(find.text('Comparendos'), findsNothing);
    });

    testWidgets('standard viewport renders compact status IA', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness, viewportSize: const Size(390, 844));

      final tomorrow = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-tomorrow')),
      );
      final soat = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-soat')),
      );
      final rtm = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-rtm')),
      );
      final tomorrowBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-status-tomorrow')),
      );

      expect(tomorrow.dx, lessThanOrEqualTo(soat.dx));
      expect(soat.dy, greaterThan(tomorrowBottom.dy));
      expect((soat.dy - rtm.dy).abs(), lessThan(1));
      expect(rtm.dx, greaterThan(soat.dx));
      expect(
        find.byKey(const ValueKey('home-status-comparendos')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-status-tomorrow')),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('compact top bar removes greeting copy', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness, viewportSize: const Size(390, 844));

      expect(
        find.byKey(const ValueKey('home-compact-top-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-user-controls-capsule')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-avatar-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-notification-bell')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('home-compact-top-bar')))
            .height,
        56,
      );
      expect(find.text('¡Hola!'), findsNothing);
      expect(find.text('Así están tus vehículos hoy'), findsNothing);
    });

    testWidgets('standard viewport does not ellipsize primary status text', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC126');

      await _pumpHome(tester, harness, viewportSize: const Size(360, 800));

      _expectNoEllipsisInCard(tester, const ValueKey('home-status-tomorrow'), [
        'MAÑANA',
        'Puede circular',
      ]);
      _expectNoEllipsisInCard(tester, const ValueKey('home-status-soat'), [
        'SOAT',
        'Sin configurar',
      ]);
      _expectNoEllipsisInCard(tester, const ValueKey('home-status-rtm'), [
        'Tecnomecánica',
        'Sin configurar',
      ]);
    });

    testWidgets('390x844 keeps essential Home content above bottom nav', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(
        tester,
        harness,
        viewportSize: const Size(390, 844),
        bottomNavigationBar: const SizedBox(
          key: ValueKey('test-bottom-nav-budget'),
          height: 96,
        ),
      );

      final bannerBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-bottom-banner-slot')),
      );

      expect(bannerBottom.dy, lessThanOrEqualTo(844 - 96));
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x800 keeps essential Home content above bottom nav', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(
        tester,
        harness,
        viewportSize: const Size(360, 800),
        bottomNavigationBar: const SizedBox(
          key: ValueKey('test-bottom-nav-budget'),
          height: 96,
        ),
      );

      final bannerBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-bottom-banner-slot')),
      );

      expect(bannerBottom.dy, lessThanOrEqualTo(800 - 96));
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avatar picker selects locally and persists after restart', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await _pumpHome(tester, harness);

      await tester.ensureVisible(
        find.byKey(const ValueKey('home-avatar-button')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-avatar-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('avatar-picker-grid')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('avatar-option-avatar_004')));
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(selectedAvatarPreferenceKey),
        'avatar_004',
      );

      await _pumpHome(tester, harness);
      expect(
        find.byKey(const ValueKey('home-avatar-image-avatar_004')),
        findsOneWidget,
      );
    });

    testWidgets('vehicle detail picker stores override and auto reset', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
      );
      await _pumpHomeApp(tester, harness);

      await tester.tap(find.byKey(ValueKey('home-vehicle-card-${vehicle.id}')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vehicle-visual-picker-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vehicle-visual-option-veh_car_toyota_01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vehicle-visual-option-veh_moto_yamaha_01')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('vehicle-visual-option-veh_car_toyota_01')),
      );
      await tester.pumpAndSettle();
      expect(
        await harness.preferences.getString(
          vehicleVisualPreferenceKey(vehicle.id),
        ),
        'veh_car_toyota_01',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('vehicle-visual-auto-option')),
      );
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(
          vehicleVisualPreferenceKey(vehicle.id),
        ),
        isNull,
      );
    });

    testWidgets('three vehicles center restricted card without auto advance', (
      tester,
    ) async {
      await _createVehicle(harness, plate: 'AAA111');
      await _createVehicle(
        harness,
        plate: 'TST453',
        nickname: 'Familiar',
        year: 2026,
      );
      await _createVehicle(
        harness,
        plate: 'MOT789',
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

      expect(pageView.controller?.viewportFraction, closeTo(0.64, 0.001));
      expect(pageView.pageSnapping, isTrue);
      expect(
        find.byKey(const ValueKey('home-carousel-counter')),
        findsOneWidget,
      );
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-2')), findsOneWidget);
      expect(find.text('TST453'), findsOneWidget);
      expect(find.text('Hoy no puedes circular'), findsOneWidget);
      final restrictedSummary = tester.widget<Text>(
        find.text('Hoy no puedes circular'),
      );
      expect(restrictedSummary.overflow, isNot(TextOverflow.ellipsis));

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('2 de 3'), findsOneWidget);
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

    testWidgets('unrelated rebuild keeps Home snapshots visible', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);
      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);

      await tester.pump();

      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-vehicle-carousel')),
        findsOneWidget,
      );
      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));
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

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(find.text(restricted.plate), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('Conducir tab promotes focused vehicle from Home only', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      final restricted = await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpFullHomeApp(tester, harness);
      expect(find.text('Pico y placa hoy'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);

      await tester.tap(find.byKey(const ValueKey('tab-drive')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.text('Modo de conduccion de alta concentracion.'),
        findsOneWidget,
      );
      expect((await harness.repository.getActiveVehicle())?.id, restricted.id);
    });

    testWidgets('Conducir from another tab keeps the global active vehicle', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpFullHomeApp(tester, harness);
      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('tab-drive')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.text('Modo de conduccion de alta concentracion.'),
        findsOneWidget,
      );
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });
  });

  group('Home V2 data truth', () {
    testWidgets('SOAT and RTM missing show Sin configurar', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));
      expect(find.text('0 pendientes'), findsNothing);
      expect(find.text('Consultar'), findsNothing);
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

    testWidgets('promo and C14 card stay out of compact Home', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Más control, más tranquilidad.'), findsNothing);
      expect(
        find.textContaining('Próximamente nuevas funciones'),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-status-comparendos')),
        findsNothing,
      );
      expect(find.textContaining('PicoRadar Protect'), findsNothing);
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
    });
  });

  group('Home V2 module tap reliability', () {
    testWidgets('Tomorrow sends active taxi to Pico without mutating active', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX125',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
        year: 2022,
      );
      final toyota = await _createVehicle(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
        year: 2023,
      );
      final renault = await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
        year: 2024,
      );
      await _setVehicleCreatedAt(
        harness,
        activeTaxi.id,
        DateTime.utc(2026, 8, 3),
      );
      await _setVehicleCreatedAt(harness, toyota.id, DateTime.utc(2026, 8, 2));
      await _setVehicleCreatedAt(harness, renault.id, DateTime.utc(2026, 8, 1));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await _openTomorrowAndExpectPico(tester, activeTaxi);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('Tomorrow, SOAT and RTM use focused non-active vehicle', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
        year: 2022,
      );
      final toyota = await _createVehicle(
        harness,
        plate: 'ABC123',
        brand: 'Toyota',
        year: 2023,
      );
      await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
        year: 2024,
      );
      await _setVehicleCreatedAt(
        harness,
        activeTaxi.id,
        DateTime.utc(2026, 8, 3),
      );
      await _setVehicleCreatedAt(harness, toyota.id, DateTime.utc(2026, 8, 2));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await tester.tap(find.byKey(const ValueKey('home-status-soat')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('module-soat-${toyota.id}'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);

      await _goHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-status-rtm')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('module-tecnomecanica-${toyota.id}'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);

      await _goHome(tester);
      await _openTomorrowAndExpectPico(tester, toyota);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('Tomorrow can target a third focused vehicle', (tester) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
      );
      await _createVehicle(harness, plate: 'ABC124', brand: 'Toyota');
      final renault = await _createVehicle(
        harness,
        plate: 'REN123',
        brand: 'Renault',
      );
      await _setVehicleCreatedAt(harness, renault.id, DateTime.utc(2026, 8, 3));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await _openTomorrowAndExpectPico(tester, renault);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('explicit Pico vehicle uses third vehicle directly', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
      );
      await _createVehicle(harness, plate: 'ABC124', brand: 'Toyota');
      final renault = await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
      );
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: renault.id);

      expect(find.text('Próximos 7 días'), findsOneWidget);
      expect(find.text(renault.plate), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets(
      'Home focused vehicle still promotes to active only through Conducir',
      (tester) async {
        final activeTaxi = await _createVehicle(
          harness,
          plate: 'TAX129',
          serviceType: VehicleServiceType.taxi,
        );
        final focused = await _createVehicle(
          harness,
          plate: 'ABC123',
          brand: 'Toyota',
        );
        await harness.repository.setActiveVehicle(activeTaxi.id);
        await harness.preferences.setString(
          picoJurisdictionPreferenceKey,
          'co-dc-bogota',
        );

        await _pumpFullHomeApp(tester, harness);
        expect(
          (await harness.repository.getActiveVehicle())?.id,
          activeTaxi.id,
        );

        await tester.tap(find.byKey(const ValueKey('tab-drive')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect((await harness.repository.getActiveVehicle())?.id, focused.id);
      },
    );

    testWidgets('Tomorrow card routes consistently to Pico detail', (
      tester,
    ) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (var i = 0; i < 5; i += 1) {
        await tester.tap(find.byKey(const ValueKey('home-status-tomorrow')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Próximos 7 días'), findsOneWidget);
        expect(find.text(vehicle.plate), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('Próximos 7 días')),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
    });

    testWidgets('SOAT card routes consistently', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (var i = 0; i < 10; i += 1) {
        await tester.tap(find.byKey(const ValueKey('home-status-soat')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('module-soat-${vehicle.id}'), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('module-soat-${vehicle.id}')),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
    });

    testWidgets('RTM card routes consistently', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (var i = 0; i < 10; i += 1) {
        await tester.tap(find.byKey(const ValueKey('home-status-rtm')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('module-tecnomecanica-${vehicle.id}'), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('module-tecnomecanica-${vehicle.id}')),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
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
          find.byKey(const ValueKey('home-user-controls-capsule')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-vehicle-carousel')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-bottom-banner-slot')),
          findsOneWidget,
        );
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

    testWidgets('invalid explicit vehicle falls back to active without crash', (
      tester,
    ) async {
      final active = await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: 'missing');

      expect(find.text('Próximos 7 días'), findsOneWidget);
      expect(find.text(active.plate), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  TestAppHarness harness, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget? bottomNavigationBar,
  Widget Function(Widget child)? wrap,
  DeviceLocationGateway? deviceLocationGateway,
}) async {
  await _pump(
    tester,
    harness,
    Scaffold(
      body: const HomeScreen(),
      bottomNavigationBar: bottomNavigationBar,
    ),
    viewportSize: viewportSize,
    textScaleFactor: textScaleFactor,
    wrap: wrap,
    deviceLocationGateway: deviceLocationGateway,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  TestAppHarness harness, {
  String? vehicleId,
}) async {
  await _pump(tester, harness, PicoDetailScreen(vehicleId: vehicleId));
}

Future<void> _pumpHomeApp(WidgetTester tester, TestAppHarness harness) async {
  await _installWidgetChannelMock(tester, harness);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/pico',
        builder: (context, state) =>
            PicoDetailScreen(vehicleId: state.uri.queryParameters['vehicleId']),
      ),
      GoRoute(
        path: '/garage/vehicle/:id',
        builder: (context, state) =>
            VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
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

Future<void> _openTomorrowAndExpectPico(
  WidgetTester tester,
  VehicleProfile vehicle,
) async {
  await tester.tap(find.byKey(const ValueKey('home-status-tomorrow')));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(find.text('Próximos 7 días'), findsOneWidget);
  expect(find.text(vehicle.plate), findsOneWidget);
}

Future<void> _goHome(WidgetTester tester) async {
  final routeContent = [
    find.text('Próximos 7 días'),
    find.textContaining('module-'),
    find.byType(HomeScreen),
    find.byType(Scaffold),
  ].firstWhere((finder) => finder.evaluate().isNotEmpty);
  final router = GoRouter.of(routeContent.evaluate().first);
  router.go('/home');
  await _pumpAsyncHome(tester);
}

Future<void> _pumpFullHomeApp(
  WidgetTester tester,
  TestAppHarness harness,
) async {
  await _installWidgetChannelMock(tester, harness);
  await tester.pumpWidget(_providerScope(harness, child: const PicoRadarApp()));
  await _pumpAsyncHome(tester);
}

Future<void> _pump(
  WidgetTester tester,
  TestAppHarness harness,
  Widget child, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget Function(Widget child)? wrap,
  DeviceLocationGateway? deviceLocationGateway,
}) async {
  await _installWidgetChannelMock(tester, harness, viewportSize: viewportSize);
  if (textScaleFactor != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final app = _providerScope(
    harness,
    child: MaterialApp(home: child),
    deviceLocationGateway: deviceLocationGateway,
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await _pumpAsyncHome(tester);
}

Widget _providerScope(
  TestAppHarness harness, {
  required Widget child,
  DeviceLocationGateway? deviceLocationGateway,
}) {
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
      startupReadinessProvider.overrideWith(
        (ref) async => const StartupReadiness(
          imageAssets: [],
          vehicleCount: 0,
          selectedJurisdictionId: null,
        ),
      ),
      deviceLocationGatewayProvider.overrideWithValue(
        deviceLocationGateway ?? _FakeDeviceLocationGateway(),
      ),
      avatarCatalogProvider.overrideWith(
        (ref) async => AvatarCatalog.fromJson(
          jsonDecode(File(avatarCatalogAssetPath).readAsStringSync())
              as Map<String, Object?>,
        ),
      ),
      vehicleVisualCatalogProvider.overrideWith(
        (ref) async => VehicleVisualCatalog.fromJson(
          jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
              as Map<String, Object?>,
        ),
      ),
    ],
    child: child,
  );
}

void _expectNoEllipsisInCard(
  WidgetTester tester,
  ValueKey<String> cardKey,
  List<String> labels,
) {
  final card = find.byKey(cardKey);
  for (final label in labels) {
    final labelFinder = find.descendant(of: card, matching: find.text(label));
    expect(labelFinder, findsWidgets, reason: label);
    final widgets = tester.widgetList<Text>(labelFinder);
    expect(
      widgets.any((widget) => widget.overflow == TextOverflow.ellipsis),
      isFalse,
      reason: label,
    );
  }
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
  String? brand,
  String? model,
}) async {
  final vehicle = await _createVehicle(
    harness,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    brand: brand,
    model: model,
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
