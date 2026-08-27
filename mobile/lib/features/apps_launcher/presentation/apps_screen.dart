import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../data/module_registry.dart';
import '../domain/app_module.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(moduleFeatureFlagsProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) => active.when(
          data: (activeVehicle) => _AppsContent(
            activeVehicle:
                activeVehicle ?? (items.isEmpty ? null : items.first),
            primary: visibleModules(primaryModules, flags),
            secondary: visibleModules(secondaryModules, flags),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadError(message: error.toString()),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(message: error.toString()),
      ),
    );
  }
}

class _AppsContent extends StatelessWidget {
  const _AppsContent({
    required this.activeVehicle,
    required this.primary,
    required this.secondary,
  });

  final VehicleProfile? activeVehicle;
  final List<AppModule> primary;
  final List<AppModule> secondary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        96,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apps', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.m),
              _ActiveVehicleChip(vehicle: activeVehicle),
              const SizedBox(height: AppSpacing.l),
              _PrimaryGrid(modules: primary, activeVehicle: activeVehicle),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Más para tu vehículo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.m),
              _SecondaryList(modules: secondary, activeVehicle: activeVehicle),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveVehicleChip extends StatelessWidget {
  const _ActiveVehicleChip({required this.vehicle});

  final VehicleProfile? vehicle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: const ValueKey('apps-active-vehicle-chip'),
        onTap: () => context.go(AppRoute.garage.path),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.m,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  vehicle == null
                      ? Icons.directions_car
                      : vehicleIcon(vehicle!),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.s),
                Flexible(
                  child: Text(
                    vehicle == null
                        ? 'Sin vehículo'
                        : '${vehicle!.plate} · ${shortVehicleTypeLabel(vehicle!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryGrid extends StatelessWidget {
  const _PrimaryGrid({required this.modules, required this.activeVehicle});

  final List<AppModule> modules;
  final VehicleProfile? activeVehicle;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final aspectRatio = scale >= 1.8 ? 0.64 : (scale >= 1.4 ? 0.78 : 1.0);
    return GridView.builder(
      key: const ValueKey('apps-primary-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        final module = modules[index];
        return _ModuleTile(module: module, activeVehicle: activeVehicle);
      },
    );
  }
}

class _SecondaryList extends StatelessWidget {
  const _SecondaryList({required this.modules, required this.activeVehicle});

  final List<AppModule> modules;
  final VehicleProfile? activeVehicle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        return GridView.builder(
          key: const ValueKey('apps-secondary-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.s,
            crossAxisSpacing: AppSpacing.m,
            childAspectRatio: columns == 1 ? 5.0 : 4.3,
          ),
          itemBuilder: (context, index) {
            return _SecondaryRow(
              module: modules[index],
              activeVehicle: activeVehicle,
            );
          },
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.activeVehicle});

  final AppModule module;
  final VehicleProfile? activeVehicle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: ValueKey('app-module-${module.id}'),
        onTap: () => _openModule(context, module, activeVehicle),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  module.icon,
                  size: AppIconSize.l,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  module.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryRow extends StatelessWidget {
  const _SecondaryRow({required this.module, required this.activeVehicle});

  final AppModule module;
  final VehicleProfile? activeVehicle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: ValueKey('app-secondary-${module.id}'),
        onTap: () => _openModule(context, module, activeVehicle),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: Row(
              children: [
                Icon(module.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    module.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    );
  }
}

Future<void> _openModule(
  BuildContext context,
  AppModule module,
  VehicleProfile? activeVehicle,
) async {
  if (module.requiresVehicle && activeVehicle == null) {
    final rootContext = context;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agrega un vehículo'),
        content: const Text('Agrega un vehículo para usar esta función.'),
        actions: [
          TextButton(
            key: const ValueKey('vehicle-guard-cancel'),
            onPressed: () => context.pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('vehicle-guard-add'),
            onPressed: () {
              context.pop();
              rootContext.go('/onboarding/vehicle?return=apps');
            },
            child: const Text('Agregar vehículo'),
          ),
        ],
      ),
    );
    return;
  }

  if (module.destination == AppRoute.trip.path) {
    context.go(AppRoute.trip.path);
    return;
  }
  context.push(module.destination);
}
