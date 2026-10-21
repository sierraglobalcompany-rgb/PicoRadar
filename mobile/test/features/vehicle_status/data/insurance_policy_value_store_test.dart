import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/insurance_policy_value.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

void main() {
  test(
    'source value survives SQLite close/reopen without altering other data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'c13-value-test-',
      );
      final file = File('${directory.path}/fixture.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      try {
        await database
            .into(database.vehicles)
            .insert(
              VehiclesCompanion.insert(id: 'fictional-car', plate: 'QA123'),
            );
        final source = InsurancePolicyValue(
          minorUnits: 10001,
          period: InsuranceValuePeriod.annual,
        );
        final original = await VehicleObligationStore(database).upsert(
          vehicleId: 'fictional-car',
          type: VehicleObligationType.insurance,
          startDate: DateTime(2024, 2, 29),
          dueDate: DateTime(2027, 2, 28),
          reminderEnabled: false,
          details: {
            'providerName': 'Entidad ficticia',
            'legacyKey': 'preserved',
            ...source.toDetails(),
          },
        );
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        final restored = (await VehicleObligationStore(database)
            .get('fictional-car', VehicleObligationType.insurance))!;
        expect(restored.details, original.details);
        expect(restored.startDate, original.startDate);
        expect(restored.dueDate, original.dueDate);
        expect(restored.reminderEnabled, isFalse);
        final value = InsurancePolicyValue.fromDetails(restored.details)!;
        expect(value.minorUnits, 10001);
        expect(value.period, InsuranceValuePeriod.annual);
        expect(value.inputFor(InsuranceValuePeriod.monthly), '8,33');
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
