import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/presentation/restriction_scope_notice.dart';
import 'package:picoradar/features/pico_placa/presentation/today_restriction_summary.dart';
import 'package:picoradar/features/trip/application/trip_restriction_evaluation.dart';
import 'package:picoradar/features/trip/presentation/trip_plan_result.dart';

void main() {
  test('scope message is limited to Bogota private cars in November 2026', () {
    expect(
      bogotaUrbanRestrictionScopeNotice(
        jurisdictionId: 'co-dc-bogota',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        localDate: DateTime(2026, 11, 9),
      ),
      'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.',
    );
    expect(
      bogotaUrbanRestrictionScopeNotice(
        jurisdictionId: 'co-dc-bogota',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        localDate: DateTime(2026, 11, 16),
      ),
      'Restricción ordinaria urbana no aplica; retorno regional no evaluado.',
    );
    expect(
      bogotaUrbanRestrictionScopeNotice(
        jurisdictionId: 'co-dc-bogota',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
        localDate: DateTime(2026, 11, 9),
      ),
      isNull,
    );
    expect(
      bogotaUrbanRestrictionScopeNotice(
        jurisdictionId: 'co-medellin',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        localDate: DateTime(2026, 11, 9),
      ),
      isNull,
    );
    expect(
      bogotaUrbanRestrictionScopeNotice(
        jurisdictionId: 'co-dc-bogota',
        vehicleKind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
        localDate: DateTime(2026, 11, 9),
      ),
      isNull,
    );
  });

  testWidgets('Inicio summary exposes the scope visibly and accessibly', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bogotaNowProvider.overrideWith((ref) => DateTime(2026, 11, 9, 8)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TodayRestrictionSummary(
              evaluation: RestrictionDayEvaluation(
                status: RestrictionDayStatus.allowed,
                effectiveWindows: [],
              ),
              vehicleKind: VehicleKind.car,
              serviceType: VehicleServiceType.private,
              jurisdictionId: 'co-dc-bogota',
              cityLabel: 'Bogotá',
            ),
          ),
        ),
      ),
    );

    const scope =
        'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.';
    expect(find.text(scope), findsOneWidget);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('home-status-today')),
    );
    expect(node.value, contains(scope));
    semantics.dispose();
  });

  testWidgets(
    'Inicio and Mi Pico do not show the car notice for taxi or motorcycle',
    (tester) async {
      const cases = <(VehicleKind, VehicleServiceType)>[
        (VehicleKind.car, VehicleServiceType.taxi),
        (VehicleKind.motorcycle, VehicleServiceType.private),
      ];
      for (final prefix in ['home', 'pico']) {
        for (final (kind, service) in cases) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bogotaNowProvider.overrideWith(
                  (ref) => DateTime(2026, 11, 9, 8),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: TodayRestrictionSummary(
                    keyPrefix: prefix,
                    evaluation: const RestrictionDayEvaluation(
                      status: RestrictionDayStatus.allowed,
                      effectiveWindows: [],
                    ),
                    vehicleKind: kind,
                    serviceType: service,
                    jurisdictionId: 'co-dc-bogota',
                    cityLabel: 'Bogotá',
                  ),
                ),
              ),
            ),
          );

          expect(find.byKey(ValueKey('$prefix-summary-scope')), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'Inicio displays the decision evaluated from Laravel release bytes',
    (tester) async {
      final r2EvidenceDirectory =
          Platform.environment['PICORADAR_R2_EVIDENCE_DIR'];
      final evidenceDirectory =
          r2EvidenceDirectory ??
          Platform.environment['PICORADAR_R1_EVIDENCE_DIR'];
      if (evidenceDirectory == null || evidenceDirectory.isEmpty) {
        markTestSkipped('Requires the Laravel R1 release export.');
        return;
      }
      final releaseName = r2EvidenceDirectory == null
          ? 'ACTUAL_LARAVEL_RELEASE.json'
          : 'ACTUAL_R2_LARAVEL_RELEASE.json';
      final release = jsonDecode(
        File('$evidenceDirectory${Platform.pathSeparator}$releaseName')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final cities = (release['jurisdictions'] as List)
          .cast<Map<String, dynamic>>();
      final bogota = cities.singleWhere((city) => city['id'] == 'co-dc-bogota');
      final coverages = (bogota['coverages'] as List)
          .cast<Map<String, dynamic>>();
      final coverage = coverages.singleWhere(
        (item) =>
            item['vehicleKind'] == 'car' && item['serviceType'] == 'private',
      );
      final rules = restrictionRulesFromJson(
        jsonEncode(coverage['rules']),
        jurisdictionId: 'co-dc-bogota',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
      );
      final ruleSet = RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: false,
        rules: rules,
        jurisdictionName: 'Bogotá',
        verifiedAt: DateTime.parse(coverage['verifiedAt'] as String),
        staleAfter: DateTime.parse(coverage['staleAfter'] as String),
        sourceUrls: (coverage['sourceUrls'] as List).cast<String>(),
      );
      final evaluation = evaluateRestrictionDay(
        ruleSet: ruleSet,
        jurisdictionId: 'co-dc-bogota',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime(2026, 11, 9),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bogotaNowProvider.overrideWith((ref) => DateTime(2026, 11, 9, 8)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TodayRestrictionSummary(
                evaluation: evaluation,
                vehicleKind: VehicleKind.car,
                serviceType: VehicleServiceType.private,
                jurisdictionId: 'co-dc-bogota',
                cityLabel: 'Bogotá',
              ),
            ),
          ),
        ),
      );

      expect(evaluation.status, RestrictionDayStatus.allowed);
      expect(find.text('Puede circular'), findsOneWidget);
      expect(
        find.text(
          'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Trip endpoint keeps regional return outside its result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripInstantEndpoint(
            label: 'Salida',
            city: 'Bogotá',
            jurisdictionId: 'co-dc-bogota',
            vehicleKind: VehicleKind.car,
            serviceType: VehicleServiceType.private,
            instantUtc: DateTime.utc(2026, 11, 16, 19),
            evaluation: const AsyncValue.data(
              TripEndpointRestriction(
                status: RestrictionDayStatus.allowed,
                instantStatus: RestrictionStatus.allowed,
              ),
            ),
            onSource: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Restricción ordinaria urbana no aplica; retorno regional no evaluado.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Trip does not show the car scope warning for private motorcycles',
    (tester) async {
      const scope =
          'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInstantEndpoint(
              label: 'Salida',
              city: 'Bogotá',
              jurisdictionId: 'co-dc-bogota',
              vehicleKind: VehicleKind.motorcycle,
              serviceType: VehicleServiceType.private,
              instantUtc: DateTime.utc(2026, 11, 9, 13),
              evaluation: const AsyncValue.data(
                TripEndpointRestriction(
                  status: RestrictionDayStatus.allowed,
                  instantStatus: RestrictionStatus.allowed,
                ),
              ),
              onSource: (_) {},
            ),
          ),
        ),
      );

      expect(find.text(scope), findsNothing);
    },
  );

  testWidgets('Trip needs a car/private identity before showing the car notice', (
    tester,
  ) async {
    const scope =
        'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.';
    const cases = <(VehicleKind?, VehicleServiceType)>[
      (VehicleKind.car, VehicleServiceType.taxi),
      (null, VehicleServiceType.private),
    ];

    for (final (kind, service) in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInstantEndpoint(
              label: 'Salida',
              city: 'Bogotá',
              jurisdictionId: 'co-dc-bogota',
              vehicleKind: kind,
              serviceType: service,
              instantUtc: DateTime.utc(2026, 11, 9, 13),
              evaluation: const AsyncValue.data(
                TripEndpointRestriction(
                  status: RestrictionDayStatus.allowed,
                  instantStatus: RestrictionStatus.allowed,
                ),
              ),
              onSource: (_) {},
            ),
          ),
        ),
      );

      expect(find.text(scope), findsNothing);
    }
  });
}
