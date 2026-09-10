import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const asset = 'assets/vehicles/veh_car_audi_01.webp';

  for (final width in [180, 220, 360, 420]) {
    test(
      'shared vehicle provider preserves the $width decode cache key',
      () async {
        final prewarm = visualAssetImageProvider(asset, cacheWidth: width);
        final rendered = Image.asset(asset, cacheWidth: width).image;
        expect(prewarm, rendered);
        expect(
          await prewarm.obtainKey(ImageConfiguration.empty),
          await rendered.obtainKey(ImageConfiguration.empty),
        );
        expect(prewarm, isNot(const AssetImage(asset)));
        expect(
          prewarm,
          isNot(visualAssetImageProvider(asset, cacheWidth: width + 1)),
        );
      },
    );
  }

  for (final size in [112, 128]) {
    test('shared avatar provider preserves both $size decode dimensions', () {
      final provider = visualAssetImageProvider(
        asset,
        cacheWidth: size,
        cacheHeight: size,
      );
      expect(
        provider,
        Image.asset(asset, cacheWidth: size, cacheHeight: size).image,
      );
      expect((provider as ResizeImage).width, size);
      expect(provider.height, size);
    });
  }
}
