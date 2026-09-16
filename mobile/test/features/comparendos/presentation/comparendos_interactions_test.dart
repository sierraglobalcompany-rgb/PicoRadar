import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';

import '../../../plate_test_fonts.dart';
import 'comparendos_test_fixture.dart';

const _firstNote = 'comparendos.last_checked.vehicle-a';
const _secondNote = 'comparendos.last_checked.vehicle-b';
const _today = '2026-09-03';
const _previous = '2026-08-30';

void main() {
  setUpAll(loadPlateTestFonts);
  late ComparendosPreferences preferences;
  late ComparendosLauncher launcher;
  late VehicleProfile first;
  late VehicleProfile second;

  setUp(() {
    preferences = ComparendosPreferences();
    launcher = ComparendosLauncher();
    first = comparendosVehicle(nickname: 'Carro familiar');
    second = comparendosVehicle(
      id: 'vehicle-b',
      plate: 'XYZ789',
      nickname: 'Moto urbana',
      kind: VehicleKind.motorcycle,
    );
    preferences.values[VehicleRepository.activeVehiclePreferenceKey] = first.id;
    preferences.values[picoJurisdictionPreferenceKey] = 'co-ant-medellin';
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? vehicleId,
    Future<VehicleProfile?> Function()? activeLoader,
    Future<List<VehicleProfile>> Function(Ref)? vehicleLoader,
    Future<TerritorialCatalog> Function()? directoryLoader,
    Future<TripMunicipalityCatalog> Function()? municipalityLoader,
  }) => pumpComparendos(
    tester,
    preferences: preferences,
    vehicles: [first, second],
    active: first,
    vehicleId: vehicleId,
    activeLoader: activeLoader,
    vehicleLoader: vehicleLoader,
    directoryLoader: directoryLoader,
    municipalityLoader: municipalityLoader,
    launcher: launcher,
  );

  testWidgets('manual vehicle and city changes do not write any preferences', (
    tester,
  ) async {
    final before = Map<String, Object?>.of(preferences.values);
    await pump(tester);
    await chooseComparendosVehicle(tester, second.id);
    expect(findPlateNumber(second.plate), findsOneWidget);
    expect(findPlateNumber(first.plate), findsNothing);
    await chooseComparendosCity(tester, '11001', 'bogota');
    expect(find.text('Consulta temporal'), findsOneWidget);
    expect(
      tester.widget<Text>(comparendosKey('consultation-city')).data,
      'Bogotá',
    );
    await tapComparendos(tester, 'open-territorial');
    expect(launcher.opened, [testBogotaUrl]);
    expect(preferences.values, before);
    expect(preferences.writes, isEmpty);

    await pump(tester);
    expect(findPlateNumber(first.plate), findsOneWidget);
    expect(
      tester.widget<Text>(comparendosKey('consultation-city')).data,
      'Medellín',
    );
  });

  testWidgets(
    'favorite resolves once and repeated global updates cannot replace local selections',
    (tester) async {
      var favorite = first;
      final container = await pump(tester, activeLoader: () async => favorite);
      await chooseComparendosVehicle(tester, second.id);
      await chooseComparendosCity(tester, '11001', 'Bogotá');
      for (final next in [second, first, second]) {
        favorite = next;
        preferences.values[VehicleRepository.activeVehiclePreferenceKey] =
            next.id;
        preferences.values[picoJurisdictionPreferenceKey] = 'co-vac-cali';
        container.invalidate(activeVehicleProvider);
        container.invalidate(vehicleListProvider);
        container.invalidate(selectedPicoJurisdictionIdProvider);
        await tester.pumpAndSettle();
        expect(findPlateNumber(second.plate), findsOneWidget);
        expect(
          tester.widget<Text>(comparendosKey('consultation-city')).data,
          'Bogotá',
        );
      }
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'initial favorite and suggested city stay fixed even before a manual choice',
    (tester) async {
      var favorite = first;
      final container = await pump(tester, activeLoader: () async => favorite);
      favorite = second;
      preferences.values[picoJurisdictionPreferenceKey] = 'co-dc-bogota';
      container.invalidate(activeVehicleProvider);
      container.invalidate(selectedPicoJurisdictionIdProvider);
      container.invalidate(vehicleListProvider);
      await tester.pumpAndSettle();
      expect(findPlateNumber(first.plate), findsOneWidget);
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Medellín',
      );
    },
  );

  testWidgets('explicit vehicle wins without waiting for unresolved favorite', (
    tester,
  ) async {
    final favorite = Completer<VehicleProfile?>();
    await pump(
      tester,
      vehicleId: second.id,
      activeLoader: () => favorite.future,
    );
    expect(findPlateNumber(second.plate), findsOneWidget);
    await tapComparendos(tester, 'open-simit');
    expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
    favorite.complete(first);
    await tester.pumpAndSettle();
    expect(findPlateNumber(second.plate), findsOneWidget);
  });

  testWidgets(
    'stale explicit id fails closed then manual choice survives list refresh',
    (tester) async {
      final container = await pump(tester, vehicleId: 'deleted-id');
      expect(comparendosKey('no-vehicle'), findsOneWidget);
      expect(comparendosKey('copy-plate'), findsNothing);
      expect(findPlateNumber(first.plate), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar vehículo'));
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'choose-${second.id}');
      container.invalidate(vehicleListProvider);
      container.invalidate(activeVehicleProvider);
      await tester.pumpAndSettle();
      expect(findPlateNumber(second.plate), findsOneWidget);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'vehicle chooser reflects live additions and removals while open',
    (tester) async {
      var vehicles = [first, second];
      final container = await pump(
        tester,
        vehicleLoader: (ref) async => vehicles,
      );
      await tapComparendos(tester, 'change-vehicle');
      expect(comparendosKey('choose-${second.id}'), findsOneWidget);
      final third = comparendosVehicle(
        id: 'vehicle-c',
        plate: 'NEW456',
        nickname: 'Nuevo',
      );
      vehicles = [first, third];
      container.invalidate(vehicleListProvider);
      await tester.pumpAndSettle();
      expect(comparendosKey('choose-${second.id}'), findsNothing);
      await tapComparendos(tester, 'choose-${third.id}');
      expect(findPlateNumber(third.plate), findsOneWidget);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'removed selected vehicle does not silently fall back to favorite',
    (tester) async {
      var vehicles = [first, second];
      final container = await pump(
        tester,
        vehicleId: second.id,
        vehicleLoader: (ref) async => vehicles,
      );
      vehicles = [first];
      container.invalidate(vehicleListProvider);
      await tester.pumpAndSettle();
      expect(comparendosKey('no-vehicle'), findsOneWidget);
      expect(comparendosKey('copy-plate'), findsNothing);
      expect(findPlateNumber(first.plate), findsNothing);
    },
  );

  testWidgets(
    'favorite failure allows explicit manual recovery without changing favorite',
    (tester) async {
      await pump(
        tester,
        activeLoader: () async => throw StateError('Test favorite failure'),
      );
      expect(
        find.text('No pudimos cargar el vehículo favorito.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cambiar vehículo'));
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'choose-${second.id}');
      expect(findPlateNumber(second.plate), findsOneWidget);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'city search handles accents department authority platform and empty results',
    (tester) async {
      await pump(tester);
      await tapComparendos(tester, 'change-city');
      for (final query in [
        'MEDELLIN',
        'Antioquia',
        'secretaria de movilidad',
        'movilidad en linea',
      ]) {
        await tester.enterText(comparendosKey('city-search'), query);
        await tester.pumpAndSettle();
        expect(comparendosKey('city-05001'), findsOneWidget, reason: query);
        expect(comparendosKey('city-11001'), findsNothing, reason: query);
      }
      await tester.enterText(comparendosKey('city-search'), 'zzzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.enterText(comparendosKey('city-search'), 'itagui');
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'city-05360');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Itagüí',
      );
      expect(comparendosKey('open-territorial'), findsNothing);
      await tapComparendos(tester, 'open-simit');
      expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'dismissing either selector preserves current selections and preferences',
    (tester) async {
      await pump(tester);
      for (final selector in ['change-vehicle', 'change-city']) {
        await tapComparendos(tester, selector);
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
        expect(findPlateNumber(first.plate), findsOneWidget);
        expect(
          tester.widget<Text>(comparendosKey('consultation-city')).data,
          'Medellín',
        );
      }
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'failed note write preserves previous date and retry replaces it',
    (tester) async {
      preferences.values[_firstNote] = _previous;
      preferences.failWrites = true;
      await pump(tester);
      await tapComparendos(tester, 'mark-checked');
      expect(find.text('No pudimos guardar tu anotación.'), findsOneWidget);
      expect(find.text('Última consulta anotada: $_previous'), findsOneWidget);
      expect(preferences.values[_firstNote], _previous);
      expect(find.text('Consulta de hoy anotada'), findsNothing);
      preferences.failWrites = false;
      await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(preferences.values[_firstNote], _today);
      expect(find.text('Última consulta anotada: $_today'), findsOneWidget);
      expect(preferences.writes, [(_firstNote, _today), (_firstNote, _today)]);
    },
  );

  testWidgets(
    'note read failure offers retry and does not erase persisted date',
    (tester) async {
      preferences.values[_firstNote] = _previous;
      preferences.failNoteReads = true;
      await pump(tester);
      expect(find.text('No pudimos leer tu anotación.'), findsOneWidget);
      expect(comparendosKey('mark-checked'), findsNothing);
      preferences.failNoteReads = false;
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Última consulta anotada: $_previous'), findsOneWidget);
      expect(preferences.values[_firstNote], _previous);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'same-frame double tap writes once and completed note is idempotent',
    (tester) async {
      final pending = Completer<void>();
      preferences.pending[_firstNote] = pending;
      await pump(tester);
      await tester.ensureVisible(comparendosKey('mark-checked'));
      await tester.tap(comparendosKey('mark-checked'));
      await tester.tap(comparendosKey('mark-checked'));
      await tester.pump();
      expect(preferences.writes, [(_firstNote, _today)]);
      expect(
        tester.widget<FilledButton>(comparendosKey('mark-checked')).onPressed,
        isNull,
      );
      expect(preferences.values[_firstNote], isNull);
      pending.complete();
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'mark-checked');
      expect(preferences.writes, hasLength(1));
      expect(find.text('Consulta de hoy anotada'), findsOneWidget);
      await pump(tester);
      expect(
        tester.widget<FilledButton>(comparendosKey('mark-checked')).onPressed,
        isNull,
      );
      expect(preferences.writes, hasLength(1));
    },
  );

  testWidgets(
    'late write for first vehicle cannot overwrite second vehicle note',
    (tester) async {
      final pending = Completer<void>();
      preferences.pending[_firstNote] = pending;
      preferences.values[_secondNote] = _previous;
      await pump(tester);
      await tester.ensureVisible(comparendosKey('mark-checked'));
      await tester.tap(comparendosKey('mark-checked'));
      await tester.pump();
      await _chooseDuringWrite(tester, second.id);
      expect(findPlateNumber(second.plate), findsOneWidget);
      expect(find.text('Última consulta anotada: $_previous'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(preferences.values[_firstNote], _today);
      expect(preferences.values[_secondNote], _previous);
      expect(find.text('Última consulta anotada: $_previous'), findsOneWidget);
      expect(find.text('Última consulta anotada: $_today'), findsNothing);
      await tapComparendos(tester, 'mark-checked');
      expect(preferences.writes, [(_firstNote, _today), (_secondNote, _today)]);
      await chooseComparendosVehicle(tester, first.id);
      expect(find.text('Consulta de hoy anotada'), findsOneWidget);
    },
  );

  testWidgets('per-vehicle writes can finish in reverse order', (tester) async {
    final pendingFirst = Completer<void>();
    final pendingSecond = Completer<void>();
    preferences.pending.addAll({
      _firstNote: pendingFirst,
      _secondNote: pendingSecond,
    });
    await pump(tester);
    await tester.ensureVisible(comparendosKey('mark-checked'));
    await tester.tap(comparendosKey('mark-checked'));
    await tester.pump();
    await _chooseDuringWrite(tester, second.id);
    await tester.ensureVisible(comparendosKey('mark-checked'));
    await tester.tap(comparendosKey('mark-checked'));
    await tester.pump();
    expect(preferences.writes, [(_firstNote, _today), (_secondNote, _today)]);
    pendingSecond.complete();
    await tester.pumpAndSettle();
    expect(find.text('Consulta de hoy anotada'), findsOneWidget);
    expect(preferences.values[_firstNote], isNull);
    pendingFirst.complete();
    await tester.pumpAndSettle();
    expect(preferences.values[_firstNote], _today);
    expect(preferences.values[_secondNote], _today);
    expect(findPlateNumber(second.plate), findsOneWidget);
  });

  testWidgets(
    'clipboard failure retries the selected plate without writing preferences',
    (tester) async {
      var fail = true;
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
              if (fail) throw PlatformException(code: 'clipboard_unavailable');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pump(tester);
      await chooseComparendosVehicle(tester, second.id);
      await tapComparendos(tester, 'copy-plate');
      expect(find.text('No pudimos copiar la placa.'), findsOneWidget);
      expect(find.text('Placa copiada.'), findsNothing);
      fail = false;
      await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(copied, [second.plate, second.plate]);
      expect(find.text('Placa copiada.'), findsOneWidget);
      expect(preferences.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'directory failure keeps SIMIT independent and retry restores territory',
    (tester) async {
      var fail = true;
      var loads = 0;
      await pump(
        tester,
        directoryLoader: () async {
          loads++;
          if (fail) throw StateError('Test directory unavailable');
          return comparendosAuthorities;
        },
      );
      expect(
        find.text(
          'No pudimos cargar el directorio territorial. SIMIT sigue disponible.',
        ),
        findsOneWidget,
      );
      expect(comparendosKey('open-territorial'), findsNothing);
      await tapComparendos(tester, 'open-simit');
      expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
      fail = false;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'open-territorial');
      expect(launcher.opened, [
        'https://www.fcm.org.co/simit/',
        testMedellinUrl,
      ]);
      expect(loads, 2);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets('pending directory never blocks SIMIT', (tester) async {
    final pending = Completer<TerritorialCatalog>();
    await pump(tester, directoryLoader: () => pending.future);
    await tapComparendos(tester, 'open-simit');
    expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
    expect(comparendosKey('open-territorial'), findsNothing);
    pending.complete(comparendosAuthorities);
    await tester.pumpAndSettle();
    expect(comparendosKey('open-territorial'), findsOneWidget);
  });

  testWidgets(
    'municipality load failure keeps SIMIT usable and city search recovers',
    (tester) async {
      var fail = true;
      await pump(
        tester,
        municipalityLoader: () async {
          if (fail) throw StateError('Test municipalities unavailable');
          return comparendosMunicipalities;
        },
      );
      await tapComparendos(tester, 'open-simit');
      expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
      await tapComparendos(tester, 'change-city');
      expect(find.text('No pudimos cargar las ciudades.'), findsOneWidget);
      fail = false;
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(TextButton, 'Reintentar'),
        ),
      );
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'city-11001');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Bogotá',
      );
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets('failed portal launch retries only the exact selected URL', (
    tester,
  ) async {
    launcher.succeeds = false;
    await pump(tester);
    await chooseComparendosCity(tester, '11001', 'bogota');
    await tapComparendos(tester, 'open-territorial');
    expect(
      find.text('No pudimos abrir la autoridad de tránsito.'),
      findsOneWidget,
    );
    launcher.succeeds = true;
    await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
    await tester.pumpAndSettle();
    expect(launcher.opened, [testBogotaUrl, testBogotaUrl]);
    expect(preferences.writes, isEmpty);
  });

  testWidgets(
    'pending authority is searchable by name office department and platform',
    (tester) async {
      await pump(
        tester,
        directoryLoader: () async => const TerritorialCatalog(
          authorities: [pendingComparendosAuthority],
        ),
      );
      await tapComparendos(tester, 'change-city');
      for (final query in [
        'pendiente de revision',
        'MEDELLIN',
        'Antioquia',
        'historico',
      ]) {
        await tester.enterText(comparendosKey('city-search'), query);
        await tester.pumpAndSettle();
        expect(
          comparendosKey('authority-test-pending'),
          findsOneWidget,
          reason: query,
        );
      }
      await tapComparendos(tester, 'authority-test-pending');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(find.text(pendingComparendosAuthority.name), findsOneWidget);
      expect(find.text('Ámbito territorial por verificar.'), findsOneWidget);
      expect(comparendosKey('open-territorial'), findsNothing);
      expect(comparendosKey('open-institutional'), findsNothing);
      expect(launcher.opened, isEmpty);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'directory mode selects pending authority without using its office as scope',
    (tester) async {
      final before = Map<String, Object?>.of(preferences.values);
      await pump(
        tester,
        directoryLoader: () async => TerritorialCatalog(
          authorities: [
            ...comparendosAuthorities.authorities,
            pendingComparendosAuthority,
          ],
        ),
      );
      await tapComparendos(tester, 'change-city');
      await tapComparendos(tester, 'directory-mode');
      expect(comparendosKey('city-05001'), findsNothing);
      await tapComparendos(tester, 'authority-test-pending');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(comparendosKey('open-territorial'), findsNothing);
      await tapComparendos(tester, 'authority-info');
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(pendingComparendosAuthority.name),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Sede registrada: Medellín · Antioquia'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ámbito territorial por verificar. La sede no determina su competencia.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Referencia histórica del directorio. Vigencia y enlaces pendientes de comprobación.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Abrir fuente oficial'),
        findsNothing,
      );
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'open-simit');
      expect(launcher.opened, ['https://www.fcm.org.co/simit/']);
      expect(preferences.values, before);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'pending selection survives global changes and a city choice clears it',
    (tester) async {
      final container = await pump(
        tester,
        directoryLoader: () async => TerritorialCatalog(
          authorities: [
            ...comparendosAuthorities.authorities,
            pendingComparendosAuthority,
          ],
        ),
      );
      await tapComparendos(tester, 'change-city');
      await tester.enterText(comparendosKey('city-search'), 'pendiente');
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'authority-test-pending');
      await chooseComparendosVehicle(tester, second.id);
      preferences.values[picoJurisdictionPreferenceKey] = 'co-dc-bogota';
      container.invalidate(selectedPicoJurisdictionIdProvider);
      container.invalidate(territorialCatalogProvider);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(find.text(pendingComparendosAuthority.name), findsOneWidget);
      expect(comparendosKey('open-territorial'), findsNothing);
      await chooseComparendosCity(tester, '11001', 'bogota');
      expect(find.text(pendingComparendosAuthority.name), findsNothing);
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Bogotá',
      );
      await tapComparendos(tester, 'open-territorial');
      expect(launcher.opened, [testBogotaUrl]);
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'verified multi-city authority opens portal safely with no assigned city',
    (tester) async {
      final before = Map<String, Object?>.of(preferences.values);
      final container = await pump(
        tester,
        directoryLoader: () async => const TerritorialCatalog(
          authorities: [regionalComparendosAuthority],
        ),
      );
      await tapComparendos(tester, 'change-city');
      await tester.enterText(comparendosKey('city-search'), 'regional');
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'authority-test-regional');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(find.text('Consultar en el portal'), findsOneWidget);
      await tapComparendos(tester, 'open-territorial');
      expect(launcher.opened, [regionalComparendosAuthority.consultationUrl]);
      container.invalidate(selectedPicoJurisdictionIdProvider);
      container.invalidate(territorialCatalogProvider);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(preferences.values, before);
      expect(preferences.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verified authority ficha opens evidence independently of its consultation portal',
    (tester) async {
      await pump(
        tester,
        directoryLoader: () async => const TerritorialCatalog(
          authorities: [regionalComparendosAuthority],
        ),
      );
      await tapComparendos(tester, 'change-city');
      await tester.enterText(comparendosKey('city-search'), 'regional');
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'authority-test-regional');
      await tapComparendos(tester, 'authority-info');
      expect(
        find.text(
          'Enlaces revisados: 2026-09-01. Esta revisión no consulta tus comparendos.',
        ),
        findsOneWidget,
      );
      final evidence = find.widgetWithText(
        OutlinedButton,
        'Abrir fuente oficial',
      );
      await tester.ensureVisible(evidence);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      expect(launcher.opened, [regionalComparendosAuthority.evidenceUrl]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(preferences.writes, isEmpty);
    },
  );

  testWidgets(
    'source name alias finds pending authority without inferring city coverage',
    (tester) async {
      await pump(
        tester,
        directoryLoader: () async => const TerritorialCatalog(
          authorities: [pendingComparendosAuthority],
        ),
      );
      await tapComparendos(tester, 'change-city');
      await tester.enterText(
        comparendosKey('city-search'),
        'registro nacional',
      );
      await tester.pumpAndSettle();
      expect(comparendosKey('authority-test-pending'), findsOneWidget);
      expect(comparendosKey('city-05001'), findsNothing);
      await tapComparendos(tester, 'authority-test-pending');
      expect(
        tester.widget<Text>(comparendosKey('consultation-city')).data,
        'Autoridad seleccionada',
      );
      expect(comparendosKey('open-territorial'), findsNothing);
      expect(preferences.writes, isEmpty);
    },
  );

  for (final throwsException in [false, true]) {
    testWidgets(
      'authority source failure closes ficha and exposes retry throws=$throwsException',
      (tester) async {
        launcher.succeeds = false;
        launcher.throwsOnOpen = throwsException;
        await pump(
          tester,
          directoryLoader: () async => const TerritorialCatalog(
            authorities: [regionalComparendosAuthority],
          ),
        );
        await tapComparendos(tester, 'change-city');
        await tester.enterText(comparendosKey('city-search'), 'regional');
        await tester.pumpAndSettle();
        await tapComparendos(tester, 'authority-test-regional');
        await tapComparendos(tester, 'authority-info');
        final source = find.widgetWithText(
          OutlinedButton,
          'Abrir fuente oficial',
        );
        await tester.ensureVisible(source);
        await tester.tap(source);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.text('No pudimos abrir la autoridad de tránsito.'),
          findsOneWidget,
        );
        final retry = find.widgetWithText(SnackBarAction, 'Reintentar');
        expect(retry.hitTestable(), findsOneWidget);
        expect(launcher.opened, [regionalComparendosAuthority.evidenceUrl]);
        await captureComparendos(
          tester,
          'authority-source-failure-$throwsException',
        );
        launcher.succeeds = true;
        launcher.throwsOnOpen = false;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(launcher.opened, [
          regionalComparendosAuthority.evidenceUrl,
          regionalComparendosAuthority.evidenceUrl,
        ]);
        expect(
          tester.widget<Text>(comparendosKey('consultation-city')).data,
          'Autoridad seleccionada',
        );
        expect(preferences.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'institutional fallback does not claim a direct consultation or invent evidence',
    (tester) async {
      const authority = TerritorialAuthority(
        id: 'test-institution',
        name: 'Autoridad institucional de prueba',
        platformName: 'Institución de prueba',
        municipalityCodes: [],
        institutionalUrl: 'https://www.example.org/institucion',
      );
      await pump(
        tester,
        directoryLoader: () async =>
            const TerritorialCatalog(authorities: [authority]),
      );
      await tapComparendos(tester, 'change-city');
      await tester.enterText(comparendosKey('city-search'), 'institucional');
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'authority-test-institution');
      expect(comparendosKey('open-territorial'), findsNothing);
      expect(comparendosKey('unsupported-city'), findsOneWidget);
      await tapComparendos(tester, 'authority-info');
      expect(
        find.text(
          'Referencia histórica del directorio. Vigencia y enlaces pendientes de comprobación.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Abrir fuente oficial'),
        findsNothing,
      );
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tapComparendos(tester, 'open-institutional');
      expect(launcher.opened, [authority.institutionalUrl]);
      expect(preferences.writes, isEmpty);
    },
  );
}

Future<void> _chooseDuringWrite(WidgetTester tester, String id) async {
  // The saving spinner is intentionally active; do not wait for animation idle.
  await tester.ensureVisible(comparendosKey('change-vehicle'));
  await tester.tap(comparendosKey('change-vehicle'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(comparendosKey('choose-$id'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}
