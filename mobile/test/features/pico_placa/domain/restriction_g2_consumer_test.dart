import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/city_restriction_summary.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  test(
    'partial schema2 day stays unknown when a conditional rule does not match',
    () {
      final evaluation = evaluateRestrictionDay(
        ruleSet: _partialSet(),
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime(2026, 11, 10),
      );

      expect(evaluation.status, RestrictionDayStatus.unknown);
    },
  );

  test('personal partial scope without certified evidence stays unknown', () {
    final evaluation = evaluateRestrictionDay(
      ruleSet: _partialSet(),
      jurisdictionId: 'co-g2-synthetic',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 11, 10),
      facts: const RestrictionFacts(),
    );

    expect(evaluation.status, RestrictionDayStatus.unknown);
  });

  test(
    'SYNTHETIC_ONLY outside scope without trusted evidence stays unknown',
    () {
      final evaluation = evaluateRestrictionDay(
        ruleSet: _partialSet(),
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime(2026, 11, 10),
        facts: const RestrictionFacts(
          spatialEvidence: SpatialEvidence(
            scopeId: 'synthetic-zone',
            scopeVersion: 'v1',
            membership: SpatialMembership.outside,
            provenance: SpatialEvidenceProvenance.untrusted,
          ),
        ),
      );

      expect(evaluation.status, RestrictionDayStatus.unknown);
    },
  );

  test(
    'partial holiday with unverified holiday rule stays personally unknown',
    () {
      final evaluation = evaluateRestrictionDay(
        ruleSet: _partialSet(
          rules: [
            RestrictionRule(
              id: 'holiday-scope-rule',
              jurisdictionId: 'co-g2-synthetic',
              priority: 100,
              effect: RestrictionEffect.restrict,
              validFrom: DateTime(2026, 1, 1),
              validUntil: DateTime(2026, 12, 31, 23, 59, 59),
              vehicleKinds: const {VehicleKind.car},
              serviceTypes: const {VehicleServiceType.private},
              weekdays: const {DateTime.thursday},
              digitPosition: RestrictionDigitPosition.lastNumeric,
              digits: const {3, 4},
              timeWindows: const [
                RestrictionTimeWindow(startMinute: 360, endMinute: 1200),
              ],
              appliesOnHolidays: false,
              conditions: const [InsideScopeRefCondition('scope@holiday-lab')],
            ),
          ],
        ),
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime(2026, 1, 1),
      );

      expect(evaluation.status, RestrictionDayStatus.unknown);
    },
  );

  test(
    'partial mismatched service never inherits a personal calendar result',
    () {
      final evaluation = evaluateRestrictionDay(
        ruleSet: _partialSet(),
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
        date: DateTime(2026, 11, 10),
      );

      expect(evaluation.status, RestrictionDayStatus.unknown);
    },
  );

  test('partial schema2 with no rules never implies an all-day permission', () {
    final evaluation = evaluateRestrictionDay(
      ruleSet: _partialSet(rules: const []),
      jurisdictionId: 'co-g2-synthetic',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 11, 10),
    );

    expect(evaluation.status, RestrictionDayStatus.unknown);
  });

  test(
    'expired partial schema2 coverage stays stale before empty-data unknown',
    () {
      final evaluation = evaluateRestrictionDay(
        ruleSet: _partialSet(rules: const []),
        jurisdictionId: 'co-g2-synthetic',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime(2026, 11, 21),
      );

      expect(evaluation.status, RestrictionDayStatus.stale);
    },
  );

  test(
    'partial city calendar exposes information without changing unknown status',
    () {
      final ruleSet = _partialSet();
      final day = summarizeCityRestrictionDay(
        ruleSet: ruleSet,
        jurisdictionId: 'co-g2-synthetic',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 11, 10),
      );
      final rotation = summarizeCityRestrictionRotation(
        ruleSet: ruleSet,
        jurisdictionId: 'co-g2-synthetic',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 11, 10),
      );
      final ruleSummary = summarizeCityRestrictionRules(
        ruleSet: ruleSet,
        jurisdictionId: 'co-g2-synthetic',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 11, 10),
      );

      expect(day.status, RestrictionDayStatus.unknown);
      expect(day.publishedScheduleInformational, isTrue);
      expect(day.restrictedDigits, [3, 4]);
      expect(day.effectiveWindows.single.startMinute, 360);
      expect(ruleSummary.isConditional, isTrue);
      expect(ruleSummary.publishedScheduleInformational, isTrue);
      expect(ruleSummary.generalWindows.single.startMinute, 360);
      expect(ruleSummary.digitBasis, CityRestrictionDigitBasis.lastNumeric);
      expect(rotation.rows, hasLength(7));
      expect(
        rotation.rows.map((row) => row.status),
        everyElement(RestrictionDayStatus.unknown),
      );
      expect(rotation.rows[0].digits, [3, 4]);
      expect(
        rotation.rows
            .where((row) => row.date?.weekday != DateTime.tuesday)
            .every((row) => row.digits.isEmpty),
        isTrue,
      );
    },
  );

  test('complete coverage without conditional predicates preserves calendar result', () {
    final ruleSet = _partialSet(
      completeness: CoverageCompleteness.complete,
      rules: const [],
    );
    final day = summarizeCityRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'co-g2-synthetic',
      category: PicoVehicleCategory.cars,
      date: DateTime(2026, 11, 10),
    );

    expect(day.status, RestrictionDayStatus.allowed);
  });
}

RestrictionRuleSet _partialSet({
  CoverageCompleteness completeness = CoverageCompleteness.partial,
  List<RestrictionRule>? rules,
}) => RestrictionRuleSet(
  coverageKnown: true,
  dataIsStale: false,
  coverageCompleteness: completeness,
  rules:
      rules ??
      [
        RestrictionRule(
          id: 'conditional-rule',
          jurisdictionId: 'co-g2-synthetic',
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026, 11, 10),
          vehicleKinds: const {VehicleKind.car},
          serviceTypes: const {VehicleServiceType.private},
          weekdays: const {DateTime.tuesday},
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: const {3, 4},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 360, endMinute: 480),
          ],
          appliesOnHolidays: false,
          conditions: const [
            PillionPresentCondition(true),
            InsideScopeRefCondition('scope@lab-v1'),
          ],
        ),
      ],
  verifiedAt: DateTime.utc(2026, 11, 10),
  staleAfter: DateTime.utc(2026, 11, 20),
  sourceUrls: const ['https://example.test/synthetic'],
);
