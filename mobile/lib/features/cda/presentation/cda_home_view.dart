import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/cda_catalog.dart';

class CdaHomeView extends StatelessWidget {
  const CdaHomeView({
    super.key,
    required this.catalog,
    required this.operationalCount,
    required this.geoReady,
    required this.onDirectory,
    required this.onMap,
    required this.onNearby,
    required this.onSource,
  });
  final CdaCatalog catalog;
  final int operationalCount;
  final bool geoReady;
  final VoidCallback onDirectory, onMap, onNearby, onSource;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final enlarged = MediaQuery.textScalerOf(context).scale(16) > 20;
      return SingleChildScrollView(
        key: const ValueKey('cda-home-scroll'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tu próximo CDA',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        if (!enlarged)
                          Image.asset(
                            'assets/vehicles/cda_center_owner_v1.png',
                            width: 112,
                            height: 92,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stack) =>
                                const SizedBox(
                                  width: 88,
                                  height: 72,
                                  child: Icon(
                                    Icons.garage_outlined,
                                    size: 48,
                                    color: AppColors.teal,
                                  ),
                                ),
                          ),
                      ],
                    ),
                    const Text(
                      'Centros incluidos en el catálogo RUNT.',
                      style: TextStyle(fontSize: 16, color: AppColors.navy),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: onDirectory,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, size: 26),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Buscar ciudad o CDA',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (enlarged) ...[
                      _CdaPath(
                        key: const ValueKey('cda-use-location'),
                        title: 'Cerca de mí',
                        subtitle: geoReady
                            ? 'Usar ubicación'
                            : 'Ubicación por verificar',
                        icon: Icons.my_location,
                        onTap: onNearby,
                        primary: true,
                        compact: true,
                      ),
                      const SizedBox(height: 8),
                      _CdaPath(
                        key: const ValueKey('cda-map-open'),
                        title: 'Explorar mapa',
                        subtitle: geoReady
                            ? 'Ver centros'
                            : 'Ubicaciones por verificar',
                        icon: Icons.map_outlined,
                        onTap: onMap,
                        compact: true,
                      ),
                    ] else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _CdaPath(
                                key: const ValueKey('cda-use-location'),
                                title: 'Cerca de mí',
                                subtitle: geoReady
                                    ? 'Usar ubicación'
                                    : 'Por verificar',
                                icon: Icons.my_location,
                                onTap: onNearby,
                                primary: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CdaPath(
                                key: const ValueKey('cda-map-open'),
                                title: 'Explorar mapa',
                                subtitle: geoReady
                                    ? 'Ver centros'
                                    : 'Por verificar',
                                icon: Icons.map_outlined,
                                onTap: onMap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const ValueKey('cda-directory-open'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: onDirectory,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                color: Colors.white,
                                size: 30,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Directorio RUNT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$operationalCount CDA disponibles',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Buscar y filtrar',
                                      style: TextStyle(
                                        color: Color(0xFF83E5DC),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    TextButton.icon(
                      key: const ValueKey('cda-source-open'),
                      onPressed: onSource,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: Text(
                        'Fuente y actualización · ${catalog.source.latestSourceMonthName.toLowerCase()} ${catalog.source.latestSourceYear}',
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CdaPath extends StatelessWidget {
  const _CdaPath({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.compact = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary, compact;
  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.navy;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: foreground)),
      ],
    );
    return Material(
      color: primary ? AppColors.teal : const Color(0xFFE6F4F3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: compact
              ? Row(
                  children: [
                    Icon(icon, size: 28, color: foreground),
                    const SizedBox(width: 16),
                    Expanded(child: words),
                    Icon(Icons.chevron_right, color: foreground),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 32, color: foreground),
                    const SizedBox(height: 16),
                    words,
                  ],
                ),
        ),
      ),
    );
  }
}
