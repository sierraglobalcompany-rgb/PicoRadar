import '../../garage/data/vehicle_profile.dart';
import 'visual_asset_catalogs.dart';

class VehicleVisualResolver {
  const VehicleVisualResolver(this.catalog);

  final VehicleVisualCatalog catalog;

  VehicleVisualAsset? resolve(VehicleProfile vehicle, {String? overrideId}) {
    final override = catalog.assetById(overrideId);
    if (override != null && _compatible(vehicle, override)) {
      return override;
    }

    final kind = vehicle.kind.value;
    final serviceType = vehicle.serviceType.value;
    final brand = normalizeVisualToken(vehicle.brand);
    final model = normalizeVisualToken(vehicle.model);

    if (brand != null && model != null) {
      final exact = _firstWhere(
        (item) =>
            item.kind == kind &&
            item.serviceType == serviceType &&
            normalizeVisualToken(item.brand) == brand &&
            normalizeVisualToken(item.model) == model,
      );
      if (exact != null) {
        return exact;
      }
    }

    if (brand != null) {
      final brandMatch = _firstWhere(
        (item) =>
            item.kind == kind &&
            item.serviceType == serviceType &&
            normalizeVisualToken(item.brand) == brand,
      );
      if (brandMatch != null) {
        return brandMatch;
      }
    }

    if (vehicle.serviceType == VehicleServiceType.taxi) {
      final taxi = _firstWhere(
        (item) => item.kind == 'car' && item.serviceType == 'taxi',
      );
      if (taxi != null) {
        return taxi;
      }
    }

    return _firstWhere(
      (item) =>
          item.kind == kind &&
          item.serviceType == VehicleServiceType.private.value,
    );
  }

  List<VehicleVisualAsset> optionsFor(VehicleProfile vehicle) {
    final compatible = catalog.items
        .where((item) => _compatible(vehicle, item))
        .toList(growable: false);
    final brand = normalizeVisualToken(vehicle.brand);
    final model = normalizeVisualToken(vehicle.model);
    final scored =
        [
          for (final item in compatible)
            (item: item, score: _score(item, brand: brand, model: model)),
        ]..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) {
            return byScore;
          }
          return a.item.id.compareTo(b.item.id);
        });
    return [for (final entry in scored) entry.item];
  }

  VehicleVisualAsset? _firstWhere(bool Function(VehicleVisualAsset) test) {
    for (final item in catalog.items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  bool _compatible(VehicleProfile vehicle, VehicleVisualAsset item) {
    if (vehicle.kind == VehicleKind.motorcycle) {
      return item.kind == 'motorcycle';
    }
    if (vehicle.serviceType == VehicleServiceType.taxi) {
      return item.kind == 'car' && item.serviceType == 'taxi';
    }
    return item.kind == 'car' && item.serviceType == 'private';
  }

  int _score(VehicleVisualAsset item, {String? brand, String? model}) {
    var score = 0;
    if (brand != null && normalizeVisualToken(item.brand) == brand) {
      score += 20;
    }
    if (model != null && normalizeVisualToken(item.model) == model) {
      score += 30;
    }
    if (item.serviceType == 'taxi') {
      score += 10;
    }
    return score;
  }
}

String? normalizeVisualToken(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  var normalized = trimmed;
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}
