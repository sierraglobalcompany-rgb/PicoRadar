class DefenseCase {
  const DefenseCase({
    required this.id,
    required this.vehicleId,
    required this.authority,
    required this.incidentDate,
    required this.facts,
    required this.createdAt,
    required this.updatedAt,
    this.reference,
    this.notificationDate,
  });

  final String id;
  final String vehicleId;
  final String? reference;
  final String authority;
  final DateTime incidentDate;
  final DateTime? notificationDate;
  final String facts;
  final DateTime createdAt;
  final DateTime updatedAt;

  DefenseCase copyWith({
    String? reference,
    String? authority,
    DateTime? incidentDate,
    DateTime? notificationDate,
    bool clearNotificationDate = false,
    String? facts,
    DateTime? updatedAt,
  }) {
    return DefenseCase(
      id: id,
      vehicleId: vehicleId,
      reference: reference ?? this.reference,
      authority: authority ?? this.authority,
      incidentDate: incidentDate ?? this.incidentDate,
      notificationDate: clearNotificationDate
          ? null
          : notificationDate ?? this.notificationDate,
      facts: facts ?? this.facts,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'reference': reference,
    'authority': authority,
    'incidentDate': _encodeDate(incidentDate),
    'notificationDate': notificationDate == null
        ? null
        : _encodeDate(notificationDate!),
    'facts': facts,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static DefenseCase fromJson(Map<String, Object?> json) {
    return DefenseCase(
      id: json['id']! as String,
      vehicleId: json['vehicleId']! as String,
      reference: _optionalString(json['reference']),
      authority: json['authority']! as String,
      incidentDate: parseDefenseDate(json['incidentDate']! as String),
      notificationDate: json['notificationDate'] == null
          ? null
          : parseDefenseDate(json['notificationDate']! as String),
      facts: json['facts']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
    );
  }
}

class DefenseCaseDraft {
  const DefenseCaseDraft({
    required this.vehicleId,
    required this.authority,
    required this.incidentDate,
    required this.facts,
    this.reference,
    this.notificationDate,
  });

  final String vehicleId;
  final String? reference;
  final String authority;
  final DateTime incidentDate;
  final DateTime? notificationDate;
  final String facts;
}

String formatDefenseDate(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

DateTime parseDefenseDate(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match == null) {
    throw FormatException('Invalid defense case date: $value.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Invalid defense case date: $value.');
  }
  return date;
}

String _encodeDate(DateTime date) {
  return formatDefenseDate(date);
}

String? _optionalString(Object? value) {
  final text = value as String?;
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return text;
}
