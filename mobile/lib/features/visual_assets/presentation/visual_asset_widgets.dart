import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../data/vehicle_visual_resolver.dart';
import '../data/visual_asset_catalogs.dart';
import '../data/visual_asset_preferences.dart';

class HomeAvatarButton extends ConsumerWidget {
  const HomeAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(avatarCatalogProvider);
    final selected = ref.watch(selectedAvatarIdProvider);
    return catalog.when(
      data: (items) {
        final selectedId = selected.asData?.value;
        final asset = items.assetById(selectedId) ?? items.defaultAsset;
        return Semantics(
          button: true,
          label: 'Cambiar avatar',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('home-avatar-button'),
              borderRadius: BorderRadius.circular(28),
              onTap: () => showAvatarPicker(context, ref),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.42),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: asset == null
                    ? const Icon(Icons.person_rounded, color: AppColors.teal)
                    : Image.asset(
                        asset.asset,
                        key: ValueKey('home-avatar-image-${asset.id}'),
                        fit: BoxFit.cover,
                        cacheWidth: 112,
                        cacheHeight: 112,
                      ),
              ),
            ),
          ),
        );
      },
      loading: () => const _AvatarFallback(),
      error: (error, stackTrace) => const _AvatarFallback(),
    );
  }
}

class VehicleVisualImage extends ConsumerWidget {
  const VehicleVisualImage({
    required this.vehicle,
    required this.fallbackBuilder,
    this.cacheWidth = 360,
    super.key,
  });

  final VehicleProfile vehicle;
  final WidgetBuilder fallbackBuilder;
  final int cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vehicleVisualCatalogProvider);
    final overrideId = ref.watch(vehicleVisualOverrideProvider(vehicle.id));
    return catalog.when(
      data: (items) {
        final resolver = VehicleVisualResolver(items);
        final asset = resolver.resolve(
          vehicle,
          overrideId: overrideId.asData?.value,
        );
        if (asset == null) {
          return fallbackBuilder(context);
        }
        return Semantics(
          image: true,
          label: 'Imagen de ${vehicle.plate}',
          child: Image.asset(
            asset.asset,
            key: ValueKey('vehicle-visual-image-${vehicle.id}'),
            fit: BoxFit.contain,
            cacheWidth: cacheWidth,
          ),
        );
      },
      loading: () => fallbackBuilder(context),
      error: (error, stackTrace) => fallbackBuilder(context),
    );
  }
}

Future<void> showAvatarPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AvatarPickerSheet(),
  );
}

Future<void> showVehicleVisualPicker(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile vehicle,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _VehicleVisualPickerSheet(vehicle: vehicle),
  );
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      key: ValueKey('home-avatar-fallback'),
      radius: 26,
      backgroundColor: Color(0xFFEAF4F3),
      child: Icon(Icons.person_rounded, color: AppColors.teal),
    );
  }
}

class _AvatarPickerSheet extends ConsumerWidget {
  const _AvatarPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(avatarCatalogProvider);
    final selected = ref.watch(selectedAvatarIdProvider);
    return _SheetScaffold(
      title: 'Elige tu avatar',
      child: catalog.when(
        data: (items) {
          final selectedId = selected.asData?.value ?? items.defaultId;
          return GridView.builder(
            key: const ValueKey('avatar-picker-grid'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xl,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 112,
              mainAxisSpacing: AppSpacing.m,
              crossAxisSpacing: AppSpacing.m,
            ),
            itemCount: items.items.length,
            itemBuilder: (context, index) {
              final item = items.items[index];
              final isSelected = item.id == selectedId;
              return _AvatarOption(
                item: item,
                selected: isSelected,
                onTap: () async {
                  await saveSelectedAvatarId(
                    ref.read(appPreferencesProvider),
                    item.id,
                  );
                  ref.invalidate(selectedAvatarIdProvider);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _VehicleVisualPickerSheet extends ConsumerWidget {
  const _VehicleVisualPickerSheet({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vehicleVisualCatalogProvider);
    final overrideId = ref.watch(vehicleVisualOverrideProvider(vehicle.id));
    return _SheetScaffold(
      title: 'Cambiar imagen',
      child: catalog.when(
        data: (items) {
          final resolver = VehicleVisualResolver(items);
          final options = resolver.optionsFor(vehicle);
          final selectedId = overrideId.asData?.value;
          return GridView.builder(
            key: const ValueKey('vehicle-visual-picker-grid'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xl,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 156,
              mainAxisSpacing: AppSpacing.m,
              crossAxisSpacing: AppSpacing.m,
              childAspectRatio: 1.05,
            ),
            itemCount: options.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AutoVisualOption(
                  selected: selectedId == null,
                  onTap: () async {
                    await clearVehicleVisualOverride(
                      ref.read(appPreferencesProvider),
                      vehicle.id,
                    );
                    ref.invalidate(vehicleVisualOverrideProvider(vehicle.id));
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              }
              final item = options[index - 1];
              return _VehicleVisualOption(
                item: item,
                selected: item.id == selectedId,
                onTap: () async {
                  await saveVehicleVisualOverride(
                    ref.read(appPreferencesProvider),
                    vehicle.id,
                    item.id,
                  );
                  ref.invalidate(vehicleVisualOverrideProvider(vehicle.id));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.74;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: Text(title, style: AppTextStyles.h2),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AvatarAsset item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      key: ValueKey('avatar-option-${item.id}'),
      label: item.displayName,
      selected: selected,
      onTap: onTap,
      child: ClipOval(
        child: Image.asset(
          item.asset,
          fit: BoxFit.cover,
          cacheWidth: 128,
          cacheHeight: 128,
        ),
      ),
    );
  }
}

class _AutoVisualOption extends StatelessWidget {
  const _AutoVisualOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      key: const ValueKey('vehicle-visual-auto-option'),
      label: 'Automático',
      selected: selected,
      onTap: onTap,
      child: const Icon(
        Icons.auto_awesome_outlined,
        color: AppColors.teal,
        size: 34,
      ),
    );
  }
}

class _VehicleVisualOption extends StatelessWidget {
  const _VehicleVisualOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final VehicleVisualAsset item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      key: ValueKey('vehicle-visual-option-${item.id}'),
      label: item.displayName,
      selected: selected,
      onTap: onTap,
      child: Image.asset(item.asset, fit: BoxFit.contain, cacheWidth: 220),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.teal : AppColors.border;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    child: child,
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 5,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
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
