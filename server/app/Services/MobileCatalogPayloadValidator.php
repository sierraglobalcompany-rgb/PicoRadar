<?php

namespace App\Services;

use App\Enums\GeographicUnitLevel;
use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use DateTimeImmutable;
use DateTimeZone;
use DomainException;

/** Validation for versioned mobile catalog payloads before publication. */
final class MobileCatalogPayloadValidator
{
    /** @param array<string, mixed> $payload */
    public function validate(array $payload, string $key): void
    {
        if (! in_array($key, ['cda_catalog', 'cda_geography', 'insurance_directory', ServiceProvider::DATASET_KEY], true) ||
            ($payload['datasetKey'] ?? null) !== $key || ($payload['schemaVersion'] ?? null) !== 1) {
            throw new DomainException('Unsupported mobile catalog contract.');
        }
        match ($key) {
            'cda_catalog' => $this->cdaCatalog($payload),
            'cda_geography' => $this->cdaGeography($payload),
            'insurance_directory' => $this->insuranceDirectory($payload),
            ServiceProvider::DATASET_KEY => $this->serviceProviders($payload),
        };
    }

    /** @param array<string,mixed> $payload */
    private function cdaCatalog(array $payload): void
    {
        $source = $this->object($payload['source'] ?? null, 'source');
        foreach (['provider', 'datasetId', 'datasetName', 'latestSourceMonthName'] as $field) {
            $this->text($source[$field] ?? null, "source.$field");
        }
        $this->https($source['sourceUrl'] ?? null, 'source.sourceUrl');
        $this->instant($source['sourceVerifiedAt'] ?? null, 'source.sourceVerifiedAt');
        $this->year($source['latestSourceYear'] ?? null, 'source.latestSourceYear');
        $this->month($source['latestSourceMonth'] ?? null, 'source.latestSourceMonth');

        $metrics = $this->object($payload['metrics'] ?? null, 'metrics');
        foreach (['sourceRows', 'cdaSourceRows', 'latestPeriodCdaRows', 'currentUniqueCdaCount', 'staleHistoricalCdaExcludedCount', 'certificoNotSiCount', 'unsafeNoveltyCount', 'ambiguousCurrentDuplicateCount', 'uniqueCdaCount', 'excludedCurrentStatusCount', 'municipalityCount', 'departmentCount', 'sponsoredCdaCount'] as $field) {
            if (! is_int($metrics[$field] ?? null) || $metrics[$field] < 0) {
                throw new DomainException("Invalid CDA metric: $field.");
            }
        }
        foreach (['latestSourcePeriod', 'globalLatestSourcePeriod'] as $field) {
            $this->text($metrics[$field] ?? null, "metrics.$field");
        }
        if (! is_bool($metrics['futureSourcePeriodsIgnored'] ?? null)) {
            throw new DomainException('Invalid CDA futureSourcePeriodsIgnored flag.');
        }
        $seen = [];
        foreach ($this->rows($payload['entries'] ?? null, 'entries') as $entry) {
            $row = $this->object($entry, 'CDA entry');
            $id = $this->text($row['id'] ?? null, 'CDA id');
            $this->unique($seen, $id, 'CDA id');
            foreach (['name', 'municipality', 'department', 'departmentCode', 'sourceMonthName', 'novelty'] as $field) {
                $this->text($row[$field] ?? null, "CDA $field");
            }
            if (isset($row['nit']) && (! is_string($row['nit']) || trim($row['nit']) === '')) {
                throw new DomainException('Invalid CDA NIT.');
            }
            $this->year($row['sourceYear'] ?? null, 'CDA sourceYear');
            $this->month($row['sourceMonth'] ?? null, 'CDA sourceMonth');
            foreach (['generatedAt', 'sourceVerifiedAt'] as $field) {
                $this->instant($row[$field] ?? null, "CDA $field");
            }
            if (($row['certified'] ?? null) !== true) {
                throw new DomainException('Uncertified CDA cannot enter the published current inventory.');
            }
        }
        if (count($seen) !== $metrics['uniqueCdaCount']) {
            throw new DomainException('CDA inventory count does not match its published metric.');
        }
    }

    /** @param array<string,mixed> $payload */
    private function cdaGeography(array $payload): void
    {
        $period = $this->text($payload['catalogPeriod'] ?? null, 'catalogPeriod');
        if (! preg_match('/^\d{4}-(?:0[1-9]|1[0-2])$/D', $period) || ! is_bool($payload['approved'] ?? null)) {
            throw new DomainException('Invalid CDA geographic publication period/approval.');
        }
        $seen = [];
        foreach ($this->rows($payload['entries'] ?? null, 'entries') as $entry) {
            $row = $this->object($entry, 'CDA site');
            $this->unique($seen, $this->text($row['cdaId'] ?? null, 'CDA site id'), 'CDA site id');
            foreach (['catalogName', 'municipality', 'departmentCode'] as $field) {
                $this->text($row[$field] ?? null, "CDA site $field");
            }
            $status = $this->text($row['status'] ?? null, 'CDA site status');
            if (! in_array($status, ['pending', 'address_verified', 'geocoded', 'verified', 'rejected'], true)) {
                throw new DomainException('Unsupported CDA site status.');
            }
            $lat = $row['latitude'] ?? null;
            $lon = $row['longitude'] ?? null;
            if (($lat === null) !== ($lon === null) ||
                ($lat !== null && ((! is_float($lat) && ! is_int($lat)) || ! is_finite((float) $lat) || (float) $lat < -5 || (float) $lat > 14)) ||
                ($lon !== null && ((! is_float($lon) && ! is_int($lon)) || ! is_finite((float) $lon) || (float) $lon < -82 || (float) $lon > -66))) {
                throw new DomainException('Invalid Colombian CDA coordinates.');
            }
            if (in_array($status, ['address_verified', 'geocoded', 'verified'], true) &&
                (! is_string($row['address'] ?? null) || trim($row['address']) === '')) {
                throw new DomainException('Verified CDA site requires address.');
            }
            if (in_array($status, ['geocoded', 'verified'], true) && $lat === null) {
                throw new DomainException('Geocoded CDA site requires coordinates.');
            }
            foreach (['locationSources', 'compatibilitySources', 'contactSources'] as $field) {
                $sources = $this->optionalRows($row, $field);
                foreach ($sources as $source) {
                    $evidence = $this->object($source, 'CDA site evidence');
                    $this->https($evidence['url'] ?? null, 'CDA evidence.url');
                    $this->date($evidence['reviewedAt'] ?? null, 'CDA evidence.reviewedAt');
                }
                if ($field === 'locationSources' && in_array($status, ['address_verified', 'geocoded', 'verified'], true) && $sources === []) {
                    throw new DomainException('Verified CDA address requires location evidence.');
                }
            }
            foreach ($this->optionalRows($row, 'vehicleTypes') as $type) {
                if (! in_array($type, ['car', 'motorcycle'], true)) {
                    throw new DomainException('Invalid CDA vehicle type.');
                }
            }
            if (isset($row['web'])) {
                $this->https($row['web'], 'CDA website');
            }
            if (isset($row['phone']) && (! is_string($row['phone']) || ! preg_match('/^\+?[0-9 ()-]{7,24}$/D', $row['phone']))) {
                throw new DomainException('Invalid CDA telephone.');
            }
        }
    }

    /** @param array<string,mixed> $payload */
    private function insuranceDirectory(array $payload): void
    {
        $this->date($payload['reviewedAt'] ?? null, 'reviewedAt');
        $this->date($payload['sfcPublicationModifiedAt'] ?? null, 'sfcPublicationModifiedAt');
        foreach (['referenceSourceUrl', 'sfcSourceUrl'] as $field) {
            $this->https($payload[$field] ?? null, $field);
        }
        $this->text($payload['coverage'] ?? null, 'coverage');
        $seen = [];
        $nameOwner = [];
        foreach ($this->rows($payload['entries'] ?? null, 'entries') as $entry) {
            $row = $this->object($entry, 'insurer');
            $id = $this->text($row['id'] ?? null, 'insurer.id');
            $this->unique($seen, $id, 'insurer.id');
            foreach (['name', 'legalName'] as $field) {
                $this->text($row[$field] ?? null, "insurer.$field");
            }
            $this->date($row['reviewedAt'] ?? null, 'insurer.reviewedAt');
            foreach (['website', 'sourceUrl'] as $field) {
                $this->https($row[$field] ?? null, "insurer.$field");
            }
            foreach ([$row['name'], $row['legalName'], ...$this->optionalRows($row, 'aliases')] as $alias) {
                $folded = $this->fold($this->text($alias, 'insurer.alias'));
                if (isset($nameOwner[$folded]) && $nameOwner[$folded] !== $id) {
                    throw new DomainException('Ambiguous insurer alias across companies.');
                }
                $nameOwner[$folded] = $id;
            }
            if (! array_key_exists('categories', $row) || ! array_key_exists('channels', $row) || ! array_key_exists('aliases', $row)) {
                throw new DomainException('Insurer lists are required.');
            }
            $categories = $this->optionalRows($row, 'categories');
            foreach ($categories as $category) {
                if (! in_array($category, ['car', 'motorcycle', 'taxi'], true)) {
                    throw new DomainException('Invalid insurer category.');
                }
            }
            if (count(array_unique($categories)) !== count($categories)) {
                throw new DomainException('Duplicate insurer categories.');
            }
            $channelIds = [];
            $contactKeys = [];
            foreach ($this->optionalRows($row, 'channels') as $channel) {
                $item = $this->object($channel, 'insurer channel');
                $this->unique($channelIds, $this->text($item['id'] ?? null, 'channel.id'), 'channel.id');
                $kind = $this->text($item['kind'] ?? null, 'channel.kind');
                $purpose = $this->text($item['purpose'] ?? null, 'channel.purpose');
                $number = $this->text($item['value'] ?? null, 'channel.value');
                if (! in_array($kind, ['phone', 'whatsapp'], true) || ! in_array($purpose, ['assistance', 'customerService'], true)) {
                    throw new DomainException('Invalid insurer channel type/purpose.');
                }
                $pattern = $kind === 'whatsapp' ? '/^573\d{9}$/D' : '/^(?:\+?57[36]\d{9}|60[1-8]\d{7}|3\d{9}|018000\d{6}|#\d{3})$/D';
                if (! preg_match($pattern, $number)) {
                    throw new DomainException('Invalid insurer phone/WhatsApp destination.');
                }
                $normalized = ltrim($number, '+');
                if (strlen($normalized) === 12 && str_starts_with($normalized, '57')) {
                    $normalized = substr($normalized, 2);
                }
                $this->unique($contactKeys, $kind.':'.$normalized, 'insurer contact destination');
                foreach (['label'] as $field) {
                    $this->text($item[$field] ?? null, "channel.$field");
                }
                $this->https($item['sourceUrl'] ?? null, 'channel.sourceUrl');
                $this->date($item['reviewedAt'] ?? null, 'channel.reviewedAt');
                if (! is_bool($item['verified'] ?? null)) {
                    throw new DomainException('Invalid insurer channel verification status.');
                }
                $services = $this->optionalRows($item, 'services');
                if (count($services) !== count(array_unique($services, SORT_REGULAR))) {
                    throw new DomainException('Duplicate insurer channel services.');
                }
                foreach ($services as $service) {
                    if (! in_array($service, ['generalAssistance', 'towing', 'designatedDriver', 'roadsideRepair'], true) || $purpose !== 'assistance' || $item['verified'] !== true) {
                        throw new DomainException('Unverified or invalid insurer channel service.');
                    }
                }
            }
        }
    }

    /** @param array<string,mixed> $payload */
    private function serviceProviders(array $payload): void
    {
        $this->onlyKeys($payload, ['schemaVersion', 'datasetKey', 'version', 'generatedAt', 'providers'], 'service_providers envelope');
        foreach (['schemaVersion', 'datasetKey', 'version', 'generatedAt', 'providers'] as $field) {
            if (! array_key_exists($field, $payload)) {
                throw new DomainException("Missing service_providers field: $field.");
            }
        }

        $this->boundedText($payload['version'], 'service_providers version', 64);
        $generatedAt = $this->boundedText($payload['generatedAt'], 'service_providers generatedAt', 40);
        $this->instant($generatedAt, 'service_providers generatedAt');
        $generatedAtDate = (new DateTimeImmutable($generatedAt))->setTimezone(new DateTimeZone('America/Bogota'));
        $seen = [];
        $previous = null;
        $providers = $this->rowsAllowEmpty($payload['providers'], 'providers');

        foreach ($providers as $entry) {
            $row = $this->object($entry, 'service provider');
            $fields = [
                'id', 'category', 'departmentCode', 'department', 'municipalityCode', 'municipality',
                'name', 'address', 'latitude', 'longitude', 'contactUrl', 'sourceUrl', 'verifiedAt', 'validUntil',
            ];
            $this->onlyKeys($row, $fields, 'service provider');
            foreach ($fields as $field) {
                if (! array_key_exists($field, $row)) {
                    throw new DomainException("Missing service provider field: $field.");
                }
            }

            $id = $this->boundedText($row['id'], 'service provider id', 24);
            if (! preg_match('/^sp-[1-9][0-9]*$/D', $id)) {
                throw new DomainException('Service provider id must be sp-{primary_key}.');
            }
            $this->unique($seen, $id, 'service provider id');
            if (! in_array($row['category'], ServiceProvider::CATEGORIES, true)) {
                throw new DomainException('Invalid service provider category.');
            }
            $departmentCode = $this->boundedText($row['departmentCode'], 'departmentCode', 2);
            $municipalityCode = $this->boundedText($row['municipalityCode'], 'municipalityCode', 5);
            if (! preg_match('/^\d{2}$/D', $departmentCode) || ! preg_match('/^\d{5}$/D', $municipalityCode)) {
                throw new DomainException('Invalid DIVIPOLA department or municipality code.');
            }
            $this->boundedText($row['department'], 'department', 120);
            $this->boundedText($row['municipality'], 'municipality', 120);
            $this->boundedText($row['name'], 'service provider name', 160);
            $this->nullableBoundedText($row['address'], 'service provider address', 240);
            $this->nullableBoundedText($row['contactUrl'], 'service provider contactUrl', 768);
            if ($row['contactUrl'] !== null) {
                $this->https($row['contactUrl'], 'service provider contactUrl');
            }
            $sourceUrl = $this->boundedText($row['sourceUrl'], 'service provider sourceUrl', 768);
            $this->https($sourceUrl, 'service provider sourceUrl');

            $latitude = $row['latitude'];
            $longitude = $row['longitude'];
            if (($latitude === null) !== ($longitude === null) ||
                ($latitude !== null && ((! is_float($latitude) && ! is_int($latitude)) || ! is_finite((float) $latitude) || (float) $latitude < -5 || (float) $latitude > 14)) ||
                ($longitude !== null && ((! is_float($longitude) && ! is_int($longitude)) || ! is_finite((float) $longitude) || (float) $longitude < -82 || (float) $longitude > -66))) {
                throw new DomainException('Invalid or unpaired Colombian service provider coordinates.');
            }

            $verifiedAt = $this->boundedText($row['verifiedAt'], 'service provider verifiedAt', 40);
            $this->instant($verifiedAt, 'service provider verifiedAt');
            $validUntil = $this->boundedText($row['validUntil'], 'service provider validUntil', 10);
            $this->date($validUntil, 'service provider validUntil');
            if (new DateTimeImmutable($verifiedAt) > $generatedAtDate || $validUntil < $generatedAtDate->format('Y-m-d')) {
                throw new DomainException('Service provider source evidence is not current for generatedAt.');
            }

            if ($previous !== null && $this->compareServiceProviders($previous, $row) > 0) {
                throw new DomainException('Service providers must use deterministic order.');
            }
            $previous = $row;
        }

        $this->assertServiceProviderGeography($providers);
    }

    /** @param list<mixed> $providers */
    private function assertServiceProviderGeography(array $providers): void
    {
        if ($providers === []) {
            return;
        }

        $departmentCodes = array_values(array_unique(array_column($providers, 'departmentCode')));
        $municipalityCodes = array_values(array_unique(array_column($providers, 'municipalityCode')));
        $departments = GeographicUnit::query()
            ->where('level', GeographicUnitLevel::Department->value)
            ->where('is_active', true)
            ->whereIn('code', $departmentCodes)
            ->get(['id', 'code', 'name'])
            ->keyBy('code');
        $municipalities = GeographicUnit::query()
            ->where('level', GeographicUnitLevel::Municipality->value)
            ->where('is_active', true)
            ->whereIn('code', $municipalityCodes)
            ->get(['id', 'parent_id', 'code', 'name'])
            ->keyBy('code');

        foreach ($providers as $row) {
            $department = $departments->get($row['departmentCode']);
            $municipality = $municipalities->get($row['municipalityCode']);
            if (
                $department === null
                || $municipality === null
                || (int) $municipality->parent_id !== (int) $department->id
                || $department->name !== $row['department']
                || $municipality->name !== $row['municipality']
            ) {
                throw new DomainException('Service provider DIVIPOLA codes, names, and department-parent relationship do not match the active geographic catalog.');
            }
        }
    }

    /** @param array<string,mixed> $left @param array<string,mixed> $right */
    private function compareServiceProviders(array $left, array $right): int
    {
        foreach (['departmentCode', 'municipalityCode', 'category', 'name', 'id'] as $field) {
            $comparison = strcmp((string) $left[$field], (string) $right[$field]);
            if ($comparison !== 0) {
                return $comparison;
            }
        }

        return 0;
    }

    private function boundedText(mixed $value, string $label, int $maxLength): string
    {
        if (! is_string($value) || trim($value) === '' || preg_match('//u', $value) !== 1 || preg_match('/[\x00-\x1F\x7F]/u', $value)) {
            throw new DomainException("Missing or invalid $label.");
        }

        $trimmed = trim($value);
        $length = preg_match_all('/./us', $trimmed);
        if ($length === false || $length > $maxLength) {
            throw new DomainException("Missing or invalid $label.");
        }

        return $trimmed;
    }

    private function nullableBoundedText(mixed $value, string $label, int $maxLength): ?string
    {
        return $value === null ? null : $this->boundedText($value, $label, $maxLength);
    }

    /** @param array<string,mixed> $value @param list<string> $allowed */
    private function onlyKeys(array $value, array $allowed, string $label): void
    {
        if (array_diff(array_keys($value), $allowed) !== []) {
            throw new DomainException("Unexpected field in $label.");
        }
    }

    /** @return list<mixed> */
    private function rowsAllowEmpty(mixed $value, string $label): array
    {
        if (! is_array($value) || ! array_is_list($value)) {
            throw new DomainException("Expected JSON array: $label.");
        }

        return $value;
    }

    private function text(mixed $value, string $label): string
    {
        if (! is_string($value) || trim($value) === '') {
            throw new DomainException("Missing or invalid $label.");
        }

        return trim($value);
    }

    private function https(mixed $value, string $label): void
    {
        $url = $this->text($value, $label);
        $parts = parse_url($url);
        if (! is_array($parts) || ($parts['scheme'] ?? null) !== 'https' || ! isset($parts['host']) ||
            ! str_contains($parts['host'], '.') || isset($parts['user']) || isset($parts['pass']) ||
            (isset($parts['port']) && $parts['port'] !== 443) || isset($parts['fragment'])) {
            throw new DomainException("Invalid HTTPS URL: $label.");
        }
    }

    private function date(mixed $value, string $label): void
    {
        if (! is_string($value) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/D', $value) ||
            ! checkdate((int) substr($value, 5, 2), (int) substr($value, 8, 2), (int) substr($value, 0, 4))) {
            throw new DomainException("Invalid date: $label.");
        }
    }

    private function instant(mixed $value, string $label): void
    {
        if (! is_string($value) || ! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/D', $value)) {
            throw new DomainException("Invalid timestamp: $label.");
        }
        try {
            new DateTimeImmutable($value);
            $errors = DateTimeImmutable::getLastErrors();
            if (is_array($errors) && ($errors['warning_count'] > 0 || $errors['error_count'] > 0)) {
                throw new DomainException("Invalid timestamp: $label.");
            }
        } catch (\Throwable) {
            throw new DomainException("Invalid timestamp: $label.");
        }
    }

    /** @return array<string,mixed> */
    private function object(mixed $value, string $label): array
    {
        if (! is_array($value) || array_is_list($value)) {
            throw new DomainException("Invalid JSON object: $label.");
        }

        return $value;
    }

    /** @return list<mixed> */
    private function rows(mixed $value, string $label): array
    {
        if (! is_array($value) || ! array_is_list($value) || $value === []) {
            throw new DomainException("Expected nonempty JSON array: $label.");
        }

        return $value;
    }

    /** @param array<string,mixed> $parent @return list<mixed> */
    private function optionalRows(array $parent, string $key): array
    {
        if (! array_key_exists($key, $parent)) {
            return [];
        }
        $value = $parent[$key];
        if (! is_array($value) || ! array_is_list($value)) {
            throw new DomainException("Invalid JSON array: $key.");
        }

        return $value;
    }

    /** @param array<string,bool> $seen */
    private function unique(array &$seen, string $value, string $label): void
    {
        if (isset($seen[$value])) {
            throw new DomainException("Duplicate $label.");
        }
        $seen[$value] = true;
    }

    private function fold(string $value): string
    {
        $folded = strtr($value, [
            'Á' => 'a', 'À' => 'a', 'Â' => 'a', 'Ä' => 'a', 'á' => 'a', 'à' => 'a', 'â' => 'a', 'ä' => 'a',
            'É' => 'e', 'È' => 'e', 'Ê' => 'e', 'Ë' => 'e', 'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
            'Í' => 'i', 'Ì' => 'i', 'Î' => 'i', 'Ï' => 'i', 'í' => 'i', 'ì' => 'i', 'î' => 'i', 'ï' => 'i',
            'Ó' => 'o', 'Ò' => 'o', 'Ô' => 'o', 'Ö' => 'o', 'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'ö' => 'o',
            'Ú' => 'u', 'Ù' => 'u', 'Û' => 'u', 'Ü' => 'u', 'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'u',
            'Ñ' => 'n', 'ñ' => 'n',
        ]);

        return strtolower(trim(preg_replace('/\s+/u', ' ', $folded) ?? $folded));
    }

    private function year(mixed $value, string $label): void
    {
        if (! is_int($value) || $value < 2000 || $value > 2200) {
            throw new DomainException("Invalid $label.");
        }
    }

    private function month(mixed $value, string $label): void
    {
        if (! is_int($value) || $value < 1 || $value > 12) {
            throw new DomainException("Invalid $label.");
        }
    }
}
