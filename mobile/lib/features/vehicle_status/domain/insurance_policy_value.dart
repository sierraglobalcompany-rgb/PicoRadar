import 'package:intl/intl.dart';

enum InsuranceValuePeriod { annual, monthly }

/// The user's original COP amount. Equivalents never replace its source.
class InsurancePolicyValue {
  InsurancePolicyValue({required this.minorUnits, required this.period}) {
    if (minorUnits <= 0 || minorUnits > maxMinorUnits) {
      throw ArgumentError.value(minorUnits, 'minorUnits', 'Invalid COP amount');
    }
  }

  static const maxMinorUnits = 99999999999999;
  static const detailKeys = {
    'premiumMinorUnits',
    'premiumPeriod',
    'premiumCurrency',
  };

  final int minorUnits;
  final InsuranceValuePeriod period;

  static InsurancePolicyValue? fromDetails(Map<String, String> details) {
    if (details['premiumCurrency'] != 'COP') return null;
    final raw = details['premiumMinorUnits'] ?? '';
    if (!RegExp(r'^\d{1,14}$').hasMatch(raw)) return null;
    final amount = int.tryParse(raw);
    final period = switch (details['premiumPeriod']) {
      'annual' => InsuranceValuePeriod.annual,
      'monthly' => InsuranceValuePeriod.monthly,
      _ => null,
    };
    if (amount == null ||
        amount <= 0 ||
        amount > maxMinorUnits ||
        period == null) {
      return null;
    }
    return InsurancePolicyValue(minorUnits: amount, period: period);
  }

  /// Colombian decimal comma and optional validated thousands groups.
  static int? parseMinorUnits(String input) {
    final raw = input.trim();
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$').hasMatch(raw)) {
      return null;
    }
    final parts = raw.replaceAll('.', '').split(',');
    final digits =
        '${parts[0]}${parts.length == 2 ? parts[1].padRight(2, '0') : '00'}';
    final amount = int.tryParse(digits);
    if (amount == null || amount <= 0 || amount > maxMinorUnits) return null;
    return amount;
  }

  Map<String, String> toDetails() => {
    'premiumMinorUnits': '$minorUnits',
    'premiumPeriod': period.name,
    'premiumCurrency': 'COP',
  };

  int roundedMinorUnitsFor(InsuranceValuePeriod target) {
    if (target == period) return minorUnits;
    if (target == InsuranceValuePeriod.annual) return minorUnits * 12;
    // Round half up for display only; all arithmetic remains integral.
    return (minorUnits + 6) ~/ 12;
  }

  String inputFor(InsuranceValuePeriod target) {
    final amount = roundedMinorUnitsFor(target);
    final cents = amount % 100;
    return '${amount ~/ 100}${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'}';
  }

  String formattedFor(InsuranceValuePeriod target) {
    final amount = roundedMinorUnitsFor(target);
    final whole = NumberFormat.decimalPattern('es_CO').format(amount ~/ 100);
    final cents = amount % 100;
    return '\$$whole${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'}';
  }
}
