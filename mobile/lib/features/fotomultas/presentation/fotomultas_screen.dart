import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/driving/data/camera_pack_loader.dart';
import '../../../features/driving/domain/traffic_camera.dart';
import '../../../features/vehicle_status/platform/external_launcher.dart';

enum _SpeedFilter { all, known, unknown }

class FotomultasScreen extends ConsumerStatefulWidget {
  const FotomultasScreen({super.key});

  @override
  ConsumerState<FotomultasScreen> createState() => _FotomultasScreenState();
}

class _FotomultasScreenState extends ConsumerState<FotomultasScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _SpeedFilter _filter = _SpeedFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(cameraPackProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fotomultas')),
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
    );
  }

  Widget _buildPack(CameraPack pack) {
    final sorted = _sortedCameras(pack.cameras);
    final filtered = _filterCameras(sorted, _query, _filter);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: _Header(
              pack: pack,
              controller: _searchController,
              query: _query,
              filter: _filter,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterChanged: (value) => setState(() => _filter = value),
              onOpenDriving: () => context.go(AppRoute.drive.path),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyPane())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              96,
            ),
            sliver: SliverList(
              key: const ValueKey('fotomultas-list'),
              delegate: SliverChildBuilderDelegate((context, index) {
                final camera = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: _CameraCard(
                    camera: camera,
                    source: pack.source,
                    onTap: () => _showDetails(camera, pack.source),
                  ),
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
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
                  Text(_valueOrFallback(camera.address, 'Cámara autorizada')),
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

  Future<void> _openSource(CameraPackSource source) async {
    final opened = await ref
        .read(externalLauncherProvider)
        .openExternal(source.pageUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir la fuente ANSV.')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pack,
    required this.controller,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onOpenDriving,
  });

  final CameraPack pack;
  final TextEditingController controller;
  final String query;
  final _SpeedFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_SpeedFilter> onFilterChanged;
  final VoidCallback onOpenDriving;

  @override
  Widget build(BuildContext context) {
    final speedKnown = pack.cameras.where((camera) {
      return camera.speedLimitKmh != null;
    }).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetricChip(
                      icon: Icons.photo_camera_outlined,
                      label: '${pack.cameras.length} cámaras',
                    ),
                    _MetricChip(
                      icon: Icons.speed_outlined,
                      label: '$speedKnown con velocidad reportada',
                    ),
                    _MetricChip(
                      icon: Icons.verified_outlined,
                      label: 'fuente ANSV',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Actualizado ${pack.source.fetchedAtUtc}',
                  key: const ValueKey('fotomultas-source-date'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Text(
                  'Cámaras autorizadas y reportadas como operando en la fuente publicada por ANSV.',
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Este módulo no consulta comparendos ni confirma una sanción. La velocidad reportada no reemplaza la señalización de la vía.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                FilledButton.icon(
                  key: const ValueKey('fotomultas-open-driving'),
                  onPressed: onOpenDriving,
                  icon: const Icon(Icons.drive_eta_outlined),
                  label: const Text('Abrir Conducir'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        TextField(
          key: const ValueKey('fotomultas-search-field'),
          controller: controller,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar dirección, ciudad o autoridad',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SegmentedButton<_SpeedFilter>(
          key: const ValueKey('fotomultas-speed-filter'),
          segments: const [
            ButtonSegment(value: _SpeedFilter.all, label: Text('Todas')),
            ButtonSegment(value: _SpeedFilter.known, label: Text('Con vel.')),
            ButtonSegment(value: _SpeedFilter.unknown, label: Text('Sin vel.')),
          ],
          selected: {filter},
          onSelectionChanged: (selected) => onFilterChanged(selected.single),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            minimumSize: WidgetStatePropertyAll(Size(0, 42)),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.teal),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
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
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
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
