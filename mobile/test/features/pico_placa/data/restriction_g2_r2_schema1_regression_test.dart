import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('actual R2 schema1 release retains seven cities and twelve legacy coverages', () async {
    final releasePath = Platform.environment['PICORADAR_G2_R2_RELEASE'];
    expect(releasePath, isNotNull);
    final bytes = await File(releasePath!).readAsBytes();
    expect(
      await _sha256(bytes),
      'c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5',
    );

    final release = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(release['schemaVersion'], 1);
    final jurisdictions = release['jurisdictions'] as List;
    expect(jurisdictions, hasLength(7));
    await importRestrictionsDataset(database, release);

    final rows = await database.select(database.restrictionCoverages).get();
    expect(rows, hasLength(12));
    expect(rows.map((row) => row.jurisdictionId).toSet(), hasLength(7));
    expect(rows.map((row) => row.coverageCompleteness), everyElement('legacy'));
    for (final jurisdiction in jurisdictions.cast<Map<String, dynamic>>()) {
      for (final coverage
          in (jurisdiction['coverages'] as List).cast<Map<String, dynamic>>()) {
        final row = rows.singleWhere(
          (candidate) =>
              candidate.jurisdictionId == jurisdiction['id'] &&
              candidate.vehicleKind == coverage['vehicleKind'] &&
              candidate.serviceType == coverage['serviceType'],
        );
        expect(jsonDecode(row.rulesJson), coverage['rules']);
      }
    }
  });
}

Future<String> _sha256(List<int> bytes) async =>
    (await Sha256().hash(bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
