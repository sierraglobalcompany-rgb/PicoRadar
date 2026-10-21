import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/fotomultas/data/camera_dataset_manifest.dart';

void main() {
  test('camera manifest pins snapshot bytes and truthful coverage', () async {
    final manifest = CameraDatasetManifest.fromJsonString(
      File(cameraDatasetManifestAssetPath).readAsStringSync(),
    );
    final bytes = File(cameraDatasetAssetPath).readAsBytesSync();

    expect(manifest.version, '2026.08.31-ansv');
    expect(manifest.recordCount, 360);
    expect(manifest.speedKnownCount, 293);
    expect(manifest.speedUnknownCount, 67);
    expect(manifest.departmentCount, 13);
    expect(manifest.snapshotOnly, isTrue);
    expect(manifest.currentOperationConfirmed, isFalse);
    expect(manifest.sourceAsOf, '2026-08-31');
    expect(
      manifest.sourceUrl,
      'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
    );
    expect(manifest.assetBytes, bytes.length);
    expect(manifest.assetSha256, await _sha256(bytes));
  });
}

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}
