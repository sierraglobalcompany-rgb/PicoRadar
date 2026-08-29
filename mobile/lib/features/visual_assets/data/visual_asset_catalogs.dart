import 'dart:convert';

import 'package:flutter/services.dart';

const avatarCatalogAssetPath = 'assets/catalogs/avatar_catalog.json';
const vehicleCatalogAssetPath = 'assets/catalogs/vehicle_catalog.json';

class AvatarCatalog {
  const AvatarCatalog({required this.defaultId, required this.items});

  final String? defaultId;
  final List<AvatarAsset> items;

  AvatarAsset? get defaultAsset => assetById(defaultId);

  AvatarAsset? assetById(String? id) {
    if (id == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  factory AvatarCatalog.fromJson(Map<String, Object?> json) {
    return AvatarCatalog(
      defaultId: json['defaultId'] as String?,
      items: _list(json['items']).map(AvatarAsset.fromJson).toList(),
    );
  }
}

class AvatarAsset {
  const AvatarAsset({
    required this.id,
    required this.asset,
    required this.width,
    required this.height,
    required this.bytes,
    required this.sha256,
  });

  final String id;
  final String asset;
  final int width;
  final int height;
  final int bytes;
  final String sha256;

  String get displayName {
    final number = id.split('_').last;
    return 'Avatar ${int.tryParse(number) ?? number}';
  }

  factory AvatarAsset.fromJson(Map<String, Object?> json) {
    return AvatarAsset(
      id: json['id']! as String,
      asset: json['asset']! as String,
      width: json['width']! as int,
      height: json['height']! as int,
      bytes: json['bytes']! as int,
      sha256: json['sha256']! as String,
    );
  }
}

class VehicleVisualCatalog {
  const VehicleVisualCatalog({required this.items});

  final List<VehicleVisualAsset> items;

  VehicleVisualAsset? assetById(String? id) {
    if (id == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  factory VehicleVisualCatalog.fromJson(Map<String, Object?> json) {
    return VehicleVisualCatalog(
      items: _list(json['items']).map(VehicleVisualAsset.fromJson).toList(),
    );
  }
}

class VehicleVisualAsset {
  const VehicleVisualAsset({
    required this.id,
    required this.asset,
    required this.kind,
    required this.serviceType,
    required this.brand,
    required this.model,
    required this.yearFrom,
    required this.yearTo,
    required this.width,
    required this.height,
    required this.bytes,
    required this.sha256,
  });

  final String id;
  final String asset;
  final String kind;
  final String serviceType;
  final String? brand;
  final String? model;
  final int? yearFrom;
  final int? yearTo;
  final int width;
  final int height;
  final int bytes;
  final String sha256;

  String get displayName {
    if (serviceType == 'taxi') {
      return 'Taxi';
    }
    final parts = [
      brand,
      model,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return parts.isEmpty ? (kind == 'motorcycle' ? 'Moto' : 'Vehículo') : parts;
  }

  factory VehicleVisualAsset.fromJson(Map<String, Object?> json) {
    return VehicleVisualAsset(
      id: json['id']! as String,
      asset: json['asset']! as String,
      kind: json['kind']! as String,
      serviceType: json['serviceType']! as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      yearFrom: json['yearFrom'] as int?,
      yearTo: json['yearTo'] as int?,
      width: json['width']! as int,
      height: json['height']! as int,
      bytes: json['bytes']! as int,
      sha256: json['sha256']! as String,
    );
  }
}

Future<AvatarCatalog> loadAvatarCatalog(AssetBundle bundle) async {
  final raw = await bundle.loadString(avatarCatalogAssetPath);
  return AvatarCatalog.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

Future<VehicleVisualCatalog> loadVehicleVisualCatalog(
  AssetBundle bundle,
) async {
  final raw = await bundle.loadString(vehicleCatalogAssetPath);
  return VehicleVisualCatalog.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

Iterable<Map<String, Object?>> _list(Object? value) {
  return (value! as List<Object?>).map(
    (item) => (item! as Map).cast<String, Object?>(),
  );
}
