import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../data/cda_catalog.dart';
import '../data/cda_geography.dart';
import 'cda_detail_sheet.dart';
import 'cda_directory_view.dart';
import 'cda_home_view.dart';
import 'cda_map_view.dart';

final cdaCatalogProvider = FutureProvider<CdaCatalog>(
  (ref) => loadCdaCatalog(rootBundle),
);
final cdaGeographyProvider = FutureProvider<CdaGeography>(
  (ref) => loadCdaGeography(rootBundle),
);

enum _CdaPage { home, directory, map }

class CdaFinderScreen extends ConsumerStatefulWidget {
  const CdaFinderScreen({super.key});
  @override
  ConsumerState<CdaFinderScreen> createState() => _CdaFinderScreenState();
}

class _CdaFinderScreenState extends ConsumerState<CdaFinderScreen> {
  _CdaPage _page = _CdaPage.home;
  bool _mapVisited = false;
  bool _nearMe = false;
  void _back() {
    if (_page != _CdaPage.home) {
      setState(() => _page = _CdaPage.home);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.maybeOf(context)?.go('/apps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(cdaCatalogProvider);
    final geography = ref.watch(cdaGeographyProvider);
    final now = ref.watch(bogotaNowProvider);
    final title = switch (_page) {
      _CdaPage.home => 'Buscar CDA',
      _CdaPage.directory => 'Directorio RUNT',
      _CdaPage.map => _nearMe ? 'CDA cerca de ti' : 'Explorar mapa',
    };
    return PopScope(
      canPop: _page == _CdaPage.home,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('cda-back'),
                      onPressed: _back,
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    if (_page != _CdaPage.home)
                      IconButton(
                        tooltip: 'Fuente y actualización',
                        onPressed: catalog.value == null
                            ? null
                            : () => showCdaSources(
                                context,
                                ref,
                                catalog.value!,
                                geography.value,
                                now,
                              ),
                        icon: const Icon(Icons.info_outline),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: catalog.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No se pudo abrir el catálogo CDA.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(cdaCatalogProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  data: (data) {
                    final geo = geography.value;
                    final coverage = geo?.coverage(data, now: now);
                    final operationalCatalog = _operationalCatalog(
                      data,
                      geo,
                      now,
                    );
                    void open(CdaCatalogEntry entry) => showCdaDetails(
                      context,
                      ref,
                      data,
                      entry,
                      geo?.byId[entry.id],
                      now,
                    );
                    return IndexedStack(
                      index: _page.index,
                      children: [
                        CdaHomeView(
                          catalog: data,
                          operationalCount:
                              coverage?.operationalTotal ??
                              operationalCatalog.entries.length,
                          geoReady: coverage?.mapEnabled ?? false,
                          onDirectory: () =>
                              setState(() => _page = _CdaPage.directory),
                          onMap: () => _openMap(
                            data,
                            operationalCatalog,
                            geo,
                            now,
                            false,
                          ),
                          onNearby: () => _openMap(
                            data,
                            operationalCatalog,
                            geo,
                            now,
                            true,
                          ),
                          onSource: () =>
                              showCdaSources(context, ref, data, geo, now),
                        ),
                        CdaDirectoryView(
                          catalog: operationalCatalog,
                          onOpen: open,
                          verifiedVehicleTypes: {
                            for (final entry in operationalCatalog.entries)
                              if (geo?.byId[entry.id]?.matches(entry) ?? false)
                                entry.id: geo!.byId[entry.id]!
                                    .verifiedVehicleTypes(now),
                          },
                        ),
                        if (_mapVisited && coverage?.mapEnabled == true)
                          CdaMapView(
                            key: ValueKey(_nearMe),
                            catalog: operationalCatalog,
                            geography: geo!,
                            onOpen: open,
                            now: now,
                            nearMe: _nearMe,
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMap(
    CdaCatalog fullCatalog,
    CdaCatalog operationalCatalog,
    CdaGeography? geo,
    DateTime now,
    bool nearby,
  ) async {
    final coverage = geo?.coverage(fullCatalog, now: now);
    if (coverage?.mapEnabled != true) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('cda-geography-gate'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ubicaciones por verificar',
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${coverage?.addressVerifiedCount ?? 0} de ${fullCatalog.entries.length} sedes con dirección respaldada.\n'
                    '${coverage?.mapEligibleCount ?? 0} tienen coordenada para mapa y cercanía.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mapa y cercanía estarán disponibles con el catálogo operativo enriquecido. Mientras tanto, puedes consultar el directorio por nombre o territorio.',
                    style: TextStyle(fontSize: 16),
                  ),
                  if (ref.read(cdaGeographyProvider).hasError)
                    TextButton.icon(
                      onPressed: () {
                        ref.invalidate(cdaGeographyProvider);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar datos de ubicación'),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _page = _CdaPage.directory);
                    },
                    child: const Text('Buscar en el directorio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _nearMe = nearby;
      _mapVisited = true;
      _page = _CdaPage.map;
    });
  }
}

CdaCatalog _operationalCatalog(
  CdaCatalog catalog,
  CdaGeography? geography,
  DateTime now,
) {
  if (geography == null) return catalog;
  final entries = catalog.entries
      .where((entry) {
        final site = geography.byId[entry.id];
        return site != null &&
            site.matches(entry) &&
            site.addressVerifiedAt(now);
      })
      .toList(growable: false);
  if (entries.isEmpty) return catalog;
  return CdaCatalog(
    source: catalog.source,
    metrics: catalog.metrics,
    entries: entries,
  );
}
