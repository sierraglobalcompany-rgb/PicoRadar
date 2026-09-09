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
    return 'Total por confirmar';
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
              : 'Estimación parcial',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.l),
        if (pricing == null)
          const Text('Las tarifas no están disponibles. Tu ruta sigue lista.'),
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
          const Divider(height: AppSpacing.l, color: AppColors.border),
          ExpansionTile(
            key: ValueKey('trip-route-toll-${charge.stationId}-$index'),
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.only(top: AppSpacing.s),
            expansionAnimationStyle: AnimationStyle(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.fade,
            ),
            title: _TollNamePrice(
              name: '${index + 1}. ${_tollName(charge.name)}',
              amount:
                  charge.amountMinor ??
                  charge.nominalMinor ??
                  charge.station
                      ?.generalRateByCategory(charge.categoryCode)
                      ?.amountMinor,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                charge.amountMinor != null ||
                        (charge.nominalMinor ??
                                charge.station
                                    ?.generalRateByCategory(charge.categoryCode)
                                    ?.amountMinor) ==
                            null
                    ? 'Categoría ${charge.categoryCode}'
                    : 'Categoría ${charge.categoryCode} · Tarifa de referencia, no sumada',
                style: AppTextStyles.caption,
              ),
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

class TripTollChargeDetails extends StatelessWidget {
  const TripTollChargeDetails({
    required this.charge,
    required this.onSource,
    super.key,
  });
  final LocalTollPricingCharge charge;
  final ValueChanged<String> onSource;

  @override
  Widget build(BuildContext context) {
    final station = charge.station;
    final rates = station?.generalRates ?? const <TollTariffRate>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (charge.amountMinor == null) ...[
            Text(_tollExclusionExplanation(charge), style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.l),
          ],
          if (station != null)
            OutlinedButton.icon(
              key: ValueKey('trip-toll-location-${charge.stationId}'),
              onPressed: () => onSource(
                Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': '${station.latitude},${station.longitude}',
                }).toString(),
              ),
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Ver ubicación en Google Maps'),
            ),
          const SizedBox(height: AppSpacing.l),
          const Text('Tarifas por categoría', style: AppTextStyles.bodyStrong),
          const Text('Valores publicados · COP', style: AppTextStyles.caption),
          for (final rate in rates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TollNamePrice(
                    name: 'Categoría ${rate.categoryCode}',
                    amount: rate.amountMinor,
                    strongName: false,
                  ),
                  if (tollVehicleDescription(rate) !=
                      'Descripción no disponible')
                    Text(
                      tollVehicleDescription(rate),
                      style: AppTextStyles.caption,
                    ),
                  if (rate.dataStatus == 'SOLO_PASO_EXCEPCIONAL_AUTORIZADO')
                    const Text(
                      'Solo con autorización',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
          if (rates.isEmpty) const Text('Tarifas no disponibles.'),
          ExpansionTile(
            key: ValueKey('trip-toll-conditions-${charge.stationId}'),
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text(
              'Condiciones y fuentes',
              style: AppTextStyles.caption,
            ),
            expansionAnimationStyle: AnimationStyle(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.fade,
            ),
            children: [
              const Text(
                'Las tarifas de otras categorías no cambian tu vehículo ni confirman que pueda circular por esta ruta.',
              ),
              if (station?.specialRates.isNotEmpty == true)
                const Text(
                  'Las tarifas especiales requieren cumplir condiciones y no están incluidas en la estimación.',
                ),
              for (final rate in rates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Categoría ${rate.categoryCode}',
                        style: AppTextStyles.bodyStrong,
                      ),
                      Text(tollVehicleDescription(rate)),
                      if (rate.boothBaseChargeMinor != null &&
                          rate.boothBaseChargeMinor != rate.amountMinor)
                        Text(
                          'Importe condicionado: ${tripTollMoney(rate.boothBaseChargeMinor!)}',
                        ),
                      if (rate.conditions != null) Text(rate.conditions!),
                      if (rate.sourceDate != null)
                        Text('Fecha de la fuente: ${rate.sourceDate}'),
                      if ((rate.chargeSourceUrl ??
                              rate.amountSourceUrl ??
                              charge.sourceUrl)
                          case final String source)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => onSource(source),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              'Fuente · categoría ${rate.categoryCode}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TollNamePrice extends StatelessWidget {
  const _TollNamePrice({
    required this.name,
    required this.amount,
    this.strongName = true,
  });
  final String name;
  final int? amount;
  final bool strongName;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(
        name,
        style: strongName ? AppTextStyles.bodyStrong : AppTextStyles.body,
      );
      final price = Text(
        amount == null
            ? 'Tarifa no disponible'
            : tripTollMoney(amount!).replaceFirst('COP ', r'$ '),
        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.teal),
      );
      if (constraints.maxWidth < 275 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: AppSpacing.xs),
            price,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: AppSpacing.s),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
            child: price,
          ),
        ],
      );
    },
  );
}

String _tollName(String name) {
  if (name != name.toUpperCase()) return name;
  return name
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _tollExclusionExplanation(
  LocalTollPricingCharge charge,
) => switch (charge.pendingReason) {
  'Sentido y condición de cobro por confirmar' =>
    'Depende del sentido del viaje. Por eso no está sumada.',
  'Suspensión: vigencia y categoría por confirmar' => 'El cobro tiene una suspensión por verificar. Esta tarifa es de referencia y no está sumada al total.',
  'Paso excepcional: requiere autorización' =>
    'Este paso requiere autorización. Su tarifa no está sumada al total.',
  'Operación pendiente de verificar' ||
  'Cobro bloqueado por revisión de datos' => 'No está confirmado que este peaje esté cobrando. Su tarifa no está sumada al total.',
  _ =>
    'No tenemos una tarifa confirmada para este paso. No está sumado al total.',
};
