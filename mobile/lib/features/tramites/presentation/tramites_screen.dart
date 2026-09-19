import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/tramites_catalog.dart';

const _disclaimer =
    'Esta lista es una ayuda de preparación. Confirma siempre los requisitos, '
    'costos, vigencia y disponibilidad en el portal oficial.';

class TramitesScreen extends ConsumerStatefulWidget {
  const TramitesScreen({super.key});

  @override
  ConsumerState<TramitesScreen> createState() => _TramitesScreenState();
}

class _TramitesScreenState extends ConsumerState<TramitesScreen> {
  String _query = '';
  TramitesAuthority? _selectedAuthority;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(tramitesCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trámites')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _CatalogError(),
          data: (value) {
            final selected = _selectedAuthority;
            if (selected != null) {
              return _AuthorityDetail(
                authority: selected,
                reviewedAt: value.procedureReviewedAt,
                onBack: () => setState(() => _selectedAuthority = null),
                onOpenProcedure: _showProcedure,
                onOpenFallback: (url) => _openOfficial(url),
              );
            }
            return _CatalogSearch(
              catalog: value,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onSelect: (authority) {
                FocusScope.of(context).unfocus();
                setState(() => _selectedAuthority = authority);
              },
            );
          },
        ),
      ),
    );
  }

  void _showProcedure(TramitesProcedure procedure) {
    final checked = <String>{};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Padding(
                  key: const ValueKey('tramites-detail-sheet'),
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
                      Text(procedure.title, style: AppTextStyles.h2),
                      const SizedBox(height: AppSpacing.s),
                      Text(procedure.description, style: AppTextStyles.body),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        _disclaimer,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      FilledButton.icon(
                        key: const ValueKey('tramites-open-official'),
                        onPressed: () => _openOfficial(procedure.url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir portal oficial'),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        'Lista de preparación',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      for (final item in procedure.preparationItems)
                        CheckboxListTile(
                          key: ValueKey('tramites-check-$item'),
                          value: checked.contains(item),
                          onChanged: (value) {
                            setSheetState(() {
                              if (value ?? false) {
                                checked.add(item);
                              } else {
                                checked.remove(item);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
                        ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Revisado ${ref.read(tramitesCatalogProvider).value?.procedureReviewedAt ?? ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openOfficial(String url) async {
    final launcher = ref.read(externalLauncherProvider);
    var opened = false;
    try {
      opened = await launcher.openExternal(url);
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pudimos abrir el portal oficial.')),
    );
  }
}

class _CatalogSearch extends StatelessWidget {
  const _CatalogSearch({
    required this.catalog,
    required this.query,
    required this.onQueryChanged,
    required this.onSelect,
  });

  final TramitesCatalog catalog;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TramitesAuthority> onSelect;

  @override
  Widget build(BuildContext context) {
    final results = catalog.search(query);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CoveragePanel(),
              const SizedBox(height: AppSpacing.l),
              TextField(
                key: const ValueKey('tramites-search'),
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  labelText: 'Autoridad, municipio o departamento',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                '${_formatCount(results.length)} resultados',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('No encontramos autoridades.'))
                    : ListView.separated(
                        key: const ValueKey('tramites-results'),
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.s),
                        itemBuilder: (context, index) {
                          final authority = results[index];
                          return _AuthorityCard(
                            authority: authority,
                            onTap: () => onSelect(authority),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveragePanel extends ConsumerWidget {
  const _CoveragePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(tramitesCatalogProvider).requireValue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cobertura nacional', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.xs,
              children: [
                Text('${catalog.authorities.length} autoridades'),
                Text('${_formatCount(catalog.sourceRowCount)} filas fuente'),
                Text('${catalog.directAuthorityCount} con enlaces revisados'),
                Text(
                  '${catalog.authorities.length - catalog.directAuthorityCount} por confirmar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorityCard extends StatelessWidget {
  const _AuthorityCard({required this.authority, required this.onTap});

  final TramitesAuthority authority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: ValueKey('tramites-authority-${authority.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                authority.hasDirectProcedures
                    ? Icons.verified_outlined
                    : Icons.account_balance_outlined,
                color: authority.hasDirectProcedures
                    ? AppColors.green
                    : AppColors.navy,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authority.name, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${authority.municipality} · ${authority.department}',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      authority.statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: authority.hasDirectProcedures
                            ? AppColors.green
                            : AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorityDetail extends StatelessWidget {
  const _AuthorityDetail({
    required this.authority,
    required this.reviewedAt,
    required this.onBack,
    required this.onOpenProcedure,
    required this.onOpenFallback,
  });

  final TramitesAuthority authority;
  final String reviewedAt;
  final VoidCallback onBack;
  final ValueChanged<TramitesProcedure> onOpenProcedure;
  final ValueChanged<String> onOpenFallback;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('tramites-authority-detail'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        96,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Autoridades'),
                ),
              ),
              Text(authority.name, style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${authority.municipality} · ${authority.department}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                authority.statusLabel,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: authority.hasDirectProcedures
                      ? AppColors.green
                      : AppColors.orange,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              if (authority.hasDirectProcedures) ...[
                for (final procedure in authority.procedures) ...[
                  _ProcedureCard(
                    authorityId: authority.id,
                    procedure: procedure,
                    onTap: () => onOpenProcedure(procedure),
                  ),
                  const SizedBox(height: AppSpacing.s),
                ],
                Text(
                  'Revisión de enlaces: $reviewedAt',
                  style: AppTextStyles.caption,
                ),
              ] else ...[
                const Text(
                  'No hay enlaces directos de trámites revisados para esta autoridad.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  'La presencia en el inventario no confirma que esta entidad tramite matrículas, traspasos o certificados.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                FilledButton.icon(
                  key: const ValueKey('tramites-open-fallback'),
                  onPressed: authority.fallbackUrl == null
                      ? null
                      : () => onOpenFallback(authority.fallbackUrl!),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    authority.fallbackKind == TramitesFallbackKind.institution
                        ? 'Abrir sitio institucional'
                        : 'Consultar directorio RUNT',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({
    required this.authorityId,
    required this.procedure,
    required this.onTap,
  });

  final String authorityId;
  final TramitesProcedure procedure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: ValueKey('tramites-card-$authorityId-${procedure.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(procedure.title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(procedure.description, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: Text('No pudimos cargar el catálogo oficial de trámites.'),
      ),
    );
  }
}

String _formatCount(int value) {
  final raw = value.toString();
  if (raw.length <= 3) return raw;
  return '${raw.substring(0, raw.length - 3)}.${raw.substring(raw.length - 3)}';
}
