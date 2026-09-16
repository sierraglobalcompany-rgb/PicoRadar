import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

const departmentGeometryAsset =
    'assets/maps/colombia_departments_dane2025.geojson';
final departmentGeometryProvider =
    FutureProvider.autoDispose<DepartmentGeometry>((ref) async {
      final text = await rootBundle.loadString(departmentGeometryAsset);
      final parsed = await compute(_decodeGeometry, text);
      return DepartmentGeometry.fromJson(parsed);
    }, retry: (_, _) => null);

Map<String, dynamic> _decodeGeometry(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

// Legacy camera catalog identifiers stay unchanged; DANE identifies geometry only.
const daneToCameraDepartment = <String, String>{
  '05': 'ANT',
  '08': 'ATL',
  '11': 'BOG',
  '13': 'BOL',
  '15': 'BOY',
  '17': 'CAL',
  '18': 'CAQ',
  '19': 'CAU',
  '20': 'CES',
  '23': 'COR',
  '25': 'CUN',
  '27': 'CHO',
  '41': 'HUI',
  '44': 'LAG',
  '47': 'MAG',
  '50': 'MET',
  '52': 'NAR',
  '54': 'NSA',
  '63': 'QUI',
  '66': 'RIS',
  '68': 'SAN',
  '70': 'SUC',
  '73': 'TOL',
  '76': 'VAC',
  '81': 'ARA',
  '85': 'CAS',
  '86': 'PUT',
  '88': 'SAP',
  '91': 'AMA',
  '94': 'GUA',
  '95': 'GUV',
  '97': 'VAU',
  '99': 'VIC',
};

double distanceToSegment(Offset p, Offset a, Offset b) {
  final vector = b - a;
  final squared = vector.distanceSquared;
  if (squared == 0) return (p - a).distance;
  final fraction =
      (((p.dx - a.dx) * vector.dx + (p.dy - a.dy) * vector.dy) / squared).clamp(
        0.0,
        1.0,
      );
  return (p - (a + vector * fraction)).distance;
}

class DepartmentPart {
  DepartmentPart(this.daneCode, this.rings)
    : polygon = Polygon<String>(
        points: rings.first,
        holePointsList: rings.skip(1).toList(),
        color: const Color(0xffd5e8e9),
        borderColor: const Color(0xff547d8a),
        borderStrokeWidth: 0.7,
        hitValue: daneCode,
        labelPlacementCalculator:
            const PolygonLabelPlacementCalculator.polylabel(precision: 0.001),
      );

  final String daneCode;
  final List<List<LatLng>> rings;
  final Polygon<String> polygon;
  String get cameraCode => daneToCameraDepartment[daneCode]!;
  late final worldRings = rings
      .map(
        (ring) =>
            ring.map((p) => const Epsg3857().latLngToOffset(p, 0)).toList(),
      )
      .toList();
  late final ui.Path worldPath = _path();
  late final Rect worldBounds = worldPath.getBounds();
  late final LatLng anchor = polygon.labelPosition;
  late final Offset worldAnchor = const Epsg3857().latLngToOffset(anchor, 0);
  late final double labelRadius = boundaryDistance(worldAnchor);

  ui.Path _path() {
    final path = ui.Path()..fillType = PathFillType.evenOdd;
    for (final ring in worldRings) {
      path.addPolygon(ring, true);
    }
    return path;
  }

  double boundaryDistance(Offset point) {
    var distance = double.infinity;
    for (final ring in worldRings) {
      for (var i = 1; i < ring.length; i++) {
        distance = math.min(
          distance,
          distanceToSegment(point, ring[i - 1], ring[i]),
        );
      }
    }
    return distance;
  }

  Polygon<String> selectedPolygon() => Polygon<String>(
    points: rings.first,
    holePointsList: rings.skip(1).toList(),
    color: const Color(0xff087e83),
    borderColor: const Color(0xff123e51),
    borderStrokeWidth: 1.4,
    hitValue: daneCode,
  );
}

class DepartmentGeometry {
  DepartmentGeometry(this.parts) {
    for (final part in parts) {
      final old = labelParts[part.cameraCode];
      if (old == null || _area(part) > _area(old)) {
        labelParts[part.cameraCode] = part;
      }
    }
  }
  final List<DepartmentPart> parts;
  final Map<String, DepartmentPart> labelParts = {};
  static double _area(DepartmentPart p) =>
      p.worldBounds.width * p.worldBounds.height;
  late final continentalBounds = LatLngBounds.fromPoints(
    parts
        .where((p) => p.daneCode != '88')
        .expand((p) => p.rings.first)
        .toList(),
  );
  LatLngBounds boundsFor(String code) => LatLngBounds.fromPoints(
    parts
        .where((p) => p.cameraCode == code)
        .expand((p) => p.rings.first)
        .toList(),
  );

  factory DepartmentGeometry.fromJson(Map<String, dynamic> json) {
    final parts = <DepartmentPart>[];
    final codes = <String>{};
    for (final raw in json['features'] as List) {
      final feature = raw as Map<String, dynamic>;
      final code = (feature['properties'] as Map)['code'] as String;
      if (!daneToCameraDepartment.containsKey(code) || !codes.add(code)) {
        throw const FormatException('Invalid department code');
      }
      final geometry = feature['geometry'] as Map;
      final coordinates = geometry['coordinates'] as List;
      final List polygons = switch (geometry['type']) {
        'Polygon' => [coordinates],
        'MultiPolygon' => coordinates,
        _ => throw const FormatException('Expected polygon'),
      };
      for (final polygon in polygons) {
        final rings = <List<LatLng>>[];
        for (final rawRing in polygon as List) {
          final ring = (rawRing as List)
              .map((p) {
                final lat = (p[1] as num).toDouble(),
                    lon = (p[0] as num).toDouble();
                if (!lat.isFinite ||
                    !lon.isFinite ||
                    lat.abs() > 90 ||
                    lon.abs() > 180) {
                  throw const FormatException('Invalid coordinate');
                }
                return LatLng(lat, lon);
              })
              .toList(growable: false);
          if (ring.length < 4 || ring.first != ring.last) {
            throw const FormatException('Invalid ring');
          }
          rings.add(ring);
        }
        if (rings.isEmpty) throw const FormatException('Missing outline');
        parts.add(DepartmentPart(code, rings));
      }
    }
    if (codes.length != 33) {
      throw const FormatException('Incomplete department geometry');
    }
    return DepartmentGeometry(parts);
  }

  List<String> candidates(LatLng coordinate, double zoom) {
    final point = const Epsg3857().latLngToOffset(coordinate, 0);
    final factor = math.pow(2, zoom).toDouble();
    final near = <String>{};
    for (final part in parts) {
      if (!part.worldBounds.inflate(24 / factor).contains(point)) continue;
      final inside = part.worldPath.contains(point);
      final distance = part.boundaryDistance(point) * factor;
      if (inside && distance > 24) return [part.cameraCode];
      if (inside || distance <= 24) near.add(part.cameraCode);
    }
    return near.toList()..sort();
  }

  bool contains(String cameraCode, LatLng coordinate) {
    final point = const Epsg3857().latLngToOffset(coordinate, 0);
    return parts.any(
      (p) => p.cameraCode == cameraCode && p.worldPath.contains(point),
    );
  }
}
