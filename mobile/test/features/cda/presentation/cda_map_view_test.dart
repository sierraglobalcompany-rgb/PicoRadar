import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/presentation/cda_map_view.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../domain/cda_spatial_query_test.dart'
    show fictionalCatalog, fictionalEntry, fictionalGeography;

void main() {
  testWidgets(
    'explore starts nationally without GPS, and preserves map across list',
    (tester) async {
      final gateway = _Location();
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();
      expect(gateway.calls, 0);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      expect(
        controller.camera.visibleBounds.contains(const LatLng(12.58, -81.7)),
        isTrue,
      );
      expect(find.byKey(const ValueKey('cda-selected')), findsNothing);
      await tester.tap(find.byTooltip('Ver lista'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cda-results')), findsOneWidget);
      await tester.tap(find.byTooltip('Ver mapa'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(controller),
      );
      expect(gateway.calls, 0);
    },
  );

  testWidgets('near me opens the map and list keeps local distance context', (
    tester,
  ) async {
    final gateway = _Location();
    await tester.pumpWidget(_app(gateway, nearMe: true));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('cda-results')), findsNothing);
    expect(find.byKey(const ValueKey('cda-attribution')), findsOneWidget);
    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cda-results')), findsOneWidget);
    expect(find.textContaining('15 km'), findsOneWidget);
    expect(find.textContaining('20 m'), findsOneWidget);
    expect(find.byKey(const ValueKey('cda-attribution')), findsNothing);
    expect(gateway.positions, 1);
  });

  testWidgets('search is a sheet and manual input never requests GPS', (
    tester,
  ) async {
    final gateway = _Location();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Buscar CDA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cda-search-input')),
      'Villa Clara',
    );
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Villa Clara'), findsWidgets);
    expect(gateway.calls, 0);
  });

  testWidgets(
    'denial is recoverable and late location cannot overwrite manual search',
    (tester) async {
      final gateway = _Location()
        ..permission = DeviceLocationPermission.deniedForever;
      await tester.pumpWidget(_app(gateway, nearMe: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('permiso'), findsOneWidget);
      expect(find.byTooltip('Reintentar ubicaci\u00f3n'), findsOneWidget);
      gateway.permission = DeviceLocationPermission.granted;
      gateway.pending = Completer<DeviceLocationResult>();
      await tester.tap(find.byTooltip('Reintentar ubicaci\u00f3n'));
      await tester.pump();
      await tester.tap(find.byTooltip('Buscar CDA'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cda-search-input')),
        'Villa Clara',
      );
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      gateway.pending!.complete(
        const DeviceLocationSuccess(
          DeviceLocationPoint(latitude: 4, longitude: -74, accuracyMeters: 999),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('999 m'), findsNothing);
      expect(find.textContaining('15 km'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposal while locating ignores completion', (tester) async {
    final gateway = _Location()..pending = Completer<DeviceLocationResult>();
    await tester.pumpWidget(_app(gateway, nearMe: true));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gateway.pending!.complete(
      const DeviceLocationSuccess(
        DeviceLocationPoint(latitude: 4, longitude: -74, accuracyMeters: 20),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all coincident members are reachable and callbacks preserve identity',
    (tester) async {
      final entries = List.generate(
        90,
        (i) => fictionalEntry(i.toString().padLeft(2, '0')),
      );
      CdaCatalogEntry? opened;
      await tester.pumpWidget(
        _app(_Location(), entries: entries, onOpen: (entry) => opened = entry),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cda-group-00')));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('cda-group-members'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cda-member-89')),
        500,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('cda-member-89')));
      await tester.pumpAndSettle();
      expect(opened, same(entries[89]));
    },
  );

  testWidgets(
    'tile factory is feature scoped and attribution opens externally',
    (tester) async {
      final launcher = _Launcher();
      await tester.pumpWidget(_app(_Location(), launcher: launcher));
      await tester.pumpAndSettle();
      final tile = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        tile.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(
        tile.tileProvider.headers['User-Agent'],
        contains('co.picoradar.app.cda'),
      );
      final attribution = find.byKey(const ValueKey('cda-attribution'));
      expect(tester.getSize(attribution).height, greaterThanOrEqualTo(48));
      await tester.tap(attribution);
      await tester.pumpAndSettle();
      expect(launcher.uri, 'https://www.openstreetmap.org/copyright');
    },
  );

  testWidgets('compact scaled layout keeps controls out of the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_Location(), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final header = tester.getRect(
      find.byKey(const ValueKey('cda-map-toolbar')),
    );
    final zoom = tester.getRect(find.byTooltip('Acercar'));
    expect(zoom.top, greaterThanOrEqualTo(header.bottom));
    expect(zoom.size, const Size(48, 48));
  });
}

Widget _app(
  _Location gateway, {
  bool nearMe = false,
  double scale = 1,
  List<CdaCatalogEntry>? entries,
  ValueChanged<CdaCatalogEntry>? onOpen,
  _Launcher? launcher,
}) {
  final inventory = entries ?? [fictionalEntry('one')];
  return ProviderScope(
    overrides: [
      deviceLocationGatewayProvider.overrideWithValue(gateway),
      cdaTileProviderFactory.overrideWithValue(() => _Tiles()),
      externalLauncherProvider.overrideWithValue(launcher ?? _Launcher()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Explorar mapa')),
        body: CdaMapView(
          catalog: fictionalCatalog(inventory),
          geography: fictionalGeography(inventory),
          nearMe: nearMe,
          now: DateTime.utc(2026, 9, 14),
          onOpen: onOpen ?? (_) {},
        ),
      ),
    ),
  );
}

class _Location implements DeviceLocationGateway {
  int calls = 0, positions = 0;
  DeviceLocationPermission permission = DeviceLocationPermission.granted;
  Completer<DeviceLocationResult>? pending;
  @override
  Future<bool> isLocationServiceEnabled() async {
    calls++;
    return true;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    calls++;
    return permission;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    calls++;
    return permission;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    calls++;
    positions++;
    return pending == null
        ? const DeviceLocationSuccess(
            DeviceLocationPoint(
              latitude: 4,
              longitude: -74,
              accuracyMeters: 20,
            ),
          )
        : await pending!.future;
  }

  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
}

class _Launcher implements ExternalLauncher {
  String? uri;
  @override
  Future<bool> openExternal(String uri) async {
    this.uri = uri;
    return true;
  }

  @override
  Future<bool> callPhone(String phone) async => false;
}
