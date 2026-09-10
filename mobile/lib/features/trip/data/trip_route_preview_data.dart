import 'dart:convert';

import 'package:flutter/services.dart';

import '../../driving/data/camera_pack_loader.dart';
import '../../driving/domain/traffic_camera.dart';

class TripCameraPackSnapshot {
  const TripCameraPackSnapshot({required this.version, required this.pack});

  final String version;
  final CameraPack pack;
}

Future<TripCameraPackSnapshot> loadTripCameraPackSnapshot(
  AssetBundle bundle,
) async {
  final source = await bundle.loadString(cameraPackAssetPath);
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Camera pack must be a JSON object.');
  }
  final json = Map<String, Object?>.from(decoded);
  final version = json['version'];
  if (version is! String || version.trim().isEmpty) {
    throw const FormatException('Camera pack version is required.');
  }
  return TripCameraPackSnapshot(
    version: version,
    pack: CameraPack.fromJson(json),
  );
}
