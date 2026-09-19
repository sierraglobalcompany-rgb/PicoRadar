import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/data/toll_dataset_manifest.dart';

void main() {
  test(
    'toll manifest pins both audited assets and unknown semantics',
    () async {
      final manifest = TollDatasetManifest.fromJsonString(
        File(tollDatasetManifestAssetPath).readAsStringSync(),
      );
      final inventory = File(tollInventoryAssetPath).readAsBytesSync();
      final tariffs = File(tollTariffAssetPath).readAsBytesSync();

      expect(manifest.inventory.stationCount, 184);
      expect(manifest.inventory.verifiedChargeEventCount, 0);
      expect(manifest.inventory.unknownTariffStationCount, 184);
      expect(manifest.inventory.currentOperationConfirmed, isFalse);
      expect(manifest.inventory.operationCounts, {
        'inventoried_operation_not_confirmed': 180,
        'source_reports_operating': 1,
        'non_operational_historical': 2,
        'damaged_review_required': 1,
      });
      expect(manifest.inventory.assetBytes, inventory.length);
      expect(manifest.inventory.assetSha256, await _sha256(inventory));

      expect(manifest.tariffs.stationCount, 184);
      expect(manifest.tariffs.generalRateCount, 1300);
      expect(manifest.tariffs.numericGeneralRateCount, 1007);
      expect(manifest.tariffs.officialGeneralRateCount, 793);
      expect(manifest.tariffs.secondaryGeneralRateCount, 214);
      expect(manifest.tariffs.specialRateCount, 437);
      expect(manifest.tariffs.candidatesOutsideBase, 9);
      expect(manifest.tariffs.consultationCutoffAsStated, '2026-09-08');
      expect(manifest.tariffs.independentExternalReverification, isFalse);
      expect(manifest.tariffs.assetBytes, tariffs.length);
      expect(manifest.tariffs.assetSha256, await _sha256(tariffs));
    },
  );
}

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}
