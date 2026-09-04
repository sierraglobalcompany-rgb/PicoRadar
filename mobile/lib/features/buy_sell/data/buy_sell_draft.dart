import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const buySellDraftPreferenceKey = 'buy_sell.draft.v1';
const _buySellDraftSchemaVersion = 1;
const buySellMandatoryCopy =
    'Esta preparacion no certifica el estado juridico, mecanico o tributario del vehiculo.';

enum BuySellMode {
  buy('buy', 'Comprar'),
  sell('sell', 'Vender');

  const BuySellMode(this.value, this.label);

  final String value;
  final String label;

  static BuySellMode? tryFromValue(String value) {
    return switch (value) {
      'buy' => BuySellMode.buy,
      'sell' => BuySellMode.sell,
      _ => null,
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
      'version': _buySellDraftSchemaVersion,
      'mode': mode.value,
      'candidatePlate': candidatePlate.trim(),
      'city': city.trim(),
      'notes': notes.trim(),
      'checkedItems': checkedItems.toList()..sort(),
    });
  }

  static BuySellDraft fromJsonString(String source) {
    final data = jsonDecode(source);
    if (data is! Map) {
      throw const FormatException('Buy/sell draft must be an object.');
    }
    final version = data['version'];
    if (version != _buySellDraftSchemaVersion) {
      throw const FormatException('Unsupported buy/sell draft version.');
    }
    final modeValue = data['mode'];
    if (modeValue is! String) {
      throw const FormatException('Buy/sell draft mode must be a string.');
    }
    final mode = BuySellMode.tryFromValue(modeValue);
    if (mode == null) {
      throw const FormatException('Unsupported buy/sell draft mode.');
    }
    final candidatePlate = data['candidatePlate'];
    final city = data['city'];
    final notes = data['notes'];
    final checked = data['checkedItems'];
    if (candidatePlate is! String ||
        city is! String ||
        notes is! String ||
        checked is! List) {
      throw const FormatException('Invalid buy/sell draft field type.');
    }
    final checkedItems = <String>{};
    for (final item in checked) {
      if (item is! String) {
        throw const FormatException('Invalid buy/sell draft checklist item.');
      }
      checkedItems.add(item);
    }
    return BuySellDraft(
      mode: mode,
      candidatePlate: candidatePlate,
      city: city,
      notes: notes,
      checkedItems: checkedItems,
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
    await preferences.remove(buySellDraftPreferenceKey);
    return null;
  } on TypeError {
    await preferences.remove(buySellDraftPreferenceKey);
    return null;
  }
}

Future<void> saveBuySellDraft(AppPreferences preferences, BuySellDraft draft) {
  return preferences.setString(buySellDraftPreferenceKey, draft.toJsonString());
}

Future<void> deleteBuySellDraft(AppPreferences preferences) {
  return preferences.remove(buySellDraftPreferenceKey);
}
