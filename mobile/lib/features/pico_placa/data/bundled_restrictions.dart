import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import 'restriction_dataset.dart';

const bundledRestrictionsAsset =
    'assets/datasets/restrictions/restrictions_v1.json';

Future<void> ensureBundledRestrictionsLoaded(
  AppDatabase db, {
  Future<String> Function()? bundledLoader,
}) async {
  final beforeLoad =
      await (db.select(db.datasetVersions)
            ..where((row) => row.datasetKey.equals(restrictionsDatasetKey)))
          .getSingleOrNull();
  if (!await _canInstallBundledRestrictions(db, beforeLoad)) {
    return;
  }

  // Asset loading may use an isolate. Never hold the database lock across it.
  final raw =
      await (bundledLoader?.call() ??
          rootBundle.loadString(bundledRestrictionsAsset));
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const DatasetSyncException('Bundled restrictions must be an object.');
  }
  final json = Map<String, dynamic>.from(decoded);
  final version = json['version'];
  if (version is! String || version.trim().isEmpty) {
    throw const DatasetSyncException(
      'Bundled restrictions version is required.',
    );
  }
  final generated = json['generatedAt'];
  final generatedAt = generated is String ? DateTime.tryParse(generated) : null;
  if (generatedAt == null || !generatedAt.isUtc) {
    throw const DatasetSyncException(
      'Bundled restrictions generatedAt must identify a UTC instant.',
    );
  }

  await db.transaction(() async {
    // Another installer may have finished while the asset was loading.
    final installed =
        await (db.select(db.datasetVersions)
              ..where((row) => row.datasetKey.equals(restrictionsDatasetKey)))
            .getSingleOrNull();
    if (!await _canInstallBundledRestrictions(db, installed)) {
      return;
    }
    if (installed != null) {
      // Legacy metadata has no source timestamp. Same-day ordering is unknown.
      final generatedDay = DateTime.utc(
        generatedAt.year,
        generatedAt.month,
        generatedAt.day,
      );
      if (_bundledVersionDay(version.trim()) != generatedDay ||
          installed.version == version.trim() ||
          !generatedDay.isAfter(_bundledVersionDay(installed.version)!)) {
        return;
      }
    }

    await importRestrictionsDataset(db, json);
    await db
        .into(db.datasetVersions)
        .insertOnConflictUpdate(
          DatasetVersionsCompanion.insert(
            id: installed?.id ?? restrictionsDatasetKey,
            datasetKey: restrictionsDatasetKey,
            version: version.trim(),
            status: 'bundled',
            appliedAt: Value(DateTime.now().toUtc()),
          ),
        );
  });
}

Future<bool> _canInstallBundledRestrictions(
  AppDatabase db,
  DatasetVersion? installed,
) async {
  if (installed != null) {
    return installed.status == 'bundled' &&
        installed.publicationRevision == 0 &&
        installed.sha256 == null &&
        _bundledVersionDay(installed.version) != null;
  }
  final existing = await (db.select(
    db.restrictionCoverages,
  )..limit(1)).getSingleOrNull();
  return existing == null;
}

DateTime? _bundledVersionDay(String version) {
  final match = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})(?:$|[-+])')
      .firstMatch(version);
  if (match == null) {
    return null;
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}
