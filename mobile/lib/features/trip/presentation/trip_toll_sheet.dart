import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/toll_tariff_catalog.dart';

String tripTollMoney(int minor) {
  final pesos = (minor ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return 'COP $pesos';
}

String tripTollEstimate(LocalTollPricingBreakdown? pricing) {
  if (pricing == null) return 'Peajes por confirmar';
  if (pricing.coverage == LocalTollPricingCoverage.noPassages) {
    return 'Sin pasos identificados';
  }
  if (pricing.coverage == LocalTollPricingCoverage.unsupportedCategory) {
    return 'Categoría por confirmar';
  }
  if (pricing.charges.every((charge) => charge.amountMinor == null)) {
    return 'Cobros por confirmar';
  }
  return tripTollMoney(pricing.totalMinor ?? pricing.subtotalMinor);
}

class TripRouteTolls extends StatefulWidget {
  const TripRouteTolls({
    required this.pricing,
    required this.onSource,
    super.key,
  });
  final LocalTollPricingBreakdown? pricing;
  final ValueChanged<String> onSource;

  @override
  State<TripRouteTolls> createState() => _TripRouteTollsState();
}

class _TripRouteTollsState extends State<TripRouteTolls> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final pricing = widget.pricing;
    final charges = pricing?.charges ?? const <LocalTollPricingCharge>[];
    final entries = charges.indexed.where(
      (entry) =>
          entry.$2.name.toLowerCase().contains(_query.trim().toLowerCase()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tripTollEstimate(pricing), style: AppTextStyles.h2),
        Text(
          pricing?.coverage == LocalTollPricingCoverage.complete
              ? 'Peajes estimados · una ida'
              : 'Estimación parcial · cobros pendientes',
        ),
        const SizedBox(height: AppSpacing.s),
        const Text(
          'Peajes próximos al recorrido. La estimación no confirma sentido ni operación actual.',
        ),
        if (pricing != null && pricing.missingRates > 0)
          Text(
            '${pricing.missingRates} cobros pendientes, excluidos de la estimación.',
          ),
        if (pricing == null)
          const Text(
            'No hay una estimación local disponible. Puedes conservar la ruta y volver a consultar los datos.',
          ),
        if (pricing != null && charges.isEmpty)
          const Text(
            'No hay pasos identificados para esta ruta. No significa que sea gratuita.',
          ),
        if (charges.length > 1) ...[
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const ValueKey('trip-route-toll-search'),
            decoration: const InputDecoration(
              labelText: 'Buscar en esta ruta',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ],
        for (final (index, charge) in entries) ...[
          const Divider(),
          ExpansionTile(
            key: ValueKey('trip-route-toll-${charge.stationId}-$index'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${index + 1}. ${charge.name}',
              style: AppTextStyles.bodyStrong,
            ),
            subtitle: Text(
              'Cat. ${charge.categoryCode} · '
              '${charge.amountMinor == null ? 'Cobro pendiente' : tripTollMoney(charge.amountMinor!)}',
            ),
            children: [
              TripTollChargeDetails(charge: charge, onSource: widget.onSource),
            ],
          ),
        ],
        if (charges.isNotEmpty && entries.isEmpty)
          const Text('No hay coincidencias en esta ruta.'),
      ],
    );
  }
}

class TripTollChargeDetails extends StatefulWidget {
  const TripTollChargeDetails({
    required this.charge,
    required this.onSource,
    super.key,
  });
  final LocalTollPricingCharge charge;
  final ValueChanged<String> onSource;

  @override
  State<TripTollChargeDetails> createState() => _TripTollChargeDetailsState();
}

class _TripTollChargeDetailsState extends State<TripTollChargeDetails> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final charge = widget.charge;
    final station = charge.station;
    final rates = station?.generalRates ?? const <TollTariffRate>[];
    final requestedCategory = _category ?? charge.categoryCode;
    final category = rates.any((rate) => rate.categoryCode == requestedCategory)
        ? requestedCategory
        : rates.firstOrNull?.categoryCode ?? requestedCategory;
    final rate = station?.generalRateByCategory(category);
    final source =
        rate?.chargeSourceUrl ?? rate?.amountSourceUrl ?? charge.sourceUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (charge.pendingReason != null) Text(charge.pendingReason!),
          if (rates.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('trip-toll-category-${charge.stationId}'),
              initialValue: rates.any((r) => r.categoryCode == category)
                  ? category
                  : rates.first.categoryCode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Consultar categoría del peaje',
              ),
              items: [
                for (final item in rates)
                  DropdownMenuItem(
                    value: item.categoryCode,
                    child: Text('Categoría ${item.categoryCode}'),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
          const SizedBox(height: AppSpacing.s),
          Text(
            rate == null
                ? 'Descripción no disponible'
                : tollVehicleDescription(rate),
          ),
          Text(
            'Tarifa publicada: ${rate?.amountMinor == null ? 'Sin dato' : tripTollMoney(rate!.amountMinor!)}',
          ),
          if (rate?.boothBaseChargeMinor != null &&
              rate?.boothBaseChargeMinor != rate?.amountMinor)
            Text(
              'Importe de cobro condicionado: ${tripTollMoney(rate!.boothBaseChargeMinor!)}',
            ),
          if (rate?.conditions != null) Text(rate!.conditions!),
          if (rate?.sourceDate != null) Text('Fuente: ${rate!.sourceDate}'),
          if (station?.specialRates.isNotEmpty == true)
            const Text(
              'Tarifas especiales sujetas a elegibilidad; no aplicadas al presupuesto.',
            ),
          if (category != charge.categoryCode)
            const Text(
              'Consulta de tarifa; no modifica el vehículo ni valida la ruta para esta categoría.',
            ),
          if (source != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => widget.onSource(source),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Consultar fuente'),
              ),
            ),
        ],
      ),
    );
  }
}
