import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_owner_content.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_quote_demo.dart';

void main() {
  test('F16 real compile configuration gates preview and quote together', () {
    const expected = bool.fromEnvironment('EXPECT_INSURANCE_DEMO');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(insurancePreviewProvider),
      expected,
      reason:
          'flavor=$appFlavor APP_ENV=${const String.fromEnvironment('APP_ENV')}',
    );
    expect(insuranceQuoteDemoAvailable, expected);
  });
}
