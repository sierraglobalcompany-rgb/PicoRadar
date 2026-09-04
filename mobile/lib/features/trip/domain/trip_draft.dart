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

class TripDraft {
  const TripDraft({
    required this.origin,
    required this.destination,
    required this.date,
    this.activeVehicleId,
    this.completedChecklist = const {},
  });

  final String origin;
  final String destination;
  final DateTime date;
  final String? activeVehicleId;
  final Set<TripChecklistItem> completedChecklist;

  Map<String, Object?> toJson() {
    return {
      'origin': origin.trim(),
      'destination': destination.trim(),
      'date': _dateOnlyIso(date),
      'activeVehicleId': _optionalText(activeVehicleId),
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

    return TripDraft(
      origin: _requiredText(json['origin'], 'origin'),
      destination: _requiredText(json['destination'], 'destination'),
      date: DateTime.parse(rawDate),
      activeVehicleId: _optionalText(json['activeVehicleId']),
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
