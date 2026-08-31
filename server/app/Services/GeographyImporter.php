<?php

namespace App\Services;

use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Support\GeographicNameNormalizer;
use DomainException;
use Illuminate\Support\Facades\DB;

class GeographyImporter
{
    private const SOURCE_SYSTEM = 'dane_divipola';

    private const SOURCE_VERSION = 'mgn_2025';

    public function __construct(
        private readonly DatasetAuditLogger $audit,
        private readonly JurisdictionService $jurisdictions,
        private readonly ?string $fixturePath = null,
        private readonly ?string $aliasPath = null,
        private readonly ?string $picoCatalogPath = null,
        private readonly ?string $picoMappingPath = null,
        private readonly ?string $registrationCatalogPath = null,
    ) {}

    /** @return array<string, int> */
    public function bootstrap(bool $dryRun = false): array
    {
        $data = $this->validatedData();
        if ($dryRun) {
            return $data['summary'];
        }

        return DB::transaction(function () use ($data): array {
            $country = $this->upsertCountry();
            $departments = [];
            foreach ($data['fixture']['departments'] as $department) {
                $departments[$department['code']] = $this->upsertUnit([
                    'parent_id' => $country->id,
                    'key' => 'co-'.strtolower($department['code']),
                    'level' => GeographicUnitLevel::Department,
                    'code' => $department['code'],
                    'name' => $department['name'],
                    'normalized_name' => GeographicNameNormalizer::normalize($department['name']),
                    'is_active' => true,
                    'source_system' => self::SOURCE_SYSTEM,
                    'source_version' => self::SOURCE_VERSION,
                    'metadata' => null,
                ]);
            }
            foreach ($data['fixture']['municipalities'] as $municipality) {
                $this->upsertUnit([
                    'parent_id' => $departments[$municipality['departmentCode']]->id,
                    'key' => 'co-'.$municipality['code'],
                    'level' => GeographicUnitLevel::Municipality,
                    'code' => $municipality['code'],
                    'name' => $municipality['name'],
                    'normalized_name' => GeographicNameNormalizer::normalize($municipality['name']),
                    'is_active' => true,
                    'source_system' => self::SOURCE_SYSTEM,
                    'source_version' => self::SOURCE_VERSION,
                    'metadata' => ['officialType' => $municipality['officialType']],
                ]);
            }
            foreach ($data['picoCatalog']['records'] as $record) {
                $mapping = $data['picoMappings'][$record['id']];
                $primary = GeographicUnit::query()->where('code', $mapping['primaryDivipolaCode'])->firstOrFail();
                $coverage = GeographicUnit::query()->whereIn('code', $mapping['coverageDivipolaCodes'])->pluck('id')->all();
                if (count($coverage) !== count($mapping['coverageDivipolaCodes'])) {
                    throw new DomainException('Pico jurisdiction coverage cannot be reconciled.');
                }
                $metadata = ['picoClassification' => $record['classification'], 'sourceDate' => $record['sourceDate']];
                if (($mapping['coverageStatus'] ?? null) === 'reference_only') {
                    $metadata['coverageStatus'] = 'reference_only';
                }
                $jurisdiction = Jurisdiction::query()->where('key', $record['id'])->first();
                $attributes = ['name' => $record['name'], 'kind' => JurisdictionKind::from($mapping['kind']), 'primary_geographic_unit_id' => $primary->id, 'enabled' => $record['classification'] === 'SUPPORTED_CURRENT', 'timezone' => 'America/Bogota', 'metadata' => $metadata];
                if ($jurisdiction) {
                    $jurisdiction = $this->jurisdictions->update($jurisdiction, $attributes);
                    $this->jurisdictions->setCoverage($jurisdiction, $coverage);
                } else {
                    $jurisdiction = $this->jurisdictions->create(['key' => $record['id']] + $attributes, $coverage);
                }
            }
            $this->audit->log(null, 'geography.bootstrapped', $country, [
                'source' => self::SOURCE_SYSTEM,
                'sourceVersion' => self::SOURCE_VERSION,
                'departmentCount' => $data['summary']['departments'],
                'municipalityCount' => $data['summary']['municipalities'],
                'jurisdictionCount' => $data['summary']['jurisdictions'],
                'registrationRecords' => $data['summary']['registrationRecords'],
                'exactMatches' => $data['summary']['exactMatches'],
                'aliasMatches' => $data['summary']['aliasMatches'],
            ]);

            return $data['summary'];
        });
    }

    /** @return array{fixture: array<string,mixed>, picoCatalog: array<string,mixed>, picoMappings: array<string,array<string,mixed>>, summary: array<string,int>} */
    private function validatedData(): array
    {
        $fixture = $this->readJson($this->fixturePath ?? database_path('data/colombia_divipola_mgn_2025.json'));
        $aliases = $this->readJson($this->aliasPath ?? database_path('data/registration_city_divipola_aliases_v1.json'));
        $picoCatalog = $this->readJson($this->picoCatalogPath ?? base_path('../mobile/assets/catalogs/pico_jurisdiction_catalog_v1.json'));
        $picoMappingFixture = $this->readJson($this->picoMappingPath ?? database_path('data/pico_jurisdiction_divipola_v1.json'));
        if (($fixture['schemaVersion'] ?? null) !== 1 || ($fixture['source']['authority'] ?? null) !== 'DANE' || ($fixture['source']['version'] ?? null) !== '2025') {
            throw new DomainException('DANE fixture provenance is invalid.');
        }
        $departments = $fixture['departments'] ?? null;
        $municipalities = $fixture['municipalities'] ?? null;
        if (! is_array($departments) || ! is_array($municipalities) || array_is_list($departments) === false || array_is_list($municipalities) === false) {
            throw new DomainException('DANE fixture hierarchy is invalid.');
        }
        $departmentCodes = [];
        foreach ($departments as $department) {
            if (! is_array($department) || ! is_string($department['code'] ?? null) || ! preg_match('/^\d{2}$/', $department['code']) || ! is_string($department['name'] ?? null) || isset($departmentCodes[$department['code']])) {
                throw new DomainException('DANE fixture departments are invalid or duplicate.');
            }
            $departmentCodes[$department['code']] = $department;
        }
        $municipalityCodes = [];
        foreach ($municipalities as $municipality) {
            if (! is_array($municipality) || ! is_string($municipality['code'] ?? null) || ! preg_match('/^\d{5}$/', $municipality['code']) || ! is_string($municipality['departmentCode'] ?? null) || ! isset($departmentCodes[$municipality['departmentCode']]) || ! is_string($municipality['name'] ?? null) || isset($municipalityCodes[$municipality['code']])) {
                throw new DomainException('DANE fixture municipalities are invalid, orphaned, or duplicate.');
            }
            $municipalityCodes[$municipality['code']] = $municipality;
        }
        $aliasMap = $this->validateAliases($aliases, $municipalityCodes, $departmentCodes);
        $registration = $this->readJson($this->registrationCatalogPath ?? base_path('../mobile/assets/catalogs/colombia_registration_cities_v1.json'));
        $registrationRecords = $registration['records'] ?? null;
        if (! is_array($registrationRecords) || ! array_is_list($registrationRecords)) {
            throw new DomainException('Registration city catalog is invalid.');
        }
        $canonicalPairs = [];
        foreach ($municipalityCodes as $municipality) {
            $canonicalPairs[$this->pair($municipality['name'], $departmentCodes[$municipality['departmentCode']]['name'])] = $municipality['code'];
        }
        $exact = 0;
        $alias = 0;
        foreach ($registrationRecords as $record) {
            if (! is_array($record) || ! is_string($record['municipality'] ?? null) || ! is_string($record['department'] ?? null)) {
                throw new DomainException('Registration city record is invalid.');
            }
            $pair = $this->pair($record['municipality'], $record['department']);
            if (isset($canonicalPairs[$pair])) {
                $exact++;
            } elseif (isset($aliasMap[$pair])) {
                $alias++;
            } else {
                throw new DomainException("Unmatched registration city: {$record['municipality']} / {$record['department']}");
            }
        }
        $picoMappings = $this->validatePicoMappings($picoCatalog, $picoMappingFixture, $municipalityCodes);

        return ['fixture' => $fixture, 'picoCatalog' => $picoCatalog, 'picoMappings' => $picoMappings, 'summary' => ['countries' => 1, 'departments' => count($departments), 'municipalities' => count($municipalities), 'jurisdictions' => count($picoCatalog['records']), 'coverageMappings' => array_sum(array_map(fn (array $mapping): int => count($mapping['coverageDivipolaCodes']), $picoMappings)), 'errors' => 0, 'registrationRecords' => count($registrationRecords), 'exactMatches' => $exact, 'aliasMatches' => $alias, 'unmatched' => 0, 'ambiguous' => 0]];
    }

    /** @param array<string,mixed> $aliases @param array<string,array<string,mixed>> $municipalities @param array<string,array<string,mixed>> $departments @return array<string,string> */
    private function validateAliases(array $aliases, array $municipalities, array $departments): array
    {
        $records = $aliases['records'] ?? null;
        if (($aliases['schemaVersion'] ?? null) !== 1 || ($aliases['sourceSystem'] ?? null) !== 'runt_registration_city_catalog' || ! is_array($records) || ! array_is_list($records) || count($records) !== 12) {
            throw new DomainException('Registration alias fixture is invalid.');
        }
        $map = [];
        foreach ($records as $alias) {
            if (! is_array($alias) || ! is_string($alias['sourceMunicipality'] ?? null) || trim($alias['sourceMunicipality']) === '' || ! is_string($alias['sourceDepartment'] ?? null) || trim($alias['sourceDepartment']) === '' || ! is_string($alias['divipolaCode'] ?? null) || ! preg_match('/^\d{5}$/', $alias['divipolaCode']) || ! isset($municipalities[$alias['divipolaCode']])) {
                throw new DomainException('Registration alias target is invalid.');
            }
            $target = $municipalities[$alias['divipolaCode']];
            $department = $departments[$target['departmentCode']];
            if (GeographicNameNormalizer::normalize($target['name']) !== GeographicNameNormalizer::normalize((string) ($alias['canonicalMunicipality'] ?? '')) || GeographicNameNormalizer::normalize($department['name']) !== GeographicNameNormalizer::normalize((string) ($alias['canonicalDepartment'] ?? ''))) {
                throw new DomainException('Registration alias canonical evidence is invalid.');
            }
            $pair = $this->pair($alias['sourceMunicipality'], $alias['sourceDepartment']);
            if (isset($map[$pair])) {
                throw new DomainException('Duplicate registration alias source pair.');
            }
            $map[$pair] = $alias['divipolaCode'];
        }

        return $map;
    }

    /** @param array<string,mixed> $catalog @param array<string,mixed> $mappingFixture @param array<string,array<string,mixed>> $municipalities @return array<string,array<string,mixed>> */
    private function validatePicoMappings(array $catalog, array $mappingFixture, array $municipalities): array
    {
        $records = $catalog['records'] ?? null;
        $mappings = $mappingFixture['records'] ?? null;
        if (! is_array($records) || ! array_is_list($records) || ! is_array($mappings) || ! array_is_list($mappings)) {
            throw new DomainException('Pico jurisdiction catalog is invalid.');
        }
        $byKey = [];
        foreach ($mappings as $mapping) {
            if (! is_array($mapping) || ! is_string($mapping['key'] ?? null) || ! is_string($mapping['primaryDivipolaCode'] ?? null) || ! isset($municipalities[$mapping['primaryDivipolaCode']]) || ! in_array($mapping['kind'] ?? null, array_map(static fn (JurisdictionKind $kind): string => $kind->value, JurisdictionKind::cases()), true) || ! is_array($mapping['coverageDivipolaCodes'] ?? null) || ! in_array($mapping['primaryDivipolaCode'], $mapping['coverageDivipolaCodes'], true) || isset($byKey[$mapping['key']])) {
                throw new DomainException('Pico jurisdiction mapping is invalid.');
            }
            foreach ($mapping['coverageDivipolaCodes'] as $code) {
                if (! is_string($code) || ! isset($municipalities[$code])) {
                    throw new DomainException('Pico jurisdiction coverage is unresolved.');
                }
            }
            $byKey[$mapping['key']] = $mapping;
        }
        foreach ($records as $record) {
            if (! is_array($record) || ! is_string($record['id'] ?? null) || ! isset($byKey[$record['id']])) {
                throw new DomainException('Pico jurisdiction is unresolved.');
            }
        }
        if (count($byKey) !== count($records)) {
            throw new DomainException('Pico jurisdiction mapping has unknown records.');
        }

        return $byKey;
    }

    /** @param array<string,mixed> $attributes */
    private function upsertUnit(array $attributes): GeographicUnit
    {
        $existing = GeographicUnit::query()->where('code', $attributes['code'])->first();
        if ($existing) {
            foreach (['key', 'level', 'parent_id'] as $field) {
                if ($existing->{$field} !== $attributes[$field]) {
                    throw new DomainException("Canonical geography structural contradiction for {$attributes['code']}.");
                }
            }
            $existing->update(collect($attributes)->only(['name', 'normalized_name', 'is_active', 'source_version', 'metadata'])->all());

            return $existing->refresh();
        }

        return GeographicUnit::query()->create($attributes);
    }

    private function upsertCountry(): GeographicUnit
    {
        return $this->upsertUnit(['parent_id' => null, 'key' => 'co', 'level' => GeographicUnitLevel::Country, 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => self::SOURCE_SYSTEM, 'source_version' => self::SOURCE_VERSION, 'metadata' => null]);
    }

    /** @return array<string,mixed> */
    private function readJson(string $path): array
    {
        try {
            $decoded = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            throw new DomainException("Invalid required fixture: $path");
        }
        if (! is_array($decoded) || array_is_list($decoded)) {
            throw new DomainException("Invalid required fixture: $path");
        }

        return $decoded;
    }

    private function pair(string $municipality, string $department): string
    {
        return GeographicNameNormalizer::normalize($municipality).'|'.GeographicNameNormalizer::normalize($department);
    }
}
