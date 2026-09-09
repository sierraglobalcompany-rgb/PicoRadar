import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../pico_placa/domain/bogota_time.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/domain/restriction_engine.dart';
import '../application/trip_services.dart';
import '../data/toll_tariff_catalog.dart';
import '../domain/trip_plan.dart';

class TripPlanResult extends StatelessWidget {
  const TripPlanResult({
    required this.request,
    required this.plan,
    required this.selectedRouteId,
    required this.onRouteSelected,
    required this.onSource,
    this.mapPreview,
    this.mapAnchorKey,
    this.onViewMap,
    this.cameraLocationCount,
    this.localTollPricing,
    super.key,
  });

  final TripPlanRequest request;
  final TripPlan plan;
  final String selectedRouteId;
  final ValueChanged<String> onRouteSelected;
  final ValueChanged<String> onSource;
  final Widget? mapPreview;
  final GlobalKey? mapAnchorKey;
  final VoidCallback? onViewMap;
  final int? cameraLocationCount;
  final LocalTollPricingBreakdown? localTollPricing;

  @override
  Widget build(BuildContext context) {
    final routes = plan.routes.toList()
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final selected = routes
        .where((route) => route.id == selectedRouteId)
        .firstOrNull;
    final demoLabel = plan.attribution == tripDemoWarningLabel
        ? tripDemoWarningLabel
        : null;
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
        Semantics(
          header: true,
          child: Text('Tu plan de viaje', style: AppTextStyles.h2),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          '${request.origin.displayName} → ${request.destination.displayName}',
          style: AppTextStyles.bodyStrong,
        ),
        if (demoLabel != null) ...[
          const SizedBox(height: AppSpacing.s),
          _DemoBanner(label: demoLabel),
        ],
        Text(
          'Vehículo: ${request.vehicle.plate} · ${_category(request.vehicleCategory)}',
        ),
        Text(_departureLabel(request)),
        if (request.departureMode == TripDepartureMode.dateOnly)
          const Text(
            'La fecha real de llegada depende de la ruta y puede ser el día siguiente.',
          ),
        const SizedBox(height: AppSpacing.m),
        if (selected != null) _TripSummary(route: selected),
        if (selected != null)
          Text(
            'Mapa del viaje · ${selected.summary}',
            style: AppTextStyles.caption,
          ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          key: mapAnchorKey,
          child: GestureDetector(
            key: const ValueKey('trip-map-preview-slot'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 300),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child:
                  mapPreview ??
                  const Center(
                    child: Text(
                      'Vista previa de ruta no disponible. Conserva las alternativas y sus detalles.',
                      textAlign: TextAlign.center,
                    ),
                  ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (selected != null)
          _DetailActions(
            routes: routes,
            selectedRouteId: selectedRouteId,
            request: request,
            plan: plan,
            cheapest: cheapest,
            comparable: comparable,
            onRouteSelected: onRouteSelected,
            onSource: onSource,
            onViewMap: onViewMap,
            cameraLocationCount: cameraLocationCount,
            localTollPricing: localTollPricing,
          ),
      ],
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.route});

  final TripRouteOption route;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        key: 'distance',
        icon: Icons.route_outlined,
        value: '${(route.distanceMeters / 1000).toStringAsFixed(1)} km',
        label: 'Distancia aproximada',
      ),
      (
        key: 'duration',
        icon: Icons.schedule_outlined,
        value: _duration(route.durationSeconds),
        label: 'Duración estimada',
      ),
      (
        key: 'cost',
        icon: Icons.payments_outlined,
        value: _summaryCost(route.tolls),
        label: 'Costo de peajes',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.s;
          final useSingleColumn =
              MediaQuery.textScalerOf(context).scale(1) >= 2;
          final width = useSingleColumn
              ? constraints.maxWidth
              : (constraints.maxWidth - gap) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: AppSpacing.s,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      key: ValueKey('trip-summary-${metric.key}'),
                      width: width,
                      child: _SummaryMetric(
                        icon: metric.icon,
                        value: metric.value,
                        label: metric.label,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    container: true,
    child: Container(
      key: const ValueKey('trip-demo-result-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFE4B443)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFF5D4100),
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.routes,
    required this.selectedRouteId,
    required this.request,
    required this.plan,
    required this.cheapest,
    required this.comparable,
    required this.onRouteSelected,
    required this.onSource,
    required this.onViewMap,
    required this.cameraLocationCount,
    required this.localTollPricing,
  });

  final List<TripRouteOption> routes;
  final String selectedRouteId;
  final TripPlanRequest request;
  final TripPlan plan;
  final int? cheapest;
  final List<TripRouteOption> comparable;
  final ValueChanged<String> onRouteSelected;
  final ValueChanged<String> onSource;
  final VoidCallback? onViewMap;
  final int? cameraLocationCount;
  final LocalTollPricingBreakdown? localTollPricing;

  TripRouteOption get selected => routes.firstWhere(
    (route) => route.id == selectedRouteId,
    orElse: () => routes.first,
  );

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s,
    runSpacing: AppSpacing.s,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('trip-open-routes-detail'),
        onPressed: () => _showRoutes(context),
        icon: const Icon(Icons.alt_route_rounded),
        label: Text('Otras rutas · ${routes.length}'),
      ),
      OutlinedButton.icon(
        key: ValueKey('trip-toll-details-${selected.id}'),
        onPressed: () => _showTolls(context),
        icon: const Icon(Icons.toll_outlined),
        label: const Text('Peajes'),
      ),
      OutlinedButton.icon(
        key: const ValueKey('trip-open-cameras-detail'),
        onPressed: () => _showCameras(context),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(
          cameraLocationCount == null
              ? 'Cámaras'
              : 'Cámaras · $cameraLocationCount',
        ),
      ),
      OutlinedButton.icon(
        key: const ValueKey('trip-plan-source-details'),
        onPressed: () => _showSources(context),
        icon: const Icon(Icons.dataset_outlined),
        label: const Text('Datos y fuentes'),
      ),
      if (onViewMap != null)
        TextButton.icon(
          key: ValueKey('trip-view-map-${selected.id}'),
          onPressed: onViewMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Ver en mapa'),
        ),
    ],
  );

  void _showRoutes(BuildContext context) {
    _showDetailSheet(
      context,
      title: 'Otras rutas · ${routes.length}',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final route in routes) ...[
            _RouteOptionCard(
              route: route,
              request: request,
              selected: route.id == selectedRouteId,
              cheapest: cheapest,
              comparable: comparable,
              onRouteSelected: (id) {
                Navigator.of(sheetContext).pop();
                onRouteSelected(id);
              },
            ),
            const SizedBox(height: AppSpacing.m),
          ],
        ],
      ),
    );
  }

  void _showTolls(BuildContext context) {
    _showDetailSheet(
      context,
      title: 'Peajes y presupuesto',
      child: Column(
        key: ValueKey('trip-toll-sheet-${selected.id}'),
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
          for (final (index, charge) in selected.tolls.charges.indexed) ...[
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
              _SourceButton(url: charge.sourceUrl!, onSource: onSource)
            else
              const Text('Fuente de tarifa no informada.'),
          ],
          if (localTollPricing != null) ...[
            const Divider(),
            Text(
              'Tarifas propias sobre peajes candidatos',
              key: ValueKey('trip-local-toll-pricing-${selected.id}'),
              style: AppTextStyles.bodyStrong,
            ),
            const Text(
              'Estimación local por ID físico cercano a la geometría. No confirma cruce, sentido ni cobro activo.',
            ),
            Text(_localCoverageText(localTollPricing!)),
            if (localTollPricing!.coverage !=
                LocalTollPricingCoverage.noPassages) ...[
              Text(
                'Subtotal con datos: ${_cop(localTollPricing!.subtotalMinor)}',
              ),
              if (localTollPricing!.totalMinor == null)
                Text(
                  'Total no publicado: faltan ${localTollPricing!.missingRates} tarifa(s).',
                )
              else
                Text('Total local: ${_cop(localTollPricing!.totalMinor!)}'),
            ],
            for (final (index, charge)
                in localTollPricing!.charges.indexed) ...[
              const Divider(),
              Text(
                '${index + 1}. ${charge.name}',
                style: AppTextStyles.bodyStrong,
              ),
              Text('Categoría operador: ${charge.categoryCode}'),
              Text(
                charge.amountMinor == null
                    ? 'Tarifa no informada; no equivale a gratis.'
                    : _cop(charge.amountMinor!),
              ),
              Text(
                '${charge.publicationControl ?? 'Control no informado'} · '
                '${charge.sourceType ?? 'fuente no informada'}'
                '${charge.sourceDate == null ? '' : ' · ${charge.sourceDate}'}',
              ),
              if (charge.sourceUrl != null)
                _SourceButton(url: charge.sourceUrl!, onSource: onSource),
            ],
          ],
        ],
      ),
    );
  }

  void _showCameras(BuildContext context) {
    final count = cameraLocationCount;
    _showDetailSheet(
      context,
      title: count == null ? 'Cámaras' : 'Cámaras · $count',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == null
                ? 'Las cámaras se calculan cuando la geometría y los datos locales están listos.'
                : '$count cámaras registradas próximas al recorrido.',
          ),
          const Text(
            'La proximidad no confirma vía, carril, sentido ni vigencia operativa. Toca los marcadores del mapa para ver fuente y ubicación registrada.',
          ),
        ],
      ),
    );
  }

  void _showSources(BuildContext context) {
    _showDetailSheet(
      context,
      title: 'Datos y fuentes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Consulta: ${tripInstantLabel(plan.generatedAtUtc)}'),
          Text('Punto de origen: ${plan.origin.label}'),
          Text('Punto de destino: ${plan.destination.label}'),
          const Text('Estimación entre puntos de referencia de las ciudades'),
          Text('Proveedor: ${plan.provider}'),
          Text(plan.attribution),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    required this.route,
    required this.request,
    required this.selected,
    required this.cheapest,
    required this.comparable,
    required this.onRouteSelected,
  });

  final TripRouteOption route;
  final TripPlanRequest request;
  final bool selected;
  final int? cheapest;
  final List<TripRouteOption> comparable;
  final ValueChanged<String> onRouteSelected;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('trip-route-${route.id}'),
    padding: const EdgeInsets.all(AppSpacing.m),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: selected ? AppColors.teal : AppColors.border,
        width: selected ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? AppColors.teal
                  : AppColors.navy.withValues(alpha: 0.62),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(route.summary, style: AppTextStyles.bodyStrong),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          '${(route.distanceMeters / 1000).toStringAsFixed(1)} km por carretera',
        ),
        Text('Duración aproximada: ${_duration(route.durationSeconds)}'),
        Text(
          request.departureUtc == null
              ? 'Llegada: sin hora exacta'
              : 'Llegada: ${tripInstantLabel(route.arrivalUtc(request.departureUtc!))}',
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
          const Text('Menor costo de peajes entre opciones con total completo'),
        const SizedBox(height: AppSpacing.s),
        OutlinedButton.icon(
          key: ValueKey('trip-select-route-${route.id}'),
          onPressed: selected ? null : () => onRouteSelected(route.id),
          icon: Icon(
            selected
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
          ),
          label: Text(selected ? 'Ruta seleccionada' : 'Seleccionar ruta'),
        ),
      ],
    ),
  );
}

void _showDetailSheet(
  BuildContext context, {
  required String title,
  Widget? child,
  WidgetBuilder? builder,
}) {
  assert(child != null || builder != null);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.m),
              child ?? builder!(sheetContext),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.teal),
      const SizedBox(width: AppSpacing.s),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyles.bodyStrong),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    ],
  );
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

String _localCoverageText(LocalTollPricingBreakdown pricing) {
  return switch (pricing.coverage) {
    LocalTollPricingCoverage.complete =>
      'Cobertura local completa para los pasos candidatos listados.',
    LocalTollPricingCoverage.partial =>
      'Cobertura local parcial: ${pricing.missingRates} tarifa(s) sin dato.',
    LocalTollPricingCoverage.noPassages => 'Sin peajes candidatos identificados sobre la geometría. No equivale a ruta libre de cobro.',
    LocalTollPricingCoverage.unsupportedCategory =>
      'Categoría local no soportada para estimación.',
  };
}

String _category(String value) => switch (value) {
  'car' => 'Carro de 2 ejes',
  'motorcycle' => 'Moto de 2 ejes',
  'taxi' => 'Taxi',
  _ => 'Categoría no soportada',
};

String _departureLabel(TripPlanRequest request) =>
    switch (request.departureMode) {
      TripDepartureMode.now => 'Salida: ahora',
      TripDepartureMode.dateOnly => 'Salida: Hora opcional · Sin definir',
      TripDepartureMode.specified =>
        'Salida: ${tripInstantLabel(request.departureUtc!)}',
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

String _summaryCost(TripTolls tolls) => switch (tolls.coverage) {
  TripTollCoverage.complete =>
    tolls.totalMinor == null ? 'Por confirmar' : _cop(tolls.totalMinor!),
  TripTollCoverage.partial =>
    tolls.subtotalMinor == null
        ? 'Parcial'
        : '${_cop(tolls.subtotalMinor!)} parcial',
  TripTollCoverage.noChargeConfirmed => 'Sin cobro confirmado',
  TripTollCoverage.unknown => 'Por confirmar',
  TripTollCoverage.unsupportedVehicle => 'No disponible',
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
