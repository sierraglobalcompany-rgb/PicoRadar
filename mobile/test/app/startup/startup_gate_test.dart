import 'dart:async';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';

import '../../test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory walletCache;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() {
    walletCache = Directory.systemTemp.createTempSync('picoradar-startup-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') return walletCache.path;
          throw MissingPluginException('Unexpected path lookup: ${call.method}');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await walletCache.delete(recursive: true);
  });

  testWidgets('explicit retry clears a cached transient privacy failure', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        overrides: [
          startupPrivacyCleanupProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('test-private-cleanup-failure');
          }),
          startupReadinessProvider.overrideWith((ref) async {
            await ref.watch(startupPrivacyCleanupProvider.future);
            return const StartupReadiness(
              imageAssets: [],
              vehicleCount: 0,
              selectedJurisdictionId: null,
            );
          }),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-error')), findsOneWidget);
    expect(find.text('Home ready'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('startup-retry')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(attempts, 2);
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-error')), findsNothing);
  });

  test('private cleanup completes before core loading', () async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final gateway = _StartupTestDocumentGateway();
    gateway.release = Completer<void>();
    var coreReads = 0;
    final stop = StateError('test-core-stop');
    final container = ProviderContainer(
      overrides: [
        privateVehicleDocumentStoreProvider.overrideWithValue(
          harness.documentStore,
        ),
        vehicleDocumentGatewayProvider.overrideWithValue(gateway),
        bundledRestrictionsProvider.overrideWith((ref) {
          coreReads++;
          throw stop;
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(startupReadinessProvider, (_, _) {});
    addTearDown(subscription.close);
    final completion = expectLater(
      container.read(startupReadinessProvider.future),
      throwsA(same(stop)),
    );
    await gateway.entered.future;
    expect(coreReads, 0);
    gateway.release!.complete();
    await completion;
    expect(coreReads, 1);
  });

  testWidgets('secondary work starts only after child paint, once', (
    tester,
  ) async {
    var painted = false;
    var starts = 0;
    final readiness = Completer<StartupReadiness>();
    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith((ref) => readiness.future),
        ],
        child: CustomPaint(painter: _PaintProbe(() => painted = true)),
        onFirstContentFrame: () {
          expect(painted, isTrue);
          starts++;
        },
      ),
    );
    expect(starts, 0);
    readiness.complete(
      const StartupReadiness(
        imageAssets: [],
        vehicleCount: 0,
        selectedJurisdictionId: null,
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(starts, 1);
  });

  testWidgets('content marker follows child paint once, never during loading', (
    tester,
  ) async {
    final messages = <String>[];
    var painted = false;
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message?.contains('STARTUP_CONTENT_FRAME') ?? false) {
        expect(painted, isTrue);
      }
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previous);
    final readiness = Completer<StartupReadiness>();
    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith((ref) => readiness.future),
        ],
        child: CustomPaint(painter: _PaintProbe(() => painted = true)),
      ),
    );
    expect(painted, isFalse);
    expect(
      messages.where((line) => line.contains('STARTUP_CONTENT_FRAME')),
      isEmpty,
    );
    readiness.complete(
      const StartupReadiness(
        imageAssets: [],
        vehicleCount: 0,
        selectedJurisdictionId: null,
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(painted, isTrue);
    expect(
      messages.where((line) => line.contains('STARTUP_CONTENT_FRAME')),
      hasLength(1),
    );
    await tester.pump();
    expect(
      messages.where((line) => line.contains('STARTUP_CONTENT_FRAME')),
      hasLength(1),
    );
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE_FRAME')),
      isEmpty,
    );
    debugPrint = previous;
  });

  testWidgets('Home raster marker matches the rendered frame and detaches', (
    tester,
  ) async {
    final messages = <String>[];
    var frameNumber = 41;
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previous);
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
        isHomeRoute: () => true,
        frameNumberForTesting: () => frameNumber,
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final rendered = messages.singleWhere(
      (line) => line.contains('HOME_FIRST_USABLE_FRAME'),
    );
    final start = int.parse(
      RegExp(r'frame_target_us=(\d+)').firstMatch(rendered)!.group(1)!,
    );
    final report = tester.binding.platformDispatcher.onReportTimings!;
    report([_frameAt(start, frameNumber: 40)]);
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE_RASTER')),
      isEmpty,
    );
    // The frame ID, not equality with the framework's raw timestamp, identifies it.
    report([_frameAt(start + 1000, frameNumber: 41)]);
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE_RASTER')),
      hasLength(1),
    );
    report([_frameAt(start + 1, frameNumber: 42)]);
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE_RASTER')),
      hasLength(1),
    );
    frameNumber = 42;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(
      messages.where((line) => line.contains('HOME_RESUME_FRAME')),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final resumed = messages.singleWhere(
      (line) => line.contains('HOME_RESUME_FRAME'),
    );
    final resumeStart = int.parse(
      RegExp(r'frame_target_us=(\d+)').firstMatch(resumed)!.group(1)!,
    );
    tester.binding.platformDispatcher.onReportTimings!([
      _frameAt(resumeStart, frameNumber: 43),
    ]);
    expect(
      messages.where((line) => line.contains('HOME_RESUME_RASTER')),
      isEmpty,
    );
    expect(
      messages.where(
        (line) => line.contains('STARTUP_CONTENT_TIMING_UNAVAILABLE'),
      ),
      hasLength(1),
    );
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE_FRAME')),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    debugPrint = previous;
  });

  testWidgets('dispose before readiness never emits a usable frame', (
    tester,
  ) async {
    final messages = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previous);
    final readiness = Completer<StartupReadiness>();
    await tester.pumpWidget(
      _app(
        overrides: [
          startupReadinessProvider.overrideWith((ref) => readiness.future),
        ],
        isHomeRoute: () => true,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    readiness.complete(
      const StartupReadiness(
        imageAssets: [],
        vehicleCount: 0,
        selectedJurisdictionId: null,
      ),
    );
    await tester.pump();
    expect(
      messages.where((line) => line.contains('HOME_FIRST_USABLE')),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    debugPrint = previous;
  });

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

    final subscription = container.listen(startupReadinessProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(startupReadinessProvider.future);

    expect(await viewFile.exists(), isFalse);
  });

  test(
    'secondary data cannot block core and core refresh does not repurge',
    () async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      final gateway = _StartupTestDocumentGateway();
      var secondaryReads = 0;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(harness.database),
          appPreferencesProvider.overrideWithValue(harness.preferences),
          privateVehicleDocumentStoreProvider.overrideWithValue(
            harness.documentStore,
          ),
          vehicleDocumentGatewayProvider.overrideWithValue(gateway),
          avatarCatalogProvider.overrideWith(
            (ref) => Completer<Never>().future,
          ),
          vehicleVisualCatalogProvider.overrideWith(
            (ref) => Completer<Never>().future,
          ),
          homeBannerConfigProvider.overrideWith((ref) {
            secondaryReads++;
            throw StateError('secondary config unavailable');
          }),
          homeBannerCampaignProvider.overrideWith((ref) {
            secondaryReads++;
            throw StateError('secondary campaign unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        startupReadinessProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final first = await container.read(startupReadinessProvider.future);
      expect(first.vehicleCount, 0);
      expect(first.imageAssets, isEmpty);
      expect(gateway.cleanups, 1);
      container.invalidate(startupReadinessProvider);
      await container.read(startupReadinessProvider.future);
      expect(gateway.cleanups, 1);
      expect(secondaryReads, 0);
    },
  );
}

class _PaintProbe extends CustomPainter {
  _PaintProbe(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}

class _StartupTestDocumentGateway implements VehicleDocumentGateway {
  int cleanups = 0;
  final entered = Completer<void>();
  Completer<void>? release;

  @override
  Future<void> clearTemporaryFiles() async {
    cleanups++;
    if (!entered.isCompleted) entered.complete();
    await release?.future;
  }

  @override
  Future<bool> openDocument(File file) async => true;

  @override
  Future<PickedVehicleDocument?> pickDocument() async => null;
}

Widget _app({
  required dynamic overrides,
  Widget child = const Text('Home ready'),
  bool Function()? isHomeRoute,
  VoidCallback? onFirstContentFrame,
  int Function()? frameNumberForTesting,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: StartupGate(
        isHomeRoute: isHomeRoute,
        onFirstContentFrame: onFirstContentFrame,
        frameNumberForTesting: frameNumberForTesting,
        child: child,
      ),
    ),
  );
}

FrameTiming _frameAt(int start, {int frameNumber = -1}) => FrameTiming(
  frameNumber: frameNumber,
  vsyncStart: start,
  buildStart: start + 25,
  buildFinish: start + 100,
  rasterStart: start + 200,
  rasterFinish: start + 300,
  rasterFinishWallTime: 1000000 + start,
);

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
