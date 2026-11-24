// Opt-in only; this file is outside mobile/test auto-discovery.
// C28_DART=NOT_RUN_ENV: the PHP export gate was blocked in this run.
// Set PICORADAR_C28_BRIDGE_EXPORT_DIR to the directory created by the focused
// PHP test, then run from mobile/:
// flutter test --no-pub qa/c28/national_bridge_interop_c28_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  test(
    'imports exact PHP C28 bytes and keeps OFF/partial coverage unknown',
    () async {
      final exportDirectory =
          Platform.environment['PICORADAR_C28_BRIDGE_EXPORT_DIR'];
      if (exportDirectory == null || exportDirectory.trim().isEmpty) {
        throw StateError(
          'PICORADAR_C28_BRIDGE_EXPORT_DIR is required; this opt-in test must '
          'not skip when the PHP export is absent.',
        );
      }

      final separator = Platform.pathSeparator;
      final payloadFile = File('$exportDirectory${separator}restrictions.json');
      final manifestFile = File('$exportDirectory${separator}manifest.json');
      if (!await payloadFile.exists() || !await manifestFile.exists()) {
        throw StateError(
          'The exact PHP payload and manifest export are required; neither may '
          'be synthesized by this Dart test.',
        );
      }

      final payloadBytes = await payloadFile.readAsBytes();
      final manifestBytes = await manifestFile.readAsBytes();
      final manifest = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(manifestBytes)) as Map,
      );
      final datasets = Map<String, dynamic>.from(manifest['datasets'] as Map);
      final entry = Map<String, dynamic>.from(datasets['restrictions'] as Map);
      final digest = await Sha256().hash(payloadBytes);
      final bytesSha256 = digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(bytesSha256, entry['sha256']);

      final payload = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(payloadBytes)) as Map,
      );
      expect(payload['datasetKey'], 'restrictions');
      expect(payload['schemaVersion'], 2);
      expect(payload['version'], entry['version']);

      final db = AppDatabase(NativeDatabase.memory());
      try {
        await importRestrictionsDataset(db, payload);
        final store = RestrictionStore(db);
        final coverage = await store.loadCoverage(
          'co-c28-synthetic-99999',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime(2026, 11, 23, 12),
        );

        expect(coverage.coverageKnown, isTrue);
        expect(coverage.coverageCompleteness, CoverageCompleteness.partial);
        expect(coverage.consultationEnabled, isFalse);
        expect(coverage.jurisdictionConsultationEnabled, isFalse);
        expect(coverage.rules, isNotEmpty);

        final evaluation = evaluateRestrictionDay(
          ruleSet: coverage,
          jurisdictionId: 'co-c28-synthetic-99999',
          plate: 'ABC123',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          date: DateTime(2026, 11, 23),
        );
        expect(evaluation.status, RestrictionDayStatus.unknown);
        expect(evaluation.status, isNot(RestrictionDayStatus.allowed));
      } finally {
        await db.close();
      }
    },
  );
}
