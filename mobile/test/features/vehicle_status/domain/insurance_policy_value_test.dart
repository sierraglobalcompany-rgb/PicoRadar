import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/domain/insurance_policy_value.dart';

void main() {
  test('annual and monthly preserve the original minor units', () {
    final annual = InsurancePolicyValue(
      minorUnits: 120000000,
      period: InsuranceValuePeriod.annual,
    );
    expect(annual.roundedMinorUnitsFor(InsuranceValuePeriod.monthly), 10000000);
    final monthly = InsurancePolicyValue(
      minorUnits: 10000000,
      period: InsuranceValuePeriod.monthly,
    );
    expect(
      monthly.roundedMinorUnitsFor(InsuranceValuePeriod.annual),
      120000000,
    );
    expect(annual.formattedFor(InsuranceValuePeriod.annual), r'$1.200.000');
    expect(monthly.inputFor(InsuranceValuePeriod.monthly), '100000');
  });

  test('inexact division and repeated presentation never alter source', () {
    final value = InsurancePolicyValue(
      minorUnits: 10001,
      period: InsuranceValuePeriod.annual,
    );
    final original = value.toDetails();
    for (var i = 0; i < 50; i++) {
      expect(value.inputFor(InsuranceValuePeriod.monthly), '8,33');
      expect(value.inputFor(InsuranceValuePeriod.annual), '100,01');
    }
    expect(value.toDetails(), original);
    expect(InsurancePolicyValue.fromDetails(original)!.minorUnits, 10001);
    expect(
      InsurancePolicyValue(
        minorUnits: 6,
        period: InsuranceValuePeriod.annual,
      ).roundedMinorUnitsFor(InsuranceValuePeriod.monthly),
      1,
    );
  });

  test('Colombian amount parser accepts whole pesos and comma centavos', () {
    for (final input in ['1200000,50', '1.200.000,50', ' 1200000,50 ']) {
      expect(InsurancePolicyValue.parseMinorUnits(input), 120000050);
    }
    expect(InsurancePolicyValue.parseMinorUnits('0,01'), 1);
    expect(InsurancePolicyValue.parseMinorUnits('1.234'), 123400);
    expect(InsurancePolicyValue.parseMinorUnits('100,5'), 10050);
  });

  test('invalid values cannot become valid amounts silently', () {
    for (final input in [
      '',
      ' ',
      '0',
      '-1',
      '+1',
      '1e6',
      'NaN',
      '1,234',
      '12.34',
      '1..000',
      '1 000',
      r'$1.000',
      '999999999999999999999',
    ]) {
      expect(
        InsurancePolicyValue.parseMinorUnits(input),
        isNull,
        reason: input,
      );
    }
  });

  test(
    'details have one amount, period and currency; corrupt data is rejected',
    () {
      final value = InsurancePolicyValue(
        minorUnits: 54321,
        period: InsuranceValuePeriod.monthly,
      );
      expect(value.toDetails(), {
        'premiumMinorUnits': '54321',
        'premiumPeriod': 'monthly',
        'premiumCurrency': 'COP',
      });
      expect(
        InsurancePolicyValue.fromDetails({
          ...value.toDetails(),
          'unrelated': 'keep',
        })!.period,
        InsuranceValuePeriod.monthly,
      );
      for (final details in <Map<String, String>>[
        {},
        {...value.toDetails(), 'premiumCurrency': 'USD'},
        {...value.toDetails(), 'premiumPeriod': 'weekly'},
        {...value.toDetails(), 'premiumMinorUnits': '-1'},
        {...value.toDetails(), 'premiumMinorUnits': '0'},
        {...value.toDetails(), 'premiumMinorUnits': '5.25'},
        {...value.toDetails(), 'premiumMinorUnits': '999999999999999999999'},
      ]) {
        expect(InsurancePolicyValue.fromDetails(details), isNull);
      }
    },
  );

  test('maximum stored amount and its equivalent retain integer precision', () {
    final value = InsurancePolicyValue(
      minorUnits: InsurancePolicyValue.maxMinorUnits,
      period: InsuranceValuePeriod.monthly,
    );
    expect(
      value.roundedMinorUnitsFor(InsuranceValuePeriod.annual),
      InsurancePolicyValue.maxMinorUnits * 12,
    );
    expect(
      InsurancePolicyValue.fromDetails(value.toDetails())!.minorUnits,
      value.minorUnits,
    );
  });
}
