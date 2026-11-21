<?php

namespace App\Services;

use DateTimeImmutable;
use DomainException;

/** Validation for existing Flutter catalog schema v1 before immutable publication. */
final class MobileCatalogPayloadValidator
{
    /** @param array<string, mixed> $payload */
    public function validate(array $payload, string $key): void
    {
        if (! in_array($key, ['cda_catalog', 'cda_geography', 'insurance_directory'], true) ||
            ($payload['datasetKey'] ?? null) !== $key || ($payload['schemaVersion'] ?? null) !== 1) {
            throw new DomainException('Unsupported mobile catalog contract.');
        }
        match ($key) {
            'cda_catalog' => $this->cdaCatalog($payload),
            'cda_geography' => $this->cdaGeography($payload),
            'insurance_directory' => $this->insuranceDirectory($payload),
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
