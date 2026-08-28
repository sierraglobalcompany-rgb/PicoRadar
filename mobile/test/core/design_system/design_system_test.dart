import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/core/design_system/app_components.dart';

void main() {
  test('R01 spacing includes approved 3XL token', () {
    expect(AppSpacing.xxxl, 48);
  });

  test('R01 radii stay inside approved product ranges', () {
    expect(AppRadius.card, inInclusiveRange(20, 24));
    expect(AppRadius.button, inInclusiveRange(20, 24));
    expect(AppRadius.modal, inInclusiveRange(24, 28));
    expect(AppRadius.input, inInclusiveRange(16, 20));
    expect(AppRadius.chip, greaterThan(100));
  });

  test('R01 typography follows the baseline scale', () {
    expect(AppTextStyles.display.fontSize, inInclusiveRange(32, 40));
    expect(AppTextStyles.display.fontWeight, FontWeight.w700);
    expect(AppTextStyles.h1.fontSize, inInclusiveRange(24, 28));
    expect(AppTextStyles.h2.fontSize, inInclusiveRange(18, 22));
    expect(AppTextStyles.body.fontSize, inInclusiveRange(15, 17));
    expect(AppTextStyles.caption.fontSize, inInclusiveRange(12, 14));
  });

  test('R01-FIX motion tokens match the approved baseline', () {
    expect(AppMotion.microPress, const Duration(milliseconds: 110));
    expect(AppMotion.fade, const Duration(milliseconds: 180));
    expect(AppMotion.navBounce, const Duration(milliseconds: 220));
    expect(AppMotion.carouselSnap, const Duration(milliseconds: 300));
    expect(AppMotion.restrictedPulse, const Duration(milliseconds: 1700));
    expect(AppMotion.standardCurve, Curves.easeOutCubic);
    expect(AppMotion.springCurve, Curves.easeOutBack);
  });

  test('R01 keeps the approved route order unchanged', () {
    expect(AppTab.values.map((tab) => tab.route.path), [
      '/home',
      '/garage',
      '/apps',
      '/trip',
      '/drive',
    ]);
  });

  testWidgets('AppBottomNav has five tabs with Apps in the center', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
    );

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Garaje'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Conducir'), findsOneWidget);
    expect(_destinations[2].label, 'Apps');
    expect(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
      findsOneWidget,
    );
  });

  testWidgets('AppBottomNav Apps uses the elevated center affordance', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
    );

    final center = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
    );
    final centerBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('app-bottom-nav-apps-center')),
    );
    final decoration = center.decoration! as BoxDecoration;

    expect(centerBox.size.width, greaterThanOrEqualTo(56));
    expect(centerBox.size.height, greaterThanOrEqualTo(56));
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, AppColors.teal);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('AppBottomNav exposes selected and unselected semantics', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (_) {},
      ),
    );

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    final selected = semantics.singleWhere(
      (widget) => widget.properties.label == 'Inicio',
    );
    final unselected = semantics.singleWhere(
      (widget) => widget.properties.label == 'Garaje',
    );

    expect(selected.properties.label, 'Inicio');
    expect(selected.properties.button, isTrue);
    expect(selected.properties.selected, isTrue);
    expect(unselected.properties.label, 'Garaje');
    expect(unselected.properties.button, isTrue);
    expect(unselected.properties.selected, isFalse);
  });

  testWidgets('AppBottomNav press calls onSelect and settles animation', (
    tester,
  ) async {
    var selectedIndex = 0;
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (index) => selectedIndex = index,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pump(AppMotion.navBounce);
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppBottomNav updates selected state after tab change', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPicoRadarTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppBottomNav(
                destinations: _destinations,
                currentIndex: selectedIndex,
                onSelect: (index) => setState(() => selectedIndex = index),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    final garage = semantics.singleWhere(
      (widget) => widget.properties.label == 'Garaje',
    );
    expect(garage.properties.selected, isTrue);
  });

  testWidgets('AppBottomNav disables bounce transforms for reduced motion', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
      disableAnimations: true,
    );

    expect(
      find.byKey(const ValueKey('app-bottom-nav-motion-transform')),
      findsNothing,
    );
  });

  testWidgets('AppBottomNav touch targets are at least 48 dp tall', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 0,
        onSelect: (_) {},
      ),
    );

    final itemBox = tester.renderObject<RenderBox>(find.text('Inicio'));
    final navBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('app-bottom-navigation')),
    );

    expect(itemBox.size.height, greaterThan(0));
    expect(navBox.size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('AppBottomNav remains stable at 360dp and text scale 2', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
      size: const Size(360, 800),
      textScale: 2,
    );

    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PicoRadar brand lockup is local and keeps brand text', (
    tester,
  ) async {
    await _pumpComponent(tester, const PicoRadarBrandLockup());

    expect(find.text('PicoRadar'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      File('lib/app/app.dart').readAsStringSync(),
      contains("title: 'PicoRadar'"),
    );
  });

  testWidgets('ColombianPlateBadge renders common plate formats', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColombianPlateBadge(plate: 'ABC123'),
          ColombianPlateBadge(plate: 'XYZ789'),
          ColombianPlateBadge(plate: 'ABC12D'),
        ],
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ789'), findsOneWidget);
    expect(find.text('ABC12D'), findsOneWidget);
  });

  testWidgets('ColombianPlateBadge handles larger text scales', (tester) async {
    for (final textScale in [1.5, 2.0]) {
      await _pumpComponent(
        tester,
        const ColombianPlateBadge(plate: 'ABC1234', compact: true),
        textScale: textScale,
      );
      expect(find.text('ABC1234'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('R01-FIX Android launcher resources exist', () {
    final expectedPaths = [
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png',
      'android/app/src/main/res/drawable/ic_launcher_foreground.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      'android/app/src/main/res/values/colors.xml',
    ];

    for (final path in expectedPaths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  testWidgets(
    'StatusCard renders success, warning, danger and neutral states',
    (tester) async {
      await _pumpComponent(
        tester,
        const Column(
          children: [
            StatusCard(
              title: 'Al dia',
              message: 'Puedes conducir.',
              tone: StatusTone.success,
            ),
            StatusCard(
              title: 'Preventivo',
              message: 'Revisa tu horario.',
              tone: StatusTone.warning,
            ),
            StatusCard(
              title: 'Critico',
              message: 'No conduzcas ahora.',
              tone: StatusTone.danger,
            ),
            StatusCard(
              title: 'Informativo',
              message: 'Consulta local disponible.',
              tone: StatusTone.neutral,
            ),
          ],
        ),
      );

      expect(find.text('Al dia'), findsOneWidget);
      expect(find.text('Preventivo'), findsOneWidget);
      expect(find.text('Critico'), findsOneWidget);
      expect(find.text('Informativo'), findsOneWidget);
    },
  );

  testWidgets('VehicleCard renders active and inactive states', (tester) async {
    await _pumpComponent(
      tester,
      const Column(
        children: [
          VehicleCard(plate: 'ABC123', kindLabel: 'Carro', active: true),
          VehicleCard(plate: 'XYZ789', kindLabel: 'Moto', active: false),
        ],
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('XYZ789'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
  });

  testWidgets('DocumentExpiryCard renders document state content', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      const DocumentExpiryCard(
        title: 'SOAT',
        expiryLabel: 'Vence en 20 dias',
        tone: StatusTone.warning,
      ),
    );

    expect(find.text('SOAT'), findsOneWidget);
    expect(find.text('Vence en 20 dias'), findsOneWidget);
  });

  testWidgets('AppLauncherTile accepts a two-line label', (tester) async {
    await _pumpComponent(
      tester,
      SizedBox(
        width: 112,
        child: AppLauncherTile(
          title: 'Seguro\ny asistencia',
          icon: Icons.health_and_safety_outlined,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Seguro\ny asistencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLauncherTile avoids overflow at high text scale', (
    tester,
  ) async {
    await _pumpShowcase(tester, size: const Size(360, 800), textScale: 2);

    expect(find.byKey(const ValueKey('launcher-grid-360')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState CTA stays actionable', (tester) async {
    var tapped = false;
    await _pumpComponent(
      tester,
      EmptyState(
        title: 'Sin vehiculos',
        message: 'Agrega tu primer vehiculo.',
        actionLabel: 'Agregar',
        onActionPressed: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Agregar'));

    expect(tapped, isTrue);
  });

  testWidgets('DrivingSurface provides the future dark driving surface', (
    tester,
  ) async {
    await _pumpComponent(tester, const DrivingSurface(child: Text('Conducir')));

    final box = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('driving-surface')),
    );
    expect(box.color, const Color(0xFF07131F));
  });

  testWidgets('R01 visual gate renders required viewport and scale variants', (
    tester,
  ) async {
    final variants = [
      (size: const Size(390, 844), textScale: 1.0),
      (size: const Size(360, 800), textScale: 1.0),
      (size: const Size(412, 915), textScale: 1.0),
      (size: const Size(390, 844), textScale: 1.5),
      (size: const Size(390, 844), textScale: 2.0),
    ];

    for (final variant in variants) {
      await _pumpShowcase(
        tester,
        size: variant.size,
        textScale: variant.textScale,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('R01 theme exposes PicoRadar light colors', (tester) async {
    await _pumpComponent(tester, const SizedBox.shrink());

    final theme = Theme.of(tester.element(find.byType(SizedBox)));
    expect(theme.colorScheme.primary, AppColors.teal);
    expect(theme.colorScheme.secondary, AppColors.blue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  testWidgets('PrimaryButton minimum touch target is at least 48 dp', (
    tester,
  ) async {
    await _pumpComponent(
      tester,
      PrimaryButton(
        key: const ValueKey('primary-touch-target'),
        label: 'Continuar',
        onPressed: () {},
      ),
    );

    final buttonBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('primary-touch-target')),
    );

    expect(buttonBox.size.height, greaterThanOrEqualTo(48));
  });
}

Future<void> _pumpComponent(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildPicoRadarTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          accessibleNavigation: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpShowcase(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildPicoRadarTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const PicoSurface(child: _DesignSystemShowcase()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _destinations = [
  AppBottomNavDestination(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    color: AppColors.teal,
    keyName: 'home',
  ),
  AppBottomNavDestination(
    label: 'Garaje',
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car,
    color: AppColors.blue,
    keyName: 'garage',
  ),
  AppBottomNavDestination(
    label: 'Apps',
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    color: AppColors.navy,
    keyName: 'apps',
  ),
  AppBottomNavDestination(
    label: 'Viaje',
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
    color: AppColors.orange,
    keyName: 'trip',
  ),
  AppBottomNavDestination(
    label: 'Conducir',
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    color: AppColors.red,
    keyName: 'drive',
  ),
];

class _DesignSystemShowcase extends StatelessWidget {
  const _DesignSystemShowcase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        destinations: _destinations,
        currentIndex: 2,
        onSelect: (_) {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(
              title: 'PicoRadar',
              subtitle: 'Sistema visual base',
            ),
            const StatusCard(
              title: 'Listo para salir',
              message: 'Consulta local disponible sin cuenta.',
              tone: StatusTone.success,
            ),
            const SizedBox(height: AppSpacing.l),
            const VehicleCard(
              plate: 'ABC123',
              kindLabel: 'Carro particular',
              active: true,
            ),
            const SizedBox(height: AppSpacing.l),
            const DocumentExpiryCard(
              title: 'Tecnomecanica',
              expiryLabel: 'Vence en 30 dias',
              tone: StatusTone.warning,
            ),
            const SizedBox(height: AppSpacing.l),
            const Wrap(
              key: ValueKey('launcher-grid-360'),
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Seguro y asistencia',
                    icon: Icons.health_and_safety_outlined,
                    onTap: null,
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Comparendos',
                    icon: Icons.receipt_long_outlined,
                    onTap: null,
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: AppLauncherTile(
                    title: 'Parqueaderos',
                    icon: Icons.local_parking_outlined,
                    onTap: null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            EmptyState(
              title: 'Sin documentos',
              message: 'Agrega documentos cuando el lote lo habilite.',
              actionLabel: 'Entendido',
              onActionPressed: () {},
            ),
            const SizedBox(height: AppSpacing.l),
            const AppSkeleton(width: 180),
            const SizedBox(height: AppSpacing.l),
            const DrivingSurface(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Text('Superficie Conducir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
