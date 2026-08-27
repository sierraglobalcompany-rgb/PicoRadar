import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../data/vehicle_profile.dart';
import 'vehicle_display.dart';

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) {
          if (items.isEmpty) {
            return const _GarageEmpty();
          }

          String? activeId;
          if (active case AsyncData(:final value)) {
            activeId = value?.id;
            _ensureActiveVehicle(ref, items, activeId);
          }

          return _GarageList(vehicles: items, activeId: activeId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(error.toString()),
          );
        },
      ),
    );
  }

  void _ensureActiveVehicle(
    WidgetRef ref,
    List<VehicleProfile> vehicles,
    String? activeId,
  ) {
    if (activeId != null && vehicles.any((vehicle) => vehicle.id == activeId)) {
      return;
    }

    Future<void>.microtask(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      final latestActive = await repository.getActiveVehicle();
      if (latestActive != null) {
        return;
      }
      await repository.setActiveVehicle(vehicles.first.id);
      ref.invalidate(activeVehicleProvider);
      ref.invalidate(vehicleListProvider);
    });
  }
}

class _GarageList extends ConsumerWidget {
  const _GarageList({required this.vehicles, required this.activeId});

  final List<VehicleProfile> vehicles;
  final String? activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garaje',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                const Text('Tus vehículos y su estado en un solo lugar.'),
                const SizedBox(height: AppSpacing.l),
                FilledButton.icon(
                  key: const ValueKey('garage-add-vehicle'),
                  onPressed: () {
                    context.push(
                      '${AppRoute.vehicleOnboarding.path}?return=garage',
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar vehículo'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 900
                  ? 3
                  : width >= 620
                  ? 2
                  : 1;
              return SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final vehicle = vehicles[index];
                  return _VehicleCard(
                    vehicle: vehicle,
                    active: vehicle.id == activeId,
                    onUse: () async {
                      await ref
                          .read(vehicleRepositoryProvider)
                          .setActiveVehicle(vehicle.id);
                      ref.invalidate(activeVehicleProvider);
                    },
                    onOpen: () => context.push('/garage/vehicle/${vehicle.id}'),
                  );
                }, childCount: vehicles.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.m,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 250,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.active,
    required this.onUse,
    required this.onOpen,
  });

  final VehicleProfile vehicle;
  final bool active;
  final VoidCallback onUse;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = vehicleAccent(vehicle);
    final makeModel = vehicleMakeModel(vehicle);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: ValueKey('vehicle-card-${vehicle.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: active ? accent : AppColors.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(vehicleIcon(vehicle), color: accent, size: 32),
                    const Spacer(),
                    if (active)
                      Chip(
                        key: ValueKey('vehicle-active-${vehicle.id}'),
                        label: const Text('Activo'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  vehicle.plate,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardLine(vehicleTypeLabel(vehicle)),
                      if (vehicle.nickname != null)
                        _CardLine(vehicle.nickname!),
                      if (vehicle.registrationCity != null)
                        _CardLine('Matrícula: ${vehicle.registrationCity}'),
                      if (makeModel.isNotEmpty) _CardLine(makeModel),
                    ],
                  ),
                ),
                if (!active)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: ValueKey('vehicle-use-${vehicle.id}'),
                      onPressed: onUse,
                      child: const Text('Usar este vehículo'),
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

class _CardLine extends StatelessWidget {
  const _CardLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

class _GarageEmpty extends StatelessWidget {
  const _GarageEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.garage_outlined, size: 40),
              const SizedBox(height: AppSpacing.l),
              Text(
                'No tienes vehículos todavía',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                key: const ValueKey('garage-add-vehicle'),
                onPressed: () {
                  context.push(
                    '${AppRoute.vehicleOnboarding.path}?return=garage',
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
