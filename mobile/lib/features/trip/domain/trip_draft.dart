enum TripChecklistItem {
  picoPlaca('pico_placa', 'Revisé Pico y placa'),
  soat('soat', 'Revisé SOAT'),
  tecnomecanica('tecnomecanica', 'Revisé tecnomecánica'),
  safety('safety', 'Planeé descansos y elementos de seguridad');

  const TripChecklistItem(this.key, this.label);

  final String key;
  final String label;

  static TripChecklistItem? fromKey(String key) {
    for (final item in values) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }
}

enum TripVehicleConfiguration {
  standardTwoAxle('standard_two_axle'),
  unsupported('unsupported');

  const TripVehicleConfiguration(this.key);

  final String key;

  static TripVehicleConfiguration fromKey(Object? value) => switch (value) {
    'unsupported' => unsupported,
    _ => standardTwoAxle,
  };
}

enum TripVehicleCategorySource {
  defaultStandard('default_standard'),
  userSelected('user_selected');

  const TripVehicleCategorySource(this.key);

  final String key;

  static TripVehicleCategorySource fromKey(Object? value) => switch (value) {
    'user_selected' => userSelected,
    _ => defaultStandard,
  };
}

class TripDraft {
  const TripDraft({
    required this.origin,
    required this.destination,
    required this.date,
    this.activeVehicleId,
    this.departureMinute,
    this.vehicleConfiguration = TripVehicleConfiguration.standardTwoAxle,
    this.vehicleCategorySource = TripVehicleCategorySource.defaultStandard,
    this.completedChecklist = const {},
  });

  final String origin;
  final String destination;
  final DateTime date;
  final String? activeVehicleId;
  final int? departureMinute;
  final TripVehicleConfiguration vehicleConfiguration;
  final TripVehicleCategorySource vehicleCategorySource;
  final Set<TripChecklistItem> completedChecklist;

  Map<String, Object?> toJson() {
    return {
      'origin': origin.trim(),
      'destination': destination.trim(),
      'date': _dateOnlyIso(date),
      'activeVehicleId': _optionalText(activeVehicleId),
      'departureMinute': departureMinute,
      'vehicleConfiguration': vehicleConfiguration.key,
      'vehicleCategorySource': vehicleCategorySource.key,
      'completedChecklist': [for (final item in completedChecklist) item.key],
    };
  }

  static TripDraft fromJson(Map<String, Object?> json) {
    final rawDate = json['date'];
    if (rawDate is! String || rawDate.trim().isEmpty) {
      throw const FormatException('Trip draft date is required.');
    }

    final rawChecklist = json['completedChecklist'];
    final completedChecklist = <TripChecklistItem>{};
    if (rawChecklist is List) {
      for (final value in rawChecklist) {
        if (value is String) {
          final item = TripChecklistItem.fromKey(value);
          if (item != null) {
            completedChecklist.add(item);
          }
        }
      }
    }

    final minute = json['departureMinute'];
    if (minute != null && (minute is! int || minute < 0 || minute > 1439)) {
      throw const FormatException('Trip draft time is invalid.');
    }
    return TripDraft(
      origin: _requiredText(json['origin'], 'origin'),
      destination: _requiredText(json['destination'], 'destination'),
      date: DateTime.parse(rawDate),
      activeVehicleId: _optionalText(json['activeVehicleId']),
      departureMinute: minute as int?,
      vehicleConfiguration: TripVehicleConfiguration.fromKey(
        json['vehicleConfiguration'],
      ),
      vehicleCategorySource: TripVehicleCategorySource.fromKey(
        json['vehicleCategorySource'],
      ),
      completedChecklist: completedChecklist,
    );
  }
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Trip draft $field is required.');
  }
  return value.trim();
}

String? _optionalText(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _dateOnlyIso(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
