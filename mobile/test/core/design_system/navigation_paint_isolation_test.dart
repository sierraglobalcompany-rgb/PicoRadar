import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/core/design_system/navigation.dart';

void main() {
  for (final initiallyOpen in [false, true]) {
    testWidgets(
      'Apps halo keeps its paint while bouncing ${initiallyOpen ? 'closed' : 'open'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var open = initiallyOpen;
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: AppBottomNav(
                  destinations: _destinations,
                  currentIndex: open ? 2 : 1,
                  onSelect: (index) {
                    expect(index, 2);
                    taps++;
                    setState(() => open = !open);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tab-apps')));
        await tester.pump();
        expect(taps, 1);
        expect(open, !initiallyOpen);

        final halo = find.byKey(const ValueKey('app-bottom-nav-apps-halo'));
        final decorated = tester.renderObject<RenderDecoratedBox>(
          find.descendant(of: halo, matching: find.byType(DecoratedBox)).first,
        );
        final original = decorated.decoration as BoxDecoration;
        final shadow = original.boxShadow!.single;
        expect(original.shape, BoxShape.circle);
        expect(original.color, AppColors.surface);
        expect(shadow.blurRadius, open ? 12 : 9);
        expect(shadow.offset, const Offset(0, 5));
        expect(
          shadow.color,
          AppColors.teal.withValues(alpha: open ? 0.22 : 0.14),
        );
        expect(decorated.size, const Size.square(54));

        // Count the real halo decoration's paint, without replacing its visuals
        // or inserting a test-only repaint boundary into the measured subtree.
        final counter = _PaintCounter();
        decorated.decoration = _CountingDecoration(original, counter);
        await tester.pump();
        final initialPaints = counter.paints;
        expect(initialPaints, greaterThan(0));

        final motion = find.descendant(
          of: find.byKey(const ValueKey('tab-apps')),
          matching: find.byKey(
            const ValueKey('app-bottom-nav-motion-transform'),
          ),
        );
        final initialTransform = tester
            .widget<Transform>(motion)
            .transform
            .clone();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          tester.widget<Transform>(motion).transform,
          isNot(initialTransform),
          reason: 'The approved lift must still animate during the sample.',
        );
        expect(
          counter.paints,
          initialPaints,
          reason:
              'A stable halo should reuse paint beneath changing transforms.',
        );

        await tester.pumpAndSettle();
        final settledPaints = counter.paints;
        decorated.markNeedsPaint();
        await tester.pump();
        expect(
          counter.paints,
          settledPaints + 1,
          reason: 'The counter must still observe a genuine halo repaint.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _destinations = [
  AppBottomNavDestination(
    label: 'Inicio',
    keyName: 'home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    color: AppColors.teal,
  ),
  AppBottomNavDestination(
    label: 'Garaje',
    keyName: 'garage',
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car,
    color: AppColors.blue,
  ),
  AppBottomNavDestination(
    label: 'Apps',
    keyName: 'apps',
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    color: AppColors.navy,
  ),
  AppBottomNavDestination(
    label: 'Viaje',
    keyName: 'trip',
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    color: AppColors.orange,
  ),
  AppBottomNavDestination(
    label: 'Conducir',
    keyName: 'drive',
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    color: AppColors.red,
  ),
];

class _PaintCounter {
  int paints = 0;
}

class _CountingDecoration extends Decoration {
  const _CountingDecoration(this.original, this.counter);

  final BoxDecoration original;
  final _PaintCounter counter;

  @override
  bool get isComplex => original.isComplex;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _CountingBoxPainter(
    original.createBoxPainter(onChanged),
    counter,
    onChanged,
  );
}

class _CountingBoxPainter extends BoxPainter {
  _CountingBoxPainter(this.original, this.counter, super.onChanged);

  final BoxPainter original;
  final _PaintCounter counter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    counter.paints++;
    original.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    original.dispose();
    super.dispose();
  }
}
