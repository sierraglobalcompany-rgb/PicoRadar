import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/garage_favorites.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_preferences.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('VehicleRepository', () {
    late AppDatabase db;
    late _MemoryPreferences preferences;
    late VehicleRepository repository;
    var vehicleIdSequence = 0;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      preferences = _MemoryPreferences();
      vehicleIdSequence = 0;
      repository = VehicleRepository(
        database: db,
        preferences: preferences,
        idGenerator: () {
          vehicleIdSequence += 1;
          return vehicleIdSequence.toString().padLeft(32, '0');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<VehicleProfile> create(String plate, String nickname) => repository
        .createVehicle(plate: plate, kind: VehicleKind.car, nickname: nickname);

    Future<void> legacy(List<String> ids) => preferences.setString(
      garageFavoriteVehicleIdsPreferenceKey,
      jsonEncode(ids),
    );

    test(
      'first create selects favorite and later create preserves it',
      () async {
        final first = await create('ZZZ111', 'Zulu');
        expect(
          await preferences.getString(
            VehicleRepository.activeVehiclePreferenceKey,
          ),
          first.id,
        );
        await create('AAA111', 'Alpha');
        expect((await repository.getActiveVehicle())?.id, first.id);
      },
    );

    test('preserves valid active over alphabetical legacy favorites', () async {
      final selected = await create('ZZZ111', 'Zulu');
      final alpha = await create('AAA111', 'Alpha');
      await repository.setActiveVehicle(selected.id);
      await legacy([alpha.id]);
      expect((await repository.getActiveVehicle())?.id, selected.id);
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        isNull,
      );
    });

    for (final active in <String?>[null, '', 'missing']) {
      test(
        'repairs $active active from alphabetical valid legacy favorites',
        () async {
          final zebra = await create('ZZZ111', 'Zebra');
          final beta = await create('BBB111', 'Beta');
          await create('AAA111', 'Alpha');
          await legacy(['missing', zebra.id, beta.id]);
          if (active == null) {
            await preferences.remove(
              VehicleRepository.activeVehiclePreferenceKey,
            );
          } else {
            await preferences.setString(
              VehicleRepository.activeVehiclePreferenceKey,
              active,
            );
          }
          expect((await repository.getActiveVehicle())?.id, beta.id);
          expect(
            await preferences.getString(
              VehicleRepository.activeVehiclePreferenceKey,
            ),
            beta.id,
          );
          expect(
            await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
            isNull,
          );
        },
      );
    }

    test(
      'falls back alphabetically using nickname then brand then default',
      () async {
        final unnamed = await create('AAA111', ' ');
        final branded = await repository.createVehicle(
          plate: 'ZZZ111',
          kind: VehicleKind.car,
          nickname: ' ',
          brand: ' zeta ',
        );
        final alpha = await repository.createVehicle(
          plate: 'BBB111',
          kind: VehicleKind.car,
          brand: ' alfa ',
        );
        await legacy(['missing']);
        await repository.clearActiveVehicle();
        expect((await repository.getActiveVehicle())?.id, alpha.id);
        await repository.deleteVehicle(alpha.id);
        expect((await repository.getActiveVehicle())?.id, unnamed.id);
        expect(await repository.getVehicle(branded.id), isNotNull);
      },
    );

    test('alphabetical ties use plate regardless of creation order', () async {
      await create('ZZZ111', ' alpha ');
      final first = await create('AAA111', 'ALPHA');
      await repository.clearActiveVehicle();
      expect((await repository.getActiveVehicle())?.id, first.id);
    });

    test('clear remains available and next get repairs favorite', () async {
      await create('ZZZ111', 'Zulu');
      final alpha = await create('AAA111', 'Alpha');
      await repository.clearActiveVehicle();
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        isNull,
      );
      expect((await repository.getActiveVehicle())?.id, alpha.id);
    });

    test(
      'new create repairs existing vehicles before considering new one',
      () async {
        final old = await create('ZZZ111', 'Zulu');
        await repository.clearActiveVehicle();
        await create('AAA111', 'Alpha');
        expect((await repository.getActiveVehicle())?.id, old.id);
      },
    );

    test('deleting favorite chooses alphabetical replacement', () async {
      final selected = await create('ZZZ111', 'Zulu');
      final alpha = await create('AAA111', 'Alpha');
      await create('BBB111', 'Beta');
      await repository.setActiveVehicle(selected.id);
      await repository.deleteVehicle(selected.id);
      expect((await repository.getActiveVehicle())?.id, alpha.id);
    });

    test('deleting nonfavorite preserves valid favorite', () async {
      final selected = await create('ZZZ111', 'Zulu');
      final alpha = await create('AAA111', 'Alpha');
      await repository.setActiveVehicle(selected.id);
      await repository.deleteVehicle(alpha.id);
      expect((await repository.getActiveVehicle())?.id, selected.id);
    });

    test(
      'delete favorite chooses alphabetical replacement over legacy favorites',
      () async {
        final selected = await create('ZZZ111', 'Zulu');
        final alpha = await create('AAA111', 'Alpha');
        final beta = await create('BBB111', 'Beta');
        await repository.setActiveVehicle(selected.id);
        await legacy([beta.id]);
        await repository.deleteVehicle(selected.id);
        expect((await repository.getActiveVehicle())?.id, alpha.id);
        expect(
          await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
          isNull,
        );
      },
    );

    test('empty garage clears stale selection and legacy ids', () async {
      await preferences.setString(
        VehicleRepository.activeVehiclePreferenceKey,
        'missing',
      );
      await legacy(['missing']);
      expect(await repository.getActiveVehicle(), isNull);
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        isNull,
      );
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        isNull,
      );
    });

    test('migration write failure preserves legacy for retry', () async {
      final vehicle = await create('AAA111', 'Alpha');
      await repository.clearActiveVehicle();
      await legacy([vehicle.id]);
      preferences.failSetKey = VehicleRepository.activeVehiclePreferenceKey;
      await expectLater(repository.getActiveVehicle(), throwsStateError);
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        jsonEncode([vehicle.id]),
      );
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        isNull,
      );
      preferences.failSetKey = null;
      expect((await repository.getActiveVehicle())?.id, vehicle.id);
    });

    test('legacy is removed only after selected write succeeds even for valid active', () async {
      final vehicle = await create('AAA111', 'Alpha');
      await repository.setActiveVehicle(vehicle.id);
      await legacy([vehicle.id]);
      preferences.failSetKey = VehicleRepository.activeVehiclePreferenceKey;
      await expectLater(repository.getActiveVehicle(), throwsStateError);
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        isNotNull,
      );
    });

    test('legacy cleanup failure is reported and retried without losing selected id', () async {
      final vehicle = await create('AAA111', 'Alpha');
      await repository.clearActiveVehicle();
      await legacy([vehicle.id]);
      preferences.failRemoveKey = garageFavoriteVehicleIdsPreferenceKey;
      await expectLater(repository.getActiveVehicle(), throwsStateError);
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        vehicle.id,
      );
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        isNotNull,
      );
      preferences.failRemoveKey = null;
      expect((await repository.getActiveVehicle())?.id, vehicle.id);
      expect(
        await preferences.getString(garageFavoriteVehicleIdsPreferenceKey),
        isNull,
      );
    });

    test('favorite write failure rolls back first vehicle insertion', () async {
      preferences.failSetKey = VehicleRepository.activeVehiclePreferenceKey;
      await expectLater(create('AAA111', 'Alpha'), throwsStateError);
      expect(await repository.listVehicles(), isEmpty);
      preferences.failSetKey = null;
      final retried = await create('AAA111', 'Alpha');
      expect((await repository.getActiveVehicle())?.id, retried.id);
    });

    for (final failedPreference in ['selection', 'legacy', 'visual']) {
      test(
        'delete preserves vehicle when $failedPreference preference fails',
        () async {
          final selected = await create('ZZZ111', 'Zulu');
          await create('AAA111', 'Alpha');
          await repository.setActiveVehicle(selected.id);
          await saveVehicleVisualOverride(
            preferences,
            selected.id,
            'veh_car_toyota_01',
          );
          if (failedPreference == 'selection') {
            preferences.failSetKey =
                VehicleRepository.activeVehiclePreferenceKey;
          } else if (failedPreference == 'legacy') {
            await legacy([selected.id]);
            preferences.failRemoveKey = garageFavoriteVehicleIdsPreferenceKey;
          } else {
            preferences.failRemoveKey = vehicleVisualPreferenceKey(selected.id);
          }
          await expectLater(
            repository.deleteVehicle(selected.id),
            throwsStateError,
          );
          expect(await repository.getVehicle(selected.id), isNotNull);
          expect(
            await loadVehicleVisualOverride(preferences, selected.id),
            'veh_car_toyota_01',
          );
          expect(
            await preferences.getString(
              VehicleRepository.activeVehiclePreferenceKey,
            ),
            selected.id,
          );
          preferences.failSetKey = null;
          preferences.failRemoveKey = null;
          expect((await repository.getActiveVehicle())?.id, selected.id);
        },
      );
    }

    test('last vehicle survives failure to clear selection', () async {
      final vehicle = await create('AAA111', 'Alpha');
      await repository.setActiveVehicle(vehicle.id);
      preferences.failRemoveKey = VehicleRepository.activeVehiclePreferenceKey;
      await expectLater(repository.deleteVehicle(vehicle.id), throwsStateError);
      expect(await repository.getVehicle(vehicle.id), isNotNull);
    });

    test(
      'delete restores cleared favorite when last vehicle cleanup fails',
      () async {
        final selected = await create('ZZZ111', 'Zulu');
        preferences.failRemoveKey = vehicleVisualPreferenceKey(selected.id);

        await expectLater(
          repository.deleteVehicle(selected.id),
          throwsStateError,
        );

        expect(await repository.getVehicle(selected.id), isNotNull);
        expect(
          await preferences.getString(
            VehicleRepository.activeVehiclePreferenceKey,
          ),
          selected.id,
        );
        expect((await repository.getActiveVehicle())?.id, selected.id);
      },
    );

    test('delete restores previous favorite after database failure', () async {
      final selected = await create('ZZZ111', 'Zulu');
      await create('AAA111', 'Alpha');
      await db.customStatement('''
        CREATE TEMP TRIGGER reject_vehicle_delete BEFORE DELETE ON vehicles
        BEGIN SELECT RAISE(ABORT, 'Delete rejected by test'); END;
      ''');

      await expectLater(repository.deleteVehicle(selected.id), throwsException);

      expect(await repository.getVehicle(selected.id), isNotNull);
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        selected.id,
      );
      expect((await repository.getActiveVehicle())?.id, selected.id);
    });

    test(
      'delete rollback reports both errors and leaves actual favorite readable',
      () async {
        final selected = await create('ZZZ111', 'Zulu');
        final replacement = await create('AAA111', 'Alpha');
        final rollbackError = StateError('Rollback write failed');
        preferences.failRemoveKey = vehicleVisualPreferenceKey(selected.id);
        preferences.beforeSet = (key, value) async {
          if (key == VehicleRepository.activeVehiclePreferenceKey &&
              value == selected.id) {
            throw rollbackError;
          }
        };

        await expectLater(
          repository.deleteVehicle(selected.id),
          throwsA(
            isA<VehicleDeletionRollbackException>()
                .having(
                  (error) => error.originalError,
                  'original error',
                  isA<StateError>().having(
                    (error) => error.message,
                    'message',
                    'Preference removal failed',
                  ),
                )
                .having(
                  (error) => error.rollbackError,
                  'rollback error',
                  same(rollbackError),
                )
                .having(
                  (error) => error.originalStackTrace.toString(),
                  'original stack',
                  isNotEmpty,
                )
                .having(
                  (error) => error.rollbackStackTrace.toString(),
                  'rollback stack',
                  isNotEmpty,
                ),
          ),
        );

        expect(await repository.getVehicle(selected.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, replacement.id);
      },
    );

    test('delete rollback completes inside queue before pending reads and selections', () async {
      final selected = await create('ZZZ111', 'Zulu');
      final replacement = await create('AAA111', 'Alpha');
      final restoring = Completer<void>();
      final release = Completer<void>();
      preferences.failRemoveKey = vehicleVisualPreferenceKey(selected.id);
      preferences.beforeSet = (key, value) async {
        if (key == VehicleRepository.activeVehiclePreferenceKey &&
            value == selected.id) {
          restoring.complete();
          await release.future;
        }
      };
      final deletion = expectLater(
        repository.deleteVehicle(selected.id),
        throwsStateError,
      );
      await restoring.future;
      final queuedRead = repository.getActiveVehicle();
      final queuedSelection = repository.setActiveVehicle(replacement.id);
      release.complete();
      await deletion;

      expect((await queuedRead)?.id, selected.id);
      await queuedSelection;
      expect((await repository.getActiveVehicle())?.id, replacement.id);
    });

    test(
      'delete rollback does not restore an invalid previous favorite',
      () async {
        final selected = await create('ZZZ111', 'Zulu');
        final replacement = await create('AAA111', 'Alpha');
        await preferences.setString(
          VehicleRepository.activeVehiclePreferenceKey,
          'missing',
        );
        preferences.failRemoveKey = vehicleVisualPreferenceKey(selected.id);

        await expectLater(
          repository.deleteVehicle(selected.id),
          throwsStateError,
        );

        expect(await repository.getVehicle(selected.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, replacement.id);
      },
    );

    test(
      'set validates id and leaves existing selection on write failure',
      () async {
        final selected = await create('AAA111', 'Alpha');
        final other = await create('BBB111', 'Beta');
        await repository.setActiveVehicle(selected.id);
        await expectLater(
          repository.setActiveVehicle('missing'),
          throwsA(isA<VehicleRepositoryException>()),
        );
        preferences.failSetKey = VehicleRepository.activeVehiclePreferenceKey;
        await expectLater(
          repository.setActiveVehicle(other.id),
          throwsStateError,
        );
        expect(
          await preferences.getString(
            VehicleRepository.activeVehiclePreferenceKey,
          ),
          selected.id,
        );
      },
    );

    test(
      'rapid selection calls serialize across repositories sharing preferences',
      () async {
        final alpha = await create('AAA111', 'Alpha');
        final beta = await create('BBB111', 'Beta');
        final otherRepository = VehicleRepository(
          database: db,
          preferences: preferences,
        );
        final started = Completer<void>();
        final release = Completer<void>();
        preferences.beforeSet = (key, value) async {
          if (key == VehicleRepository.activeVehiclePreferenceKey &&
              value == alpha.id) {
            started.complete();
            await release.future;
          }
        };
        final first = repository.setActiveVehicle(alpha.id);
        await started.future;
        final second = otherRepository.setActiveVehicle(beta.id);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        release.complete();
        await Future.wait([first, second]);
        preferences.beforeSet = null;
        expect((await repository.getActiveVehicle())?.id, beta.id);
      },
    );

    test('repository operations join existing preference queue', () async {
      final vehicle = await create('AAA111', 'Alpha');
      final started = Completer<void>();
      final release = Completer<void>();
      final blocker = serializeGarageFavoriteMutation(preferences, () async {
        started.complete();
        await release.future;
      });
      await started.future;
      var completed = false;
      final deletion = repository
          .deleteVehicle(vehicle.id)
          .then((_) => completed = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final completedWhileBlocked = completed;
      release.complete();
      await blocker;
      await deletion;
      expect(completedWhileBlocked, isFalse);
      expect(await repository.getActiveVehicle(), isNull);
    });

    test('rapid create delete and get never expose deleted favorite', () async {
      final creations = await Future.wait([
        create('ZZZ111', 'Zulu'),
        create('AAA111', 'Alpha'),
        create('BBB111', 'Beta'),
      ]);
      expect((await repository.getActiveVehicle())?.id, creations.first.id);
      final deletion = repository.deleteVehicle(creations.first.id);
      final selected = repository.getActiveVehicle();
      await deletion;
      expect((await selected)?.id, creations[1].id);
    });

    test(
      'shared comparator uses trimmed case-insensitive label then plate and id',
      () {
        VehicleProfile profile(
          String id,
          String plate, {
          String? nickname,
          String? brand,
        }) => VehicleProfile(
          id: id,
          plate: plate,
          kind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          nickname: nickname,
          brand: brand,
        );
        final vehicles = [
          profile('z', 'ZZZ111', nickname: ' Zulu', brand: 'Aardvark'),
          profile('default', 'AAA111', nickname: ' ', brand: ''),
          profile('c', 'BBB111', brand: ' ALPHA '),
          profile('b', 'AAA111', nickname: 'alpha', brand: 'Zeta'),
          profile('a', 'AAA111', nickname: ' Alpha '),
        ]..sort(compareVehiclesAlphabetically);
        expect(vehicles.map((vehicle) => vehicle.id), [
          'a',
          'b',
          'c',
          'default',
          'z',
        ]);
        expect(
          compareVehiclesAlphabetically(vehicles.first, vehicles.first),
          0,
        );
      },
    );

    test('creates a private car', () async {
      final vehicle = await repository.createVehicle(
        plate: 'abc 123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        subtype: ' car_sedan ',
        registrationCity: ' Bogota ',
        brand: ' Mazda ',
        model: ' 2 ',
        year: 2021,
        color: ' Rojo ',
        fuel: ' Gasolina ',
      );

      expect(vehicle.plate, 'ABC123');
      expect(vehicle.kind, VehicleKind.car);
      expect(vehicle.serviceType, VehicleServiceType.private);
      expect(vehicle.subtype, 'car_sedan');
      expect(vehicle.registrationCity, 'Bogota');
      expect(vehicle.brand, 'Mazda');
      expect(vehicle.model, '2');
      expect(vehicle.year, 2021);
      expect(vehicle.color, 'Rojo');
      expect(vehicle.fuel, 'Gasolina');
    });

    test('creates a taxi as car with taxi service type', () async {
      final vehicle = await repository.createVehicle(
        plate: 'tax 123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
        subtype: 'taxi',
      );

      expect(vehicle.plate, 'TAX123');
      expect(vehicle.kind, VehicleKind.car);
      expect(vehicle.serviceType, VehicleServiceType.taxi);
      expect(vehicle.subtype, 'taxi');
    });

    test('creates a motorcycle', () async {
      final vehicle = await repository.createVehicle(
        plate: 'moto-01',
        kind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
        subtype: 'moto_scooter',
      );

      expect(vehicle.plate, 'MOTO01');
      expect(vehicle.kind, VehicleKind.motorcycle);
      expect(vehicle.serviceType, VehicleServiceType.private);
      expect(vehicle.subtype, 'moto_scooter');
    });

    test('rejects motorcycle with taxi service type', () async {
      await expectLater(
        repository.createVehicle(
          plate: 'MOT123',
          kind: VehicleKind.motorcycle,
          serviceType: VehicleServiceType.taxi,
        ),
        throwsA(isA<VehicleRepositoryException>()),
      );
    });

    test('normalizes plates without over-restricting formats', () {
      expect(VehicleRepository.normalizePlate('abc 123'), 'ABC123');
      expect(VehicleRepository.normalizePlate('abc-123'), 'ABC123');
      expect(VehicleRepository.normalizePlate(' AbC123 '), 'ABC123');
      expect(VehicleRepository.normalizePlate('AB12CD34'), 'AB12CD34');
    });

    test('rejects duplicate normalized plates', () async {
      await repository.createVehicle(plate: 'abc 123', kind: VehicleKind.car);

      await expectLater(
        repository.createVehicle(
          plate: 'ABC-123',
          kind: VehicleKind.motorcycle,
        ),
        throwsException,
      );
    });

    test('lists multiple vehicles', () async {
      final car = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );
      final motorcycle = await repository.createVehicle(
        plate: 'BBB222',
        kind: VehicleKind.motorcycle,
      );

      final vehicles = await repository.listVehicles();

      expect(vehicles.map((vehicle) => vehicle.id), contains(car.id));
      expect(vehicles.map((vehicle) => vehicle.id), contains(motorcycle.id));
      expect(vehicles, hasLength(2));
    });

    test('updates a vehicle while preserving createdAt', () async {
      final created = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
        nickname: 'Inicial',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final updated = await repository.updateVehicle(
        id: created.id,
        plate: 'bbb 222',
        kind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
        nickname: 'Actualizado',
        registrationCity: 'Medellin',
      );

      expect(updated.plate, 'BBB222');
      expect(updated.kind, VehicleKind.motorcycle);
      expect(updated.serviceType, VehicleServiceType.private);
      expect(updated.nickname, 'Actualizado');
      expect(updated.registrationCity, 'Medellin');
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
    });

    test('updates a private car to taxi when kind is car', () async {
      final created = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );

      final updated = await repository.updateVehicle(
        id: created.id,
        plate: 'AAA111',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
      );

      expect(updated.kind, VehicleKind.car);
      expect(updated.serviceType, VehicleServiceType.taxi);
    });

    test('conserves service type when reading and listing vehicles', () async {
      final taxi = await repository.createVehicle(
        plate: 'TAX123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
      );

      final read = await repository.getVehicle(taxi.id);
      final listed = await repository.listVehicles();

      expect(read?.serviceType, VehicleServiceType.taxi);
      expect(listed.single.serviceType, VehicleServiceType.taxi);
    });

    test('deletes a vehicle', () async {
      final vehicle = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );

      await repository.deleteVehicle(vehicle.id);

      expect(await repository.getVehicle(vehicle.id), isNull);
      expect(await repository.listVehicles(), isEmpty);
    });

    test('deleting a vehicle clears its visual override preference', () async {
      final vehicle = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );
      await saveVehicleVisualOverride(
        preferences,
        vehicle.id,
        'veh_car_toyota_01',
      );

      await repository.deleteVehicle(vehicle.id);

      expect(await loadVehicleVisualOverride(preferences, vehicle.id), isNull);
    });

    test('sets and gets active vehicle', () async {
      final vehicle = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );

      await repository.setActiveVehicle(vehicle.id);

      expect((await repository.getActiveVehicle())?.id, vehicle.id);
      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        vehicle.id,
      );
    });

    test(
      'cleans active vehicle preference when stored id no longer exists',
      () async {
        await preferences.setString(
          VehicleRepository.activeVehiclePreferenceKey,
          'missing',
        );

        expect(await repository.getActiveVehicle(), isNull);
        expect(
          await preferences.getString(
            VehicleRepository.activeVehiclePreferenceKey,
          ),
          isNull,
        );
      },
    );

    test(
      'cleans active vehicle preference when deleting active vehicle',
      () async {
        final vehicle = await repository.createVehicle(
          plate: 'AAA111',
          kind: VehicleKind.car,
        );
        await repository.setActiveVehicle(vehicle.id);

        await repository.deleteVehicle(vehicle.id);

        expect(await repository.getActiveVehicle(), isNull);
        expect(
          await preferences.getString(
            VehicleRepository.activeVehiclePreferenceKey,
          ),
          isNull,
        );
      },
    );

    test('keeps optional fields null when omitted or blank', () async {
      final vehicle = await repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
        nickname: ' ',
        brand: '',
      );

      expect(vehicle.subtype, isNull);
      expect(vehicle.nickname, isNull);
      expect(vehicle.registrationCity, isNull);
      expect(vehicle.brand, isNull);
      expect(vehicle.model, isNull);
      expect(vehicle.year, isNull);
      expect(vehicle.color, isNull);
      expect(vehicle.fuel, isNull);
    });

    test('rejects invalid years', () async {
      await expectLater(
        repository.createVehicle(
          plate: 'AAA111',
          kind: VehicleKind.car,
          year: 1899,
        ),
        throwsA(isA<VehicleRepositoryException>()),
      );
      await expectLater(
        repository.createVehicle(
          plate: 'BBB222',
          kind: VehicleKind.car,
          year: DateTime.now().year + 2,
        ),
        throwsA(isA<VehicleRepositoryException>()),
      );
    });
  });
}

class _MemoryPreferences implements AppPreferences {
  final _values = <String, Object?>{};
  String? failSetKey;
  String? failRemoveKey;
  Future<void> Function(String key, String value)? beforeSet;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    if (key == failRemoveKey) throw StateError('Preference removal failed');
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (key == failSetKey) throw StateError('Preference write failed');
    await beforeSet?.call(key, value);
    _values[key] = value;
  }
}
