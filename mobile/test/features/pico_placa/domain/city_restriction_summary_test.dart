import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/city_restriction_summary.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  test(
    'cached city coverage cannot outlive its timestamp or future horizon',
    () {
      final cached = _ruleSet(
        staleAfter: DateTime.utc(2026, 9, 10, 17),
        rules: [_rule()],
      );
      for (final hour in [11, 12, 13]) {
        final date = DateTime(2026, 9, 10, hour);
        final day = summarizeCityRestrictionDay(
          ruleSet: cached,
          jurisdictionId: 'co-dc-bogota',
          category: PicoVehicleCategory.cars,
          date: date,
        );
        expect(day.status, RestrictionDayStatus.stale);
        final rules = summarizeCityRestrictionRules(
          ruleSet: cached,
          jurisdictionId: 'co-dc-bogota',
          category: PicoVehicleCategory.cars,
          date: date,
        );
        expect(rules.dataIsStale, isTrue);
        expect(rules.generalWindows, isEmpty);
      }
      final rotation = summarizeCityRestrictionRotation(
        ruleSet: cached,
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 9, 9),
      );
      expect(rotation.isWeekly, isFalse);
      expect(rotation.rows.first.status, RestrictionDayStatus.allowed);
      expect(
        rotation.rows.skip(1).map((row) => row.status),
        everyElement(RestrictionDayStatus.stale),
      );
    },
  );

  group('summarizeCityRestrictionDay', () {
    test('reports restricted digits and time windows from real rules', () {
      final summary = summarizeCityRestrictionDay(
        ruleSet: _ruleSet(
          rules: [
            _rule(
              weekdays: {DateTime.thursday},
              digits: {3, 4},
              windows: const [
                RestrictionTimeWindow(startMinute: 360, endMinute: 540),
                RestrictionTimeWindow(startMinute: 960, endMinute: 1140),
              ],
            ),
          ],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 27),
      );

      expect(summary.status, RestrictionDayStatus.restricted);
      expect(summary.ruleLabel, 'Último dígito 3 y 4');
      expect(summary.effectiveWindows, hasLength(2));
    });

    test('reports allowed when no rule matches the date', () {
      final summary = summarizeCityRestrictionDay(
        ruleSet: _ruleSet(
          rules: [
            _rule(weekdays: {DateTime.monday}, digits: {3}),
          ],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 27),
      );

      expect(summary.status, RestrictionDayStatus.allowed);
      expect(summary.ruleLabel, 'Sin restricción');
    });

    test('reports holiday without applying non-holiday rules', () {
      final summary = summarizeCityRestrictionDay(
        ruleSet: _ruleSet(
          rules: [
            _rule(
              weekdays: {DateTime.thursday},
              digits: {3},
              appliesOnHolidays: false,
            ),
          ],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 1, 1),
      );

      expect(summary.status, RestrictionDayStatus.allowed);
      expect(summary.ruleLabel, 'Festivo sin restricción');
    });

    test('reports stale data as non-green status', () {
      final summary = summarizeCityRestrictionDay(
        ruleSet: _ruleSet(dataIsStale: true),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 27),
      );

      expect(summary.status, RestrictionDayStatus.stale);
      expect(summary.ruleLabel, 'Datos por actualizar');
    });

    test('reports unknown when coverage is missing', () {
      final summary = summarizeCityRestrictionDay(
        ruleSet: const RestrictionRuleSet(
          coverageKnown: false,
          dataIsStale: false,
          rules: [],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.motorcycles,
        date: DateTime(2026, 8, 27),
      );

      expect(summary.status, RestrictionDayStatus.unknown);
      expect(summary.ruleLabel, 'Sin cobertura verificada');
    });
  });

  test('plateBasisLabel uses the applicable digit position', () {
    final vehicle = VehicleProfile(
      id: '1',
      plate: 'ABC123',
      kind: VehicleKind.motorcycle,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(
      plateBasisLabel(
        _ruleSet(
          rules: [
            _rule(
              vehicleKinds: {VehicleKind.motorcycle},
              digitPosition: RestrictionDigitPosition.firstNumeric,
              digits: {1},
            ),
          ],
        ),
        vehicle,
      ),
      'Primer número 1',
    );
  });

  group('P04 city comprehension helpers', () {
    test('summarizes weekly last-digit rules without duplicating data', () {
      final ruleSet = _ruleSet(
        rules: [
          _rule(weekdays: {DateTime.monday}, digits: {5, 8}),
          _rule(weekdays: {DateTime.tuesday}, digits: {1, 4}),
        ],
      );

      final summary = summarizeCityRestrictionRules(
        ruleSet: ruleSet,
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 31),
      );
      final rotation = summarizeCityRestrictionRotation(
        ruleSet: ruleSet,
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 31),
      );

      expect(summary.digitBasis, CityRestrictionDigitBasis.lastNumeric);
      expect(summary.generalWindows.single.startMinute, 360);
      expect(summary.hasUniformSchedule, isTrue);
      expect(rotation.title, 'Rotación vigente');
      expect(rotation.isWeekly, isTrue);
      expect(rotation.rows.first.label, 'Lunes');
      expect(rotation.rows.first.digits, [5, 8]);
      expect(rotation.rows[5].status, RestrictionDayStatus.allowed);
    });

    test('summarizes weekly first-number motorcycle rules', () {
      final summary = summarizeCityRestrictionRules(
        ruleSet: _ruleSet(
          rules: [
            _rule(
              vehicleKinds: {VehicleKind.motorcycle},
              digitPosition: RestrictionDigitPosition.firstNumeric,
              digits: {5, 8},
            ),
          ],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.motorcycles,
        date: DateTime(2026, 8, 31),
      );

      expect(summary.category, PicoVehicleCategory.motorcycles);
      expect(summary.digitBasis, CityRestrictionDigitBasis.firstNumeric);
    });

    test('date-parity rules render a seven-day date matrix', () {
      final rotation = summarizeCityRestrictionRotation(
        ruleSet: _ruleSet(
          rules: [
            _rule(
              weekdays: null,
              dateParity: RestrictionDateParity.odd,
              digits: {1, 3, 5, 7, 9},
            ),
            _rule(
              weekdays: null,
              dateParity: RestrictionDateParity.even,
              digits: {0, 2, 4, 6, 8},
            ),
          ],
        ),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 31),
      );

      expect(rotation.title, 'Próximos 7 días');
      expect(rotation.isWeekly, isFalse);
      expect(rotation.rows, hasLength(7));
      expect(rotation.rows.first.digits, [1, 3, 5, 7, 9]);
      expect(rotation.rows[1].digits, [1, 3, 5, 7, 9]);
      expect(rotation.rows[2].digits, [0, 2, 4, 6, 8]);
    });

    test('taxi without coverage fails closed with explicit unknown rows', () {
      final rotation = summarizeCityRestrictionRotation(
        ruleSet: const RestrictionRuleSet(
          coverageKnown: false,
          dataIsStale: false,
          rules: [],
        ),
        jurisdictionId: 'co-ant-medellin',
        category: PicoVehicleCategory.taxis,
        date: DateTime(2026, 8, 31),
      );

      expect(rotation.isWeekly, isFalse);
      expect(rotation.rows.first.status, RestrictionDayStatus.unknown);
      expect(rotation.rows.first.digits, isEmpty);
    });

    test('stale data never reports a green rule summary', () {
      final summary = summarizeCityRestrictionRules(
        ruleSet: _ruleSet(dataIsStale: true, rules: [_rule()]),
        jurisdictionId: 'co-dc-bogota',
        category: PicoVehicleCategory.cars,
        date: DateTime(2026, 8, 31),
      );

      expect(summary.dataIsStale, isTrue);
      expect(summary.digitBasis, CityRestrictionDigitBasis.none);
      expect(summary.generalWindows, isEmpty);
    });
  });
}

RestrictionRuleSet _ruleSet({
  bool dataIsStale = false,
  DateTime? staleAfter,
  List<RestrictionRule> rules = const [],
}) {
  return RestrictionRuleSet(
    coverageKnown: true,
    dataIsStale: dataIsStale,
    staleAfter: staleAfter,
    rules: rules,
    verifiedAt: DateTime(2026, 8),
    sourceUrls: const ['https://bogota.gov.co/source'],
  );
}

RestrictionRule _rule({
  Set<VehicleKind> vehicleKinds = const {VehicleKind.car},
  Set<VehicleServiceType> serviceTypes = const {VehicleServiceType.private},
  Set<int>? weekdays = const {DateTime.thursday},
  RestrictionDateParity? dateParity,
  Set<int> digits = const {3},
  RestrictionDigitPosition digitPosition = RestrictionDigitPosition.lastNumeric,
  List<RestrictionTimeWindow> windows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 1260),
  ],
  bool appliesOnHolidays = true,
}) {
  return RestrictionRule(
    id: 'rule',
    jurisdictionId: 'co-dc-bogota',
    priority: 100,
    effect: RestrictionEffect.restrict,
    validFrom: DateTime(2026),
    validUntil: DateTime(2026, 12, 31, 23, 59, 59),
    vehicleKinds: vehicleKinds,
    serviceTypes: serviceTypes,
    weekdays: weekdays,
    dateParity: dateParity,
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: windows,
    appliesOnHolidays: appliesOnHolidays,
  );
}
