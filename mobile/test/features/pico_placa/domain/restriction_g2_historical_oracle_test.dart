import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  const engine = RestrictionEngine();
  final ruleSet = RestrictionRuleSet(
    coverageKnown: true,
    dataIsStale: false,
    coverageCompleteness: CoverageCompleteness.partial,
    rules: [
      RestrictionRule(
        id: 'HISTORICAL_NOT_CURRENT_PARTIAL',
        jurisdictionId: 'co-dc-bogota',
        priority: 100,
        effect: RestrictionEffect.restrict,
        validFrom: DateTime(2026, 10, 29, 18),
        validUntil: DateTime(2026, 11, 3, 5, 59, 59),
        vehicleKinds: const {VehicleKind.motorcycle},
        serviceTypes: const {VehicleServiceType.private},
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        timeWindows: const [
          RestrictionTimeWindow(startMinute: 1080, endMinute: 360),
        ],
        appliesOnHolidays: true,
        conditions: const [PillionPresentCondition(true)],
        sourceUrl: 'https://www.bogotajuridica.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=194777',
      ),
    ],
    sourceUrls: const [
      'https://www.bogotajuridica.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=194777',
    ],
  );

  RestrictionEvaluation at(DateTime time, {bool? pillion}) => engine.evaluate(
    RestrictionContext(
      jurisdictionId: 'co-dc-bogota',
      plate: 'SYN123',
      vehicleKind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      registrationOrigin: RegistrationOrigin.unknown,
      localDateTime: time,
      isHoliday: false,
      coverageKnown: true,
      dataIsStale: false,
      coverageCompleteness: CoverageCompleteness.partial,
      facts: pillion == null ? null : RestrictionFacts(pillionPresent: pillion),
    ),
    ruleSet.rules,
  );

  test(
    'historical parrillero predicate restricts only its known true match',
    () {
      final trueFact = at(DateTime(2026, 10, 30, 19), pillion: true);
      final falseFact = at(DateTime(2026, 10, 30, 19), pillion: false);
      final missingFact = at(DateTime(2026, 10, 30, 19));

      expect(trueFact.status, RestrictionStatus.restricted);
      expect(trueFact.matchedRuleId, 'HISTORICAL_NOT_CURRENT_PARTIAL');
      expect(falseFact.status, RestrictionStatus.unknown);
      expect(missingFact.status, RestrictionStatus.unknown);
    },
  );

  test('historical cutoff does not become an all-day permission', () {
    final atCutoff = at(DateTime(2026, 11, 3, 6), pillion: true);
    final day = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'co-dc-bogota',
      plate: 'SYN123',
      vehicleKind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 11, 3),
      facts: const RestrictionFacts(pillionPresent: true),
    );

    expect(atCutoff.status, RestrictionStatus.unknown);
    expect(atCutoff.reasonCode, RestrictionReasonCode.partialCoverage);
    expect(day.status, RestrictionDayStatus.unknown);
    expect(
      day.effectiveWindows.map(
        (window) => (window.startMinute, window.endMinute),
      ),
      [(0, 360)],
    );
  });

  test('overnight boundaries stay normalized and known active segments remain visible', () {
    for (final sample in [
      (DateTime(2026, 10, 29, 18), RestrictionStatus.restricted),
      (DateTime(2026, 10, 30, 0), RestrictionStatus.restricted),
      (DateTime(2026, 10, 30, 5, 59), RestrictionStatus.restricted),
      (DateTime(2026, 10, 30, 6), RestrictionStatus.unknown),
      (DateTime(2026, 11, 2, 18), RestrictionStatus.restricted),
      (DateTime(2026, 11, 3, 5, 59), RestrictionStatus.restricted),
      (DateTime(2026, 11, 3, 6), RestrictionStatus.unknown),
    ]) {
      expect(
        at(sample.$1, pillion: true).status,
        sample.$2,
        reason: '${sample.$1}',
      );
    }

    final day = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'co-dc-bogota',
      plate: 'SYN123',
      vehicleKind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 10, 30),
      facts: const RestrictionFacts(pillionPresent: true),
    );

    expect(day.status, RestrictionDayStatus.unknown);
    expect(
      day.effectiveWindows.map(
        (window) => (window.startMinute, window.endMinute),
      ),
      [(0, 360), (1080, 1440)],
    );
    expect(
      restrictionPhaseAt(day, DateTime(2026, 10, 30, 0)),
      RestrictionDayPhase.active,
    );
    expect(
      restrictionPhaseAt(day, DateTime(2026, 10, 30, 5, 59)),
      RestrictionDayPhase.active,
    );
    expect(
      restrictionPhaseAt(day, DateTime(2026, 10, 30, 6)),
      RestrictionDayPhase.unknown,
    );
  });
}
