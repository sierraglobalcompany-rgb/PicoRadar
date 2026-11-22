import 'dart:convert';

const serviceProvidersDatasetKey = 'service_providers';
const emptyServiceProviderCatalogJson =
    '{"schemaVersion":1,"datasetKey":"service_providers","version":"bundled-empty","generatedAt":"2026-11-21T00:00:00Z","providers":[]}';

class ServiceProviderCatalog {
  ServiceProviderCatalog({
    required this.version,
    required this.generatedAt,
    required List<ServiceProviderRecord> providers,
  }) : providers = List.unmodifiable(providers);

  final String version;
  final DateTime generatedAt;
  final List<ServiceProviderRecord> providers;

  factory ServiceProviderCatalog.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Service provider dataset must be an object.',
      );
    }
    return ServiceProviderCatalog.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory ServiceProviderCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['datasetKey'] != serviceProvidersDatasetKey) {
      throw const FormatException('Unsupported service provider dataset.');
    }
    final version = _requiredText(json['version'], 'version', maxLength: 64);
    final generatedAt = _instant(json['generatedAt'], 'generatedAt');
    final rows = json['providers'];
    if (rows is! List) {
      throw const FormatException('providers must be a list.');
    }
    final providers = <ServiceProviderRecord>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map) {
        throw const FormatException('Invalid service provider record.');
      }
      final provider = ServiceProviderRecord.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (!ids.add(provider.id)) {
        throw const FormatException('Duplicate service provider id.');
      }
      providers.add(provider);
    }
    return ServiceProviderCatalog(
      version: version,
      generatedAt: generatedAt,
      providers: providers,
    );
  }

  List<ServiceProviderRecord> search(
    String query, {
    ServiceProviderCategory? category,
  }) {
    final needle = _fold(query);
    return providers
        .where((provider) {
          if (category != null && provider.category != category) return false;
          if (needle.isEmpty) return true;
          return _fold(
            [
              provider.name,
              provider.municipality,
              provider.department,
              provider.municipalityCode,
              provider.departmentCode,
              provider.address ?? '',
            ].join(' '),
          ).contains(needle);
        })
        .toList(growable: false);
  }
}

enum ServiceProviderCategory {
  cda('cda', 'CDA'),
  soat('soat', 'SOAT'),
  workshop('workshop', 'Taller'),
  tow('tow', 'Grúa'),
  ally('ally', 'Aliado');

  const ServiceProviderCategory(this.value, this.label);

  final String value;
  final String label;

  static ServiceProviderCategory parse(Object? value) {
    return ServiceProviderCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => throw const FormatException('Invalid provider category.'),
    );
  }
}

class ServiceProviderRecord {
  const ServiceProviderRecord({
    required this.id,
    required this.category,
    required this.departmentCode,
    required this.municipalityCode,
    required this.name,
    required this.sourceUrl,
    required this.verifiedAt,
    required this.validUntil,
    this.department,
    this.municipality,
    this.address,
    this.latitude,
    this.longitude,
    this.contactUrl,
  });

  final String id;
  final ServiceProviderCategory category;
  final String departmentCode;
  final String municipalityCode;
  final String? department;
  final String? municipality;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? contactUrl;
  final String sourceUrl;
  final DateTime verifiedAt;
  final DateTime validUntil;

  String get territoryLabel =>
      '${municipality?.trim().isNotEmpty == true ? municipality : municipalityCode}, '
      '${department?.trim().isNotEmpty == true ? department : departmentCode}';

  bool isCurrentAt(DateTime instant) {
    final bogotaDate = instant.toUtc().subtract(const Duration(hours: 5));
    return DateTime.utc(
          bogotaDate.year,
          bogotaDate.month,
          bogotaDate.day,
        ).compareTo(validUntil) <=
        0;
  }

  factory ServiceProviderRecord.fromJson(Map<String, dynamic> json) {
    final id = _requiredText(json['id'], 'id', maxLength: 80);
    if (!RegExp(r'^sp-[1-9][0-9]*$').hasMatch(id)) {
      throw const FormatException('Invalid stable service provider id.');
    }
    final departmentCode = _requiredCode(json['departmentCode'], 2);
    final municipalityCode = _requiredCode(json['municipalityCode'], 5);
    if (!municipalityCode.startsWith(departmentCode)) {
      throw const FormatException('DIVIPOLA codes do not match.');
    }
    final latitude = _optionalCoordinate(json['latitude'], -5, 14, 'latitude');
    final longitude = _optionalCoordinate(
      json['longitude'],
      -82,
      -66,
      'longitude',
    );
    if ((latitude == null) != (longitude == null)) {
      throw const FormatException('Coordinates must be supplied together.');
    }

    return ServiceProviderRecord(
      id: id,
      category: ServiceProviderCategory.parse(json['category']),
      departmentCode: departmentCode,
      municipalityCode: municipalityCode,
      department: _optionalText(json['department'], 'department', 120),
      municipality: _optionalText(json['municipality'], 'municipality', 120),
      name: _requiredText(json['name'], 'name', maxLength: 180),
      address: _optionalText(json['address'], 'address', 240),
      latitude: latitude,
      longitude: longitude,
      contactUrl: _httpsUrl(json['contactUrl'], 'contactUrl', optional: true),
      sourceUrl: _httpsUrl(json['sourceUrl'], 'sourceUrl')!,
      verifiedAt: _instant(json['verifiedAt'], 'verifiedAt'),
      validUntil: _dateOnly(json['validUntil'], 'validUntil'),
    );
  }
}

String _requiredCode(Object? value, int length) {
  if (value is! String || !RegExp('^\\d{$length}\$').hasMatch(value)) {
    throw const FormatException('Invalid DIVIPOLA code.');
  }
  return value;
}

String _requiredText(Object? value, String field, {required int maxLength}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.trim().length > maxLength) {
    throw FormatException('Invalid $field.');
  }
  return value.trim();
}

String? _optionalText(Object? value, String field, int maxLength) {
  if (value == null) return null;
  return _requiredText(value, field, maxLength: maxLength);
}

DateTime _instant(Object? value, String field) {
  if (value is! String || !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$field must include a timezone.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) throw FormatException('Invalid $field.');
  return date.toUtc();
}

DateTime _dateOnly(Object? value, String field) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$field must be YYYY-MM-DD.');
  }
  final parts = value.split('-').map(int.parse).toList(growable: false);
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.toIso8601String().substring(0, 10) != value) {
    throw FormatException('Invalid $field.');
  }
  return date;
}

double? _optionalCoordinate(
  Object? value,
  double min,
  double max,
  String field,
) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw FormatException('Invalid $field.');
  }
  return value.toDouble();
}

String? _httpsUrl(Object? value, String field, {bool optional = false}) {
  if (value == null && optional) return null;
  if (value is! String) throw FormatException('Invalid $field.');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw FormatException('$field must be an HTTPS URL.');
  }
  return uri.toString();
}

String _fold(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[áàä]'), 'a')
    .replaceAll(RegExp(r'[éèë]'), 'e')
    .replaceAll(RegExp(r'[íìï]'), 'i')
    .replaceAll(RegExp(r'[óòö]'), 'o')
    .replaceAll(RegExp(r'[úùü]'), 'u')
    .replaceAll('ñ', 'n');
