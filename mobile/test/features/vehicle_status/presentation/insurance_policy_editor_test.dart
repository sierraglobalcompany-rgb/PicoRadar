import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/insurance_policy_value.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_owner_sheets.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';

const _type = VehicleObligationType.insurance;
final _insurer = InsuranceCompany(
  id: 'fictional',
  name: 'Aseguradora ficticia',
  legalName: 'Aseguradora ficticia de pruebas S.A.',
  aliases: const [],
  website: 'https://fixture.example/',
  sourceUrl: 'https://fixture.example/source',
  reviewedAt: '2026-09-14',
  channels: const [],
  categories: const ['car'],
);

void main() {
  setUpAll(loadPlateTestFonts);
  late TestAppHarness harness;
  late VehicleObligationStore store;
  setUp(() {
    harness = TestAppHarness();
    store = VehicleObligationStore(harness.database);
  });
  tearDown(() async => harness.dispose());

  Future<VehicleProfile> car() => harness.repository.createVehicle(
    plate: 'QAQ123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    registrationCity: 'Bogot\u00e1',
  );

  Future<VehicleObligation> seed(
    VehicleProfile vehicle, {
    Map<String, String> extra = const {},
    DateTime? start,
    DateTime? due,
  }) => store.upsert(
    vehicleId: vehicle.id,
    type: _type,
    startDate: start,
    dueDate: due,
    details: {
      'providerId': 'fictional',
      'providerName': _insurer.name,
      'policyNumber': 'FICTICIA-0123456789',
      ...extra,
    },
  );

  Future<void> mount(
    WidgetTester tester,
    VehicleProfile vehicle,
    VehicleObligation? original,
  ) async {
    await harness.pump(
      tester,
      childOverride: ProviderScope(
        overrides: [
          insuranceDirectoryProvider.overrideWith(
            (_) async => InsuranceDirectory(entries: [_insurer]),
          ),
          vehicleObligationStoreProvider.overrideWithValue(store),
          vehicleRepositoryProvider.overrideWithValue(harness.repository),
          bogotaDateProvider.overrideWithValue(DateTime(2026, 9, 14)),
        ],
        child: MaterialApp(
          theme: buildPicoRadarTheme(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-editor'),
                onPressed: () =>
                    showInsuranceEditor(context, ref, vehicle, original),
                child: const Text('Abrir editor de prueba'),
              ),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, find.byKey(const ValueKey('open-editor')));
  }

  for (final source in [
    InsurancePolicyValue(minorUnits: 1, period: InsuranceValuePeriod.annual),
    InsurancePolicyValue(minorUnits: 6, period: InsuranceValuePeriod.annual),
    InsurancePolicyValue(
      minorUnits: 120000050,
      period: InsuranceValuePeriod.annual,
    ),
    InsurancePolicyValue(
      minorUnits: 99999999999999,
      period: InsuranceValuePeriod.monthly,
    ),
  ]) {
    testWidgets(
      'period viewing preserves exact source ${source.minorUnits} ${source.period.name}',
      (tester) async {
        final vehicle = await car();
        final original = await seed(vehicle, extra: source.toDetails());
        await mount(tester, vehicle, original);
        final other = source.period == InsuranceValuePeriod.annual
            ? InsuranceValuePeriod.monthly
            : InsuranceValuePeriod.annual;
        for (final period in [other, source.period, other]) {
          await _tap(
            tester,
            find.text(
              period == InsuranceValuePeriod.annual ? 'Anual' : 'Mensual',
            ),
          );
          expect(_premium(tester).controller!.text, source.inputFor(period));
        }
        await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
        final saved = (await store.get(vehicle.id, _type))!;
        for (final key in InsurancePolicyValue.detailKeys) {
          expect(saved.details[key], original.details[key], reason: key);
        }
        expect(find.text('Escribe un valor v\u00e1lido en COP.'), findsNothing);
      },
    );
  }

  testWidgets(
    'editing monthly amount persists monthly source after annual preview',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        extra: InsurancePolicyValue(
          minorUnits: 120000000,
          period: InsuranceValuePeriod.annual,
        ).toDetails(),
      );
      await mount(tester, vehicle, original);
      await _tap(tester, find.text('Mensual'));
      await _enterPremium(tester, '100.000,50');
      await _tap(tester, find.text('Anual'));
      expect(_premium(tester).controller!.text, '1200006');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = InsurancePolicyValue.fromDetails(
        (await store.get(vehicle.id, _type))!.details,
      )!;
      expect(saved.period, InsuranceValuePeriod.monthly);
      expect(saved.minorUnits, 10000050);
    },
  );

  for (final invalid in [
    '0',
    '-1',
    '1e6',
    '1.20.000',
    '1,234',
    '999999999999999',
  ]) {
    testWidgets('invalid COP input $invalid cannot save', (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original);
      await _enterPremium(tester, invalid);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(find.text('Escribe un valor v\u00e1lido en COP.'), findsOneWidget);
      expect((await store.get(vehicle.id, _type))!.details, original.details);
    });
  }

  for (final clear in [false, true]) {
    testWidgets(
      'malformed historical premium is ${clear ? 'explicitly removed' : 'preserved without edit'}',
      (tester) async {
        final vehicle = await car();
        final original = await seed(
          vehicle,
          extra: const {
            'premiumCurrency': 'UNKNOWN',
            'premiumMinorUnits': 'bad',
            'premiumPeriod': 'other',
            'futureDetail': 'preserve',
          },
        );
        await mount(tester, vehicle, original);
        await _tap(tester, find.text('Mensual'));
        if (clear) await _tap(tester, find.byTooltip('Quitar valor'));
        await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
        final saved = (await store.get(vehicle.id, _type))!;
        for (final key in InsurancePolicyValue.detailKeys) {
          expect(saved.details[key], clear ? null : original.details[key]);
        }
        expect(saved.details['futureDetail'], 'preserve');
      },
    );
  }

  testWidgets('closing premium draft and calendar clear never writes', (
    tester,
  ) async {
    final vehicle = await car();
    final original = await seed(vehicle, due: DateTime(2028, 2, 29));
    await mount(tester, vehicle, original);
    await _enterPremium(tester, '1.200.000,50');
    await _tap(tester, find.byKey(const ValueKey('insurance-editor-due')));
    await _tap(tester, find.byKey(const ValueKey('insurance-calendar-clear')));
    expect((await store.get(vehicle.id, _type))!.dueDate, original.dueDate);
    await _tap(tester, find.byTooltip('Cerrar'));
    final saved = (await store.get(vehicle.id, _type))!;
    expect(saved.details, original.details);
    expect(saved.dueDate, original.dueDate);
  });

  testWidgets(
    'calendar includes historical saved date and uses Bogota today when absent',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle, start: DateTime(1850, 4, 7));
      await mount(tester, vehicle, original);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-start')));
      var picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.initialDate, DateTime(1850, 4, 7));
      expect(picker.firstDate.isAfter(picker.initialDate!), isFalse);
      await _tap(tester, find.text('Cancelar'));
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-due')));
      picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(picker.initialDate, DateTime(2026, 9, 14));
      expect(picker.currentDate, DateTime(2026, 9, 14));
      await _tap(tester, find.text('Aceptar'));
      expect((await store.get(vehicle.id, _type))!.dueDate, isNull);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        (await store.get(vehicle.id, _type))!.dueDate,
        DateTime(2026, 9, 14),
      );
    },
  );

  testWidgets(
    'manual name requires validated dialog and cancel retains selection',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original);
      expect(
        find.byKey(const ValueKey('insurance-editor-providerName')),
        findsNothing,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('insurance-editor-insurer')),
      );
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, _insurer.name).last)
            .selected,
        isTrue,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('insurance-directory-manual')),
      );
      for (final invalid in ['', '123', 'https://fixture.example/']) {
        await tester.enterText(
          find.byKey(const ValueKey('insurance-editor-providerName')),
          invalid,
        );
        await _tap(
          tester,
          find.byKey(const ValueKey('insurance-manual-accept')),
        );
        expect(
          find.text('Escribe un nombre v\u00e1lido de aseguradora.'),
          findsOneWidget,
        );
      }
      await _tap(tester, find.text('Cancelar'));
      await _tap(tester, find.byTooltip('Cerrar').last);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect((await store.get(vehicle.id, _type))!.details, original.details);
    },
  );

  testWidgets('collapsed optional phones retain all saved values and count', (
    tester,
  ) async {
    final vehicle = await car();
    final original = await seed(
      vehicle,
      extra: const {'assistancePhone': '#123', 'towPhone': '6011234567 ext. 2'},
    );
    await mount(tester, vehicle, original);
    expect(
      find.byKey(const ValueKey('insurance-editor-towPhone')),
      findsNothing,
    );
    expect(find.text('2 guardados'), findsOneWidget);
    await _tap(
      tester,
      find.byKey(const ValueKey('insurance-editor-phones-toggle')),
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('insurance-editor-towPhone')),
          )
          .controller!
          .text,
      '6011234567 ext. 2',
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('insurance-editor-phones-toggle')),
    );
    await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
    expect((await store.get(vehicle.id, _type))!.details, original.details);
  });
}

TextFormField _premium(WidgetTester tester) => tester.widget<TextFormField>(
  find.byKey(const ValueKey('insurance-editor-premium')),
);

Future<void> _enterPremium(WidgetTester tester, String value) async {
  final field = find.byKey(const ValueKey('insurance-editor-premium'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
