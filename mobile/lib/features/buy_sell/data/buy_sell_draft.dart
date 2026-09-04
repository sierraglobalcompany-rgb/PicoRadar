import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const buySellDraftPreferenceKey = 'buy_sell.draft.v1';
const buySellMandatoryCopy =
    'Esta preparacion no certifica el estado juridico, mecanico o tributario del vehiculo.';

enum BuySellMode {
  buy('buy', 'Comprar'),
  sell('sell', 'Vender');

  const BuySellMode(this.value, this.label);

  final String value;
  final String label;

  static BuySellMode fromValue(String? value) {
    return switch (value) {
      'sell' => BuySellMode.sell,
      _ => BuySellMode.buy,
    };
  }
}

class BuySellDraft {
  const BuySellDraft({
    required this.mode,
    required this.candidatePlate,
    required this.city,
    required this.notes,
    required this.checkedItems,
  });

  final BuySellMode mode;
  final String candidatePlate;
  final String city;
  final String notes;
  final Set<String> checkedItems;

  String toJsonString() {
    return jsonEncode({
      'mode': mode.value,
      'candidatePlate': candidatePlate.trim(),
      'city': city.trim(),
      'notes': notes.trim(),
      'checkedItems': checkedItems.toList()..sort(),
    });
  }

  static BuySellDraft fromJsonString(String source) {
    final data = jsonDecode(source);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Buy/sell draft must be an object.');
    }
    final checked = data['checkedItems'];
    return BuySellDraft(
      mode: BuySellMode.fromValue(data['mode'] as String?),
      candidatePlate: data['candidatePlate'] as String? ?? '',
      city: data['city'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      checkedItems: {
        if (checked is List)
          for (final item in checked)
            if (item is String) item,
      },
    );
  }
}

Future<BuySellDraft?> loadBuySellDraft(AppPreferences preferences) async {
  final source = await preferences.getString(buySellDraftPreferenceKey);
  if (source == null || source.trim().isEmpty) {
    return null;
  }
  try {
    return BuySellDraft.fromJsonString(source);
  } on FormatException {
    return null;
  }
}

Future<void> saveBuySellDraft(AppPreferences preferences, BuySellDraft draft) {
  return preferences.setString(buySellDraftPreferenceKey, draft.toJsonString());
}

Future<void> deleteBuySellDraft(AppPreferences preferences) {
  return preferences.remove(buySellDraftPreferenceKey);
}
