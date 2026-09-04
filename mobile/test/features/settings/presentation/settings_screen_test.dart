import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/settings/presentation/settings_screen.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';

void main() {
  late MemoryPreferences preferences;
  late _FakePicoNotificationScheduler scheduler;
  late _FakeExternalLauncher launcher;
  late _FakeDocumentStore documentStore;
  late int avatarCalls;
  late int configureCalls;

  setUp(() {
    preferences = MemoryPreferences();
    scheduler = _FakePicoNotificationScheduler();
    launcher = _FakeExternalLauncher();
    documentStore = _FakeDocumentStore();
    avatarCalls = 0;
    configureCalls = 0;
  });

  testWidgets('renders required sections and avatar callback', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () => avatarCalls += 1,
      onConfigureNotifications: () => configureCalls += 1,
    );

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Fuentes'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Borrar todo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-change-avatar')));
    await tester.pump();
    expect(avatarCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('settings-go-home-notifications')),
    );
    await tester.pump();
    expect(configureCalls, 1);
  });

  testWidgets('shows notification state without requesting permission', (
    tester,
  ) async {
    preferences.values[picoRestrictionAlertsEnabledKey] = false;
    preferences.values[picoNotificationPermissionRequestedKey] = true;
    preferences.values[picoNotificationPermissionGrantedKey] = false;
    scheduler.areEnabledResult = false;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(
      find.text('Permiso del sistema: denegado o desactivado.'),
      findsOneWidget,
    );
    expect(find.text('Alertas locales: desactivadas.'), findsOneWidget);
    expect(scheduler.areEnabledCalls, 1);
    expect(scheduler.requestPermissionCalls, 0);
  });

  testWidgets('states local privacy truths', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(
      find.text('Los datos del vehículo viven en este dispositivo.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Los documentos se guardan cifrados en almacenamiento privado.',
      ),
      findsOneWidget,
    );
    expect(find.text('PicoRadar funciona sin cuenta.'), findsOneWidget);
    expect(
      find.text('No hay sincronización en nube en Free 1.0.'),
      findsOneWidget,
    );
    expect(find.text('No guardamos historial GPS.'), findsOneWidget);
    expect(find.text('No subimos GPS al servidor.'), findsOneWidget);
  });

  testWidgets('runs only real local cleanup actions after confirmation', (
    tester,
  ) async {
    final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
    preferences.values['trip.draft.v1'] =
        '{"origin":"A","destination":"B",'
        '"date":"2026-09-03","completedChecklist":[]}';
    preferences.values['comparendos.last_checked.vehicle-1'] = '2026-09-03';

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicle: activeVehicle,
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-purge-document-viewer')),
    );
    await tester.pumpAndSettle();
    expect(documentStore.purgeViewerCacheCalls, 1);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-trip-draft')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Borrar borrador de Viaje'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(preferences.values.containsKey('trip.draft.v1'), isTrue);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-trip-draft')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(preferences.values.containsKey('trip.draft.v1'), isFalse);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Borrar nota de Comparendos'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isTrue,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isFalse,
    );
    expect(find.textContaining('ABC123'), findsNothing);
  });

  testWidgets('shows no active vehicle message for Comparendos cleanup', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicleFuture: Future<VehicleProfile?>.value(),
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No hay vehículo activo para limpiar.'), findsOneWidget);
  });

  testWidgets('does not use context after active vehicle wait is disposed', (
    tester,
  ) async {
    final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
    final completer = Completer<VehicleProfile?>();
    preferences.values['comparendos.last_checked.vehicle-1'] = '2026-09-03';

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicleFuture: completer.future,
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(activeVehicle);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isFalse,
    );
  });

  test('uses exact official source metadata', () {
    expect(ansvFotodeteccionUrl, endsWith('/ubicaciones-aprobadas.html'));
    expect(simitSourceUrl, 'https://www.simit.org.co/');
    expect(
      sicPersonalDataGuideUrl,
      'https://sedeelectronica.sic.gov.co/noticias/sic-expide-guia-para-el-correcto-tratamiento-de-las-fotografias-como-datos-personales',
    );

    final sicSource = settingsSourceLinks.singleWhere(
      (source) => source.label == 'Guía SIC de datos personales',
    );
    expect(sicSource.url, sicPersonalDataGuideUrl);
    expect(sicSource.description, contains('fotografías'));
    expect(
      settingsSourceLinks.where((source) => source.label.contains('SIC')),
      hasLength(1),
    );

    final inviasSource = settingsSourceLinks.singleWhere(
      (source) => source.label == 'INVÍAS',
    );
    expect(inviasSource.url, inviasRoadStatusUrl);
  });

  testWidgets('opens official source URLs', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    for (final source in settingsSourceLinks) {
      await tester.ensureVisible(find.text(source.label));
      await tester.tap(find.text(source.label));
      await tester.pump();
    }

    expect(launcher.opened, [
      ansvFotodeteccionUrl,
      simitSourceUrl,
      inviasRoadStatusUrl,
      sicPersonalDataGuideUrl,
    ]);
  });

  testWidgets('shows visible message when source launcher returns false', (
    tester,
  ) async {
    launcher.openResult = false;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('SIMIT'));
    await tester.tap(find.text('SIMIT'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('shows visible message when source launcher throws', (
    tester,
  ) async {
    launcher.openException = Exception('launcher failed');

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('SIMIT'));
    await tester.tap(find.text('SIMIT'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('copies non-sensitive diagnostic only', (tester) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicle: _vehicle(id: 'vehicle-secret', plate: 'ABC123'),
      cameraDatasetDiagnostic: const CameraDatasetDiagnostic(
        version: '2026.08.31-ansv',
        count: 360,
      ),
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('Copiar diagnóstico'));
    await tester.tap(find.byKey(const ValueKey('settings-copy-diagnostic')));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('schemaVersion=5'));
    expect(clipboardText, contains('cameraDatasetVersion=2026.08.31-ansv'));
    expect(clipboardText, contains('cameraDatasetCount=360'));
    expect(clipboardText, isNot(contains('ABC123')));
    expect(clipboardText, isNot(contains('vehicle-secret')));
    expect(clipboardText, isNot(contains('vehicleId')));
    expect(clipboardText, isNot(contains('coordinates')));
    expect(clipboardText, isNot(contains('device')));
  });

  testWidgets('shows visible message when diagnostic copy throws', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'copy_failed');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      cameraDatasetDiagnostic: const CameraDatasetDiagnostic(
        version: '2026.08.31-ansv',
        count: 360,
      ),
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('Copiar diagnóstico'));
    await tester.tap(find.byKey(const ValueKey('settings-copy-diagnostic')));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos copiar el diagnóstico.'), findsOneWidget);
  });

  testWidgets('phone viewports do not overflow', (tester) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpSettings(
        tester,
        preferences: preferences,
        scheduler: scheduler,
        launcher: launcher,
        documentStore: documentStore,
        onChangeAvatar: () {},
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(
        find.byKey(const ValueKey('settings-screen-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  required _FakePicoNotificationScheduler scheduler,
  required _FakeExternalLauncher launcher,
  required _FakeDocumentStore documentStore,
  required VoidCallback onChangeAvatar,
  VoidCallback? onConfigureNotifications,
  VehicleProfile? activeVehicle,
  Future<VehicleProfile?>? activeVehicleFuture,
  CameraDatasetDiagnostic cameraDatasetDiagnostic =
      const CameraDatasetDiagnostic(version: 'test-cameras', count: 2),
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        picoNotificationSchedulerProvider.overrideWithValue(scheduler),
        externalLauncherProvider.overrideWithValue(launcher),
        privateVehicleDocumentStoreProvider.overrideWithValue(documentStore),
        if (activeVehicleFuture != null)
          activeVehicleProvider.overrideWith((ref) => activeVehicleFuture),
        if (activeVehicle != null)
          activeVehicleProvider.overrideWithValue(
            AsyncValue.data(activeVehicle),
          ),
        cameraDatasetDiagnosticProvider.overrideWithValue(
          AsyncValue.data(cameraDatasetDiagnostic),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: SettingsScreen(
            onChangeAvatar: onChangeAvatar,
            onConfigureNotifications: onConfigureNotifications,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

VehicleProfile _vehicle({required String id, required String plate}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime.utc(2026, 9, 3),
    updatedAt: DateTime.utc(2026, 9, 3),
  );
}

class _FakePicoNotificationScheduler extends PicoNotificationScheduler {
  bool? areEnabledResult = true;
  var areEnabledCalls = 0;
  var requestPermissionCalls = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    areEnabledCalls += 1;
    return areEnabledResult;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return true;
  }
}

class _FakeExternalLauncher implements ExternalLauncher {
  final opened = <String>[];
  bool openResult = true;
  Object? openException;

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    final exception = openException;
    if (exception != null) {
      throw exception;
    }
    opened.add(uri);
    return openResult;
  }
}

class _FakeDocumentStore extends PrivateVehicleDocumentStore {
  var purgeViewerCacheCalls = 0;

  @override
  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {
    purgeViewerCacheCalls += 1;
  }
}
