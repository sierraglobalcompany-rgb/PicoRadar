part of 'comparendos_screen.dart';

const _secondaryText = Color(0xFF596F83);

class _VehicleSummary extends ConsumerWidget {
  const _VehicleSummary({
    required this.vehicle,
    required this.onCopyPlate,
    required this.onChoose,
  });
  final VehicleProfile vehicle;
  final VoidCallback onCopyPlate, onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = _nonEmpty(vehicle.registrationCity);
    final catalog = ref.watch(registrationCityCatalogProvider);
    final municipality = raw == null
        ? null
        : catalog.asData?.value.plateMunicipality(raw) ?? raw;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _vehicleDisplayName(vehicle),
                    key: const ValueKey('comparendos-vehicle-name'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (scale <= 1.1)
                  TextButton(
                    key: const ValueKey('comparendos-change-vehicle'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: onChoose,
                    child: const Text(
                      'Cambiar vehículo',
                      style: TextStyle(fontSize: 14),
                    ),
                  )
                else
                  IconButton(
                    key: const ValueKey('comparendos-change-vehicle'),
                    tooltip: 'Cambiar vehículo',
                    onPressed: onChoose,
                    icon: const Icon(Icons.swap_horiz),
                  ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final expanded = scale > 1.1;
                final plateWidth = math.min(
                  constraints.maxWidth - 56,
                  104 * scale,
                );
                final art = SizedBox(
                  key: const ValueKey('comparendos-vehicle-art'),
                  height: 90,
                  child: VehicleVisualImage(
                    vehicle: vehicle,
                    cacheWidth:
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    fallbackBuilder: (_) => Icon(
                      vehicleIcon(vehicle),
                      size: 64,
                      color: AppColors.teal,
                    ),
                  ),
                );
                final plate = SizedBox(
                  width: expanded ? plateWidth : 104,
                  child: VehiclePlateBadge(
                    key: const ValueKey('comparendos-plate'),
                    vehicle: vehicle,
                    compact: true,
                    compactWidth: 104,
                  ),
                );
                final copy = IconButton.outlined(
                  key: const ValueKey('comparendos-copy-plate'),
                  tooltip: 'Copiar placa',
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onCopyPlate,
                  icon: const Icon(Icons.copy_outlined),
                );
                if (expanded) {
                  return Column(
                    children: [
                      art,
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [plate, const SizedBox(width: 8), copy],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: art),
                    const SizedBox(width: 8),
                    plate,
                    const SizedBox(width: 8),
                    copy,
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              municipality == null
                  ? 'Matrícula sin registrar'
                  : 'Matrícula: $municipality',
              key: const ValueKey('comparendos-vehicle-type'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimitAction extends StatelessWidget {
  const _SimitAction({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey('comparendos-open-simit'),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onTap,
    child: Row(
      children: [
        const Icon(Icons.public, size: 32),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NACIONAL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                'Consultar en SIMIT',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Comparendos y multas a nivel nacional.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.open_in_new, size: 24),
      ],
    ),
  );
}

class _TerritorialConsultation extends StatelessWidget {
  const _TerritorialConsultation({
    required this.city,
    required this.authority,
    required this.multipleAuthorities,
    required this.temporary,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onChoose,
    required this.onChooseAuthority,
    required this.onOpen,
  });
  final TripMunicipality? city;
  final TerritorialAuthority? authority;
  final bool multipleAuthorities, temporary, loading, error;
  final VoidCallback onRetry, onChoose, onChooseAuthority;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final consultation = authority?.consultationUrl;
    final institutional = authority?.institutionalUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CONSULTA TERRITORIAL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          key: const ValueKey('comparendos-change-city'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onChoose,
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loading && city == null
                      ? 'Cargando ciudad…'
                      : city?.municipality ??
                            (authority != null
                                ? 'Autoridad seleccionada'
                                : 'Seleccionar ciudad'),
                  key: const ValueKey('comparendos-consultation-city'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
        if (city != null || authority != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              temporary
                  ? 'Consulta temporal'
                  : 'Sugerida por tu contexto de pico y placa',
              style: const TextStyle(fontSize: 14, color: _secondaryText),
            ),
          ),
        const SizedBox(height: 8),
        if (error)
          _LoadError(
            message: 'No pudimos cargar el directorio territorial. SIMIT sigue disponible.',
            onRetry: onRetry,
          )
        else if (loading)
          const Text('Cargando directorio…', style: TextStyle(fontSize: 14))
        else if (city != null || authority != null) ...[
          Row(
            children: [
              const Icon(Icons.location_city, size: 28, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  authority?.platformName ??
                      (multipleAuthorities
                          ? 'Selecciona la autoridad'
                          : 'Autoridad territorial por verificar'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (multipleAuthorities)
                IconButton(
                  tooltip: 'Cambiar autoridad',
                  onPressed: onChooseAuthority,
                  icon: const Icon(Icons.swap_horiz),
                ),
              if (authority != null)
                IconButton(
                  key: const ValueKey('comparendos-authority-info'),
                  tooltip: 'Información de la autoridad',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    showDragHandle: true,
                    builder: (_) => _AuthorityDetails(
                      authority: authority!,
                      onOpen: onOpen,
                    ),
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
            ],
          ),
          if (authority != null && authority!.name != authority!.platformName)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                authority!.name,
                style: const TextStyle(fontSize: 14, color: _secondaryText),
              ),
            ),
          if (authority != null && authority!.municipalityCodes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Ámbito territorial por verificar.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          if (consultation != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('comparendos-open-territorial'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => onOpen(consultation),
              icon: const Icon(Icons.open_in_new),
              label: Text(
                city == null
                    ? 'Consultar en el portal'
                    : 'Consultar en ${city!.municipality}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'Sin consulta directa verificada. SIMIT queda disponible como consulta nacional.',
              key: ValueKey('comparendos-unsupported-city'),
              style: TextStyle(fontSize: 14),
            ),
            if (institutional != null)
              OutlinedButton.icon(
                key: const ValueKey('comparendos-open-institutional'),
                onPressed: () => onOpen(institutional),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir web institucional'),
              ),
          ],
        ],
      ],
    );
  }
}

class _AuthorityDetails extends StatelessWidget {
  const _AuthorityDetails({required this.authority, required this.onOpen});
  final TerritorialAuthority authority;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(authority.name, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          if (authority.officeMunicipality.isNotEmpty)
            Text(
              'Sede registrada: ${authority.officeMunicipality} · ${authority.department}',
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 8),
          Text(
            authority.municipalityCodes.isEmpty
                ? 'Ámbito territorial por verificar. La sede no determina su competencia.'
                : 'Ámbito municipal comprobado en las fuentes de esta ficha.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            authority.verifiedAt == null
                ? 'Referencia histórica del directorio. Vigencia y enlaces pendientes de comprobación.'
                : 'Enlaces revisados: ${authority.verifiedAt}. Esta revisión no consulta tus comparendos.',
            style: const TextStyle(fontSize: 14),
          ),
          if (authority.evidenceUrl case final evidence?) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpen(evidence);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir fuente oficial'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CheckedAction extends StatelessWidget {
  const _CheckedAction({
    required this.checked,
    required this.saving,
    required this.onTap,
  });
  final bool checked, saving;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    key: const ValueKey('comparendos-mark-checked'),
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 64),
      padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: checked || saving ? null : onTap,
    child: Row(
      children: [
        Icon(checked ? Icons.event_available : Icons.today_outlined, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saving
                    ? 'Guardando…'
                    : checked
                    ? 'Consulta de hoy anotada'
                    : 'Marcar que consulté hoy',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Solo para tu control',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        if (checked) const Icon(Icons.check_circle_outline),
        if (saving)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    ),
  );
}

class _NoVehiclePane extends StatelessWidget {
  const _NoVehiclePane({required this.hasVehicles, required this.onChoose});
  final bool hasVehicles;
  final VoidCallback onChoose;
  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('comparendos-no-vehicle'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, size: 48),
          Text(
            hasVehicles ? 'Vehículo no disponible' : 'Agrega un vehículo',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 12),
          if (hasVehicles)
            FilledButton(
              onPressed: onChoose,
              child: const Text('Cambiar vehículo'),
            )
          else
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

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();
  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('comparendos-loading'),
    child: CircularProgressIndicator(),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    this.onChoose,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onChoose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(fontSize: 14)),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        if (onChoose != null)
          TextButton(
            onPressed: onChoose,
            child: const Text('Cambiar vehículo'),
          ),
      ],
    ),
  );
}
