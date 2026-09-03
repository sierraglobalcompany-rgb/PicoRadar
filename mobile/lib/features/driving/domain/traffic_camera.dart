class CameraPack {
  const CameraPack({required this.source, required this.cameras});

  final CameraPackSource source;
  final List<TrafficCamera> cameras;

  factory CameraPack.fromJson(Map<String, Object?> json) {
    final sourceJson = (json['source'] as Map?)?.cast<String, Object?>();
    final sourceItems =
        json['records'] as List? ?? json['cameras'] as List? ?? const [];
    final cameraItems = sourceItems
        .whereType<Map>()
        .map((item) => TrafficCamera.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    for (final camera in cameraItems) {
      if (!camera.hasApprovedAuthorizationStatus) {
        throw FormatException(
          'Camera pack contains a non-approved ANSV camera: ${camera.id}',
        );
      }
    }
    return CameraPack(
      source: CameraPackSource.fromJson(sourceJson ?? const {}),
      cameras: cameraItems,
    );
  }
}

class CameraPackSource {
  const CameraPackSource({
    required this.name,
    required this.pageUrl,
    required this.dataUrl,
    required this.fetchedAtUtc,
  });

  final String name;
  final String pageUrl;
  final String dataUrl;
  final String fetchedAtUtc;

  factory CameraPackSource.fromJson(Map<String, Object?> json) {
    return CameraPackSource(
      name: _string(json['name'] ?? json['title']),
      pageUrl: _string(json['pageUrl'] ?? json['url']),
      dataUrl: _string(json['dataUrl'] ?? json['url']),
      fetchedAtUtc: _string(json['fetchedAtUtc'] ?? json['fetchedAt']),
    );
  }
}

enum CameraKind {
  speed('Velocidad'),
  redLight('Semáforo'),
  mixed('Fotodetección');

  const CameraKind(this.label);

  final String label;
}

class TrafficCamera {
  const TrafficCamera({
    required this.id,
    required this.department,
    required this.municipality,
    required this.jurisdiction,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.technology,
    required this.kind,
    required this.speedLimitKmh,
    this.operationStatus,
    this.trafficAuthority,
    this.installationType,
    this.equipmentName,
    this.rawInfractionCodes = const [],
  });

  final String id;
  final String? department;
  final String? municipality;
  final String? jurisdiction;
  final String? address;
  final double latitude;
  final double longitude;
  final String? status;
  final String? technology;
  final CameraKind kind;
  final int? speedLimitKmh;
  final String? operationStatus;
  final String? trafficAuthority;
  final String? installationType;
  final String? equipmentName;
  final List<String> rawInfractionCodes;

  factory TrafficCamera.fromJson(Map<String, Object?> json) {
    return TrafficCamera(
      id: _string(json['id'] ?? json['cameraId']),
      department: _nullableString(json['department']),
      municipality: _nullableString(json['municipality']),
      jurisdiction: _nullableString(json['jurisdiction']),
      address: _nullableString(json['address']),
      latitude: _double(json['latitude'] ?? json['lat']),
      longitude: _double(json['longitude'] ?? json['lon']),
      status: _nullableString(json['status'] ?? json['authorizationStatus']),
      technology: _nullableString(json['technology']),
      kind: switch (_string(json['kind'])) {
        'speed' => CameraKind.speed,
        'red_light' => CameraKind.redLight,
        _ => CameraKind.mixed,
      },
      speedLimitKmh: _int(json['speedLimitKmh'] ?? json['reportedSpeedKmh']),
      operationStatus: _nullableString(json['operationStatus']),
      trafficAuthority: _nullableString(json['trafficAuthority']),
      installationType: _nullableString(json['installationType']),
      equipmentName: _nullableString(json['equipmentName']),
      rawInfractionCodes: _stringList(
        json['rawInfractionCodes'] ?? json['infractionCodes'],
      ),
    );
  }

  String get locality {
    final city = municipality;
    final dept = department;
    if (city != null && dept != null) {
      return '$city, $dept';
    }
    return city ?? dept ?? 'Colombia';
  }

  bool get hasApprovedAuthorizationStatus {
    final approvedStatus = status?.trim().toLowerCase() == 'aprobada';
    final operatingStatus = operationStatus?.trim().toLowerCase() == 'operando';
    return approvedStatus || operatingStatus;
  }
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _int(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) ?_nullableString(item)];
}
