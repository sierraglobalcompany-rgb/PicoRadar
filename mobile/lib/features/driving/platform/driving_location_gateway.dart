import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;

import '../../location/platform/device_location_gateway.dart';
import '../domain/camera_matcher.dart';

abstract class DrivingLocationGateway {
  Future<bool> isLocationServiceEnabled();

  Future<DeviceLocationPermission> checkPermission();

  Future<DeviceLocationPermission> requestPermission();

  Stream<DrivingPoint> positionStream();
}

class GeolocatorDrivingLocationGateway implements DrivingLocationGateway {
  const GeolocatorDrivingLocationGateway();

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return _permission(await geo.Geolocator.checkPermission());
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return geo.Geolocator.isLocationServiceEnabled();
  }

  @override
  Stream<DrivingPoint> positionStream() {
    return geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).map(_point);
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    return _permission(await geo.Geolocator.requestPermission());
  }

  DrivingPoint _point(geo.Position position) {
    return DrivingPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedKmh: (position.speed * 3.6).clamp(0, 260).toDouble(),
      headingDegrees: position.heading.isFinite && position.heading >= 0
          ? position.heading
          : null,
      recordedAt: position.timestamp,
    );
  }

  DeviceLocationPermission _permission(geo.LocationPermission permission) {
    return switch (permission) {
      geo.LocationPermission.always ||
      geo.LocationPermission.whileInUse => DeviceLocationPermission.granted,
      geo.LocationPermission.denied => DeviceLocationPermission.denied,
      geo.LocationPermission.deniedForever =>
        DeviceLocationPermission.deniedForever,
      geo.LocationPermission.unableToDetermine =>
        DeviceLocationPermission.notRequested,
    };
  }
}
