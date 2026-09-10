import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/city_restriction_summary.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';

import '../../../test_app_harness.dart';

void main() {
  final dataset = jsonDecode(
    File('assets/datasets/restrictions/restrictions_v1.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final now = DateTime(2026, 9, 10, 13);
  final instant = DateTime.utc(2026, 9, 10, 18);

  test(
    'installed pack, manual cities, Home and Pico agree for both plates',
    () async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      await importRestrictionsDataset(harness.database, dataset);
      final vehicles = [
        await harness.repository.createVehicle(
          plate: 'BOG126',
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationCity: 'Bogota',
        ),
        await harness.repository.createVehicle(
          plate: 'MED124',
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationCity: 'Medellin',
        ),
      ];
      final store = RestrictionStore(harness.database);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(harness.database),
          appPreferencesProvider.overrideWithValue(harness.preferences),
          bundledRestrictionsProvider.overrideWith((ref) async {}),
          currentInstantProvider.overrideWithValue(instant),
          bogotaNowProvider.overrideWithValue(now),
        ],
      );
      addTearDown(container.dispose);
      final jurisdictions = await store.listJurisdictions();
      await container.read(locationStateProvider.future);

      for (final scenario in [
        (id: 'co-ant-medellin', digits: [3, 6], start: 300, end: 1200),
        (id: 'co-dc-bogota', digits: [1, 2, 3, 4, 5], start: 360, end: 1260),
        (id: 'co-san-bucaramanga', digits: [3, 4], start: 360, end: 1200),
        (id: 'co-cal-manizales', digits: [5, 6], start: 300, end: 1320),
      ]) {
        final city = jurisdictions.singleWhere((j) => j.id == scenario.id);
        await container.read(locationStateProvider.notifier).selectManual(city);
        expect(
          await container.read(selectedPicoJurisdictionIdProvider.future),
          city.id,
        );
        final coverage = await store.loadCoverage(
          city.id,
          VehicleKind.car,
          VehicleServiceType.private,
          instant,
        );
        final collective = summarizeCityRestrictionDay(
          ruleSet: coverage,
          jurisdictionId: city.id,
          category: PicoVehicleCategory.cars,
          date: now,
        );
        expect(collective.restrictedDigits, scenario.digits, reason: city.id);
        expect(collective.effectiveWindows.single.startMinute, scenario.start);
        expect(collective.effectiveWindows.single.endMinute, scenario.end);
        final home = await container.read(
          homeVehicleSnapshotsProvider(
            HomeVehicleSnapshotsRequest(
              vehicles: vehicles,
              selectedJurisdiction: city,
            ),
          ).future,
        );
        for (var i = 0; i < vehicles.length; i++) {
          final vehicle = vehicles[i];
          final expected = scenario.digits.contains(i == 0 ? 6 : 4)
              ? RestrictionDayStatus.restricted
              : RestrictionDayStatus.allowed;
          final personal = evaluateRestrictionDay(
            ruleSet: coverage,
            jurisdictionId: city.id,
            plate: vehicle.plate,
            vehicleKind: vehicle.kind,
            serviceType: vehicle.serviceType,
            date: now,
          );
          expect(
            home[i].today.status,
            expected,
            reason: '${city.id} vehicle $i',
          );
          expect(personal.status, expected);
          expect(
            restrictionPhaseAt(home[i].today, now),
            expected == RestrictionDayStatus.restricted
                ? RestrictionDayPhase.active
                : RestrictionDayPhase.unrestricted,
          );
          expect(
            formatRestrictionWindows12(home[i].today.effectiveWindows),
            formatRestrictionWindows12(personal.effectiveWindows),
          );
        }
      }
      expect(
        (await harness.repository.listVehicles()).map(
          (v) => v.registrationCity,
        ),
        containsAll(['Bogota', 'Medellin']),
      );
    },
  );

  test(
    'pack does not turn missing vehicle coverage or expired data green',
    () async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      await importRestrictionsDataset(harness.database, dataset);
      final store = RestrictionStore(harness.database);
      final missing = await store.loadCoverage(
        'co-cal-manizales',
        VehicleKind.motorcycle,
        VehicleServiceType.private,
        instant,
      );
      final stale = await store.loadCoverage(
        'co-cal-manizales',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime.utc(2026, 9, 14, 18),
      );
      expect(
        summarizeCityRestrictionDay(
          ruleSet: missing,
          jurisdictionId: 'co-cal-manizales',
          category: PicoVehicleCategory.motorcycles,
          date: now,
        ).status,
        RestrictionDayStatus.unknown,
      );
      expect(
        evaluateRestrictionDay(
          ruleSet: stale,
          jurisdictionId: 'co-cal-manizales',
          plate: 'BOG126',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          date: DateTime(2026, 9, 14),
        ).status,
        RestrictionDayStatus.stale,
      );
    },
  );
}
