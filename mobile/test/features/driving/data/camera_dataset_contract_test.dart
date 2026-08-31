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
      expect(dataset['recordCount'], greaterThan(0));
      expect(dataset['recordCount'], manifest['recordCount']);
      expect(dataset['speedKnownCount'], manifest['speedKnownCount']);
      expect(manifest['asset']['bytes'], datasetBytes.length);
      expect(manifest['asset']['sha256'], await _sha256Hex(datasetBytes));

      final records = (dataset['records'] as List).cast<Map<String, dynamic>>();
      expect(records.length, dataset['recordCount']);
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
          (record) => record['lat'] is! num || record['lon'] is! num,
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

      final first = records.first;
      expect(
        first.keys,
        containsAll(<String>[
          'cameraId',
          'sourceRowId',
          'sourceOfficialCode',
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
        ]),
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
