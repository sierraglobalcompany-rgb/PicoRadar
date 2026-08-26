import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../theme/app_tokens.dart';
import 'app_routes.dart';

class RootPlaceholderScreen extends StatefulWidget {
  const RootPlaceholderScreen({required this.tab, super.key});

  final AppTab tab;

  @override
  State<RootPlaceholderScreen> createState() => _RootPlaceholderScreenState();
}

class _RootPlaceholderScreenState extends State<RootPlaceholderScreen> {
  int _stateMarker = 0;

  @override
  Widget build(BuildContext context) {
    final color = widget.tab.color;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.tab.icon, color: color, size: AppIconSize.l),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      widget.tab.label,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(widget.tab.placeholderText),
                    const SizedBox(height: AppSpacing.l),
                    OutlinedButton(
                      key: ValueKey('state-button-${widget.tab.name}'),
                      onPressed: () => setState(() => _stateMarker++),
                      child: Text('Estado local $_stateMarker'),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.tab == AppTab.home) ...[
              const SizedBox(height: AppSpacing.l),
              TextButton(
                key: const ValueKey('open-immersive-route'),
                onPressed: () => context.push(AppRoute.immersivePreview.path),
                child: const Text('Probar ruta inmersiva'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
