import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';
import 'comparendos_test_fixture.dart';

late MemoryPreferences _preferences;
late _FakeExternalLauncher _launcher;

void main() {
  setUpAll(loadPlateTestFonts);
  setUp(() {
    _preferences = MemoryPreferences();
    _launcher = _FakeExternalLauncher();
  });

  testWidgets('shows loading vehicles state', (tester) async {
    final completer = Completer<List<VehicleProfile>>();
    await _pumpScreen(tester, vehicleList: (ref) => completer.future);

    expect(find.byKey(const ValueKey('comparendos-loading')), findsOneWidget);
  });

  testWidgets('explicit vehicle remains usable when favorite lookup fails', (
    tester,
  ) async {
    final vehicle = _vehicle();
    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      vehicleId: vehicle.id,
      activeLoader: () async => throw StateError('Favorite unavailable'),
    );
    expect(find.byKey(const ValueKey('comparendos-plate')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('comparendos-copy-plate')),
      findsOneWidget,
    );
  });

  testWidgets('uses explicit valid vehicleId over active vehicle', (
    tester,
  ) async {
    final first = _vehicle(id: 'vehicle-a', plate: 'AAA111');
    final second = _vehicle(
      id: 'vehicle-b',
      plate: 'BBB222',
      registrationCity: 'Medellín',
    );

    await _pumpScreen(
      tester,
      vehicles: [first, second],
      active: first,
      vehicleId: second.id,
    );

    expect(find.byKey(const ValueKey('comparendos-plate')), findsOneWidget);
    expect(find.text('Matrícula: Medellín'), findsOneWidget);
    expect(find.text('Matrícula: Bogotá'), findsNothing);
  });

  testWidgets('falls back to active vehicle without vehicleId', (tester) async {
    final first = _vehicle(id: 'vehicle-a', plate: 'AAA111');
    final active = _vehicle(id: 'vehicle-b', plate: 'ACT222');

    await _pumpScreen(tester, vehicles: [first, active], active: active);

    expect(find.byKey(const ValueKey('comparendos-plate')), findsOneWidget);
  });

  testWidgets('shows clear state without vehicle', (tester) async {
    await _pumpScreen(tester);

    expect(
      find.byKey(const ValueKey('comparendos-no-vehicle')),
      findsOneWidget,
    );
    expect(find.text('Agrega un vehículo'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparendos-go-garage')), findsOneWidget);
  });

  testWidgets('invalid explicit vehicleId fails closed without another plate', (
    tester,
  ) async {
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'AAA111');

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      vehicleId: 'missing-vehicle',
    );

    expect(
      find.byKey(const ValueKey('comparendos-no-vehicle')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('comparendos-copy-plate')), findsNothing);
  });

  testWidgets('shows plate and registration without duplicating vehicle type', (
    tester,
  ) async {
    final vehicle = _vehicle(
      plate: 'MOT123',
      kind: VehicleKind.motorcycle,
      registrationCity: 'Bogotá',
    );

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);

    expect(find.byKey(const ValueKey('comparendos-plate')), findsOneWidget);
    expect(find.text('Moto'), findsNothing);
    expect(find.text('Matrícula: Bogotá'), findsOneWidget);
  });

  testWidgets('copies plate only and shows snackbar', (tester) async {
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
    final vehicle = _vehicle(plate: 'ABC123');

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    await tester.tap(find.byKey(const ValueKey('comparendos-copy-plate')));
    await tester.pumpAndSettle();

    expect(clipboardText, 'ABC123');
    expect(find.text('Placa copiada.'), findsOneWidget);
  });

  testWidgets('opens exact SIMIT URL without plate parameters', (tester) async {
    final vehicle = _vehicle(plate: 'ABC123');

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('comparendos-open-simit')));

    expect(_launcher.opened, ['https://www.fcm.org.co/simit/']);
  });

  testWidgets('shows SIMIT launch failure visibly', (tester) async {
    _launcher.openResult = false;
    final vehicle = _vehicle();

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('comparendos-open-simit')));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('shows SIMIT launch exception visibly', (tester) async {
    _launcher.throwOnOpen = true;
    final vehicle = _vehicle();

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('comparendos-open-simit')));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens Medellín territorial URL for Medellín context', (
    tester,
  ) async {
    final vehicle = _vehicle(registrationCity: 'Bogotá');

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
      jurisdictionId: 'co-ant-medellin',
    );
    expect(find.text('Consultar en Medellín'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('comparendos-open-territorial')),
    );

    expect(_launcher.opened, [testMedellinUrl]);
  });

  testWidgets('opens Bogotá territorial URL for Bogotá context', (
    tester,
  ) async {
    final vehicle = _vehicle(registrationCity: 'Medellín');

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
      jurisdictionId: 'co-dc-bogota',
    );
    expect(find.text('Consultar en Bogotá'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('comparendos-open-territorial')),
    );

    expect(_launcher.opened, [testBogotaUrl]);
  });

  testWidgets(
    'unsupported effective city does not expose a fake territorial link',
    (tester) async {
      final vehicle = _vehicle(registrationCity: 'Bogotá');

      await _pumpScreen(
        tester,
        vehicles: [vehicle],
        active: vehicle,
        jurisdictionId: 'co-vac-cali',
      );

      expect(
        find.byKey(const ValueKey('comparendos-open-territorial')),
        findsNothing,
      );
      expect(find.text('Cali'), findsOneWidget);
      expect(
        find.textContaining('SIMIT queda disponible como consulta nacional.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('marks checked today with Bogotá date and local note', (
    tester,
  ) async {
    final vehicle = _vehicle(id: 'vehicle-a');

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    await tester.tap(find.byKey(const ValueKey('comparendos-mark-checked')));
    await tester.pumpAndSettle();

    expect(
      await _preferences.getString('comparendos.last_checked.vehicle-a'),
      '2026-09-03',
    );
    expect(find.text('Última consulta anotada: 2026-09-03'), findsOneWidget);
    expect(
      find.text(
        'Los resultados se consultan en el portal oficial. PicoRadar no obtiene tus resultados.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('dispose during delayed local note write does not throw', (
    tester,
  ) async {
    final pendingWrite = Completer<void>();
    final preferences = _DelayedSetStringPreferences(pendingWrite.future);
    _preferences = preferences;
    final vehicle = _vehicle(id: 'vehicle-a');

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    await tester.tap(find.byKey(const ValueKey('comparendos-mark-checked')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    pendingWrite.complete();
    await tester.pump();

    expect(
      await preferences.getString('comparendos.last_checked.vehicle-a'),
      '2026-09-03',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('last checked persistence stays per vehicle', (tester) async {
    final first = _vehicle(id: 'vehicle-a', plate: 'AAA111');
    final second = _vehicle(id: 'vehicle-b', plate: 'BBB222');

    await _pumpScreen(tester, vehicles: [first, second], active: first);
    await tester.tap(find.byKey(const ValueKey('comparendos-mark-checked')));
    await tester.pumpAndSettle();
    expect(find.text('Última consulta anotada: 2026-09-03'), findsOneWidget);

    await _pumpScreen(
      tester,
      vehicles: [first, second],
      active: first,
      vehicleId: second.id,
    );

    expect(find.byKey(const ValueKey('comparendos-plate')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('comparendos-last-checked')),
      findsNothing,
    );
  });

  testWidgets('never stores official result, debts or documents', (
    tester,
  ) async {
    final vehicle = _vehicle();

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    await tester.tap(find.byKey(const ValueKey('comparendos-mark-checked')));
    await tester.pumpAndSettle();

    expect(_preferences.values.keys, ['comparendos.last_checked.vehicle-a']);
    expect(find.textContaining('0 comparendos'), findsNothing);
    expect(find.textContaining('sin multas'), findsNothing);
    expect(find.textContaining('paz y salvo'), findsNothing);
    expect(find.textContaining('deuda'), findsNothing);
    expect(find.textContaining('Defensa'), findsNothing);
  });

  testWidgets(
    'target responsive viewports avoid overflow and duplicate controls',
    (tester) async {
      final vehicle = _vehicle(registrationCity: 'Medellín');
      const cases = [
        (Size(360, 800), 1.0),
        (Size(360, 800), 2.0),
        (Size(390, 844), 1.5),
        (Size(412, 915), 2.0),
      ];

      for (final testCase in cases) {
        await _pumpScreen(
          tester,
          vehicles: [vehicle],
          active: vehicle,
          size: testCase.$1,
          textScale: testCase.$2,
        );

        expect(
          find.byKey(const ValueKey('comparendos-screen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('comparendos-open-simit')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('comparendos-copy-plate')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  List<VehicleProfile> vehicles = const [],
  VehicleProfile? active,
  Future<VehicleProfile?> Function()? activeLoader,
  String? vehicleId,
  ExternalLauncher? launcher,
  Future<List<VehicleProfile>> Function(Ref ref)? vehicleList,
  String? jurisdictionId,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  if (jurisdictionId != null) {
    await _preferences.setString(picoJurisdictionPreferenceKey, jurisdictionId);
  }
  await pumpComparendos(
    tester,
    preferences: _preferences,
    vehicles: vehicles,
    active: active,
    activeLoader: activeLoader,
    vehicleId: vehicleId,
    launcher: launcher,
    vehicleLoader: vehicleList,
    size: size,
    textScale: textScale,
  );
}

VehicleProfile _vehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? registrationCity,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    registrationCity: registrationCity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  var openResult = true;
  var throwOnOpen = false;
  final opened = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    opened.add(uri);
    return openResult;
  }
}

class _DelayedSetStringPreferences extends MemoryPreferences {
  _DelayedSetStringPreferences(this.delay);

  final Future<void> delay;

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
    await delay;
  }
}
