import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v8 to v9 preserves vehicles obligations and notification preferences', () async {
    final old = sqlite3.openInMemory();
    addTearDown(old.close);
    _seedV8(old);
    expect(old.select('PRAGMA user_version').single['user_version'], 8);
    expect(
      old.select(
        "SELECT name FROM sqlite_master WHERE name = 'alert_delivery_settings'",
      ),
      isEmpty,
    );
    final before = {
      for (final table in _preservedTables)
        table: old
            .select('SELECT * FROM $table ORDER BY id')
            .map(Map<String, Object?>.of)
            .toList(),
    };
    final schema = old
        .select('SELECT name, sql FROM sqlite_master ORDER BY name')
        .map(Map<String, Object?>.of)
        .toList();
    var db = AppDatabase(
      NativeDatabase.opened(old, closeUnderlyingOnClose: false),
    );
    try {
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        9,
      );
      expect(await AlertSettingsStore(db).loadAll(), isEmpty);
      for (final table in _preservedTables) {
        expect([
          for (final row
              in await db
                  .customSelect('SELECT * FROM $table ORDER BY id')
                  .get())
            row.data,
        ], before[table]);
      }
      expect(
        old
            .select(
              "SELECT name, sql FROM sqlite_master WHERE tbl_name <> 'alert_delivery_settings' ORDER BY name",
            )
            .map(Map<String, Object?>.of)
            .toList(),
        schema,
      );
      await AlertSettingsStore(db).save(
        'v1',
        AlertCategory.pico,
        const AlertSettings(enabled: false, minute: 615),
      );
      await db.close();
      db = AppDatabase(
        NativeDatabase.opened(old, closeUnderlyingOnClose: false),
      );
      final restored = await AlertSettingsStore(db)
          .load('v1', AlertCategory.pico);
      expect(restored!.enabled, isFalse);
      expect(restored.minute, 615);
      expect(
        await AlertSettingsStore(db).load('v2', AlertCategory.pico),
        isNull,
      );
      for (final table in _preservedTables) {
        expect([
          for (final row
              in await db
                  .customSelect('SELECT * FROM $table ORDER BY id')
                  .get())
            row.data,
        ], before[table]);
      }
      await expectLater(
        db.writeAlertSettings('missing', 'soat', '{}'),
        throwsException,
      );
      await expectLater(
        db.writeAlertSettings('v1', 'unknown', '{}'),
        throwsException,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
  });
}

const _preservedTables = [
  'vehicles',
  'vehicle_obligations',
  'notification_preferences',
];

void _seedV8(Database old) {
  // Independent pre-alert schema: do not create v9 and lower user_version.
  old.execute('''CREATE TABLE vehicles (
    id TEXT NOT NULL PRIMARY KEY, plate TEXT NOT NULL,
    nickname TEXT, kind TEXT NOT NULL DEFAULT 'car',
    service_type TEXT NOT NULL DEFAULT 'private', subtype TEXT,
    registration_city TEXT, brand TEXT, model TEXT, year INTEGER,
    color TEXT, fuel TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')))''');
  old.execute('CREATE UNIQUE INDEX vehicles_plate_idx ON vehicles(plate)');
  old.execute('''CREATE TABLE vehicle_obligations (
    id TEXT NOT NULL PRIMARY KEY,
    vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    type TEXT NOT NULL, status TEXT NOT NULL, start_date INTEGER,
    due_date INTEGER, details_json TEXT,
    reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0, 1)),
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')))''');
  old.execute(
    'CREATE INDEX vehicle_obligations_vehicle_id_idx ON vehicle_obligations(vehicle_id)',
  );
  old.execute(
    'CREATE INDEX vehicle_obligations_due_date_idx ON vehicle_obligations(due_date)',
  );
  old.execute('''CREATE TABLE notification_preferences (
    id TEXT NOT NULL PRIMARY KEY,
    restriction_alerts_enabled INTEGER NOT NULL DEFAULT 1 CHECK (restriction_alerts_enabled IN (0, 1)),
    obligation_reminders_enabled INTEGER NOT NULL DEFAULT 1 CHECK (obligation_reminders_enabled IN (0, 1)),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')))''');
  for (final id in ['v1', 'v2']) {
    old.execute('INSERT INTO vehicles VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)', [
      id,
      id == 'v1' ? 'DEM123' : 'DEM456',
      'Fixture $id',
      'car',
      'private',
      'sedan',
      'Medellin',
      'Generic',
      'Fixture',
      2024,
      'white',
      'gasoline',
      123,
      456,
    ]);
    for (final category in ['soat', 'rtm', 'insurance']) {
      old.execute(
        'INSERT INTO vehicle_obligations VALUES (?,?,?,?,?,?,?,?,?,?)',
        [
          '$id-$category',
          id,
          category,
          'current',
          1768435200,
          category == 'insurance' ? null : 1799971200,
          '{ "policy": "synthetic-$id-$category", "issuer": "Fixture" }',
          id == 'v1' ? 0 : 1,
          123,
          456,
        ],
      );
    }
  }
  old.execute("INSERT INTO notification_preferences VALUES ('local',0,1,789)");
  old.execute('PRAGMA user_version=8');
}
