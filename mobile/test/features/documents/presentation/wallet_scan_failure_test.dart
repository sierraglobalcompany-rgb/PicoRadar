import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/wallet_actions.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  testWidgets(
    'scanner failure permits retry then import with finite diagnostic',
    (tester) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      final scanner = _Scanner();
      final gateway = _Gateway();
      await harness.pump(
        tester,
        documentGateway: gateway,
        childOverride: ProviderScope(
          overrides: [walletPlatformProvider.overrideWithValue(scanner)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => WalletActions(context, ref).add(
                    const WalletOwner.driver('principal'),
                    WalletDocumentType.identityCard,
                    ownerLabel: 'Principal',
                  ),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear'));
      await tester.pumpAndSettle();
      expect(scanner.calls, 1);
      expect(find.textContaining('scanner_start_failed'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(scanner.calls, 2);
      await tester.tap(find.text('Importar archivo'));
      await tester.pumpAndSettle();
      expect(gateway.calls, 1);
      expect(find.text('Reintentar'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Scanner extends WalletPlatform {
  int calls = 0;
  @override
  Future<List<WalletCaptureFile>?> scan({int maxPages = 2}) async {
    calls++;
    throw const WalletPlatformException('scanner_start_failed');
  }

  @override
  Future<void> setSecure(bool enabled) async {}
}

class _Gateway implements VehicleDocumentGateway {
  int calls = 0;
  @override
  Future<PickedVehicleDocument?> pickDocument() async {
    calls++;
    return null;
  }

  @override
  Future<void> clearTemporaryFiles() async {}
  @override
  Future<bool> openDocument(File file) async => false;
}
