import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/router/app_router.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/apps_launcher/data/module_registry.dart';
import 'package:picoradar/features/apps_launcher/domain/app_module.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';
import 'package:picoradar/features/defense/presentation/defense_screen.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/driving_alert_engine.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/settings/presentation/settings_screen.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';

import '../test_app_harness.dart';

void main() {
  group('K7-C functional audit documentation gate', () {
    test('records required source coverage and launcher matrix', () {
      final report = File('../docs/qa/K7_FUNCTIONAL_AUDIT.md');

      expect(report.existsSync(), isTrue);
      final text = report.readAsStringSync();

      for (final source in [
        'ANSV',
        'SIMIT',
        'INVÍAS',
        'C-038/20',
        'C-321/22',
        'SIC datos personales',
      ]) {
        expect(text, contains(source));
      }

      for (final callSite in _externalLauncherCallSites()) {
        expect(
          text,
          contains('| `${callSite.replaceAll('\\', '/')}` |'),
          reason: '$callSite must be covered by the K7-C launcher matrix.',
        );
      }
    });
  });

  group('K7-C local preferences fail closed', () {
    test('corrupt preferences fail closed and preserve purchase ownership for recovery', () async {
      final preferences = MemoryPreferences()
        ..values[tripDraftPreferenceKey] = '{broken trip'
        ..values[buySellDraftPreferenceKey] = '{"version":1,"mode":7}'
        ..values[peritajesDraftPreferenceKey('vehicle-a')] = '[bad]';

      expect(await TripDraftStore(preferences).loadDraft(), isNull);
      await expectLater(loadBuySellDraft(preferences), throwsFormatException);
      expect(
        await PeritajesDraftStore(preferences).loadDraft('vehicle-a'),
        isNull,
      );

      expect(preferences.values.containsKey(tripDraftPreferenceKey), isFalse);
      expect(
        preferences.values[buySellDraftPreferenceKey],
        '{"version":1,"mode":7}',
      );
      expect(
        preferences.values.containsKey(
          peritajesDraftPreferenceKey('vehicle-a'),
        ),
        isFalse,
      );
    });

    test(
      'corrupt driving preferences fall back to conservative defaults',
      () async {
        final preferences = MemoryPreferences()
          ..values['driving.alert.profile'] = 'turbo'
          ..values['driving.alert.voice'] = false
          ..values['driving.alert.sound'] = false
          ..values['driving.alert.vibration'] = false
          ..values['driving.alert.customThresholds'] = '999,abc,-10'
          ..values['driving.hud.mirror'] = true
          ..values['driving.alert.targetingConeDegrees'] = 271
          ..values['driving.camera.visualizationMode'] = 'satellite';

        final loaded = await loadDrivingPreferences(preferences);

        expect(loaded.profile, DrivingAlertProfile.normal);
        expect(loaded.customThresholdsMeters, [500, 300, 100]);
        expect(loaded.cameraTargetingConeDegrees, 90);
        expect(loaded.cameraVisualizationMode, CameraVisualizationMode.auto);
        expect(loaded.voiceEnabled, isFalse);
        expect(loaded.soundEnabled, isFalse);
        expect(loaded.vibrationEnabled, isFalse);
        expect(loaded.hudMirrorEnabled, isTrue);
      },
    );
  });

  group('K7-C privacy and source gates', () {
    test(
      'diagnostic text contains no plate vehicle id coordinates or facts',
      () {
        final text = settingsDiagnosticText(
          schemaVersion: 4,
          cameraDataset: const CameraDatasetDiagnostic(
            version: 'cameras_v1',
            count: 123,
          ),
        );

        expect(text, contains('schemaVersion=4'));
        expect(text, contains('cameraDatasetVersion=cameras_v1'));
        for (final forbidden in [
          'ABC123',
          'vehicle-a',
          '6.244',
          '-75.57',
          'hechos del caso',
          'placa',
          'plate',
          'vehicleId',
          'latitude',
          'longitude',
          'coordinates',
          'facts',
        ]) {
          expect(text, isNot(contains(forbidden)));
        }
      },
    );

    test('official sources use HTTPS and expected hosts', () {
      final expectedHosts = <String, Set<String>>{
        'ANSV Fotodetección': {'fotodeteccion.ansv.gov.co'},
        'SIMIT': {'www.simit.org.co'},
        'INVÍAS': {'hermes2.invias.gov.co'},
        'Guía SIC de datos personales': {'sedeelectronica.sic.gov.co'},
        'Defensa SIMIT': {'www.simit.org.co'},
        'C-038/20': {'www.corteconstitucional.gov.co'},
        'C-321/22': {'www.corteconstitucional.gov.co'},
        'Viaje INVÍAS': {'hermes2.invias.gov.co'},
        'Google Maps route': {'www.google.com'},
        'Waze route': {'waze.com'},
      };
      final urls = <String, String>{
        for (final source in settingsSourceLinks) source.label: source.url,
        'Defensa SIMIT': defenseSimitUrl,
        'C-038/20': defenseC038Url,
        'C-321/22': defenseC321Url,
        'Viaje INVÍAS': inviasRoadStatusUrl,
        'Google Maps route': googleMapsTripUrl(
          origin: 'Bogotá',
          destination: 'Medellín',
        ),
        'Waze route': wazeTripUrl(destination: 'Medellín'),
      };

      expect(urls.keys, containsAll(expectedHosts.keys));
      for (final entry in urls.entries) {
        final uri = Uri.parse(entry.value);
        expect(uri.scheme, 'https', reason: entry.key);
        expect(expectedHosts[entry.key], contains(uri.host), reason: entry.key);
      }
    });
  });

  group('K7-C navigation and visibility gates', () {
    late TestAppHarness harness;

    setUp(() {
      harness = TestAppHarness();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('five root tabs and Apps module counts match baseline', () {
      expect(AppTab.values.map((tab) => tab.label), [
        'Inicio',
        'Garaje',
        'Apps',
        'Viaje',
        'Conducir',
      ]);
      expect(AppTab.values.indexOf(AppTab.apps), 2);
      expect(visibleModules(primaryModules, defaultModuleFeatureFlags), [
        ...primaryModules,
      ]);
      expect(visibleModules(secondaryModules, defaultModuleFeatureFlags), [
        ...secondaryModules,
      ]);
      expect(primaryModules, hasLength(9));
      expect(secondaryModules, hasLength(7));
    });

    testWidgets('visible launcher modules do not route to placeholders', (
      tester,
    ) async {
      final vehicle = await harness.repository.createVehicle(
        plate: 'KTC123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationCity: 'Bogota',
      );
      await harness.repository.setActiveVehicle(vehicle.id);

      for (final module in [...primaryModules, ...secondaryModules]) {
        await _pumpAtRoute(
          tester,
          harness,
          appModuleLocation(module, vehicle.id),
        );
        await _pumpAuditFrame(tester);

        expect(
          find.byType(ModulePlaceholderScreen),
          findsNothing,
          reason: '${module.id} must not expose a visible placeholder.',
        );
        expect(tester.takeException(), isNull, reason: module.id);
      }
    });

    testWidgets('root shell is responsive at logical 360x800 and scale 2.0', (
      tester,
    ) async {
      _usePhone360AtScale2(tester);
      await harness.pump(tester);

      for (final tab in AppTab.values) {
        expect(find.byKey(ValueKey('tab-${tab.name}')), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('tab-apps')));
      await _pumpAuditFrame(tester);
      expect(
        find.byKey(const ValueKey('apps-launcher-overlay')),
        findsOneWidget,
      );
      for (final module in primaryModules) {
        expect(
          find.byKey(ValueKey('app-module-${module.id}'), skipOffstage: false),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('K7-C destructive local actions', () {
    testWidgets('settings local deletes require confirmation', (tester) async {
      final preferences = MemoryPreferences()
        ..values[tripDraftPreferenceKey] = '{"origin":"Bogotá"}'
        ..values['comparendos.last_checked.vehicle-a'] = '2026-09-04';
      final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');

      await _pumpSettings(
        tester,
        preferences: preferences,
        activeVehicle: vehicle,
      );

      await _tapSettingsAction(tester, 'settings-delete-trip-draft');
      expect(_dialogText('Borrar borrador de Viaje'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await preferences.getString(tripDraftPreferenceKey), isNotNull);

      await _tapSettingsAction(tester, 'settings-delete-trip-draft');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(await preferences.getString(tripDraftPreferenceKey), isNull);

      await _tapSettingsAction(tester, 'settings-delete-comparendos-note');
      expect(_dialogText('Borrar nota de Comparendos'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-a'),
        '2026-09-04',
      );

      await _tapSettingsAction(tester, 'settings-delete-comparendos-note');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-a'),
        isNull,
      );
    });
  });
}

Finder _dialogText(String text) {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(text),
  );
}

Future<void> _pumpAuditFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(seconds: 1));
}

List<String> _externalLauncherCallSites() {
  final lib = Directory('lib');
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) {
        final text = file.readAsStringSync();
        return text.contains('.openExternal(') || text.contains('.callPhone(');
      })
      .map((file) => file.path)
      .toList()
    ..sort();
}

Future<void> _pumpAtRoute(
  WidgetTester tester,
  TestAppHarness harness,
  String route,
) async {
  final appRouter = _routeHarness(route);
  await harness.pump(
    tester,
    childOverride: MaterialApp.router(routerConfig: appRouter),
  );
}

GoRouter _routeHarness(String route) {
  final container = ProviderContainer();
  final router = container.read(appRouterProvider);
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  router.go(route);
  return router;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  required VehicleProfile activeVehicle,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        activeVehicleProvider.overrideWithValue(AsyncValue.data(activeVehicle)),
        picoNotificationSchedulerProvider.overrideWithValue(
          _FakePicoNotificationScheduler(),
        ),
        cameraDatasetDiagnosticProvider.overrideWithValue(
          const AsyncValue.data(
            CameraDatasetDiagnostic(version: 'camera_pack_test', count: 1),
          ),
        ),
      ],
      child: MaterialApp(
        home: SettingsScreen(
          onChangeAvatar: () {},
          onConfigureNotifications: () {},
        ),
      ),
    ),
  );
  await tester.pump();
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

Future<void> _tapSettingsAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _usePhone360AtScale2(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(720, 1600);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

VehicleProfile _vehicle({required String id, required String plate}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
