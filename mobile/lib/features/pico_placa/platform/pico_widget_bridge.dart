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

class PicoWidgetSnapshotSync {
  PicoWidgetSnapshotSync(this._bridge);

  final PicoWidgetBridge _bridge;
  String? _lastSnapshot;

  Future<void> sync({
    required VehicleProfile? vehicle,
    required String? jurisdictionName,
  }) async {
    final snapshot = [
      vehicle?.id ?? 'none',
      vehicle?.plate ?? '',
      vehicle == null ? '' : shortVehicleTypeLabel(vehicle),
      jurisdictionName ?? '',
    ].join('|');
    if (_lastSnapshot == snapshot) {
      return;
    }

    if (vehicle == null) {
      await _bridge.updateNoVehicle();
    } else if (jurisdictionName == null) {
      await _bridge.updateMissingJurisdiction(vehicle);
    } else {
      await _bridge.updateConfigured(
        vehicle: vehicle,
        jurisdictionName: jurisdictionName,
      );
    }
    _lastSnapshot = snapshot;
  }
}
