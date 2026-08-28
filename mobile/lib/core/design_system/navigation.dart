import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        key: const ValueKey('app-bottom-navigation'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.08),
              offset: const Offset(0, -4),
              blurRadius: 18,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.xs,
            AppSpacing.m,
            0,
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _BottomNavItem(
                    key: ValueKey(
                      'tab-${destinations[index].keyName ?? destinations[index].label}',
                    ),
                    centerRaised: index == 2,
                    destination: destinations[index],
                    selected: index == currentIndex,
                    reduceMotion: reduceMotion,
                    onTap: () => _select(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    if (index != currentIndex) {
      HapticFeedback.selectionClick();
    }
    onSelect(index);
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.centerRaised,
    required this.destination,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
    super.key,
  });

  final bool centerRaised;
  final AppBottomNavDestination destination;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.navBounce,
    );
    _scale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 0.86), weight: 36),
          TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.06), weight: 38),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 26),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
        );
    _lift =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -4), weight: 55),
          TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 45),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final destination = widget.destination;
    final color = selected || widget.centerRaised
        ? destination.color
        : AppColors.navy.withValues(alpha: 0.72);
    final icon = selected ? destination.selectedIcon : destination.icon;
    final child = widget.centerRaised
        ? _CenterAppsItem(
            destination: destination,
            icon: icon,
            selected: selected,
            onTap: _onTap,
          )
        : _SideNavItem(
            destination: destination,
            icon: icon,
            color: color,
            selected: selected,
            onTap: _onTap,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: widget.reduceMotion
          ? child
          : AnimatedBuilder(
              animation: _controller,
              child: child,
              builder: (context, child) {
                final lift = widget.centerRaised ? _lift.value : 0.0;
                return Transform.translate(
                  key: const ValueKey('app-bottom-nav-motion-transform'),
                  offset: Offset(0, lift),
                  child: Transform.scale(scale: _scale.value, child: child),
                );
              },
            ),
    );
  }

  void _onTap() {
    if (!widget.reduceMotion) {
      _controller.forward(from: 0);
    }
    widget.onTap();
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.destination,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fade,
                  curve: AppMotion.standardCurve,
                  width: selected ? 28 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                ),
                const SizedBox(height: 5),
                _NavGlyph(
                  icon: icon,
                  color: color,
                  drive: destination.keyName == 'drive',
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
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

class _CenterAppsItem extends StatelessWidget {
  const _CenterAppsItem({
    required this.destination,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.fade,
                curve: AppMotion.standardCurve,
                width: selected ? 30 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                key: const ValueKey('app-bottom-nav-apps-halo'),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teal.withValues(
                        alpha: selected ? 0.22 : 0.14,
                      ),
                      offset: const Offset(0, 5),
                      blurRadius: selected ? 12 : 9,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedContainer(
                    key: const ValueKey('app-bottom-nav-apps-center'),
                    duration: AppMotion.fade,
                    curve: AppMotion.standardCurve,
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal,
                    ),
                    child: Icon(icon, color: AppColors.surface, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({
    required this.icon,
    required this.color,
    required this.drive,
  });

  final IconData icon;
  final Color color;
  final bool drive;

  @override
  Widget build(BuildContext context) {
    if (drive) {
      return CustomPaint(
        key: const ValueKey('app-bottom-nav-drive-wheel'),
        size: const Size.square(23),
        painter: _SteeringWheelPainter(color),
      );
    }
    return Icon(icon, color: color, size: 22);
  }
}

class _SteeringWheelPainter extends CustomPainter {
  const _SteeringWheelPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + radius * 0.78),
      paint,
    );
    canvas.drawLine(
      center,
      Offset(center.dx - radius * 0.76, center.dy + radius * 0.12),
      paint,
    );
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.76, center.dy + radius * 0.12),
      paint,
    );
    canvas.drawCircle(
      center,
      stroke * 0.56,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SteeringWheelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
