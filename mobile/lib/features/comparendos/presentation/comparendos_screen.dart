import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../vehicle_status/platform/external_launcher.dart';

const _simitUrl = 'https://www.simit.org.co/';
const _medellinUrl =
    'https://www.medellin.gov.co/es/tramites-y-servicios/consulta-de-comparendos-electronicos/';
const _bogotaUrl = 'https://www.movilidadbogota.gov.co/node/15670';

final _lastCheckedProvider = FutureProvider.family<String?, String>((
  ref,
  vehicleId,
) {
  return ref
      .watch(appPreferencesProvider)
      .getString(_lastCheckedKey(vehicleId));
});

class ComparendosScreen extends ConsumerWidget {
  const ComparendosScreen({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comparendos')),
      body: SafeArea(
        child: vehicles.when(
          data: (items) => active.when(
            data: (activeVehicle) {
              final vehicle = _resolveVehicle(
                vehicles: items,
                activeVehicle: activeVehicle,
                vehicleId: vehicleId,
              );
              if (vehicle == null) {
                return const _NoVehiclePane();
              }
              return _ComparendosContent(vehicle: vehicle);
            },
            loading: () => const _LoadingPane(),
            error: (error, stackTrace) => _ErrorPane(message: error.toString()),
          ),
          loading: () => const _LoadingPane(),
          error: (error, stackTrace) => _ErrorPane(message: error.toString()),
        ),
      ),
    );
  }
}

class _ComparendosContent extends ConsumerWidget {
  const _ComparendosContent({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastChecked = ref.watch(_lastCheckedProvider(vehicle.id));
    final cityLink = _territorialLink(vehicle.registrationCity);

    return SingleChildScrollView(
      key: const ValueKey('comparendos-screen'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleSummary(vehicle: vehicle),
              const SizedBox(height: AppSpacing.l),
              const _OfficialNotice(),
              const SizedBox(height: AppSpacing.l),
              OutlinedButton.icon(
                key: const ValueKey('comparendos-copy-plate'),
                onPressed: () => _copyPlate(context, vehicle.plate),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar placa'),
              ),
              const SizedBox(height: AppSpacing.s),
              FilledButton.icon(
                key: const ValueKey('comparendos-open-simit'),
                onPressed: () => _openExternal(
                  context,
                  ref,
                  _simitUrl,
                  'No pudimos abrir SIMIT.',
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Consultar en SIMIT'),
              ),
              const SizedBox(height: AppSpacing.s),
              if (cityLink == null)
                Text(
                  'Usa SIMIT para la consulta nacional.',
                  key: const ValueKey('comparendos-unsupported-city'),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('comparendos-open-territorial'),
                  onPressed: () => _openExternal(
                    context,
                    ref,
                    cityLink.url,
                    'No pudimos abrir la autoridad de tránsito.',
                  ),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: Text(cityLink.label),
                ),
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonalIcon(
                key: const ValueKey('comparendos-mark-checked'),
                onPressed: () => _markCheckedToday(context, ref, vehicle.id),
                icon: const Icon(Icons.today_outlined),
                label: const Text('Marcar que consulté hoy'),
              ),
              const SizedBox(height: AppSpacing.s),
              lastChecked.when(
                data: (date) => date == null
                    ? const SizedBox.shrink()
                    : Text(
                        'Última consulta anotada: $date',
                        key: const ValueKey('comparendos-last-checked'),
                        style: AppTextStyles.bodyStrong,
                      ),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => Text(error.toString()),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Esta fecha es una nota local. No guarda ni confirma el resultado oficial.',
                key: const ValueKey('comparendos-local-note'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyPlate(BuildContext context, String plate) async {
    await Clipboard.setData(ClipboardData(text: plate));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Placa copiada.')));
    }
  }

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    String url,
    String failureMessage,
  ) async {
    final launcher = ref.read(externalLauncherProvider);
    var opened = false;
    try {
      opened = await launcher.openExternal(url);
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failureMessage)));
  }

  Future<void> _markCheckedToday(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
  ) async {
    final date = _formatBogotaDate(ref.read(bogotaNowProvider));
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setString(_lastCheckedKey(vehicleId), date);
    if (!context.mounted) {
      return;
    }
    ref.invalidate(_lastCheckedProvider(vehicleId));
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Icon(
              vehicleIcon(vehicle),
              size: AppIconSize.l,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plate,
                    key: const ValueKey('comparendos-plate'),
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _vehicleType(vehicle),
                    key: const ValueKey('comparendos-vehicle-type'),
                    style: AppTextStyles.body,
                  ),
                  if (_hasText(vehicle.registrationCity)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      vehicle.registrationCity!.trim(),
                      key: const ValueKey('comparendos-registration-city'),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialNotice extends StatelessWidget {
  const _OfficialNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          'PicoRadar no consulta ni almacena el resultado de comparendos.\n'
          'La información oficial se consulta en SIMIT o en la autoridad de tránsito.',
          key: const ValueKey('comparendos-official-notice'),
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _NoVehiclePane extends StatelessWidget {
  const _NoVehiclePane();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('comparendos-no-vehicle'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 48),
            const SizedBox(height: AppSpacing.m),
            Text('Agrega un vehículo', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Necesitas una placa local para consultar en los canales oficiales.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              key: const ValueKey('comparendos-go-garage'),
              onPressed: () => context.go(AppRoute.garage.path),
              child: const Text('Ir a Garaje'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('comparendos-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    );
  }
}

VehicleProfile? _resolveVehicle({
  required List<VehicleProfile> vehicles,
  required VehicleProfile? activeVehicle,
  required String? vehicleId,
}) {
  final requestedId = vehicleId?.trim();
  if (requestedId != null && requestedId.isNotEmpty) {
    for (final vehicle in vehicles) {
      if (vehicle.id == requestedId) {
        return vehicle;
      }
    }
    return null;
  }
  return activeVehicle ?? (vehicles.isEmpty ? null : vehicles.first);
}

String _vehicleType(VehicleProfile vehicle) {
  if (vehicle.kind == VehicleKind.motorcycle) {
    return 'Moto';
  }
  return switch (vehicle.serviceType) {
    VehicleServiceType.taxi => 'Taxi',
    VehicleServiceType.private => 'Particular',
  };
}

_TerritorialLink? _territorialLink(String? registrationCity) {
  final normalized = _normalizeCity(registrationCity);
  if (normalized.contains('medellin')) {
    return const _TerritorialLink('Consultar en Medellín', _medellinUrl);
  }
  if (normalized.contains('bogota')) {
    return const _TerritorialLink('Consultar en Bogotá', _bogotaUrl);
  }
  return null;
}

String _normalizeCity(String? value) {
  final lower = value?.trim().toLowerCase() ?? '';
  return lower
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

String _lastCheckedKey(String vehicleId) {
  return 'comparendos.last_checked.$vehicleId';
}

String _formatBogotaDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

class _TerritorialLink {
  const _TerritorialLink(this.label, this.url);

  final String label;
  final String url;
}
