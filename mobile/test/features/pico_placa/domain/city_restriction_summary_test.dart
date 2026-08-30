import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/city_restriction_summary.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
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
}

RestrictionRuleSet _ruleSet({
  bool dataIsStale = false,
  List<RestrictionRule> rules = const [],
}) {
  return RestrictionRuleSet(
    coverageKnown: true,
    dataIsStale: dataIsStale,
    rules: rules,
    verifiedAt: DateTime(2026, 8),
    sourceUrls: const ['https://bogota.gov.co/source'],
  );
}

RestrictionRule _rule({
  Set<VehicleKind> vehicleKinds = const {VehicleKind.car},
  Set<VehicleServiceType> serviceTypes = const {VehicleServiceType.private},
  Set<int> weekdays = const {DateTime.thursday},
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
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: windows,
    appliesOnHolidays: appliesOnHolidays,
  );
}
