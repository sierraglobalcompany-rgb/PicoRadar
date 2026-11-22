<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DatasetReleaseStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Http\Controllers\Controller;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Services\RestrictionFormPayloadBuilder;
use App\Services\RestrictionImportService;
use App\Services\RestrictionPayloadEncoder;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;

class RestrictionRuleController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('datasets.view');

        $filters = $this->restrictionFilters($request);
        $query = $this->jurisdictionsForFilters($filters);
        $perPage = 50;
        $page = $this->boundedPage($request);
        $offset = ($page - 1) * $perPage;
        $rows = [];
        $total = 0;

        foreach ($query->lazy(100) as $jurisdiction) {
            $version = $jurisdiction->restrictionRuleVersions->first();
            $coverages = $this->coverageSummariesForVersion($version, $filters);
            if ($coverages->isEmpty()) {
                continue;
            }
            if ($total >= $offset && $total < $offset + $perPage) {
                $rows[] = ['jurisdiction' => $jurisdiction, 'version' => $version, 'coverages' => $coverages];
            }
            $total++;
        }

        $jurisdictions = new LengthAwarePaginator(
            $rows,
            $total,
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $filters],
        );

        return view('admin.restrictions.index', [
            'operator' => $request->user(),
            'jurisdictions' => $jurisdictions,
            'departments' => GeographicUnit::query()->where('level', 'department')->where('is_active', true)->orderBy('name')->get(['code', 'name']),
            'filters' => [
                ...$filters,
            ],
            'dataset' => Dataset::query()->where('key', 'restrictions')->first(),
        ]);
    }

    public function municipalities(Request $request)
    {
        Gate::authorize('datasets.view');

        $filters = $this->municipalityMatrixFilters($request);
        $currentSnapshot = $this->currentRestrictionSnapshot();
        $query = $this->municipalityCoverageQuery();

        if ($filters['q'] !== '') {
            $search = $filters['q'];
            $query->where(function (Builder $query) use ($search): void {
                $query->where('name', 'like', "%$search%")
                    ->orWhere('code', 'like', "%$search%")
                    ->orWhere('key', 'like', "%$search%")
                    ->orWhereHas('parent', fn (Builder $parent) => $parent
                        ->where('name', 'like', "%$search%")
                        ->orWhere('code', 'like', "%$search%"))
                    ->orWhereHas('jurisdictions', fn (Builder $jurisdiction) => $jurisdiction
                        ->where('name', 'like', "%$search%")
                        ->orWhere('key', 'like', "%$search%"));
            });
        }
        if ($filters['department'] !== '') {
            $department = $filters['department'];
            $query->whereHas('parent', fn (Builder $parent) => $parent->where('code', $department));
        }
        if ($filters['management'] === 'unassigned') {
            $query->whereDoesntHave('jurisdictions');
        } elseif (in_array($filters['management'], ['active', 'inactive'], true)) {
            $enabled = $filters['management'] === 'active';
            $query->whereHas('jurisdictions', fn (Builder $jurisdictions) => $jurisdictions->where('enabled', $enabled));
        }

        $perPage = 50;
        $page = $this->boundedPage($request);
        $offset = ($page - 1) * $perPage;
        $rows = [];
        $total = 0;

        foreach ($query->orderBy('parent_id')->orderBy('code')->orderBy('id')->lazy(100) as $municipality) {
            $entries = $this->municipalityCoverageEntries($municipality, $filters, $currentSnapshot);
            if ($entries === []) {
                continue;
            }
            if ($total >= $offset && $total < $offset + $perPage) {
                $rows[] = ['municipality' => $municipality, 'entries' => $entries];
            }
            $total++;
        }

        $municipalities = new LengthAwarePaginator(
            $rows,
            $total,
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $filters],
        );

        return view('admin.restrictions.municipalities', [
            'operator' => $request->user(),
            'municipalities' => $municipalities,
            'departments' => GeographicUnit::query()->where('level', 'department')->where('is_active', true)->orderBy('name')->get(['code', 'name']),
            'filters' => $filters,
            'currentRelease' => $currentSnapshot['release'],
        ]);
    }

    public function exportCoverage(Request $request): StreamedResponse
    {
        Gate::authorize('datasets.view');
        $scope = $request->query('scope', 'editorial');
        abort_unless(is_string($scope) && in_array($scope, ['editorial', 'published', 'municipalities'], true), 422);
        $filters = $this->restrictionFilters($request);

        return response()->streamDownload(function () use ($scope, $filters): void {
            $stream = fopen('php://output', 'wb');
            if ($stream === false) {
                return;
            }

            $currentSnapshot = $this->currentRestrictionSnapshot();
            fputcsv($stream, $this->coverageExportHeaders(), ',', '"', '');
            if ($scope === 'municipalities') {
                $this->streamMunicipalityCoverage($stream, $currentSnapshot);
            } elseif ($scope === 'editorial') {
                $this->streamEditorialCoverage($stream, $filters, $currentSnapshot);
            } else {
                $this->streamPublishedCoverage($stream, $filters, $currentSnapshot);
            }
            fclose($stream);
        }, "restriction-coverage-{$scope}-".now()->format('Ymd').'.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    /** @return array{q:string,department:string,vehicle_kind:string,availability:string,management:string} */
    private function restrictionFilters(Request $request): array
    {
        $management = $this->queryString($request, 'management');
        $vehicleKind = $this->queryString($request, 'vehicle_kind');
        $availability = $this->queryString($request, 'availability');
        $department = $this->queryString($request, 'department');

        return [
            'q' => mb_substr(trim($this->queryString($request, 'q')), 0, 100),
            'department' => preg_match('/^\d{2}$/D', $department) === 1 ? $department : '',
            'vehicle_kind' => in_array($vehicleKind, ['car', 'motorcycle', 'truck', 'bus', 'motocarro'], true)
                ? $vehicleKind
                : '',
            'availability' => in_array($availability, ['attention', 'verified', 'partial', 'unknown', 'stale'], true)
                ? $availability
                : '',
            'management' => is_string($management) && in_array($management, ['active', 'inactive', 'all'], true)
                ? $management
                : 'active',
        ];
    }

    /** @return array{q:string,department:string,management:string,availability:string} */
    private function municipalityMatrixFilters(Request $request): array
    {
        $management = $this->queryString($request, 'management');
        $availability = $this->queryString($request, 'availability');
        $department = $this->queryString($request, 'department');

        return [
            'q' => mb_substr(trim($this->queryString($request, 'q')), 0, 100),
            'department' => preg_match('/^\d{2}$/D', $department) === 1 ? $department : '',
            'management' => is_string($management) && in_array($management, ['active', 'inactive', 'unassigned', 'all'], true)
                ? $management
                : 'all',
            'availability' => is_string($availability) && in_array($availability, ['verified', 'partial', 'stale', 'unknown', 'all'], true)
                ? $availability
                : 'all',
        ];
    }

    /** @param array{q:string,department:string,vehicle_kind:string,availability:string,management:string} $filters */
    private function jurisdictionsForFilters(array $filters): Builder
    {
        $query = Jurisdiction::query()
            ->with([
                'primaryGeographicUnit.parent',
                'restrictionRuleVersions' => fn ($query) => $query->whereRaw(
                    'restriction_rule_versions.version = (select max(latest.version) from restriction_rule_versions as latest where latest.jurisdiction_id = restriction_rule_versions.jurisdiction_id)',
                ),
            ])
            ->orderBy('name')
            ->orderBy('id');

        if ($filters['management'] !== 'all') {
            $query->where('enabled', $filters['management'] === 'active');
        }
        if ($filters['q'] !== '') {
            $search = $filters['q'];
            $query->where(function ($query) use ($search): void {
                $query->where('name', 'like', "%$search%")
                    ->orWhere('key', 'like', "%$search%")
                    ->orWhereHas('primaryGeographicUnit', fn ($unit) => $unit->where('name', 'like', "%$search%"));
            });
        }
        if ($filters['department'] !== '') {
            $department = $filters['department'];
            $query->whereHas('primaryGeographicUnit.parent', fn ($parent) => $parent->where('code', $department));
        }

        return $query;
    }

    /** @param array{q:string,department:string,vehicle_kind:string,availability:string,management:string} $filters
     * @return Collection<int, array<string, mixed>>
     */
    private function coverageSummariesForVersion(?RestrictionRuleVersion $version, array $filters = []): Collection
    {
        $coverages = collect($version?->payload['coverages'] ?? [])
            ->filter(fn ($coverage): bool => is_array($coverage))
            ->map(fn (array $coverage): array => $this->coverageSummary($coverage));

        if ($coverages->isEmpty()) {
            $coverages->push($this->unknownCoverage());
        }
        return $this->filterCoverageSummaries($coverages, $filters);
    }

    /**
     * @param array{release:DatasetRelease|null,cities:array<string,array<string,mixed>>,source_editor_versions:array<string,string>} $snapshot
     * @return Collection<int, array<string, mixed>>
     */
    private function currentCoverageSummaries(array $snapshot, string $jurisdictionKey): Collection
    {
        if ($snapshot['release'] === null) {
            return collect([$this->unknownCoverage('NO_VERIFIED_CURRENT_RELEASE')]);
        }

        $city = $snapshot['cities'][$jurisdictionKey] ?? null;
        if ($city === null) {
            return collect([$this->unknownCoverage('NOT_PRESENT_IN_CURRENT_RELEASE')]);
        }

        $rawCoverages = $city['coverages'] ?? null;
        if (! is_array($rawCoverages)) {
            return collect([$this->unknownCoverage('NO_COVERAGE_IN_CURRENT_RELEASE')]);
        }

        $coverages = collect($rawCoverages)
            ->filter(fn ($coverage): bool => is_array($coverage))
            ->map(fn (array $coverage): array => $this->coverageSummary($coverage));

        return $coverages->isEmpty()
            ? collect([$this->unknownCoverage('NO_COVERAGE_IN_CURRENT_RELEASE')])
            : $coverages->values();
    }

    /**
     * @param Collection<int, array<string, mixed>> $coverages
     * @param array<string, string> $filters
     * @return Collection<int, array<string, mixed>>
     */
    private function filterCoverageSummaries(Collection $coverages, array $filters): Collection
    {
        if (($filters['vehicle_kind'] ?? '') !== '') {
            $coverages = $coverages->filter(fn (array $coverage): bool => $coverage['vehicle_kind'] === $filters['vehicle_kind']);
        }
        $availability = $filters['availability'] ?? '';
        if ($availability !== '' && $availability !== 'all') {
            $coverages = $coverages->filter(fn (array $coverage): bool => $availability === 'attention'
                ? in_array($coverage['availability'], ['UNKNOWN', 'PARTIAL', 'STALE'], true)
                : strtolower($coverage['availability']) === $availability);
        }

        return $coverages->values();
    }

    /**
     * Resolve the currently pointed restrictions asset once for this request. An
     * editor version or publication history never substitutes for that asset.
     *
     * @return array{release:DatasetRelease|null,cities:array<string,array<string,mixed>>,source_editor_versions:array<string,string>}
     */
    private function currentRestrictionSnapshot(): array
    {
        $empty = ['release' => null, 'cities' => [], 'source_editor_versions' => []];
        $dataset = Dataset::query()->where('key', 'restrictions')->first();
        if ($dataset === null || ! is_string($dataset->current_version) || $dataset->current_version === '') {
            return $empty;
        }

        $release = DatasetRelease::query()
            ->where('dataset_id', $dataset->id)
            ->where('version', $dataset->current_version)
            ->first();
        if ($release === null || $release->status !== DatasetReleaseStatus::Published
            || ! is_string($release->asset_path) || $release->asset_path === ''
            || ! is_string($release->sha256) || preg_match('/^[a-f0-9]{64}$/iD', $release->sha256) !== 1) {
            return $empty;
        }

        try {
            $disk = Storage::disk(config('datasets.published_disk'));
            if (! $disk->exists($release->asset_path)) {
                return $empty;
            }
            $bytes = $disk->get($release->asset_path);
            if (! hash_equals($release->sha256, hash('sha256', $bytes))) {
                return $empty;
            }
            $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable) {
            return $empty;
        }

        if (! is_array($payload)
            || ($payload['datasetKey'] ?? null) !== 'restrictions'
            || ($payload['version'] ?? null) !== $release->version
            || ! is_array($payload['jurisdictions'] ?? null)) {
            return $empty;
        }

        $cities = [];
        $duplicateKeys = [];
        foreach ($payload['jurisdictions'] as $city) {
            if (! is_array($city) || ! is_string($city['id'] ?? null) || trim($city['id']) === '') {
                continue;
            }
            $key = $city['id'];
            if (isset($duplicateKeys[$key])) {
                continue;
            }
            if (isset($cities[$key])) {
                unset($cities[$key]);
                $duplicateKeys[$key] = true;

                continue;
            }
            $cities[$key] = $city;
        }

        $sourceEditorVersions = array_fill_keys(array_keys($cities), 'NO_IDENTIFICADA');
        if ($cities !== []) {
            $encoder = app(RestrictionPayloadEncoder::class);
            $jurisdictions = Jurisdiction::query()
                ->whereIn('key', array_keys($cities))
                ->get(['id', 'key']);
            $keyByJurisdictionId = $jurisdictions->mapWithKeys(fn (Jurisdiction $jurisdiction): array => [
                $jurisdiction->id => $jurisdiction->key,
            ])->all();
            $hashByKey = [];
            foreach ($cities as $key => $city) {
                $hashByKey[$key] = hash('sha256', $encoder->encode($city));
            }
            $hashes = array_values(array_unique($hashByKey));
            $matches = [];

            if ($keyByJurisdictionId !== [] && $hashes !== []) {
                $versions = RestrictionRuleVersion::query()
                    ->whereIn('jurisdiction_id', array_keys($keyByJurisdictionId))
                    ->whereIn('payload_sha256', $hashes)
                    ->get(['jurisdiction_id', 'version', 'payload', 'payload_sha256']);

                foreach ($versions as $version) {
                    $key = $keyByJurisdictionId[$version->jurisdiction_id] ?? null;
                    if ($key === null || ! isset($hashByKey[$key]) || ! is_array($version->payload)) {
                        continue;
                    }
                    $versionHash = hash('sha256', $encoder->encode($version->payload));
                    if (hash_equals($hashByKey[$key], $versionHash)) {
                        $matches[$key][] = (string) $version->version;
                    }
                }
            }

            foreach ($matches as $key => $versions) {
                if (count($versions) === 1) {
                    $sourceEditorVersions[$key] = $versions[0];
                }
            }
        }

        return [
            'release' => $release,
            'cities' => $cities,
            'source_editor_versions' => $sourceEditorVersions,
        ];
    }

    private function queryString(Request $request, string $key): string
    {
        $value = $request->query($key);

        return is_string($value) || is_int($value) ? (string) $value : '';
    }

    private function boundedPage(Request $request): int
    {
        $value = $request->query('page', 1);
        if (! is_string($value) && ! is_int($value)) {
            return 1;
        }
        $page = filter_var($value, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);

        return $page === false ? 1 : min($page, 10000);
    }

    /** @return list<string> */
    private function coverageExportHeaders(): array
    {
        return [
            'scope', 'department_code', 'municipality_code', 'municipality_key', 'municipality_name',
            'jurisdiction_key', 'jurisdiction_name', 'management_state', 'vehicle_kind', 'service_type',
            'consultation_enabled', 'coverage_evidence_state', 'editor_version', 'editor_version_status', 'source_editor_version', 'published_release',
            'publication_state', 'source_urls', 'verified_at', 'valid_until', 'stale_after', 'missing_reason',
        ];
    }

    /** @param resource $stream
     * @param  array{q:string,department:string,vehicle_kind:string,availability:string,management:string}  $filters
     */
    private function streamEditorialCoverage($stream, array $filters, array $currentSnapshot): void
    {
        foreach ($this->jurisdictionsForFilters($filters)->lazy(100) as $jurisdiction) {
            $version = $jurisdiction->restrictionRuleVersions->first();
            $coverages = $version === null
                ? collect([$this->unknownCoverage('NO_EDITOR_VERSION')])
                : $this->filterCoverageSummaries($this->coverageSummariesForVersion($version), $filters);
            foreach ($coverages as $coverage) {
                $municipality = $jurisdiction->primaryGeographicUnit;
                $this->writeCoverageRow($stream, [
                    'scope' => 'editorial',
                    'department_code' => $municipality?->parent?->code ?? '',
                    'municipality_code' => $municipality?->code ?? '',
                    'municipality_key' => $municipality?->key ?? '',
                    'municipality_name' => $municipality?->name ?? '',
                    'jurisdiction' => $jurisdiction,
                    'version' => $version,
                    'coverage' => $coverage,
                    'management_state' => $jurisdiction->enabled ? 'ACTIVE' : 'INACTIVE',
                    'published_release' => $currentSnapshot['release'],
                    'source_editor_version' => $currentSnapshot['source_editor_versions'][$jurisdiction->key] ?? 'NO_IDENTIFICADA',
                    'publication_state' => $currentSnapshot['release'] === null ? 'UNKNOWN' : 'REFERENCE_ONLY',
                ]);
            }
        }
    }

    /** @param resource $stream
     * @param array{q:string,department:string,vehicle_kind:string,availability:string,management:string} $filters
     */
    private function streamPublishedCoverage($stream, array $filters, array $currentSnapshot): void
    {
        foreach ($this->jurisdictionsForFilters($filters)->lazy(100) as $jurisdiction) {
            $version = $jurisdiction->restrictionRuleVersions->first();
            $coverages = $this->filterCoverageSummaries(
                $this->currentCoverageSummaries($currentSnapshot, $jurisdiction->key),
                $filters,
            );
            foreach ($coverages as $coverage) {
                $municipality = $jurisdiction->primaryGeographicUnit;
                $this->writeCoverageRow($stream, [
                    'scope' => 'published',
                    'department_code' => $municipality?->parent?->code ?? '',
                    'municipality_code' => $municipality?->code ?? '',
                    'municipality_key' => $municipality?->key ?? '',
                    'municipality_name' => $municipality?->name ?? '',
                    'jurisdiction' => $jurisdiction,
                    'version' => $version,
                    'coverage' => $coverage,
                    'management_state' => $jurisdiction->enabled ? 'ACTIVE' : 'INACTIVE',
                    'published_release' => $currentSnapshot['release'],
                    'source_editor_version' => $currentSnapshot['source_editor_versions'][$jurisdiction->key] ?? 'NO_IDENTIFICADA',
                ]);
            }
        }
    }

    /**
     * @param  array{q:string,department:string,management:string,availability:string}  $filters
     * @param array{release:DatasetRelease|null,cities:array<string,array<string,mixed>>,source_editor_versions:array<string,string>} $currentSnapshot
     * @return list<array{jurisdiction: Jurisdiction|null,management_state:string,coverages:list<array<string,mixed>>,editor_coverages:list<array<string,mixed>>,version:RestrictionRuleVersion|null,published_release:DatasetRelease|null,source_editor_version:string}>
     */
    private function municipalityCoverageEntries(GeographicUnit $municipality, array $filters, array $currentSnapshot): array
    {
        $jurisdictions = $municipality->jurisdictions;
        if ($jurisdictions->isEmpty()) {
            if (! in_array($filters['management'], ['all', 'unassigned'], true) || ! in_array($filters['availability'], ['all', 'unknown'], true)) {
                return [];
            }

            return [[
                'jurisdiction' => null,
                'management_state' => 'NO_JURISDICTION',
                'coverages' => [$this->unknownCoverage('NO_JURISDICTION')],
                'editor_coverages' => [],
                'version' => null,
                'published_release' => $currentSnapshot['release'],
                'source_editor_version' => 'NO_IDENTIFICADA',
            ]];
        }

        $entries = [];
        foreach ($jurisdictions as $jurisdiction) {
            $managementState = $jurisdiction->enabled ? 'ACTIVE' : 'INACTIVE';
            if (($filters['management'] === 'active' && ! $jurisdiction->enabled)
                || ($filters['management'] === 'inactive' && $jurisdiction->enabled)
                || $filters['management'] === 'unassigned') {
                continue;
            }

            $version = $jurisdiction->restrictionRuleVersions->first();
            $currentCoverages = $this->filterCoverageSummaries(
                $this->currentCoverageSummaries($currentSnapshot, $jurisdiction->key),
                $filters,
            );
            $coverages = $currentCoverages->all();
            if ($coverages === []) {
                continue;
            }

            $entries[] = [
                'jurisdiction' => $jurisdiction,
                'management_state' => $managementState,
                'coverages' => $coverages,
                'editor_coverages' => $this->coverageSummariesForVersion($version)->all(),
                'version' => $version,
                'published_release' => $currentSnapshot['release'],
                'source_editor_version' => $currentSnapshot['source_editor_versions'][$jurisdiction->key] ?? 'NO_IDENTIFICADA',
            ];
        }

        return $entries;
    }

    private function municipalityCoverageQuery(): Builder
    {
        return GeographicUnit::query()
            ->where('level', 'municipality')
            ->with([
                'parent',
                'jurisdictions' => fn ($query) => $query->orderBy('key'),
                'jurisdictions.restrictionRuleVersions' => fn ($query) => $query->whereRaw(
                    'restriction_rule_versions.version = (select max(latest.version) from restriction_rule_versions as latest where latest.jurisdiction_id = restriction_rule_versions.jurisdiction_id)',
                ),
            ]);
    }

    /** @param resource $stream */
    private function streamMunicipalityCoverage($stream, array $currentSnapshot): void
    {
        $municipalities = $this->municipalityCoverageQuery()->orderBy('id')->lazy(100);

        foreach ($municipalities->chunk(100) as $batch) {
            foreach ($batch as $municipality) {
                $jurisdictions = $municipality->jurisdictions;
                if ($jurisdictions->isEmpty()) {
                    $this->writeCoverageRow($stream, [
                        'scope' => 'municipalities',
                        'department_code' => $municipality->parent?->code ?? '',
                        'municipality_code' => $municipality->code,
                        'municipality_key' => $municipality->key,
                        'municipality_name' => $municipality->name,
                        'jurisdiction' => null,
                        'version' => null,
                        'coverage' => $this->unknownCoverage('NO_JURISDICTION'),
                        'management_state' => 'NO_JURISDICTION',
                        'published_release' => $currentSnapshot['release'],
                        'source_editor_version' => 'NO_IDENTIFICADA',
                    ]);

                    continue;
                }

                foreach ($jurisdictions as $jurisdiction) {
                    $version = $jurisdiction->restrictionRuleVersions->first();
                    foreach ($this->currentCoverageSummaries($currentSnapshot, $jurisdiction->key) as $coverage) {
                        $this->writeCoverageRow($stream, [
                            'scope' => 'municipalities',
                            'department_code' => $municipality->parent?->code ?? '',
                            'municipality_code' => $municipality->code,
                            'municipality_key' => $municipality->key,
                            'municipality_name' => $municipality->name,
                            'jurisdiction' => $jurisdiction,
                            'version' => $version,
                            'coverage' => $coverage,
                            'management_state' => $jurisdiction->enabled ? 'ACTIVE' : 'INACTIVE',
                            'published_release' => $currentSnapshot['release'],
                            'source_editor_version' => $currentSnapshot['source_editor_versions'][$jurisdiction->key] ?? 'NO_IDENTIFICADA',
                        ]);
                    }
                }
            }
        }
    }

    /** @param resource $stream
     * @param  array<string, mixed>  $row
     */
    private function writeCoverageRow($stream, array $row): void
    {
        /** @var Jurisdiction|null $jurisdiction */
        $jurisdiction = $row['jurisdiction'];
        /** @var RestrictionRuleVersion|null $version */
        $version = $row['version'];
        /** @var array<string, mixed> $coverage */
        $coverage = $row['coverage'];
        /** @var DatasetRelease|null $release */
        $release = $row['published_release'] ?? null;
        $values = [
            $row['scope'], $row['department_code'], $row['municipality_code'], $row['municipality_key'], $row['municipality_name'],
            $jurisdiction?->key ?? '', $jurisdiction?->name ?? '', $row['management_state'],
            $coverage['vehicle_kind'] ?? '', $coverage['service_type'] ?? '',
            ($coverage['consultation_enabled'] ?? null) === null ? '' : ($coverage['consultation_enabled'] ? 'true' : 'false'),
            $coverage['availability'] ?? 'UNKNOWN',
            $version?->version ?? '', $version?->status?->value ?? '', $row['source_editor_version'] ?? 'NO_IDENTIFICADA', $release?->version ?? '',
            $row['publication_state'] ?? ($release ? 'PUBLISHED' : 'UNKNOWN'),
            $this->jsonList($coverage['source_urls'] ?? []), $this->jsonList($coverage['verified_at'] ?? []),
            $this->jsonList($coverage['valid_until'] ?? []), $coverage['stale_after'] ?? '', $coverage['missing_reason'] ?? '',
        ];

        fputcsv($stream, array_map($this->spreadsheetSafe(...), $values), ',', '"', '');
    }

    /** @param list<string> $values */
    private function jsonList(array $values): string
    {
        return json_encode(array_values($values), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    }

    /** @param array<string, mixed> $coverage
     * @return array{vehicle_kind: string, service_type: string, consultation_enabled: bool, category: string, availability: string, source_urls: list<string>, verified_at: list<string>, valid_until: list<string>, stale_after: ?string, has_unbounded_rule: bool, missing_reason: string}
     */
    private function coverageSummary(array $coverage): array
    {
        $rules = collect($coverage['rules'] ?? [])->filter(fn ($rule): bool => is_array($rule))->values();
        $sourceUrls = collect($coverage['sourceUrls'] ?? [])
            ->merge($rules->pluck('sourceUrl'))
            ->filter(fn ($value): bool => is_string($value) && trim($value) !== '')
            ->unique()
            ->values()
            ->all();
        $verifiedAt = collect([$coverage['verifiedAt'] ?? null])
            ->merge($rules->pluck('verifiedAt'))
            ->filter(fn ($value): bool => is_string($value) && trim($value) !== '')
            ->unique()
            ->values()
            ->all();
        $validUntil = $rules->pluck('validUntil')
            ->filter(fn ($value): bool => is_string($value) && trim($value) !== '')
            ->unique()
            ->values()
            ->all();
        $completeness = $coverage['coverageCompleteness'] ?? null;
        $hasEvidence = $sourceUrls !== [] && $verifiedAt !== [];
        $expiredRules = $rules->isNotEmpty()
            && $rules->every(fn (array $rule): bool => $this->isExpired($rule['validUntil'] ?? null));

        if (! $hasEvidence || ! in_array($completeness, ['complete', 'partial'], true)) {
            $availability = 'UNKNOWN';
        } elseif ($this->isExpired($coverage['staleAfter'] ?? null) || $expiredRules) {
            $availability = 'STALE';
        } else {
            $availability = $completeness === 'partial' ? 'PARTIAL' : 'VERIFIED';
        }

        $vehicleKind = is_string($coverage['vehicleKind'] ?? null) ? $coverage['vehicleKind'] : '';
        $serviceType = is_string($coverage['serviceType'] ?? null) ? $coverage['serviceType'] : '';

        return [
            'vehicle_kind' => $vehicleKind,
            'service_type' => $serviceType,
            // Payloads without the field predate the toggle and were evaluated as ON.
            'consultation_enabled' => $coverage['consultationEnabled'] ?? true,
            'category' => implode(' · ', array_filter([
                $this->vehicleKindLabel($vehicleKind),
                $this->serviceTypeLabel($serviceType),
            ])),
            'availability' => $availability,
            'source_urls' => $sourceUrls,
            'verified_at' => $verifiedAt,
            'valid_until' => $validUntil,
            'stale_after' => is_string($coverage['staleAfter'] ?? null) ? $coverage['staleAfter'] : null,
            'has_unbounded_rule' => $rules->contains(fn (array $rule): bool => empty($rule['validUntil'])),
            'missing_reason' => match ($availability) {
                'UNKNOWN' => 'MISSING_SOURCE_OR_VERIFICATION',
                'PARTIAL' => 'PARTIAL_COVERAGE',
                'STALE' => 'EVIDENCE_STALE',
                default => '',
            },
        ];
    }

    /** @return array{vehicle_kind: string, service_type: string, consultation_enabled: null, category: string, availability: string, source_urls: list<string>, verified_at: list<string>, valid_until: list<string>, stale_after: null, has_unbounded_rule: false, missing_reason: string} */
    private function unknownCoverage(string $reason = 'NO_COVERAGE_REGISTERED'): array
    {
        return [
            'vehicle_kind' => '',
            'service_type' => '',
            'consultation_enabled' => null,
            'category' => 'Sin cobertura registrada',
            'availability' => 'UNKNOWN',
            'source_urls' => [],
            'verified_at' => [],
            'valid_until' => [],
            'stale_after' => null,
            'has_unbounded_rule' => false,
            'missing_reason' => $reason,
        ];
    }

    private function isExpired(mixed $value): bool
    {
        if (! is_string($value) || trim($value) === '') {
            return false;
        }

        $timestamp = strtotime($value);

        return $timestamp !== false && $timestamp < now()->timestamp;
    }

    private function vehicleKindLabel(string $vehicleKind): string
    {
        return match ($vehicleKind) {
            'car' => 'Carro',
            'motorcycle' => 'Moto',
            'truck' => 'Camión',
            'bus' => 'Bus',
            'motocarro' => 'Motocarro',
            '' => 'Categoría no indicada',
            default => ucfirst($vehicleKind),
        };
    }

    private function serviceTypeLabel(string $serviceType): string
    {
        return match ($serviceType) {
            'private' => 'Particular',
            'public' => 'Público',
            'taxi' => 'Taxi',
            '' => 'Servicio no indicado',
            default => ucfirst($serviceType),
        };
    }

    public function create(Request $request)
    {
        Gate::authorize('datasets.edit');
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();
        $jurisdictions = Jurisdiction::query()
            ->with('primaryGeographicUnit')
            ->where('enabled', true)
            ->orderBy('name')
            ->get();
        $queryId = $request->query('jurisdiction_id');
        $preselectedJurisdictionId = null;

        if (is_int($queryId) || (is_string($queryId) && strlen($queryId) <= 19 && ctype_digit($queryId))) {
            $id = filter_var($queryId, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            if ($id !== false && $jurisdictions->contains('id', $id)) {
                $preselectedJurisdictionId = (int) $id;
            }
        }

        return view('admin.restrictions.form', [
            'operator' => $request->user(),
            'jurisdictions' => $jurisdictions,
            'version' => null,
            'schemaVersion' => (int) $dataset->schema_version,
            'preselectedJurisdictionId' => $preselectedJurisdictionId,
        ]);
    }

    public function store(Request $request, RestrictionRuleVersionService $service, RestrictionFormPayloadBuilder $builder): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $schemaVersion = (int) Dataset::query()->where('key', 'restrictions')->value('schema_version');
        if (! in_array($schemaVersion, [1, 2], true)) {
            throw ValidationException::withMessages(['coverages' => 'La versión publicada del esquema no permite crear borradores.']);
        }
        $data = $request->validate([
            'jurisdiction_id' => ['required', 'integer', 'exists:jurisdictions,id'],
            'coverages' => ['required', 'array', 'min:1', 'max:'.($schemaVersion === 2 ? 9 : 8)],
            'coverages.*' => ['required', 'array'],
            'coverages.*.rules' => ['present', 'array', 'max:1000'],
        ]);
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->findOrFail($data['jurisdiction_id']);
        try {
            $payload = $builder->build($jurisdiction, $request->only(['coverages', 'consultation_enabled']), $schemaVersion);
        } catch (DomainException $error) {
            throw ValidationException::withMessages([$this->formErrorField($error) => $this->formErrorMessage($error)]);
        }
        $version = $service->createDraft($jurisdiction, $payload, $request->user());

        return redirect()->route('admin.restrictions.edit', $version);
    }

    public function edit(Request $request, RestrictionRuleVersion $version)
    {
        Gate::authorize('datasets.view');

        return view('admin.restrictions.form', [
            'operator' => $request->user(),
            'jurisdictions' => collect([$version->jurisdiction->loadMissing('primaryGeographicUnit')]),
            'version' => $version,
            'schemaVersion' => (int) ($version->payload['schemaVersion'] ?? 1),
            'editable' => Gate::allows('datasets.edit')
                && $version->status === RestrictionRuleVersionStatus::Draft
                && in_array(($version->payload['schemaVersion'] ?? 1), [1, 2], true),
        ]);
    }

    public function update(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service, RestrictionFormPayloadBuilder $builder): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $schemaVersion = (int) ($version->payload['schemaVersion'] ?? 1);
        if (! in_array($schemaVersion, [1, 2], true)) {
            return back()->withErrors(['version' => 'La versión del esquema de este borrador no se puede editar.']);
        }
        $request->validate([
            'coverages' => ['required', 'array', 'min:1', 'max:'.($schemaVersion === 2 ? 9 : 8)],
            'coverages.*' => ['required', 'array'],
            'coverages.*.rules' => ['present', 'array', 'max:1000'],
        ]);
        try {
            $payload = $builder->build(
                $version->jurisdiction,
                $request->only(['coverages', 'consultation_enabled']),
                $schemaVersion,
                $schemaVersion === 2 ? $version->payload : null,
            );
            $service->updateDraft($version, $payload, $request->user());
        } catch (DomainException $error) {
            return back()->withInput()->withErrors([$this->formErrorField($error) => $this->formErrorMessage($error)]);
        }

        return back();
    }

    public function duplicate(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $copy = $service->duplicate($version, $request->user());

        return redirect()->route('admin.restrictions.edit', $copy);
    }

    public function validateVersion(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        try {
            $service->validate($version, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['version' => $error->getMessage()]);
        }

        return back();
    }

    public function archive(Request $request, RestrictionRuleVersion $version, RestrictionRuleVersionService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $service->archive($version, $request->user());

        return back();
    }

    public function importForm(Request $request)
    {
        Gate::authorize('datasets.edit');

        return view('admin.restrictions.import', ['operator' => $request->user(), 'imports' => RestrictionImport::query()->latest('id')->limit(20)->get()]);
    }

    public function analyzeImport(Request $request, RestrictionImportService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $request->validate(['file' => ['required', 'file', 'max:'.config('datasets.max_upload_kb')], 'sheet' => ['nullable', 'string', 'max:128']]);
        $file = $request->file('file');
        $format = strtolower($file->getClientOriginalExtension());
        try {
            $import = $service->analyze($file->getRealPath(), $file->getClientOriginalName(), $format, $request->string('sheet')->trim()->value() ?: null, $request->user());
        } catch (DomainException $error) {
            throw ValidationException::withMessages(['file' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.imports.review', $import);
    }

    public function reviewImport(Request $request, RestrictionImport $import)
    {
        Gate::authorize('datasets.edit');

        return view('admin.restrictions.import-review', [
            'operator' => $request->user(),
            'import' => $import->load(['rows.jurisdiction.primaryGeographicUnit.parent']),
            'canCreateJurisdictions' => Gate::allows('jurisdictions.edit'),
        ]);
    }

    public function confirmImport(Request $request, RestrictionImport $import, RestrictionImportService $service): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate(['rows' => ['required', 'array', 'min:1'], 'rows.*' => ['integer']]);
        try {
            $service->confirm($import, array_map('intval', $data['rows']), $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['rows' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.index');
    }

    public function publicationPreview(Request $request, RestrictionPublicationService $service)
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['versions' => ['required', 'array', 'min:1'], 'versions.*' => ['integer', 'exists:restriction_rule_versions,id']]);
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();
        $versions = RestrictionRuleVersion::query()->with('jurisdiction')->whereIn('id', $data['versions'])->get();
        $materialReviews = [];
        foreach ($versions as $version) {
            try {
                $materialReviews[$version->id] = $service->materialChangePreview($version, (int) $dataset->publication_revision);
            } catch (DomainException $error) {
                $materialReviews[$version->id] = ['error' => $error->getMessage()];
            }
        }

        return view('admin.restrictions.publish', [
            'operator' => $request->user(),
            'dataset' => $dataset,
            'versions' => $versions,
            'materialReviews' => $materialReviews,
            'canApproveMaterial' => Gate::allows('restriction.material_change.approve'),
        ]);
    }

    public function approveMaterialChange(Request $request, RestrictionRuleVersion $version, RestrictionPublicationService $service): RedirectResponse
    {
        Gate::authorize('restriction.material_change.approve');
        $data = $request->validate([
            'publication_revision' => ['required', 'integer', 'min:0'],
            'reason' => ['required', 'string', 'min:10', 'max:1000'],
            'evidence_url' => ['required', 'url', 'starts_with:https://', 'max:2048'],
        ]);
        try {
            $service->approveMaterialChange(
                $version,
                (int) $data['publication_revision'],
                $request->user(),
                $data['reason'],
                $data['evidence_url'],
            );
        } catch (DomainException $error) {
            return back()->withErrors(['approval' => $error->getMessage()]);
        }

        return back()->with('status', 'Aprobación editorial registrada. La publicación debe ejecutarse por separado.');
    }

    public function publish(Request $request, RestrictionPublicationService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['versions' => ['required', 'array', 'min:1'], 'versions.*' => ['integer'], 'publication_revision' => ['required', 'integer', 'min:0']]);
        try {
            $service->publish(array_map('intval', $data['versions']), (int) $data['publication_revision'], $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['publication' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.history');
    }

    public function history(Request $request)
    {
        Gate::authorize('datasets.view');

        return view('admin.restrictions.history', [
            'operator' => $request->user(),
            'publications' => RestrictionPublication::query()->with(['datasetRelease', 'actor', 'items.jurisdiction', 'items.ruleVersion'])->latest('id')->paginate(30),
            'dataset' => Dataset::query()->where('key', 'restrictions')->first(),
        ]);
    }

    public function rollback(Request $request, RestrictionRuleVersion $version, RestrictionPublicationService $service): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $data = $request->validate(['publication_revision' => ['required', 'integer', 'min:0']]);
        try {
            $service->rollbackCity($version, (int) $data['publication_revision'], $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['rollback' => $error->getMessage()]);
        }

        return redirect()->route('admin.restrictions.history');
    }

    public function template(): Response
    {
        Gate::authorize('datasets.edit');
        $headers = ['jurisdiction_id', 'jurisdiction_name', 'vehicle_kind', 'service_type', 'consultation_enabled', 'rule_id', 'priority', 'effect', 'valid_from', 'valid_until', 'weekdays', 'date_parity', 'digit_position', 'digits', 'time_windows', 'applies_on_holidays', 'source_url', 'verified_at', 'stale_after', 'publish', 'department_code', 'municipality_code'];

        return response(implode(',', $headers)."\n", 200, ['Content-Type' => 'text/csv; charset=UTF-8', 'Content-Disposition' => 'attachment; filename="restriction-rules-template.csv"']);
    }

    public function report(RestrictionImport $import): StreamedResponse
    {
        Gate::authorize('datasets.view');

        return response()->streamDownload(function () use ($import): void {
            $stream = fopen('php://output', 'wb');
            fputcsv($stream, ['row', 'state', 'publishable', 'jurisdiction', 'onboarding_status', 'department_code', 'municipality_code', 'proposed_key', 'errors'], ',', '"', '');
            foreach ($import->rows()->with('jurisdiction')->orderBy('row_number')->cursor() as $row) {
                $onboarding = $row->normalized['onboarding'] ?? [];
                $values = [
                    $row->row_number,
                    $row->state,
                    $row->publishable ? 'yes' : 'no',
                    $row->jurisdiction?->key ?? '',
                    $onboarding['status'] ?? '',
                    $onboarding['department_code'] ?? '',
                    $onboarding['municipality_code'] ?? '',
                    $onboarding['proposed_key'] ?? '',
                    implode(' | ', $row->errors ?? []),
                ];
                fputcsv($stream, array_map($this->spreadsheetSafe(...), $values), ',', '"', '');
            }
            fclose($stream);
        }, "restriction-import-{$import->id}-report.csv", ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    private function spreadsheetSafe(mixed $value): string
    {
        $value = (string) $value;

        $formulaAfterWhitespace = preg_match('/^[\x00-\x20]*[=+\-@]/', $value) === 1
            || preg_match('/^[\t\r\n]/', $value) === 1
            || preg_match('/^[\p{Z}\x{FEFF}]*[=+\-@]/u', $value) === 1;

        return $formulaAfterWhitespace ? "'$value" : $value;
    }

    private function formErrorField(DomainException $error): string
    {
        return preg_match('/^(coverages\.\d+\.rules\.\d+\.conditions_json):/', $error->getMessage(), $match)
            ? $match[1]
            : 'coverages';
    }

    private function formErrorMessage(DomainException $error): string
    {
        return preg_replace('/^coverages\.\d+\.rules\.\d+\.conditions_json:\s*/', '', $error->getMessage()) ?? $error->getMessage();
    }
}
