import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/domain/vehicle_month_evaluation.dart';

void main() {
  test('evaluates a whole month from the restriction engine', () {
    final days = evaluateVehicleMonth(
      ruleSet: RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: false,
        verifiedAt: DateTime(2026, 8, 1),
        sourceUrls: const ['https://example.gov/rule'],
        rules: [
          RestrictionRule(
            id: 'fixture-tuesday-3',
            jurisdictionId: 'fixture-city',
            priority: 10,
            effect: RestrictionEffect.restrict,
            validFrom: DateTime(2026, 9),
            vehicleKinds: {VehicleKind.car},
            serviceTypes: {VehicleServiceType.private},
            weekdays: {DateTime.tuesday},
            digitPosition: RestrictionDigitPosition.lastNumeric,
            digits: {3},
            timeWindows: [
              RestrictionTimeWindow(startMinute: 360, endMinute: 540),
            ],
            appliesOnHolidays: false,
            sourceUrl: 'https://example.gov/rule',
          ),
        ],
      ),
      jurisdictionId: 'fixture-city',
      vehicle: _vehicle('ABC123'),
      year: 2026,
      month: 9,
    );

    expect(days, hasLength(30));
    expect(days.first.date.weekday, DateTime.tuesday);
    expect(
      days
          .where(
            (day) => day.evaluation.status == RestrictionDayStatus.restricted,
          )
          .map((day) => day.date.day),
      [1, 8, 15, 22, 29],
    );
    expect(
      days.singleWhere((day) => day.date.day == 2).evaluation.status,
      RestrictionDayStatus.allowed,
    );
  });

  test('fails closed as unknown when coverage is not known', () {
    final days = evaluateVehicleMonth(
      ruleSet: const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      ),
      jurisdictionId: 'fixture-city',
      vehicle: _vehicle('ABC123'),
      year: 2026,
      month: 9,
    );

    expect(days, hasLength(30));
    expect(days.map((day) => day.evaluation.status).toSet(), {
      RestrictionDayStatus.unknown,
    });
  });
}

VehicleProfile _vehicle(String plate) {
  return VehicleProfile(
    id: 'vehicle-1',
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
