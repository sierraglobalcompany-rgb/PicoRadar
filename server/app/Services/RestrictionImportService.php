<?php

namespace App\Services;

use App\Enums\GeographicUnitLevel;
use App\Enums\RestrictionImportStatus;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionImportRow;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Support\GeographicNameNormalizer;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use JsonException;
use SplFileObject;

final class RestrictionImportService
{
    private const MAX_ROWS = 10_000;

    /** @var array<int,?array<string,mixed>> */
    private array $latestPayloadCache = [];

    public function __construct(
        private readonly SafeXlsxReader $xlsx,
        private readonly RestrictionContractValidator $validator,
        private readonly RestrictionRuleVersionService $versions,
        private readonly JurisdictionService $jurisdictions,
        private readonly DatasetAuditLogger $audit,
    ) {}

    public function analyze(string $path, string $originalName, string $format, ?string $sheet, User $actor): RestrictionImport
    {
        $this->latestPayloadCache = [];
        $format = strtolower($format);
        if (! in_array($format, ['json', 'csv', 'xlsx'], true)) {
            throw new DomainException('Only JSON, CSV, and XLSX imports are supported.');
        }
        if (! is_file($path) || filesize($path) === false || filesize($path) > ((int) config('datasets.max_upload_kb') * 1024)) {
            throw new DomainException('The import file is missing or exceeds the upload limit.');
        }
        $sha = hash_file('sha256', $path);
        if (! is_string($sha)) {
            throw new DomainException('The import file could not be hashed.');
        }
        $existing = RestrictionImport::query()->where('sha256', $sha)->first();
        if ($existing) {
            return $existing;
        }

        [$rows, $selectedSheet, $envelopeSchemaVersion] = $this->read($path, $format, $sheet);
        if (count($rows) > self::MAX_ROWS) {
            throw new DomainException('The import row limit was exceeded.');
        }
        $privatePath = "restriction-imports/$sha.$format";
        if (Storage::disk(config('datasets.draft_disk'))->put($privatePath, file_get_contents($path)) === false) {
            throw new DomainException('The import file could not be stored privately.');
        }

        return DB::transaction(function () use ($sha, $originalName, $format, $privatePath, $selectedSheet, $rows, $envelopeSchemaVersion, $actor): RestrictionImport {
            $import = RestrictionImport::query()->create([
                'sha256' => $sha,
                'original_name' => basename(str_replace('\\', '/', $originalName)),
                'format' => $format,
                'private_path' => $privatePath,
                'sheet' => $selectedSheet,
                'status' => RestrictionImportStatus::Analyzed,
                'created_by_id' => $actor->id,
                'analyzed_at' => now(),
            ]);
            $counts = ['valid' => 0, 'invalid' => 0, 'excluded' => 0];
            $onboardingCounts = ['new' => 0, 'existing' => 0];
            foreach ($rows as $index => $raw) {
                $result = $this->normalize($raw, $envelopeSchemaVersion);
                $counts[$result['state']]++;
                $onboardingStatus = $result['normalized']['onboarding']['status'] ?? null;
                if ($result['state'] === 'valid' && $onboardingStatus === 'ALTA_PROPUESTA') {
                    $onboardingCounts['new']++;
                } elseif ($result['state'] === 'valid' && $onboardingStatus === 'EXISTENTE') {
                    $onboardingCounts['existing']++;
                }
                $import->rows()->create([
                    'row_number' => $index + 1,
                    'jurisdiction_id' => $result['jurisdiction']?->id,
                    'state' => $result['state'],
                    'publishable' => $result['state'] === 'valid',
                    'normalized' => $result['normalized'],
                    'errors' => $result['errors'],
                    'raw' => $raw,
                ]);
            }
            $import->update([
                'row_count' => count($rows),
                'valid_count' => $counts['valid'],
                'invalid_count' => $counts['invalid'],
                'excluded_count' => $counts['excluded'],
                'report' => ['syntheticFixturesAllowed' => true, 'counts' => $counts, 'onboarding' => $onboardingCounts],
            ]);
            $this->audit->log($actor, 'restriction_import.analyzed', $import, ['sha256' => $sha, 'format' => $format, 'counts' => $counts]);

            return $import->refresh();
        });
    }

    /** @param list<int> $rowIds @return list<RestrictionRuleVersion> */
    public function confirm(RestrictionImport $import, array $rowIds, User $actor): array
    {
        if ($rowIds === []) {
            throw new DomainException('At least one analyzed row must be selected.');
        }
        Gate::forUser($actor)->authorize('datasets.edit');
        $rowIds = array_values(array_unique(array_map('intval', $rowIds)));

        return DB::transaction(function () use ($import, $rowIds, $actor): array {
            $locked = RestrictionImport::query()->lockForUpdate()->findOrFail($import->id);
            if ($locked->status !== RestrictionImportStatus::Analyzed) {
                if ($locked->status === RestrictionImportStatus::Confirmed) {
                    $draftIds = $locked->report['confirmation']['draft_ids'] ?? [];
                    if (! is_array($draftIds) || $draftIds === []) {
                        return [];
                    }
                    $versions = RestrictionRuleVersion::query()->whereIn('id', $draftIds)->get()->keyBy('id');
                    if ($versions->count() !== count($draftIds)) {
                        throw new DomainException('The recorded confirmation drafts are no longer available.');
                    }

                    return array_map(static fn (int $id): RestrictionRuleVersion => $versions->get($id), $draftIds);
                }
                throw new DomainException('Only analyzed imports can be confirmed.');
            }
            $rows = RestrictionImportRow::query()->where('restriction_import_id', $locked->id)->whereIn('id', array_values(array_unique($rowIds)))->lockForUpdate()->get();
            if ($rows->count() !== count($rowIds) || $rows->contains(fn (RestrictionImportRow $row): bool => $row->state !== 'valid' || ! $row->publishable || ! is_array($row->normalized))) {
                throw new DomainException('Only valid publishable rows from this import can be confirmed.');
            }
            foreach ($rows as $row) {
                $this->assertOnboardingSourceCurrent($row->normalized);
            }

            $proposals = $rows->filter(fn (RestrictionImportRow $row): bool => ($row->normalized['onboarding']['status'] ?? null) === 'ALTA_PROPUESTA');
            if ($proposals->isNotEmpty()) {
                Gate::forUser($actor)->authorize('jurisdictions.edit');
            }

            $groups = [];
            $createdByJurisdiction = [];
            $createdKeys = [];
            $reusedJurisdictions = [];
            foreach ($proposals->groupBy(fn (RestrictionImportRow $row): string => (string) ($row->normalized['onboarding']['municipality_code'] ?? '')) as $municipalityCode => $municipalityRows) {
                [$jurisdiction, $createdNew] = $this->resolveProposalForConfirmation($municipalityRows->all(), $actor);
                $groups[$jurisdiction->id] ??= [];
                foreach ($municipalityRows as $row) {
                    $row->jurisdiction_id = $jurisdiction->id;
                    $row->save();
                    $groups[$jurisdiction->id][] = $row;
                }
                $createdByJurisdiction[$jurisdiction->id] = $createdNew;
                if ($createdNew) {
                    $createdKeys[$jurisdiction->id] = $jurisdiction->key;
                } else {
                    $reusedJurisdictions[$jurisdiction->id] = true;
                }
            }

            foreach ($rows->reject(fn (RestrictionImportRow $row): bool => ($row->normalized['onboarding']['status'] ?? null) === 'ALTA_PROPUESTA') as $row) {
                if (! $row->jurisdiction_id) {
                    throw new DomainException('An existing import row has no jurisdiction.');
                }
                $jurisdiction = Jurisdiction::query()->lockForUpdate()->findOrFail($row->jurisdiction_id);
                $groups[$jurisdiction->id][] = $row;
                $createdByJurisdiction[$jurisdiction->id] ??= false;
            }

            $created = [];
            foreach ($groups as $jurisdictionId => $cityRows) {
                $jurisdiction = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdictionId);
                $payload = $this->payloadForRows($jurisdiction, $cityRows, $createdByJurisdiction[$jurisdictionId] ?? false);
                $schemaVersion = $payload['schemaVersion'] ?? 1;
                $this->validator->validateJurisdictionForEnvelope($payload, $jurisdiction->key, $schemaVersion);
                $created[] = $this->versions->createDraft($jurisdiction, $payload, $actor);
            }
            $draftIds = array_map(static fn (RestrictionRuleVersion $version): int => $version->id, $created);
            $summary = [
                'actor_id' => $actor->id,
                'created_jurisdictions' => array_values($createdKeys),
                'reused' => count($reusedJurisdictions),
                'draft_ids' => $draftIds,
                'rejected' => $locked->invalid_count,
            ];
            $report = $locked->report ?? [];
            $report['confirmation'] = $summary;
            $locked->update([
                'status' => RestrictionImportStatus::Confirmed,
                'confirmed_by_id' => $actor->id,
                'confirmed_at' => now(),
                'report' => $report,
            ]);
            $this->audit->log($actor, 'restriction_import.confirmed', $locked, [
                'file_sha' => $locked->sha256,
                'actor_id' => $actor->id,
                'created_jurisdictions' => array_values($createdKeys),
                'reused' => count($reusedJurisdictions),
                'draft_ids' => $draftIds,
                'rejected' => $locked->invalid_count,
            ]);

            return $created;
        });
    }

    /** @param list<RestrictionImportRow> $rows @return array{0:Jurisdiction,1:bool} */
    private function resolveProposalForConfirmation(array $rows, User $actor): array
    {
        $first = $rows[0] ?? throw new DomainException('A proposed municipality has no selected rows.');
        $onboarding = $first->normalized['onboarding'] ?? [];
        $departmentCode = (string) ($onboarding['department_code'] ?? '');
        $municipalityCode = (string) ($onboarding['municipality_code'] ?? '');
        $unitId = (int) ($onboarding['geographic_unit_id'] ?? 0);
        $unit = $this->territoryByCodes($departmentCode, $municipalityCode, true);
        if ($unit->id !== $unitId) {
            throw new DomainException('The DIVIPOLA municipality changed after analysis; analyze the file again.');
        }
        foreach ($rows as $row) {
            $candidate = $row->normalized['onboarding'] ?? [];
            if (($candidate['department_code'] ?? null) !== $departmentCode ||
                ($candidate['municipality_code'] ?? null) !== $municipalityCode ||
                (int) ($candidate['geographic_unit_id'] ?? 0) !== $unit->id) {
                throw new DomainException('Selected rows do not resolve to one canonical municipality.');
            }
        }

        $matches = $this->jurisdictionsForTerritory($unit, true);
        if ($matches->count() > 1) {
            throw new DomainException('Multiple jurisdictions cover this municipality; assign it manually before confirming.');
        }
        if ($matches->isNotEmpty()) {
            return [$matches->first(), false];
        }

        $key = $this->proposedJurisdictionKey($municipalityCode);
        $collision = Jurisdiction::query()->lockForUpdate()->where('key', $key)->first();
        if ($collision) {
            throw new DomainException('The deterministic jurisdiction key belongs to another municipality.');
        }
        $jurisdiction = $this->jurisdictions->create([
            'key' => $key,
            'name' => $unit->name,
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => false,
            'timezone' => 'America/Bogota',
        ], [$unit->id], $actor);

        return [$jurisdiction, true];
    }

    private function territoryByCodes(string $departmentCode, string $municipalityCode, bool $lock = false): GeographicUnit
    {
        if (! preg_match('/^\d{2}$/', $departmentCode) || ! preg_match('/^\d{5}$/', $municipalityCode) ||
            substr($municipalityCode, 0, 2) !== $departmentCode) {
            throw new DomainException('Department and municipality DIVIPOLA codes must be valid and match.');
        }

        $query = GeographicUnit::query()->where('code', $municipalityCode);
        if ($lock) {
            $query->lockForUpdate();
        }
        $unit = $query->first();
        $department = $unit?->parent_id
            ? GeographicUnit::query()->when($lock, fn ($query) => $query->lockForUpdate())->find($unit->parent_id)
            : null;
        if ($unit && $department) {
            $unit->setRelation('parent', $department);
        }
        if ($unit?->level !== GeographicUnitLevel::Municipality || ! $unit->is_active ||
            ! $department || $department->level !== GeographicUnitLevel::Department ||
            $department->code !== $departmentCode || ! $department->is_active) {
            throw new DomainException('DIVIPOLA municipality or active department was not found in the canonical geography.');
        }

        return $unit;
    }

    /** @return \Illuminate\Database\Eloquent\Collection<int,Jurisdiction> */
    private function jurisdictionsForTerritory(GeographicUnit $unit, bool $lock = false)
    {
        $query = Jurisdiction::query()
            ->with('primaryGeographicUnit.parent')
            ->where(function ($query) use ($unit): void {
                $query->where('primary_geographic_unit_id', $unit->id)
                    ->orWhereHas('geographicUnits', fn ($geography) => $geography->where('geographic_units.id', $unit->id));
            })
            ->orderBy('id');
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->get();
    }

    private function proposedJurisdictionKey(string $municipalityCode): string
    {
        return 'municipio-'.$municipalityCode;
    }

    /** @param \Illuminate\Database\Eloquent\Collection<int,Jurisdiction> $jurisdictions @return list<array{id:int,key:string,name:string}> */
    private function jurisdictionOptions($jurisdictions): array
    {
        return $jurisdictions->map(static fn (Jurisdiction $jurisdiction): array => [
            'id' => $jurisdiction->id,
            'key' => $jurisdiction->key,
            'name' => $jurisdiction->name,
        ])->values()->all();
    }

    /** @param list<array<string,mixed>> $coverages @return array<string,mixed> */
    private function onboardingData(?GeographicUnit $unit, ?Jurisdiction $jurisdiction, array $coverages): array
    {
        $unit ??= $jurisdiction ? $this->territoryForJurisdiction($jurisdiction) : null;
        $sources = [];
        $verifiedAt = [];
        $validFrom = [];
        $validUntil = [];
        $staleAfter = [];
        foreach ($coverages as $coverage) {
            if (! is_array($coverage)) {
                continue;
            }
            $sourceUrls = is_array($coverage['sourceUrls'] ?? null) ? $coverage['sourceUrls'] : [];
            foreach ($sourceUrls as $source) {
                if (is_string($source) && $source !== '') {
                    $sources[] = $source;
                }
            }
            if (is_string($coverage['verifiedAt'] ?? null) && $coverage['verifiedAt'] !== '') {
                $verifiedAt[] = $coverage['verifiedAt'];
            }
            if (is_string($coverage['staleAfter'] ?? null) && $coverage['staleAfter'] !== '') {
                $staleAfter[] = $coverage['staleAfter'];
            }
            $rules = is_array($coverage['rules'] ?? null) ? $coverage['rules'] : [];
            foreach ($rules as $rule) {
                if (! is_array($rule)) {
                    continue;
                }
                if (is_string($rule['sourceUrl'] ?? null) && $rule['sourceUrl'] !== '') {
                    $sources[] = $rule['sourceUrl'];
                }
                if (is_string($rule['verifiedAt'] ?? null) && $rule['verifiedAt'] !== '') {
                    $verifiedAt[] = $rule['verifiedAt'];
                }
                if (is_string($rule['validFrom'] ?? null) && $rule['validFrom'] !== '') {
                    $validFrom[] = $rule['validFrom'];
                }
                if (is_string($rule['validUntil'] ?? null) && $rule['validUntil'] !== '') {
                    $validUntil[] = $rule['validUntil'];
                }
            }
        }
        $sources = array_values(array_unique($sources));
        $verifiedAt = array_values(array_unique($verifiedAt));
        $validFrom = array_values(array_unique($validFrom));
        $validUntil = array_values(array_unique($validUntil));
        $staleAfter = array_values(array_unique($staleAfter));

        return [
            'status' => $jurisdiction ? 'EXISTENTE' : 'ALTA_PROPUESTA',
            'department_code' => $unit?->parent?->code,
            'municipality_code' => $unit?->code,
            'geographic_unit_id' => $unit?->id,
            'department_name' => $unit?->parent?->name,
            'municipality_name' => $unit?->name,
            'proposed_key' => $jurisdiction?->key ?? ($unit ? $this->proposedJurisdictionKey((string) $unit->code) : null),
            'existing_jurisdiction_id' => $jurisdiction?->id,
            'source' => ['urls' => $sources, 'verified_at' => $verifiedAt],
            'validity' => ['from' => $validFrom, 'until' => $validUntil, 'stale_after' => $staleAfter],
        ];
    }

    /** @param array<string,mixed> $raw @return array<string,mixed> */
    private function flatOnboardingData(?GeographicUnit $unit, ?Jurisdiction $jurisdiction, array $raw): array
    {
        $sourceUrl = trim((string) ($raw['source_url'] ?? ''));
        $verifiedAt = trim((string) ($raw['verified_at'] ?? ''));
        $coverage = [
            'sourceUrls' => [$sourceUrl],
            'verifiedAt' => $verifiedAt,
            'staleAfter' => trim((string) ($raw['stale_after'] ?? '')),
            'rules' => [[
                'sourceUrl' => $sourceUrl,
                'verifiedAt' => $verifiedAt,
                'validFrom' => trim((string) ($raw['valid_from'] ?? '')),
                'validUntil' => trim((string) ($raw['valid_until'] ?? '')),
            ]],
        ];
        $onboarding = $this->onboardingData($unit, $jurisdiction, [$coverage]);
        $onboarding['vehicle_kind'] = trim((string) ($raw['vehicle_kind'] ?? ''));
        $onboarding['service_type'] = trim((string) ($raw['service_type'] ?? ''));

        return $onboarding;
    }

    private function territoryForJurisdiction(Jurisdiction $jurisdiction): ?GeographicUnit
    {
        $unit = $jurisdiction->primaryGeographicUnit()->with('parent')->first();

        return $unit?->level === GeographicUnitLevel::Municipality &&
            $unit->parent?->level === GeographicUnitLevel::Department
                ? $unit
                : null;
    }

    /** @param array{sourceCheckedAt:string,staleAfter:string} $validation */
    private function assertSourceCurrent(array $validation): void
    {
        $verifiedAt = CarbonImmutable::parse($validation['sourceCheckedAt']);
        $staleAfter = CarbonImmutable::parse($validation['staleAfter']);
        if ($verifiedAt->isAfter(now()) || ! $staleAfter->isAfter(now())) {
            throw new DomainException('The source is future-dated or stale; no restriction draft can be created.');
        }
    }

    /** @param array<string,mixed> $normalized */
    private function assertOnboardingSourceCurrent(array $normalized): void
    {
        $source = $normalized['onboarding']['source'] ?? [];
        $validity = $normalized['onboarding']['validity'] ?? [];
        $urls = $source['urls'] ?? [];
        $verifiedAt = $source['verified_at'] ?? [];
        $staleAfter = $validity['stale_after'] ?? [];
        if (! is_array($urls) || $urls === [] || ! is_array($verifiedAt) || $verifiedAt === [] ||
            ! is_array($staleAfter) || $staleAfter === []) {
            throw new DomainException('A current HTTPS source, verification date, and review date are required.');
        }
        $this->assertSourceUrlsHaveNoCredentials($urls);
        foreach ($verifiedAt as $date) {
            if (CarbonImmutable::parse($date)->isAfter(now())) {
                throw new DomainException('A source verification date is in the future.');
            }
        }
        foreach ($staleAfter as $date) {
            if (! CarbonImmutable::parse($date)->isAfter(now())) {
                throw new DomainException('A source has expired since analysis; analyze the file again.');
            }
        }
    }

    /** @param list<mixed> $urls */
    private function assertSourceUrlsHaveNoCredentials(array $urls): void
    {
        foreach ($urls as $url) {
            if (! is_string($url)) {
                throw new DomainException('Source URLs must not contain embedded credentials.');
            }
            try {
                $parts = parse_url($url);
            } catch (\ValueError) {
                $parts = false;
            }
            if (! is_array($parts) || array_key_exists('user', $parts) || array_key_exists('pass', $parts)) {
                throw new DomainException('Source URLs must not contain embedded credentials.');
            }
        }
    }

    /** @param array<string,mixed> $payload @return array<string,mixed> */
    private function prepareNewMunicipalityPayload(array $payload, GeographicUnit $unit): array
    {
        if (! is_array($payload['coverages'] ?? null) || ! array_is_list($payload['coverages'])) {
            throw new DomainException('A new municipality proposal must contain a coverage list.');
        }
        $payload['schemaVersion'] = 2;
        $payload['id'] = $this->proposedJurisdictionKey((string) $unit->code);
        $payload['name'] = $unit->name;
        $payload['municipalityCodes'] = [(string) $unit->code];
        $payload['consultationEnabled'] = false;
        foreach ($payload['coverages'] as &$coverage) {
            if (! is_array($coverage)) {
                throw new DomainException('An imported coverage is invalid.');
            }
            $coverage['coverageCompleteness'] = 'partial';
            $coverage['consultationEnabled'] = false;
        }
        unset($coverage);

        return $payload;
    }

    /** @param array<string,mixed> $payload @param array<string,mixed>|null $existing @return array<string,mixed> */
    private function prepareNewModalityCoverage(array $payload, ?array $existing, bool $preserveExistingConsultation = false): array
    {
        if (! is_array($payload['coverages'] ?? null) || ! array_is_list($payload['coverages'])) {
            throw new DomainException('An imported jurisdiction must contain a coverage list.');
        }
        $existingByPair = [];
        $existingCoverages = is_array($existing['coverages'] ?? null) ? $existing['coverages'] : [];
        foreach ($existingCoverages as $coverage) {
            if (is_array($coverage)) {
                $existingByPair[($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '')] = $coverage;
            }
        }
        foreach ($payload['coverages'] ?? [] as &$coverage) {
            if (! is_array($coverage)) {
                continue;
            }
            $pair = ($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '');
            $previous = $existingByPair[$pair] ?? null;
            if ($previous === null) {
                $coverage['coverageCompleteness'] = 'partial';
                $coverage['consultationEnabled'] = false;
            } else {
                if (isset($previous['coverageCompleteness'])) {
                    $coverage['coverageCompleteness'] = $previous['coverageCompleteness'];
                }
                if ($preserveExistingConsultation) {
                    $coverage['consultationEnabled'] = $previous['consultationEnabled'] ?? false;
                }
            }
        }
        unset($coverage);

        return $payload;
    }

    /** @param array<string,mixed> $jurisdiction @param array<string,mixed>|null $existing */
    private function assertNoMaterialRuleConflicts(array $jurisdiction, ?array $existing): void
    {
        $rulesById = [];
        $existingCoverages = is_array($existing['coverages'] ?? null) ? $existing['coverages'] : [];
        $incomingCoverages = is_array($jurisdiction['coverages'] ?? null) ? $jurisdiction['coverages'] : [];
        foreach ($existingCoverages as $coverage) {
            if (! is_array($coverage)) {
                continue;
            }
            $pair = ($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '');
            foreach (is_array($coverage['rules'] ?? null) ? $coverage['rules'] : [] as $rule) {
                if (is_array($rule) && is_string($rule['id'] ?? null)) {
                    if (($existing['schemaVersion'] ?? 1) === 2) {
                        $rule['conditions'] ??= [];
                    }
                    $rulesById[$rule['id']] = ['pair' => $pair, 'rule' => $rule];
                }
            }
        }
        foreach ($incomingCoverages as $coverage) {
            if (! is_array($coverage)) {
                continue;
            }
            $pair = ($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '');
            foreach (is_array($coverage['rules'] ?? null) ? $coverage['rules'] : [] as $rule) {
                if (! is_array($rule) || ! is_string($rule['id'] ?? null) || ! isset($rulesById[$rule['id']])) {
                    continue;
                }
                if (($jurisdiction['schemaVersion'] ?? 1) === 2 || ($existing['schemaVersion'] ?? 1) === 2) {
                    $rule['conditions'] ??= $rulesById[$rule['id']]['rule']['conditions'] ?? [];
                }
                if ($pair !== $rulesById[$rule['id']]['pair'] ||
                    $this->canonicalJson($rule) !== $this->canonicalJson($rulesById[$rule['id']]['rule'])) {
                    throw new DomainException('Material conflict for existing rule id '.$rule['id'].'; use the normal editorial change flow.');
                }
            }
        }
    }

    private function canonicalJson(mixed $value): string
    {
        $sort = function (mixed $item) use (&$sort): mixed {
            if (! is_array($item)) {
                return $item;
            }
            foreach ($item as &$child) {
                $child = $sort($child);
            }
            unset($child);
            if (! array_is_list($item)) {
                ksort($item);
            }

            return $item;
        };

        return json_encode($sort($value), JSON_THROW_ON_ERROR);
    }

    /** @return array{0:list<array<string,mixed>>,1:?string,2:?int} */
    private function read(string $path, string $format, ?string $sheet): array
    {
        if ($format === 'json') {
            try {
                $decoded = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            } catch (JsonException) {
                throw new DomainException('The JSON import is malformed.');
            }
            if (is_array($decoded) && ! array_is_list($decoded) && isset($decoded['jurisdictions'])) {
                $schemaVersion = array_key_exists('schemaVersion', $decoded) ? $decoded['schemaVersion'] : 1;
                if (! is_int($schemaVersion) || ! in_array($schemaVersion, [1, 2], true) || ! is_array($decoded['jurisdictions']) || ! array_is_list($decoded['jurisdictions'])) {
                    throw new DomainException('The restrictions envelope is invalid.');
                }
                foreach ($decoded['jurisdictions'] as $jurisdiction) {
                    if (! is_array($jurisdiction) || array_is_list($jurisdiction)) {
                        throw new DomainException('Invalid restrictions jurisdiction.');
                    }
                    $citySchemaVersion = array_key_exists('schemaVersion', $jurisdiction)
                        ? $jurisdiction['schemaVersion']
                        : 1;
                    if (! is_int($citySchemaVersion) || ! in_array($citySchemaVersion, [1, 2], true) ||
                        ($schemaVersion === 1 && $citySchemaVersion !== 1)) {
                        throw new DomainException('Jurisdiction schemaVersion does not match the dataset envelope.');
                    }
                }

                return [$decoded['jurisdictions'], null, $schemaVersion];
            }
            if (! is_array($decoded) || ! array_is_list($decoded)) {
                throw new DomainException('The JSON import must contain a list of rows or jurisdictions.');
            }

            return [$decoded, null, null];
        }
        if ($format === 'csv') {
            $file = new SplFileObject($path, 'r');
            $file->setFlags(SplFileObject::READ_CSV | SplFileObject::SKIP_EMPTY | SplFileObject::DROP_NEW_LINE);
            $table = iterator_to_array($file, false);

            return [$this->associateTable($table), null, null];
        }

        $workbook = $this->xlsx->read($path);
        $selected = $sheet ?? ($workbook['sheets'][0] ?? null);
        if ($selected === null || ! isset($workbook['rows'][$selected])) {
            throw new DomainException('The requested XLSX worksheet does not exist.');
        }

        $rows = $this->associateTable($workbook['rows'][$selected]);
        if ($this->isOwnerCalendar($rows)) {
            $rows = $this->adaptOwnerCalendar($rows, $workbook['rows']);
        }

        return [$rows, $selected, null];
    }

    /** @param list<list<mixed>> $table @return list<array<string,mixed>> */
    private function associateTable(array $table): array
    {
        $header = array_shift($table);
        if (! is_array($header) || $header === []) {
            throw new DomainException('The tabular import has no header row.');
        }
        $header = array_map(fn (mixed $value): string => strtolower(trim((string) $value)), $header);
        $header[0] = ltrim($header[0], "\xEF\xBB\xBF");
        if (count($header) !== count(array_unique($header))) {
            throw new DomainException('The tabular import has duplicate headers.');
        }
        $rows = [];
        foreach ($table as $values) {
            if (! is_array($values) || count(array_filter($values, fn (mixed $value): bool => trim((string) $value) !== '')) === 0) {
                continue;
            }
            $values = array_pad(array_slice($values, 0, count($header)), count($header), '');
            $rows[] = array_combine($header, $values);
        }

        return $rows;
    }

    /** @param array<string,mixed> $raw @return array{state:string,jurisdiction:?Jurisdiction,normalized:?array,errors:list<string>} */
    private function normalize(array $raw, ?int $envelopeSchemaVersion = null): array
    {
        $jurisdiction = null;
        $onboarding = null;
        $normalized = null;
        $publish = strtolower(trim((string) ($raw['publish'] ?? 'yes')));
        if (in_array($publish, ['no', 'false', '0', 'excluded', 'exclude'], true)) {
            return ['state' => 'excluded', 'jurisdiction' => null, 'normalized' => null, 'errors' => []];
        }
        try {
            if (isset($raw['_owner_error']) && $raw['_owner_error'] !== '') {
                throw new DomainException((string) $raw['_owner_error']);
            }
            if (isset($raw['coverages'])) {
                $citySchemaVersion = array_key_exists('schemaVersion', $raw)
                    ? $raw['schemaVersion']
                    : 1;
                if (! is_int($citySchemaVersion) ||
                    ! in_array($citySchemaVersion, [1, 2], true) ||
                    ($envelopeSchemaVersion === 1 && $citySchemaVersion !== 1)) {
                    throw new DomainException('Jurisdiction schemaVersion does not match the dataset envelope.');
                }
                $payload = $raw;
                $territory = null;
                if ($citySchemaVersion === 2 && array_key_exists('municipalityCodes', $raw)) {
                    $codes = $raw['municipalityCodes'];
                    if (! is_array($codes) || ! array_is_list($codes) || count($codes) !== 1 || ! is_string($codes[0] ?? null)) {
                        $onboarding = $this->onboardingData(null, null, is_array($raw['coverages']) ? $raw['coverages'] : []);
                        $onboarding['status'] = 'REQUIERE_ASIGNACION_MANUAL';
                        $onboarding['municipality_codes'] = is_array($codes) ? $codes : [];
                        $normalized = ['payload' => $raw, 'onboarding' => $onboarding];
                        throw new DomainException('A schema2 jurisdiction covering multiple or invalid municipalities requires manual assignment.');
                    }
                    $municipalityCode = $codes[0];
                    $departmentCode = substr($municipalityCode, 0, 2);
                    $onboarding = $this->onboardingData(null, null, $raw['coverages']);
                    $onboarding['status'] = 'DIVIPOLA_PENDIENTE';
                    $onboarding['municipality_code'] = $municipalityCode;
                    $onboarding['department_code'] = $departmentCode;
                    $territory = $this->territoryByCodes($departmentCode, $municipalityCode);
                    $matches = $this->jurisdictionsForTerritory($territory);
                    if ($matches->count() > 1) {
                        $incomingId = trim((string) ($raw['id'] ?? ''));
                        $selected = $matches->first(fn (Jurisdiction $candidate): bool => $candidate->key === $incomingId);
                        if (! $selected) {
                            $onboarding = $this->onboardingData($territory, null, $raw['coverages']);
                            $onboarding['status'] = 'REQUIERE_ASIGNACION_MANUAL';
                            $onboarding['candidate_jurisdictions'] = $this->jurisdictionOptions($matches);
                            $normalized = ['payload' => $raw, 'onboarding' => $onboarding];
                            throw new DomainException('Multiple jurisdictions cover this municipality; select a listed jurisdiction id and analyze the file again.');
                        }
                        $matches = collect([$selected]);
                    }
                    $jurisdiction = $matches->first();
                    if ($jurisdiction) {
                        if (($raw['id'] ?? null) !== $jurisdiction->key) {
                            throw new DomainException('The JSON jurisdiction id conflicts with the canonical municipality mapping.');
                        }
                        $payload['name'] = $jurisdiction->name;
                        if ($citySchemaVersion === 2) {
                            $payload = $this->prepareNewModalityCoverage($payload, $this->latestPayloadFor($jurisdiction));
                        }
                        $onboarding = $this->onboardingData($territory, $jurisdiction, $raw['coverages']);
                    } else {
                        $incomingId = trim((string) ($raw['id'] ?? ''));
                        if ($incomingId === '') {
                            throw new DomainException('A schema2 municipality proposal must include a jurisdiction id.');
                        }
                        if (Jurisdiction::query()->where('key', $incomingId)->exists() ||
                            Jurisdiction::query()->where('key', $this->proposedJurisdictionKey($municipalityCode))->exists()) {
                            $onboarding = $this->onboardingData($territory, null, $raw['coverages']);
                            $onboarding['status'] = 'REQUIERE_ASIGNACION_MANUAL';
                            throw new DomainException('The JSON id or deterministic jurisdiction key conflicts with an existing registration.');
                        }
                        $payload = $this->prepareNewMunicipalityPayload($raw, $territory);
                        $onboarding = $this->onboardingData($territory, null, $payload['coverages']);
                    }
                }
                if (! $territory && ! $jurisdiction) {
                    $key = trim((string) ($raw['id'] ?? ''));
                    $jurisdiction = Jurisdiction::query()->where('key', $key)->where('enabled', true)->first();
                    if (! $jurisdiction) {
                        throw new DomainException('The jurisdiction_id is unknown or disabled.');
                    }
                    $onboarding = $this->onboardingData($this->territoryForJurisdiction($jurisdiction), $jurisdiction, $payload['coverages']);
                }
                $normalized = ['payload' => $payload, 'onboarding' => $onboarding];
                $expectedId = $payload['id'];
                $validation = $this->validator->validateJurisdictionForEnvelope(
                    $payload,
                    $expectedId,
                    $envelopeSchemaVersion ?? $citySchemaVersion,
                );
                $this->assertSourceCurrent($validation);
                $this->assertSourceUrlsHaveNoCredentials($onboarding['source']['urls'] ?? []);
                if ($jurisdiction) {
                    $this->assertNoMaterialRuleConflicts($payload, $this->latestPayloadFor($jurisdiction));
                }
                return ['state' => 'valid', 'jurisdiction' => $jurisdiction, 'normalized' => $normalized, 'errors' => []];
            }

            $departmentCode = trim((string) ($raw['department_code'] ?? ''));
            $municipalityCode = trim((string) ($raw['municipality_code'] ?? ''));
            $hasDepartmentCode = $departmentCode !== '';
            $hasMunicipalityCode = $municipalityCode !== '';
            $territory = null;
            $isProposal = false;
            if ($hasDepartmentCode || $hasMunicipalityCode) {
                $onboarding = $this->flatOnboardingData(null, null, $raw);
                $onboarding['status'] = 'DIVIPOLA_PENDIENTE';
                $onboarding['department_code'] = $departmentCode ?: null;
                $onboarding['municipality_code'] = $municipalityCode ?: null;
                if (! $hasDepartmentCode || ! $hasMunicipalityCode) {
                    throw new DomainException('department_code and municipality_code must be supplied together.');
                }
                $territory = $this->territoryByCodes($departmentCode, $municipalityCode);
                $matches = $this->jurisdictionsForTerritory($territory);
                if ($matches->count() > 1) {
                    $incomingKey = trim((string) ($raw['jurisdiction_id'] ?? ''));
                    $selected = $matches->first(fn (Jurisdiction $candidate): bool => $candidate->key === $incomingKey);
                    if (! $selected) {
                        $onboarding = $this->flatOnboardingData($territory, null, $raw);
                        $onboarding['status'] = 'REQUIERE_ASIGNACION_MANUAL';
                        $onboarding['candidate_jurisdictions'] = $this->jurisdictionOptions($matches);
                        throw new DomainException('Multiple jurisdictions cover this municipality; select a listed jurisdiction_id and analyze the file again.');
                    }
                    $matches = collect([$selected]);
                }
                $jurisdiction = $matches->first();
                $incomingKey = trim((string) ($raw['jurisdiction_id'] ?? ''));
                if ($jurisdiction && $incomingKey !== '' && $incomingKey !== $jurisdiction->key) {
                    throw new DomainException('The jurisdiction_id conflicts with the canonical municipality mapping.');
                }
                if (! $jurisdiction) {
                    $isProposal = true;
                    $deterministicKey = $this->proposedJurisdictionKey($municipalityCode);
                    if (Jurisdiction::query()->where('key', $deterministicKey)->exists() ||
                        ($incomingKey !== '' && Jurisdiction::query()->where('key', $incomingKey)->exists())) {
                        $onboarding = $this->flatOnboardingData($territory, null, $raw);
                        $onboarding['status'] = 'REQUIERE_ASIGNACION_MANUAL';
                        throw new DomainException('The supplied id or deterministic jurisdiction key belongs to another municipality.');
                    }
                } else {
                    $onboarding = $this->flatOnboardingData($territory, $jurisdiction, $raw);
                }
            } else {
                $key = trim((string) ($raw['jurisdiction_id'] ?? ''));
                $jurisdiction = Jurisdiction::query()->where('key', $key)->where('enabled', true)->first();
                if (! $jurisdiction) {
                    throw new DomainException('The jurisdiction_id is unknown or disabled.');
                }
                $onboarding = $this->flatOnboardingData($this->territoryForJurisdiction($jurisdiction), $jurisdiction, $raw);
            }

            $existingPayload = $jurisdiction ? $this->latestPayloadFor($jurisdiction) : null;
            $vehicleKind = trim((string) ($raw['vehicle_kind'] ?? ''));
            $serviceType = trim((string) ($raw['service_type'] ?? ''));
            $existingCoverage = $this->coverageForPair($existingPayload, $vehicleKind, $serviceType);
            $rawConsultationInput = $raw['consultation_enabled'] ?? '';
            $consultationProvided = array_key_exists('consultation_enabled', $raw) && $raw['consultation_enabled'] !== '';
            $consultationInput = is_bool($rawConsultationInput)
                ? ($rawConsultationInput ? 'true' : 'false')
                : trim((string) $rawConsultationInput);
            $requestedConsultation = $consultationProvided
                ? $this->boolean($consultationInput, 'consultation_enabled')
                : null;
            $schemaVersion = $isProposal || $territory !== null || ($existingPayload['schemaVersion'] ?? 1) === 2 || $consultationProvided ? 2 : 1;
            $coverage = [
                'vehicleKind' => $vehicleKind,
                'serviceType' => $serviceType,
                'verifiedAt' => trim((string) ($raw['verified_at'] ?? '')),
                'staleAfter' => trim((string) ($raw['stale_after'] ?? '')),
                'sourceUrls' => [trim((string) ($raw['source_url'] ?? ''))],
            ];
            if ($schemaVersion === 2) {
                $coverage['coverageCompleteness'] = $existingCoverage['coverageCompleteness'] ?? 'partial';
                $coverage['consultationEnabled'] = $existingCoverage === null
                    ? false
                    : ($requestedConsultation ?? ($existingCoverage['consultationEnabled'] ?? false));
            }
            $rule = [
                'id' => trim((string) ($raw['rule_id'] ?? '')),
                'priority' => $this->integer($raw['priority'] ?? null, 'priority'),
                'effect' => trim((string) ($raw['effect'] ?? '')),
                'validFrom' => trim((string) ($raw['valid_from'] ?? '')),
                'timeWindows' => $this->jsonList($raw['time_windows'] ?? null, 'time_windows'),
                'appliesOnHolidays' => $this->boolean($raw['applies_on_holidays'] ?? null),
                'sourceUrl' => trim((string) ($raw['source_url'] ?? '')),
                'verifiedAt' => trim((string) ($raw['verified_at'] ?? '')),
            ];
            foreach (['valid_until' => 'validUntil', 'date_parity' => 'dateParity', 'digit_position' => 'digitPosition'] as $source => $target) {
                if (trim((string) ($raw[$source] ?? '')) !== '') {
                    $rule[$target] = trim((string) $raw[$source]);
                }
            }
            foreach (['weekdays' => 'weekdays', 'digits' => 'digits', 'registration_origins' => 'registrationOrigins'] as $source => $target) {
                if (trim((string) ($raw[$source] ?? '')) !== '') {
                    $rule[$target] = $this->jsonList($raw[$source], $source);
                }
            }
            if ($schemaVersion === 2) {
                $existingRules = [];
                foreach ($existingCoverage['rules'] ?? [] as $existingRule) {
                    if (is_array($existingRule) && is_string($existingRule['id'] ?? null)) {
                        $existingRules[$existingRule['id']] = $existingRule;
                    }
                }
                $rule['conditions'] = $existingRules[$rule['id']]['conditions'] ?? [];
            }
            $payload = [
                'id' => $isProposal ? $this->proposedJurisdictionKey($municipalityCode) : $jurisdiction->key,
                'name' => $isProposal ? $territory->name : $jurisdiction->name,
                'coverages' => [$coverage + ['rules' => [$rule]]],
                ...($schemaVersion === 2 ? ['schemaVersion' => 2] : []),
            ];
            if ($isProposal) {
                $payload['municipalityCodes'] = [$municipalityCode];
                $payload['consultationEnabled'] = false;
                $onboarding = $this->flatOnboardingData($territory, null, $raw);
            } elseif ($territory) {
                $onboarding = $this->flatOnboardingData($territory, $jurisdiction, $raw);
            } else {
                $onboarding = $this->flatOnboardingData($this->territoryForJurisdiction($jurisdiction), $jurisdiction, $raw);
            }
            $normalized = ['coverage' => $coverage, 'rule' => $rule, 'onboarding' => $onboarding];
            $validation = $schemaVersion === 2 && ($isProposal || array_key_exists('municipalityCodes', $payload))
                ? $this->validator->validateJurisdictionForEnvelope($payload, $payload['id'], 2)
                : $this->validator->validateJurisdiction($payload, $payload['id'], $schemaVersion);
            $this->assertSourceCurrent($validation);
            $this->assertSourceUrlsHaveNoCredentials($onboarding['source']['urls'] ?? []);
            if ($existingPayload) {
                $this->assertNoMaterialRuleConflicts($payload, $existingPayload);
            }
            return ['state' => 'valid', 'jurisdiction' => $jurisdiction, 'normalized' => $normalized, 'errors' => []];
        } catch (DomainException $error) {
            if ($normalized === null && is_array($onboarding)) {
                $normalized = ['onboarding' => $onboarding];
            }

            return ['state' => 'invalid', 'jurisdiction' => $jurisdiction, 'normalized' => $normalized, 'errors' => [$error->getMessage()]];
        }
    }

    /** @param list<array<string,mixed>> $rows */
    private function isOwnerCalendar(array $rows): bool
    {
        if ($rows === []) {
            return false;
        }

        return array_diff(['departamento', 'ciudad', 'tipo vehículo', 'fecha', 'dígitos restringidos', '¿publicar en picoradar?', 'fuente'], array_keys($rows[0])) === [];
    }

    /**
     * @param  list<array<string,mixed>>  $rows
     * @param  array<string,list<list<string>>>  $sheets
     * @return list<array<string,mixed>>
     */
    private function adaptOwnerCalendar(array $rows, array $sheets): array
    {
        $sourceDates = [];
        foreach ($sheets as $table) {
            if (($table[0][0] ?? null) !== 'URL' || ($table[0][2] ?? null) !== 'Auditada el') {
                continue;
            }
            foreach (array_slice($table, 1) as $sourceRow) {
                $url = trim((string) ($sourceRow[0] ?? ''));
                $date = trim((string) ($sourceRow[2] ?? ''));
                if ($url !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) && (! isset($sourceDates[$url]) || $date > $sourceDates[$url])) {
                    $sourceDates[$url] = $date;
                }
            }
        }

        return array_map(function (array $row) use ($sourceDates): array {
            $publishFlag = GeographicNameNormalizer::normalize((string) ($row['¿publicar en picoradar?'] ?? '')) === 'si';
            $activeFlag = str_starts_with(GeographicNameNormalizer::normalize((string) ($row['activar para fecha de corte'] ?? '')), 'si');
            $source = trim((string) ($row['fuente'] ?? ''));
            $verifiedDate = $sourceDates[$source] ?? '';
            $date = $this->ownerDate($row['fecha'] ?? null);
            $vehicle = GeographicNameNormalizer::normalize((string) ($row['tipo vehículo'] ?? ''));
            [$vehicleKind, $serviceType] = match (true) {
                str_starts_with($vehicle, 'taxi') => ['car', 'taxi'],
                $vehicle === 'particular' => ['car', 'private'],
                $vehicle === 'moto' => ['motorcycle', 'private'],
                default => ['', ''],
            };
            $digitPosition = str_contains(GeographicNameNormalizer::normalize((string) ($row['dígito usado'] ?? '')), 'ultimo') ? 'lastNumeric' : '';
            $digits = array_map('intval', preg_split('/\s*,\s*/', trim((string) ($row['dígitos restringidos'] ?? '')), -1, PREG_SPLIT_NO_EMPTY) ?: []);
            $windows = $this->ownerTimeWindows((string) ($row['horario'] ?? ''));
            $jurisdiction = $this->ownerJurisdiction((string) ($row['departamento'] ?? ''), (string) ($row['ciudad'] ?? ''));

            return [
                'jurisdiction_id' => $jurisdiction?->key ?? '',
                'jurisdiction_name' => (string) ($row['ciudad'] ?? ''),
                'vehicle_kind' => $vehicleKind,
                'service_type' => $serviceType,
                'rule_id' => 'owner-'.substr(hash('sha256', implode('|', [(string) ($row['departamento'] ?? ''), (string) ($row['ciudad'] ?? ''), $vehicle, $date, implode(',', $digits), (string) ($row['horario'] ?? ''), $source])), 0, 24),
                'priority' => '100',
                'effect' => 'restrict',
                'valid_from' => $date === '' ? '' : $date.'T00:00:00-05:00',
                'valid_until' => $date === '' ? '' : $date.'T23:59:59-05:00',
                'weekdays' => '',
                'date_parity' => '',
                'digit_position' => $digitPosition,
                'digits' => json_encode($digits, JSON_THROW_ON_ERROR),
                'time_windows' => json_encode($windows, JSON_THROW_ON_ERROR),
                'applies_on_holidays' => 'true',
                'source_url' => $source,
                'verified_at' => $verifiedDate === '' ? '' : $verifiedDate.'T00:00:00-05:00',
                'stale_after' => $date === '' ? '' : CarbonImmutable::parse($date, 'America/Bogota')->addDay()->startOfDay()->toAtomString(),
                'publish' => $publishFlag && $activeFlag ? 'yes' : 'no',
                '_owner_scope' => (string) ($row['alcance / zona'] ?? ''),
                '_owner_state' => (string) ($row['estado temporal al corte'] ?? ''),
                '_owner_error' => $windows === [] ? 'The owner workbook time window cannot be represented without ambiguity.' : '',
            ];
        }, $rows);
    }

    private function ownerDate(mixed $value): string
    {
        if (is_numeric($value) && (float) $value > 0) {
            return CarbonImmutable::create(1899, 12, 30, 0, 0, 0, 'UTC')->addDays((int) floor((float) $value))->toDateString();
        }
        $text = trim((string) $value);

        return preg_match('/^\d{4}-\d{2}-\d{2}$/', $text) ? $text : '';
    }

    /** @return list<array{startMinute:int,endMinute:int}> */
    private function ownerTimeWindows(string $value): array
    {
        $windows = [];
        foreach (preg_split('/\s*;\s*/', trim($value), -1, PREG_SPLIT_NO_EMPTY) ?: [] as $window) {
            if (! preg_match('/^(\d{1,2}):(\d{2})\s*[\x{2013}\x{2014}-]\s*(\d{1,2}):(\d{2})/u', $window, $matches)) {
                return [];
            }
            $start = ((int) $matches[1] * 60) + (int) $matches[2];
            $end = ((int) $matches[3] * 60) + (int) $matches[4];
            if ($start === $end) {
                return [];
            }
            $windows[] = ['startMinute' => $start, 'endMinute' => $end];
        }

        return $windows;
    }

    private function ownerJurisdiction(string $department, string $city): ?Jurisdiction
    {
        $department = GeographicNameNormalizer::normalize($department);
        $city = GeographicNameNormalizer::normalize($city);

        return Jurisdiction::query()
            ->where('enabled', true)
            ->whereHas('primaryGeographicUnit', fn ($query) => $query
                ->where('normalized_name', $city)
                ->whereHas('parent', fn ($parent) => $parent->where('normalized_name', $department)))
            ->first();
    }

    /** @param list<RestrictionImportRow> $rows @return array<string,mixed> */
    private function payloadForRows(Jurisdiction $jurisdiction, array $rows, bool $createdNewMunicipality = false): array
    {
        if (count($rows) === 1 && isset($rows[0]->normalized['payload'])) {
            $existing = $this->latestPayloadFor($jurisdiction, false);
            $payload = $this->mergeSchema2CoverageState(
                $rows[0]->normalized['payload'],
                $existing,
            );
            if ($createdNewMunicipality) {
                $unit = $jurisdiction->primaryGeographicUnit()->with('parent')->firstOrFail();
                $payload = $this->prepareNewMunicipalityPayload($payload, $unit);
            } elseif (($rows[0]->normalized['onboarding']['status'] ?? null) === 'ALTA_PROPUESTA') {
                $unit = $jurisdiction->primaryGeographicUnit()->with('parent')->firstOrFail();
                $payload['id'] = $jurisdiction->key;
                $payload['name'] = $jurisdiction->name;
                $payload['municipalityCodes'] = $existing['municipalityCodes'] ?? [(string) $unit->code];
                $payload['consultationEnabled'] = $existing['consultationEnabled'] ?? false;
                $payload = $this->prepareNewModalityCoverage($payload, $existing, true);
            }

            return $payload;
        }
        $coverages = [];
        foreach ($rows as $row) {
            $normalized = $row->normalized;
            if (isset($normalized['payload'])) {
                throw new DomainException('Full-jurisdiction JSON cannot be mixed with tabular rows.');
            }
            $coverage = $normalized['coverage'];
            $key = $coverage['vehicleKind'].':'.$coverage['serviceType'];
            if (! isset($coverages[$key])) {
                $coverages[$key] = $coverage + ['rules' => []];
            } elseif (json_encode($coverage, JSON_THROW_ON_ERROR) !== json_encode(array_intersect_key($coverages[$key], $coverage), JSON_THROW_ON_ERROR)) {
                throw new DomainException('Coverage metadata differs between selected rows.');
            }
            $coverages[$key]['rules'][] = $normalized['rule'];
        }

        $payload = ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'coverages' => array_values($coverages)];
        if ($createdNewMunicipality) {
            $unit = $jurisdiction->primaryGeographicUnit()->with('parent')->firstOrFail();
            $payload = $this->prepareNewMunicipalityPayload($payload, $unit);
        }

        return $this->mergeSchema2CoverageState($payload, $this->latestPayloadFor($jurisdiction, false));
    }

    /** @param array<string,mixed> $payload @param array<string,mixed>|null $existing @return array<string,mixed> */
    private function mergeSchema2CoverageState(array $payload, ?array $existing): array
    {
        $coverages = $payload['coverages'] ?? [];
        if (! is_array($coverages) || ! array_is_list($coverages)) {
            throw new DomainException('An imported jurisdiction must contain a coverage list.');
        }
        $existingCoverages = is_array($existing['coverages'] ?? null) ? $existing['coverages'] : [];
        $isSchema2 = ($payload['schemaVersion'] ?? 1) === 2 ||
            ($existing['schemaVersion'] ?? 1) === 2 ||
            array_filter($coverages, static fn (mixed $coverage): bool => is_array($coverage) && (
                array_key_exists('coverageCompleteness', $coverage) || array_key_exists('consultationEnabled', $coverage)
            )) !== [];
        $existingByPair = [];
        foreach ($existingCoverages as $coverage) {
            if (is_array($coverage)) {
                $existingByPair[($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '')] = $coverage;
            }
        }

        $incomingPairs = [];
        $merged = [];
        foreach ($coverages as $coverage) {
            if (! is_array($coverage)) {
                throw new DomainException('An imported coverage is invalid.');
            }
            $pair = ($coverage['vehicleKind'] ?? '').'|'.($coverage['serviceType'] ?? '');
            $incomingPairs[$pair] = true;
            $previous = $existingByPair[$pair] ?? [];
            $coverage['rules'] = $this->mergeRulesById($coverage['rules'] ?? [], $previous['rules'] ?? [], $isSchema2);
            if ($isSchema2) {
                if ($previous === []) {
                    $coverage['coverageCompleteness'] = 'partial';
                    $coverage['consultationEnabled'] = false;
                } else {
                    $coverage['coverageCompleteness'] = $previous['coverageCompleteness'] ?? 'partial';
                    $coverage['consultationEnabled'] ??= $previous['consultationEnabled'] ?? false;
                }
                if (! is_bool($coverage['consultationEnabled'])) {
                    throw new DomainException('coverage consultationEnabled must be a boolean.');
                }
            }
            $merged[] = $coverage;
        }

        foreach ($existingByPair as $pair => $coverage) {
            if (isset($incomingPairs[$pair])) {
                continue;
            }
            if ($isSchema2) {
                $coverage['coverageCompleteness'] ??= 'partial';
                $coverage['consultationEnabled'] ??= false;
                $rules = is_array($coverage['rules'] ?? null) ? $coverage['rules'] : [];
                foreach ($rules as &$rule) {
                    if (is_array($rule)) {
                        $rule['conditions'] ??= [];
                    }
                }
                unset($rule);
                $coverage['rules'] = $rules;
            }
            $merged[] = $coverage;
        }
        $payload['coverages'] = $merged;

        if (! $isSchema2) {
            return $payload;
        }

        $payload['schemaVersion'] = 2;

        if (! array_key_exists('municipalityCodes', $payload) && ! array_key_exists('consultationEnabled', $payload) &&
            array_key_exists('municipalityCodes', $existing ?? []) && array_key_exists('consultationEnabled', $existing ?? [])) {
            $payload['municipalityCodes'] = $existing['municipalityCodes'];
            $payload['consultationEnabled'] = $existing['consultationEnabled'];
        }

        return $payload;
    }

    /** @param list<array<string,mixed>> $incoming @param list<array<string,mixed>> $previous @return list<array<string,mixed>> */
    private function mergeRulesById(array $incoming, array $previous, bool $schema2): array
    {
        if (! array_is_list($incoming) || ! array_is_list($previous)) {
            throw new DomainException('An imported restriction rule list is invalid.');
        }
        $merged = [];
        foreach ($previous as $rule) {
            if (is_array($rule) && is_string($rule['id'] ?? null)) {
                $merged[$rule['id']] = $rule;
            }
        }
        foreach ($incoming as $rule) {
            if (! is_array($rule) || ! is_string($rule['id'] ?? null)) {
                throw new DomainException('An imported restriction rule has no id.');
            }
            $id = $rule['id'];
            if (! isset($merged[$id])) {
                $merged[$id] = $rule;
                continue;
            }
            $existingRule = $merged[$id];
            if ($schema2) {
                $rule['conditions'] ??= $existingRule['conditions'] ?? [];
                $existingRule['conditions'] ??= [];
            }
            if ($this->canonicalJson($rule) !== $this->canonicalJson($existingRule)) {
                throw new DomainException('Material conflict for existing rule id '.$id.'; use the normal editorial change flow.');
            }
            $merged[$id] = $existingRule;
        }

        return array_values($merged);
    }

    /** @param array<string,mixed>|null $payload */
    private function coverageForPair(?array $payload, string $vehicleKind, string $serviceType): ?array
    {
        foreach ($payload['coverages'] ?? [] as $coverage) {
            if (is_array($coverage) &&
                ($coverage['vehicleKind'] ?? null) === $vehicleKind &&
                ($coverage['serviceType'] ?? null) === $serviceType) {
                return $coverage;
            }
        }

        return null;
    }

    /** @return array<string,mixed>|null */
    private function latestPayloadFor(Jurisdiction $jurisdiction, bool $cache = true): ?array
    {
        if ($cache && array_key_exists($jurisdiction->id, $this->latestPayloadCache)) {
            return $this->latestPayloadCache[$jurisdiction->id];
        }
        $version = RestrictionRuleVersion::query()
            ->where('jurisdiction_id', $jurisdiction->id)
            ->orderByDesc('version')
            ->first(['payload']);
        $payload = is_array($version?->payload) ? $version->payload : null;
        if ($cache) {
            $this->latestPayloadCache[$jurisdiction->id] = $payload;
        }

        return $payload;
    }

    private function integer(mixed $value, string $field): int
    {
        if (filter_var($value, FILTER_VALIDATE_INT) === false) {
            throw new DomainException("$field must be an integer.");
        }

        return (int) $value;
    }

    /** @return list<mixed> */
    private function jsonList(mixed $value, string $field): array
    {
        try {
            $decoded = json_decode((string) $value, true, 64, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new DomainException("$field must be a JSON list.");
        }
        if (! is_array($decoded) || ! array_is_list($decoded)) {
            throw new DomainException("$field must be a JSON list.");
        }

        return $decoded;
    }

    private function boolean(mixed $value, string $field = 'applies_on_holidays'): bool
    {
        $boolean = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($boolean === null) {
            throw new DomainException("$field must be true or false.");
        }

        return $boolean;
    }
}
