import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:picoradar/features/fotomultas/presentation/department_geometry.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';

void main() {
  late Map<String, dynamic> json;
  late DepartmentGeometry geometry;
  setUpAll(() async {
    json = jsonDecode(
      await File(departmentGeometryAsset).readAsString(),
    ) as Map<String, dynamic>;
    geometry = DepartmentGeometry.fromJson(json);
  });
  test('DANE has 33 distinct territories and all 90 components', () {
    expect(geometry.parts.map((p) => p.daneCode).toSet().length, 33);
    expect(geometry.parts.length, 90);
    expect(geometry.parts.where((p) => p.daneCode == '88').length, 6);
    expect(geometry.parts.where((p) => p.daneCode == '13').length, 51);
    for (final part in geometry.parts) {
      expect(part.rings.first.length, greaterThanOrEqualTo(4));
      expect(part.rings.first.first, part.rings.first.last);
    }
  });
  test('Bogota does not become Cundinamarca and coast is not a rectangle', () {
    const bogota = LatLng(4.65, -74.07);
    expect(geometry.contains('BOG', bogota), isTrue);
    expect(geometry.contains('CUN', bogota), isFalse);
    expect(geometry.contains('ANT', const LatLng(6.25, -75.57)), isTrue);
    expect(geometry.contains('ANT', const LatLng(10, -78)), isFalse);
    expect(geometry.candidates(const LatLng(0, -82), 12), isEmpty);
  });
  test('every label anchor is inside its own territory', () {
    for (final entry in geometry.labelParts.entries) {
      expect(
        geometry.contains(entry.key, entry.value.anchor),
        isTrue,
        reason: entry.key,
      );
      expect(entry.value.labelRadius, greaterThan(0));
    }
  });
  test('small territories remain candidates at national and detailed zoom', () {
    for (final code in ['BOG', 'ATL', 'QUI', 'RIS', 'SAP']) {
      final anchor = geometry.labelParts[code]!.anchor;
      expect(geometry.candidates(anchor, 5), contains(code));
      expect(geometry.candidates(anchor, 12), contains(code));
    }
  });
  test(
    'malformed or missing geometry is rejected rather than approximated',
    () {
      final missing = Map<String, dynamic>.from(json)
        ..['features'] = (json['features'] as List).skip(1).toList();
      expect(() => DepartmentGeometry.fromJson(missing), throwsFormatException);
    },
  );
  test(
    'current camera pack remains 360 with 76 in Antioquia and separate Bogota',
    () async {
      final pack = CameraPack.fromJson(
        (jsonDecode(
          await File('assets/datasets/cameras/cameras_v1.json').readAsString(),
        ) as Map).cast<String, Object?>(),
      );
      expect(pack.cameras.length, 360);
      expect(pack.cameras.where((c) => c.department == 'ANTIOQUIA').length, 76);
      expect(
        pack.cameras.where((c) => c.department == 'BOGOTA D.C').length,
        88,
      );
      expect(
        pack.cameras.where((c) => c.department == 'CUNDINAMARCA').length,
        2,
      );
    },
  );
}
