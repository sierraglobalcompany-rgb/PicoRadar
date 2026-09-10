import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/sync/dataset_sync_service.dart';
import 'toll_inventory.dart';

const tollTariffCatalogDatasetKey = 'tolls_tariffs';
const bundledTollTariffCatalogAsset = 'assets/catalogs/tolls_tariffs_v1.json';

Future<TollTariffCatalog> loadTollTariffCatalog(AssetBundle bundle) async {
  final raw = await bundle.loadString(bundledTollTariffCatalogAsset);
  return TollTariffCatalog.fromJsonString(raw);
}

class TollTariffCatalog {
  TollTariffCatalog({
    required this.version,
    required this.currency,
    required this.amountUnit,
    required this.source,
    required this.counts,
    required List<TollTariffStation> stations,
  }) : stations = List.unmodifiable(stations),
       _byId = {for (final station in stations) station.id: station} {
    if (_byId.length != stations.length) {
      throw const DatasetSyncException('Duplicate toll tariff station id.');
    }
  }

  factory TollTariffCatalog.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const DatasetSyncException(
          'Toll tariff payload must be a JSON object.',
        );
      }
      return TollTariffCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (error) {
      throw DatasetSyncException('Invalid toll tariff JSON: $error');
    }
  }

  factory TollTariffCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw DatasetSyncException(
        'Unsupported toll tariff schemaVersion: $schemaVersion.',
      );
    }
    if (_requiredString(json, 'datasetKey') != tollTariffCatalogDatasetKey) {
      throw const DatasetSyncException('Toll tariff datasetKey is invalid.');
    }
    if (_requiredString(json, 'currency') != 'COP') {
      throw const DatasetSyncException('Toll tariff currency must be COP.');
    }
    if (_requiredString(json, 'amountUnit') != 'whole_pesos') {
      throw const DatasetSyncException(
        'Toll tariff amounts must be whole COP pesos.',
      );
    }
    final source = TollTariffSource.fromJson(_requiredMap(json, 'source'));
    final counts = TollTariffCounts.fromJson(_requiredMap(json, 'counts'));
    final stations = [
      for (final value in _requiredList(json, 'stations'))
        TollTariffStation.fromJson(_mapValue(value, 'toll tariff station')),
    ];
    if (stations.isEmpty) {
      throw const DatasetSyncException('Toll tariff stations are required.');
    }
    if (stations.length != counts.stations) {
      throw DatasetSyncException(
        'Toll tariff station count mismatch: ${stations.length}.',
      );
    }
    final generalRateCount = stations.fold<int>(
      0,
      (count, station) => count + station.generalRates.length,
    );
    final specialRateCount = stations.fold<int>(
      0,
      (count, station) => count + station.specialRates.length,
    );
    if (generalRateCount != counts.generalRates ||
        specialRateCount != counts.specialRates) {
      throw const DatasetSyncException('Toll tariff rate counts mismatch.');
    }
    return TollTariffCatalog(
      version: _requiredString(json, 'version'),
      currency: _requiredString(json, 'currency'),
      amountUnit: _requiredString(json, 'amountUnit'),
      source: source,
      counts: counts,
      stations: stations,
    );
  }

  final String version;
  final String currency;
  final String amountUnit;
  final TollTariffSource source;
  final TollTariffCounts counts;
  final List<TollTariffStation> stations;
  final Map<String, TollTariffStation> _byId;

  TollTariffStation? byId(String id) => _byId[id];

  List<TollTariffStation> search(String query, {int limit = 12}) {
    final normalized = _normalize(query);
    final matches = normalized.isEmpty
        ? stations.where((station) => station.hasAnyGeneralAmount)
        : stations.where((station) {
            return _normalize(station.name).contains(normalized) ||
                _normalize(station.department ?? '').contains(normalized) ||
                _normalize(station.id).contains(normalized);
          });
    return matches.take(limit).toList(growable: false);
  }
}

class TollTariffSource {
  const TollTariffSource({
    required this.fileName,
    required this.sha256,
    required this.consultationCutoffAsStated,
    required this.independentExternalReverification,
    required this.jsonFileName,
    required this.jsonSha256,
  });

  factory TollTariffSource.fromJson(Map<String, dynamic> json) {
    return TollTariffSource(
      fileName: _requiredString(json, 'fileName'),
      sha256: _requiredString(json, 'sha256'),
      consultationCutoffAsStated: _requiredString(
        json,
        'consultationCutoffAsStated',
      ),
      independentExternalReverification: _requiredBool(
        json,
        'independentExternalReverification',
      ),
      jsonFileName: _requiredString(json, 'jsonFileName'),
      jsonSha256: _requiredString(json, 'jsonSha256'),
    );
  }

  final String fileName;
  final String sha256;
  final String consultationCutoffAsStated;
  final bool independentExternalReverification;
  final String jsonFileName;
  final String jsonSha256;
}

class TollTariffCounts {
  const TollTariffCounts({
    required this.stations,
    required this.generalRates,
    required this.specialRates,
    required this.numericGeneralRates,
    required this.officialGeneralRates,
    required this.secondaryGeneralRates,
    required this.candidatesOutsideBase,
  });

  factory TollTariffCounts.fromJson(Map<String, dynamic> json) {
    return TollTariffCounts(
      stations: _requiredInt(json, 'stations'),
      generalRates: _requiredInt(json, 'generalRates'),
      specialRates: _requiredInt(json, 'specialRates'),
      numericGeneralRates: _requiredInt(json, 'numericGeneralRates'),
      officialGeneralRates: _requiredInt(json, 'officialGeneralRates'),
      secondaryGeneralRates: _requiredInt(json, 'secondaryGeneralRates'),
      candidatesOutsideBase: _requiredInt(json, 'candidatesOutsideBase'),
    );
  }

  final int stations;
  final int generalRates;
  final int specialRates;
  final int numericGeneralRates;
  final int officialGeneralRates;
  final int secondaryGeneralRates;
  final int candidatesOutsideBase;
}

class TollTariffStation {
  TollTariffStation({
    required this.id,
    required this.name,
    required this.department,
    required this.latitude,
    required this.longitude,
    required this.operationStatus,
    required this.publicationControl,
    required this.routeRule,
    required this.logicalChargeGroup,
    required this.evidenceQuality,
    required List<TollTariffRate> generalRates,
    required List<TollSpecialTariffRate> specialRates,
  }) : generalRates = List.unmodifiable(generalRates),
       specialRates = List.unmodifiable(specialRates) {
    final keys = <String>{};
    for (final rate in generalRates) {
      if (!keys.add(rate.categoryCode)) {
        throw DatasetSyncException(
          'Duplicate general tariff category for $id: ${rate.categoryCode}.',
        );
      }
    }
  }

  factory TollTariffStation.fromJson(Map<String, dynamic> json) {
    return TollTariffStation(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      department: _optionalString(json['department']),
      latitude: _requiredNumber(json, 'latitude').toDouble(),
      longitude: _requiredNumber(json, 'longitude').toDouble(),
      operationStatus: _optionalString(json['operationStatus']),
      publicationControl: _optionalString(json['publicationControl']),
      routeRule: _optionalString(json['routeRule']),
      logicalChargeGroup: _optionalString(json['logicalChargeGroup']),
      evidenceQuality: _optionalString(json['evidenceQuality']),
      generalRates: [
        for (final value in _requiredList(json, 'generalRates'))
          TollTariffRate.fromJson(_mapValue(value, 'general toll tariff')),
      ],
      specialRates: [
        for (final value in _requiredList(json, 'specialRates'))
          TollSpecialTariffRate.fromJson(_mapValue(value, 'special toll rate')),
      ],
    );
  }

  final String id;
  final String name;
  final String? department;
  final double latitude;
  final double longitude;
  final String? operationStatus;
  final String? publicationControl;
  final String? routeRule;
  final String? logicalChargeGroup;
  final String? evidenceQuality;
  final List<TollTariffRate> generalRates;
  final List<TollSpecialTariffRate> specialRates;

  bool get hasAnyGeneralAmount =>
      generalRates.any((rate) => rate.amountCop != null);

  TollTariffRate? generalRateByCategory(String categoryCode) {
    final normalized = categoryCode.trim().toUpperCase();
    return generalRates
        .where((rate) => rate.categoryCode == normalized)
        .firstOrNull;
  }

  TollTariffRate? get categoryI => generalRateByCategory('I');
}

class TollTariffRate {
  const TollTariffRate({
    required this.categoryCode,
    required this.vehicleDescription,
    required this.rateType,
    required this.amountCop,
    required this.collectionMultiplier,
    required this.boothBaseChargeCop,
    required this.dataStatus,
    required this.sourceDate,
    required this.sourceDatePrecision,
    required this.consultedOn,
    required this.sourceType,
    required this.amountSourceId,
    required this.amountSourceUrl,
    required this.chargeSourceUrl,
    required this.conditions,
    required this.publicationControl,
  });

  factory TollTariffRate.fromJson(Map<String, dynamic> json) {
    final amountCop = _optionalInt(json['amountCop']);
    final boothBaseChargeCop = _optionalInt(json['boothBaseChargeCop']);
    if (amountCop != null && amountCop < 0) {
      throw const DatasetSyncException(
        'Toll tariff amount cannot be negative.',
      );
    }
    if (boothBaseChargeCop != null && boothBaseChargeCop < 0) {
      throw const DatasetSyncException(
        'Toll tariff base amount cannot be negative.',
      );
    }
    final multiplier = _optionalInt(json['collectionMultiplier']);
    if (multiplier != null && multiplier < 1) {
      throw const DatasetSyncException(
        'Toll tariff multiplier must be positive.',
      );
    }
    return TollTariffRate(
      categoryCode: _requiredString(json, 'categoryCode').toUpperCase(),
      vehicleDescription: _optionalString(json['vehicleDescription']),
      rateType: _optionalString(json['rateType']),
      amountCop: amountCop,
      collectionMultiplier: multiplier,
      boothBaseChargeCop: boothBaseChargeCop,
      dataStatus: _optionalString(json['dataStatus']),
      sourceDate: _optionalString(json['sourceDate']),
      sourceDatePrecision: _optionalString(json['sourceDatePrecision']),
      consultedOn: _optionalString(json['consultedOn']),
      sourceType: _optionalString(json['sourceType']),
      amountSourceId: _optionalString(json['amountSourceId']),
      amountSourceUrl: _optionalString(json['amountSourceUrl']),
      chargeSourceUrl: _optionalString(json['chargeSourceUrl']),
      conditions: _optionalString(json['conditions']),
      publicationControl: _optionalString(json['publicationControl']),
    );
  }

  final String categoryCode;
  final String? vehicleDescription;
  final String? rateType;
  final int? amountCop;
  final int? collectionMultiplier;
  final int? boothBaseChargeCop;
  final String? dataStatus;
  final String? sourceDate;
  final String? sourceDatePrecision;
  final String? consultedOn;
  final String? sourceType;
  final String? amountSourceId;
  final String? amountSourceUrl;
  final String? chargeSourceUrl;
  final String? conditions;
  final String? publicationControl;

  int? get amountMinor => amountCop == null ? null : amountCop! * 100;
  int? get boothBaseChargeMinor =>
      boothBaseChargeCop == null ? null : boothBaseChargeCop! * 100;
  bool get hasOfficialSource => sourceType == 'Oficial';
  bool get hasSecondarySource => sourceType == 'Secundaria';
}

class TollSpecialTariffRate {
  const TollSpecialTariffRate({
    required this.categoryCode,
    required this.rateType,
    required this.amountCop,
    required this.conditionalChargeCop,
    required this.validityStatus,
    required this.sourceDate,
    required this.sourceDatePrecision,
    required this.beneficiariesCondition,
    required this.routeControl,
    required this.sourceType,
    required this.sourceUrl,
    required this.consultedOn,
  });

  factory TollSpecialTariffRate.fromJson(Map<String, dynamic> json) {
    return TollSpecialTariffRate(
      categoryCode: _requiredString(json, 'categoryCode').toUpperCase(),
      rateType: _optionalString(json['rateType']),
      amountCop: _optionalInt(json['amountCop']),
      conditionalChargeCop: _optionalInt(json['conditionalChargeCop']),
      validityStatus: _optionalString(json['validityStatus']),
      sourceDate: _optionalString(json['sourceDate']),
      sourceDatePrecision: _optionalString(json['sourceDatePrecision']),
      beneficiariesCondition: _optionalString(json['beneficiariesCondition']),
      routeControl: _optionalString(json['routeControl']),
      sourceType: _optionalString(json['sourceType']),
      sourceUrl: _optionalString(json['sourceUrl']),
      consultedOn: _optionalString(json['consultedOn']),
    );
  }

  final String categoryCode;
  final String? rateType;
  final int? amountCop;
  final int? conditionalChargeCop;
  final String? validityStatus;
  final String? sourceDate;
  final String? sourceDatePrecision;
  final String? beneficiariesCondition;
  final String? routeControl;
  final String? sourceType;
  final String? sourceUrl;
  final String? consultedOn;
}

class LocalTollPricingBreakdown {
  const LocalTollPricingBreakdown({
    required this.coverage,
    required this.subtotalMinor,
    required this.totalMinor,
    required this.missingRates,
    required this.charges,
  });

  final LocalTollPricingCoverage coverage;
  final int subtotalMinor;
  final int? totalMinor;
  final int missingRates;
  final List<LocalTollPricingCharge> charges;
}

enum LocalTollPricingCoverage {
  complete,
  partial,
  noPassages,
  unsupportedCategory,
}

class LocalTollPricingCharge {
  const LocalTollPricingCharge({
    required this.stationId,
    required this.name,
    required this.categoryCode,
    required this.amountMinor,
    required this.publicationControl,
    required this.sourceType,
    required this.sourceDate,
    required this.sourceUrl,
    this.nominalMinor,
    this.pendingReason,
    this.station,
  });

  final String stationId;
  final String name;
  final String categoryCode;
  final int? amountMinor;
  final String? publicationControl;
  final String? sourceType;
  final String? sourceDate;
  final String? sourceUrl;
  final int? nominalMinor;
  final String? pendingReason;
  final TollTariffStation? station;
}

LocalTollPricingBreakdown priceExplicitTollPassages({
  required TollTariffCatalog catalog,
  required Iterable<TollInventoryRecord> passages,
  required String operatorCategoryCode,
}) {
  final explicitPassages = passages.toList(growable: false);
  if (explicitPassages.isEmpty) {
    return const LocalTollPricingBreakdown(
      coverage: LocalTollPricingCoverage.noPassages,
      subtotalMinor: 0,
      totalMinor: null,
      missingRates: 0,
      charges: [],
    );
  }
  final categoryCode = operatorCategoryCode.trim().toUpperCase();
  if (categoryCode.isEmpty) {
    return const LocalTollPricingBreakdown(
      coverage: LocalTollPricingCoverage.unsupportedCategory,
      subtotalMinor: 0,
      totalMinor: null,
      missingRates: 0,
      charges: [],
    );
  }
  var subtotalMinor = 0;
  var missingRates = 0;
  final charges = <LocalTollPricingCharge>[];
  for (final passage in explicitPassages) {
    final station = catalog.byId(passage.id);
    final localCategory =
        categoryCode == 'I' && station?.id == 'INV-LOS-SANTOS-85453C31BB'
        ? 'AUTOMOVIL'
        : categoryCode;
    final rate = station?.generalRateByCategory(localCategory);
    final pendingReason = _pendingChargeReason(station, rate, passage);
    final amountMinor = pendingReason == null
        ? rate?.boothBaseChargeMinor ?? rate?.amountMinor
        : null;
    if (amountMinor == null) {
      missingRates++;
    } else {
      subtotalMinor += amountMinor;
    }
    charges.add(
      LocalTollPricingCharge(
        stationId: passage.id,
        name: station?.name ?? passage.name,
        categoryCode: localCategory,
        amountMinor: amountMinor,
        nominalMinor: rate?.amountMinor,
        pendingReason: pendingReason,
        station: station,
        publicationControl:
            rate?.publicationControl ?? station?.publicationControl,
        sourceType: rate?.sourceType,
        sourceDate: rate?.sourceDate,
        sourceUrl: rate?.chargeSourceUrl ?? rate?.amountSourceUrl,
      ),
    );
  }
  return LocalTollPricingBreakdown(
    coverage: missingRates == 0
        ? LocalTollPricingCoverage.complete
        : LocalTollPricingCoverage.partial,
    subtotalMinor: subtotalMinor,
    totalMinor: missingRates == 0 ? subtotalMinor : null,
    missingRates: missingRates,
    charges: List.unmodifiable(charges),
  );
}

String? _pendingChargeReason(
  TollTariffStation? station,
  TollTariffRate? rate,
  TollInventoryRecord passage,
) {
  if (passage.operationClassification ==
          TollOperationClassification.nonOperationalHistorical ||
      passage.operationClassification ==
          TollOperationClassification.damagedReviewRequired) {
    return 'Operación pendiente de verificar';
  }
  final controls = [station?.publicationControl, rate?.publicationControl];
  if (controls.any(
    (value) =>
        value?.startsWith('BLOQUEADO_') == true ||
        value == 'EXCLUIR_ESTACION_RETIRADA',
  )) {
    return 'Cobro bloqueado por revisión de datos';
  }
  if (controls.contains('APLICAR_SUSPENSION_PARCIAL')) {
    return 'Suspensión: vigencia y categoría por confirmar';
  }
  // These source-defined groups need direction evidence that proximity lacks.
  if (const {
        'TÚNEL DE ORIENTE',
        'TÚNEL DE LA LÍNEA',
        'LOS GARZONES',
      }.contains(station?.logicalChargeGroup) ||
      station?.id == 'INV-LOS-SANTOS-85453C31BB' ||
      controls.contains('VALIDAR_CODIGO_Y_SENTIDO')) {
    return 'Sentido y condición de cobro por confirmar';
  }
  if (rate?.dataStatus == 'SOLO_PASO_EXCEPCIONAL_AUTORIZADO') {
    return 'Paso excepcional: requiere autorización';
  }
  if (rate?.amountMinor == null) {
    return 'Tarifa de esta categoría no disponible';
  }
  if ((rate?.collectionMultiplier ?? 1) != 1 ||
      (rate?.boothBaseChargeMinor != null &&
          rate?.boothBaseChargeMinor != rate?.amountMinor)) {
    return 'Condición del importe de cobro por confirmar';
  }
  return null;
}

String tollVehicleDescription(TollTariffRate rate) {
  final description = rate.vehicleDescription;
  if (description == null ||
      description.startsWith('Clasificación local') ||
      description.startsWith('Código no publicado') ||
      description.contains('pendiente de confirmación')) {
    return 'Descripción no disponible';
  }
  return description;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw DatasetSyncException('Toll tariff $key must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

List<Object?> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw DatasetSyncException('Toll tariff $key must be a list.');
  }
  return value;
}

Map<String, dynamic> _mapValue(Object? value, String label) {
  if (value is! Map) {
    throw DatasetSyncException('$label must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw DatasetSyncException('Toll tariff $key is required.');
  }
  return value.trim();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw DatasetSyncException('Toll tariff $key must be boolean.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw DatasetSyncException('Toll tariff $key must be integer.');
  }
  return value;
}

num _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw DatasetSyncException('Toll tariff $key must be numeric.');
  }
  return value;
}

int? _optionalInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw const DatasetSyncException('Optional toll tariff integer is invalid.');
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is String) {
    return null;
  }
  throw const DatasetSyncException('Optional toll tariff string is invalid.');
}

String _normalize(String value) {
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    buffer.write(
      replacements[String.fromCharCode(rune)] ?? String.fromCharCode(rune),
    );
  }
  return buffer.toString();
}
