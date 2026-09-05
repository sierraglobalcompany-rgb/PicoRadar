import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../cda/presentation/cda_finder_screen.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/google_maps_service_search.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.onOpenCda});

  final VoidCallback? onOpenCda;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _cityController = TextEditingController();
  bool _cityInitialized = false;
  bool _cityWasEdited = false;
  bool _applyingInitialCity = false;

  @override
  void initState() {
    super.initState();
    _cityController.addListener(_markCityEdited);
  }

  @override
  void dispose() {
    _cityController
      ..removeListener(_markCityEdited)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVehicle = ref.watch(activeVehicleProvider);
    _applyInitialCity(activeVehicle.asData?.value?.registrationCity);

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('services-screen'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.xxl,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ServicesHeader(),
                    const SizedBox(height: AppSpacing.l),
                    TextField(
                      key: const ValueKey('services-city-field'),
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        hintText: 'Ej. Medellín',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _ServiceActionCard(
                      keyName: 'services-open-cda',
                      icon: Icons.fact_check_outlined,
                      title: 'Abrir CDA dentro de PicoRadar',
                      body: 'Consulta el finder oficial de CDA disponible en la app.',
                      onTap: _openCda,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    for (final action in _externalActions) ...[
                      _ServiceActionCard(
                        keyName: 'services-search-${action.key}',
                        icon: action.icon,
                        title: action.label,
                        body: 'Abre una búsqueda externa en Google Maps.',
                        onTap: () => _openExternalSearch(action.category),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                    const SizedBox(height: AppSpacing.s),
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

  void _markCityEdited() {
    if (!_applyingInitialCity) {
      _cityWasEdited = true;
    }
  }

  void _applyInitialCity(String? city) {
    if (_cityInitialized || _cityWasEdited) {
      return;
    }
    final initialCity = city?.trim();
    if (initialCity == null || initialCity.isEmpty) {
      return;
    }
    _applyingInitialCity = true;
    _cityController.value = TextEditingValue(
      text: initialCity,
      selection: TextSelection.collapsed(offset: initialCity.length),
    );
    _applyingInitialCity = false;
    _cityInitialized = true;
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

  Future<void> _openExternalSearch(String category) async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una ciudad para buscar.')),
      );
      return;
    }

    final launcher = ref.read(externalLauncherProvider);
    final uri = googleMapsServiceSearchUri(category: category, city: city);
    final opened = await launcher.openExternal(uri.toString());
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pudimos abrir Google Maps.')),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Servicios para tu vehículo',
              style: AppTextStyles.h2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Elige una necesidad y revisa opciones por ciudad.',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceActionCard extends StatelessWidget {
  const _ServiceActionCard({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: title,
      onTap: onTap,
      child: Material(
        key: ValueKey(keyName),
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.10),
                  child: Icon(icon, color: AppColors.teal),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                const Icon(Icons.chevron_right, color: AppColors.teal),
              ],
            ),
          ),
        ),
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
        color: AppColors.plateYellow.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.plateYellow),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Text(
          'PicoRadar no presta estos servicios ni verifica proveedores en esta versión.\n'
          'Revisa identidad, precio y condiciones antes de contratar.',
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}

class _ExternalServiceAction {
  const _ExternalServiceAction({
    required this.key,
    required this.label,
    required this.category,
    required this.icon,
  });

  final String key;
  final String label;
  final String category;
  final IconData icon;
}

const _externalActions = [
  _ExternalServiceAction(
    key: 'tow',
    label: 'Buscar grúa 24 horas',
    category: 'grúa 24 horas',
    icon: Icons.local_shipping_outlined,
  ),
  _ExternalServiceAction(
    key: 'battery',
    label: 'Buscar batería',
    category: 'batería',
    icon: Icons.battery_charging_full_outlined,
  ),
  _ExternalServiceAction(
    key: 'tires',
    label: 'Buscar llantas',
    category: 'llantas',
    icon: Icons.tire_repair_outlined,
  ),
  _ExternalServiceAction(
    key: 'mechanic',
    label: 'Buscar taller mecánico',
    category: 'taller mecánico',
    icon: Icons.car_repair_outlined,
  ),
];
