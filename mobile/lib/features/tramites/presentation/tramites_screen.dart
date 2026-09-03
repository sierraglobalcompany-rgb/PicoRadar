import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../vehicle_status/platform/external_launcher.dart';

const _reviewedAt = '2026-09-03';
const _disclaimer =
    'Esta lista es una ayuda de preparación. Confirma siempre los requisitos, '
    'costos, vigencia y disponibilidad en el portal oficial.';

enum _TramiteCity {
  medellin('Medellín'),
  bogota('Bogotá');

  const _TramiteCity(this.label);

  final String label;
}

class TramitesScreen extends ConsumerStatefulWidget {
  const TramitesScreen({super.key});

  @override
  ConsumerState<TramitesScreen> createState() => _TramitesScreenState();
}

class _TramitesScreenState extends ConsumerState<TramitesScreen> {
  _TramiteCity? _selectedCity;

  @override
  Widget build(BuildContext context) {
    final selectedCity = _selectedCity;
    return Scaffold(
      appBar: AppBar(title: const Text('Trámites')),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('tramites-screen'),
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
                  Text(
                    'Selecciona la ciudad donde realizarás el trámite.',
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Por ahora incluimos enlaces revisados de Medellín y Bogotá.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  SegmentedButton<_TramiteCity>(
                    key: const ValueKey('tramites-city-selector'),
                    segments: const [
                      ButtonSegment(
                        value: _TramiteCity.medellin,
                        label: Text('Medellín'),
                        icon: Icon(Icons.location_city_outlined),
                      ),
                      ButtonSegment(
                        value: _TramiteCity.bogota,
                        label: Text('Bogotá'),
                        icon: Icon(Icons.account_balance_outlined),
                      ),
                    ],
                    selected: selectedCity == null ? {} : {selectedCity},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (selection) {
                      setState(() => _selectedCity = selection.firstOrNull);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (selectedCity == null)
                    const _SelectCityPane()
                  else
                    _TramiteList(
                      city: selectedCity,
                      entries: _entriesFor(selectedCity),
                      onOpen: _showDetails,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(_TramiteEntry entry) {
    final checked = <String>{};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Padding(
                  key: const ValueKey('tramites-detail-sheet'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    0,
                    AppSpacing.l,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(entry.title, style: AppTextStyles.h2),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        entry.city.label,
                        key: const ValueKey('tramites-detail-city'),
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(entry.description, style: AppTextStyles.body),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        _disclaimer,
                        key: const ValueKey('tramites-disclaimer'),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      FilledButton.icon(
                        key: const ValueKey('tramites-open-official'),
                        onPressed: () => _openOfficial(entry.officialUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir portal oficial'),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        'Lista de preparación',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      for (final item in entry.preparationItems)
                        CheckboxListTile(
                          key: ValueKey('tramites-check-$item'),
                          value: checked.contains(item),
                          onChanged: (value) {
                            setSheetState(() {
                              if (value ?? false) {
                                checked.add(item);
                              } else {
                                checked.remove(item);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
                        ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Revisado $_reviewedAt',
                        key: const ValueKey('tramites-reviewed-at'),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openOfficial(String url) async {
    final opened = await ref.read(externalLauncherProvider).openExternal(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el portal oficial.')),
      );
    }
  }
}

class _SelectCityPane extends StatelessWidget {
  const _SelectCityPane();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('tramites-select-city'),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: Text('Elige Medellín o Bogotá para ver los trámites revisados.'),
      ),
    );
  }
}

class _TramiteList extends StatelessWidget {
  const _TramiteList({
    required this.city,
    required this.entries,
    required this.onOpen,
  });

  final _TramiteCity city;
  final List<_TramiteEntry> entries;
  final ValueChanged<_TramiteEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('tramites-list-${city.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${city.label}: trámites revisados',
          style: AppTextStyles.bodyStrong,
        ),
        const SizedBox(height: AppSpacing.m),
        for (final entry in entries) ...[
          _TramiteCard(entry: entry, onOpen: () => onOpen(entry)),
          const SizedBox(height: AppSpacing.s),
        ],
      ],
    );
  }
}

class _TramiteCard extends StatelessWidget {
  const _TramiteCard({required this.entry, required this.onOpen});

  final _TramiteEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: ValueKey('tramites-card-${entry.city.name}-${entry.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(entry.title, style: AppTextStyles.bodyStrong),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: ValueKey(
                      'tramites-open-${entry.city.name}-${entry.id}',
                    ),
                    onPressed: onOpen,
                    child: const Text('Ver preparación'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<_TramiteEntry> _entriesFor(_TramiteCity city) {
  return _tramites.where((entry) => entry.city == city).toList(growable: false);
}

class _TramiteEntry {
  const _TramiteEntry({
    required this.id,
    required this.city,
    required this.title,
    required this.description,
    required this.officialUrl,
    required this.preparationItems,
  });

  final String id;
  final _TramiteCity city;
  final String title;
  final String description;
  final String officialUrl;
  final List<String> preparationItems;
}

const _transferItems = [
  'Verificar inscripción RUNT de las partes.',
  'Confirmar SOAT vigente.',
  'Confirmar RTM cuando aplique.',
  'Revisar multas, impuestos y documentos de transferencia en el portal.',
];

const _duplicateItems = [
  'Verificar inscripción RUNT.',
  'Confirmar SOAT vigente.',
  'Revisar multas y obligaciones aplicables.',
  'Preparar identificación y autorización si actúa un tercero.',
];

const _registrationItems = [
  'Verificar inscripción RUNT.',
  'Tener factura y documentos de origen del vehículo.',
  'Confirmar SOAT y obligaciones tributarias aplicables.',
  'Revisar requisitos específicos del tipo de vehículo.',
];

const _certificateItems = [
  'Confirmar que el vehículo esté matriculado en la ciudad seleccionada.',
  'Tener placa y datos del solicitante.',
  'Revisar si el trámite es virtual o presencial.',
  'Confirmar tarifa y forma de entrega en el portal.',
];

const _tramites = [
  _TramiteEntry(
    id: 'traspaso',
    city: _TramiteCity.medellin,
    title: 'Traspaso de propiedad',
    description: 'Cambio de propiedad del vehículo ante la autoridad.',
    officialUrl: 'https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/',
    preparationItems: _transferItems,
  ),
  _TramiteEntry(
    id: 'duplicado',
    city: _TramiteCity.medellin,
    title: 'Duplicado de licencia de tránsito',
    description: 'Reposición del documento de tránsito del vehículo.',
    officialUrl: 'https://www.medellin.gov.co/es/tramites-y-servicios/como-sacar-el-duplicado-de-la-licencia-de-transito-de-un-vehiculo-automotor/',
    preparationItems: _duplicateItems,
  ),
  _TramiteEntry(
    id: 'matricula',
    city: _TramiteCity.medellin,
    title: 'Matrícula de vehículo',
    description: 'Registro inicial del vehículo ante la autoridad.',
    officialUrl: 'https://www.medellin.gov.co/es/tramites-y-servicios/matricula-de-vehiculos-automotores/',
    preparationItems: _registrationItems,
  ),
  _TramiteEntry(
    id: 'certificado',
    city: _TramiteCity.medellin,
    title: 'Certificado de libertad y tradición',
    description: 'Consulta oficial de estado registral del vehículo.',
    officialUrl: 'https://www.medellin.gov.co/es/tramites-y-servicios/certificado-de-libertad-y-tradicion-de-un-vehiculo-automotor/',
    preparationItems: _certificateItems,
  ),
  _TramiteEntry(
    id: 'traspaso',
    city: _TramiteCity.bogota,
    title: 'Traspaso de propiedad',
    description: 'Cambio de propiedad del vehículo ante la autoridad.',
    officialUrl:
        'https://www.ventanillamovilidad.com.co/tramites/traspaso-propiedad',
    preparationItems: _transferItems,
  ),
  _TramiteEntry(
    id: 'duplicado',
    city: _TramiteCity.bogota,
    title: 'Duplicado de licencia de tránsito',
    description: 'Reposición del documento de tránsito del vehículo.',
    officialUrl: 'https://www.ventanillamovilidad.com.co/tramites/duplicado-de-licencia-de-transito',
    preparationItems: _duplicateItems,
  ),
  _TramiteEntry(
    id: 'matricula',
    city: _TramiteCity.bogota,
    title: 'Matrícula de vehículo',
    description: 'Registro inicial del vehículo ante la autoridad.',
    officialUrl: 'https://www.ventanillamovilidad.com.co/tramites/matricula',
    preparationItems: _registrationItems,
  ),
  _TramiteEntry(
    id: 'certificado',
    city: _TramiteCity.bogota,
    title: 'Certificado de libertad y tradición',
    description: 'Consulta oficial de estado registral del vehículo.',
    officialUrl: 'https://www.ventanillamovilidad.com.co/tramites/certificado-de-libertad-y-tradicion',
    preparationItems: _certificateItems,
  ),
];
