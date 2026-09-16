import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/router/app_routes.dart';
import 'department_geometry.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/driving/data/camera_pack_loader.dart';
import '../../../features/driving/domain/traffic_camera.dart';
import '../../../features/vehicle_status/platform/external_launcher.dart';

part 'national_department_view.dart';
part 'national_department_map.dart';
part 'department_camera_map.dart';
part 'department_explorer.dart';

enum _SpeedFilter { all, known, unknown }

enum _DepartmentView { map, list }

const _pageSize = 25;
const _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _tileUserAgent = 'co.picoradar.app';

class FotomultasScreen extends ConsumerStatefulWidget {
  const FotomultasScreen({super.key});

  @override
  ConsumerState<FotomultasScreen> createState() => _FotomultasScreenState();
}

class _FotomultasScreenState extends ConsumerState<FotomultasScreen> {
  final _countrySearchController = TextEditingController();
  String _departmentQuery = '';
  String _cameraQuery = '';
  String? _selectedDepartmentCode;
  _SpeedFilter _filter = _SpeedFilter.all;
  _DepartmentView _view = _DepartmentView.map;
  int _page = 0;
  CameraPack? _preparedPack;
  Map<String, _DepartmentSummary>? _departments;
  GlobalKey<_DepartmentMapViewState> _departmentMapKey = GlobalKey();

  @override
  void dispose() {
    _countrySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(cameraPackProvider);
    return PopScope(
      canPop: _selectedDepartmentCode == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedDepartmentCode != null) _backToCountry();
      },
      child: Scaffold(
        appBar: _selectedDepartmentCode == null
            ? _nationalAppBar(context, pack.asData?.value)
            : _departmentAppBar(
                context,
                name: _departments?[_selectedDepartmentCode]?.name ?? '',
                view: _view,
                onBack: _backToCountry,
                onToggle: () => setState(() {
                  _view = _view == _DepartmentView.map
                      ? _DepartmentView.list
                      : _DepartmentView.map;
                }),
              ),
        body: SafeArea(
          child: pack.when(
            loading: () => const Center(
              key: ValueKey('fotomultas-loading'),
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => _ErrorPane(
              message: error.toString(),
              onRetry: () => ref.refresh(cameraPackProvider),
            ),
            data: _buildPack,
          ),
        ),
      ),
    );
  }

  Widget _buildPack(CameraPack pack) {
    if (!identical(pack, _preparedPack)) {
      _departments = _buildDepartmentSummaries(pack.cameras);
      _preparedPack = pack;
    }
    final departments = _departments!;
    final geometry = ref.watch(departmentGeometryProvider);
    final selected = _selectedDepartmentCode == null
        ? null
        : departments[_selectedDepartmentCode!];
    final national = _NationalDepartmentView(
      pack: pack,
      departments: departments.values.toList(growable: false),
      controller: _countrySearchController,
      query: _departmentQuery,
      onQueryChanged: (value) => setState(() => _departmentQuery = value),
      onOpenDriving: () => context.go(AppRoute.drive.path),
      onSelect: _openDepartment,
      geometry: geometry,
      onRetryGeometry: () => ref.invalidate(departmentGeometryProvider),
      onOpenSource: () => _openSource(pack.source),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: selected != null,
          child: TickerMode(enabled: selected == null, child: national),
        ),
        if (selected != null)
          _DepartmentExplorer(
            mapKey: _departmentMapKey,
            pack: pack,
            department: selected,
            geometry: geometry.asData?.value,
            view: _view,
            filter: _filter,
            page: _page,
            query: _cameraQuery,
            onQueryChanged: (value) => setState(() {
              _cameraQuery = value;
              _page = 0;
            }),
            onFilterChanged: (value) => setState(() {
              _filter = value;
              _page = 0;
            }),
            onPageChanged: (value) => setState(() => _page = value),
            onShowList: () => setState(() => _view = _DepartmentView.list),
            onShowDetails: _showDetails,
            onOpenDriving: () => context.go(AppRoute.drive.path),
            onOpenSource: () => _openSource(pack.source, offerRetry: true),
          ),
      ],
    );
  }

  void _openDepartment(String code) {
    final department = _departments?[code];
    if (department == null) return;
    if (department.count == 0) {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('fotomultas-empty-department-sheet'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.name, style: AppTextStyles.h2),
                  const SizedBox(height: 12),
                  const Text(
                    'Sin registros en este inventario',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La cobertura es parcial. Esto no significa que no existan cámaras en el departamento.',
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver al mapa'),
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
      _departmentMapKey = GlobalKey();
      _selectedDepartmentCode = code;
      _cameraQuery = '';
      _filter = _SpeedFilter.all;
      _view = _DepartmentView.map;
      _page = 0;
    });
  }

  void _backToCountry() {
    setState(() {
      _selectedDepartmentCode = null;

      _page = 0;
    });
  }

  void _showDetails(TrafficCamera camera, CameraPackSource source) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('fotomultas-detail-sheet'),
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
                  Text(
                    _valueOrFallback(camera.address, 'Cámara autorizada'),
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    _location(camera),
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  FilledButton.icon(
                    key: const ValueKey('fotomultas-detail-open-driving'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      this.context.go(AppRoute.drive.path);
                    },
                    icon: const Icon(Icons.drive_eta_outlined),
                    label: const Text('Abrir Conducir'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (_hasValidCoordinate(camera))
                    OutlinedButton.icon(
                      key: const ValueKey('fotomultas-locate-camera'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() => _view = _DepartmentView.map);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _departmentMapKey.currentState?.locate(camera);
                          }
                        });
                      },
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Ver ubicación en el mapa'),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('fotomultas-open-source'),
                    onPressed: () => _openSource(source),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir fuente ANSV'),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _DetailLine(
                    label: 'Autoridad',
                    value: camera.trafficAuthority,
                  ),
                  _DetailLine(
                    label: 'Velocidad reportada por ANSV',
                    value: _speedText(camera),
                  ),
                  _DetailLine(label: 'Tecnología', value: camera.technology),
                  _DetailLine(
                    label: 'Tipo de instalación',
                    value: camera.installationType,
                  ),
                  _DetailLine(label: 'Equipo', value: camera.equipmentName),
                  if (camera.rawInfractionCodes.isNotEmpty)
                    _DetailLine(
                      label: 'Códigos de infracción',
                      value: camera.rawInfractionCodes.join(', '),
                    ),
                  _DetailLine(label: 'Fuente', value: source.name),
                  _DetailLine(
                    label: 'Fecha del snapshot',
                    value: source.fetchedAtUtc,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSource(
    CameraPackSource source, {
    bool offerRetry = false,
  }) async {
    final launcher = ref.read(externalLauncherProvider);
    var opened = false;
    try {
      final uri = Uri.tryParse(source.pageUrl);
      final valid =
          uri != null &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          (uri.scheme == 'https' || uri.scheme == 'http');
      if (!offerRetry || valid) {
        opened = await launcher.openExternal(source.pageUrl);
      }
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No pudimos abrir la fuente ANSV.'),
        action: offerRetry
            ? SnackBarAction(
                label: 'Reintentar',
                onPressed: () => _openSource(source, offerRetry: true),
              )
            : null,
      ),
    );
  }
}

class _DepartmentTile extends StatelessWidget {
  const _DepartmentTile({required this.department, required this.onTap});

  final _DepartmentSummary department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('fotomultas-department-tile-${department.code}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _departmentColor(
                  department.colorIndex,
                  department.count,
                ),
                child: Text(
                  department.code,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(department.name, style: AppTextStyles.bodyStrong),
                    Text(
                      department.count == 0
                          ? 'Sin registros en este inventario'
                          : '${department.count} cámaras del inventario',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraMapMarker extends StatelessWidget {
  const _CameraMapMarker({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: count > 1
                ? Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentCameraList extends StatelessWidget {
  const _DepartmentCameraList({
    required this.cameras,
    required this.source,
    required this.page,
    required this.onPageChanged,
    required this.onShowDetails,
  });

  final List<TrafficCamera> cameras;
  final CameraPackSource source;
  final int page;
  final ValueChanged<int> onPageChanged;
  final void Function(TrafficCamera camera, CameraPackSource source)
  onShowDetails;

  @override
  Widget build(BuildContext context) {
    final pageCount = (cameras.length / _pageSize).ceil().clamp(1, 9999);
    final safePage = page.clamp(0, pageCount - 1);
    final start = safePage * _pageSize;
    final visible = cameras.skip(start).take(_pageSize).toList(growable: false);
    return ListView.separated(
      key: const ValueKey('fotomultas-list'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, 96),
      itemBuilder: (context, index) {
        if (index == visible.length) {
          return _PaginationControls(
            page: safePage,
            pageCount: pageCount,
            total: cameras.length,
            onPageChanged: onPageChanged,
          );
        }
        final camera = visible[index];
        return _CameraCard(
          camera: camera,
          source: source,
          onTap: () => onShowDetails(camera, source),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.s),
      itemCount: visible.length + 1,
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$total registros · Página ${page + 1} de $pageCount',
              style: AppTextStyles.caption,
            ),
          ),
          IconButton(
            key: const ValueKey('fotomultas-page-prev'),
            tooltip: 'Página anterior',
            onPressed: page == 0 ? null : () => onPageChanged(page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const ValueKey('fotomultas-page-next'),
            tooltip: 'Página siguiente',
            onPressed: page >= pageCount - 1
                ? null
                : () => onPageChanged(page + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.source,
    required this.onTap,
  });

  final TrafficCamera camera;
  final CameraPackSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('fotomultas-camera-${camera.id}'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.photo_camera_outlined),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _valueOrFallback(
                          camera.address,
                          'Dirección no publicada',
                        ),
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _location(camera),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _valueOrFallback(
                          camera.trafficAuthority,
                          'Autoridad no publicada',
                        ),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        _speedText(camera),
                        key: ValueKey('fotomultas-speed-${camera.id}'),
                        style: AppTextStyles.caption.copyWith(
                          color: camera.speedLimitKmh == null
                              ? AppColors.navy.withValues(alpha: 0.66)
                              : AppColors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red),
            const SizedBox(height: AppSpacing.s),
            Text(
              'No pudimos cargar las cámaras.',
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              key: const ValueKey('fotomultas-retry'),
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('fotomultas-empty-search'),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('No encontramos cámaras con esa búsqueda.'),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(text),
        ],
      ),
    );
  }
}

class _DepartmentSummary {
  const _DepartmentSummary({
    required this.code,
    required this.name,
    required this.colorIndex,
    required this.cameras,
  });

  final String code;
  final String name;
  final int colorIndex;
  final List<TrafficCamera> cameras;

  int get count => cameras.length;
}

class _DepartmentInfo {
  const _DepartmentInfo(this.code, this.name, this.colorIndex);

  final String code;
  final String name;
  final int colorIndex;
}

class _CameraCluster {
  const _CameraCluster({
    required this.id,
    required this.center,
    required this.cameras,
  });

  final String id;
  final LatLng center;
  final List<TrafficCamera> cameras;
}

Map<String, _DepartmentSummary> _buildDepartmentSummaries(
  Iterable<TrafficCamera> cameras,
) {
  final grouped = {
    for (final item in _departmentCatalog) item.code: <TrafficCamera>[],
    _unknownDepartment.code: <TrafficCamera>[],
  };
  for (final camera in cameras) {
    final code = _departmentCode(camera.department);
    grouped.putIfAbsent(code, () => <TrafficCamera>[]).add(camera);
  }
  final summaries = <String, _DepartmentSummary>{};
  for (final info in [..._departmentCatalog, _unknownDepartment]) {
    final items = _sortedCameras(grouped[info.code] ?? const []);
    summaries[info.code] = _DepartmentSummary(
      code: info.code,
      name: info.name,
      colorIndex: info.colorIndex,
      cameras: items,
    );
  }
  return summaries;
}

List<_DepartmentSummary> _filterDepartments(
  Iterable<_DepartmentSummary> departments,
  String query,
) {
  final terms = _normalize(query).split(' ').where((term) => term.isNotEmpty);
  final filtered = departments
      .where((department) {
        if (department.code == _unknownDepartment.code &&
            department.count == 0) {
          return false;
        }
        final haystack = _normalize('${department.name} ${department.code}');
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
  filtered.sort((a, b) {
    return _normalize(a.name).compareTo(_normalize(b.name));
  });
  return filtered;
}

List<TrafficCamera> _sortedCameras(Iterable<TrafficCamera> cameras) {
  final sorted = cameras.toList(growable: false);
  sorted.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  return sorted;
}

List<TrafficCamera> _filterCameras(
  Iterable<TrafficCamera> cameras,
  String query,
  _SpeedFilter filter,
) {
  final terms = _normalize(query).split(' ').where((term) => term.isNotEmpty);
  return cameras
      .where((camera) {
        final matchesSpeed = switch (filter) {
          _SpeedFilter.all => true,
          _SpeedFilter.known => camera.speedLimitKmh != null,
          _SpeedFilter.unknown => camera.speedLimitKmh == null,
        };
        if (!matchesSpeed) {
          return false;
        }
        final haystack = _normalize(
          '${camera.address ?? ''} ${camera.municipality ?? ''} '
          '${camera.department ?? ''} ${camera.trafficAuthority ?? ''}',
        );
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
}

String _sortKey(TrafficCamera camera) {
  return _normalize(
    '${camera.department ?? ''} ${camera.municipality ?? ''} '
    '${camera.address ?? ''}',
  );
}

bool _hasValidCoordinate(TrafficCamera camera) {
  final lat = camera.latitude;
  final lon = camera.longitude;
  return lat.isFinite &&
      lon.isFinite &&
      lat.abs() > 0.01 &&
      lon.abs() > 0.01 &&
      lat >= -5 &&
      lat <= 14 &&
      lon >= -82 &&
      lon <= -66;
}

String _departmentCode(String? raw) {
  final value = _normalize(raw ?? '');
  return _departmentAliases[value] ?? _unknownDepartment.code;
}

Color _departmentColor(int index, int count) {
  final palette = <Color>[
    const Color(0xFFBFE7DF),
    const Color(0xFFFFE0A3),
    const Color(0xFFCFE0FF),
    const Color(0xFFFFC7C7),
    const Color(0xFFD9D1FF),
    const Color(0xFFCDECC8),
    const Color(0xFFFAD6E5),
    const Color(0xFFD4EDF7),
  ];
  final base = palette[index % palette.length];
  if (count == 0) {
    return AppColors.surface;
  }
  final boost = math.min(count / 90, 0.35);
  return Color.lerp(base, AppColors.teal, boost)!;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

String _location(TrafficCamera camera) {
  final municipality = camera.municipality?.trim();
  final department = camera.department?.trim();
  if (municipality != null &&
      municipality.isNotEmpty &&
      department != null &&
      department.isNotEmpty) {
    return '$municipality · $department';
  }
  return municipality ?? department ?? 'Colombia';
}

String _speedText(TrafficCamera camera) {
  final speed = camera.speedLimitKmh;
  if (speed == null) {
    return 'Velocidad no publicada';
  }
  return 'Velocidad reportada: $speed km/h';
}

String _valueOrFallback(String? value, String fallback) {
  final text = value?.trim();
  return text == null || text.isEmpty ? fallback : text;
}

const _unknownDepartment = _DepartmentInfo(
  'ZZZ',
  'Departamento por verificar',
  8,
);

const _departmentCatalog = [
  _DepartmentInfo('AMA', 'Amazonas', 0),
  _DepartmentInfo('ANT', 'Antioquia', 1),
  _DepartmentInfo('ARA', 'Arauca', 2),
  _DepartmentInfo('ATL', 'Atlántico', 3),
  _DepartmentInfo('BOG', 'Bogotá', 4),
  _DepartmentInfo('BOL', 'Bolívar', 5),
  _DepartmentInfo('BOY', 'Boyacá', 6),
  _DepartmentInfo('CAL', 'Caldas', 7),
  _DepartmentInfo('CAQ', 'Caquetá', 0),
  _DepartmentInfo('CAS', 'Casanare', 1),
  _DepartmentInfo('CAU', 'Cauca', 2),
  _DepartmentInfo('CES', 'Cesar', 3),
  _DepartmentInfo('CHO', 'Chocó', 4),
  _DepartmentInfo('COR', 'Córdoba', 5),
  _DepartmentInfo('CUN', 'Cundinamarca', 6),
  _DepartmentInfo('GUA', 'Guainía', 7),
  _DepartmentInfo('GUV', 'Guaviare', 0),
  _DepartmentInfo('HUI', 'Huila', 1),
  _DepartmentInfo('LAG', 'La Guajira', 2),
  _DepartmentInfo('MAG', 'Magdalena', 3),
  _DepartmentInfo('MET', 'Meta', 4),
  _DepartmentInfo('NAR', 'Nariño', 5),
  _DepartmentInfo('NSA', 'Norte de Santander', 6),
  _DepartmentInfo('PUT', 'Putumayo', 7),
  _DepartmentInfo('QUI', 'Quindío', 0),
  _DepartmentInfo('RIS', 'Risaralda', 1),
  _DepartmentInfo('SAP', 'San Andrés, Providencia y Santa Catalina', 2),
  _DepartmentInfo('SAN', 'Santander', 3),
  _DepartmentInfo('SUC', 'Sucre', 4),
  _DepartmentInfo('TOL', 'Tolima', 5),
  _DepartmentInfo('VAC', 'Valle del Cauca', 6),
  _DepartmentInfo('VAU', 'Vaupés', 7),
  _DepartmentInfo('VIC', 'Vichada', 0),
];

const _departmentAliases = {
  'amazonas': 'AMA',
  'antioquia': 'ANT',
  'arauca': 'ARA',
  'atlantico': 'ATL',
  'bogota': 'BOG',
  'bogota d c': 'BOG',
  'bogota dc': 'BOG',
  'distrito capital': 'BOG',
  'bolivar': 'BOL',
  'boyaca': 'BOY',
  'caldas': 'CAL',
  'caqueta': 'CAQ',
  'casanare': 'CAS',
  'cauca': 'CAU',
  'cesar': 'CES',
  'choco': 'CHO',
  'cordoba': 'COR',
  'cundinamarca': 'CUN',
  'guainia': 'GUA',
  'guaviare': 'GUV',
  'huila': 'HUI',
  'la guajira': 'LAG',
  'magdalena': 'MAG',
  'meta': 'MET',
  'narino': 'NAR',
  'n de santander': 'NSA',
  'norte de santander': 'NSA',
  'putumayo': 'PUT',
  'quindio': 'QUI',
  'risaralda': 'RIS',
  'san andres': 'SAP',
  'san andres providencia y santa catalina': 'SAP',
  'archipielago de san andres providencia y santa catalina': 'SAP',
  'santander': 'SAN',
  'sucre': 'SUC',
  'tolima': 'TOL',
  'valle': 'VAC',
  'valle del cauca': 'VAC',
  'vaupes': 'VAU',
  'vichada': 'VIC',
};
