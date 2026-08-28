import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.h1),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.m),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppBottomNavDestination {
  const AppBottomNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    this.keyName,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final String? keyName;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  }) : assert(destinations.length == 5, 'PicoRadar bottom nav has five tabs.');

  final List<AppBottomNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        key: const ValueKey('app-bottom-navigation'),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _BottomNavItem(
                    key: ValueKey(
                      'tab-${destinations[index].keyName ?? destinations[index].label}',
                    ),
                    destination: destinations[index],
                    selected: index == currentIndex,
                    onTap: () => onSelect(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? destination.color : AppColors.navy;
    final icon = selected ? destination.selectedIcon : destination.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.s,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    width: selected ? 48 : 40,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Icon(icon, color: color, size: AppIconSize.m),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
