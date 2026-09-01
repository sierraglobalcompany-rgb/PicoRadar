import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production camera pack contains approved ANSV cameras only', () async {
    final pack = await loadCameraPack(rootBundle);

    expect(pack.cameras, hasLength(360));
    expect(pack.source.name, 'ANSV ubicaciones aprobadas de fotodetección');
    expect(pack.source.fetchedAtUtc, '2026-08-31T15:44:00+00:00');
    expect(
      pack.cameras.where((camera) => !camera.hasApprovedAuthorizationStatus),
      isEmpty,
    );
    expect(pack.cameras.where((camera) => camera.address == null), isEmpty);
    expect(
      pack.cameras.where((camera) => camera.trafficAuthority == null),
      isEmpty,
    );
    expect(pack.cameras.where((camera) => camera.latitude == 0), isEmpty);
    expect(pack.cameras.where((camera) => camera.longitude == 0), isEmpty);
  });

  test('loader rejects rejected ANSV cameras', () async {
    await _expectRejectedStatus('Rechazada');
  });

  test('loader rejects pending ANSV cameras', () async {
    await _expectRejectedStatus('Pendiente');
  });

  test('loader rejects cameras with observations', () async {
    await _expectRejectedStatus('Con observaciones');
  });

  test('loader fails closed for unknown ANSV camera statuses', () async {
    await _expectRejectedStatus('Suspendida');
  });

  test('matcher cannot receive an excluded camera from the loader', () async {
    final bundle = _StringAssetBundle(_packJson(status: 'Pendiente'));

    await expectLater(loadCameraPack(bundle), throwsFormatException);
  });

  test('loader accepts optional B05 rich source fields', () async {
    final bundle = _StringAssetBundle(
      jsonEncode({
        'schemaVersion': 1,
        'datasetKey': 'traffic_cameras',
        'source': {
          'title': 'ANSV ubicaciones aprobadas de fotodetección',
          'url': 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
          'fetchedAt': '2026-08-31T10:44:00-05:00',
        },
        'records': [
          {
            'cameraId': 'ansv-test',
            'department': 'ANTIOQUIA',
            'municipality': 'MEDELLIN',
            'jurisdiction': 'Municipal',
            'address': 'Avenida 80',
            'lat': 6.244,
            'lon': -75.57,
            'operationStatus': 'Operando',
            'reportedSpeedKmh': 60,
            'technology': 'Camara',
            'trafficAuthority': 'Secretaría de Movilidad de Medellín',
            'installationType': 'Fija',
            'equipmentName': 'Equipo 123',
            'infractionCodes': ['C29'],
          },
        ],
      }),
    );

    final pack = await loadCameraPack(bundle);
    final camera = pack.cameras.single;

    expect(pack.source.name, 'ANSV ubicaciones aprobadas de fotodetección');
    expect(pack.source.fetchedAtUtc, '2026-08-31T10:44:00-05:00');
    expect(camera.operationStatus, 'Operando');
    expect(camera.trafficAuthority, 'Secretaría de Movilidad de Medellín');
    expect(camera.installationType, 'Fija');
    expect(camera.equipmentName, 'Equipo 123');
    expect(camera.rawInfractionCodes, ['C29']);
  });
}

Future<void> _expectRejectedStatus(String status) async {
  final bundle = _StringAssetBundle(_packJson(status: status));

  await expectLater(loadCameraPack(bundle), throwsFormatException);
}

String _packJson({
  required String status,
  Map<String, Object?> extraFields = const {},
}) {
  return jsonEncode({
    'schemaVersion': 1,
    'source': {
      'name': 'ANSV',
      'pageUrl': 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      'dataUrl': 'https://srvansvargweb.ansv.gov.co/server/rest/services/Equipos_Fotodeteccion/Equipos_Geo/FeatureServer/0/query',
      'fetchedAtUtc': '2026-08-31T00:00:00Z',
    },
    'cameras': [
      {
        'id': 'ansv-test',
        'officialId': 'test',
        'department': 'ANTIOQUIA',
        'municipality': 'MEDELLIN',
        'jurisdiction': 'Municipal',
        'address': null,
        'latitude': 6.244,
        'longitude': -75.57,
        'status': status,
        'technology': 'Camara',
        'kind': 'mixed',
        'speedLimitKmh': 60,
        ...extraFields,
      },
    ],
  });
}

class _StringAssetBundle extends AssetBundle {
  _StringAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    expect(key, cameraPackAssetPath);
    return source;
  }
}
