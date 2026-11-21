<?php

namespace Tests\Unit;

use App\Services\MobileCatalogPayloadValidator;
use DomainException;
use PHPUnit\Framework\TestCase;

class MobileCatalogPayloadValidatorTest extends TestCase
{
    public function test_the_three_real_bundled_catalogs_accept_the_server_publication_envelope(): void
    {
        foreach (['cda_catalog', 'cda_geography', 'insurance_directory'] as $key) {
            (new MobileCatalogPayloadValidator)->validate($this->fixture($key), $key);
            $this->addToAssertionCount(1);
        }
    }

    public function test_edits_cannot_create_duplicate_records_or_cross_dataset_contracts(): void
    {
        foreach (['cda_catalog', 'cda_geography', 'insurance_directory'] as $key) {
            $payload = $this->fixture($key);
            $wrong = $payload;
            $wrong['datasetKey'] = 'restrictions';
            $this->rejects($wrong, $key);
            $duplicate = $payload;
            $duplicate['entries'][] = $duplicate['entries'][0];
            $this->rejects($duplicate, $key);
            $empty = $payload;
            $empty['entries'] = [];
            $this->rejects($empty, $key);
        }
    }

    public function test_cda_catalog_rejects_unverified_inventory_and_unsafe_sources(): void
    {
        $catalog = $this->fixture('cda_catalog');
        $catalog['entries'][0]['certified'] = false;
        $this->rejects($catalog, 'cda_catalog');
        $catalog = $this->fixture('cda_catalog');
        $catalog['source']['sourceUrl'] = 'http://example.org/actors';
        $this->rejects($catalog, 'cda_catalog');
    }

    public function test_geography_rejects_unverified_addresses_and_invalid_colombian_coordinates(): void
    {
        $catalog = $this->fixture('cda_geography');
        $catalog['entries'][0]['latitude'] = 60;
        $this->rejects($catalog, 'cda_geography');
        $catalog = $this->fixture('cda_geography');
        $catalog['entries'][0]['locationSources'] = [];
        $this->rejects($catalog, 'cda_geography');
        $catalog = $this->fixture('cda_geography');
        $catalog['entries'][0]['locationSources'][0]['url'] = 'javascript:alert(1)';
        $this->rejects($catalog, 'cda_geography');
    }

    public function test_insurance_catalog_rejects_unsafe_contacts_and_unverified_services(): void
    {
        $directory = $this->fixture('insurance_directory');
        $directory['entries'][0]['channels'][0]['value'] = 'https://evil.test/';
        $this->rejects($directory, 'insurance_directory');
        $directory = $this->fixture('insurance_directory');
        $directory['entries'][0]['channels'][0]['verified'] = false;
        $this->rejects($directory, 'insurance_directory');
        $directory = $this->fixture('insurance_directory');
        $directory['entries'][0]['channels'][0]['sourceUrl'] = 'http://insecure.test/';
        $this->rejects($directory, 'insurance_directory');
    }

    /** @return array<string,mixed> */
    private function fixture(string $key): array
    {
        $file = match ($key) {
            'cda_catalog' => 'cda_catalog_v1.json',
            'cda_geography' => 'cda_geography_v1.json',
            'insurance_directory' => 'insurance_directory_v1.json',
        };
        $payload = json_decode(file_get_contents(dirname(__DIR__, 3).'/mobile/assets/catalogs/'.$file), true, 512, JSON_THROW_ON_ERROR);
        $payload['datasetKey'] = $key;
        $payload['version'] ??= '2026.11.18-test';
        $payload['generatedAt'] = '2026-11-18T12:00:00Z';

        return $payload;
    }

    /** @param array<string,mixed> $payload */
    private function rejects(array $payload, string $key): void
    {
        try {
            (new MobileCatalogPayloadValidator)->validate($payload, $key);
            $this->fail('An unsafe catalog update was accepted: '.$key);
        } catch (DomainException) {
            $this->addToAssertionCount(1);
        }
    }
}
