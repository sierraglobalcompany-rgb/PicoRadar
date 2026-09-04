import '../../garage/data/vehicle_profile.dart';
import 'defense_case.dart';

const defensePrudentDisclaimer =
    'PicoRadar organiza la informacion que ingresas.\n'
    'No decide si un comparendo o una sancion es valido o nulo,\n'
    'no reemplaza asesoria juridica y no radica documentos.';

String buildDefenseCaseNeutralSummary({
  required DefenseCase defenseCase,
  required VehicleProfile vehicle,
}) {
  final buffer = StringBuffer()
    ..writeln(defensePrudentDisclaimer)
    ..writeln()
    ..writeln('Vehiculo: ${vehicle.plate}')
    ..writeln('Autoridad: ${defenseCase.authority}')
    ..writeln(
      'Fecha del hecho: ${formatDefenseDate(defenseCase.incidentDate)}',
    );

  final notificationDate = defenseCase.notificationDate;
  if (notificationDate != null) {
    buffer.writeln(
      'Fecha de notificacion: ${formatDefenseDate(notificationDate)}',
    );
  }

  final reference = defenseCase.reference;
  if (reference != null && reference.trim().isNotEmpty) {
    buffer.writeln('Referencia: ${reference.trim()}');
  }

  buffer
    ..writeln()
    ..writeln('Hechos escritos por el usuario:')
    ..write(defenseCase.facts.trim());
  return buffer.toString();
}
