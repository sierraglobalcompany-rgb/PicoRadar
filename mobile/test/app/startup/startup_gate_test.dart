import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';

import '../../test_app_harness.dart';

void main() {
  testWidgets('shows branded loader until readiness completes', (tester) async {
    final readiness = Completer<StartupReadiness>();

    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith((ref) => readiness.future),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('startup-loader')), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-loader-copy')), findsOneWidget);
    expect(find.text('Preparando PicoRadar'), findsOneWidget);
    expect(find.text('Home ready'), findsNothing);

    readiness.complete(
      const StartupReadiness(
        imageAssets: [],
        vehicleCount: 0,
        selectedJurisdictionId: null,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-loader')), findsNothing);
  });

  testWidgets('error state offers retry instead of infinite loading', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith((ref) {
            attempts += 1;
            if (attempts == 1) {
              return Future<StartupReadiness>.error(StateError('boom'));
            }
            return Future.value(
              const StartupReadiness(
                imageAssets: [],
                vehicleCount: 0,
                selectedJurisdictionId: null,
              ),
            );
          }),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('startup-error')), findsOneWidget);
    expect(find.text('No pudimos preparar PicoRadar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('startup-retry')));
    for (var i = 0; i < 8; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(attempts, 2);
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-error')), findsNothing);
  });

  testWidgets('does not show full startup gate after normal child rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith(
            (ref) async => const StartupReadiness(
              imageAssets: [],
              vehicleCount: 0,
              selectedJurisdictionId: null,
            ),
          ),
        ],
        child: const _RebuildableHome(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('startup-loader')), findsNothing);
    expect(find.text('count 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('increment-home')));
    await tester.pump();

    expect(find.text('count 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-loader')), findsNothing);
  });

  test('startup readiness purges stale plaintext viewer cache', () async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final source = File('${harness.documentRoot.path}/stale-soat.pdf');
    await source.writeAsBytes([0x25, 0x50, 0x44, 0x46]);
    final metadata = await harness.documentStore.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.soat,
      source: source,
      originalName: 'stale-soat.pdf',
      mimeType: 'application/pdf',
    );
    final viewFile = await harness.documentStore.decryptForView(metadata);
    expect(await viewFile.exists(), isTrue);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        privateVehicleDocumentStoreProvider.overrideWithValue(
          harness.documentStore,
        ),
        vehicleDocumentGatewayProvider.overrideWithValue(
          _StartupTestDocumentGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(startupReadinessProvider.future);

    expect(await viewFile.exists(), isFalse);
  });
}

class _StartupTestDocumentGateway implements VehicleDocumentGateway {
  @override
  Future<void> clearTemporaryFiles() async {}

  @override
  Future<bool> openDocument(File file) async => true;

  @override
  Future<PickedVehicleDocument?> pickDocument() async => null;
}

Widget _app({
  required dynamic overrides,
  Widget child = const Text('Home ready'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: StartupGate(child: child)),
  );
}

class _RebuildableHome extends StatefulWidget {
  const _RebuildableHome();

  @override
  State<_RebuildableHome> createState() => _RebuildableHomeState();
}

class _RebuildableHomeState extends State<_RebuildableHome> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('increment-home'),
      onPressed: () => setState(() => count += 1),
      child: Text('count $count'),
    );
  }
}
