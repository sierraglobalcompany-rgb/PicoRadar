import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

import 'test_app_harness.dart';

const performanceJurisdictions = [
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellin'),
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogota'),
];

VehicleProfile performanceVehicle(
  String id, {
  String plate = 'BOG126',
  String? registrationCity,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType service = VehicleServiceType.private,
  int revision = 0,
}) => VehicleProfile(
  id: id,
  plate: plate,
  registrationCity: registrationCity,
  kind: kind,
  serviceType: service,
  nickname: 'Vehicle $id revision $revision',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 9, 10, 0, 0, revision),
);

class PerformanceTestHarness {
  PerformanceTestHarness(this.vehicles);

  final List<VehicleProfile> vehicles;
  final local = TestAppHarness();
  DateTime nowUtc = DateTime.utc(2026, 9, 10, 9, 59);
  late final store = CountingPerformanceStore(local.database);
  late final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(local.database),
      appPreferencesProvider.overrideWithValue(local.preferences),
      appClockNowProvider.overrideWithValue(() => nowUtc),
      bundledRestrictionsProvider.overrideWith((ref) async {}),
      restrictionStoreProvider.overrideWithValue(store),
      restrictionJurisdictionsProvider.overrideWith(
        (ref) async => performanceJurisdictions,
      ),
      selectedPicoJurisdictionIdProvider.overrideWith(
        (ref) async => performanceJurisdictions.first.id,
      ),
      vehicleListProvider.overrideWith((ref) async => vehicles),
      activeVehicleProvider.overrideWith(
        (ref) async => vehicles.isEmpty ? null : vehicles.first,
      ),
      avatarCatalogProvider.overrideWith(
        (ref) async => const AvatarCatalog(defaultId: null, items: []),
      ),
      vehicleVisualCatalogProvider.overrideWith(
        (ref) async => const VehicleVisualCatalog(items: []),
      ),
      homeBannerCampaignProvider.overrideWith((ref) async => null),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await local.preferences.setString(
      picoJurisdictionPreferenceKey,
      performanceJurisdictions.first.id,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await local.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      _OwnedTestContainer(
        container: container,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildPicoRadarTheme(),
            home: Scaffold(body: screen),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester, Duration elapsed) async {
    nowUtc = nowUtc.add(elapsed);
    await tester.pump(elapsed);
    await tester.pumpAndSettle();
  }
}

class _OwnedTestContainer extends StatefulWidget {
  const _OwnedTestContainer({required this.container, required this.child});

  final ProviderContainer container;
  final Widget child;

  @override
  State<_OwnedTestContainer> createState() => _OwnedTestContainerState();
}

class _OwnedTestContainerState extends State<_OwnedTestContainer> {
  @override
  void dispose() {
    widget.container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef PerformanceCoverageKey = (String, VehicleKind, VehicleServiceType);

class CountingPerformanceStore extends RestrictionStore {
  CountingPerformanceStore(super.database);

  final calls = <PerformanceCoverageKey>[];
  int ruleReads = 0;
  DateTime staleAfter = DateTime.utc(2026, 11);
  final loadedStaleStates = <bool>[];
  RestrictionDayStatus status = RestrictionDayStatus.restricted;
  Completer<void>? pending;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    calls.add((jurisdictionId, vehicleKind, serviceType));
    await pending?.future;
    final stale =
        status == RestrictionDayStatus.stale ||
        !now.toUtc().isBefore(staleAfter.toUtc());
    loadedStaleStates.add(stale);
    return RestrictionRuleSet(
      coverageKnown: status != RestrictionDayStatus.unknown,
      dataIsStale: stale,
      staleAfter: staleAfter,
      verifiedAt: DateTime.utc(2026, 9, 10),
      sourceUrls: const ['https://www.medellin.gov.co/'],
      rules: _CountingRules([
        if (status == RestrictionDayStatus.restricted)
          RestrictionRule(
            id: 'performance-thursday',
            jurisdictionId: jurisdictionId,
            priority: 100,
            effect: RestrictionEffect.restrict,
            validFrom: DateTime(2026, 9),
            validUntil: DateTime(2026, 10, 31, 23, 59, 59),
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: const {4},
            digitPosition: RestrictionDigitPosition.lastNumeric,
            digits: jurisdictionId == 'co-ant-medellin' ? {6} : {1, 2, 3, 4, 5},
            timeWindows: const [
              RestrictionTimeWindow(startMinute: 300, endMinute: 540),
              RestrictionTimeWindow(startMinute: 960, endMinute: 1200),
            ],
            appliesOnHolidays: false,
          ),
      ], () => ruleReads++),
    );
  }
}

// Counts real rule traversal without adding production profiling hooks.
class _CountingRules extends ListBase<RestrictionRule> {
  _CountingRules(this.values, this.onRead);

  final List<RestrictionRule> values;
  final VoidCallback onRead;

  @override
  int get length => values.length;

  @override
  set length(int value) => throw UnsupportedError('Immutable fixture');

  @override
  RestrictionRule operator [](int index) {
    onRead();
    return values[index];
  }

  @override
  void operator []=(int index, RestrictionRule value) =>
      throw UnsupportedError('Immutable fixture');
}
