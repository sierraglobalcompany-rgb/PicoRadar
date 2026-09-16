import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../cda/presentation/cda_finder_screen.dart';
import '../../location/application/location_controller.dart';
import '../../location/domain/jurisdiction_location_resolver.dart';
import '../../location/platform/device_location_gateway.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/google_maps_service_search.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.onOpenCda});

  final VoidCallback? onOpenCda;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String? _loadingActionKey;
  int _locationOperation = 0;
  int _pillLocationOperation = 0;
  _LocationPillState _locationPill = const _LocationPillState.idle();
  RegistrationCity? _selectedFallbackCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocationPill(requestPermission: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('services-screen'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.xs,
            AppSpacing.l,
            AppSpacing.s,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopChrome(
                      location: _locationPill,
                      onRefresh: _handleLocationPillTap,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const _ServicesHero(),
                    const SizedBox(height: AppSpacing.xs),
                    _PrimaryServiceCard(
                      action: _towAction,
                      loading: _loadingActionKey == _towAction.key,
                      onTap: () => _openNearbySearch(_towAction),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Otras necesidades',
                      style: AppTextStyles.h2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CompactServicesGrid(
                      actions: _secondaryActions,
                      loadingActionKey: _loadingActionKey,
                      onTap: _openNearbySearch,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'CDA en PicoRadar',
                      style: AppTextStyles.h2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CdaCard(onTap: _openCda),
                    const SizedBox(height: AppSpacing.xs),
                    const _ServicesDisclaimer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCda() {
    final callback = widget.onOpenCda;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const CdaFinderScreen()),
    );
  }

  Future<void> _openNearbySearch(_ServiceSearchAction action) async {
    if (_loadingActionKey != null) {
      return;
    }
    final operation = ++_locationOperation;
    setState(() => _loadingActionKey = action.key);
    final result = await _readCurrentLocation();
    if (!mounted || operation != _locationOperation) {
      return;
    }
    setState(() => _loadingActionKey = null);

    switch (result) {
      case _ResolvedLocation(:final point):
        _selectedFallbackCity = null;
        _setLocationPillFromPoint(point);
        final uri = googleMapsNearbyServiceSearchUri(
          category: action.category,
          latitude: point.latitude,
          longitude: point.longitude,
        );
        await _launchGoogleMaps(uri);
      case _LocationFailed(:final failure):
        final fallbackCity = _selectedFallbackCity;
        if (fallbackCity != null) {
          setState(
            () => _locationPill = _LocationPillState.fallback(
              fallbackCity.municipality,
            ),
          );
          await _launchCitySearch(action, fallbackCity);
          return;
        }
        _setLocationPillFailure(failure);
        await _handleLocationFailure(failure, action: action);
    }
  }

  Future<void> _handleLocationPillTap() async {
    final failure = await _refreshLocationPill(requestPermission: true);
    if (!mounted || failure == null) {
      return;
    }
    await _handleLocationFailure(failure);
  }

  Future<DeviceLocationFailure?> _refreshLocationPill({
    required bool requestPermission,
  }) async {
    final operation = ++_pillLocationOperation;
    if (mounted) {
      setState(() => _locationPill = const _LocationPillState.detecting());
    }
    final gateway = ref.read(deviceLocationGatewayProvider);
    final serviceEnabled = await gateway.isLocationServiceEnabled();
    if (!mounted || operation != _pillLocationOperation) {
      return null;
    }
    if (!serviceEnabled) {
      const failure = DeviceLocationFailure.serviceDisabled;
      setState(() => _locationPill = const _LocationPillState.failed(failure));
      return failure;
    }

    var permission = await gateway.checkPermission();
    if (!mounted || operation != _pillLocationOperation) {
      return null;
    }
    if (permission != DeviceLocationPermission.granted) {
      if (!requestPermission) {
        setState(() => _locationPill = const _LocationPillState.idle());
        return null;
      }
      permission = await gateway.requestPermission();
      if (!mounted || operation != _pillLocationOperation) {
        return null;
      }
    }
    if (permission != DeviceLocationPermission.granted) {
      final failure = permission == DeviceLocationPermission.deniedForever
          ? DeviceLocationFailure.permissionDeniedForever
          : DeviceLocationFailure.permissionDenied;
      setState(() => _locationPill = _LocationPillState.failed(failure));
      return failure;
    }

    final result = await gateway.getCurrentPosition();
    if (!mounted || operation != _pillLocationOperation) {
      return null;
    }
    switch (result) {
      case DeviceLocationSuccess(:final point) when _isValidPoint(point):
        _selectedFallbackCity = null;
        _setLocationPillFromPoint(point);
        return null;
      case DeviceLocationSuccess() || DeviceLocationError():
        const failure = DeviceLocationFailure.positionUnavailable;
        _setLocationPillFailure(failure);
        return failure;
    }
  }

  void _setLocationPillFromPoint(DeviceLocationPoint point) {
    final label = _cityLabelForPoint(point) ?? 'GPS activo';
    if (mounted) {
      setState(() => _locationPill = _LocationPillState.detected(label));
    }
  }

  void _setLocationPillFailure(DeviceLocationFailure failure) {
    if (mounted) {
      setState(() => _locationPill = _LocationPillState.failed(failure));
    }
  }

  String? _cityLabelForPoint(DeviceLocationPoint point) {
    final matches = <({String label, double distanceKm})>[];
    for (final hint in jurisdictionLocationHints) {
      final label = _serviceLocationLabels[hint.jurisdictionId];
      if (label == null) {
        continue;
      }
      final distanceKm = haversineDistanceKm(
        point.latitude,
        point.longitude,
        hint.centerLat,
        hint.centerLon,
      );
      if (distanceKm <= hint.maxDetectionRadiusKm) {
        matches.add((label: label, distanceKm: distanceKm));
      }
    }
    matches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return matches.isEmpty ? null : matches.first.label;
  }

  Future<_LocationSearchResult> _readCurrentLocation() async {
    final gateway = ref.read(deviceLocationGatewayProvider);
    final serviceEnabled = await gateway.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const _LocationFailed(DeviceLocationFailure.serviceDisabled);
    }

    var permission = await gateway.checkPermission();
    if (permission == DeviceLocationPermission.denied ||
        permission == DeviceLocationPermission.notRequested) {
      permission = await gateway.requestPermission();
    }
    if (permission == DeviceLocationPermission.denied) {
      return const _LocationFailed(DeviceLocationFailure.permissionDenied);
    }
    if (permission == DeviceLocationPermission.deniedForever) {
      return const _LocationFailed(
        DeviceLocationFailure.permissionDeniedForever,
      );
    }

    final current = await gateway.getCurrentPosition();
    return switch (current) {
      DeviceLocationSuccess(:final point) when _isValidPoint(point) =>
        _ResolvedLocation(point),
      DeviceLocationSuccess() || DeviceLocationError() => const _LocationFailed(
        DeviceLocationFailure.positionUnavailable,
      ),
    };
  }

  bool _isValidPoint(DeviceLocationPoint point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.accuracyMeters.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  Future<void> _handleLocationFailure(
    DeviceLocationFailure failure, {
    _ServiceSearchAction? action,
  }) async {
    if (!mounted) {
      return;
    }
    final choice = await showModalBottomSheet<_LocationFailureChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LocationFailureSheet(failure: failure),
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _LocationFailureChoice.retry:
        if (action == null) {
          await _handleLocationPillTap();
        } else {
          await _openNearbySearch(action);
        }
      case _LocationFailureChoice.openSettings:
        final gateway = ref.read(deviceLocationGatewayProvider);
        if (failure == DeviceLocationFailure.serviceDisabled) {
          await gateway.openLocationSettings();
        } else {
          await gateway.openAppSettings();
        }
      case _LocationFailureChoice.chooseCity:
        final city = await _showCityFallbackSheet();
        if (city == null) {
          return;
        }
        setState(() {
          _selectedFallbackCity = city;
          _locationPill = _LocationPillState.fallback(city.municipality);
        });
        if (action != null) {
          await _launchCitySearch(action, city);
        }
    }
  }

  Future<RegistrationCity?> _showCityFallbackSheet() async {
    final catalog = await ref.read(registrationCityCatalogProvider.future);
    if (!mounted) {
      return null;
    }
    return showModalBottomSheet<RegistrationCity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CityFallbackSheet(catalog: catalog),
    );
  }

  Future<void> _launchCitySearch(
    _ServiceSearchAction action,
    RegistrationCity city,
  ) async {
    final uri = googleMapsCityServiceSearchUri(
      category: action.category,
      city: city.displayName,
    );
    await _launchGoogleMaps(uri);
  }

  Future<void> _launchGoogleMaps(Uri uri) async {
    try {
      final opened = await ref
          .read(externalLauncherProvider)
          .openExternal(uri.toString());
      if (!mounted || opened) {
        return;
      }
      _showSnackBar('No pudimos abrir Google Maps.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No pudimos abrir Google Maps.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.location, required this.onRefresh});

  final _LocationPillState location;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final label = location.label;
    final iconColor = location.isError ? AppColors.red : AppColors.teal;
    final borderColor = location.isError
        ? AppColors.red.withValues(alpha: 0.42)
        : AppColors.border;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Volver',
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.navy),
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Ubicación para búsquedas: $label',
            child: Material(
              key: const ValueKey('services-location-pill'),
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                onTap: onRefresh,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (location.isDetecting)
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.teal,
                              ),
                            )
                          else
                            Icon(Icons.gps_fixed, color: iconColor, size: 20),
                          const SizedBox(width: AppSpacing.s),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: location.isError
                                    ? AppColors.red
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPillState {
  const _LocationPillState._(
    this.label, {
    this.isDetecting = false,
    this.isError = false,
  });

  const _LocationPillState.idle() : this._('Usar GPS');

  const _LocationPillState.detecting()
    : this._('Detectando...', isDetecting: true);

  const _LocationPillState.detected(String label) : this._(label);

  const _LocationPillState.fallback(String label) : this._(label);

  const _LocationPillState.failed(DeviceLocationFailure failure)
    : this._(
        failure == DeviceLocationFailure.serviceDisabled
            ? 'GPS apagado'
            : failure == DeviceLocationFailure.positionUnavailable
            ? 'Sin señal GPS'
            : 'Seleccionar ciudad',
        isError: true,
      );

  final String label;
  final bool isDetecting;
  final bool isError;
}

class _ServicesHero extends StatelessWidget {
  const _ServicesHero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final isNarrow = constraints.maxWidth < 380;
        final useStacked = textScale >= 1.7;
        final artWidth = useStacked ? 150.0 : (isNarrow ? 136.0 : 172.0);
        final artHeight = useStacked ? 88.0 : (isNarrow ? 84.0 : 108.0);
        final imageWidth = useStacked ? 136.0 : (isNarrow ? 136.0 : 172.0);
        final circleSize = useStacked ? 56.0 : (isNarrow ? 44.0 : 68.0);
        final titleSize = isNarrow ? 25.0 : 29.0;

        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Servicios para\ntu vehículo',
              style: AppTextStyles.display.copyWith(fontSize: titleSize),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Encuentra apoyo y soluciones cerca de ti.',
              style: AppTextStyles.body.copyWith(
                fontSize: isNarrow ? 14.5 : 15.5,
                color: AppColors.navy.withValues(alpha: 0.72),
              ),
            ),
          ],
        );

        final art = SizedBox(
          width: artWidth,
          height: artHeight,
          child: SizedBox(
            width: artWidth,
            height: artHeight,
            child: ExcludeSemantics(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/vehicles/veh_car_chevrolet_01.webp',
                      width: imageWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 4,
                    bottom: 0,
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Row(
                      children: [
                        _CityBlock(
                          height: useStacked ? 54 : (isNarrow ? 42 : 72),
                        ),
                        const SizedBox(width: 6),
                        _CityBlock(
                          height: useStacked ? 78 : (isNarrow ? 58 : 104),
                        ),
                        const SizedBox(width: 6),
                        _CityBlock(
                          height: useStacked ? 44 : (isNarrow ? 34 : 60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (useStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: AppSpacing.s),
              Align(alignment: Alignment.centerRight, child: art),
            ],
          );
        }

        return SizedBox(
          height: isNarrow ? 104 : 128,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: isNarrow ? 190 : constraints.maxWidth * 0.62,
                child: copy,
              ),
              Positioned(
                right: isNarrow ? -4 : 0,
                top: isNarrow ? 4 : 8,
                child: art,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CityBlock extends StatelessWidget {
  const _CityBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 28,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _PrimaryServiceCard extends StatelessWidget {
  const _PrimaryServiceCard({
    required this.action,
    required this.loading,
    required this.onTap,
  });

  final _ServiceSearchAction action;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useAccessibleLayout = textScale >= 1.3;
    return _ServiceSurface(
      keyName: 'services-search-${action.key}',
      semanticLabel: action.title,
      onTap: loading ? null : onTap,
      color: AppColors.teal.withValues(alpha: 0.12),
      borderColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      child: useAccessibleLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title, style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Grúas cercanas en Google Maps.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                _InlineActionLabel(loading: loading),
              ],
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Stack(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.title,
                            style: AppTextStyles.h2.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Grúas cercanas en Google Maps.',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13,
                              color: AppColors.navy.withValues(alpha: 0.70),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _InlineActionLabel(loading: loading),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 50,
                        color: AppColors.teal.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InlineActionLabel extends StatelessWidget {
  const _InlineActionLabel({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            'Buscando ubicación',
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.teal),
          ),
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Text(
          'Abrir en Google Maps',
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.teal),
        ),
        const Icon(Icons.north_east, color: AppColors.teal, size: 19),
      ],
    );
  }
}

class _CompactServicesGrid extends StatelessWidget {
  const _CompactServicesGrid({
    required this.actions,
    required this.loadingActionKey,
    required this.onTap,
  });

  final List<_ServiceSearchAction> actions;
  final String? loadingActionKey;
  final void Function(_ServiceSearchAction action) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useColumn = constraints.maxWidth < 300 || textScale >= 1.3;
        if (useColumn) {
          return Column(
            children: [
              for (final action in actions) ...[
                _CompactServiceCard(
                  action: action,
                  loading: loadingActionKey == action.key,
                  onTap: () => onTap(action),
                ),
                if (action != actions.last)
                  const SizedBox(height: AppSpacing.s),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final action in actions) ...[
              Expanded(
                child: _CompactServiceCard(
                  action: action,
                  loading: loadingActionKey == action.key,
                  onTap: () => onTap(action),
                ),
              ),
              if (action != actions.last) const SizedBox(width: AppSpacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _CompactServiceCard extends StatelessWidget {
  const _CompactServiceCard({
    required this.action,
    required this.loading,
    required this.onTap,
  });

  final _ServiceSearchAction action;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useAccessibleLayout = textScale >= 1.3;
    return _ServiceSurface(
      keyName: 'services-search-${action.key}',
      semanticLabel: action.title,
      onTap: loading ? null : onTap,
      padding: const EdgeInsets.all(8),
      child: useAccessibleLayout
          ? Row(
              children: [
                _SoftIcon(icon: action.icon, radius: 25, size: 26),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.title, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Google Maps',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.navy.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : CircleAvatar(
                        radius: 19,
                        backgroundColor: AppColors.teal.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.north_east,
                          color: AppColors.teal,
                        ),
                      ),
              ],
            )
          : SizedBox(
              height: 102,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _SoftIcon(icon: action.icon, radius: 19, size: 21),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 13,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Google Maps',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            color: AppColors.navy.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : CircleAvatar(
                            radius: 15,
                            backgroundColor: AppColors.teal.withValues(
                              alpha: 0.10,
                            ),
                            child: const Icon(
                              Icons.north_east,
                              color: AppColors.teal,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CdaCard extends StatelessWidget {
  const _CdaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ServiceSurface(
      keyName: 'services-open-cda',
      semanticLabel: 'Abrir CDA dentro de PicoRadar',
      onTap: onTap,
      color: AppColors.navy,
      borderColor: AppColors.navy,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abrir CDA dentro de PicoRadar',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Consulta el CDA disponible en la app.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

class _ServicesDisclaimer extends StatelessWidget {
  const _ServicesDisclaimer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.plateYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.plateYellow.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFFD4A000),
              size: 22,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Las búsquedas externas se abren en Google Maps. '
                'PicoRadar no presta estos servicios ni verifica proveedores.',
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceSurface extends StatelessWidget {
  const _ServiceSurface({
    required this.keyName,
    required this.semanticLabel,
    required this.child,
    required this.onTap,
    this.color = Colors.white,
    this.borderColor = AppColors.border,
    this.padding = const EdgeInsets.all(AppSpacing.l),
  });

  final String keyName;
  final String semanticLabel;
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label: semanticLabel,
      onTap: onTap,
      child: Material(
        key: ValueKey(keyName),
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, this.radius = 32, this.size = 32});

  final IconData icon;
  final double radius;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.teal.withValues(alpha: 0.10),
      child: Icon(icon, color: AppColors.teal, size: size),
    );
  }
}

class _LocationFailureSheet extends StatelessWidget {
  const _LocationFailureSheet({required this.failure});

  final DeviceLocationFailure failure;

  @override
  Widget build(BuildContext context) {
    final copy = _copyForFailure(failure);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(copy.title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              copy.body,
              style: AppTextStyles.body.copyWith(
                color: AppColors.navy.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_LocationFailureChoice.retry),
              child: const Text('Reintentar'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(_LocationFailureChoice.openSettings),
              child: Text(copy.settingsLabel),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_LocationFailureChoice.chooseCity),
              child: const Text('Seleccionar ciudad'),
            ),
          ],
        ),
      ),
    );
  }

  _LocationFailureCopy _copyForFailure(DeviceLocationFailure failure) {
    return switch (failure) {
      DeviceLocationFailure.serviceDisabled => const _LocationFailureCopy(
        title: 'Activa la ubicación',
        body: 'Para ordenar opciones cercanas necesitamos una lectura puntual de tu ubicación.',
        settingsLabel: 'Abrir ajustes de ubicación',
      ),
      DeviceLocationFailure.permissionDenied => const _LocationFailureCopy(
        title: 'Permiso de ubicación',
        body: 'Puedes permitir la ubicación para buscar cerca de ti o elegir una ciudad temporal.',
        settingsLabel: 'Abrir ajustes',
      ),
      DeviceLocationFailure.permissionDeniedForever =>
        const _LocationFailureCopy(
          title: 'Permiso bloqueado',
          body: 'El permiso quedó bloqueado para PicoRadar. Puedes cambiarlo en ajustes o buscar por ciudad.',
          settingsLabel: 'Abrir ajustes',
        ),
      DeviceLocationFailure.positionUnavailable => const _LocationFailureCopy(
        title: 'No pudimos ubicarte',
        body: 'La lectura puntual no estuvo disponible. Intenta de nuevo o busca por ciudad.',
        settingsLabel: 'Abrir ajustes de ubicación',
      ),
    };
  }
}

class _CityFallbackSheet extends StatefulWidget {
  const _CityFallbackSheet({required this.catalog});

  final RegistrationCityCatalog catalog;

  @override
  State<_CityFallbackSheet> createState() => _CityFallbackSheetState();
}

class _CityFallbackSheetState extends State<_CityFallbackSheet> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final query = _queryController.text.trim();
    final results = widget.catalog.search(query, limit: 32);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elegir ciudad', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Esta búsqueda es temporal y no cambia tus preferencias.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.navy.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              key: const ValueKey('services-city-fallback-search'),
              controller: _queryController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Buscar ciudad',
                hintText: 'Municipio o departamento',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: ListView(
                key: const ValueKey('services-city-fallback-results'),
                shrinkWrap: true,
                children: [
                  for (final city in results)
                    ListTile(
                      key: ValueKey(
                        'services-city-${normalizeRegistrationCityText(city.displayName)}',
                      ),
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(city.displayName),
                      subtitle: const Text('Catálogo local de ciudades'),
                      onTap: () => Navigator.of(context).pop(city),
                    ),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                      child: Text('Sin resultados en el catálogo local.'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

const _serviceLocationLabels = <String, String>{
  'co-dc-bogota': 'Bogotá',
  'co-ant-medellin': 'Medellín',
  'co-vac-cali': 'Cali',
  'co-bol-cartagena': 'Cartagena',
  'co-san-bucaramanga': 'Bucaramanga',
  'co-atl-barranquilla': 'Barranquilla',
  'co-cal-manizales': 'Manizales',
  'co-cau-popayan': 'Popayán',
  'co-met-villavicencio': 'Villavicencio',
};

sealed class _LocationSearchResult {
  const _LocationSearchResult();
}

class _ResolvedLocation extends _LocationSearchResult {
  const _ResolvedLocation(this.point);

  final DeviceLocationPoint point;
}

class _LocationFailed extends _LocationSearchResult {
  const _LocationFailed(this.failure);

  final DeviceLocationFailure failure;
}

class _LocationFailureCopy {
  const _LocationFailureCopy({
    required this.title,
    required this.body,
    required this.settingsLabel,
  });

  final String title;
  final String body;
  final String settingsLabel;
}

enum _LocationFailureChoice { retry, openSettings, chooseCity }

class _ServiceSearchAction {
  const _ServiceSearchAction({
    required this.key,
    required this.title,
    required this.category,
    required this.icon,
  });

  final String key;
  final String title;
  final GoogleMapsServiceCategory category;
  final IconData icon;
}

const _towAction = _ServiceSearchAction(
  key: 'tow',
  title: 'Buscar grúa 24 horas',
  category: GoogleMapsServiceCategory.tow,
  icon: Icons.fire_truck_outlined,
);

const _secondaryActions = [
  _ServiceSearchAction(
    key: 'battery',
    title: 'Buscar batería',
    category: GoogleMapsServiceCategory.battery,
    icon: Icons.battery_charging_full_outlined,
  ),
  _ServiceSearchAction(
    key: 'tires',
    title: 'Buscar llantas',
    category: GoogleMapsServiceCategory.tires,
    icon: Icons.tire_repair_outlined,
  ),
  _ServiceSearchAction(
    key: 'mechanic',
    title: 'Buscar taller mecánico',
    category: GoogleMapsServiceCategory.mechanic,
    icon: Icons.car_repair_outlined,
  ),
];
