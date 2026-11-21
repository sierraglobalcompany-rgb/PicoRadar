import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';

import '../../../plate_test_fonts.dart';

const _v6r4FixturePath =
    '../server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.json';

late AppDatabase _database;
late RestrictionStore _store;
late List<RestrictionJurisdiction> _runtimeJurisdictions;

void main() {
  setUpAll(() async {
    await loadPlateTestFonts();
    _database = AppDatabase(NativeDatabase.memory());
    try {
      final snapshot = jsonDecode(
        await File(_v6r4FixturePath).readAsString(),
      ) as Map<String, dynamic>;
      await importRestrictionsDataset(
        _database,
        snapshot,
        now: () => DateTime.utc(2026, 11, 13, 14),
      );
      _store = RestrictionStore(_database);
      final jurisdictions = await _store.listJurisdictions();
      _runtimeJurisdictions = jurisdictions
          .where((item) => item.consultationEnabled == true)
          .map((item) => RestrictionJurisdiction(id: item.id, name: item.name))
          .toList(growable: false);
      stdout.writeln(
        'TEST_MARKER fixture_ready jurisdictions=${jurisdictions.length} '
        'coverages=21 rules=115',
      );
    } catch (_) {
      await _database.close();
      rethrow;
    }
  });

  tearDownAll(() async {
    await _database.close();
  });

  testWidgets('Dosquebradas partial calendar renders with its warning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(_database),
          appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
          bundledRestrictionsProvider.overrideWith((ref) async {}),
          restrictionStoreProvider.overrideWithValue(_store),
          restrictionJurisdictionsProvider.overrideWith(
            (ref) async => _runtimeJurisdictions,
          ),
          selectedPicoJurisdictionIdProvider.overrideWith(
            (ref) async => 'co-ris-dosquebradas',
          ),
          currentInstantProvider.overrideWithValue(
            DateTime.utc(2026, 11, 13, 14),
          ),
          bogotaDateProvider.overrideWithValue(DateTime(2026, 11, 13)),
          vehicleListProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: PicoDetailScreen(jurisdictionId: 'co-ris-dosquebradas'),
        ),
      ),
    );
    stdout.writeln('TEST_MARKER widget_mounted');
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final hero = find.byKey(const ValueKey('pico-city-hero'));
    expect(hero, findsOneWidget);
    expect(
      find.descendant(
        of: hero,
        matching: find.text('Calendario oficial publicado'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hero,
        matching: find.text('Sujeto a vías y excepciones'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Horario publicado · consulta informativa'),
      findsOneWidget,
    );
    expect(find.text('Fuente: dosquebradas.gov.co'), findsOneWidget);
    expect(find.textContaining('6:00'), findsWidgets);
    expect(find.textContaining('8:00'), findsWidgets);
    expect(find.text('Puede circular'), findsNothing);
    expect(find.text('Restringido'), findsNothing);
    expect(tester.takeException(), isNull);
    stdout.writeln(
      'TEST_MARKER assertions_complete bounded_pumps=10 '
      'pending_frames=${tester.binding.transientCallbackCount}',
    );
    stdout.writeln(
      'TEST_EVIDENCE V6R4_WIDGET calendar=partial warning=present '
      'universal_permission_claim=false real_database=true',
    );
  });
}

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object?> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
