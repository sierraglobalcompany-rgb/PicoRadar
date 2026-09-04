import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/trip/domain/trip_draft.dart';
import 'package:picoradar/features/trip/presentation/trip_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';

void main() {
  late MemoryPreferences preferences;
  late _FakeExternalLauncher launcher;

  setUp(() {
    preferences = MemoryPreferences();
    launcher = _FakeExternalLauncher();
  });

  testWidgets('shows basic trip planner copy and checklist', (tester) async {
    await _pumpScreen(tester, preferences: preferences);

    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
    expect(find.text('Planea tu viaje'), findsOneWidget);
    expect(
      find.text('PicoRadar no calcula rutas, ETA ni peajes en esta versión.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'La navegación y el estado vial se consultan en servicios externos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Opcional para este borrador.'), findsOneWidget);
    expect(find.text('Revisé Pico y placa'), findsOneWidget);
    expect(find.text('Revisé SOAT'), findsOneWidget);
    expect(find.text('Revisé tecnomecánica'), findsOneWidget);
    expect(
      find.text('Planeé descansos y elementos de seguridad'),
      findsOneWidget,
    );
  });

  testWidgets('shows active vehicle without requiring it', (tester) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(plate: 'ABC123'),
    );

    expect(find.text('Particular · ABC123'), findsOneWidget);
  });

  testWidgets('validates required origin and destination before navigation', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences, launcher: launcher);

    await _tapByKey(tester, 'trip-open-google-maps');

    expect(find.text('Ingresa el origen.'), findsOneWidget);
    expect(find.text('Ingresa el destino.'), findsOneWidget);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('opens Google Maps Waze and INVÍAS with exact URLs', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences, launcher: launcher);
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Medellín',
    );

    await _tapByKey(tester, 'trip-open-google-maps');
    await _tapByKey(tester, 'trip-open-waze');
    await _tapByKey(tester, 'trip-open-invias');

    expect(launcher.opened, [
      'https://www.google.com/maps/dir/?api=1&origin=Bogot%C3%A1&destination=Medell%C3%ADn&travelmode=driving',
      'https://waze.com/ul?q=Medell%C3%ADn&navigate=yes',
      'https://www.invias.gov.co/index.php/informacion-institucional/2-uncategorised/57-estado-de-la-red-vial',
    ]);
  });

  testWidgets('saves local draft with active vehicle and checklist only', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(id: 'vehicle-a'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Cali',
    );
    await _tapByKey(tester, 'trip-checklist-pico_placa');

    await _tapByKey(tester, 'trip-save-draft');

    expect(preferences.values.keys, [tripDraftPreferenceKey]);
    final restored = await TripDraftStore(preferences).loadDraft();
    expect(restored?.origin, 'Bogotá');
    expect(restored?.destination, 'Cali');
    expect(restored?.activeVehicleId, 'vehicle-a');
    expect(restored?.completedChecklist, {TripChecklistItem.picoPlaca});
    expect(find.text('Borrador guardado en este dispositivo.'), findsOneWidget);
  });

  testWidgets('restores and deletes the explicit local draft', (tester) async {
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Cali',
        destination: 'Pereira',
        date: DateTime(2026, 9, 5),
        completedChecklist: {TripChecklistItem.soat},
      ),
    );

    await _pumpScreen(tester, preferences: preferences);

    expect(find.text('Cali'), findsOneWidget);
    expect(find.text('Pereira'), findsOneWidget);
    expect(find.text('Fecha · 2026-09-05'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-draft-restored')), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('trip-checklist-soat')),
          )
          .value,
      isTrue,
    );

    await _tapByKey(tester, 'trip-delete-draft');

    expect(await preferences.getString(tripDraftPreferenceKey), isNull);
    expect(find.text('Borrador eliminado.'), findsOneWidget);
    expect(find.text('Cali'), findsNothing);
    expect(find.text('Pereira'), findsNothing);
  });

  testWidgets('target responsive viewports avoid overflow', (tester) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(360, 800), 2.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpScreen(
        tester,
        preferences: preferences,
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  _FakeExternalLauncher? launcher,
  VehicleProfile? activeVehicle,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        activeVehicleProvider.overrideWith((ref) async => activeVehicle),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const TripScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

VehicleProfile _vehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  final opened = <String>[];
  var openResult = true;

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    opened.add(uri);
    return openResult;
  }
}
