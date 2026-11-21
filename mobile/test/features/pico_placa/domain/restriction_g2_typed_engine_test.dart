import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  const engine = RestrictionEngine();

  RestrictionEvaluation evaluate({
    required RestrictionCondition condition,
    RestrictionFacts? facts,
    CoverageCompleteness completeness = CoverageCompleteness.partial,
    DateTime? at,
  }) {
    return engine.evaluate(
      RestrictionContext(
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationOrigin: RegistrationOrigin.local,
        localDateTime: at ?? DateTime(2026, 11, 10, 7),
        isHoliday: false,
        coverageKnown: true,
        dataIsStale: false,
        coverageCompleteness: completeness,
        facts: facts,
      ),
      [
        RestrictionRule(
          id: 'g2-synthetic-rule',
          jurisdictionId: 'co-g2-synthetic',
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026, 11, 10),
          validUntil: DateTime(2026, 11, 19, 23, 59, 59),
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 360, endMinute: 480),
          ],
          appliesOnHolidays: false,
          conditions: [condition],
        ),
      ],
    );
  }

  test(
    'pillion false and unknown are not broad permission in partial coverage',
    () {
      final noPassenger = evaluate(
        condition: const PillionPresentCondition(true),
        facts: const RestrictionFacts(pillionPresent: false),
      );
      final missing = evaluate(condition: const PillionPresentCondition(true));

      expect(noPassenger.status, RestrictionStatus.unknown);
      expect(missing.status, RestrictionStatus.unknown);
    },
  );

  test(
    'occupants_below uses strict less-than and fails closed at threshold',
    () {
      final one = evaluate(
        condition: const OccupantsBelowCondition(3),
        facts: const RestrictionFacts(occupantsCount: 1),
      );
      final two = evaluate(
        condition: const OccupantsBelowCondition(3),
        facts: const RestrictionFacts(occupantsCount: 2),
      );
      final three = evaluate(
        condition: const OccupantsBelowCondition(3),
        facts: const RestrictionFacts(occupantsCount: 3),
      );
      final missing = evaluate(condition: const OccupantsBelowCondition(3));

      expect(one.status, RestrictionStatus.restricted);
      expect(two.status, RestrictionStatus.restricted);
      expect(three.status, RestrictionStatus.unknown);
      expect(missing.status, RestrictionStatus.unknown);
    },
  );

  test('occupants_at_least remains a separate inclusive predicate', () {
    final three = evaluate(
      condition: const OccupantsAtLeastCondition(3),
      facts: const RestrictionFacts(occupantsCount: 3),
    );
    final two = evaluate(
      condition: const OccupantsAtLeastCondition(3),
      facts: const RestrictionFacts(occupantsCount: 2),
    );

    expect(three.status, RestrictionStatus.restricted);
    expect(two.status, RestrictionStatus.unknown);
  });

  test('weight and axle predicates require valid typed facts', () {
    final weighted = evaluate(
      condition: const GrossWeightKgGreaterThanCondition(8500),
      facts: const RestrictionFacts(grossVehicleWeightKg: 8501),
    );
    final atBoundary = evaluate(
      condition: const GrossWeightKgGreaterThanCondition(8500),
      facts: const RestrictionFacts(grossVehicleWeightKg: 8500),
    );
    final axles = evaluate(
      condition: const AxlesAtLeastCondition(3),
      facts: const RestrictionFacts(axleCount: 3),
    );
    final invalid = evaluate(
      condition: const AxlesAtLeastCondition(3),
      facts: const RestrictionFacts(axleCount: 0),
    );

    expect(weighted.status, RestrictionStatus.restricted);
    expect(atBoundary.status, RestrictionStatus.unknown);
    expect(axles.status, RestrictionStatus.restricted);
    expect(invalid.status, RestrictionStatus.unknown);
  });

  test(
    'scope membership requires exact id, version, and accepted provenance',
    () {
      final inside = evaluate(
        condition: const InsideScopeRefCondition('zone-1@v2'),
        facts: const RestrictionFacts(
          spatialEvidence: SpatialEvidence(
            scopeId: 'zone-1',
            scopeVersion: 'v2',
            membership: SpatialMembership.inside,
            provenance: SpatialEvidenceProvenance.syntheticContext,
          ),
        ),
      );
      final wrongVersion = evaluate(
        condition: const InsideScopeRefCondition('zone-1@v2'),
        facts: const RestrictionFacts(
          spatialEvidence: SpatialEvidence(
            scopeId: 'zone-1',
            scopeVersion: 'v1',
            membership: SpatialMembership.inside,
            provenance: SpatialEvidenceProvenance.syntheticContext,
          ),
        ),
      );
      final untrusted = evaluate(
        condition: const InsideScopeRefCondition('zone-1@v2'),
        facts: const RestrictionFacts(
          spatialEvidence: SpatialEvidence(
            scopeId: 'zone-1',
            scopeVersion: 'v2',
            membership: SpatialMembership.inside,
            provenance: SpatialEvidenceProvenance.untrusted,
          ),
        ),
      );
      final outside = evaluate(
        condition: const InsideScopeRefCondition('zone-1@v2'),
        facts: const RestrictionFacts(
          spatialEvidence: SpatialEvidence(
            scopeId: 'zone-1',
            scopeVersion: 'v2',
            membership: SpatialMembership.outside,
            provenance: SpatialEvidenceProvenance.syntheticContext,
          ),
        ),
      );

      expect(inside.status, RestrictionStatus.restricted);
      expect(wrongVersion.status, RestrictionStatus.unknown);
      expect(untrusted.status, RestrictionStatus.unknown);
      expect(outside.status, RestrictionStatus.unknown);
    },
  );

  test(
    'invalid numeric facts stay unknown rather than permitting circulation',
    () {
      for (final facts in const [
        RestrictionFacts(occupantsCount: 0),
        RestrictionFacts(occupantsCount: 100),
        RestrictionFacts(grossVehicleWeightKg: 100001),
        RestrictionFacts(axleCount: 21),
      ]) {
        final condition = facts.occupantsCount != null
            ? const OccupantsBelowCondition(3)
            : facts.grossVehicleWeightKg != null
            ? const GrossWeightKgGreaterThanCondition(8500)
            : const AxlesAtLeastCondition(3);
        expect(
          evaluate(condition: condition, facts: facts).status,
          RestrictionStatus.unknown,
        );
      }
    },
  );

  test('full-day windows use a 06:00 anchor through the next morning', () {
    final rule = _fullDayRule(
      weekdays: {DateTime.monday},
      appliesOnHolidays: true,
    );

    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 9, 5, 59)).status,
      RestrictionStatus.allowed,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 9, 6)).status,
      RestrictionStatus.restricted,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 10, 2)).status,
      RestrictionStatus.restricted,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 10, 5, 59)).status,
      RestrictionStatus.restricted,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 10, 6)).status,
      RestrictionStatus.allowed,
    );
  });

  test('full-day Friday tail uses its anchor validity and weekday', () {
    final rule = _fullDayRule(
      weekdays: {DateTime.friday},
      validFrom: DateTime(2026, 11, 13, 6),
      validUntil: DateTime(2026, 11, 13, 23, 59, 59),
      appliesOnHolidays: true,
    );

    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 13, 5, 59)).status,
      RestrictionStatus.allowed,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 13, 6)).status,
      RestrictionStatus.restricted,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 14, 2)).status,
      RestrictionStatus.restricted,
    );
    expect(
      _evaluateFullDay(rule, DateTime(2026, 11, 14, 6)).status,
      RestrictionStatus.allowed,
    );
  });

  test('full-day windows evaluate validity and holidays per window anchor', () {
    final mondayAfterTen = _fullDayRule(
      weekdays: {DateTime.monday},
      validFrom: DateTime(2026, 11, 9, 10),
      appliesOnHolidays: true,
      timeWindows: const [
        RestrictionTimeWindow(startMinute: 360, endMinute: 360, fullDay: true),
        RestrictionTimeWindow(startMinute: 720, endMinute: 720, fullDay: true),
      ],
    );
    expect(
      _evaluateFullDay(mondayAfterTen, DateTime(2026, 11, 10, 2)).status,
      RestrictionStatus.restricted,
    );

    final mondayNoHoliday = _fullDayRule(
      weekdays: {DateTime.monday},
      appliesOnHolidays: false,
    );
    expect(
      _evaluateFullDay(
        mondayNoHoliday,
        DateTime(2026, 11, 10, 2),
        isHolidayOnDate: (date) => date.weekday == DateTime.monday,
      ).status,
      RestrictionStatus.allowed,
    );
    expect(
      _evaluateFullDay(mondayNoHoliday, DateTime(2026, 11, 10, 2)).status,
      RestrictionStatus.unknown,
    );
  });

  test('partial coverage and unknown geography never become allowed', () {
    final rule = _fullDayRule(
      weekdays: {DateTime.monday},
      appliesOnHolidays: true,
      conditions: const [InsideScopeRefCondition('scope@v1')],
    );
    expect(
      _evaluateFullDay(
        rule,
        DateTime(2026, 11, 9, 7),
        completeness: CoverageCompleteness.partial,
      ).status,
      RestrictionStatus.unknown,
    );
    expect(
      _evaluateFullDay(
        rule,
        DateTime(2026, 11, 10, 7),
        completeness: CoverageCompleteness.partial,
      ).status,
      RestrictionStatus.unknown,
    );
  });

  test(
    'legacy empty rules are unknown without positive no-measure evidence',
    () {
      final result = engine.evaluate(
        RestrictionContext(
          jurisdictionId: 'co-g2-synthetic',
          plate: 'ABC123',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          registrationOrigin: RegistrationOrigin.local,
          localDateTime: DateTime(2026, 11, 10, 7),
          isHoliday: false,
          coverageKnown: true,
          dataIsStale: false,
        ),
        const [],
      );

      expect(result.status, RestrictionStatus.unknown);
      expect(result.reasonCode, RestrictionReasonCode.unknownCoverage);
    },
  );
}

RestrictionEvaluation _evaluateFullDay(
  RestrictionRule rule,
  DateTime at, {
  bool isHoliday = false,
  bool Function(DateTime date)? isHolidayOnDate,
  CoverageCompleteness completeness = CoverageCompleteness.complete,
}) {
  return const RestrictionEngine().evaluate(
    RestrictionContext(
      jurisdictionId: 'co-g2-synthetic',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationOrigin: RegistrationOrigin.local,
      localDateTime: at,
      isHoliday: isHoliday,
      coverageKnown: true,
      dataIsStale: false,
      coverageCompleteness: completeness,
      isHolidayOnDate: isHolidayOnDate,
    ),
    [rule],
  );
}

RestrictionRule _fullDayRule({
  Set<int>? weekdays,
  DateTime? validFrom,
  DateTime? validUntil,
  bool appliesOnHolidays = false,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 360, fullDay: true),
  ],
  List<RestrictionCondition> conditions = const [],
}) => RestrictionRule(
  id: 'g2-full-day-rule',
  jurisdictionId: 'co-g2-synthetic',
  priority: 100,
  effect: RestrictionEffect.restrict,
  validFrom: validFrom ?? DateTime(2026, 11, 1),
  validUntil: validUntil ?? DateTime(2026, 11, 30, 23, 59, 59),
  vehicleKinds: const {VehicleKind.car},
  serviceTypes: const {VehicleServiceType.private},
  weekdays: weekdays,
  digitPosition: RestrictionDigitPosition.lastNumeric,
  digits: const {3},
  conditions: conditions,
  timeWindows: timeWindows,
  appliesOnHolidays: appliesOnHolidays,
);
