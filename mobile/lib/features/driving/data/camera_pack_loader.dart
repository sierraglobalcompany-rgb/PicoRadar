import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/traffic_camera.dart';

const cameraPackAssetPath = 'assets/datasets/cameras/camera_pack_v1.json';

final cameraPackProvider = FutureProvider<CameraPack>((ref) {
  return loadCameraPack(rootBundle);
});

Future<CameraPack> loadCameraPack(AssetBundle bundle) async {
  final source = await bundle.loadString(cameraPackAssetPath);
  return CameraPack.fromJson(jsonDecode(source) as Map<String, Object?>);
}
