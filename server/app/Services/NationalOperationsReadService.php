<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImportRow;
use App\Models\RestrictionPublicationItem;
use App\Models\RestrictionRuleVersion;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Gate;

final class NationalOperationsReadService
{
    private const STATES = [
        'sin_asignar',
        'off',
        'borrador',
        'validado',
        'publicacion_no_confirmada',
        'vencido',
        'sin_evidencia',
    ];

    /** @param array{department?:string,q?:string,state?:string,per_page?:int} $filters
     *  @return array{metrics:array<string,int|string>,rows:LengthAwarePaginator,filters:array<string,mixed>,departments:Collection<int,GeographicUnit>,release:array<string,string|null>}
     */
    public function dashboard(array $filters): array
    {
        $canEditDatasets = Gate::allows('datasets.edit');
        $canReviewDatasets = Gate::allows('datasets.review');
        $canEditJurisdictions = Gate::allows('jurisdictions.edit');
        $restrictionSchemaVersion = (int) (Dataset::query()->where('key', 'restrictions')->value('schema_version') ?? 1);
        $municipalities = $this->municipalityQuery($filters)->get();
        $jurisdictionsByMunicipality = $this->jurisdictionsByMunicipality($municipalities->modelKeys());
        $proposalRowsByMunicipality = $this->pendingProposalsByMunicipality($municipalities->pluck('code')->map(fn ($code): string => (string) $code));
        $asOf = now();
        $publishedVersionIds = $this->publicationHistoryVersionIds($jurisdictionsByMunicipality);

        $rows = $municipalities->map(function (GeographicUnit $unit) use ($jurisdictionsByMunicipality, $proposalRowsByMunicipality, $publishedVersionIds, $asOf, $canEditDatasets, $canReviewDatasets, $canEditJurisdictions, $restrictionSchemaVersion): array {
            $jurisdictions = collect($jurisdictionsByMunicipality[$unit->id] ?? [])->values();
            $pendingRows = collect($proposalRowsByMunicipality[(string) $unit->code] ?? []);
            $details = $jurisdictions->map(fn (Jurisdiction $jurisdiction): array => $this->jurisdictionSummary($jurisdiction, $asOf, $publishedVersionIds));
            $state = $this->stateFor($jurisdictions, $details);
            $firstProposal = $pendingRows->first();
            $action = $this->nextAction(
                $unit,
                $state,
                $jurisdictions,
                $details,
                $firstProposal,
                $canEditDatasets,
                $canReviewDatasets,
                $canEditJurisdictions,
                $restrictionSchemaVersion,
            );

            return [
                'municipality_code' => (string) $unit->code,
                'geographic_unit_id' => (int) $unit->id,
                'municipality_name' => $unit->name,
                'department_code' => (string) $unit->parent?->code,
                'department_name' => $unit->parent?->name ?? 'Sin departamento verificado',
                'state' => $state,
                'state_label' => $this->stateLabel($state),
                'reason' => $this->reasonFor($state, $jurisdictions, $details, $pendingRows->count()),
                'jurisdiction_count' => $jurisdictions->count(),
                'jurisdictions' => $details->all(),
                'latest_source_url' => $details->first(fn (array $detail): bool => $detail['source_url'] !== null)['source_url'] ?? null,
                'source_checked_at' => $details->first(fn (array $detail): bool => $detail['source_checked_at'] !== null)['source_checked_at'] ?? null,
                'stale_after' => $details->first(fn (array $detail): bool => $detail['stale_after'] !== null)['stale_after'] ?? null,
                'publication_note' => 'PUBLICACIÓN POR CIUDAD NO COMPROBADA',
                'pending_proposal_count' => $pendingRows->count(),
                'next_action_label' => $action['label'],
                'next_action_url' => $action['url'],
                'matrix_url' => route('admin.restrictions.municipalities'),
            ];
        });

        $stateFilter = (string) ($filters['state'] ?? '');
        if ($stateFilter !== '' && in_array($stateFilter, self::STATES, true)) {
            $rows = $rows->where('state', $stateFilter)->values();
        }

        $selectedRows = $rows->values();
        $metrics = $this->metrics($selectedRows, $jurisdictionsByMunicipality, $proposalRowsByMunicipality);
        $perPage = in_array((int) ($filters['per_page'] ?? 50), [25, 50], true) ? (int) $filters['per_page'] : 50;
        $page = max(1, (int) request()->query('page', 1));
        $paginator = new LengthAwarePaginator(
            $selectedRows->forPage($page, $perPage)->values(),
            $selectedRows->count(),
            $perPage,
            $page,
            ['path' => request()->url(), 'query' => request()->query()],
        );

        return [
            'metrics' => $metrics,
            'rows' => $paginator,
            'filters' => ['department' => (string) ($filters['department'] ?? ''), 'q' => (string) ($filters['q'] ?? ''), 'state' => $stateFilter, 'per_page' => $perPage],
            'departments' => GeographicUnit::query()
                ->where('level', GeographicUnitLevel::Department->value)
                ->where('is_active', true)
                ->orderBy('code')
                ->get(['id', 'code', 'name']),
            'release' => $this->currentReleaseSummary(),
            'generated_at' => $asOf,
        ];
    }

    /** @param array{department?:string,q?:string} $filters */
    private function municipalityQuery(array $filters): Builder
    {
        $query = GeographicUnit::query()
            ->with('parent:id,code,name')
            ->where('level', GeographicUnitLevel::Municipality->value)
            ->where('is_active', true)
            ->orderBy('parent_id')
            ->orderBy('code');

        $department = (string) ($filters['department'] ?? '');
        if ($department !== '') {
            $query->whereHas('parent', fn (Builder $parent) => $parent->where('code', $department));
        }
        $search = trim((string) ($filters['q'] ?? ''));
        if ($search !== '') {
            $query->where(function (Builder $match) use ($search): void {
                if (preg_match('/^\d{5}$/D', $search) === 1) {
                    $match->where('code', $search);
                } else {
                    $match->where('name', 'like', '%'.$search.'%');
                }
            });
        }

        return $query;
    }

    /** @param list<int> $municipalityIds @return array<int,list<Jurisdiction>> */
    private function jurisdictionsByMunicipality(array $municipalityIds): array
    {
        if ($municipalityIds === []) {
            return [];
        }

        $jurisdictions = Jurisdiction::query()
            ->with([
                'primaryGeographicUnit.parent',
                'geographicUnits',
                'restrictionRuleVersions' => fn (Builder $versions) => $versions->whereRaw(
                    'restriction_rule_versions.version = (select max(latest.version) from restriction_rule_versions as latest where latest.jurisdiction_id = restriction_rule_versions.jurisdiction_id)',
                ),
            ])
            ->where(function (Builder $query) use ($municipalityIds): void {
                $query->whereIn('primary_geographic_unit_id', $municipalityIds)
                    ->orWhereHas('geographicUnits', fn (Builder $units) => $units->whereIn('geographic_units.id', $municipalityIds));
            })
            ->orderBy('name')
            ->orderBy('id')
            ->get();

        $map = [];
        foreach ($jurisdictions as $jurisdiction) {
            $units = $jurisdiction->geographicUnits
                ->concat([$jurisdiction->primaryGeographicUnit])
                ->filter(fn ($unit): bool => $unit instanceof GeographicUnit && $unit->level === GeographicUnitLevel::Municipality);
            foreach ($units->unique('id') as $unit) {
                if (in_array($unit->id, $municipalityIds, true)) {
                    $map[$unit->id][$jurisdiction->id] = $jurisdiction;
                }
            }
        }

        return array_map(static fn (array $items): array => array_values($items), $map);
    }

    /** @param array<int,list<Jurisdiction>> $jurisdictionsByMunicipality @return Collection<int,int> */
    private function publicationHistoryVersionIds(array $jurisdictionsByMunicipality): Collection
    {
        $versionIds = collect($jurisdictionsByMunicipality)
            ->flatten(1)
            ->unique('id')
            ->flatMap(fn (Jurisdiction $jurisdiction) => $jurisdiction->restrictionRuleVersions->pluck('id'))
            ->filter()
            ->unique()
            ->values();
        if ($versionIds->isEmpty()) {
            return collect();
        }

        return RestrictionPublicationItem::query()
            ->whereIn('restriction_rule_version_id', $versionIds->all())
            ->distinct()
            ->pluck('restriction_rule_version_id')
            ->map(static fn ($id): int => (int) $id);
    }

    /** @param Collection<int,string> $municipalityCodes @return array<string,list<array{import_id:int,row_id:int}>> */
    private function pendingProposalsByMunicipality(Collection $municipalityCodes): array
    {
        $codes = $municipalityCodes->filter()->unique()->values()->all();
        if ($codes === []) {
            return [];
        }

        $rows = RestrictionImportRow::query()
            ->select(['id', 'restriction_import_id', 'normalized'])
            ->where('state', 'valid')
            ->where('publishable', true)
            ->where('normalized->onboarding->status', 'ALTA_PROPUESTA')
            ->whereIn('normalized->onboarding->municipality_code', $codes)
            ->whereHas('import', fn (Builder $imports) => $imports->where('status', RestrictionImportStatus::Analyzed->value))
            ->get();

        $map = [];
        foreach ($rows as $row) {
            $code = (string) ($row->normalized['onboarding']['municipality_code'] ?? '');
            if ($code !== '') {
                $map[$code][] = ['import_id' => (int) $row->restriction_import_id, 'row_id' => (int) $row->id];
            }
        }

        return $map;
    }

    /** @return array<string,mixed> */
    private function jurisdictionSummary(Jurisdiction $jurisdiction, mixed $asOf, Collection $publishedVersionIds): array
    {
        /** @var RestrictionRuleVersion|null $version */
        $version = $jurisdiction->restrictionRuleVersions->first();
        $url = $version ? $this->sourceUrl($version->payload ?? []) : null;
        $staleAfter = $version?->stale_after;
        $validUntil = $version?->valid_until;
        $stale = ($staleAfter !== null && $staleAfter->lessThanOrEqualTo($asOf)) ||
            ($validUntil !== null && $validUntil->toDateString() < $asOf->copy()->setTimezone('America/Bogota')->toDateString());
        $hasEvidence = $version !== null && $url !== null && $version->source_checked_at !== null && $staleAfter !== null;

        return [
            'id' => (int) $jurisdiction->id,
            'key' => $jurisdiction->key,
            'name' => $jurisdiction->name,
            'enabled' => (bool) $jurisdiction->enabled,
            'version_id' => $version?->id,
            'version_status' => $version?->status?->value,
            'source_url' => $url,
            'source_checked_at' => $version?->source_checked_at?->toAtomString(),
            'stale_after' => $staleAfter?->toAtomString(),
            'source_stale' => $stale,
            'has_evidence' => $hasEvidence,
            'has_publication_history' => $version !== null && $publishedVersionIds->contains($version->id),
        ];
    }

    /** @param array<string,mixed> $payload */
    private function sourceUrl(array $payload): ?string
    {
        foreach (($payload['coverages'] ?? []) as $coverage) {
            if (! is_array($coverage)) {
                continue;
            }
            $urls = is_array($coverage['sourceUrls'] ?? null) ? $coverage['sourceUrls'] : [];
            foreach (($coverage['rules'] ?? []) as $rule) {
                if (is_array($rule) && is_string($rule['sourceUrl'] ?? null)) {
                    $urls[] = $rule['sourceUrl'];
                }
            }
            foreach ($urls as $url) {
                if (! is_string($url) || trim($url) === '') {
                    continue;
                }
                $parts = parse_url($url);
                if (is_array($parts) && strtolower((string) ($parts['scheme'] ?? '')) === 'https' && trim((string) ($parts['host'] ?? '')) !== '' && ! isset($parts['user']) && ! isset($parts['pass'])) {
                    return $url;
                }
            }
        }

        return null;
    }

    /** @param Collection<int,Jurisdiction> $jurisdictions @param Collection<int,array<string,mixed>> $details */
    private function stateFor(Collection $jurisdictions, Collection $details): string
    {
        if ($jurisdictions->isEmpty()) {
            return 'sin_asignar';
        }
        if ($details->contains(fn (array $detail): bool => $detail['source_stale'])) {
            return 'vencido';
        }
        if ($details->contains(fn (array $detail): bool => ! $detail['has_evidence'])) {
            return 'sin_evidencia';
        }
        if ($jurisdictions->contains(fn (Jurisdiction $jurisdiction): bool => ! $jurisdiction->enabled)) {
            return 'off';
        }

        $versions = $jurisdictions->map(fn (Jurisdiction $jurisdiction) => $jurisdiction->restrictionRuleVersions->first())->filter();
        if ($versions->contains(fn (?RestrictionRuleVersion $version): bool => $version?->status === RestrictionRuleVersionStatus::Draft)) {
            return 'borrador';
        }
        if ($versions->contains(fn (?RestrictionRuleVersion $version): bool => $version?->status === RestrictionRuleVersionStatus::Validated)) {
            return $details->contains(fn (array $detail): bool => $detail['has_publication_history']) ? 'publicacion_no_confirmada' : 'validado';
        }

        return 'sin_evidencia';
    }

    /** @param Collection<int,array<string,mixed>> $selectedRows
     *  @param array<int,list<Jurisdiction>> $jurisdictionsByMunicipality
     *  @param array<string,list<array{import_id:int,row_id:int}>> $proposalRowsByMunicipality
     *  @return array<string,int|string>
     */
    private function metrics(Collection $selectedRows, array $jurisdictionsByMunicipality, array $proposalRowsByMunicipality): array
    {
        $municipalityIds = $selectedRows->pluck('municipality_code')->all();
        $jurisdictions = collect($municipalityIds)->flatMap(function (string $code) use ($selectedRows, $jurisdictionsByMunicipality): Collection {
            $unit = $selectedRows->firstWhere('municipality_code', $code);

            return collect($jurisdictionsByMunicipality[$unit['geographic_unit_id'] ?? -1] ?? []);
        })->unique('id')->values();
        $jurisdictionIds = $jurisdictions->pluck('id')->all();
        $versionCounts = $jurisdictionIds === [] ? collect() : RestrictionRuleVersion::query()
            ->whereIn('jurisdiction_id', $jurisdictionIds)
            ->selectRaw('status, count(*) as aggregate')
            ->groupBy('status')
            ->pluck('aggregate', 'status');
        $draftJurisdictionIds = $jurisdictionIds === [] ? collect() : RestrictionRuleVersion::query()
            ->whereIn('jurisdiction_id', $jurisdictionIds)
            ->where('status', RestrictionRuleVersionStatus::Draft->value)
            ->distinct()
            ->pluck('jurisdiction_id');
        $proposalCount = collect($municipalityIds)->sum(fn (string $code): int => count($proposalRowsByMunicipality[$code] ?? []));
        $assigned = $selectedRows->filter(fn (array $row): bool => $row['jurisdiction_count'] > 0)->count();

        return [
            'active_municipalities' => $selectedRows->count(),
            'associated_municipalities' => $assigned,
            'off_jurisdictions' => $jurisdictions->filter(fn (Jurisdiction $jurisdiction): bool => ! $jurisdiction->enabled)->count(),
            'jurisdictions_without_draft' => $jurisdictions->reject(fn (Jurisdiction $jurisdiction): bool => $draftJurisdictionIds->contains($jurisdiction->id))->count(),
            'draft_versions' => (int) ($versionCounts[RestrictionRuleVersionStatus::Draft->value] ?? 0),
            'validated_versions' => (int) ($versionCounts[RestrictionRuleVersionStatus::Validated->value] ?? 0),
            'pending_proposal_rows' => $proposalCount,
        ];
    }

    /** @param Collection<int,Jurisdiction> $jurisdictions @param Collection<int,array<string,mixed>> $details
     *  @param array{import_id:int,row_id:int}|null $proposal
     *  @return array{label:string,url:string}
     */
    private function nextAction(
        GeographicUnit $municipality,
        string $state,
        Collection $jurisdictions,
        Collection $details,
        ?array $proposal,
        bool $canEditDatasets,
        bool $canReviewDatasets,
        bool $canEditJurisdictions,
        int $restrictionSchemaVersion,
    ): array
    {
        if ($proposal !== null) {
            return $canEditDatasets
                ? ['label' => 'Revisar propuesta de importación', 'url' => route('admin.restrictions.imports.review', $proposal['import_id'])]
                : ['label' => 'Propuesta de importación pendiente · abrir matriz', 'url' => route('admin.restrictions.municipalities')];
        }
        $offDraft = $details->first(fn (array $detail): bool =>
            ! $detail['enabled']
            && $detail['version_id'] !== null
            && $detail['version_status'] === RestrictionRuleVersionStatus::Draft->value
        );
        if ($offDraft !== null) {
            return [
                'label' => $canEditDatasets ? 'Revisar borrador OFF' : 'Ver borrador OFF',
                'url' => route('admin.restrictions.edit', $offDraft['version_id']),
            ];
        }
        if ($jurisdictions->isEmpty()) {
            if ($canEditJurisdictions) {
                return [
                    'label' => 'Crear jurisdicción para este municipio',
                    'url' => route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $municipality->id]),
                ];
            }

            return $canEditDatasets
                ? ['label' => 'Analizar importación territorial', 'url' => route('admin.restrictions.import')]
                : ['label' => 'Abrir matriz municipal', 'url' => route('admin.restrictions.municipalities')];
        }
        if ($jurisdictions->count() > 1) {
            return ['label' => 'Resolver asignación en matriz', 'url' => route('admin.restrictions.municipalities')];
        }
        $detail = $details->first();
        if ($detail && $detail['enabled'] && $detail['version_id'] !== null && $detail['version_status'] === RestrictionRuleVersionStatus::Draft->value) {
            $label = $detail['enabled'] ? 'Revisar borrador y fuente' : 'Revisar borrador OFF';

            return ['label' => $label, 'url' => route('admin.restrictions.edit', $detail['version_id'])];
        }
        if ($detail && ! $detail['enabled']) {
            $offJurisdiction = $jurisdictions->first();
            $hasCanonicalMunicipality = $offJurisdiction instanceof Jurisdiction
                && (int) $offJurisdiction->primary_geographic_unit_id === (int) $municipality->id
                && $municipality->level === GeographicUnitLevel::Municipality
                && is_string($municipality->code)
                && preg_match('/^\d{5}$/D', $municipality->code) === 1;
            if ($canEditDatasets && $canEditJurisdictions && $restrictionSchemaVersion === 2 && $hasCanonicalMunicipality) {
                return [
                    'label' => 'Crear borrador OFF · no publicado',
                    'url' => route('admin.restrictions.create', ['jurisdiction_id' => $detail['id']]),
                ];
            }

            return ['label' => 'Ver jurisdicción OFF', 'url' => route('admin.jurisdictions.show', $detail['id'])];
        }
        if ($state === 'validado' || $state === 'publicacion_no_confirmada') {
            if ($canReviewDatasets) {
                return ['label' => 'Revisar publicación', 'url' => route('admin.restrictions.publish.preview')];
            }

            return $detail && $detail['version_id'] !== null
                ? ['label' => 'Ver versión editorial', 'url' => route('admin.restrictions.edit', $detail['version_id'])]
                : ['label' => 'Abrir matriz municipal', 'url' => route('admin.restrictions.municipalities')];
        }
        if ($detail) {
            return ['label' => 'Abrir matriz municipal', 'url' => route('admin.restrictions.municipalities')];
        }

        return ['label' => 'Abrir matriz municipal', 'url' => route('admin.restrictions.municipalities')];
    }

    private function reasonFor(string $state, Collection $jurisdictions, Collection $details, int $pendingProposalCount): string
    {
        if ($pendingProposalCount > 0) {
            return 'Hay propuestas de importación analizadas que esperan decisión humana.';
        }
        return match ($state) {
            'sin_asignar' => 'No hay una jurisdicción asociada al municipio en el catálogo editorial.',
            'off' => 'La jurisdicción asociada está deshabilitada; no habilita consulta ni circulación.',
            'borrador' => 'Existe un borrador editorial; no equivale a publicación distribuida.',
            'validado' => 'La última versión editorial está validada; la publicación por municipio no se ha comprobado.',
            'publicacion_no_confirmada' => 'Hay historial editorial de publicación, pero no se confirmó contra el asset vigente.',
            'vencido' => 'La vigencia editorial o la fecha de revisión registrada ya venció.',
            default => $jurisdictions->isEmpty()
                ? 'No se encontró evidencia editorial suficiente; la ausencia de reglas no significa permiso.'
                : 'Faltan fuente o fecha verificable para afirmar vigencia.',
        };
    }

    private function stateLabel(string $state): string
    {
        return match ($state) {
            'sin_asignar' => 'SIN ASIGNAR',
            'off' => 'DESHABILITADO',
            'borrador' => 'BORRADOR',
            'validado' => 'VALIDADO',
            'publicacion_no_confirmada' => 'PUBLICACIÓN NO COMPROBADA',
            'vencido' => 'VENCIDO',
            default => 'SIN EVIDENCIA',
        };
    }

    /** @return array{version:string|null,status:string,expires_at:string|null,asset_state:string} */
    private function currentReleaseSummary(): array
    {
        $dataset = Dataset::query()->where('key', 'restrictions')->first();
        if ($dataset === null || ! is_string($dataset->current_version) || $dataset->current_version === '') {
            return ['version' => null, 'status' => 'SIN RELEASE ACTUAL', 'expires_at' => null, 'asset_state' => 'NO VERIFICADO'];
        }
        $release = DatasetRelease::query()->where('dataset_id', $dataset->id)->where('version', $dataset->current_version)->first();
        if ($release === null || $release->status !== DatasetReleaseStatus::Published || ! $release->sha256 || ! $release->asset_path) {
            return ['version' => $dataset->current_version, 'status' => 'NO VERIFICADO', 'expires_at' => $release?->expires_at?->toAtomString(), 'asset_state' => 'NO VERIFICADO'];
        }
        $expired = $release->expires_at !== null && $release->expires_at->isPast();

        return [
            'version' => $release->version,
            'status' => $expired ? 'VENCIDO' : 'PUBLICADO REGISTRADO',
            'expires_at' => $release->expires_at?->toAtomString(),
            'asset_state' => 'HASH Y STORAGE NO COTEJADOS EN ESTA VISTA',
        ];
    }
}
