import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../pico_placa/domain/bogota_time.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/domain/restriction_engine.dart';
import '../application/trip_services.dart';
import '../domain/trip_plan.dart';

class TripPlanResult extends StatelessWidget {
  const TripPlanResult({
    required this.request,
    required this.plan,
    required this.selectedRouteId,
    required this.onRouteSelected,
    required this.onSource,
    super.key,
  });

  final TripPlanRequest request;
  final TripPlan plan;
  final String selectedRouteId;
  final ValueChanged<String> onRouteSelected;
  final ValueChanged<String> onSource;

  @override
  Widget build(BuildContext context) {
    final routes = plan.routes.toList()
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final selected = routes
        .where((route) => route.id == selectedRouteId)
        .firstOrNull;
    final comparable = routes
        .where(
          (route) =>
              (route.tolls.coverage == TripTollCoverage.complete ||
                  route.tolls.coverage == TripTollCoverage.noChargeConfirmed) &&
              route.tolls.totalMinor != null &&
              route.tolls.vehicleCategory == request.vehicleCategory &&
              route.tolls.paymentMethod == 'cash',
        )
        .toList();
    final cheapest = comparable.length < 2
        ? null
        : comparable
              .map((route) => route.tolls.totalMinor!)
              .reduce((a, b) => a < b ? a : b);

    return Column(
      key: const ValueKey('trip-plan-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${routes.length} rutas encontradas', style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.s),
        Text(
          '${request.origin.displayName} → ${request.destination.displayName}',
          style: AppTextStyles.bodyStrong,
        ),
        Text(
          'Vehículo: ${request.vehicle.plate} · ${_category(request.vehicleCategory)}',
        ),
        Text('Salida: ${tripInstantLabel(request.departureUtc)}'),
        Text('Consulta: ${tripInstantLabel(plan.generatedAtUtc)}'),
        const SizedBox(height: AppSpacing.s),
        Text('Punto de origen: ${plan.origin.label}'),
        Text('Punto de destino: ${plan.destination.label}'),
        const Text('Estimación entre puntos de referencia de las ciudades'),
        Text('Proveedor: ${plan.provider}'),
        Text(plan.attribution),
        const SizedBox(height: AppSpacing.m),
        for (final route in routes) ...[
          Container(
            key: ValueKey('trip-route-${route.id}'),
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: route.id == selectedRouteId
                    ? AppColors.teal
                    : AppColors.border,
                width: route.id == selectedRouteId ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(route.summary, style: AppTextStyles.bodyStrong),
                Text(
                  '${(route.distanceMeters / 1000).toStringAsFixed(1)} km por carretera',
                ),
                Text(
                  'Duración aproximada: ${_duration(route.durationSeconds)}',
                ),
                Text(
                  'Llegada: ${tripInstantLabel(route.arrivalUtc(request.departureUtc))}',
                ),
                Text(
                  route.timeBasis == 'traffic'
                      ? 'Estimación con datos de tráfico del proveedor'
                      : 'Duración estática; no predice el tráfico de la salida',
                ),
                Text(_countText(route.tolls)),
                Text(_tollsText(route.tolls)),
                if (cheapest != null &&
                    comparable.contains(route) &&
                    route.tolls.totalMinor == cheapest)
                  const Text(
                    'Menor costo de peajes entre opciones con total completo',
                  ),
                const SizedBox(height: AppSpacing.s),
                OutlinedButton.icon(
                  key: ValueKey('trip-select-route-${route.id}'),
                  onPressed: route.id == selectedRouteId
                      ? null
                      : () => onRouteSelected(route.id),
                  icon: Icon(
                    route.id == selectedRouteId
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                  ),
                  label: Text(
                    route.id == selectedRouteId
                        ? 'Ruta seleccionada'
                        : 'Seleccionar ruta',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
        ],
        if (selected != null)
          ExpansionTile(
            key: ValueKey('trip-toll-details-${selected.id}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.m),
            title: Text(
              'Detalle de peajes · ${selected.summary}',
              style: AppTextStyles.bodyStrong,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Una ida. El regreso requiere otra consulta.'),
                    Text(_tollsText(selected.tolls)),
                    Text(
                      'Categoría: ${_category(selected.tolls.vehicleCategory)} · Método: ${_payment(selected.tolls.paymentMethod)}',
                    ),
                    Text('Proveedor: ${plan.provider}'),
                    const Text(
                      'Estimación basada en tarifas disponibles; no garantiza tarifas futuras.',
                    ),
                    if (selected.tolls.charges.isEmpty)
                      const Text('No se recibió desglose de estaciones.'),
                    for (final (index, charge)
                        in selected.tolls.charges.indexed) ...[
                      const Divider(),
                      Text(
                        '${index + 1}. ${charge.name}',
                        style: AppTextStyles.bodyStrong,
                      ),
                      Text(
                        charge.amountMinor == null
                            ? 'Tarifa no disponible'
                            : _cop(charge.amountMinor!),
                      ),
                      Text(
                        charge.effectiveAt == null
                            ? 'Fecha de tarifa no informada'
                            : 'Fecha de tarifa: ${charge.effectiveAt}',
                      ),
                      if (charge.sourceUrl != null)
                        _SourceButton(
                          url: charge.sourceUrl!,
                          onSource: onSource,
                        )
                      else
                        const Text('Fuente de tarifa no informada.'),
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class TripInstantEndpoint extends StatelessWidget {
  const TripInstantEndpoint({
    required this.label,
    required this.instantUtc,
    required this.evaluation,
    required this.onSource,
    super.key,
  });
  final String label;
  final DateTime instantUtc;
  final AsyncValue<TripEndpointRestriction> evaluation;
  final ValueChanged<String> onSource;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: AppTextStyles.bodyStrong),
      Text(tripInstantLabel(instantUtc)),
      evaluation.when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        loading: () => const Text('Consultando reglas locales'),
        error: (_, _) => const Text(
          'No se pudieron cargar las reglas locales. Estado no disponible.',
        ),
        data: (result) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(switch (result.instantStatus) {
              RestrictionStatus.allowed => 'Sin restricción a la hora evaluada',
              RestrictionStatus.restricted => 'No circula a la hora evaluada',
              RestrictionStatus.stale => 'Información desactualizada',
              RestrictionStatus.unknown ||
              null => 'Estado a esta hora no disponible',
            }),
            Text(switch (result.status) {
              RestrictionDayStatus.restricted =>
                'Este día tiene restricción para el vehículo.',
              RestrictionDayStatus.allowed =>
                'Sin restricción para el vehículo en este día.',
              RestrictionDayStatus.stale => 'Reglas del día desactualizadas.',
              RestrictionDayStatus.unknown => 'Reglas del día no disponibles.',
            }),
            if (result.windows.isNotEmpty)
              Text(
                'Horario restringido: ${result.windows.map((window) => '${_minute(window.startMinute)}–${_minute(window.endMinute)}').join(', ')}',
              ),
            if (result.reason != null ||
                (result.instantStatus == RestrictionStatus.unknown &&
                    result.engineReason != null))
              Text(_restrictionReason(result)),
            if (result.verifiedAt != null)
              Text(
                'Fuente verificada: ${tripInstantLabel(result.verifiedAt!)}',
              ),
            if (result.sourceUrl != null)
              _SourceButton(url: result.sourceUrl!, onSource: onSource)
            else
              const Text('Fuente de reglas no disponible.'),
          ],
        ),
      ),
    ],
  );
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.url, required this.onSource});
  final String url;
  final ValueChanged<String> onSource;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => onSource(url),
      icon: const Icon(Icons.open_in_new),
      label: const Text('Consultar fuente'),
    ),
  );
}

String tripInstantLabel(DateTime instant) {
  final date = bogotaWallClock(instant);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${_minute(date.hour * 60 + date.minute)} (Colombia)';
}

String _minute(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
String _duration(int seconds) {
  final minutes = (seconds / 60).ceil();
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}

String _cop(int minor) {
  final pesos = (minor ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  final cents = minor % 100;
  return 'COP $pesos${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'}';
}

String _category(String value) => switch (value) {
  'car' => 'Carro de 2 ejes',
  'motorcycle' => 'Moto de 2 ejes',
  'taxi' => 'Taxi',
  _ => 'Categoría no soportada',
};
String _payment(String value) => value == 'cash' ? 'Efectivo' : 'No informado';
String _countText(TripTolls tolls) {
  final stations = tolls.stationCount;
  final payable = tolls.payableCount;
  return '${stations == null ? 'Cantidad de peajes no confirmada' : '$stations estaciones de peaje'}'
      '${payable == null ? '' : ' · $payable cobros aplicables'}';
}

String _tollsText(TripTolls tolls) => switch (tolls.coverage) {
  TripTollCoverage.complete =>
    tolls.totalMinor == null
        ? 'Total de peajes no disponible'
        : 'Total estimado de peajes: ${_cop(tolls.totalMinor!)}',
  TripTollCoverage.partial =>
    'Subtotal conocido: ${tolls.subtotalMinor == null ? 'no disponible' : _cop(tolls.subtotalMinor!)} · ${tolls.missingRates} tarifas faltantes',
  TripTollCoverage.unknown => 'Costo de peajes desconocido',
  TripTollCoverage.noChargeConfirmed =>
    'Sin cobro confirmado para este vehículo (COP 0)',
  TripTollCoverage.unsupportedVehicle =>
    'Categoría no soportada para tarifas de peajes',
};

String _restrictionReason(TripEndpointRestriction result) {
  if (result.instantStatus == RestrictionStatus.unknown &&
      (result.reason == null || result.reason == 'no_coverage')) {
    switch (result.engineReason) {
      case RestrictionReasonCode.conflictingRules:
        return 'Hay reglas en conflicto para este vehículo y horario.';
      case RestrictionReasonCode.unknownRegistrationOrigin:
        return 'No se pudo determinar el origen de matrícula necesario para esta regla.';
      case RestrictionReasonCode.unknownRequiredPlateDigit:
        return 'No se pudo determinar el dígito de placa necesario para esta regla.';
      default:
        break;
    }
  }
  return switch (result.reason) {
    'missing_vehicle' =>
      'Selecciona un vehículo disponible para evaluar su restricción.',
    'ambiguous_municipality' =>
      'Elige municipio y departamento para evaluar su restricción.',
    'unmapped_jurisdiction' =>
      'Municipio sin jurisdicción de restricciones vinculada.',
    'no_coverage' => 'Sin cobertura de reglas para este municipio y vehículo.',
    'stale_data' => 'La vigencia de los datos disponibles terminó.',
    'future_coverage' => 'No hay reglas confirmadas para esta fecha futura.',
    'load_error' => 'No se pudieron cargar las reglas locales.',
    _ => 'No hay información suficiente para confirmar la restricción.',
  };
}

String tripPlanErrorText(String code) => switch (code) {
  'validation' => 'Revisa municipios, fecha, hora y categoría del vehículo.',
  'no_route' => 'No se encontró una ruta vial entre estos municipios.',
  'unsupported_vehicle' =>
    'El servicio no tiene una categoría verificada para este vehículo.',
  'not_configured' => 'El servicio de rutas y peajes aún no está habilitado.',
  'quota' => 'El servicio alcanzó su límite de consultas. Intenta más tarde.',
  'timeout' => 'La consulta tardó demasiado. Puedes volver a consultar.',
  'invalid_upstream' =>
    'El servicio no devolvió un plan verificable. Puedes volver a consultar.',
  _ => 'No pudimos conectar. Puedes volver a consultar.',
};
