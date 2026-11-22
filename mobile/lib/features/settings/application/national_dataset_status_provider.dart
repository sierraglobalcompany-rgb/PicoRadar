import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';

const nationalDatasetKeys = ['restrictions', 'service_providers'];

final nationalDatasetStatusProvider =
    FutureProvider.autoDispose<Map<String, NationalDatasetRecord>>((ref) async {
      final database = ref.watch(appDatabaseProvider);
      final rows = await (database.select(database.datasetVersions)
            ..where((row) => row.datasetKey.isIn(nationalDatasetKeys)))
          .get();

      return {
        for (final row in rows)
          row.datasetKey: NationalDatasetRecord(
            version: row.version,
            sha256: row.sha256,
            status: row.status,
            publicationRevision: row.publicationRevision,
            appliedAt: row.appliedAt,
          ),
      };
    });

class NationalDatasetRecord {
  const NationalDatasetRecord({
    required this.version,
    required this.sha256,
    required this.status,
    required this.publicationRevision,
    required this.appliedAt,
  });

  final String version;
  final String? sha256;
  final String status;
  final int publicationRevision;
  final DateTime appliedAt;

  bool get hasCompleteHash =>
      sha256 != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256!);
}
