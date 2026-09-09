import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/toll_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TollInventoryRecord toll;
  late LocalTollPricingCharge charge;
  setUpAll(() async {
    final inventory = TollInventoryDataset.fromJsonString(
      await rootBundle.loadString(bundledTollInventoryAsset),
    );
    final catalog = await loadTollTariffCatalog(rootBundle);
    toll = inventory.records.firstWhere(
      (record) => record.id == 'INV-COCORNA-6A6F1282D1',
    );
    charge = priceExplicitTollPassages(
      catalog: catalog,
      passages: [toll],
      operatorCategoryCode: 'I',
    ).charges.single;
  });

  DrivingState initial() => DrivingState(
    status: DrivingSessionStatus.active,
    preferences: defaultDrivingPreferences.copyWith(
      tollAlertsEnabled: true,
      cameraVisualizationMode: CameraVisualizationMode.radar,
    ),
    cameraCount: 360,
    cameraSpeedKnownCount: 1,
    currentPoint: DrivingPoint(
      latitude: toll.latitude - .003,
      longitude: toll.longitude,
      accuracyMeters: 5,
      speedKmh: 80,
      headingDegrees: 0,
      recordedAt: DateTime.utc(2026, 9, 9),
    ),
    nearestToll: TollMatch(
      toll: toll,
      distanceMeters: 330,
      approaching: true,
      relativeBearingDegrees: 0,
      distanceDeltaMeters: 20,
    ),
    referenceCharge: charge,
    tollEpisodeKey: 'toll-episode-1',
    reliableHeadingDegrees: 0,
    simulationName: 'Peaje Cocorná',
  );

  Future<_UiController> mount(
    WidgetTester tester, {
    double width = 360,
    double scale = 1,
    DrivingState? value,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController(value ?? initial());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drivingControllerProvider.overrideWith(() => controller),
          externalLauncherProvider.overrideWithValue(_Launcher()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const DrivingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'toll readable at $width dp scale $scale and tariffs open while moving',
        (tester) async {
          await mount(tester, width: width, scale: scale);
          expect(
            find.byKey(const ValueKey('driving-toll-alert-panel')),
            findsOneWidget,
          );
          expect(find.textContaining('18.800'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('driving-camera-alert-panel')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const ValueKey('driving-toll-reference-price')),
          );
          await tester.tap(
            find.byKey(const ValueKey('driving-toll-reference-price')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('driving-toll-details')),
            findsOneWidget,
          );
          expect(find.text('Tarifas por categoría'), findsOneWidget);
          expect(find.text('Categoría VII'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'camera takes priority and closes toll details without stopping session',
    (tester) async {
      final controller = await mount(tester);
      await tester.tap(
        find.byKey(const ValueKey('driving-toll-reference-price')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('driving-toll-details')),
        findsOneWidget,
      );
      controller.publish(
        initial().copyWith(
          nearestCamera: const CameraMatch(
            camera: TrafficCamera(
              id: 'camera',
              department: 'ANTIOQUIA',
              municipality: 'MEDELLIN',
              jurisdiction: null,
              address: null,
              latitude: 6.244,
              longitude: -75.57,
              status: 'Aprobada',
              technology: 'Cámara',
              kind: CameraKind.mixed,
              speedLimitKmh: 60,
            ),
            distanceMeters: 200,
            approaching: true,
            bearingDifferenceDegrees: 0,
            relativeBearingDegrees: 0,
          ),
          cameraEpisodeKey: 'camera-episode',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('driving-toll-details')), findsNothing);
      expect(
        find.byKey(const ValueKey('driving-camera-alert-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-toll-alert-panel')),
        findsNothing,
      );
      expect(find.text('80'), findsOneWidget);
    },
  );

  testWidgets('turning tolls off closes the sheet without stopping driving', (
    tester,
  ) async {
    final controller = await mount(tester);
    await tester.tap(
      find.byKey(const ValueKey('driving-toll-reference-price')),
    );
    await tester.pumpAndSettle();
    controller.publish(
      initial().copyWith(
        preferences: initial().preferences.copyWith(tollAlertsEnabled: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('driving-toll-details')), findsNothing);
    expect(
      find.byKey(const ValueKey('driving-toll-alert-panel')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('stop-driving')), findsOneWidget);
  });

  testWidgets('toll dismissal removes its card and keeps current speed', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('driving-toll-dismiss')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('driving-toll-alert-panel')),
      findsNothing,
    );
    expect(find.text('80'), findsOneWidget);
  });
}

class _UiController extends DrivingController {
  _UiController(this.initial);
  final DrivingState initial;
  @override
  Future<DrivingState> build() async => initial;
  void publish(DrivingState value) => state = AsyncData(value);
  @override
  Future<void> dismissCurrentToll() async =>
      publish(state.requireValue.copyWith(clearNearestToll: true));
  @override
  Future<void> stop() async =>
      publish(state.requireValue.copyWith(status: DrivingSessionStatus.idle));
}

class _Launcher implements ExternalLauncher {
  @override
  Future<bool> callPhone(String phone) async => false;
  @override
  Future<bool> openExternal(String url) async => true;
}
