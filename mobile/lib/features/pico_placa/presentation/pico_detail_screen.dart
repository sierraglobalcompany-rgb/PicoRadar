import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../data/restriction_store.dart';
import '../domain/restriction_day_evaluation.dart';

class PicoDetailScreen extends ConsumerWidget {
  const PicoDetailScreen({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(bundledRestrictionsProvider);
    final active = ref.watch(activeVehicleProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final jurisdictions = ref.watch(restrictionJurisdictionsProvider);
    final selected = ref.watch(selectedPicoJurisdictionIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pico y Placa'),
        leading: BackButton(onPressed: () => context.go(AppRoute.home.path)),
      ),
      body: seed.when(
        data: (_) => vehicles.when(
          data: (items) => active.when(
            data: (activeVehicle) {
              final vehicle = _resolveVehicle(
                explicitVehicleId: vehicleId,
                vehicles: items,
                activeVehicle: activeVehicle,
              );
              if (vehicle == null) {
                return const _Message('Agrega tu vehículo para comenzar.');
              }
              return jurisdictions.when(
                data: (jurisdictionItems) => selected.when(
                  data: (jurisdictionId) {
                    final jurisdiction = _findJurisdiction(
                      jurisdictionItems,
                      jurisdictionId,
                    );
                    if (jurisdiction == null) {
                      return const _Message('Selecciona tu ciudad en la app.');
                    }
                    return FutureBuilder<RestrictionRuleSet>(
                      future: ref
                          .read(restrictionStoreProvider)
                          .loadCoverage(
                            jurisdiction.id,
                            vehicle.kind,
                            vehicle.serviceType,
                            ref.read(currentInstantProvider),
                          ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _PicoDetailContent(
                          vehicle: vehicle,
                          jurisdiction: jurisdiction,
                          ruleSet: snapshot.data!,
                          now: ref.read(bogotaNowProvider),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _Message(error.toString()),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _Message(error.toString()),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _Message(error.toString()),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Message(error.toString()),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _Message(error.toString()),
      ),
    );
  }
}

VehicleProfile? _resolveVehicle({
  required String? explicitVehicleId,
  required List<VehicleProfile> vehicles,
  required VehicleProfile? activeVehicle,
}) {
  final id = explicitVehicleId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
  }
  return activeVehicle;
}

class _PicoDetailContent extends StatelessWidget {
  const _PicoDetailContent({
    required this.vehicle,
    required this.jurisdiction,
    required this.ruleSet,
    required this.now,
  });

  final VehicleProfile vehicle;
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var offset = 0; offset < 7; offset += 1)
        DateTime(now.year, now.month, now.day + offset),
    ];
    final evaluations = [
      for (final day in days)
        evaluateRestrictionDay(
          ruleSet: ruleSet,
          jurisdictionId: jurisdiction.id,
          plate: vehicle.plate,
          vehicleKind: vehicle.kind,
          serviceType: vehicle.serviceType,
          date: day,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(vehicleIcon(vehicle)),
                    title: Text(vehicle.plate),
                    subtitle: Text(
                      '${shortVehicleTypeLabel(vehicle)} · ${jurisdiction.name}',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _DetailStatus(title: 'Hoy', evaluation: evaluations[0]),
                const SizedBox(height: AppSpacing.m),
                _DetailStatus(title: 'Mañana', evaluation: evaluations[1]),
                const SizedBox(height: AppSpacing.l),
                Text(
                  'Próximos 7 días',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s),
                for (var index = 0; index < days.length; index += 1)
                  _DayRow(
                    date: days[index],
                    evaluation: evaluations[index],
                    label: index == 0 ? 'Hoy' : null,
                  ),
                const SizedBox(height: AppSpacing.l),
                _DataCard(ruleSet: ruleSet),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailStatus extends StatelessWidget {
  const _DetailStatus({required this.title, required this.evaluation});

  final String title;
  final RestrictionDayEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s),
            Text(_statusText(evaluation.status)),
            if (evaluation.effectiveWindows.isNotEmpty)
              Text(_windows(evaluation.effectiveWindows)),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.date, required this.evaluation, this.label});

  final DateTime date;
  final RestrictionDayEvaluation evaluation;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${_weekday(date)} ${date.day} ${label ?? ''}'.trim()),
      subtitle: Text(_statusText(evaluation.status)),
      trailing: evaluation.effectiveWindows.isEmpty
          ? null
          : Text(_windows(evaluation.effectiveWindows)),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.ruleSet});

  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s),
            Text('Estado: ${_dataState(ruleSet)}'),
            if (ruleSet.verifiedAt != null)
              Text('Última verificación: ${_date(ruleSet.verifiedAt!)}'),
            if (ruleSet.sourceUrls.isNotEmpty)
              Text(
                'Fuente oficial: ${Uri.parse(ruleSet.sourceUrls.first).host}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(text),
      ),
    );
  }
}

RestrictionJurisdiction? _findJurisdiction(
  List<RestrictionJurisdiction> items,
  String? id,
) {
  for (final item in items) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

String _statusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Tienes Pico y Placa',
    RestrictionDayStatus.allowed => 'Puedes circular',
    RestrictionDayStatus.unknown => 'No podemos confirmar',
    RestrictionDayStatus.stale => 'Datos desactualizados',
  };
}

String _dataState(RestrictionRuleSet ruleSet) {
  if (!ruleSet.coverageKnown) {
    return 'sin cobertura verificada';
  }
  return ruleSet.dataIsStale ? 'pendiente de actualización' : 'vigente';
}

String _windows(List<RestrictionDayWindow> windows) {
  return windows
      .map(
        (window) =>
            '${_minute(window.startMinute)}-${_minute(window.endMinute)}',
      )
      .join(', ');
}

String _minute(int minute) {
  if (minute == 1440) {
    return '24:00';
  }
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

String _date(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _weekday(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => 'Lun',
    DateTime.tuesday => 'Mar',
    DateTime.wednesday => 'Mié',
    DateTime.thursday => 'Jue',
    DateTime.friday => 'Vie',
    DateTime.saturday => 'Sáb',
    _ => 'Dom',
  };
}
