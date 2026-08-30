import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';

import '../../test_app_harness.dart';

void main() {
  testWidgets(
    'loading visual catalog uses stable placeholder, not generic fallback',
    (tester) async {
      final catalog = Completer<VehicleVisualCatalog>();
      final vehicle = VehicleProfile(
        id: 'vehicle-a',
        plate: 'ABC123',
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            vehicleVisualCatalogProvider.overrideWith((ref) => catalog.future),
          ],
          child: MaterialApp(
            home: SizedBox(
              width: 160,
              height: 96,
              child: VehicleVisualImage(
                vehicle: vehicle,
                fallbackBuilder: (_) =>
                    const SizedBox(key: ValueKey('generic-fallback')),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('vehicle-visual-loading-placeholder')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('generic-fallback')), findsNothing);

      catalog.complete(const VehicleVisualCatalog(items: []));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('generic-fallback')), findsOneWidget);
    },
  );
}
