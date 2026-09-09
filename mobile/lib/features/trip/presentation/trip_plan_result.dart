import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../pico_placa/domain/bogota_time.dart';
import '../../pico_placa/domain/restriction_day_evaluation.dart';
import '../../pico_placa/domain/restriction_engine.dart';
import '../application/trip_services.dart';
import '../data/toll_tariff_catalog.dart';
import '../domain/trip_plan.dart';
import 'trip_toll_sheet.dart';

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
    this.localPricingByRoute = const {},
    this.pricingChanges,
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
  final Map<String, LocalTollPricingBreakdown> localPricingByRoute;
  final ValueListenable<Map<String, LocalTollPricingBreakdown>>? pricingChanges;

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
              localPricingByRoute[route.id]?.coverage ==
                  LocalTollPricingCoverage.complete &&
              localPricingByRoute[route.id]?.totalMinor != null,
        )
        .toList();
    final cheapest = comparable.length < 2
        ? null
        : comparable
              .map((route) => localPricingByRoute[route.id]!.totalMinor!)
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
          '${request.origin.municipality} → ${request.destination.municipality}',
          style: AppTextStyles.bodyStrong,
        ),
        if (demoLabel != null) ...[
          const SizedBox(height: AppSpacing.s),
          _DemoBanner(label: demoLabel),
        ],
        const SizedBox(height: AppSpacing.m),
        if (selected != null)
          _TripSummary(route: selected, pricing: localTollPricing),
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
            localPricingByRoute: localPricingByRoute,
            pricingChanges: pricingChanges,
          ),
      ],
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.route, this.pricing});

  final TripRouteOption route;
  final LocalTollPricingBreakdown? pricing;

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
        value: tripTollEstimate(pricing),
        label: pricing?.coverage == LocalTollPricingCoverage.complete
            ? 'Peajes estimados'
            : 'Estimación parcial',
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
                      width: metric.key == 'cost'
                          ? constraints.maxWidth
                          : width,
                      child: _SummaryMetric(
                        icon: metric.icon,
                        value: metric.value,
                        label: metric.label,
                      ),
                    ),
                ],
              ),
              if (pricing != null && pricing!.missingRates > 0)
                Text(
                  pricing!.missingRates == 1
                      ? '1 cobro pendiente'
                      : '${pricing!.missingRates} cobros pendientes',
                  style: AppTextStyles.caption,
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
    required this.localPricingByRoute,
    this.pricingChanges,
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
  final Map<String, LocalTollPricingBreakdown> localPricingByRoute;
  final ValueListenable<Map<String, LocalTollPricingBreakdown>>? pricingChanges;

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
        label: Text(
          'Peajes de esta ruta · ${localTollPricing?.charges.length ?? '…'}',
        ),
      ),
      TextButton.icon(
        key: const ValueKey('trip-open-cameras-detail'),
        onPressed: () => _showCameras(context),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(
          cameraLocationCount == null
              ? 'Cámaras'
              : 'Cámaras · $cameraLocationCount',
        ),
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

  Widget _livePricing(
    Widget Function(Map<String, LocalTollPricingBreakdown>) builder,
  ) {
    final changes = pricingChanges;
    if (changes == null) return builder(localPricingByRoute);
    return ValueListenableBuilder<Map<String, LocalTollPricingBreakdown>>(
      valueListenable: changes,
      builder: (_, prices, _) => builder(prices),
    );
  }

  void _showRoutes(BuildContext context) {
    _showDetailSheet(
      context,
      title: 'Otras rutas · ${routes.length}',
      builder: (sheetContext) => _livePricing((prices) {
        final available = routes
            .where(
              (route) =>
                  prices[route.id]?.coverage ==
                      LocalTollPricingCoverage.complete &&
                  prices[route.id]?.totalMinor != null,
            )
            .toList();
        final least = available.length < 2
            ? null
            : available
                  .map((route) => prices[route.id]!.totalMinor!)
                  .reduce((a, b) => a < b ? a : b);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final route in routes) ...[
              _RouteOptionCard(
                route: route,
                request: request,
                selected: route.id == selectedRouteId,
                cheapest: least,
                comparable: available,
                localPricing: prices[route.id],
                onRouteSelected: (id) {
                  Navigator.of(sheetContext).pop();
                  onRouteSelected(id);
                },
              ),
              const SizedBox(height: AppSpacing.m),
            ],
          ],
        );
      }),
    );
  }

  void _showTolls(BuildContext context) {
    _showDetailSheet(
      context,
      title: 'Peajes de esta ruta',
      builder: (_) => _livePricing(
        (prices) => KeyedSubtree(
          key: ValueKey('trip-toll-sheet-${selected.id}'),
          child: TripRouteTolls(
            pricing: prices[selected.id] ?? localTollPricing,
            onSource: onSource,
          ),
        ),
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
}

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    required this.route,
    required this.request,
    required this.selected,
    required this.cheapest,
    required this.comparable,
    required this.onRouteSelected,
    this.localPricing,
  });

  final TripRouteOption route;
  final TripPlanRequest request;
  final bool selected;
  final int? cheapest;
  final List<TripRouteOption> comparable;
  final ValueChanged<String> onRouteSelected;
  final LocalTollPricingBreakdown? localPricing;

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
        Text(tripTollEstimate(localPricing)),
        Text(
          localPricing?.coverage == LocalTollPricingCoverage.complete
              ? 'Peajes estimados'
              : 'Estimación parcial',
        ),
        if (cheapest != null &&
            comparable.contains(route) &&
            localPricing?.totalMinor == cheapest)
          const Text('Menor estimación entre opciones con datos completos'),
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
    this.onCity,
    this.dateOnly = false,
    super.key,
  });
  final String label;
  final DateTime instantUtc;
  final AsyncValue<TripEndpointRestriction> evaluation;
  final ValueChanged<String> onSource;
  final VoidCallback? onCity;
  final bool dateOnly;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: AppTextStyles.bodyStrong),
        trailing: onCity == null ? null : const Icon(Icons.chevron_right),
        onTap: onCity,
        subtitle: onCity == null
            ? const Text('Ciudad sin cobertura identificada')
            : null,
      ),
      Text(
        dateOnly
            ? tripInstantLabel(instantUtc).split(' ').first
            : tripInstantLabel(instantUtc),
      ),
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
            Text(
              dateOnly
                  ? switch (result.status) {
                      RestrictionDayStatus.allowed =>
                        'Sin restricción para ese día',
                      RestrictionDayStatus.restricted =>
                        'Tiene restricción ese día',
                      RestrictionDayStatus.stale =>
                        'Información desactualizada',
                      RestrictionDayStatus.unknown =>
                        'Reglas del día no disponibles',
                    }
                  : switch (result.instantStatus) {
                      RestrictionStatus.allowed =>
                        'Sin restricción a la hora evaluada',
                      RestrictionStatus.restricted =>
                        'No circula a la hora evaluada',
                      RestrictionStatus.stale => 'Información desactualizada',
                      RestrictionStatus.unknown ||
                      null => 'Estado a esta hora no disponible',
                    },
            ),
            if (result.windows.isNotEmpty)
              Text(
                'Horario restringido: ${result.windows.map((window) => '${_minute(window.startMinute)}–${_minute(window.endMinute)}').join(', ')}',
              ),
            if (result.reason != null ||
                (result.instantStatus == RestrictionStatus.unknown &&
                    result.engineReason != null))
              Text(_restrictionReason(result)),
          ],
        ),
      ),
    ],
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
