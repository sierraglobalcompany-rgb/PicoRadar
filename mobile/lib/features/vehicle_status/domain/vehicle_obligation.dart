import 'dart:convert';

enum VehicleObligationType {
  soat('soat', 'SOAT'),
  rtm('rtm', 'Tecnomecánica'),
  insurance('insurance', 'Seguro'),
  tax('tax', 'Impuestos');

  const VehicleObligationType(this.value, this.label);

  final String value;
  final String label;

  static VehicleObligationType fromValue(String value) {
    return switch (value) {
      'soat' => VehicleObligationType.soat,
      'rtm' => VehicleObligationType.rtm,
      'insurance' => VehicleObligationType.insurance,
      'tax' => VehicleObligationType.tax,
      _ => throw ArgumentError.value(value, 'type', 'Unsupported obligation.'),
    };
  }
}

enum VehicleObligationState { notConfigured, valid, dueSoon, expired }

class VehicleObligation {
  const VehicleObligation({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.reminderEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.startDate,
    this.dueDate,
    this.details = const {},
  });

  final String id;
  final String vehicleId;
  final VehicleObligationType type;
  final DateTime? startDate;
  final DateTime? dueDate;
  final Map<String, String> details;
  final bool reminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
}

String vehicleObligationId(String vehicleId, VehicleObligationType type) {
  return '$vehicleId:${type.value}';
}

VehicleObligationState evaluateVehicleObligationState({
  required DateTime? dueDate,
  required DateTime nowBogota,
}) {
  if (dueDate == null) {
    return VehicleObligationState.notConfigured;
  }

  final today = DateTime(nowBogota.year, nowBogota.month, nowBogota.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final days = due.difference(today).inDays;
  if (days < 0) {
    return VehicleObligationState.expired;
  }
  if (days <= 30) {
    return VehicleObligationState.dueSoon;
  }
  return VehicleObligationState.valid;
}

Map<String, String> parseVehicleObligationDetails(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const {};
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return const {};
    }
    final details = <String, String>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) {
        details[entry.key] = value.trim();
      }
    }
    return Map.unmodifiable(details);
  } on FormatException {
    return const {};
  }
}

String encodeVehicleObligationDetails(Map<String, String> details) {
  final cleaned = <String, String>{};
  for (final entry in details.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      cleaned[entry.key] = value;
    }
  }
  return jsonEncode(cleaned);
}

String obligationStatusText(
  VehicleObligationType type,
  VehicleObligationState state,
) {
  final localText = switch (state) {
    VehicleObligationState.notConfigured => 'Sin configurar',
    VehicleObligationState.valid => 'Vigente según la fecha guardada',
    VehicleObligationState.dueSoon => 'Vence pronto según la fecha guardada',
    VehicleObligationState.expired => 'Fecha vencida según la fecha guardada',
  };
  if (type == VehicleObligationType.tax) {
    return 'Consulta calendario oficial';
  }
  return localText;
}
