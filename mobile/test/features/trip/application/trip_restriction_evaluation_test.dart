import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/bogota_time.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/trip/application/trip_restriction_evaluation.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/data/trip_plan_client.dart';
import 'package:timezone/timezone.dart' as timezone;

void main() {
  test('outside hours preserves the restricted day and provenance', () {
    final result = _evaluate(instant: DateTime.utc(2026, 9, 7, 10));
    expect(result.status, RestrictionDayStatus.restricted);
    expect(result.instantStatus, RestrictionStatus.allowed);
    expect(_windows(result), [(360, 540)]);
    expect(result.sourceUrl, 'https://example.test/rule');
    expect(result.verifiedAt, DateTime.utc(2026, 9, 1));
    expect(result.reason, isNull);
    expect(result.engineReason, RestrictionReasonCode.allowedNoRestriction);
    expect(result.evaluatedAtUtc, DateTime.utc(2026, 9, 7, 10));
    expect(result.evaluatedAtUtc!.isUtc, isTrue);
    expect(() => result.windows.clear(), throwsUnsupportedError);
  });

  for (final entry in [
    (DateTime.utc(2026, 9, 7, 10, 59, 59), RestrictionStatus.allowed),
    (DateTime.utc(2026, 9, 7, 11), RestrictionStatus.restricted),
    (DateTime.utc(2026, 9, 7, 13, 59, 59), RestrictionStatus.restricted),
    (DateTime.utc(2026, 9, 7, 14), RestrictionStatus.allowed),
  ]) {
    test('Bogota interval boundary ${entry.$1.toIso8601String()}', () {
      final result = _evaluate(instant: entry.$1);
      expect(result.instantStatus, entry.$2);
      expect(result.status, RestrictionDayStatus.restricted);
    });
  }

  test('the same instant in another timezone has the same Bogota verdict', () {
    final utc = DateTime.utc(2026, 9, 7, 11, 30);
    bogotaWallClock(utc);
    final losAngeles = timezone.TZDateTime.from(
      utc,
      timezone.getLocation('America/Los_Angeles'),
    );
    final result = _evaluate(instant: losAngeles);
    expect(result.instantStatus, RestrictionStatus.restricted);
    expect(result.evaluatedAtUtc, utc);
    expect(result.evaluatedAtUtc!.isUtc, isTrue);
  });

  test('route duration crossing Bogota midnight evaluates the next day', () {
    final departure = bogotaScheduledTime(
      date: DateTime(2026, 9, 7),
      minuteOfDay: 23 * 60 + 30,
    ).toUtc();
    final rules = [
      _rule(weekdays: {DateTime.monday}, windows: const []),
    ];
    final origin = _evaluate(instant: departure, rules: rules);
    final shortRoute = _evaluate(
      instant: departure.add(const Duration(minutes: 20)),
      rules: rules,
    );
    final longRoute = _evaluate(
      instant: departure.add(const Duration(minutes: 60)),
      rules: rules,
    );
    expect(origin.instantStatus, RestrictionStatus.restricted);
    expect(shortRoute.instantStatus, RestrictionStatus.restricted);
    expect(longRoute.instantStatus, RestrictionStatus.allowed);
    expect(longRoute.status, RestrictionDayStatus.allowed);
    expect(longRoute.evaluatedAtUtc, DateTime.utc(2026, 9, 8, 5, 30));
    expect(origin.evaluatedAtUtc, DateTime.utc(2026, 9, 8, 4, 30));
  });

  test('overnight Monday window retains its Tuesday tail', () {
    final rules = [
      _rule(
        weekdays: {DateTime.monday},
        windows: const [
          RestrictionTimeWindow(startMinute: 1320, endMinute: 120),
        ],
      ),
    ];
    final inside = _evaluate(
      instant: DateTime.utc(2026, 9, 8, 6),
      rules: rules,
    );
    final end = _evaluate(instant: DateTime.utc(2026, 9, 8, 7), rules: rules);
    expect(inside.instantStatus, RestrictionStatus.restricted);
    expect(_windows(inside), [(0, 120)]);
    expect(end.instantStatus, RestrictionStatus.allowed);
    expect(end.status, RestrictionDayStatus.restricted);
  });

  test('Colombian holiday exemption and holiday-applicable rules differ', () {
    final instant = DateTime.utc(2026, 8, 7, 12);
    final exempt = _evaluate(instant: instant, rules: [_rule(holidays: false)]);
    final applies = _evaluate(instant: instant, rules: [_rule()]);
    expect(exempt.status, RestrictionDayStatus.allowed);
    expect(exempt.instantStatus, RestrictionStatus.allowed);
    expect(exempt.windows, isEmpty);
    expect(applies.instantStatus, RestrictionStatus.restricted);
  });

  test('motorcycle first digit and taxi service do not reuse private car', () {
    final rules = [
      _rule(),
      _rule(
        id: 'moto',
        kind: VehicleKind.motorcycle,
        digitPosition: RestrictionDigitPosition.firstNumeric,
        digits: {1},
      ),
      _rule(id: 'taxi', service: VehicleServiceType.taxi, digits: {2}),
    ];
    final car = _evaluate(rules: rules);
    final moto = _evaluate(
      rules: rules,
      vehicle: _vehicle(kind: VehicleKind.motorcycle, plate: 'ABC13D'),
    );
    final taxi = _evaluate(
      rules: rules,
      vehicle: _vehicle(service: VehicleServiceType.taxi),
    );
    expect(car.instantStatus, RestrictionStatus.restricted);
    expect(moto.instantStatus, RestrictionStatus.restricted);
    expect(taxi.instantStatus, RestrictionStatus.allowed);
    expect(taxi.status, RestrictionDayStatus.allowed);
  });

  test('allow override divides personal day windows', () {
    final result = _evaluate(
      instant: DateTime.utc(2026, 9, 7, 12),
      rules: [
        _rule(),
        _rule(
          id: 'override',
          priority: 200,
          effect: RestrictionEffect.allow,
          windows: const [
            RestrictionTimeWindow(startMinute: 420, endMinute: 480),
          ],
        ),
      ],
    );
    expect(result.instantStatus, RestrictionStatus.allowed);
    expect(result.engineReason, RestrictionReasonCode.allowedByOverride);
    expect(result.status, RestrictionDayStatus.restricted);
    expect(_windows(result), [(360, 420), (480, 540)]);
  });

  test('unknown instant keeps a reason even when day has known windows', () {
    final result = _evaluate(
      rules: [
        _rule(),
        _rule(
          id: 'uncertain',
          priority: 200,
          origins: {RegistrationOrigin.local},
          windows: const [
            RestrictionTimeWindow(startMinute: 420, endMinute: 480),
          ],
        ),
      ],
    );
    expect(result.status, RestrictionDayStatus.restricted);
    expect(_windows(result), [(360, 420), (480, 540)]);
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'no_coverage');
    expect(
      result.engineReason,
      RestrictionReasonCode.unknownRegistrationOrigin,
    );
    expect(result.sourceUrl, 'https://example.test/rule');
    expect(result.verifiedAt, DateTime.utc(2026, 9, 1));
  });

  test('conflicting rules remain unknown with the engine reason', () {
    final result = _evaluate(
      rules: [
        _rule(),
        _rule(id: 'conflict', effect: RestrictionEffect.allow),
      ],
    );
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'no_coverage');
    expect(result.engineReason, RestrictionReasonCode.conflictingRules);
  });

  test('missing required plate digit is not allowed', () {
    final result = _evaluate(vehicle: _vehicle(plate: 'ABC'));
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'no_coverage');
    expect(
      result.engineReason,
      RestrictionReasonCode.unknownRequiredPlateDigit,
    );
  });

  test('known empty coverage explicitly permits the date', () {
    final result = _evaluate(rules: []);
    expect(result.status, RestrictionDayStatus.allowed);
    expect(result.instantStatus, RestrictionStatus.allowed);
    expect(result.reason, isNull);
    expect(result.sourceUrl, 'https://example.test/coverage');
  });

  test(
    'missing coverage remains unknown and preserves available provenance',
    () {
      final result = _evaluate(ruleSet: _ruleSet(known: false, rules: []));
      expect(result.status, RestrictionDayStatus.unknown);
      expect(result.instantStatus, RestrictionStatus.unknown);
      expect(result.reason, 'no_coverage');
      expect(result.sourceUrl, 'https://example.test/coverage');
      expect(result.verifiedAt, DateTime.utc(2026, 8, 31));
    },
  );

  test('already stale data retains coverage source and verification', () {
    final result = _evaluate(ruleSet: _ruleSet(stale: true));
    expect(result.status, RestrictionDayStatus.stale);
    expect(result.instantStatus, RestrictionStatus.stale);
    expect(result.reason, 'stale_data');
    expect(result.windows, isEmpty);
    expect(result.sourceUrl, 'https://example.test/coverage');
    expect(result.verifiedAt, DateTime.utc(2026, 8, 31));
  });

  test('future date beyond fresh dataset horizon is future coverage', () {
    final result = _evaluate(instant: DateTime.utc(2026, 10, 1, 12));
    expect(result.status, RestrictionDayStatus.unknown);
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'future_coverage');
    expect(result.sourceUrl, 'https://example.test/coverage');
    expect(result.verifiedAt, DateTime.utc(2026, 8, 31));
  });

  test('stale now takes precedence over future date without rules', () {
    final result = _evaluate(
      instant: DateTime.utc(2026, 10, 1, 12),
      ruleSet: _ruleSet(stale: true),
    );
    expect(result.instantStatus, RestrictionStatus.stale);
    expect(result.reason, 'stale_data');
  });

  test('expiration at current UTC is stale even if stored flag is false', () {
    final result = _evaluate(nowUtc: DateTime.utc(2026, 10, 1, 5));
    expect(result.instantStatus, RestrictionStatus.stale);
    expect(result.reason, 'stale_data');
  });

  test('stale metadata falls back to the scoped rule provenance', () {
    final result = _evaluate(
      ruleSet: RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: true,
        rules: [_rule()],
      ),
    );
    expect(result.instantStatus, RestrictionStatus.stale);
    expect(result.sourceUrl, 'https://example.test/rule');
    expect(result.verifiedAt, DateTime.utc(2026, 9, 1));
    expect(result.reason, 'stale_data');
  });

  test('a different service rule cannot prove taxi coverage', () {
    final result = _evaluate(
      vehicle: _vehicle(service: VehicleServiceType.taxi),
    );
    expect(result.status, RestrictionDayStatus.unknown);
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'no_coverage');
  });

  test('past ended rules are stale rather than future coverage', () {
    final result = _evaluate(
      instant: DateTime.utc(2026, 9, 4, 12),
      rules: [_rule(validUntil: DateTime(2026, 9, 3, 23, 59, 59))],
    );
    expect(result.instantStatus, RestrictionStatus.stale);
    expect(result.reason, 'stale_data');
  });

  test('fresh metadata does not extrapolate expired rule validity', () {
    final result = _evaluate(
      rules: [_rule(validUntil: DateTime(2026, 9, 6, 23, 59, 59))],
    );
    expect(result.status, RestrictionDayStatus.unknown);
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'future_coverage');
  });

  test('future rules not yet valid do not imply permission in the gap', () {
    final result = _evaluate(rules: [_rule(validFrom: DateTime(2026, 9, 8))]);
    expect(result.instantStatus, RestrictionStatus.unknown);
    expect(result.reason, 'future_coverage');
  });

  test('Bogota last covered date is included, next midnight is not', () {
    final before = _evaluate(instant: DateTime.utc(2026, 10, 1, 4, 59, 59));
    final after = _evaluate(instant: DateTime.utc(2026, 10, 1, 5));
    expect(before.instantStatus, RestrictionStatus.allowed);
    expect(before.reason, isNull);
    expect(after.instantStatus, RestrictionStatus.unknown);
    expect(after.reason, 'future_coverage');
  });

  group('providers', () {
    late AppDatabase database;
    late _TripStore store;
    late ProviderContainer container;
    late DateTime nowUtc;
    late int remoteClientReads;
    Completer<void>? seedGate;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      store = _TripStore(database);
      nowUtc = DateTime.utc(2026, 9, 5, 15);
      remoteClientReads = 0;
      seedGate = null;
      container = ProviderContainer(
        overrides: [
          bundledRestrictionsProvider.overrideWith((ref) async {
            await seedGate?.future;
          }),
          restrictionStoreProvider.overrideWithValue(store),
          tripRestrictionClockProvider.overrideWithValue(() => nowUtc),
          tripPlanClientProvider.overrideWith((ref) {
            remoteClientReads += 1;
            throw StateError('Local restriction refresh must not use HTTP');
          }),
          bogotaNowProvider.overrideWithValue(DateTime(2026, 9, 5, 10)),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await database.close();
    });

    for (final instant in [false, true]) {
      test(
        'performance: dataset commit renews retained Trip restriction (instant=$instant)',
        () async {
          final vehicle = _vehicle();
          final provider = instant
              ? tripInstantRestrictionProvider((
                  municipality: _bogota,
                  vehicle: vehicle,
                  instantUtc: DateTime.utc(2026, 9, 7, 12),
                ))
              : tripRestrictionProvider((
                  municipality: _bogota,
                  vehicle: vehicle,
                  date: DateTime(2026, 9, 7),
                ));
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          expect(
            (await container.read(provider.future)).status,
            RestrictionDayStatus.restricted,
          );

          store.overrideRuleSet = _ruleSet(
            rules: [
              _rule(digits: {7}),
            ],
          );
          container.read(datasetSyncCommitHandlerProvider)('restrictions');
          await container.pump();
          final renewed = await container.read(provider.future);
          expect(renewed.status, RestrictionDayStatus.allowed);
          expect(store.loads, hasLength(2));
          expect(remoteClientReads, 0);
        },
      );

      test(
        'performance: Trip waits for local seed before coverage (instant=$instant)',
        () async {
          seedGate = Completer<void>();
          final vehicle = _vehicle();
          final provider = instant
              ? tripInstantRestrictionProvider((
                  municipality: _bogota,
                  vehicle: vehicle,
                  instantUtc: DateTime.utc(2026, 9, 7, 12),
                ))
              : tripRestrictionProvider((
                  municipality: _bogota,
                  vehicle: vehicle,
                  date: DateTime(2026, 9, 7),
                ));
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          final pending = container.read(provider.future);
          try {
            await Future<void>.delayed(Duration.zero);
            expect(store.loads, isEmpty);
          } finally {
            seedGate!.complete();
          }
          expect((await pending).status, RestrictionDayStatus.restricted);
          expect(store.loads, hasLength(1));
          expect(remoteClientReads, 0);
        },
      );
    }

    test(
      'freshness clock advances for a new query in the same container',
      () async {
        final vehicle = _vehicle();
        nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 58);
        final first = await container.read(
          tripInstantRestrictionProvider((
            municipality: _bogota,
            vehicle: vehicle,
            instantUtc: DateTime.utc(2026, 9, 7, 10),
          )).future,
        );
        expect(first.instantStatus, RestrictionStatus.allowed);

        nowUtc = DateTime.utc(2026, 10, 1, 5);
        final second = await container.read(
          tripInstantRestrictionProvider((
            municipality: _bogota,
            vehicle: vehicle,
            instantUtc: DateTime.utc(2026, 9, 7, 10, 30),
          )).future,
        );
        expect(second.instantStatus, RestrictionStatus.stale);
        expect(second.reason, 'stale_data');
        expect(store.loads.last.$4, DateTime.utc(2026, 10, 1, 5));
        expect(remoteClientReads, 0);
      },
    );

    test(
      'reconsulting the same query refreshes freshness without HTTP',
      () async {
        nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 58);
        final provider = tripInstantRestrictionProvider((
          municipality: _bogota,
          vehicle: _vehicle(),
          instantUtc: DateTime.utc(2026, 9, 7, 10),
        ));
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        final first = await container.read(provider.future);
        expect(first.instantStatus, RestrictionStatus.allowed);

        nowUtc = DateTime.utc(2026, 10, 1, 5);
        container.invalidate(provider);
        final refreshed = await container.read(provider.future);
        expect(refreshed.instantStatus, RestrictionStatus.stale);
        expect(refreshed.reason, 'stale_data');
        expect(refreshed.evaluatedAtUtc, first.evaluatedAtUtc);
        expect(remoteClientReads, 0);
      },
    );

    testWidgets('visible verdict expires at staleAfter without HTTP', (
      tester,
    ) async {
      nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 58);
      final provider = tripInstantRestrictionProvider((
        municipality: _bogota,
        vehicle: _vehicle(),
        instantUtc: DateTime.utc(2026, 9, 7, 10),
      ));
      final subscription = container.listen(provider, (_, _) {});
      try {
        final first = await container.read(provider.future);
        expect(first.instantStatus, RestrictionStatus.allowed);
        nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 59);
        await tester.pump(const Duration(seconds: 1));
        expect(
          container.read(provider).requireValue.instantStatus,
          RestrictionStatus.allowed,
        );
        expect(store.loads, hasLength(1));

        nowUtc = DateTime.utc(2026, 10, 1, 5);
        await tester.pump(const Duration(seconds: 1));
        final expired = await container.read(provider.future);
        expect(expired.status, RestrictionDayStatus.stale);
        expect(expired.instantStatus, RestrictionStatus.stale);
        expect(expired.reason, 'stale_data');
        expect(expired.sourceUrl, 'https://example.test/coverage');
        expect(expired.verifiedAt, DateTime.utc(2026, 8, 31));
        expect(expired.evaluatedAtUtc, first.evaluatedAtUtc);
        expect(remoteClientReads, 0);
        final loadsAfterExpiry = store.loads.length;
        nowUtc = DateTime.utc(2026, 10, 1, 6);
        await tester.pump(const Duration(hours: 1));
        expect(store.loads, hasLength(loadsAfterExpiry));
      } finally {
        subscription.close();
        await tester.pump(const Duration(milliseconds: 1));
      }
    });

    testWidgets(
      'unobserved query releases its expiry timer and cached verdict',
      (tester) async {
        nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 58);
        final provider = tripInstantRestrictionProvider((
          municipality: _bogota,
          vehicle: _vehicle(),
          instantUtc: DateTime.utc(2026, 9, 7, 10),
        ));
        final firstSubscription = container.listen(provider, (_, _) {});
        final first = await container.read(provider.future);
        expect(first.instantStatus, RestrictionStatus.allowed);
        firstSubscription.close();
        await tester.pump(const Duration(milliseconds: 1));
        expect(container.exists(provider), isFalse);

        nowUtc = DateTime.utc(2026, 10, 1, 5);
        await tester.pump(const Duration(seconds: 2));
        expect(store.loads, hasLength(1));
        final nextSubscription = container.listen(provider, (_, _) {});
        try {
          final reopened = await container.read(provider.future);
          expect(reopened.instantStatus, RestrictionStatus.stale);
          expect(reopened.reason, 'stale_data');
          expect(remoteClientReads, 0);
        } finally {
          nextSubscription.close();
          await tester.pump(const Duration(milliseconds: 1));
        }
      },
    );

    test('local load crossing expiry cannot publish a fresh verdict', () async {
      nowUtc = DateTime.utc(2026, 10, 1, 4, 59, 58);
      store.loadGate = Completer<void>();
      final provider = tripInstantRestrictionProvider((
        municipality: _bogota,
        vehicle: _vehicle(),
        instantUtc: DateTime.utc(2026, 9, 7, 10),
      ));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final result = container.read(provider.future);
      await Future<void>.delayed(Duration.zero);
      expect(store.loads, hasLength(1));
      nowUtc = DateTime.utc(2026, 10, 1, 5);
      store.loadGate!.complete();
      final loaded = await result;
      expect(loaded.instantStatus, RestrictionStatus.stale);
      expect(loaded.reason, 'stale_data');
      expect(remoteClientReads, 0);
    });

    test('loads category and jurisdiction with current UTC, not ETA', () async {
      final result = await container.read(
        tripInstantRestrictionProvider((
          municipality: _bogota,
          vehicle: _vehicle(service: VehicleServiceType.taxi),
          instantUtc: DateTime.utc(2026, 9, 7, 12),
        )).future,
      );
      expect(store.loads.single, (
        'co-dc-bogota',
        VehicleKind.car,
        VehicleServiceType.taxi,
        DateTime.utc(2026, 9, 5, 15),
      ));
      expect(store.loads.single.$4.isUtc, isTrue);
      expect(result.evaluatedAtUtc, DateTime.utc(2026, 9, 7, 12));
    });

    test('legacy day caller remains date-only', () async {
      final result = await container.read(
        tripRestrictionProvider((
          municipality: _bogota,
          vehicle: _vehicle(),
          date: DateTime(2026, 9, 7),
        )).future,
      );
      expect(result.status, RestrictionDayStatus.restricted);
      expect(result.sourceUrl, 'https://example.test/coverage');
      expect(result.instantStatus, isNull);
      expect(result.evaluatedAtUtc, isNull);
    });

    test(
      'missing vehicle, unresolved municipality and unmapped are distinct',
      () async {
        for (final entry in [
          (_bogota, null, 'missing_vehicle'),
          (null, _vehicle(), 'ambiguous_municipality'),
          (
            const TripMunicipality(
              code: '05002',
              municipality: 'Abejorral',
              department: 'Antioquia',
            ),
            _vehicle(),
            'unmapped_jurisdiction',
          ),
        ]) {
          final result = await container.read(
            tripInstantRestrictionProvider((
              municipality: entry.$1,
              vehicle: entry.$2,
              instantUtc: DateTime.utc(2026, 9, 7, 12),
            )).future,
          );
          expect(result.reason, entry.$3);
          expect(result.status, RestrictionDayStatus.unknown);
          expect(result.instantStatus, RestrictionStatus.unknown);
        }
        expect(store.loads, isEmpty);
      },
    );

    test(
      'destination load error does not remove available origin result',
      () async {
        const destination = TripMunicipality(
          code: '05001',
          municipality: 'Medellin',
          department: 'Antioquia',
          jurisdictionId: 'co-ant-medellin',
        );
        store.failedJurisdiction = 'co-ant-medellin';
        final origin = await container.read(
          tripInstantRestrictionProvider((
            municipality: _bogota,
            vehicle: _vehicle(),
            instantUtc: DateTime.utc(2026, 9, 7, 12),
          )).future,
        );
        final failed = await container.read(
          tripInstantRestrictionProvider((
            municipality: destination,
            vehicle: _vehicle(),
            instantUtc: DateTime.utc(2026, 9, 7, 15),
          )).future,
        );
        expect(origin.instantStatus, RestrictionStatus.restricted);
        expect(failed.status, RestrictionDayStatus.unknown);
        expect(failed.instantStatus, RestrictionStatus.unknown);
        expect(failed.reason, 'load_error');
        expect(failed.sourceUrl, isNull);
        expect(failed.evaluatedAtUtc, DateTime.utc(2026, 9, 7, 15));
      },
    );

    test('inconsistent store state is surfaced as load error', () async {
      store.failedJurisdiction = 'co-dc-bogota';
      store.failure = StateError('synthetic duplicate coverage');
      final result = await container.read(
        tripInstantRestrictionProvider((
          municipality: _bogota,
          vehicle: _vehicle(),
          instantUtc: DateTime.utc(2026, 9, 7, 12),
        )).future,
      );
      expect(result.instantStatus, RestrictionStatus.unknown);
      expect(result.reason, 'load_error');
    });
  });
}

const _bogota = TripMunicipality(
  code: '11001',
  municipality: 'Bogota',
  department: 'Bogota D.C.',
  jurisdictionId: 'co-dc-bogota',
);

TripEndpointRestriction _evaluate({
  DateTime? instant,
  DateTime? nowUtc,
  VehicleProfile? vehicle,
  List<RestrictionRule>? rules,
  RestrictionRuleSet? ruleSet,
}) {
  return evaluateTripRestriction(
    ruleSet: ruleSet ?? _ruleSet(rules: rules),
    municipality: _bogota,
    vehicle: vehicle ?? _vehicle(),
    instantUtc: instant ?? DateTime.utc(2026, 9, 7, 12),
    nowUtc: nowUtc ?? DateTime.utc(2026, 9, 5, 15),
  );
}

List<(int, int)> _windows(TripEndpointRestriction result) => [
  for (final window in result.windows) (window.startMinute, window.endMinute),
];

VehicleProfile _vehicle({
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType service = VehicleServiceType.private,
  String plate = 'ABC123',
}) {
  return VehicleProfile(
    id: 'synthetic-vehicle',
    plate: plate,
    kind: kind,
    serviceType: service,
    registrationCity: 'Cali',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

RestrictionRuleSet _ruleSet({
  bool known = true,
  bool stale = false,
  List<RestrictionRule>? rules,
}) {
  return RestrictionRuleSet(
    coverageKnown: known,
    dataIsStale: stale,
    rules: rules ?? [_rule()],
    verifiedAt: DateTime.utc(2026, 8, 31),
    staleAfter: DateTime.utc(2026, 10, 1, 5),
    sourceUrls: const ['https://example.test/coverage'],
  );
}

RestrictionRule _rule({
  String id = 'rule',
  int priority = 100,
  RestrictionEffect effect = RestrictionEffect.restrict,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType service = VehicleServiceType.private,
  RestrictionDigitPosition digitPosition = RestrictionDigitPosition.lastNumeric,
  Set<int> digits = const {3},
  Set<int>? weekdays,
  Set<RegistrationOrigin>? origins,
  bool holidays = true,
  DateTime? validFrom,
  DateTime? validUntil,
  List<RestrictionTimeWindow> windows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 540),
  ],
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: 'co-dc-bogota',
    priority: priority,
    effect: effect,
    validFrom: validFrom ?? DateTime(2026),
    validUntil: validUntil,
    vehicleKinds: {kind},
    serviceTypes: {service},
    digitPosition: digitPosition,
    digits: digits,
    weekdays: weekdays,
    registrationOrigins: origins,
    timeWindows: windows,
    appliesOnHolidays: holidays,
    sourceUrl: 'https://example.test/rule',
    verifiedAt: DateTime.utc(2026, 9, 1),
  );
}

class _TripStore extends RestrictionStore {
  _TripStore(super.database);

  RestrictionRuleSet? overrideRuleSet;
  String? failedJurisdiction;
  Object failure = const FormatException('synthetic local dataset failure');
  Completer<void>? loadGate;
  final loads = <(String, VehicleKind, VehicleServiceType, DateTime)>[];

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    loads.add((jurisdictionId, vehicleKind, serviceType, now));
    final gate = loadGate;
    if (gate != null) {
      await gate.future;
    }
    if (jurisdictionId == failedJurisdiction) {
      throw failure;
    }
    return overrideRuleSet ??
        _ruleSet(
          rules: [_rule(kind: vehicleKind, service: serviceType)],
        );
  }
}
