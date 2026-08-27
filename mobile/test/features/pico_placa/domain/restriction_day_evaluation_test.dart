import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  test('restriction later today still makes the day restricted', () {
    final result = _evaluate([
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
        ],
      ),
    ]);

    expect(result.status, RestrictionDayStatus.restricted);
    expect(result.effectiveWindows.single.startMinute, 300);
    expect(result.effectiveWindows.single.endMinute, 1200);
  });

  test('multiple windows are preserved', () {
    final result = _evaluate([
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 360, endMinute: 540),
          const RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
        ],
      ),
    ]);

    expect(result.status, RestrictionDayStatus.restricted);
    expect(result.effectiveWindows, hasLength(2));
  });

  test('higher priority allow override can clear part of the day', () {
    final result = _evaluate([
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
        ],
      ),
      _rule(
        id: 'allow-midday',
        priority: 200,
        effect: RestrictionEffect.allow,
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 600, endMinute: 660),
        ],
      ),
    ]);

    expect(result.status, RestrictionDayStatus.restricted);
    expect(result.effectiveWindows, hasLength(2));
  });

  test('cross-midnight window is split into day segments', () {
    final result = _evaluate([
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
        ],
      ),
    ]);

    expect(result.status, RestrictionDayStatus.restricted);
    expect(result.effectiveWindows.first.startMinute, 0);
    expect(result.effectiveWindows.first.endMinute, 120);
    expect(result.effectiveWindows.last.startMinute, 1320);
    expect(result.effectiveWindows.last.endMinute, 1440);
  });

  test('missing coverage is unknown', () {
    final result = evaluateRestrictionDay(
      ruleSet: const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      ),
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 8, 27),
    );

    expect(result.status, RestrictionDayStatus.unknown);
  });

  test('stale data wins', () {
    final result = evaluateRestrictionDay(
      ruleSet: RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: true,
        rules: [_rule()],
      ),
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 8, 27),
    );

    expect(result.status, RestrictionDayStatus.stale);
  });

  test('Bogota coverage includes 31 August but not 1 September', () {
    final ruleSet = _ruleSet(
      staleAfter: DateTime.utc(2026, 9, 1, 5),
      rules: [_rule(weekdays: {DateTime.monday})],
    );

    final covered = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 8, 31),
    );
    final stale = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 9, 1),
    );

    expect(covered.status, RestrictionDayStatus.restricted);
    expect(stale.status, RestrictionDayStatus.stale);
  });

  test('Medellin coverage includes 31 December but not 1 January 2027', () {
    final ruleSet = _ruleSet(
      staleAfter: DateTime.utc(2027, 1, 1, 5),
      rules: [_rule(weekdays: {DateTime.thursday})],
    );

    final covered = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2026, 12, 31),
    );
    final stale = evaluateRestrictionDay(
      ruleSet: ruleSet,
      jurisdictionId: 'test',
      plate: 'ABC123',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: DateTime(2027, 1, 1),
    );

    expect(covered.status, RestrictionDayStatus.restricted);
    expect(stale.status, RestrictionDayStatus.stale);
  });

  test('day without matching restriction is allowed', () {
    final result = _evaluate([
      _rule(weekdays: {DateTime.monday}),
    ]);

    expect(result.status, RestrictionDayStatus.allowed);
  });
}

RestrictionDayEvaluation _evaluate(List<RestrictionRule> rules) {
  return evaluateRestrictionDay(
    ruleSet: _ruleSet(rules: rules),
    jurisdictionId: 'test',
    plate: 'ABC123',
    vehicleKind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    date: DateTime(2026, 8, 27),
  );
}

RestrictionRuleSet _ruleSet({
  required List<RestrictionRule> rules,
  DateTime? staleAfter,
}) {
  return RestrictionRuleSet(
    coverageKnown: true,
    dataIsStale: false,
    rules: rules,
    verifiedAt: DateTime(2026, 8, 27),
    staleAfter: staleAfter,
    sourceUrls: const ['https://example.test/source'],
  );
}

RestrictionRule _rule({
  String id = 'rule',
  int priority = 100,
  RestrictionEffect effect = RestrictionEffect.restrict,
  Set<int>? weekdays,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 540),
  ],
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: 'test',
    priority: priority,
    effect: effect,
    validFrom: DateTime(2026),
    vehicleKinds: const {VehicleKind.car},
    serviceTypes: const {VehicleServiceType.private},
    weekdays: weekdays,
    digitPosition: RestrictionDigitPosition.lastNumeric,
    digits: const {3},
    timeWindows: timeWindows,
    appliesOnHolidays: true,
  );
}
