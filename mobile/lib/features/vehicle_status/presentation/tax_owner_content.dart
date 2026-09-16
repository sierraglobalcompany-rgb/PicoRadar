import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_clock.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_plate_badge.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../data/tax_catalog.dart';
import '../data/tax_authority_resolution.dart';
import '../domain/vehicle_obligation.dart';
import '../platform/external_launcher.dart';

part 'tax_owner_sheets.dart';

class TaxOwnerContent extends ConsumerStatefulWidget {
  const TaxOwnerContent({
    required this.vehicle,
    required this.obligation,
    super.key,
  });
  final VehicleProfile vehicle;
  final VehicleObligation? obligation;

  @override
  ConsumerState<TaxOwnerContent> createState() => _TaxOwnerContentState();
}

class _TaxOwnerContentState extends ConsumerState<TaxOwnerContent>
    with WidgetsBindingObserver {
  String? _previewAuthorityId;
  String? _savedOverride;
  int? _year;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(automatic: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(automatic: true);
  }

  Future<void> _refresh({bool automatic = false}) async {
    try {
      final result = await ref.read(taxCatalogRefreshProvider)(!automatic);
      if (!mounted || automatic) return;
      _notice(
        result
            ? 'Calendarios actualizados.'
            : 'Actualización remota no disponible en esta versión.',
      );
    } catch (_) {
      if (mounted) {
        _notice('No pudimos actualizar. Conservamos la información local.');
      }
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _preview(String id) => setState(() {
    _previewAuthorityId = id;
    _year = null;
  });

  void _changeYear(int year) => setState(() => _year = year);

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(taxCatalogProvider);
    final cities = ref.watch(registrationCityCatalogProvider);
    final today = ref.watch(
      bogotaNowProvider.select(
        (now) => DateTime.utc(now.year, now.month, now.day),
      ),
    );
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pudimos cargar las entidades tributarias.'),
              TextButton.icon(
                onPressed: () => ref.invalidate(taxCatalogProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (catalog) {
        final recoveryWarning = ref
            .watch(taxCatalogStoreProvider)
            .asData
            ?.value
            .lastLoadWarning;
        final suggested = suggestTaxAuthority(
          catalog,
          cities.asData?.value,
          widget.vehicle.registrationCity,
        );
        final saved =
            _savedOverride ?? widget.obligation?.details['authorityId'];
        final baseline = saved ?? suggested;
        final selectedId = _previewAuthorityId ?? baseline;
        final authority = catalog.authorityById(selectedId);
        final temporary = selectedId != null && selectedId != baseline;
        final year = _year ?? today.year;
        final calendar = authority == null
            ? null
            : catalog.calendarFor(authority.id, year);
        final active = calendar?.activeEvents ?? <TaxCalendarEvent>[];
        final upcoming = active
            .where((event) => !event.date.isBefore(today))
            .toList();
        final past = active
            .where((event) => event.date.isBefore(today))
            .toList();
        final stale = ref.watch(
          appClockProvider.select(
            (now) =>
                calendar?.reviewAfter != null &&
                !now.isBefore(calendar!.reviewAfter!),
          ),
        );
        final otherCalendars = catalog.calendars
            .where(
              (item) =>
                  item.authorityId == authority?.id &&
                  item.year == year &&
                  item.obligationKind != 'vehicle_tax',
            )
            .toList();
        final mismatch =
            saved != null &&
            suggested != null &&
            saved != suggested &&
            !temporary;
        return ListView(
          key: const PageStorageKey('tax-owner-scroll'),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _TaxHero(
              vehicle: widget.vehicle,
              authority: authority,
              onChoose: _saving
                  ? null
                  : () => _chooseAuthority(catalog, selectedId),
              caption: temporary
                  ? 'Consulta temporal'
                  : saved != null
                  ? 'Entidad guardada'
                  : 'Según matrícula',
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recoveryWarning != null) _TaxNotice(recoveryWarning),
                  if (temporary && authority != null)
                    TextButton.icon(
                      key: const ValueKey('tax-save-authority'),
                      onPressed: _saving ? null : () => _save(authority),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'Guardando…' : 'Guardar para este vehículo',
                      ),
                    ),
                  if (mismatch)
                    const _TaxNotice(
                      'La entidad guardada no coincide con la matrícula. Revisa cuál corresponde.',
                    ),
                  if (selectedId != null && authority == null)
                    const _TaxNotice(
                      'La entidad guardada no está disponible en este catálogo. Puedes consultar otra sin borrar lo guardado.',
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Calendario informativo. No calculamos deuda ni confirmamos pagos.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF53697E)),
                    ),
                  ),
                  if (widget.vehicle.kind == VehicleKind.motorcycle)
                    const _TaxNotice(
                      'En motos, la obligación depende de la cilindrada y de otros conceptos territoriales. Verifica las condiciones en la fuente oficial.',
                    ),
                  if (widget.vehicle.serviceType == VehicleServiceType.taxi)
                    const _TaxNotice(
                      'El servicio público puede tener obligaciones distintas al impuesto de particulares. Consulta las condiciones de la entidad.',
                    ),
                  if (authority == null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Selecciona la entidad correspondiente a la matrícula del vehículo.',
                    ),
                  ] else ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('tax-calendar-year'),
                          onPressed: () =>
                              _chooseYear(catalog, authority, today.year),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            'Calendario $year',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Fuente y revisión',
                          child: TextButton.icon(
                            key: const ValueKey('tax-source'),
                            onPressed: () => _information(authority, calendar),
                            icon: const Icon(Icons.info_outline, size: 20),
                            label: const Text(
                              'Fuente',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (authority.portalUrl != null ||
                        authority.institutionalUrl != null)
                      FilledButton.icon(
                        key: const ValueKey('tax-open-portal'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 52),
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _open(
                          authority.portalUrl ?? authority.institutionalUrl!,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          authority.portalUrl != null
                              ? 'Abrir portal oficial'
                              : 'Abrir sitio de la entidad',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (calendar == null ||
                        calendar.status == 'pending' ||
                        calendar.status == 'withdrawn')
                      _TaxNotice(
                        'Calendario $year pendiente de verificar. Consulta el portal oficial; no se han confirmado sus fechas.',
                      ),
                    if (calendar?.status == 'partial')
                      const _TaxNotice(
                        'Calendario parcial. Puede haber otros plazos o condiciones por verificar.',
                      ),
                    if (stale)
                      const _TaxNotice(
                        'La información requiere una nueva revisión. Verifica posibles cambios en el portal oficial.',
                      ),
                    if (year != today.year)
                      _TaxNotice(
                        'Estás consultando el calendario $year, no el año actual.',
                      ),
                    if (upcoming.isNotEmpty) ...[
                      const Text('Próximas fechas', style: _sectionTitle),
                      const SizedBox(height: 8),
                      for (final event in upcoming)
                        _TaxDateRow(event: event, today: today, year: year),
                    ],
                    if (past.isNotEmpty) ...[
                      if (upcoming.isEmpty &&
                          calendar?.status == 'verified' &&
                          !stale)
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            'Fechas publicadas finalizadas',
                            style: _sectionTitle,
                          ),
                        ),
                      ExpansionTile(
                        key: const ValueKey('tax-past-dates'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'Fechas anteriores (${past.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          for (final event in past)
                            _TaxDateRow(event: event, today: today, year: year),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    for (final other in otherCalendars)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_conceptLabel(other.obligationKind)),
                        subtitle: const Text(
                          'Otro concepto publicado; consulta sus condiciones',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _information(authority, other),
                      ),
                    ListTile(
                      key: const ValueKey('tax-more-information'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.description_outlined,
                        color: AppColors.navy,
                      ),
                      title: const Text(
                        'Más información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Condiciones, fuentes y actualización',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _information(authority, calendar),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(TaxAuthority authority) async {
    if (_saving) return;
    final vehicleId = widget.vehicle.id;
    setState(() => _saving = true);
    try {
      await ref
          .read(vehicleObligationStoreProvider)
          .saveTaxAuthority(vehicleId, authority.id);
      if (!mounted || widget.vehicle.id != vehicleId) return;
      setState(() {
        _savedOverride = authority.id;
        _previewAuthorityId = null;
      });
      ref.invalidate(
        vehicleObligationProvider((vehicleId, VehicleObligationType.tax)),
      );
      ref.invalidate(vehicleObligationsProvider(vehicleId));
      _notice('Entidad guardada para este vehículo.');
    } catch (_) {
      if (mounted) {
        _notice(
          'No pudimos guardar la entidad. Conservamos la anterior; vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _notice('El enlace no es válido. Consulta la información de la entidad.');
      return;
    }
    try {
      final opened = await ref.read(externalLauncherProvider).openExternal(url);
      if (mounted && !opened) _portalError(url);
    } catch (_) {
      if (mounted) _portalError(url);
    }
  }

  void _portalError(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No pudimos abrir el portal oficial.'),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: () => _open(url),
        ),
      ),
    );
  }
}

const _sectionTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
);

class _TaxHero extends StatelessWidget {
  const _TaxHero({
    required this.vehicle,
    required this.authority,
    required this.onChoose,
    required this.caption,
  });
  final VehicleProfile vehicle;
  final TaxAuthority? authority;
  final VoidCallback? onChoose;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final name =
        [vehicle.nickname, vehicle.brand]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .firstOrNull ??
        'Mi vehículo';
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: math.min(MediaQuery.sizeOf(context).width - 48, 96 * scale),
          child: VehiclePlateBadge(
            key: const ValueKey('tax-vehicle-plate'),
            vehicle: vehicle,
            compact: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      ],
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entidad tributaria',
          style: TextStyle(fontSize: 14, color: Color(0xFFC7DCE8)),
        ),
        const SizedBox(height: 4),
        Text(
          authority?.territoryName ?? 'Seleccionar entidad',
          key: const ValueKey('tax-authority-name'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        if (authority != null)
          Text(
            authority!.name,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
      ],
    );
    return ColoredBox(
      key: const ValueKey('tax-owner-hero'),
      color: AppColors.navy,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .13,
              child: Image.asset(
                'assets/pico/pico_personal_city_background_owner_v1.png',
                fit: BoxFit.cover,
                cacheWidth: 900,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (scale <= 1.1)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 12),
                      SizedBox(width: 110, child: identity),
                    ],
                  )
                else ...[
                  heading,
                  const SizedBox(height: 16),
                  identity,
                ],
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    if (authority != null)
                      Text(
                        caption,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC7DCE8),
                        ),
                      ),
                    TextButton.icon(
                      key: const ValueKey('tax-authority-field'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onChoose,
                      icon: const Icon(Icons.location_on_outlined, size: 20),
                      label: const Text(
                        'Buscar entidad',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxDateRow extends StatelessWidget {
  const _TaxDateRow({
    required this.event,
    required this.today,
    required this.year,
  });
  final TaxCalendarEvent event;
  final DateTime today;
  final int year;

  @override
  Widget build(BuildContext context) {
    final isToday = event.date == today;
    final date = Text(
      '${_shortDate(event.date)}${event.date.year != year ? ' ${event.date.year}' : ''}',
      style: TextStyle(
        fontSize: 14,
        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
        color: AppColors.navy,
      ),
    );
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isToday)
          const Text(
            'Hoy',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
        Text(
          event.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        if (event.condition != null)
          Text(
            event.condition!,
            style: const TextStyle(fontSize: 14, color: Color(0xFF53697E)),
          ),
      ],
    );
    return Semantics(
      label: '${event.date.day}/${event.date.month}/${event.date.year}',
      child: Container(
        key: ValueKey('tax-event-${event.id}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (MediaQuery.textScalerOf(context).scale(14) > 19 ||
                constraints.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [date, const SizedBox(height: 4), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 100, child: date),
                const SizedBox(width: 12),
                Expanded(child: detail),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaxNotice extends StatelessWidget {
  const _TaxNotice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF53697E)),
          ),
        ),
      ],
    ),
  );
}

String _shortDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _conceptLabel(String kind) => switch (kind) {
  'semaforizacion' => 'Semaforización',
  'sistematizacion' => 'Sistematización',
  _ => 'Impuesto vehicular',
};
