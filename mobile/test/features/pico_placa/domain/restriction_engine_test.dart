import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  const engine = RestrictionEngine();

  test('coverage desconocida returns unknown', () {
    final result = engine.evaluate(_context(coverageKnown: false), [_rule()]);

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownCoverage);
  });

  test('data stale returns stale', () {
    final result = engine.evaluate(_context(dataIsStale: true), [_rule()]);

    expect(result.status, RestrictionStatus.stale);
    expect(result.reasonCode, RestrictionReasonCode.staleData);
  });

  test('carro particular is restricted by last digit', () {
    final result = engine.evaluate(_context(plate: 'ABC123'), [
      _rule(digitPosition: RestrictionDigitPosition.lastNumeric, digits: {3}),
    ]);

    expect(result.status, RestrictionStatus.restricted);
    expect(result.matchedRuleId, 'rule-1');
  });

  test('same private car rule does not restrict taxi', () {
    final result = engine.evaluate(
      _context(serviceType: VehicleServiceType.taxi),
      [
        _rule(
          serviceTypes: {VehicleServiceType.private},
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: {3},
        ),
      ],
    );

    expect(result.status, RestrictionStatus.allowed);
    expect(result.reasonCode, RestrictionReasonCode.allowedNoRestriction);
  });

  test('taxi specific rule restricts taxi', () {
    final result = engine.evaluate(
      _context(serviceType: VehicleServiceType.taxi),
      [
        _rule(
          serviceTypes: {VehicleServiceType.taxi},
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: {3},
        ),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('moto uses firstNumeric correctly', () {
    final result = engine.evaluate(
      _context(
        plate: 'ABC12D3',
        vehicleKind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
      ),
      [
        _rule(
          vehicleKinds: {VehicleKind.motorcycle},
          digitPosition: RestrictionDigitPosition.firstNumeric,
          digits: {1},
        ),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('lastNumeric works correctly', () {
    final result = engine.evaluate(_context(plate: 'ABC12D3'), [
      _rule(digitPosition: RestrictionDigitPosition.lastNumeric, digits: {3}),
    ]);

    expect(result.status, RestrictionStatus.restricted);
  });

  test('plate without digits and digit rule returns unknown', () {
    final result = engine.evaluate(_context(plate: 'ABCXYZ'), [
      _rule(digitPosition: RestrictionDigitPosition.lastNumeric, digits: {3}),
    ]);

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownRequiredPlateDigit);
  });

  test('matching weekday applies', () {
    final result = engine.evaluate(_context(localDateTime: _mondayAt(7, 0)), [
      _rule(weekdays: {DateTime.monday}),
    ]);

    expect(result.status, RestrictionStatus.restricted);
  });

  test('different weekday does not restrict', () {
    final result = engine.evaluate(_context(localDateTime: _tuesdayAt(7, 0)), [
      _rule(weekdays: {DateTime.monday}),
    ]);

    expect(result.status, RestrictionStatus.allowed);
  });

  test('odd date applies', () {
    final result = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 27, 7)),
      [_rule(dateParity: RestrictionDateParity.odd)],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('even date applies', () {
    final result = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 28, 7)),
      [_rule(dateParity: RestrictionDateParity.even)],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('multiple time windows apply', () {
    final result = engine.evaluate(_context(localDateTime: _mondayAt(17, 0)), [
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 360, endMinute: 540),
          const RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
        ],
      ),
    ]);

    expect(result.status, RestrictionStatus.restricted);
    expect(result.effectiveWindows, hasLength(2));
  });

  test('outside schedule returns allowed', () {
    final result = engine.evaluate(_context(localDateTime: _mondayAt(12, 0)), [
      _rule(
        timeWindows: [
          const RestrictionTimeWindow(startMinute: 360, endMinute: 540),
        ],
      ),
    ]);

    expect(result.status, RestrictionStatus.allowed);
  });

  test('window crossing midnight works before and after midnight', () {
    final rule = _rule(
      timeWindows: [
        const RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
      ],
    );

    final beforeMidnight = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 5, 23)),
      [rule],
    );
    final afterMidnight = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 6, 1)),
      [rule],
    );

    expect(beforeMidnight.status, RestrictionStatus.restricted);
    expect(afterMidnight.status, RestrictionStatus.restricted);
  });

  test('holiday false rule does not apply on holiday', () {
    final result = engine.evaluate(_context(isHoliday: true), [
      _rule(appliesOnHolidays: false),
    ]);

    expect(result.status, RestrictionStatus.allowed);
  });

  test('registrationOrigin local applies', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.local),
      [
        _rule(registrationOrigins: {RegistrationOrigin.local}),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('registrationOrigin foreign applies', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.foreign),
      [
        _rule(registrationOrigins: {RegistrationOrigin.foreign}),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('unknown origin with local-only rule returns unknown', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.unknown),
      [
        _rule(registrationOrigins: {RegistrationOrigin.local}),
      ],
    );

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownRegistrationOrigin);
  });

  test('unknown origin with foreign-only rule returns unknown', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.unknown),
      [
        _rule(registrationOrigins: {RegistrationOrigin.foreign}),
      ],
    );

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownRegistrationOrigin);
  });

  test('unknown origin with local and foreign rule evaluates normally', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.unknown),
      [
        _rule(
          registrationOrigins: {
            RegistrationOrigin.local,
            RegistrationOrigin.foreign,
          },
        ),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('rule outside validFrom and validUntil does not apply', () {
    final beforeStart = engine.evaluate(_context(), [
      _rule(validFrom: DateTime(2026, 2), validUntil: DateTime(2026, 3)),
    ]);
    final afterEnd = engine.evaluate(_context(), [
      _rule(
        validFrom: DateTime(2025),
        validUntil: DateTime(2025, 12, 31, 23, 59),
      ),
    ]);

    expect(beforeStart.status, RestrictionStatus.allowed);
    expect(afterEnd.status, RestrictionStatus.allowed);
  });

  test('higher priority allow override suspends restriction', () {
    final result = engine.evaluate(_context(), [
      _rule(priority: 100),
      _rule(id: 'suspension', priority: 1000, effect: RestrictionEffect.allow),
    ]);

    expect(result.status, RestrictionStatus.allowed);
    expect(result.reasonCode, RestrictionReasonCode.allowedByOverride);
    expect(result.matchedRuleId, 'suspension');
  });

  test('higher priority restrict override beats normal rule', () {
    final result = engine.evaluate(_context(), [
      _rule(priority: 100, effect: RestrictionEffect.allow),
      _rule(id: 'emergency', priority: 1000),
    ]);

    expect(result.status, RestrictionStatus.restricted);
    expect(result.matchedRuleId, 'emergency');
  });

  test('higher priority uncertain digit blocks lower known rule', () {
    final result = engine.evaluate(_context(plate: 'ABCXYZ'), [
      _rule(id: 'known', priority: 100),
      _rule(
        id: 'unknown-digit',
        priority: 1000,
        digitPosition: RestrictionDigitPosition.lastNumeric,
        digits: {3},
      ),
    ]);

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownRequiredPlateDigit);
  });

  test('lower priority uncertain digit does not block higher known rule', () {
    final result = engine.evaluate(_context(plate: 'ABCXYZ'), [
      _rule(
        id: 'unknown-digit',
        priority: 100,
        digitPosition: RestrictionDigitPosition.lastNumeric,
        digits: {3},
      ),
      _rule(id: 'known', priority: 1000),
    ]);

    expect(result.status, RestrictionStatus.restricted);
    expect(result.matchedRuleId, 'known');
  });

  test('higher priority uncertain origin blocks lower known rule', () {
    final result = engine.evaluate(
      _context(registrationOrigin: RegistrationOrigin.unknown),
      [
        _rule(id: 'known', priority: 100),
        _rule(
          id: 'unknown-origin',
          priority: 1000,
          registrationOrigins: {RegistrationOrigin.local},
        ),
      ],
    );

    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownRegistrationOrigin);
  });

  test(
    'allow and restrict with same max priority returns unknown conflict',
    () {
      final result = engine.evaluate(_context(), [
        _rule(id: 'allow', priority: 1000, effect: RestrictionEffect.allow),
        _rule(id: 'restrict', priority: 1000),
      ]);

      expect(result.status, RestrictionStatus.unknown);
      expect(result.reasonCode, RestrictionReasonCode.conflictingRules);
      expect(result.matchedRuleId, isNull);
    },
  );

  test('sourceUrl and verifiedAt are preserved in result', () {
    final verifiedAt = DateTime(2026, 1, 2, 8);
    final result = engine.evaluate(_context(), [
      _rule(sourceUrl: 'https://example.test/rules', verifiedAt: verifiedAt),
    ]);

    expect(result.sourceUrl, 'https://example.test/rules');
    expect(result.verifiedAt, verifiedAt);
  });

  test('cross-midnight weekday uses the window start date after midnight', () {
    final result = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 6, 1)),
      [
        _rule(
          weekdays: {DateTime.monday},
          timeWindows: [
            const RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
          ],
        ),
      ],
    );

    expect(result.status, RestrictionStatus.restricted);
  });

  test('cross-midnight weekday does not drift to unrelated next day', () {
    final result = engine.evaluate(
      _context(localDateTime: DateTime(2026, 1, 7, 1)),
      [
        _rule(
          weekdays: {DateTime.monday},
          timeWindows: [
            const RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
          ],
        ),
      ],
    );

    expect(result.status, RestrictionStatus.allowed);
  });

  test(
    'cross-midnight date parity uses the window start date after midnight',
    () {
      final result = engine.evaluate(
        _context(localDateTime: DateTime(2026, 1, 6, 1)),
        [
          _rule(
            dateParity: RestrictionDateParity.odd,
            timeWindows: [
              const RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
            ],
          ),
        ],
      );

      expect(result.status, RestrictionStatus.restricted);
    },
  );
}

RestrictionContext _context({
  String jurisdictionId = 'test-jurisdiction',
  String plate = 'ABC123',
  VehicleKind vehicleKind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  RegistrationOrigin registrationOrigin = RegistrationOrigin.local,
  DateTime? localDateTime,
  bool isHoliday = false,
  bool coverageKnown = true,
  bool dataIsStale = false,
}) {
  return RestrictionContext(
    jurisdictionId: jurisdictionId,
    plate: plate,
    vehicleKind: vehicleKind,
    serviceType: serviceType,
    registrationOrigin: registrationOrigin,
    localDateTime: localDateTime ?? _mondayAt(7, 0),
    isHoliday: isHoliday,
    coverageKnown: coverageKnown,
    dataIsStale: dataIsStale,
  );
}

RestrictionRule _rule({
  String id = 'rule-1',
  String jurisdictionId = 'test-jurisdiction',
  int priority = 100,
  RestrictionEffect effect = RestrictionEffect.restrict,
  DateTime? validFrom,
  DateTime? validUntil,
  Set<VehicleKind> vehicleKinds = const {VehicleKind.car},
  Set<VehicleServiceType> serviceTypes = const {VehicleServiceType.private},
  Set<RegistrationOrigin>? registrationOrigins,
  Set<int>? weekdays,
  RestrictionDateParity? dateParity,
  RestrictionDigitPosition? digitPosition,
  Set<int>? digits,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 540),
  ],
  bool appliesOnHolidays = true,
  String? sourceUrl,
  DateTime? verifiedAt,
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: jurisdictionId,
    priority: priority,
    effect: effect,
    validFrom: validFrom ?? DateTime(2026),
    validUntil: validUntil,
    vehicleKinds: vehicleKinds,
    serviceTypes: serviceTypes,
    registrationOrigins: registrationOrigins,
    weekdays: weekdays,
    dateParity: dateParity,
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: timeWindows,
    appliesOnHolidays: appliesOnHolidays,
    sourceUrl: sourceUrl,
    verifiedAt: verifiedAt,
  );
}

DateTime _mondayAt(int hour, int minute) {
  return DateTime(2026, 1, 5, hour, minute);
}

DateTime _tuesdayAt(int hour, int minute) {
  return DateTime(2026, 1, 6, hour, minute);
}
