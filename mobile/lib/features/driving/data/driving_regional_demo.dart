import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/camera_matcher.dart';
import '../domain/geo_math.dart' as geo;

const drivingRegionalDemoAsset = 'assets/config/driving_regional_demo_v1.json';

final drivingRegionalDemoLoaderProvider =
    Provider<Future<DrivingDemoRoute> Function(String)>((ref) {
      return (id) async {
        final routes = parseDrivingRegionalDemo(
          await rootBundle.loadString(drivingRegionalDemoAsset),
        );
        return routes.singleWhere((route) => route.id == id);
      };
    });

List<DrivingDemoRoute> parseDrivingRegionalDemo(String source) {
  final json = jsonDecode(source);
  if (json is! Map || json['schemaVersion'] != 1 || json['routes'] is! List) {
    throw const FormatException('Invalid driving demo schema.');
  }
  final routes = <DrivingDemoRoute>[];
  for (final raw in json['routes'] as List) {
    if (raw is! Map ||
        !const ['niquiaToEstrella', 'estrellaToNiquia'].contains(raw['id']) ||
        raw['speedKmh'] != 80 ||
        raw['intervalMilliseconds'] != 1000 ||
        raw['coordinates'] is! List) {
      throw const FormatException('Invalid driving demo route.');
    }
    final coordinates = <({double latitude, double longitude})>[];
    for (final pair in raw['coordinates'] as List) {
      if (pair is! List ||
          pair.length != 2 ||
          pair[0] is! num ||
          pair[1] is! num ||
          !(pair[0] as num).isFinite ||
          !(pair[1] as num).isFinite ||
          pair[0] < -82 ||
          pair[0] > -66 ||
          pair[1] < -5 ||
          pair[1] > 14) {
        throw const FormatException('Invalid driving demo coordinate.');
      }
      coordinates.add((
        latitude: (pair[1] as num).toDouble(),
        longitude: (pair[0] as num).toDouble(),
      ));
    }
    if (coordinates.length < 2) {
      throw const FormatException('Empty driving demo route.');
    }
    final cumulative = <double>[0];
    for (var i = 1; i < coordinates.length; i++) {
      cumulative.add(
        cumulative.last +
            geo.distanceMeters(
              fromLatitude: coordinates[i - 1].latitude,
              fromLongitude: coordinates[i - 1].longitude,
              toLatitude: coordinates[i].latitude,
              toLongitude: coordinates[i].longitude,
            ),
      );
    }
    if (cumulative.last <= 0) {
      throw const FormatException('Stationary driving demo route.');
    }
    routes.add(
      DrivingDemoRoute._(raw['id'] as String, coordinates, cumulative),
    );
  }
  if (routes.length != 2 ||
      routes.map((route) => route.id).toSet().length != 2) {
    throw const FormatException('Driving demo requires both directions.');
  }
  return List.unmodifiable(routes);
}

class DrivingDemoRoute {
  DrivingDemoRoute._(this.id, this._coordinates, this._cumulative);

  final String id;
  final List<({double latitude, double longitude})> _coordinates;
  final List<double> _cumulative;
  double get lengthMeters => _cumulative.last;

  List<DrivingPoint> samples(DateTime startedAt) {
    const metersPerTick = 80 / 3.6;
    final lastTick = (lengthMeters / metersPerTick).ceil();
    var segment = 0;
    return [
      for (var tick = 0; tick <= lastTick; tick++)
        (() {
          final distance = (tick * metersPerTick).clamp(0.0, lengthMeters);
          while (segment < _coordinates.length - 2 &&
              _cumulative[segment + 1] <= distance) {
            segment++;
          }
          final from = _coordinates[segment];
          final to = _coordinates[segment + 1];
          final length = _cumulative[segment + 1] - _cumulative[segment];
          final fraction = length == 0
              ? 1.0
              : (distance - _cumulative[segment]) / length;
          return DrivingPoint(
            // The final tick clips the remaining distance, never extends the road.
            latitude: tick == lastTick
                ? _coordinates.last.latitude
                : from.latitude + (to.latitude - from.latitude) * fraction,
            longitude: tick == lastTick
                ? _coordinates.last.longitude
                : from.longitude + (to.longitude - from.longitude) * fraction,
            accuracyMeters: 12,
            speedKmh: 80,
            headingDegrees: geo.bearingDegrees(
              fromLatitude: from.latitude,
              fromLongitude: from.longitude,
              toLatitude: to.latitude,
              toLongitude: to.longitude,
            ),
            recordedAt: startedAt.toUtc().add(Duration(seconds: tick)),
          );
        })(),
    ];
  }

  Stream<DrivingPoint> play({DateTime? startedAt}) {
    late StreamController<DrivingPoint> controller;
    late List<DrivingPoint> points;
    Timer? timer;
    var index = 0;
    void tick() {
      controller.add(points[index++]);
      if (index == points.length) {
        timer?.cancel();
        unawaited(controller.close());
      }
    }

    void schedule() {
      if (index < points.length) {
        timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
      }
    }

    controller = StreamController<DrivingPoint>(
      onListen: () {
        points = samples(startedAt ?? DateTime.now().toUtc());
        tick();
        schedule();
      },
      onPause: () => timer?.cancel(),
      onResume: schedule,
      onCancel: () async {
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
