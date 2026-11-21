import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  const engine = RestrictionEngine();
  late Map<String, Map<String, dynamic>> territories;

  setUpAll(() async {
    final fixture = jsonDecode(
      await File(
        'test/fixtures/restriction_national_data_driven_test_only.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    territories = {
      for (final value in fixture['territories'] as List<dynamic>)
        (value as Map<String, dynamic>)['id'] as String: value,
    };
  });

  Map<String, dynamic> territory(String id) => territories[id]!;

  test('one engine changes decisions when only jurisdiction data changes', () {
    final territoryA = territory('co-test-a');
    final originalRules = _rules(territoryA);
    final restricted = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'ABC124',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
      ),
      originalRules,
    );

    final updatedTerritory =
        jsonDecode(jsonEncode(territoryA)) as Map<String, dynamic>;
    updatedTerritory['rules'][0]['digits'] = [1];
    updatedTerritory['rules'][0]['id'] = 'test-a-car-private-v2';
    final updatedRules = _rules(updatedTerritory);
    final noLongerMatched = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'ABC124',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
      ),
      updatedRules,
    );
    final newlyMatched = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'ABC121',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
      ),
      updatedRules,
    );

    expect(restricted.status, RestrictionStatus.restricted);
    expect(noLongerMatched.status, RestrictionStatus.unknown);
    expect(newlyMatched.status, RestrictionStatus.restricted);
    expect(newlyMatched.matchedRuleId, 'test-a-car-private-v2');
  });

  test('jurisdiction and kind/service dimensions stay isolated', () {
    final territoryA = territory('co-test-a');
    final territoryB = territory('co-test-b');
    final ruleA = _rules(territoryA);
    final ruleB = _rules(territoryB);

    final taxiAgainstPrivateCarRule = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'ABC124',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
      ),
      ruleA,
    );
    final territoryARuleAgainstTerritoryB = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'MOT323',
        vehicleKind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
      ),
      ruleB,
    );
    final territoryBMotorcycle = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-b',
        plate: 'MOT323',
        vehicleKind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
      ),
      ruleB,
    );

    expect(taxiAgainstPrivateCarRule.status, RestrictionStatus.unknown);
    expect(territoryARuleAgainstTerritoryB.status, RestrictionStatus.unknown);
    expect(territoryBMotorcycle.status, RestrictionStatus.restricted);
  });

  test('unresearched and stale coverage remain unknown and stale', () {
    final unknown = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-unresearched',
        plate: 'ABC124',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        coverageKnown: false,
      ),
      const [],
    );
    final stale = engine.evaluate(
      _context(
        jurisdictionId: 'co-test-a',
        plate: 'ABC124',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        dataIsStale: true,
      ),
      _rules(territory('co-test-a')),
    );

    expect(unknown.status, RestrictionStatus.unknown);
    expect(stale.status, RestrictionStatus.stale);
  });
}

List<RestrictionRule> _rules(Map<String, dynamic> territory) =>
    restrictionRulesFromJson(
      jsonEncode(territory['rules']),
      jurisdictionId: territory['id'] as String,
      vehicleKind: VehicleKind.fromValue(territory['vehicleKind'] as String),
      serviceType: VehicleServiceType.fromValue(
        territory['serviceType'] as String,
      ),
      schemaVersion: 2,
    );

RestrictionContext _context({
  required String jurisdictionId,
  required String plate,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
  bool coverageKnown = true,
  bool dataIsStale = false,
}) => RestrictionContext(
  jurisdictionId: jurisdictionId,
  plate: plate,
  vehicleKind: vehicleKind,
  serviceType: serviceType,
  registrationOrigin: RegistrationOrigin.unknown,
  localDateTime: DateTime(2026, 11, 9, 8),
  isHoliday: false,
  coverageKnown: coverageKnown,
  dataIsStale: dataIsStale,
  coverageCompleteness: CoverageCompleteness.partial,
);
