import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/onboarding/presentation/onboarding_vehicle_screen.dart';

void main() {
  late AppDatabase database;
  late _Preferences preferences;
  late VehicleRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    preferences = _Preferences();
    repository = VehicleRepository(
      database: database,
      preferences: preferences,
    );
  });
  tearDown(() => database.close());

  Future<GoRouter> open(WidgetTester tester, {String? vehicleId}) async {
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/add',
          builder: (_, _) => OnboardingVehicleScreen(vehicleId: vehicleId),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Saved home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appPreferencesProvider.overrideWithValue(preferences),
          vehicleRepositoryProvider.overrideWithValue(repository),
          registrationCityCatalogProvider.overrideWith(
            (_) async => const RegistrationCityCatalog(records: []),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return router;
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('vehicle-save-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  void seed() {
    preferences.values[onboardingVehicleDraftKey] = jsonEncode({
      'choice': 'privateCar',
      'plate': 'ABC123',
      'registrationCity': 'Bogota',
    });
  }

  for (final raw in [null, '{"choice":"privateCar"}']) {
    testWidgets('late draft read after disposal is harmless: $raw', (
      tester,
    ) async {
      final pending = Completer<String?>();
      preferences.draftRead = pending;
      await open(tester);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(raw);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(preferences.values[onboardingVehicleDraftKey], isNull);
    });
  }

  for (final raw in [
    '{broken',
    '[]',
    '{"plate":42}',
    '{"choice":"unknown"}',
    '{"choice":"motorcycle","subtype":"car_sedan"}',
    '{"alertsEnabled":"true"}',
  ]) {
    testWidgets('corrupt draft stays intact and exposes retry: $raw', (
      tester,
    ) async {
      preferences.values[onboardingVehicleDraftKey] = raw;
      await open(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('borrador'), findsWidgets);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vehicle-choice-privateCar')),
        findsNothing,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(preferences.values[onboardingVehicleDraftKey], raw);
      expect(await repository.listVehicles(), isEmpty);
    });
  }

  testWidgets('failed draft read can be retried without overwriting it', (
    tester,
  ) async {
    seed();
    preferences.failRead = true;
    await open(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Reintentar'), findsOneWidget);
    preferences.failRead = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vehicle-plate-field')), findsOneWidget);
  });

  testWidgets('missing edit target shows recovery without a create form', (
    tester,
  ) async {
    await open(tester, vehicleId: 'missing');
    await tester.pumpAndSettle();
    expect(find.textContaining('no encontrado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vehicle-choice-privateCar')),
      findsNothing,
    );
  });

  testWidgets('duplicate plate keeps form and shows a useful error', (
    tester,
  ) async {
    await repository.createVehicle(plate: 'ABC123', kind: VehicleKind.car);
    seed();
    await open(tester);
    await tester.pumpAndSettle();
    await save(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ya existe'), findsOneWidget);
    expect(await repository.listVehicles(), hasLength(1));
    expect(preferences.values[onboardingVehicleDraftKey], isNotNull);
  });

  for (final failure in ['alerts', 'remove', 'draft']) {
    testWidgets('retry after $failure failure completes one vehicle', (
      tester,
    ) async {
      seed();
      preferences.failure = failure;
      await open(tester);
      await tester.pumpAndSettle();
      await save(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Reintenta'), findsOneWidget);
      final before = (await repository.listVehicles()).single;
      expect(preferences.values[onboardingVehicleDraftKey], isNotNull);
      preferences.failure = null;
      await save(tester);
      expect(tester.takeException(), isNull);
      expect((await repository.listVehicles()).single.id, before.id);
      expect(preferences.values[onboardingVehicleDraftKey], isNull);
      expect(find.text('Saved home'), findsOneWidget);
    });
  }

  testWidgets('reopening a partial save resumes the same vehicle', (
    tester,
  ) async {
    seed();
    preferences.failure = 'remove';
    await open(tester);
    await tester.pumpAndSettle();
    await save(tester);
    final savedId = (await repository.listVehicles()).single.id;
    await tester.pumpWidget(const SizedBox());
    preferences.failure = null;
    await open(tester);
    await tester.pumpAndSettle();
    await save(tester);
    expect((await repository.listVehicles()).single.id, savedId);
    expect(preferences.values[onboardingVehicleDraftKey], isNull);
    expect(find.text('Saved home'), findsOneWidget);
  });

  testWidgets('late vehicle commit after disposal completes safely', (
    tester,
  ) async {
    seed();
    final pending = Completer<void>();
    preferences.activeWrite = pending;
    await open(tester);
    await tester.pumpAndSettle();
    await save(tester);
    expect(preferences.activeWriteStarted, isTrue);
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await repository.listVehicles(), hasLength(1));
  });

  testWidgets('queued draft writes finish before final cleanup', (
    tester,
  ) async {
    seed();
    await open(tester);
    await tester.pumpAndSettle();
    final pending = Completer<void>();
    preferences.draftWrite = pending;
    final plate = find.byKey(const ValueKey('vehicle-plate-field'));
    await tester.enterText(plate, 'NEW123');
    await tester.pump();
    await tester.enterText(plate, 'NEW456');
    await save(tester);
    pending.complete();
    await tester.pumpAndSettle();
    expect((await repository.listVehicles()).single.plate, 'NEW456');
    expect(preferences.values[onboardingVehicleDraftKey], isNull);
    expect(find.text('Saved home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late alert save after disposal never reads a disposed ref', (
    tester,
  ) async {
    seed();
    final pending = Completer<void>();
    preferences.alertWrite = pending;
    await open(tester);
    await tester.pumpAndSettle();
    await save(tester);
    expect(await repository.listVehicles(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft write error is visible without escaping the listener', (
    tester,
  ) async {
    seed();
    await open(tester);
    await tester.pumpAndSettle();
    preferences.failure = 'draft';
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-plate-field')),
      'NEW123',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('borrador'), findsWidgets);
  });

  test(
    'duplicate create raises a domain error and preserves existing vehicle',
    () async {
      final original = await repository.createVehicle(
        plate: 'ABC123',
        kind: VehicleKind.car,
      );
      await expectLater(
        repository.createVehicle(plate: 'abc-123', kind: VehicleKind.car),
        throwsA(isA<VehicleRepositoryException>()),
      );
      expect((await repository.listVehicles()).single.id, original.id);
    },
  );

  test('duplicate edit raises a domain error and keeps both plates', () async {
    await repository.createVehicle(plate: 'ABC123', kind: VehicleKind.car);
    final other = await repository.createVehicle(
      plate: 'DEF456',
      kind: VehicleKind.car,
    );
    await expectLater(
      repository.updateVehicle(
        id: other.id,
        plate: 'abc 123',
        kind: VehicleKind.car,
      ),
      throwsA(isA<VehicleRepositoryException>()),
    );
    expect((await repository.getVehicle(other.id))!.plate, 'DEF456');
  });
}

class _Preferences implements AppPreferences {
  final values = <String, Object?>{};
  Completer<String?>? draftRead;
  Completer<void>? alertWrite;
  Completer<void>? activeWrite;
  Completer<void>? draftWrite;
  bool activeWriteStarted = false;
  String? failure;
  bool failRead = false;

  @override
  Future<String?> getString(String key) async {
    if (key == onboardingVehicleDraftKey) {
      if (failRead) throw StateError('Read unavailable');
      if (draftRead != null) return draftRead!.future;
    }
    return values[key] as String?;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (key == VehicleRepository.activeVehiclePreferenceKey &&
        activeWrite != null) {
      activeWriteStarted = true;
      await activeWrite!.future;
    }
    if (key == onboardingVehicleDraftKey && draftWrite != null) {
      await draftWrite!.future;
    }
    if (key == onboardingVehicleDraftKey && failure == 'draft') {
      throw StateError('Write unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (key == picoRestrictionAlertsPreferenceKey) {
      if (failure == 'alerts') throw StateError('Write unavailable');
      if (alertWrite != null) await alertWrite!.future;
    }
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (key == onboardingVehicleDraftKey && failure == 'remove') {
      throw StateError('Remove unavailable');
    }
    values.remove(key);
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }
}
