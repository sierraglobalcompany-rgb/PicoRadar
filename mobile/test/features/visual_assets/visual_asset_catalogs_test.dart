import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatar catalog parses and references valid optimized assets', () async {
    final catalog = AvatarCatalog.fromJson(
      jsonDecode(File(avatarCatalogAssetPath).readAsStringSync())
          as Map<String, Object?>,
    );

    expect(catalog.defaultId, 'avatar_001');
    expect(catalog.items, isNotEmpty);
    expect(
      catalog.items.map((item) => item.id).toSet(),
      hasLength(catalog.items.length),
    );

    for (final item in catalog.items) {
      expect(item.asset, startsWith('assets/avatars/'));
      expect(item.asset, isNot(contains('zip')));
      expect(item.asset, isNot(contains('raw')));
      final file = File(item.asset);
      expect(file.existsSync(), isTrue, reason: item.asset);
      final bytes = await file.readAsBytes();
      expect(bytes.length, item.bytes, reason: item.id);
      expect(bytes.length, lessThanOrEqualTo(120 * 1024), reason: item.id);
      expect(await _sha256(bytes), item.sha256, reason: item.id);
      final size = await _imageSize(bytes);
      expect(size.$1, lessThanOrEqualTo(384), reason: item.id);
      expect(size.$2, lessThanOrEqualTo(384), reason: item.id);
    }
  });

  test(
    'vehicle catalog parses and references valid optimized assets',
    () async {
      final catalog = VehicleVisualCatalog.fromJson(
        jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
            as Map<String, Object?>,
      );

      expect(catalog.items, isNotEmpty);
      expect(
        catalog.items.map((item) => item.id).toSet(),
        hasLength(catalog.items.length),
      );
      expect(
        catalog.items.where((item) => item.kind == 'motorcycle'),
        isNotEmpty,
      );
      expect(
        catalog.items.where((item) => item.serviceType == 'taxi'),
        isNotEmpty,
      );

      for (final item in catalog.items) {
        expect(item.asset, startsWith('assets/vehicles/'));
        expect(item.asset, isNot(contains('zip')));
        expect(item.asset, isNot(contains('raw')));
        final file = File(item.asset);
        expect(file.existsSync(), isTrue, reason: item.asset);
        final bytes = await file.readAsBytes();
        expect(bytes.length, item.bytes, reason: item.id);
        expect(bytes.length, lessThanOrEqualTo(220 * 1024), reason: item.id);
        expect(await _sha256(bytes), item.sha256, reason: item.id);
        final size = await _imageSize(bytes);
        expect(size.$1, lessThanOrEqualTo(640), reason: item.id);
        expect(size.$2, lessThanOrEqualTo(400), reason: item.id);
      }
    },
  );
}

Future<String> _sha256(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<(int, int)> _imageSize(List<int> bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    Uint8List.fromList(bytes),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = (descriptor.width, descriptor.height);
  descriptor.dispose();
  buffer.dispose();
  return size;
}
