import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import 'restriction_dataset.dart';

const bundledRestrictionsAsset =
    'assets/datasets/restrictions/restrictions_v1.json';

Future<void> ensureBundledRestrictionsLoaded(AppDatabase db) async {
  final existing = await db.select(db.restrictionCoverages).get();
  if (existing.isNotEmpty) {
    return;
  }

  final raw = await rootBundle.loadString(bundledRestrictionsAsset);
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

  await db.transaction(() async {
    await importRestrictionsDataset(db, json);
    await db
        .into(db.datasetVersions)
        .insertOnConflictUpdate(
          DatasetVersionsCompanion.insert(
            id: restrictionsDatasetKey,
            datasetKey: restrictionsDatasetKey,
            version: version.trim(),
            status: 'bundled',
            appliedAt: Value(DateTime.now().toUtc()),
          ),
        );
  });
}
