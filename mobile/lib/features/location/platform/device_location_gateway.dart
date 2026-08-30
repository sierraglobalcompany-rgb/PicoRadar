import 'package:geolocator/geolocator.dart' as geo;

enum DeviceLocationPermission { notRequested, granted, denied, deniedForever }

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionUnavailable,
}

class DeviceLocationPoint {
  const DeviceLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

sealed class DeviceLocationResult {
  const DeviceLocationResult();
}

class DeviceLocationSuccess extends DeviceLocationResult {
  const DeviceLocationSuccess(this.point);

  final DeviceLocationPoint point;
}

class DeviceLocationError extends DeviceLocationResult {
  const DeviceLocationError(this.failure);

  final DeviceLocationFailure failure;
}

abstract class DeviceLocationGateway {
  Future<bool> isLocationServiceEnabled();

  Future<DeviceLocationPermission> checkPermission();

  Future<DeviceLocationPermission> requestPermission();

  Future<DeviceLocationResult> getCurrentPosition();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorDeviceLocationGateway implements DeviceLocationGateway {
  const GeolocatorDeviceLocationGateway();

  @override
  Future<bool> isLocationServiceEnabled() {
    return geo.Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return _permission(await geo.Geolocator.checkPermission());
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    return _permission(await geo.Geolocator.requestPermission());
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return DeviceLocationSuccess(
        DeviceLocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );
    } catch (_) {
      return const DeviceLocationError(
        DeviceLocationFailure.positionUnavailable,
      );
    }
  }

  @override
  Future<bool> openAppSettings() {
    return geo.Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return geo.Geolocator.openLocationSettings();
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
