import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'published camera dataset exposes the B05 compact Driving contract',
    () async {
      final datasetFile = File('assets/datasets/cameras/cameras_v1.json');
      final manifestFile = File(
        'assets/datasets/cameras/cameras_manifest_v1.json',
      );

      expect(datasetFile.existsSync(), isTrue);
      expect(manifestFile.existsSync(), isTrue);

      final datasetBytes = await datasetFile.readAsBytes();
      final dataset =
          jsonDecode(utf8.decode(datasetBytes)) as Map<String, dynamic>;
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

      expect(dataset['schemaVersion'], 1);
      expect(dataset['datasetKey'], 'traffic_cameras');
      expect(dataset['version'], '2026.08.31-ansv');
      expect(dataset['recordCount'], 360);
      expect(dataset['speedKnownCount'], 293);
      expect(dataset['speedCoverage'], 0.8139);
      expect(manifest['schemaVersion'], 1);
      expect(manifest['datasetKey'], 'traffic_cameras');
      expect(manifest['version'], '2026.08.31-ansv');
      expect(dataset['recordCount'], manifest['recordCount']);
      expect(dataset['speedKnownCount'], manifest['speedKnownCount']);
      expect(dataset['speedCoverage'], manifest['speedCoverage']);
      expect(manifest['asset']['path'], 'cameras_v1.json');
      expect(manifest['asset']['bytes'], datasetBytes.length);
      expect(manifest['asset']['sha256'], await _sha256Hex(datasetBytes));
      expect(
        manifest['sourceSnapshotSha256'],
        dataset['source']['snapshotSha256'],
      );

      final records = (dataset['records'] as List).cast<Map<String, dynamic>>();
      expect(records.length, dataset['recordCount']);
      expect(
        records.map((record) => record['cameraId']).toSet().length,
        records.length,
      );
      expect(
        records.map((record) => record['sourceRowId']).toSet().length,
        records.length,
      );
      expect(
        records.where(
          (record) =>
              record['sourceFetchedAt'] != dataset['source']['fetchedAt'],
        ),
        isEmpty,
      );
      expect(
        records.where((record) => record['operationStatus'] != 'Operando'),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['address'] is! String ||
              (record['address'] as String).isEmpty,
        ),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['trafficAuthority'] is! String ||
              (record['trafficAuthority'] as String).isEmpty,
        ),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['lat'] is! num ||
              record['lon'] is! num ||
              (record['lat'] as num) < -4.5 ||
              (record['lat'] as num) > 13.5 ||
              (record['lon'] as num) < -82.5 ||
              (record['lon'] as num) > -66,
        ),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['reportedSpeedKmh'] != null &&
              (record['reportedSpeedKmh'] is! int ||
                  (record['reportedSpeedKmh'] as int) < 1 ||
                  (record['reportedSpeedKmh'] as int) > 200),
        ),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['rawSpeed'] == '37' && record['reportedSpeedKmh'] == 37,
        ),
        isEmpty,
      );
      final asOf = DateTime.parse(manifest['freshness']['asOf'] as String);
      expect(
        records.where(
          (record) =>
              record['validFrom'] != null &&
              DateTime.parse(record['validFrom'] as String).isAfter(asOf),
        ),
        isEmpty,
      );
      expect(
        records.where(
          (record) =>
              record['validUntil'] != null &&
              DateTime.parse(record['validUntil'] as String).isBefore(asOf),
        ),
        isEmpty,
      );

      const requiredKeys = <String>{
        'cameraId',
        'sourceRowId',
        'sourceOfficialCode',
        'sourceRequestCode',
        'lat',
        'lon',
        'municipality',
        'department',
        'address',
        'trafficAuthority',
        'jurisdiction',
        'operationStatus',
        'reportedSpeedKmh',
        'technology',
        'installationType',
        'equipmentName',
        'infractionCodes',
        'sourceFetchedAt',
        'validFrom',
        'validUntil',
      };
      expect(
        records.where(
          (record) => !record.keys.toSet().containsAll(requiredKeys),
        ),
        isEmpty,
      );
    },
  );
}

Future<String> _sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
