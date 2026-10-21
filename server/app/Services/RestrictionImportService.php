<?php

namespace App\Services;

use App\Enums\RestrictionImportStatus;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionImportRow;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Support\GeographicNameNormalizer;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use JsonException;
use SplFileObject;

final class RestrictionImportService
{
    private const MAX_ROWS = 10_000;

    public function __construct(
        private readonly SafeXlsxReader $xlsx,
        private readonly RestrictionContractValidator $validator,
        private readonly RestrictionRuleVersionService $versions,
        private readonly DatasetAuditLogger $audit,
    ) {}

    public function analyze(string $path, string $originalName, string $format, ?string $sheet, User $actor): RestrictionImport
    {
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

        [$rows, $selectedSheet] = $this->read($path, $format, $sheet);
        if (count($rows) > self::MAX_ROWS) {
            throw new DomainException('The import row limit was exceeded.');
        }
        $privatePath = "restriction-imports/$sha.$format";
        if (Storage::disk(config('datasets.draft_disk'))->put($privatePath, file_get_contents($path)) === false) {
            throw new DomainException('The import file could not be stored privately.');
        }

        return DB::transaction(function () use ($sha, $originalName, $format, $privatePath, $selectedSheet, $rows, $actor): RestrictionImport {
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
            foreach ($rows as $index => $raw) {
                $result = $this->normalize($raw);
                $counts[$result['state']]++;
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
                'report' => ['syntheticFixturesAllowed' => true, 'counts' => $counts],
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

        return DB::transaction(function () use ($import, $rowIds, $actor): array {
            $locked = RestrictionImport::query()->lockForUpdate()->findOrFail($import->id);
            if ($locked->status !== RestrictionImportStatus::Analyzed) {
                throw new DomainException('Only analyzed imports can be confirmed.');
            }
            $rows = RestrictionImportRow::query()->where('restriction_import_id', $locked->id)->whereIn('id', array_values(array_unique($rowIds)))->lockForUpdate()->get();
            if ($rows->count() !== count(array_unique($rowIds)) || $rows->contains(fn (RestrictionImportRow $row): bool => $row->state !== 'valid' || ! $row->publishable || ! $row->jurisdiction_id)) {
                throw new DomainException('Only valid publishable rows from this import can be confirmed.');
            }

            $created = [];
            foreach ($rows->groupBy('jurisdiction_id') as $jurisdictionId => $cityRows) {
                $jurisdiction = Jurisdiction::query()->findOrFail($jurisdictionId);
                $payload = $this->payloadForRows($jurisdiction, $cityRows->all());
                $this->validator->validateJurisdiction($payload, $jurisdiction->key);
                $created[] = $this->versions->createDraft($jurisdiction, $payload, $actor);
            }
            $locked->update(['status' => RestrictionImportStatus::Confirmed, 'confirmed_by_id' => $actor->id, 'confirmed_at' => now()]);
            $this->audit->log($actor, 'restriction_import.confirmed', $locked, ['rowIds' => array_values($rowIds), 'versionIds' => array_map(fn (RestrictionRuleVersion $version): int => $version->id, $created)]);

            return $created;
        });
    }

    /** @return array{0:list<array<string,mixed>>,1:?string} */
    private function read(string $path, string $format, ?string $sheet): array
    {
        if ($format === 'json') {
            try {
                $decoded = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            } catch (JsonException) {
                throw new DomainException('The JSON import is malformed.');
            }
            if (is_array($decoded) && ! array_is_list($decoded) && isset($decoded['jurisdictions'])) {
                $decoded = $decoded['jurisdictions'];
            }
            if (! is_array($decoded) || ! array_is_list($decoded)) {
                throw new DomainException('The JSON import must contain a list of rows or jurisdictions.');
            }

            return [$decoded, null];
        }
        if ($format === 'csv') {
            $file = new SplFileObject($path, 'r');
            $file->setFlags(SplFileObject::READ_CSV | SplFileObject::SKIP_EMPTY | SplFileObject::DROP_NEW_LINE);
            $table = iterator_to_array($file, false);

            return [$this->associateTable($table), null];
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

        return [$rows, $selected];
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
    private function normalize(array $raw): array
    {
        $publish = strtolower(trim((string) ($raw['publish'] ?? 'yes')));
        if (in_array($publish, ['no', 'false', '0', 'excluded', 'exclude'], true)) {
            return ['state' => 'excluded', 'jurisdiction' => null, 'normalized' => null, 'errors' => []];
        }
        try {
            if (isset($raw['_owner_error']) && $raw['_owner_error'] !== '') {
                throw new DomainException((string) $raw['_owner_error']);
            }
            if (isset($raw['coverages'])) {
                $key = trim((string) ($raw['id'] ?? ''));
                $jurisdiction = Jurisdiction::query()->where('key', $key)->where('enabled', true)->first();
                if (! $jurisdiction) {
                    throw new DomainException('The jurisdiction_id is unknown or disabled.');
                }
                $this->validator->validateJurisdiction($raw, $jurisdiction->key);

                return ['state' => 'valid', 'jurisdiction' => $jurisdiction, 'normalized' => ['payload' => $raw], 'errors' => []];
            }

            $key = trim((string) ($raw['jurisdiction_id'] ?? ''));
            $jurisdiction = Jurisdiction::query()->where('key', $key)->where('enabled', true)->first();
            if (! $jurisdiction) {
                throw new DomainException('The jurisdiction_id is unknown or disabled.');
            }
            $coverage = [
                'vehicleKind' => trim((string) ($raw['vehicle_kind'] ?? '')),
                'serviceType' => trim((string) ($raw['service_type'] ?? '')),
                'verifiedAt' => trim((string) ($raw['verified_at'] ?? '')),
                'staleAfter' => trim((string) ($raw['stale_after'] ?? '')),
                'sourceUrls' => [trim((string) ($raw['source_url'] ?? ''))],
            ];
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
            $payload = ['id' => $jurisdiction->key, 'name' => (string) ($raw['jurisdiction_name'] ?? $jurisdiction->name), 'coverages' => [$coverage + ['rules' => [$rule]]]];
            $this->validator->validateJurisdiction($payload, $jurisdiction->key);

            return ['state' => 'valid', 'jurisdiction' => $jurisdiction, 'normalized' => ['coverage' => $coverage, 'rule' => $rule], 'errors' => []];
        } catch (DomainException $error) {
            return ['state' => 'invalid', 'jurisdiction' => $jurisdiction ?? null, 'normalized' => null, 'errors' => [$error->getMessage()]];
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
    private function payloadForRows(Jurisdiction $jurisdiction, array $rows): array
    {
        if (count($rows) === 1 && isset($rows[0]->normalized['payload'])) {
            return $rows[0]->normalized['payload'];
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

        return ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'coverages' => array_values($coverages)];
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

    private function boolean(mixed $value): bool
    {
        $boolean = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($boolean === null) {
            throw new DomainException('applies_on_holidays must be true or false.');
        }

        return $boolean;
    }
}
