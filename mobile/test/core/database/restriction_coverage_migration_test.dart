import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  for (final version in [8, 9]) {
    test(
      'v$version to v11 adds coverage completeness and preserves legacy rows',
      () async {
        final old = sqlite3.openInMemory();
        addTearDown(old.close);
        _seedRestrictionCoverage(old);
        old.execute('PRAGMA user_version = $version');
        final before = old
            .select('SELECT * FROM restriction_coverages ORDER BY id')
            .map(Map<String, Object?>.of)
            .toList();
        final oldColumns = old
            .select('PRAGMA table_info(restriction_coverages)')
            .map((row) => row['name'] as String)
            .toList();

        final db = AppDatabase(
          NativeDatabase.opened(old, closeUnderlyingOnClose: false),
        );
        try {
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            11,
          );
          final afterColumns = await db
              .customSelect('PRAGMA table_info(restriction_coverages)')
              .get();
          expect(afterColumns.map((row) => row.read<String>('name')), [
            ...oldColumns,
            'coverage_completeness',
          ]);
          final after = await db
              .customSelect('SELECT * FROM restriction_coverages ORDER BY id')
              .get();
          expect(after, hasLength(before.length));
          for (var index = 0; index < before.length; index += 1) {
            for (final column in oldColumns) {
              expect(after[index].data[column], before[index][column]);
            }
            expect(
              after[index].read<String>('coverage_completeness'),
              'legacy',
            );
          }
        } finally {
          await db.close();
        }
      },
    );
  }
}

void _seedRestrictionCoverage(Database db) {
  db.execute('''CREATE TABLE restriction_coverages (
    id TEXT NOT NULL PRIMARY KEY,
    jurisdiction_id TEXT NOT NULL,
    jurisdiction_name TEXT NOT NULL,
    vehicle_kind TEXT NOT NULL,
    service_type TEXT NOT NULL,
    rules_json TEXT NOT NULL,
    verified_at INTEGER NOT NULL,
    stale_after INTEGER NOT NULL,
    source_urls_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )''');
  db.execute(
    '''INSERT INTO restriction_coverages
    (id, jurisdiction_id, jurisdiction_name, vehicle_kind, service_type,
     rules_json, verified_at, stale_after, source_urls_json, updated_at)
    VALUES ('co-fixture:car:private', 'co-fixture', 'Fixture', 'car', 'private',
            '[]', 1794272400, 1795136400, '["https://example.test/fixture"]', 1794272400)''',
  );
  db.execute(
    '''INSERT INTO restriction_coverages
    (id, jurisdiction_id, jurisdiction_name, vehicle_kind, service_type,
     rules_json, verified_at, stale_after, source_urls_json, updated_at)
    VALUES ('co-fixture:motorcycle:private', 'co-fixture', 'Fixture', 'motorcycle', 'private',
            '[]', 1794272400, 1795136400, '["https://example.test/fixture"]', 1794272401)''',
  );
}
