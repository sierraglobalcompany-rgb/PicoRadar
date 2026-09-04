import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/location/application/location_controller.dart';
import '../../../features/location/domain/jurisdiction_location_resolver.dart';
import '../../../features/location/platform/device_location_gateway.dart';
import '../../../features/vehicle_status/platform/external_launcher.dart';
import '../data/cda_catalog.dart';

final cdaCatalogProvider = FutureProvider<CdaCatalog>((ref) {
  return loadCdaCatalog(rootBundle);
});

class CdaFinderScreen extends ConsumerStatefulWidget {
  const CdaFinderScreen({super.key});

  @override
  ConsumerState<CdaFinderScreen> createState() => _CdaFinderScreenState();
}

class _CdaFinderScreenState extends ConsumerState<CdaFinderScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _locationMunicipality;
  String? _locationLabel;
  String? _locationMessage;
  bool _locating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(cdaCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar CDA')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MessagePane(message: error.toString()),
          data: _buildCatalog,
        ),
      ),
    );
  }

  Widget _buildCatalog(CdaCatalog catalog) {
    final now = ref.watch(bogotaNowProvider);
    final effectiveQuery = _locationMunicipality ?? _query;
    final results = searchCdaCatalog(catalog.entries, effectiveQuery);
    final visibleResults = results.take(40).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        96,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchHeader(
                  controller: _searchController,
                  locating: _locating,
                  onUseLocation: () => _useLocation(catalog),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _locationMunicipality = null;
                      _locationLabel = null;
                      _locationMessage = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  _locationLabel ?? cdaCatalogUpdateLabel(catalog),
                  style: AppTextStyles.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${results.length} CDA · orden alfabético oficial',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.68),
                  ),
                ),
                if (_locationMessage != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  _InfoBanner(message: _locationMessage!),
                ],
                if (isCdaCatalogStale(catalog, now)) ...[
                  const SizedBox(height: AppSpacing.s),
                  const _InfoBanner(
                    message:
                        'Actualización oficial pendiente en Datos Abiertos.',
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                if (visibleResults.isEmpty)
                  const _MessagePane(
                    message: 'No encontramos CDA con esa búsqueda.',
                  )
                else
                  for (final entry in visibleResults) ...[
                    _CdaResultCard(
                      entry: entry,
                      sourceUrl: catalog.source.sourceUrl,
                    ),
                    const SizedBox(height: AppSpacing.s),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _useLocation(CdaCatalog catalog) async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final gateway = ref.read(deviceLocationGatewayProvider);
      if (!await gateway.isLocationServiceEnabled()) {
        _finishLocation(
          message: 'Activa la ubicación para filtrar por ciudad.',
        );
        return;
      }
      var permission = await gateway.checkPermission();
      if (permission != DeviceLocationPermission.granted) {
        permission = await gateway.requestPermission();
      }
      if (permission != DeviceLocationPermission.granted) {
        _finishLocation(message: 'Permiso de ubicación no concedido.');
        return;
      }
      final result = await gateway.getCurrentPosition();
      if (result is! DeviceLocationSuccess) {
        _finishLocation(message: 'No pudimos leer tu ubicación actual.');
        return;
      }
      final municipality = _municipalityForPoint(result.point);
      if (municipality == null) {
        _finishLocation(
          message: 'No pudimos asociar esta ubicación a una ciudad soportada sin coordenadas oficiales de CDA.',
        );
        return;
      }
      final matchCount = searchCdaCatalog(catalog.entries, municipality).length;
      final label = _friendlyMunicipality(municipality);
      setState(() {
        _locating = false;
        _locationMunicipality = municipality;
        _locationLabel = 'CDA en $label · según tu ubicación';
        _locationMessage = '$matchCount resultados del catálogo RUNT.';
        _query = '';
        _searchController.clear();
      });
    } finally {
      if (mounted && _locating) {
        setState(() => _locating = false);
      }
    }
  }

  void _finishLocation({required String message}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      _locationMessage = message;
    });
  }

  String? _municipalityForPoint(DeviceLocationPoint point) {
    final matches = <({String municipality, double distanceKm})>[];
    for (final hint in jurisdictionLocationHints) {
      final distanceKm = haversineDistanceKm(
        point.latitude,
        point.longitude,
        hint.centerLat,
        hint.centerLon,
      );
      if (distanceKm <= hint.maxDetectionRadiusKm) {
        matches.add((
          municipality: switch (hint.jurisdictionId) {
            'co-dc-bogota' => 'BOGOTA',
            'co-ant-medellin' => 'MEDELLIN',
            _ => '',
          },
          distanceKm: distanceKm,
        ));
      }
    }
    matches.removeWhere((match) => match.municipality.isEmpty);
    matches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return matches.isEmpty ? null : matches.first.municipality;
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.locating,
    required this.onUseLocation,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool locating;
  final VoidCallback onUseLocation;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const ValueKey('cda-use-location'),
              onPressed: locating ? null : onUseLocation,
              icon: locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Usar mi ubicación'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('cda-search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar ciudad o CDA',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CdaResultCard extends ConsumerWidget {
  const _CdaResultCard({required this.entry, required this.sourceUrl});

  final CdaCatalogEntry entry;
  final String sourceUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      key: ValueKey('cda-result-${entry.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _showDetails(context, ref, entry, sourceUrl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.plateYellow,
                child: Icon(Icons.car_repair_outlined),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entry.municipality} · ${entry.department}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const _RuntBadge(),
                  ],
                ),
              ),
              TextButton(
                key: ValueKey('cda-detail-${entry.id}'),
                onPressed: () => _showDetails(context, ref, entry, sourceUrl),
                child: const Text('Ver detalles'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    CdaCatalogEntry entry,
    String sourceUrl,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('cda-detail-sheet'),
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
                  Text(entry.name, style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.s),
                  Text('${entry.municipality} · ${entry.department}'),
                  const SizedBox(height: AppSpacing.m),
                  _DetailLine(
                    label: 'Estado de fuente oficial',
                    value: 'CDA certificado',
                  ),
                  _DetailLine(
                    label: 'Actualizado en catálogo',
                    value:
                        '${_friendlyMonth(entry.sourceMonth)} ${entry.sourceYear}',
                  ),
                  const _DetailLine(
                    label: 'Fuente',
                    value: 'RUNT / MinTransporte',
                  ),
                  const _DetailLine(
                    label: 'Dirección / teléfono',
                    value: 'No publicado en la fuente RUNT.',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  FilledButton.icon(
                    key: const ValueKey('cda-open-directions'),
                    onPressed: () => _openExternal(
                      context,
                      ref,
                      _googleMapsSearchUrl(entry),
                      'No pudimos abrir Google Maps.',
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    key: const ValueKey('cda-open-waze'),
                    onPressed: () => _openExternal(
                      context,
                      ref,
                      _wazeSearchUrl(entry),
                      'No pudimos abrir Waze.',
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Abrir en Waze'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    key: const ValueKey('cda-open-source'),
                    onPressed: () => _openExternal(
                      context,
                      ref,
                      sourceUrl,
                      'No pudimos abrir la fuente oficial.',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir fuente oficial'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
}

String _googleMapsSearchUrl(CdaCatalogEntry entry) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': _navigationQuery(entry),
  }).toString();
}

String _wazeSearchUrl(CdaCatalogEntry entry) {
  return Uri.https('waze.com', '/ul', {
    'q': _navigationQuery(entry),
    'navigate': 'yes',
  }).toString();
}

String _navigationQuery(CdaCatalogEntry entry) {
  return '${entry.name}, ${entry.municipality}, ${entry.department}, Colombia';
}

class _RuntBadge extends StatelessWidget {
  const _RuntBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Catálogo RUNT',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.plateYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.plateYellow),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Text(message, style: AppTextStyles.caption),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(value),
        ],
      ),
    );
  }
}

String _friendlyMunicipality(String value) {
  return switch (value) {
    'BOGOTA' => 'Bogotá',
    'MEDELLIN' => 'Medellín',
    _ => value,
  };
}

String _friendlyMonth(int month) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return months[month - 1];
}
