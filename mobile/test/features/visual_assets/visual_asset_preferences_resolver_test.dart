import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/visual_assets/data/vehicle_visual_resolver.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_preferences.dart';

void main() {
  group('visual asset preferences', () {
    test('selected avatar persists locally', () async {
      final preferences = _MemoryPreferences();

      await saveSelectedAvatarId(preferences, 'avatar_003');

      expect(await loadSelectedAvatarId(preferences), 'avatar_003');
    });

    test('invalid stored avatar can fall back to catalog default', () async {
      const catalog = AvatarCatalog(
        defaultId: 'avatar_001',
        items: [
          AvatarAsset(
            id: 'avatar_001',
            asset: 'assets/avatars/avatar_001.webp',
            width: 384,
            height: 384,
            bytes: 1,
            sha256: 'a',
          ),
        ],
      );

      expect(catalog.assetById('missing') ?? catalog.defaultAsset, isNotNull);
      expect(
        (catalog.assetById('missing') ?? catalog.defaultAsset)?.id,
        'avatar_001',
      );
    });

    test('vehicle visual override persists and clears locally', () async {
      final preferences = _MemoryPreferences();

      await saveVehicleVisualOverride(preferences, 'veh1', 'veh_car_toyota_01');
      expect(
        await loadVehicleVisualOverride(preferences, 'veh1'),
        'veh_car_toyota_01',
      );

      await clearVehicleVisualOverride(preferences, 'veh1');
      expect(await loadVehicleVisualOverride(preferences, 'veh1'), isNull);
    });
  });

  group('VehicleVisualResolver', () {
    test('explicit compatible override wins', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(brand: 'Toyota', model: 'Corolla');

      final asset = resolver.resolve(vehicle, overrideId: 'veh_car_renault_01');

      expect(asset?.id, 'veh_car_renault_01');
    });

    test('brand and model match wins before brand fallback', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(brand: 'Toyota', model: 'Corolla');

      final asset = resolver.resolve(vehicle);

      expect(asset?.id, 'veh_car_toyota_corolla_01');
    });

    test('brand fallback handles punctuation and accents', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(brand: 'Rénault!', model: 'Missing');

      final asset = resolver.resolve(vehicle);

      expect(asset?.id, 'veh_car_renault_01');
    });

    test('taxi-compatible fallback does not use private cars', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(serviceType: VehicleServiceType.taxi);

      final asset = resolver.resolve(vehicle);

      expect(asset?.id, 'veh_car_taxi_01');
    });

    test('motorcycle never resolves a car asset', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(kind: VehicleKind.motorcycle, brand: 'Toyota');

      final asset = resolver.resolve(vehicle);

      expect(asset?.kind, 'motorcycle');
    });

    test('invalid override falls back to automatic resolution', () {
      final resolver = VehicleVisualResolver(_catalog());
      final vehicle = _vehicle(brand: 'Toyota', model: 'Corolla');

      final asset = resolver.resolve(vehicle, overrideId: 'missing');

      expect(asset?.id, 'veh_car_toyota_corolla_01');
    });
  });
}

VehicleProfile _vehicle({
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? brand,
  String? model,
}) {
  return VehicleProfile(
    id: 'veh1',
    plate: 'ABC123',
    kind: kind,
    serviceType: serviceType,
    brand: brand,
    model: model,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

VehicleVisualCatalog _catalog() {
  return const VehicleVisualCatalog(
    items: [
      VehicleVisualAsset(
        id: 'veh_car_toyota_corolla_01',
        asset: 'assets/vehicles/veh_car_toyota_corolla_01.webp',
        kind: 'car',
        serviceType: 'private',
        brand: 'Toyota',
        model: 'Corolla',
        yearFrom: null,
        yearTo: null,
        width: 640,
        height: 400,
        bytes: 1,
        sha256: 'a',
      ),
      VehicleVisualAsset(
        id: 'veh_car_renault_01',
        asset: 'assets/vehicles/veh_car_renault_01.webp',
        kind: 'car',
        serviceType: 'private',
        brand: 'Renault',
        model: null,
        yearFrom: null,
        yearTo: null,
        width: 640,
        height: 400,
        bytes: 1,
        sha256: 'b',
      ),
      VehicleVisualAsset(
        id: 'veh_car_taxi_01',
        asset: 'assets/vehicles/veh_car_taxi_01.webp',
        kind: 'car',
        serviceType: 'taxi',
        brand: null,
        model: null,
        yearFrom: null,
        yearTo: null,
        width: 640,
        height: 400,
        bytes: 1,
        sha256: 'c',
      ),
      VehicleVisualAsset(
        id: 'veh_moto_yamaha_01',
        asset: 'assets/vehicles/veh_moto_yamaha_01.webp',
        kind: 'motorcycle',
        serviceType: 'private',
        brand: 'Yamaha',
        model: null,
        yearFrom: null,
        yearTo: null,
        width: 640,
        height: 400,
        bytes: 1,
        sha256: 'd',
      ),
    ],
  );
}

class _MemoryPreferences implements AppPreferences {
  final _values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
