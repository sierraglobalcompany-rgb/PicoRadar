import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('VehicleRepository', () {
    late AppDatabase db;
    late _MemoryPreferences preferences;
    late VehicleRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      preferences = _MemoryPreferences();
      repository = VehicleRepository(database: db, preferences: preferences);
    });

    tearDown(() async {
      await db.close();
    });

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

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
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
    _values[key] = value;
  }
}
