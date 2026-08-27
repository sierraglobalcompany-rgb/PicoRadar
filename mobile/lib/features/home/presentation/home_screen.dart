import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) {
          if (items.isEmpty) {
            return const _HomeWelcome();
          }

          return _HomeReady(vehicleCount: items.length);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(message: error.toString()),
      ),
    );
  }
}

class _HomeWelcome extends StatelessWidget {
  const _HomeWelcome();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(
                Icons.radar_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'PicoRadar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              const Text(
                'Tu vehículo, tus alertas y tu ruta en un solo lugar.',
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                key: const ValueKey('home-add-vehicle'),
                onPressed: () => context.push(AppRoute.vehicleOnboarding.path),
                icon: const Icon(Icons.add),
                label: const Text('Agregar mi vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeReady extends StatelessWidget {
  const _HomeReady({required this.vehicleCount});

  final int vehicleCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inicio', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.s),
          Text(
            vehicleCount == 1
                ? 'Tienes 1 vehículo guardado.'
                : 'Tienes $vehicleCount vehículos guardados.',
          ),
        ],
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
