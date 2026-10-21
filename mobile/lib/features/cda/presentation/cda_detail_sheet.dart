import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/cda_catalog.dart';
import '../data/cda_geography.dart';

Future<void> showCdaDetails(
  BuildContext context,
  WidgetRef ref,
  CdaCatalog catalog,
  CdaCatalogEntry entry,
  CdaSite? site,
  DateTime now,
) {
  final matchedSite = (site?.matches(entry) ?? false) ? site : null;
  return _showCdaSheet(
    context,
    child: _CdaDetailContent(
      catalog: catalog,
      entry: entry,
      site: matchedSite,
      now: now,
    ),
  );
}

Future<void> showCdaSources(
  BuildContext context,
  WidgetRef ref,
  CdaCatalog catalog,
  CdaGeography? geography,
  DateTime now,
) {
  final coverage = geography?.coverage(catalog, now: now);
  return _showCdaSheet(
    context,
    child: _CdaSourcesContent(catalog: catalog, coverage: coverage),
  );
}

Future<void> _showCdaSheet(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.84,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: child,
        ),
      ),
    ),
  );
}

class _CdaDetailContent extends ConsumerWidget {
  const _CdaDetailContent({
    required this.catalog,
    required this.entry,
    required this.site,
    required this.now,
  });

  final CdaCatalog catalog;
  final CdaCatalogEntry entry;
  final CdaSite? site;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verifiedSite = site?.verifiedAt(now) ?? false;
    final mapEligibleSite = site?.mapEligibleAt(now) ?? false;
    final addressVerified = site?.addressVerifiedAt(now) ?? false;
    final types = site?.verifiedVehicleTypes(now) ?? const <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(entry.name, style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          '${entry.municipality} · ${entry.department}',
          style: AppTextStyles.body.copyWith(color: AppColors.navy),
        ),
        const SizedBox(height: 16),
        _FactTile(
          icon: Icons.verified_outlined,
          title: 'Catálogo RUNT',
          body:
              'Incluido en el catálogo ${catalog.source.latestSourceMonthName.toLowerCase()} ${catalog.source.latestSourceYear}. Esto no confirma acreditación vigente en tiempo real.',
        ),
        _FactTile(
          icon: Icons.location_on_outlined,
          title: 'Ubicación',
          body: addressVerified
              ? verifiedSite
                    ? site!.address!
                    : site!.mapEligibleAt(now)
                    ? '${site!.address!}\nUbicación aproximada desde dirección.'
                    : '${site!.address!}\nCoordenada pendiente de verificación.'
              : 'Ubicación de esta sede por verificar.',
        ),
        _FactTile(
          icon: Icons.directions_car_outlined,
          title: 'Compatibilidad',
          body: _compatibility(types),
        ),
        if (site?.phone != null && (site?.contactsVerifiedAt(now) ?? false))
          _CdaAction(
            icon: Icons.phone_outlined,
            label: 'Llamar al CDA',
            run: (launcher) => launcher.callPhone(site!.phone!),
          ),
        if (site?.web != null && (site?.contactsVerifiedAt(now) ?? false))
          _CdaAction(
            icon: Icons.open_in_new,
            label: 'Abrir web',
            run: (launcher) => launcher.openExternal(site!.web!),
          ),
        if (mapEligibleSite) ...[
          _CdaAction(
            icon: Icons.map_outlined,
            label: 'Abrir en Google Maps',
            run: (launcher) => launcher.openExternal(
              'https://www.google.com/maps/search/?api=1&query=${site!.latitude},${site!.longitude}',
            ),
          ),
          _CdaAction(
            icon: Icons.navigation_outlined,
            label: 'Abrir en Waze',
            run: (launcher) => launcher.openExternal(
              'https://waze.com/ul?ll=${site!.latitude},${site!.longitude}&navigate=yes',
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          key: const ValueKey('cda-open-source'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => showCdaSources(context, ref, catalog, null, now),
          icon: const Icon(Icons.info_outline),
          label: const Text('Fuente y actualización'),
        ),
      ],
    );
  }
}

class _CdaSourcesContent extends StatelessWidget {
  const _CdaSourcesContent({required this.catalog, required this.coverage});

  final CdaCatalog catalog;
  final CdaCoverage? coverage;

  @override
  Widget build(BuildContext context) {
    final source = catalog.source;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Fuente y actualización', style: AppTextStyles.h2),
        const SizedBox(height: 16),
        _FactTile(
          icon: Icons.dataset_outlined,
          title: 'Inventario',
          body:
              '${catalog.entries.length} CDA incluidos desde ${source.provider} · ${source.latestSourceMonthName.toLowerCase()} ${source.latestSourceYear}.',
        ),
        _FactTile(
          icon: Icons.map_outlined,
          title: 'Ubicaciones',
          body:
              '${coverage?.operationalTotal ?? 0} CDA con dirección y coordenada para mapa. '
              '${coverage?.missingInventoryCount ?? catalog.entries.length} registros pendientes no incluidos todavía.',
        ),
        const _FactTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacidad',
          body: 'Buscar en el directorio no usa GPS. Al abrir un mapa con teselas, el proveedor del mapa puede conocer el área visualizada.',
        ),
        _CdaExternalLink(label: 'Abrir fuente RUNT', url: source.sourceUrl),
        const _CdaExternalLink(
          label: 'Licencia y términos de datos abiertos',
          url: 'https://www.datos.gov.co/',
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.teal),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 2),
              Text(body, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CdaExternalLink extends StatelessWidget {
  const _CdaExternalLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => _CdaAction(
    icon: Icons.open_in_new,
    label: label,
    run: (launcher) => launcher.openExternal(url),
  );
}

class _CdaAction extends ConsumerStatefulWidget {
  const _CdaAction({
    required this.icon,
    required this.label,
    required this.run,
  });

  final IconData icon;
  final String label;
  final Future<bool> Function(ExternalLauncher launcher) run;

  @override
  ConsumerState<_CdaAction> createState() => _CdaActionState();
}

class _CdaActionState extends ConsumerState<_CdaAction> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await widget.run(ref.read(externalLauncherProvider));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = opened
          ? null
          : 'No se pudo abrir. Toca de nuevo para reintentar.';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.centerLeft,
          ),
          onPressed: _busy ? null : _run,
          icon: Icon(widget.icon),
          label: Text(widget.label),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: AppTextStyles.caption.copyWith(color: AppColors.red),
          ),
        ],
      ],
    ),
  );
}

String _compatibility(Set<String> types) {
  if (types.contains('car') && types.contains('motorcycle')) {
    return 'Carros y motos con evidencia publicada.';
  }
  if (types.contains('car')) return 'Carros con evidencia publicada.';
  if (types.contains('motorcycle')) return 'Motos con evidencia publicada.';
  return 'Por confirmar. El catálogo RUNT no trae compatibilidad por tipo.';
}
