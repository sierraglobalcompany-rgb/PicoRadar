import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/data/vehicle_repository.dart';

const onboardingVehicleDraftKey = 'onboarding_vehicle_draft_v1';
const picoRestrictionAlertsPreferenceKey = 'pico_restriction_alerts_enabled_v1';

enum OnboardingVehicleChoice {
  privateCar(
    label: 'Carro particular',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    icon: Icons.directions_car,
    subtypeOptions: [
      SubtypeOption('car_hatchback', 'Automóvil / hatchback'),
      SubtypeOption('car_sedan', 'Sedán'),
      SubtypeOption('car_coupe', 'Coupé'),
      SubtypeOption('car_suv', 'SUV / crossover'),
      SubtypeOption('car_pickup', 'Pick-up'),
      SubtypeOption('car_van', 'Van'),
    ],
  ),
  motorcycle(
    label: 'Moto',
    kind: VehicleKind.motorcycle,
    serviceType: VehicleServiceType.private,
    icon: Icons.two_wheeler,
    subtypeOptions: [
      SubtypeOption('moto_scooter', 'Scooter'),
      SubtypeOption('moto_naked', 'Naked'),
      SubtypeOption('moto_sport', 'Deportiva'),
      SubtypeOption('moto_adventure', 'Adventure / doble propósito'),
      SubtypeOption('moto_cruiser', 'Cruiser'),
    ],
  ),
  taxi(
    label: 'Taxi',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.taxi,
    icon: Icons.local_taxi,
    subtypeOptions: [SubtypeOption('taxi', 'Taxi')],
  );

  const OnboardingVehicleChoice({
    required this.label,
    required this.kind,
    required this.serviceType,
    required this.icon,
    required this.subtypeOptions,
  });

  final String label;
  final VehicleKind kind;
  final VehicleServiceType serviceType;
  final IconData icon;
  final List<SubtypeOption> subtypeOptions;
}

class OnboardingVehicleScreen extends ConsumerStatefulWidget {
  const OnboardingVehicleScreen({super.key});

  @override
  ConsumerState<OnboardingVehicleScreen> createState() {
    return _OnboardingVehicleScreenState();
  }
}

class _OnboardingVehicleScreenState
    extends ConsumerState<OnboardingVehicleScreen> {
  final _plateController = TextEditingController();
  final _cityController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  OnboardingVehicleChoice? _choice;
  String? _subtype;
  bool _alertsEnabled = true;
  bool _loadedDraft = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_saveDraft);
    }
  }

  Iterable<TextEditingController> get _controllers sync* {
    yield _plateController;
    yield _cityController;
    yield _nicknameController;
    yield _brandController;
    yield _modelController;
    yield _yearController;
    yield _colorController;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedDraft) {
      _loadedDraft = true;
      Future<void>.microtask(_restoreDraft);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_saveDraft);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _choice == null ? 1 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar vehículo'),
        leading: IconButton(
          key: const ValueKey('onboarding-back'),
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paso $step de 2'),
                  const SizedBox(height: AppSpacing.s),
                  if (_choice == null) _buildChoiceStep(context),
                  if (_choice != null) _buildFormStep(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Qué conduces?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.m,
              crossAxisSpacing: AppSpacing.m,
              childAspectRatio: columns == 1 ? 3.6 : 1.25,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in OnboardingVehicleChoice.values)
                  _ChoiceCard(
                    key: ValueKey('vehicle-choice-${option.name}'),
                    option: option,
                    onTap: () {
                      setState(() {
                        _choice = option;
                        _subtype = option == OnboardingVehicleChoice.taxi
                            ? 'taxi'
                            : null;
                        _error = null;
                      });
                      _saveDraft();
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFormStep(BuildContext context) {
    final choice = _choice!;
    final subtypeOptions = choice.subtypeOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(choice.label, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.l),
        TextField(
          key: const ValueKey('vehicle-plate-field'),
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Placa *'),
        ),
        const SizedBox(height: AppSpacing.m),
        TextField(
          key: const ValueKey('vehicle-city-field'),
          controller: _cityController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Ciudad de matrícula / registro *',
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        DropdownButtonFormField<String>(
          key: const ValueKey('vehicle-subtype-field'),
          initialValue: _subtype,
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin subtipo')),
            for (final option in subtypeOptions)
              DropdownMenuItem(value: option.value, child: Text(option.label)),
          ],
          onChanged: choice == OnboardingVehicleChoice.taxi
              ? null
              : (value) {
                  setState(() => _subtype = value);
                  _saveDraft();
                },
          decoration: const InputDecoration(labelText: 'Subtipo opcional'),
        ),
        const SizedBox(height: AppSpacing.m),
        TextField(
          key: const ValueKey('vehicle-nickname-field'),
          controller: _nicknameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Apodo'),
        ),
        const SizedBox(height: AppSpacing.m),
        _TwoColumnFields(
          first: TextField(
            key: const ValueKey('vehicle-brand-field'),
            controller: _brandController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Marca'),
          ),
          second: TextField(
            key: const ValueKey('vehicle-model-field'),
            controller: _modelController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Modelo'),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        _TwoColumnFields(
          first: TextField(
            key: const ValueKey('vehicle-year-field'),
            controller: _yearController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Año'),
          ),
          second: TextField(
            key: const ValueKey('vehicle-color-field'),
            controller: _colorController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Color'),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        SwitchListTile(
          key: const ValueKey('pico-alerts-toggle'),
          value: _alertsEnabled,
          contentPadding: EdgeInsets.zero,
          title: const Text('Quiero recibir alertas de Pico y Placa'),
          onChanged: (value) {
            setState(() => _alertsEnabled = value);
            _saveDraft();
          },
        ),
        const SizedBox(height: AppSpacing.s),
        const Text(
          'Después podrás agregar SOAT, tecnomecánica y seguro desde tu Garaje.',
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.m),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('vehicle-back-to-choice'),
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        _choice = null;
                        _subtype = null;
                        _error = null;
                      });
                      _saveDraft();
                    },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Atrás'),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: FilledButton(
                key: const ValueKey('vehicle-save-button'),
                onPressed: _saving ? null : _saveVehicle,
                child: Text(_saving ? 'Guardando...' : 'Continuar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _restoreDraft() async {
    final raw = await ref
        .read(appPreferencesProvider)
        .getString(onboardingVehicleDraftKey);
    if (raw == null || raw.isEmpty || !mounted) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?> || !mounted) {
      return;
    }

    setState(() {
      _choice = _choiceFromName(decoded['choice'] as String?);
      _subtype = decoded['subtype'] as String?;
      _alertsEnabled = decoded['alertsEnabled'] as bool? ?? true;
      _plateController.text = decoded['plate'] as String? ?? '';
      _cityController.text = decoded['registrationCity'] as String? ?? '';
      _nicknameController.text = decoded['nickname'] as String? ?? '';
      _brandController.text = decoded['brand'] as String? ?? '';
      _modelController.text = decoded['model'] as String? ?? '';
      _yearController.text = decoded['year'] as String? ?? '';
      _colorController.text = decoded['color'] as String? ?? '';
    });
  }

  Future<void> _saveDraft() async {
    if (!_loadedDraft) {
      return;
    }

    final draft = <String, Object?>{
      'choice': _choice?.name,
      'subtype': _subtype,
      'plate': _plateController.text,
      'registrationCity': _cityController.text,
      'nickname': _nicknameController.text,
      'brand': _brandController.text,
      'model': _modelController.text,
      'year': _yearController.text,
      'color': _colorController.text,
      'alertsEnabled': _alertsEnabled,
    };

    await ref
        .read(appPreferencesProvider)
        .setString(onboardingVehicleDraftKey, jsonEncode(draft));
  }

  Future<void> _saveVehicle() async {
    final choice = _choice;
    if (choice == null) {
      return;
    }

    final city = _cityController.text.trim();
    if (_plateController.text.trim().isEmpty) {
      setState(() => _error = 'La placa es obligatoria.');
      return;
    }
    if (city.isEmpty) {
      setState(() => _error = 'La ciudad de matrícula es obligatoria.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = ref.read(vehicleRepositoryProvider);
      final vehicle = await repository.createVehicle(
        plate: _plateController.text,
        kind: choice.kind,
        serviceType: choice.serviceType,
        subtype: _subtype,
        nickname: _nicknameController.text,
        registrationCity: city,
        brand: _brandController.text,
        model: _modelController.text,
        year: _yearController.text.trim().isEmpty
            ? null
            : int.parse(_yearController.text.trim()),
        color: _colorController.text,
      );

      await repository.setActiveVehicle(vehicle.id);
      final preferences = ref.read(appPreferencesProvider);
      await preferences.setBool(
        picoRestrictionAlertsPreferenceKey,
        _alertsEnabled,
      );
      await preferences.remove(onboardingVehicleDraftKey);
      ref.invalidate(vehicleListProvider);

      if (mounted) {
        context.go(AppRoute.home.path);
      }
    } on VehicleRepositoryException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on FormatException {
      if (mounted) {
        setState(() => _error = 'El año debe ser numérico.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  OnboardingVehicleChoice? _choiceFromName(String? name) {
    for (final choice in OnboardingVehicleChoice.values) {
      if (choice.name == name) {
        return choice;
      }
    }
    return null;
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.option, required this.onTap, super.key});

  final OnboardingVehicleChoice option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
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
            padding: const EdgeInsets.all(AppSpacing.l),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wideCard =
                    constraints.maxWidth > constraints.maxHeight * 2;
                final label = Text(
                  option.label,
                  textAlign: wideCard ? TextAlign.start : TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                );

                if (wideCard) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(option.icon, color: color, size: 36),
                      const SizedBox(width: AppSpacing.l),
                      Flexible(child: label),
                    ],
                  );
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, color: color, size: 36),
                    const SizedBox(height: AppSpacing.m),
                    label,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              first,
              const SizedBox(height: AppSpacing.m),
              second,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class SubtypeOption {
  const SubtypeOption(this.value, this.label);

  final String value;
  final String label;
}
