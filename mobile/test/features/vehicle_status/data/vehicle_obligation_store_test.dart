import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
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

    group('initial alert preference', () {
      for (final pair in [
        (VehicleObligationType.soat, AlertCategory.soat),
        (VehicleObligationType.rtm, AlertCategory.rtm),
        (VehicleObligationType.insurance, AlertCategory.insurance),
      ]) {
        for (final enabled in [false, true]) {
          test(
            '${pair.$1.value} inherits saved $enabled only on creation',
            () async {
              final alerts = AlertSettingsStore(database);
              final settings = AlertSettings(enabled: enabled, minute: 615);
              await alerts.save('vehicle-1', pair.$2, settings);
              expect(await store.get('vehicle-1', pair.$1), isNull);
              final created = await store.upsert(
                vehicleId: 'vehicle-1',
                type: pair.$1,
                startDate: DateTime(2026, 1, 1),
                dueDate: DateTime(2027, 1, 1),
                details: const {'policyNumber': 'synthetic-policy'},
                reminderEnabled: !enabled,
              );
              expect(created.reminderEnabled, enabled);
              expect(created.startDate, DateTime(2026, 1, 1));
              expect(created.dueDate, DateTime(2027, 1, 1));
              expect(created.details, {'policyNumber': 'synthetic-policy'});
              for (final moduleEnabled in [!enabled, enabled]) {
                final edited = await store.upsert(
                  vehicleId: 'vehicle-1',
                  type: pair.$1,
                  startDate: created.startDate,
                  dueDate: created.dueDate,
                  details: created.details,
                  reminderEnabled: moduleEnabled,
                );
                expect(edited.reminderEnabled, moduleEnabled);
                expect(
                  (await store.get('vehicle-1', pair.$1))!.reminderEnabled,
                  moduleEnabled,
                );
                expect(edited.createdAt, created.createdAt);
                expect(edited.startDate, created.startDate);
                expect(edited.dueDate, created.dueDate);
                expect(edited.details, created.details);
                expect(
                  (await alerts.load('vehicle-1', pair.$2))!.toJson(),
                  settings.toJson(),
                );
              }
            },
          );
        }
      }

      test('OFF is inherited with the default creation argument', () async {
        await AlertSettingsStore(database).save(
          'vehicle-1',
          AlertCategory.soat,
          const AlertSettings(enabled: false),
        );
        final created = await store.upsert(
          vehicleId: 'vehicle-1',
          type: VehicleObligationType.soat,
        );
        expect(created.reminderEnabled, isFalse);
      });

      test('does not leak across vehicles categories or tax', () async {
        await database
            .into(database.vehicles)
            .insert(VehiclesCompanion.insert(id: 'vehicle-2', plate: 'DEF456'));
        await AlertSettingsStore(database).save(
          'vehicle-1',
          AlertCategory.soat,
          const AlertSettings(enabled: false),
        );
        for (final pair in [
          ('vehicle-2', VehicleObligationType.soat),
          ('vehicle-1', VehicleObligationType.rtm),
          ('vehicle-1', VehicleObligationType.insurance),
          ('vehicle-1', VehicleObligationType.tax),
        ]) {
          expect(
            (await store.upsert(
              vehicleId: pair.$1,
              type: pair.$2,
            )).reminderEnabled,
            isTrue,
          );
        }
      });

      test(
        'corrupt matching settings reject creation without losing raw',
        () async {
          const raw = '{"enabled":"false"}';
          await database.writeAlertSettings('vehicle-1', 'soat', raw);
          await expectLater(
            store.upsert(
              vehicleId: 'vehicle-1',
              type: VehicleObligationType.soat,
            ),
            throwsFormatException,
          );
          expect(await store.listAll(), isEmpty);
          expect(
            (await database.readAlertSettings()).single.read<String>(
              'settings_json',
            ),
            raw,
          );
        },
      );

      test(
        'existing module reminder ignores stale corrupt alert settings',
        () async {
          await store.upsert(
            vehicleId: 'vehicle-1',
            type: VehicleObligationType.soat,
          );
          await database.writeAlertSettings('vehicle-1', 'soat', '{broken');
          final edited = await store.upsert(
            vehicleId: 'vehicle-1',
            type: VehicleObligationType.soat,
            reminderEnabled: false,
          );
          expect(edited.reminderEnabled, isFalse);
          expect(
            (await database.readAlertSettings()).single.read<String>(
              'settings_json',
            ),
            '{broken',
          );
        },
      );

      test(
        'failed creation rolls back the insert and trigger side effects',
        () async {
          final alerts = AlertSettingsStore(database);
          const settings = AlertSettings(enabled: false, minute: 615);
          await alerts.save('vehicle-1', AlertCategory.soat, settings);
          await database.customStatement('''
          CREATE TRIGGER fail_creation AFTER INSERT ON vehicle_obligations
          BEGIN
            UPDATE alert_delivery_settings SET settings_json = '{}';
            SELECT RAISE(FAIL, 'synthetic creation failure');
          END
        ''');
          await expectLater(
            store.upsert(
              vehicleId: 'vehicle-1',
              type: VehicleObligationType.soat,
            ),
            throwsA(
              predicate<Object>(
                (error) =>
                    error.toString().contains('synthetic creation failure'),
              ),
            ),
          );
          expect(await store.listAll(), isEmpty);
          expect(
            (await alerts.load('vehicle-1', AlertCategory.soat))!.toJson(),
            settings.toJson(),
          );
        },
      );

      test(
        'creation participates in the caller transaction rollback',
        () async {
          final alerts = AlertSettingsStore(database);
          await expectLater(
            database.transaction(() async {
              await alerts.save(
                'vehicle-1',
                AlertCategory.soat,
                const AlertSettings(enabled: false),
              );
              final created = await store.upsert(
                vehicleId: 'vehicle-1',
                type: VehicleObligationType.soat,
              );
              expect(created.reminderEnabled, isFalse);
              throw StateError('synthetic outer failure');
            }),
            throwsStateError,
          );
          expect(await store.listAll(), isEmpty);
          expect(await alerts.loadAll(), isEmpty);
        },
      );
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
