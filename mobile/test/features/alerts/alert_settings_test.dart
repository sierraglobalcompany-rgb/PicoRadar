import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';

void main() {
  test('new delivery options are off and offsets retain legacy defaults', () {
    const settings = AlertSettings();
    expect(settings.alarm, isFalse);
    expect(settings.enriched, isFalse);
    expect(settings.offsetDays, [30, 7, 1]);
    expect(settings.minute, 540);
    expect(
      AlertSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
  });

  test('invalid persisted values are not silently converted into alarms', () {
    expect(
      () => AlertSettings.fromJson({'alarm': 'true'}),
      throwsFormatException,
    );
    expect(
      () => AlertSettings.fromJson({'minute': 1440}),
      throwsFormatException,
    );
    expect(
      () => AlertSettings.fromJson({
        'offsetDays': [-1],
      }),
      throwsFormatException,
    );
  });

  test(
    'settings persist by vehicle/category and cascade without changing dates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = AlertSettingsStore(db);
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'v1', plate: 'DEM123'));
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'v2', plate: 'DEM456'));
      expect(await store.load('v1', AlertCategory.soat), isNull);
      await store.save(
        'v1',
        AlertCategory.soat,
        const AlertSettings(alarm: true),
      );
      expect((await store.load('v1', AlertCategory.soat))!.alarm, isTrue);
      expect(await store.load('v2', AlertCategory.soat), isNull);
      expect(await store.load('v1', AlertCategory.rtm), isNull);
      await (db.delete(db.vehicles)..where((t) => t.id.equals('v1'))).go();
      expect(await store.loadAll(), isEmpty);
    },
  );

  group('delivery settings integrity', () {
    late AppDatabase db;
    late AlertSettingsStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = AlertSettingsStore(db);
      for (final id in ['v1', 'v2']) {
        await db
            .into(db.vehicles)
            .insert(
              VehiclesCompanion.insert(
                id: id,
                plate: id == 'v1' ? 'DEM123' : 'DEM456',
              ),
            );
        for (final category in [
          AlertCategory.soat,
          AlertCategory.rtm,
          AlertCategory.insurance,
        ]) {
          await db
              .into(db.vehicleObligations)
              .insert(
                VehicleObligationsCompanion.insert(
                  id: '$id-${category.name}',
                  vehicleId: id,
                  type: category.name,
                  status: 'current',
                  startDate: Value(DateTime.utc(2026, 1, 15)),
                  dueDate: Value(DateTime.utc(2027, 1, 15)),
                  detailsJson: Value(
                    jsonEncode({
                      'policy': 'synthetic-$id',
                      'issuer': 'Fixture',
                    }),
                  ),
                  createdAt: Value(DateTime.utc(2026, 1, 1)),
                  updatedAt: Value(DateTime.utc(2026, 1, 2)),
                ),
              );
        }
      }
      await db
          .into(db.notificationPreferences)
          .insert(
            NotificationPreferencesCompanion.insert(
              id: 'local',
              restrictionAlertsEnabled: const Value(false),
              obligationRemindersEnabled: const Value(true),
              updatedAt: Value(DateTime.utc(2026, 1, 3)),
            ),
          );
    });
    tearDown(() => db.close());

    test(
      'single settings lookup does not decode other vehicle or category',
      () async {
        await store.save(
          'v1',
          AlertCategory.soat,
          const AlertSettings(enabled: false),
        );
        await db.writeAlertSettings('v2', 'soat', '{broken');
        await db.writeAlertSettings('v1', 'rtm', '{broken');
        expect((await store.load('v1', AlertCategory.soat))!.enabled, isFalse);
        expect(await store.load('v1', AlertCategory.insurance), isNull);
        await expectLater(store.loadAll(), throwsFormatException);
        final rows = await db.readAlertSettings();
        expect(
          rows.where((row) => row.read<String>('settings_json') == '{broken'),
          hasLength(2),
        );
      },
    );

    for (final category in AlertCategory.values) {
      test(
        'saving ${category.name} changes only its vehicle reminder flag',
        () async {
          final vehicles = await _rows(db, 'vehicles');
          final obligations = await _rows(db, 'vehicle_obligations');
          final preferences = await _rows(db, 'notification_preferences');
          for (final enabled in [false, true]) {
            final settings = AlertSettings(
              enabled: enabled,
              alarm: true,
              enriched: true,
              minute: 615,
              offsetDays: const [14, 3, 0],
            );
            await store.save('v1', category, settings);
            expect(
              (await store.load('v1', category))!.toJson(),
              settings.toJson(),
            );
            expect(await store.load('v2', category), isNull);
            expect(await store.loadAll(), hasLength(1));
            expect(await _rows(db, 'vehicles'), vehicles);
            expect(await _rows(db, 'notification_preferences'), preferences);
            expect(await _rows(db, 'vehicle_obligations'), [
              for (final row in obligations)
                {
                  ...row,
                  if (row['vehicle_id'] == 'v1' && row['type'] == category.name)
                    'reminder_enabled': enabled ? 1 : 0,
                },
            ]);
          }
        },
      );
    }

    for (final existing in [false, true]) {
      test(
        'failed reminder update rolls back settings and flag (existing=$existing)',
        () async {
          if (existing) {
            await store.save(
              'v1',
              AlertCategory.soat,
              const AlertSettings(minute: 600),
            );
          }
          final settings = await _rows(
            db,
            'alert_delivery_settings',
            orderBy: 'vehicle_id, category',
          );
          final obligations = await _rows(db, 'vehicle_obligations');
          // Fail after the flag update to exercise rollback of both writes.
          await db.customStatement('''
          CREATE TRIGGER fail_reminder AFTER UPDATE OF reminder_enabled
          ON vehicle_obligations WHEN NEW.vehicle_id = 'v1' AND NEW.type = 'soat'
          BEGIN SELECT RAISE(ABORT, 'synthetic reminder failure'); END
        ''');
          await expectLater(
            store.save(
              'v1',
              AlertCategory.soat,
              const AlertSettings(enabled: false, alarm: true),
            ),
            throwsA(
              predicate<Object>(
                (error) =>
                    error.toString().contains('synthetic reminder failure'),
              ),
            ),
          );
          expect(
            await _rows(
              db,
              'alert_delivery_settings',
              orderBy: 'vehicle_id, category',
            ),
            settings,
          );
          expect(await _rows(db, 'vehicle_obligations'), obligations);
        },
      );
    }

    test(
      'invalid save preserves the previous settings and obligations',
      () async {
        await store.save('v1', AlertCategory.soat, const AlertSettings());
        final settings = await _rows(
          db,
          'alert_delivery_settings',
          orderBy: 'vehicle_id, category',
        );
        final obligations = await _rows(db, 'vehicle_obligations');
        expect(
          () => store.save(
            'v1',
            AlertCategory.soat,
            const AlertSettings(enabled: false, minute: 1440),
          ),
          throwsFormatException,
        );
        expect(
          await _rows(
            db,
            'alert_delivery_settings',
            orderBy: 'vehicle_id, category',
          ),
          settings,
        );
        expect(await _rows(db, 'vehicle_obligations'), obligations);
      },
    );

    final corruptions = <String, String>{
      'invalid JSON': '{broken',
      'wrong flag type': '{"alarm":"true"}',
      'wrong nested offsets': '{"offsetDays":{"days":[30,7,1]}}',
      'duplicate offsets': '{"offsetDays":[7,7]}',
      'invalid minute': '{"minute":1440}',
      'unsupported version': '{"v":2}',
    };
    for (final corruption in corruptions.entries) {
      test(
        '${corruption.key} rejects loading and preserves raw data',
        () async {
          await store.save(
            'v2',
            AlertCategory.rtm,
            const AlertSettings(alarm: true),
          );
          await db.writeAlertSettings('v1', 'soat', corruption.value);
          final rows = await _rows(
            db,
            'alert_delivery_settings',
            orderBy: 'vehicle_id, category',
          );
          final obligations = await _rows(db, 'vehicle_obligations');
          await expectLater(store.loadAll(), throwsFormatException);
          await expectLater(
            store.load('v1', AlertCategory.soat),
            throwsFormatException,
          );
          expect(
            await _rows(
              db,
              'alert_delivery_settings',
              orderBy: 'vehicle_id, category',
            ),
            rows,
          );
          expect(rows.first['settings_json'], corruption.value);
          expect(await _rows(db, 'vehicle_obligations'), obligations);
        },
      );
    }
  });
}

Future<List<Map<String, Object?>>> _rows(
  AppDatabase db,
  String table, {
  String orderBy = 'id',
}) async => [
  for (final row
      in await db.customSelect('SELECT * FROM $table ORDER BY $orderBy').get())
    row.data,
];
