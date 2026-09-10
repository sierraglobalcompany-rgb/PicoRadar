import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';

import '../../features/home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(loadV01bTestFont);
  final avatars = AvatarCatalog.fromJson(
    jsonDecode(File(avatarCatalogAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );
  final vehicles = VehicleVisualCatalog.fromJson(
    jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
        as Map<String, Object?>,
  );
  final chosenAvatar = avatars.items.firstWhere(
    (item) => item.id != avatars.defaultId,
  );
  final compatibleVehicles = vehicles.items
      .where((item) => item.kind == 'car' && item.serviceType == 'private')
      .toList();
  final chosenVehicle = compatibleVehicles[1];
  final vehicle = VehicleProfile(
    id: 'startup-visual-car',
    plate: 'ABC123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  for (final (scale, baselineHeight) in [
    (1.0, 96.0),
    (1.5, 124.0),
    (2.0, 140.0),
  ]) {
    testWidgets(
      'resolved compact banner retains baseline height $baselineHeight at scale $scale',
      (tester) async {
        const campaign = HomeBannerCampaign(
          kind: HomeBannerKind.house,
          enabled: true,
          priority: 1,
          id: 'compact-house',
          label: 'PicoRadar',
          title: 'Tu vehiculo',
          subtitle: 'Al dia',
          ctaText: '',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeBannerCampaignProvider.overrideWith((ref) async => campaign),
            ],
            child: _surface(
              scale,
              const SizedBox(width: 328, child: HomeBannerSlot()),
            ),
          ),
        );
        await _settleData(tester);
        expect(find.text(campaign.title), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('home-bottom-banner-slot')))
              .height,
          baselineHeight,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'avatar catalog pending preserves its 48dp slot at scale $scale',
      (tester) async {
        final pending = Completer<AvatarCatalog>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              avatarCatalogProvider.overrideWith((ref) => pending.future),
              selectedAvatarIdProvider.overrideWith(
                (ref) async => chosenAvatar.id,
              ),
            ],
            child: _surface(scale, const HomeAvatarButton()),
          ),
        );
        final before = tester.getRect(find.byType(HomeAvatarButton));
        pending.complete(avatars);
        await _settleData(tester);
        final after = tester.getRect(find.byType(HomeAvatarButton));
        expect(before.size, const Size(48, 48));
        expect(after, before);
        expect(
          find.byKey(ValueKey('home-avatar-image-${chosenAvatar.id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pending avatar selection never renders default as configured at scale $scale',
      (tester) async {
        final pending = Completer<String?>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              avatarCatalogProvider.overrideWith((ref) async => avatars),
              selectedAvatarIdProvider.overrideWith((ref) => pending.future),
            ],
            child: _surface(scale, const HomeAvatarButton()),
          ),
        );
        await _settleData(tester);
        final before = tester.getRect(find.byType(HomeAvatarButton));
        final showedDefault = find
            .byKey(ValueKey('home-avatar-image-${avatars.defaultId}'))
            .evaluate()
            .isNotEmpty;
        pending.complete(chosenAvatar.id);
        await _settleData(tester);
        expect(showedDefault, isFalse);
        expect(tester.getRect(find.byType(HomeAvatarButton)), before);
        expect(
          find.byKey(ValueKey('home-avatar-image-${chosenAvatar.id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pending vehicle override keeps neutral fixed slot at scale $scale',
      (tester) async {
        final pending = Completer<String?>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vehicleVisualCatalogProvider.overrideWith(
                (ref) async => vehicles,
              ),
              vehicleVisualOverrideProvider(vehicle.id)
                  .overrideWith((ref) => pending.future),
            ],
            child: _surface(
              scale,
              SizedBox(
                width: 220,
                height: 124,
                child: VehicleVisualImage(
                  vehicle: vehicle,
                  fallbackBuilder: (_) =>
                      const SizedBox.expand(key: ValueKey('generic-vehicle')),
                ),
              ),
            ),
          ),
        );
        await _settleData(tester);
        final before = tester.getRect(find.byType(VehicleVisualImage));
        final showedImage = find
            .descendant(
              of: find.byType(VehicleVisualImage),
              matching: find.byType(Image),
            )
            .evaluate()
            .isNotEmpty;
        final showedGeneric = find
            .byKey(const ValueKey('generic-vehicle'))
            .evaluate()
            .isNotEmpty;
        pending.complete(chosenVehicle.id);
        await _settleData(tester);
        expect(showedImage, isFalse);
        expect(showedGeneric, isFalse);
        expect(tester.getRect(find.byType(VehicleVisualImage)), before);
        final image = tester.widget<Image>(
          find.byKey(ValueKey('vehicle-visual-image-${vehicle.id}')),
        );
        final resized = image.image as ResizeImage;
        expect(
          (resized.imageProvider as AssetImage).assetName,
          chosenVehicle.asset,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'deferred banner reserves baseline minimum without inflating resolved content at scale $scale',
      (tester) async {
        final pending = Completer<HomeBannerCampaign?>();
        const campaign = HomeBannerCampaign(
          kind: HomeBannerKind.house,
          enabled: true,
          priority: 1,
          id: 'startup-house',
          label: 'PicoRadar',
          title: 'Tu vehiculo, al dia',
          subtitle: 'Consulta tus recordatorios y documentos.',
          ctaText: 'Ver opciones',
          targetUrl: 'https://picoradar.co/demo/home-ally',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeBannerCampaignProvider.overrideWith((ref) => pending.future),
            ],
            child: _surface(
              scale,
              const SizedBox(width: 328, child: HomeBannerSlot()),
            ),
          ),
        );
        final slot = find.byKey(const ValueKey('home-bottom-banner-slot'));
        final before = tester.getRect(slot);
        expect(find.text(campaign.title), findsNothing);
        pending.complete(campaign);
        await _settleData(tester);
        final after = tester.getRect(slot);
        final baselineHeight = scale == 1 ? 96.0 : 140.0;
        expect(before.height, baselineHeight);
        expect(after.width, before.width);
        final contentConstraint = tester.widget<ConstrainedBox>(
          find
              .descendant(
                of: find.byKey(const ValueKey('home-bottom-banner')),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(contentConstraint.constraints.minHeight, baselineHeight);
        expect(find.text(campaign.title), findsOneWidget);
        expect(find.text(campaign.subtitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _surface(double scale, Widget child) => MaterialApp(
  theme: buildPicoRadarTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Future<void> _settleData(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
