import 'dart:convert';

import '../../../core/database/app_database.dart';

enum AlertCategory {
  pico('Pico y Placa'),
  soat('SOAT'),
  rtm('Tecnomecanica'),
  insurance('Seguro');

  const AlertCategory(this.label);
  final String label;
}

class AlertSettings {
  const AlertSettings({
    this.enabled = true,
    this.alarm = false,
    this.enriched = false,
    this.minute = 540,
    this.offsetDays = const [30, 7, 1],
    this.dayBefore = true,
    this.sameDay = true,
    this.dayBeforeMinute = 1140,
    this.sameDayMinute = 300,
  });
  final bool enabled, alarm, enriched, dayBefore, sameDay;
  final int minute, dayBeforeMinute, sameDayMinute;
  final List<int> offsetDays;

  AlertSettings copyWith({
    bool? enabled,
    bool? alarm,
    bool? enriched,
    int? minute,
    List<int>? offsetDays,
    bool? dayBefore,
    bool? sameDay,
    int? dayBeforeMinute,
    int? sameDayMinute,
  }) => AlertSettings(
    enabled: enabled ?? this.enabled,
    alarm: alarm ?? this.alarm,
    enriched: enriched ?? this.enriched,
    minute: minute ?? this.minute,
    offsetDays: List.unmodifiable(offsetDays ?? this.offsetDays),
    dayBefore: dayBefore ?? this.dayBefore,
    sameDay: sameDay ?? this.sameDay,
    dayBeforeMinute: dayBeforeMinute ?? this.dayBeforeMinute,
    sameDayMinute: sameDayMinute ?? this.sameDayMinute,
  );

  Map<String, Object> toJson() => {
    'v': 1,
    'enabled': enabled,
    'alarm': alarm,
    'enriched': enriched,
    'minute': minute,
    'offsetDays': offsetDays,
    'dayBefore': dayBefore,
    'sameDay': sameDay,
    'dayBeforeMinute': dayBeforeMinute,
    'sameDayMinute': sameDayMinute,
  };

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) {
      if (!json.containsKey(key)) return fallback;
      if (json[key] is! bool) throw const FormatException('Invalid alert flag');
      return json[key] as bool;
    }

    int time(String key, int fallback) {
      final value = json[key] ?? fallback;
      if (value is! int || value < 0 || value >= 1440) {
        throw const FormatException('Invalid alert time');
      }
      return value;
    }

    final offsets = json['offsetDays'] ?? [30, 7, 1];
    if (offsets is! List ||
        offsets.isEmpty ||
        offsets.length > 5 ||
        offsets.any((v) => v is! int || v < 0 || v > 365) ||
        offsets.toSet().length != offsets.length ||
        (json['v'] ?? 1) != 1) {
      throw const FormatException('Invalid alert settings');
    }
    return AlertSettings(
      enabled: flag('enabled', true),
      alarm: flag('alarm', false),
      enriched: flag('enriched', false),
      minute: time('minute', 540),
      offsetDays: List.unmodifiable(offsets.cast<int>()),
      dayBefore: flag('dayBefore', true),
      sameDay: flag('sameDay', true),
      dayBeforeMinute: time('dayBeforeMinute', 1140),
      sameDayMinute: time('sameDayMinute', 300),
    );
  }
}

class VehicleAlertSettings {
  const VehicleAlertSettings(this.vehicleId, this.category, this.settings);
  final String vehicleId;
  final AlertCategory category;
  final AlertSettings settings;
}

class AlertSettingsStore {
  const AlertSettingsStore(this.database);
  final AppDatabase database;

  Future<List<VehicleAlertSettings>> loadAll() async => [
    for (final row in await database.readAlertSettings())
      VehicleAlertSettings(
        row.read<String>('vehicle_id'),
        AlertCategory.values.byName(row.read<String>('category')),
        AlertSettings.fromJson(
          jsonDecode(row.read<String>('settings_json')) as Map<String, dynamic>,
        ),
      ),
  ];

  Future<AlertSettings?> load(String vehicleId, AlertCategory category) async {
    for (final row in await database.readAlertSettings()) {
      if (row.read<String>('vehicle_id') == vehicleId &&
          row.read<String>('category') == category.name) {
        return AlertSettings.fromJson(
          jsonDecode(row.read<String>('settings_json')) as Map<String, dynamic>,
        );
      }
    }
    return null;
  }

  Future<void> save(
    String vehicleId,
    AlertCategory category,
    AlertSettings settings,
  ) {
    final valid = AlertSettings.fromJson(settings.toJson());
    return database.transaction(() async {
      await database.writeAlertSettings(
        vehicleId,
        category.name,
        jsonEncode(valid.toJson()),
      );
      if (category != AlertCategory.pico) {
        await database.setObligationReminder(
          vehicleId,
          category.name,
          valid.enabled,
        );
      }
    });
  }
}
