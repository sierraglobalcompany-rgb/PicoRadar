import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

void main() {
  group('vehicle obligation status', () {
    final now = DateTime(2026, 8, 27, 22);

    test('returns not configured without a due date', () {
      expect(
        evaluateVehicleObligationState(dueDate: null, nowBogota: now),
        VehicleObligationState.notConfigured,
      );
    });

    test('returns valid when due date is more than 30 days away', () {
      expect(
        evaluateVehicleObligationState(
          dueDate: DateTime(2026, 9, 28),
          nowBogota: now,
        ),
        VehicleObligationState.valid,
      );
    });

    test('returns due soon from 30 days before through due date', () {
      expect(
        evaluateVehicleObligationState(
          dueDate: DateTime(2026, 9, 26),
          nowBogota: now,
        ),
        VehicleObligationState.dueSoon,
      );
      expect(
        evaluateVehicleObligationState(
          dueDate: DateTime(2026, 8, 27),
          nowBogota: now,
        ),
        VehicleObligationState.dueSoon,
      );
    });

    test('returns expired after the Bogota calendar day passes', () {
      expect(
        evaluateVehicleObligationState(
          dueDate: DateTime(2026, 8, 26, 23, 59),
          nowBogota: now,
        ),
        VehicleObligationState.expired,
      );
    });

    test('keeps status text scoped to saved dates', () {
      expect(
        obligationStatusText(
          VehicleObligationType.soat,
          VehicleObligationState.valid,
        ),
        'Vigente según la fecha guardada',
      );
      expect(
        obligationStatusText(
          VehicleObligationType.rtm,
          VehicleObligationState.dueSoon,
        ),
        'Vence pronto según la fecha guardada',
      );
    });

    test('encodes only non-empty detail strings', () {
      final decoded = parseVehicleObligationDetails(
        encodeVehicleObligationDetails(const {
          'insurerName': ' Seguros Alfa ',
          'policyNumber': '',
        }),
      );

      expect(decoded, {'insurerName': 'Seguros Alfa'});
    });
  });
}
