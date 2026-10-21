import 'dart:io';

import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';

final realTollInventory = TollInventoryDataset.fromJsonString(
  File('assets/catalogs/tolls_inventory_v1.json').readAsStringSync(),
);
final realTollCatalog = TollTariffCatalog.fromJsonString(
  File('assets/catalogs/tolls_tariffs_v1.json').readAsStringSync(),
);
final cocorna = realTollInventory.records.singleWhere(
  (toll) => toll.id == 'INV-COCORNA-6A6F1282D1',
);

DrivingPoint tollPoint(
  double south,
  int seconds, {
  double? heading = 0,
  double speed = 50,
  double accuracy = 12,
  TollInventoryRecord? toll,
}) => DrivingPoint(
  latitude: (toll ?? cocorna).latitude - south / 111320,
  longitude: (toll ?? cocorna).longitude,
  accuracyMeters: accuracy,
  speedKmh: speed,
  headingDegrees: heading,
  recordedAt: DateTime.utc(2026, 9, 9).add(Duration(seconds: seconds)),
);
