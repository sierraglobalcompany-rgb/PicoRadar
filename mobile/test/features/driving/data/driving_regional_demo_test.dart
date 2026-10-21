import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/data/driving_regional_demo.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/driving_alert_engine.dart';
import 'package:picoradar/features/driving/domain/geo_math.dart' as geo;
import 'package:picoradar/features/driving/domain/traffic_camera.dart';

void main() {
  final source = File(drivingRegionalDemoAsset).readAsStringSync();
  final routes = parseDrivingRegionalDemo(source);
  final epoch = DateTime.utc(2026, 9, 9, 12);

  for (final id in ['niquiaToEstrella', 'estrellaToNiquia']) {
    test('$id follows fixture at 80 km/h, one second, exact endpoints', () {
      final route = routes.singleWhere((route) => route.id == id);
      final raw = (jsonDecode(source)['routes'] as List).singleWhere(
        (r) => r['id'] == id,
      );
      final coordinates = raw['coordinates'] as List;
      expect(coordinates.length, id == 'niquiaToEstrella' ? 600 : 525);
      final points = route.samples(epoch);
      expect(points.first.longitude, coordinates.first[0]);
      expect(points.first.latitude, coordinates.first[1]);
      expect(points.last.longitude, coordinates.last[0]);
      expect(points.last.latitude, coordinates.last[1]);
      expect(points.length, (route.lengthMeters / (80 / 3.6)).ceil() + 1);
      var segment = 0;
      var segmentStart = 0.0;
      double length(int i) => geo.distanceMeters(
        fromLatitude: coordinates[i][1],
        fromLongitude: coordinates[i][0],
        toLatitude: coordinates[i + 1][1],
        toLongitude: coordinates[i + 1][0],
      );
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final distance = (i * 80 / 3.6).clamp(0.0, route.lengthMeters);
        while (segment < coordinates.length - 2 &&
            segmentStart + length(segment) <= distance) {
          segmentStart += length(segment++);
        }
        final ratio = ((distance - segmentStart) / length(segment)).clamp(
          0.0,
          1.0,
        );
        expect(
          point.latitude,
          closeTo(
            coordinates[segment][1] +
                (coordinates[segment + 1][1] - coordinates[segment][1]) * ratio,
            1e-8,
          ),
        );
        expect(
          point.longitude,
          closeTo(
            coordinates[segment][0] +
                (coordinates[segment + 1][0] - coordinates[segment][0]) * ratio,
            1e-8,
          ),
        );
        expect(point.speedKmh, 80);
        expect(point.recordedAt, epoch.add(Duration(seconds: i)));
        expect(
          point.headingDegrees,
          closeTo(
            geo.bearingDegrees(
              fromLatitude: coordinates[segment][1],
              fromLongitude: coordinates[segment][0],
              toLatitude: coordinates[segment + 1][1],
              toLongitude: coordinates[segment + 1][0],
            ),
            1e-6,
          ),
        );
      }
      expect(route.lengthMeters, closeTo(raw['distanceMeters'], 150));
    });

    test('$id offline current camera pack matcher and alert audit', () {
      final pack = CameraPack.fromJson(
        jsonDecode(File(cameraPackAssetPath).readAsStringSync())
            as Map<String, Object?>,
      );
      expect(pack.cameras.length, 360);
      final engine = DrivingAlertEngine(
        profile: defaultDrivingPreferences.profile,
      );
      final candidates = <String>{};
      final alerted = <String>{};
      var alertCount = 0;
      DrivingPoint? previous;
      final points = routes
          .singleWhere((route) => route.id == id)
          .samples(epoch);
      for (final point in points) {
        if (previous == null) {
          engine.markNoMatch(point.recordedAt);
        } else {
          final match = matchNearestCamera(
            current: point,
            previous: previous,
            cameras: pack.cameras,
            targetingConeDegrees:
                defaultDrivingPreferences.cameraTargetingConeDegrees,
          );
          if (match != null) candidates.add(match.camera.id);
          final alert = engine.evaluate(
            match: match,
            speedKmh: point.speedKmh,
            now: point.recordedAt,
          );
          if (alert != null) {
            alerted.add(alert.cameraId);
            alertCount++;
          }
        }
        previous = point;
      }
      expect(alerted.difference(candidates), isEmpty);
      // Counts are observations of this pack, not a claim of road coverage.
      debugPrint(
        '$id: ${points.length} samples; ${candidates.length} distinct matched cameras; ${alerted.length} alerted cameras; $alertCount alert events',
      );
    });
  }

  test('invalid fixture fails closed, without substitute coordinates', () {
    for (final invalid in [
      null,
      [0, 0],
      [double.nan, 6.2],
      [-75.5, 91],
    ]) {
      final json = jsonDecode(source);
      json['routes'][0]['coordinates'][0] = invalid;
      // NaN cannot be encoded as JSON either.
      expect(
        () => parseDrivingRegionalDemo(jsonEncode(json)),
        throwsA(anything),
      );
    }
    final json = jsonDecode(source);
    json['routes'][0]['speedKmh'] = 90;
    expect(
      () => parseDrivingRegionalDemo(jsonEncode(json)),
      throwsFormatException,
    );
  });

  testWidgets('play emits immediately, then each second and cancels', (
    tester,
  ) async {
    final points = <DrivingPoint>[];
    final subscription = routes.first.play(startedAt: epoch).listen(points.add);
    await tester.pump();
    expect(points.length, 1);
    await tester.pump(const Duration(milliseconds: 999));
    expect(points.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(points.length, 2);
    var cancelled = false;
    subscription.cancel().then((_) => cancelled = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(points.length, 2);
    expect(cancelled, isTrue);
  });
}
