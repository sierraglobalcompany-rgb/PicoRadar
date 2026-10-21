part of 'comparendos_screen.dart';

class _VehicleChooser extends ConsumerWidget {
  const _VehicleChooser();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Cambiar vehículo', style: AppTextStyles.h2),
          ),
          Expanded(
            child: ref
                .watch(vehicleListProvider)
                .when(
                  loading: () => const _LoadingPane(),
                  error: (_, _) => _LoadError(
                    message: 'No pudimos cargar tus vehículos.',
                    onRetry: () => ref.invalidate(vehicleListProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('No hay vehículos guardados.'))
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final vehicle = items[index];
                            return ListTile(
                              key: ValueKey('comparendos-choose-${vehicle.id}'),
                              minVerticalPadding: 12,
                              leading: SizedBox(
                                width: 64,
                                height: 56,
                                child: VehicleVisualImage(
                                  vehicle: vehicle,
                                  cacheWidth: 160,
                                  fallbackBuilder: (_) =>
                                      Icon(vehicleIcon(vehicle)),
                                ),
                              ),
                              title: Text(_vehicleDisplayName(vehicle)),
                              subtitle: Text(vehicle.plate),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(context, vehicle.id),
                            );
                          },
                        ),
                ),
          ),
        ],
      ),
    ),
  );
}

class _TerritorialSelection {
  const _TerritorialSelection({this.city, this.authorityId});
  final TripMunicipality? city;
  final String? authorityId;
}

class _CityChooser extends ConsumerStatefulWidget {
  const _CityChooser();
  @override
  ConsumerState<_CityChooser> createState() => _CityChooserState();
}

class _CityChooserState extends ConsumerState<_CityChooser> {
  String _query = '';
  bool _showAuthorities = false;
  @override
  Widget build(BuildContext context) {
    final municipalities = ref.watch(tripMunicipalityCatalogProvider);
    final authorities = ref.watch(territorialCatalogProvider).asData?.value;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: math.max(
            200,
            MediaQuery.sizeOf(context).height * .9 -
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Ciudad o autoridad', style: AppTextStyles.h2),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('comparendos-city-search'),
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: municipalities.when(
                  loading: () => const _LoadingPane(),
                  error: (_, _) => _LoadError(
                    message: 'No pudimos cargar las ciudades.',
                    onRetry: () =>
                        ref.invalidate(tripMunicipalityCatalogProvider),
                  ),
                  data: (catalog) {
                    final query = normalizeTerritorialText(_query);
                    final authorityCodes = <String>{
                      for (final a
                          in authorities?.authorities ??
                              <TerritorialAuthority>[])
                        if (query.isNotEmpty &&
                            normalizeTerritorialText(
                              '${a.name} ${a.platformName}',
                            ).contains(query))
                          ...a.municipalityCodes,
                    };
                    final rows =
                        catalog.records
                            .where(
                              (city) =>
                                  query.isEmpty ||
                                  normalizeTerritorialText(city.displayName)
                                      .contains(query) ||
                                  authorityCodes.contains(city.code),
                            )
                            .toList()
                          ..sort(
                            (a, b) => normalizeTerritorialText(a.displayName)
                                .compareTo(
                                  normalizeTerritorialText(b.displayName),
                                ),
                          );
                    final authorityRows =
                        ((_showAuthorities || query.isNotEmpty)
                                ? authorities?.search(query) ??
                                      <TerritorialAuthority>[]
                                : <TerritorialAuthority>[])
                            .toList()
                          ..sort(
                            (a, b) => normalizeTerritorialText(a.name)
                                .compareTo(normalizeTerritorialText(b.name)),
                          );
                    final cityRows = _showAuthorities
                        ? <TripMunicipality>[]
                        : rows;
                    final modeRowCount = query.isEmpty ? 1 : 0;
                    if (cityRows.isEmpty &&
                        authorityRows.isEmpty &&
                        query.isNotEmpty) {
                      return const Center(child: Text('Sin coincidencias'));
                    }
                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount:
                          modeRowCount + cityRows.length + authorityRows.length,
                      itemBuilder: (context, index) {
                        if (index == 0 && modeRowCount == 1) {
                          return ListTile(
                            key: const ValueKey('comparendos-directory-mode'),
                            leading: Icon(
                              _showAuthorities
                                  ? Icons.location_city
                                  : Icons.account_balance_outlined,
                            ),
                            title: Text(
                              _showAuthorities
                                  ? 'Buscar ciudades'
                                  : 'Ver autoridades del directorio',
                            ),
                            onTap: () => setState(
                              () => _showAuthorities = !_showAuthorities,
                            ),
                          );
                        }
                        final resultIndex = index - modeRowCount;
                        if (resultIndex >= cityRows.length) {
                          final authority =
                              authorityRows[resultIndex - cityRows.length];
                          final verifiedCity =
                              authority.municipalityCodes.length == 1
                              ? catalog.records
                                    .where(
                                      (m) =>
                                          m.code ==
                                          authority.municipalityCodes.single,
                                    )
                                    .firstOrNull
                              : null;
                          return ListTile(
                            key: ValueKey(
                              'comparendos-authority-${authority.id}',
                            ),
                            minVerticalPadding: 12,
                            title: Text(authority.name),
                            subtitle: Text(
                              '${authority.department}${authority.officeMunicipality.isEmpty ? '' : ' · Sede: ${authority.officeMunicipality}'}${authority.municipalityCodes.isEmpty ? '\nÁmbito territorial por verificar' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(
                                context,
                                _TerritorialSelection(
                                  city: verifiedCity,
                                  authorityId: authority.id,
                                ),
                              );
                            },
                          );
                        }
                        final city = cityRows[resultIndex];
                        final known =
                            authorities?.forMunicipality(city.code) ??
                            <TerritorialAuthority>[];
                        return ListTile(
                          key: ValueKey('comparendos-city-${city.code}'),
                          minVerticalPadding: 12,
                          title: Text(city.municipality),
                          subtitle: Text(
                            '${city.department}${known.isEmpty ? ' · Autoridad por verificar' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(
                              context,
                              _TerritorialSelection(city: city),
                            );
                          },
                        );
                      },
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
}
