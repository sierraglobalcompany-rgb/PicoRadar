import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'legacy_database_fixture.dart';

void main() {
  test('v8 to v11 preserves local data and creates alert settings', () async {
    final old = sqlite3.openInMemory();
    addTearDown(old.close);
    _seedV8(old);
    expect(old.select('PRAGMA user_version').single['user_version'], 8);
    expect(
      old
          .select('PRAGMA table_info(restriction_coverages)')
          .map((row) => row['name']),
      isNot(contains('coverage_completeness')),
    );
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
    final coverageBefore = _coverageRows(old);
    var db = AppDatabase(
      NativeDatabase.opened(old, closeUnderlyingOnClose: false),
    );
    try {
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        AppDatabase.currentSchemaVersion,
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
      expect(_coverageRows(old), coverageBefore);
      expect(
        old
            .select(
              "SELECT coverage_completeness FROM restriction_coverages "
              "WHERE id = 'coverage-1'",
            )
            .single['coverage_completeness'],
        'legacy',
      );
      expect(
        old.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'restriction_jurisdiction_availability'",
        ),
        hasLength(1),
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
      expect(_coverageRows(old), coverageBefore);
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

List<Map<String, Object?>> _coverageRows(Database database) => database
    .select(
      'SELECT id, jurisdiction_id, jurisdiction_name, vehicle_kind, '
      'service_type, rules_json, verified_at, stale_after, source_urls_json, '
      'updated_at FROM restriction_coverages ORDER BY id',
    )
    .map(Map<String, Object?>.of)
    .toList();

void _seedV8(Database old) {
  createLegacyDatabaseFixture(old, version: 8);
  old.execute('''
    INSERT INTO vehicles (id, plate, nickname, created_at, updated_at)
    VALUES ('v1', 'DEM123', 'Fixture one', 123, 456)
  ''');
  old.execute('''
    INSERT INTO vehicle_obligations (
      id, vehicle_id, type, status, start_date, due_date, details_json,
      reminder_enabled, created_at, updated_at
    ) VALUES ('v1-soat', 'v1', 'soat', 'current', 1768435200,
      1799971200, '{"source":"fixture"}', 0, 123, 456)
  ''');
  old.execute('''
    INSERT INTO notification_preferences
      (id, restriction_alerts_enabled, obligation_reminders_enabled, updated_at)
    VALUES ('local', 0, 1, 789)
  ''');
  old.execute('''
    INSERT INTO restriction_coverages (
      id, jurisdiction_id, jurisdiction_name, vehicle_kind, service_type,
      rules_json, verified_at, stale_after, source_urls_json, updated_at
    ) VALUES ('coverage-1', 'co-dc-bogota', 'Bogota', 'car', 'private',
      '[]', 1760000000, 1770000000, '[]', 123456)
  ''');
}
