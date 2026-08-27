import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) {
          if (items.isEmpty) {
            return const _GarageEmpty();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garaje',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  items.length == 1
                      ? 'Tienes 1 vehículo guardado.'
                      : 'Tienes ${items.length} vehículos guardados.',
                ),
              ],
            ),
          );
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
                onPressed: () => context.push(AppRoute.vehicleOnboarding.path),
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
