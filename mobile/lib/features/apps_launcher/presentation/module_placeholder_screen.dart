import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/module_registry.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({required this.moduleId, super.key});

  final String moduleId;

  @override
  Widget build(BuildContext context) {
    final module = findModuleById(moduleId);
    final title = module?.title ?? 'Módulo';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    module?.icon ?? Icons.apps,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const Text(
                    'Próximamente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const Text(
                    'Este módulo estará disponible en una próxima etapa.',
                    textAlign: TextAlign.center,
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
