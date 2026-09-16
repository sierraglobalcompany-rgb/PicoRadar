import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('VehicleObligationStore', () {
    late AppDatabase database;
    late VehicleObligationStore store;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      store = VehicleObligationStore(database);
      await _insertVehicle(database, 'vehicle-1');
    });

    tearDown(() async {
      await database.close();
    });

    test('upserts SOAT with deterministic id and local details', () async {
      final obligation = await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.soat,
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 31),
        details: const {
          'insurerName': 'Seguros Alfa',
          'policyNumber': 'POL-123',
        },
      );

      expect(obligation.id, 'vehicle-1:soat');
      expect(obligation.type, VehicleObligationType.soat);
      expect(obligation.startDate, DateTime(2026, 1, 1));
      expect(obligation.dueDate, DateTime(2026, 12, 31));
      expect(obligation.reminderEnabled, isTrue);
      expect(obligation.details['insurerName'], 'Seguros Alfa');
      expect(obligation.details['policyNumber'], 'POL-123');
    });

    test(
      'tax authority patch preserves unrelated data and is idempotent',
      () async {
        final previous = await store.upsert(
          vehicleId: 'vehicle-1',
          type: VehicleObligationType.tax,
          dueDate: DateTime(2026, 12, 1),
          details: const {'authorityId': 'bogota', 'note': 'keep'},
          reminderEnabled: false,
        );
        final saved = await store.saveTaxAuthority('vehicle-1', 'antioquia');
        expect(saved.details, {'authorityId': 'antioquia', 'note': 'keep'});
        expect(saved.dueDate, previous.dueDate);
        expect(saved.createdAt, previous.createdAt);
        expect(saved.reminderEnabled, isFalse);
        final again = await store.saveTaxAuthority('vehicle-1', 'antioquia');
        expect(again.updatedAt, saved.updatedAt);
      },
    );

    test('tax authority patch does not recreate a deleted vehicle', () async {
      await (database.delete(
        database.vehicles,
      )..where((row) => row.id.equals('vehicle-1'))).go();
      await expectLater(
        store.saveTaxAuthority('vehicle-1', 'bogota'),
        throwsStateError,
      );
      expect(await store.listAll(), isEmpty);
    });

    test('lists obligations by vehicle and supports RTM data', () async {
      await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.rtm,
        dueDate: DateTime(2026, 9, 15),
        details: const {'cdaName': 'CDA Norte'},
        reminderEnabled: false,
      );

      final obligations = await store.listForVehicle('vehicle-1');

      expect(obligations, hasLength(1));
      expect(obligations.single.id, 'vehicle-1:rtm');
      expect(obligations.single.details['cdaName'], 'CDA Norte');
      expect(obligations.single.reminderEnabled, isFalse);
    });

    test('stores voluntary insurance assistance fields', () async {
      final obligation = await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.insurance,
        details: const {
          'providerName': 'Seguros Bolívar S.A.',
          'policyNumber': 'VOL-456',
          'assistancePhone': '601 111 1111',
          'towPhone': '601-222-2222',
          'designatedDriverPhone': '300 333 3333',
        },
      );

      expect(obligation.details['providerName'], 'Seguros Bolívar S.A.');
      expect(obligation.details['policyNumber'], 'VOL-456');
      expect(obligation.details['assistancePhone'], '601 111 1111');
      expect(obligation.details['towPhone'], '601-222-2222');
      expect(obligation.details['designatedDriverPhone'], '300 333 3333');
    });

    test('deletes one obligation without touching other types', () async {
      await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.soat,
      );
      await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.rtm,
      );

      await store.delete('vehicle-1', VehicleObligationType.soat);

      expect(await store.get('vehicle-1', VehicleObligationType.soat), isNull);
      expect(
        await store.get('vehicle-1', VehicleObligationType.rtm),
        isNotNull,
      );
    });

    test('vehicle cascade removes local obligations', () async {
      await store.upsert(
        vehicleId: 'vehicle-1',
        type: VehicleObligationType.soat,
      );

      await (database.delete(
        database.vehicles,
      )..where((row) => row.id.equals('vehicle-1'))).go();

      expect(await store.listAll(), isEmpty);
    });

    test('malformed details json is ignored safely', () async {
      final now = DateTime.utc(2026);
      await database
          .into(database.vehicleObligations)
          .insert(
            VehicleObligationsCompanion.insert(
              id: 'vehicle-1:soat',
              vehicleId: 'vehicle-1',
              type: 'soat',
              status: 'configured',
              detailsJson: const Value('{bad'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final obligation = await store.get(
        'vehicle-1',
        VehicleObligationType.soat,
      );

      expect(obligation?.details, isEmpty);
    });
  });
}

Future<void> _insertVehicle(AppDatabase database, String id) async {
  await database
      .into(database.vehicles)
      .insert(VehiclesCompanion.insert(id: id, plate: 'ABC123'));
}
