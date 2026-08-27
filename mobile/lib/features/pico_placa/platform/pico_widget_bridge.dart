import 'package:flutter/services.dart';

import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';

class PicoWidgetBridge {
  const PicoWidgetBridge([
    this._channel = const MethodChannel('co.picoradar.app/widget'),
  ]);

  final MethodChannel _channel;

  Future<void> updateNoVehicle() {
    return _channel.invokeMethod<void>('updatePicoWidget', {
      'configured': false,
      'hasVehicle': false,
    });
  }

  Future<void> updateMissingJurisdiction(VehicleProfile vehicle) {
    return _channel.invokeMethod<void>('updatePicoWidget', {
      'configured': false,
      'hasVehicle': true,
      'plate': vehicle.plate,
      'vehicleLabel': shortVehicleTypeLabel(vehicle),
    });
  }

  Future<void> updateConfigured({
    required VehicleProfile vehicle,
    required String jurisdictionName,
  }) {
    return _channel.invokeMethod<void>('updatePicoWidget', {
      'configured': true,
      'hasVehicle': true,
      'plate': vehicle.plate,
      'vehicleLabel': shortVehicleTypeLabel(vehicle),
      'jurisdictionName': jurisdictionName,
    });
  }
}
